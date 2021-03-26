/*
    Copyright (c) 2019 Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2019
* @group Recurring Donations
* @description Trigger on Recurring Donations when enhanced Recurring Donations are enabled
*
*/
public class RD2_RecurringDonations_TDTM extends TDTM_Runnable {

    /***
    * @description dml actions gathered during trigger execution
    */
    private DmlWrapper dmlActions = new DmlWrapper();

    /***
    * @description Recurring Donation schedule service instance
    */
    @TestVisible
    private RD2_ScheduleService scheduleService {
        get {
            if (scheduleService == null) {
                scheduleService = new RD2_ScheduleService();
            }
            return scheduleService;
        }
        set;
    }

    /***
    * @description Recurring Donation naming service instance
    */
    @TestVisible
    private RD2_NamingService namingService {
        get {
            if (namingService == null) {
                namingService = new RD2_NamingService();
            }
            return namingService;
        }
        set;
    }

    /**
     * @description Current date is the cut off date to determine all functionality related a Recurring Donation.
     * Moreover, it is used to calculate the RD end date and can be a past date, today or a future date when testing.
     * When executed from a scheduler or standard DML, the current date is always today.
    */
    private Date currentDate {
        get {
            if (currentDate == null) {
                currentDate = RD2_ScheduleService.currentDate;
            }
            return currentDate;
        } set;
    }

    /***
    * @description Trigger handler on Recurring Donations when enhancement is enabled
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    * @param objResult Recurring Donation SObject describe
    * @return dmlWrapper
    */
    public override DmlWrapper run(
        List<SObject> rds, List<SObject> oldRds,
        TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult
    ) {

        if (!RD2_EnablementService.isRecurringDonations2Enabled) {
            return null;
        }
        if (TDTM_ProcessControl.isRecursive(TDTM_ProcessControl.flag.RD)) {
            return null;
        }
        if (triggerAction != TDTM_Runnable.Action.BeforeInsert && triggerAction != TDTM_Runnable.Action.BeforeUpdate) {
            TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.RD, true);
        }

        autogenerateNames(rds, oldRds, triggerAction);
        adjustDataAndValidate(rds, oldRds, triggerAction);
        transformDataInBeforeContext(rds, oldRds, triggerAction);
        handleSchedulesInAfterContext(rds, oldRds, triggerAction);

        // Insert/Update any pending RecurringDonationSchedule records before the
        // evaluation service is called so that the full schedule is available to the
        // service to determine what Opportunities to insert or modify
        TDTM_TriggerHandler.processDML(dmlActions);
        dmlActions = null;

        findMatchingElevateOpps(rds, triggerAction);

        evaluateOpportunities(rds, oldRds, triggerAction);

        dispatchToIntegrationGateway(rds, oldRds, triggerAction);

        cancelCommitments(rds, oldRds, triggerAction);

        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.RD, false);
        return dmlActions;
    }

    /***
    * @description Autogenerates recurring donation names
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    */
    public void autogenerateNames(List<SObject> rds, List<SObject> oldRds, TDTM_Runnable.Action triggerAction) {

        if (triggerAction == TDTM_Runnable.Action.BeforeInsert) {
            namingService.autogenerateNames(rds);

        } else if (triggerAction == TDTM_Runnable.Action.BeforeUpdate) {
            namingService.autogenerateNamesOnChange(rds, oldRds);
        }
    }

    /***
    * @description Data Transformation Actions for Before Insert and Update Trigger Actions:
    * - If RecurringType is Open and number of planned installments = 1, set number of planned installments to null
    * - If RecurringType is Fixed and number of paid installments is >= number of planned installments, then close RD
    * - Update the Next Donation Date on both Before Insert and Update trigger actions
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, BeforeUpdate, etc.
    */
    @TestVisible
    private void transformDataInBeforeContext(List<npe03__Recurring_Donation__c> rds,
        List<npe03__Recurring_Donation__c> oldRds, TDTM_Runnable.Action triggerAction
    ) {
        if (triggerAction != TDTM_Runnable.Action.BeforeInsert
            && triggerAction != TDTM_Runnable.Action.BeforeUpdate
        ) {
            return;
        }

        Map<Id, npe03__Recurring_Donation__c> oldRdsById = new Map<Id, npe03__Recurring_Donation__c>();
        Map<Id, List<Opportunity>> oppsByRDId = new Map<Id, List<Opportunity>>();
        Map<Id, List<RecurringDonationSchedule__c>> schedulesByRdId = new Map<Id, List<RecurringDonationSchedule__c>>();

        if (triggerAction == TDTM_Runnable.Action.BeforeUpdate) {
            oldRdsById = new Map<Id, npe03__Recurring_Donation__c>(oldRds);
            oppsByRDId = new RD2_OpportunityEvaluationService().getOpportunitiesByRDId(UTIL_SObject.extractIds(rds));
            schedulesByRdId = scheduleService.getAllSchedules(rds, oldRds);
        }

        for (npe03__Recurring_Donation__c rd : rds) {
            if (triggerAction == TDTM_Runnable.Action.BeforeInsert) {
                RD2_RecurringDonation rdRecord = new RD2_RecurringDonation(rd)
                    .revisePlannedInstallments()
                    .reviseNextDonationDateBeforeInsert(scheduleService);

            } else if (triggerAction == TDTM_Runnable.Action.BeforeUpdate) {
                RD2_RecurringDonation rdRecord = new RD2_RecurringDonation(rd, oppsByRDId.get(rd.Id))
                    .revisePlannedInstallments()
                    .reviseStatus(currentDate, scheduleService)
                    .reviseNextDonationDate(scheduleService, schedulesByRdId.get(rd.Id));

                preventScheduleChangeWhenPaused(rdRecord, oldRdsById.get(rd.Id), schedulesByRdId.get(rd.Id));
            }
        }
    }

    /***
    * @description Prevents Recurring Donation update when
    * its schedule related fields are changed and the RD has an active Pause
    * @param rdRecord The Recurring Donation to validate
    * @param oldRd The old Recurring Donation
    * @param schedules All active Schedules on the Recurring Donation
    * @return void
    */
    private void preventScheduleChangeWhenPaused(
        RD2_RecurringDonation rdRecord, npe03__Recurring_Donation__c oldRd, List<RecurringDonationSchedule__c> schedules
    ) {

        if (rdRecord.isClosed()) {
            return;
        }

        npe03__Recurring_Donation__c rd = rdRecord.getSObject();
        List<String> changedFields = getFieldsChangingSchedule(rd, oldRd);

        if (!changedFields.isEmpty() && scheduleService.pauseHandler.hasActivePause(schedules, currentDate)) {
            rd.addError(
                String.format(
                    System.Label.RD2_PauseCannotExistOnScheduleChange,
                    new String[]{ String.join(changedFields, ', ') }
                )
            );
        }
    }

    /***
    * @description Get changed fields on the RD that impact schedule date change
    * @param rd The Recurring Donation to validate
    * @param oldRd The old Recurring Donation
    * @return List<String>
    */
    private List<String> getFieldsChangingSchedule(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {
        List<String> changedFields = new List<String>();

        if (rd.npe03__Installment_Period__c != oldRd.npe03__Installment_Period__c) {
            changedFields.add(SObjectType.npe03__Recurring_Donation__c.fields.npe03__Installment_Period__c.getLabel());
        }
        if (rd.InstallmentFrequency__c != oldRd.InstallmentFrequency__c) {
            changedFields.add(SObjectType.npe03__Recurring_Donation__c.fields.InstallmentFrequency__c.getLabel());
        }
        if (rd.Day_of_Month__c != oldRd.Day_of_Month__c) {
            changedFields.add(SObjectType.npe03__Recurring_Donation__c.fields.Day_of_Month__c.getLabel());
        }

        return changedFields;
    }

    /***
    * @description Data Transformation Actions for Before Insert; and before validation
    * - Assign Installment Frequency to the recurring donation record if the field is null on insert
    * - Set Day of Month to be the Last_Day if the original value is "31"
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    */
    public void adjustDataAndValidate(List<SObject> rds, List<SObject> oldRds, TDTM_Runnable.Action triggerAction) {
        //data transformation happens in the Before context only
        if (triggerAction != TDTM_Runnable.Action.BeforeInsert
            && triggerAction != TDTM_Runnable.Action.BeforeUpdate
        ) {
            return;
        }

        new RD2_DataRegulationService(currentDate)
            .adjust(rds, oldRds);

        List<RD2_ValidationService.ErrorRecord> errorRds = new RD2_ValidationService(rds, oldRds)
            .validate();

        for (RD2_ValidationService.ErrorRecord errorRd : errorRds) {
            errorRd.getRecord().addError(errorRd.getFirstError());
        }
    }
    
    /**
    * @description When new recurring donations are inserted that have a value in the CommitmentId field
    * launch up a queueable process to look for matching existing Opportunities with that same CommmitmentId.
    * @param rds Inserted Recurring Donations
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    */
    private void findMatchingElevateOpps(List<npe03__Recurring_Donation__c> rds, TDTM_Runnable.Action triggerAction) {

        if (triggerAction != Action.AfterInsert) {
            return;
        }

        Map<String, Id> rdIdByCommitmentId = new Map<String, Id>();
        for (npe03__Recurring_Donation__c rd : rds) {
            if (String.isNotBlank(rd.CommitmentId__c)) {
                rdIdByCommitmentId.put(rd.CommitmentId__c, rd.Id);
            }
        }

        if (rdIdByCommitmentId.isEmpty()) {
            return;
        }

        RD2_QueueableService.ElevateOpportunityMatcher service
            = new RD2_QueueableService.ElevateOpportunityMatcher(rdIdByCommitmentId);

        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(service);

        } else {
            service.match();
        }

    }

    /***
    * @description Determine if Installment Opportunities need to be created or updated.
    * Opportunities are evaluated *asynchronously* unless the async job limit has been reached.
    * Thus, static flags set in the evaluation service are reset when the service executes in the async mode.
    * However, the trigger can check for those flags and verify if the service should be called at all.
    *
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    * @return void
    */
    public void evaluateOpportunities(List<npe03__Recurring_Donation__c> rds, List<npe03__Recurring_Donation__c> oldRds, TDTM_Runnable.Action triggerAction) {
        if (RD2_OpportunityEvaluationService.skipEvaluationService) {
            return;
        }

        Set<Id> rdIds = new Set<Id>();
        Set<Id> rdIdsWhereScheduleChanged = new Set<Id>();

        if (triggerAction == TDTM_Runnable.Action.AfterInsert) {
            rdIds = new Map<Id, npe03__Recurring_Donation__c>(rds).keySet();

        } else if (triggerAction == TDTM_Runnable.Action.AfterUpdate) {
            RD2_OpportunityEvaluationService evalService = new RD2_OpportunityEvaluationService();
            Map<Id, npe03__Recurring_Donation__c> oldRdsById = new Map<Id, npe03__Recurring_Donation__c>(oldRds);

            for (npe03__Recurring_Donation__c rd : rds) {
                npe03__Recurring_Donation__c oldRd = oldRdsById.get(rd.Id);

                if (evalService.hasKeyFieldChanged(rd, oldRd)) {
                    rdIds.add(rd.Id);
                }

                if (rd.npe03__Next_Payment_Date__c != oldRd.npe03__Next_Payment_Date__c
                    || !getFieldsChangingSchedule(rd, oldRd).isEmpty()
                ) {
                    rdIdsWhereScheduleChanged.add(rd.Id);
                }
            }
        }

        if (rdIds.isEmpty()) {
            return;
        }

        if (triggerAction == TDTM_Runnable.Action.AfterInsert && shouldEvaluateOppsSynchronouslyOnInsert(rds.size() > 1)) {
            new RD2_QueueableService.EvaluateInstallmentOpportunities(rdIds, rdIdsWhereScheduleChanged)
                .executeOppEvaluationService();

        } else {
            RD2_QueueableService.enqueueOppEvalService(rdIds, rdIdsWhereScheduleChanged);
        }
    }

    /***
    * @description Determines whether Opportunities should be evaluated synchronously or asynchronously
    * @return Boolean
    */
    @TestVisible
    private Boolean shouldEvaluateOppsSynchronouslyOnInsert(Boolean isBulk) {
        RD2_Settings settings = new RD2_Settings();

        if (settings.firstInstallmentCreateMode == RD2_Constants.FirstInstallmentOppCreateOptions.Synchronous.name()) {
            return true;
        }

        if (settings.firstInstallmentCreateMode == RD2_Constants.FirstInstallmentOppCreateOptions.ASynchronous.name()) {
            return false;
        }

        if (settings.firstInstallmentCreateMode == RD2_Constants.FirstInstallmentOppCreateOptions.Asynchronous_When_Bulk.name() && isBulk) {
            return false;
        }

        return true;
    }

    /***
    * @description Dispatches trigger records to integration gateway
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    */
    private void dispatchToIntegrationGateway(List<SObject> rds, List<SObject> oldRds, TDTM_Runnable.Action triggerAction) {
        if (triggerAction == TDTM_Runnable.Action.BeforeDelete) {
            integrationGateway.handleBeforeDelete(oldRds);
        }
    }

    /***
    * @description Creates/modifies schedule record(s) after insert/update of recurring donation
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    */
    private void handleSchedulesInAfterContext(List<SObject> rds, List<SObject> oldRds, TDTM_Runnable.Action triggerAction) {

        if (triggerAction == TDTM_Runnable.Action.AfterInsert) {
            buildNewSchedules(rds);

        } else if (triggerAction == TDTM_Runnable.Action.AfterUpdate) {
            synchronizeSchedulesAfterRDUpdate(rds, oldRds);
        }
    }

    /***
    * @description Handles schedule creation after insert of recurring donation
    * @param rds Trigger.new records
    */
    private void buildNewSchedules(List<npe03__Recurring_Donation__c> rds) {

        for (npe03__Recurring_Donation__c rd : rds) {
            dmlActions.objectsToInsert.addAll(scheduleService.buildNewSchedules(rd));
        }
    }

    /***
    * @description Handles schedule modification/creation after modification of recurring donation
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    */
    private void synchronizeSchedulesAfterRDUpdate(List<npe03__Recurring_Donation__c> rds, List<npe03__Recurring_Donation__c> oldRds) {

        Map<Id, npe03__Recurring_Donation__c> filteredRecurringDonations = scheduleService.getRecurringDonationsNeedingScheduleUpdates(rds, oldRds, TDTM_Runnable.Action.AfterUpdate);

        // We only need schedules for RDs that qualify for schedule updates in order to sync schedules
        Map<Id, List<RecurringDonationSchedule__c>> oldSchedules = scheduleService.getExistingSchedules(filteredRecurringDonations.values());

        DmlWrapper revisedSchedules;
        for (npe03__Recurring_Donation__c rd : filteredRecurringDonations.values()) {
            revisedSchedules = scheduleService.getUpdatedSchedules(rd, oldSchedules.get(rd.Id));

            dmlActions.objectsToInsert.addAll(revisedSchedules.objectsToInsert);
            dmlActions.objectsToUpdate.addAll(revisedSchedules.objectsToUpdate);
        }
    }

    /**
    * @description Cancel Commitments in Elevate for closed Recurring Donations containing a Commitment Id. 
    *   If the Elevate RD is closed and Elevate Service is enabled,
    *   the RD status will be set to pending process and an async job will be kick off 
    *   to cancel the mathced commitment in Elevate.
    * @param rds Trigger.new records
    * @param oldRds Trigger.old records
    * @param triggerAction BeforeInsert, AfterInsert, etc.
    */
    private void cancelCommitments(List<npe03__Recurring_Donation__c> rds, List<npe03__Recurring_Donation__c> oldRds, TDTM_Runnable.Action triggerAction ) {
        if (triggerAction != TDTM_Runnable.Action.BeforeUpdate
            || !RD2_ElevateIntegrationService.isIntegrationEnabled()) {
            return;
        }

        List<RD2_CancelCommitmentService.RecordWrapper> commitmentRDs = new List<RD2_CancelCommitmentService.RecordWrapper>();

        for (Integer i = 0; i < rds.size(); i++) {
            npe03__Recurring_Donation__c closedRd = rds[i];
            RD2_RecurringDonation rd = new RD2_RecurringDonation(closedRd);
            RD2_RecurringDonation oldRd = new RD2_RecurringDonation(oldRds[i]);

            if (rd.isElevateRecord() && rd.isClosed() && !oldRd.isClosed()) {

                if (RD2_ElevateIntegrationService.isElevateEvent(rd, oldRd)) {
                    continue;
                }

                //send the RD details including the user provided Closed Reason to the commitment service
                commitmentRDs.add(new RD2_CancelCommitmentService.RecordWrapper(
                    new npe03__Recurring_Donation__c(
                        Id = closedRd.Id,
                        ClosedReason__c = closedRd.ClosedReason__c,
                        CommitmentId__c = closedRd.CommitmentId__c
                    )
                ));

                // update the closed RD reason to Elevate pending status
                closedRd.ClosedReason__c = System.Label.RD2_ElevatePendingStatus;
            }
        }

        if (!commitmentRDs.isEmpty()) {
            System.enqueueJob(new RD2_QueueableService.CancelCommitmentService(commitmentRDs));
        }
    }
}