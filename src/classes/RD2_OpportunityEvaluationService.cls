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
* @description Installment Opportunity Evaluation and Processing
*
*/
public inherited sharing class RD2_OpportunityEvaluationService {

    /***
     * @description CurrencyIsoCode field name
     */
    private static final String CURRENCY_ISO_CODE_FIELD = UTIL_Currency.CURRENCY_ISO_CODE_FIELD;

    /***
    * @description Determines if multi-currency is enabled for the org
    */
    private Boolean isMultiCurrencyEnabled {
        get {
            if (isMultiCurrencyEnabled == null) {
                isMultiCurrencyEnabled = UserInfo.isMultiCurrencyOrganization();
            }
            return isMultiCurrencyEnabled;
        }
        set;
    }

    /**
     * @description Indicates if the Opp evaluation service will be skipped.
     * The flag is currently applicable to migration since the Opp evaluation service should not be executed on migration.
     * For example, if an active RD has no Opp, no new Opp should be created during migration.
     * If the RD is closed, close action on Open Opps should not be applied when data migration is executed.
     */
    public static Boolean skipEvaluationService = false;

    /**
    * @description Indicates if the Opportunity evaluation is invoked from a nightly batch job
    */
    private Boolean isBatchContext = false;

    /***
    * @description Recurring Donation custom settings
    */
    private RD2_Settings rdSettings {
        get {
            if (rdSettings == null) {
                rdSettings = new RD2_Settings();
            }
            return rdSettings;
        }
        set;
    }

    /**
     * @description Current date is the cut off date to filter out and evaluate existing Opportunities
     * and to determine if the next Opp should be created for a Recurring Donation.
     * Moreover, it is used to calculate projected installments as of the current date.
     * It can be a past date, today or a future date when testing. When executed from a scheduler,
     * the current date is always today.
    */
    private Date currentDate {
        get {
            if (currentDate == null) {
                currentDate = RD2_ScheduleService.currentDate;
            }
            return currentDate;
        } set;
    }

    /**
     * @description Beggining of the current calendar or fiscal year, whichever is earlier.
     * The start date is offset by the Next Donation Date match days before the year start date
     * so past Opportunities matching future projected installments are returned.
    */
    private Date startDate {
        get {
            return yearValueProcessor
                .getStartDate()
                .addDays(-rdSettings.nextDonationDateMatchDays);
        } set;
    }

    /***
    * @description Recurring Donation Opportunity service
    */
    private RD2_OpportunityService oppService {
        get {
            if (oppService == null) {
                oppService = new RD2_OpportunityService(currentDate, dbService, customFieldMapper);
            }
            return oppService;
        }
        set;
    }

    /***
    * @description Applies DML operations on records and keeps track of errors
    */
    private RD2_DatabaseService dbService {
        get {
            if (dbService == null) {
                dbService = new RD2_DatabaseService();
            }
            return dbService;
        }
        set;
    }

    /***
    * @description Recurring Donation Schedule service
    */
    public RD2_ScheduleService scheduleService {
        get {
            if (scheduleService == null) {
                scheduleService = new RD2_ScheduleService();
            }
            return scheduleService;
        } set;
    }

    /***
    * @description Calculates Current and Next Year Values for a Recurring Donation
    */
    @TestVisible
    private RD2_YearValueProcessor yearValueProcessor {
        get {
            if (yearValueProcessor == null) {
                yearValueProcessor = new RD2_YearValueProcessor(currentDate, scheduleService);
            }
            return yearValueProcessor;
        }
        set;
    }

    /***
    * @description Contains the current custom field mappings used to copy specified fields
    * on Recurring Donation to mapped fields onto the Opportunity record
    */
    private RD2_CustomFieldMapper customFieldMapper {
        get {
            if (customFieldMapper == null) {
                customFieldMapper = new RD2_CustomFieldMapper();
            }
            return customFieldMapper;
        }
        set;
    }

    /***
    * @description Helps building a query for Recurring Donations and their child records
    */
    private RD2_QueryService queryService {
        get {
            if (queryService == null) {
                queryService = new RD2_QueryService();
            }
            return queryService;
        }
        set;
    }

    /**
     * @description Recurring Donation Id's to be processed
     */
    public Set<Id> rdIds {
        get {
            if (rdIds == null && rds != null) {
                rdIds = (new Map<Id, npe03__Recurring_Donation__c>(rds)).keySet();
            }
            return rdIds;
        } set;
    }

    /**
     * @description Queried Recurring Donation records with subqueries to be processed.
     */
    @TestVisible
    private List<npe03__Recurring_Donation__c> rds {
        get {
            if (rds == null && rdIds != null) {
                rds = queryService.getRecurringDonationsWithRelatedRecords(this.rdIds, this.startDate);
            }
            return rds;
        } set;
    }

    /**
    * @description Contains Ids of new Recurring Donations
    */
    @TestVisible
    private Set<Id> newRDIds {
        get {
            if (newRDIds == null) {
                newRDIds = getNewRDIds(this.rdIds);
            }
            return newRDIds;
        } set;
    }

    /**
    * @description Recurring Donation Ids for which schedule has been changed
    */
    @TestVisible
    private Set<Id> rdIdsWhereScheduleChanged {
        get {
            if (rdIdsWhereScheduleChanged == null) {
                rdIdsWhereScheduleChanged = new Set<Id>();
            }
            return rdIdsWhereScheduleChanged;
        } 
        set;
    }

    /**
    * @description Contains Number of Paid Installments for fixed-length RD records only
    */
    @TestVisible
    private Map<Id, Integer> paidInstallmentsByRDId {
        get {
            if (paidInstallmentsByRDId == null) {
                paidInstallmentsByRDId = getPaidInstallmentsForFixedLength();
            }
            return paidInstallmentsByRDId;
        } set;
    }

    /**
     * @description Sets batch context
     * @return RD2_OpportunityEvaluationService The service instance
     */
    public RD2_OpportunityEvaluationService withBatchContext() {
        isBatchContext = true;
        return this;
    }

    /**
     * @description Sets current date.
     * It also synchronizes the passed in current date with the RD Schedule service date.
     *
     * @param currentDate Date considered as the current date
     * @return RD2_OpportunityEvaluationService The service instance
     */
    public RD2_OpportunityEvaluationService withCurrentDate(Date currentDate) {
        this.currentDate = currentDate;
        RD2_ScheduleService.currentDate = currentDate;
        return this;
    }

    /**
     * @description Pass the set of Recurring Donation Id's to be processed
     * @param rdIds Recurring Donation Ids
     * @return RD2_OpportunityEvaluationService The service instance
     */
    public RD2_OpportunityEvaluationService withRds(Set<Id> rdIds) {
        this.rdIds = rdIds;
        return this;
    }

    /**
     * @description Set Recurring Donation Ids to indicate a changed schedule
     * @param rdIds Recurring Donation Ids for which schedule has been changed
     * @return RD2_OpportunityEvaluationService The service instance
     */
    public RD2_OpportunityEvaluationService withScheduleChanged(Set<Id> rdIds) {
        this.rdIdsWhereScheduleChanged = rdIds;
        return this;
    }

    /**
     * @description Returns number of failed Recurring Donation records
     * @return Integer
     */
    public Integer getRecordsFailed() {
        return dbService.getRecordsFailed();
    }

    /**
     * @description Returns set of Ids with failed RDs
     * @return Set<Id>
     */
    public Set<Id> getRecordsFailedId() {
        return dbService.getRecordsFailedId();
    }

    /**
     * @description Returns Map of Ids and error messages for failed RDs
     * @return Map<Id,String>
     */
    public Map<Id,String> getRecordsFailedMap() {
        return dbService.getRecordsFailedMap();
    }

    /**
     * @description Returns true if any of the key fields used to create or manage installment
     * Opportunities has been changed.
     * @param rd Changed Recurring Donation
     * @param oldRd Old Recurring Donation
     * @return Boolean
     */
    public Boolean hasKeyFieldChanged(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {
        Boolean isChanged =
            rd.npe03__Contact__c != oldRd.npe03__Contact__c ||
            rd.npe03__Organization__c != oldRd.npe03__Organization__c ||
            rd.npe03__Amount__c != oldRd.npe03__Amount__c ||
            rd.npe03__Installment_Period__c != oldRd.npe03__Installment_Period__c ||
            rd.npe03__Installments__c != oldRd.npe03__Installments__c ||
            rd.InstallmentFrequency__c != oldRd.InstallmentFrequency__c ||
            rd.StartDate__c != oldRd.StartDate__c ||
            rd.Day_of_Month__c != oldRd.Day_of_Month__c ||
            rd.Status__c != oldRd.Status__c ||
            rd.PaymentMethod__c != oldRd.PaymentMethod__c ||
            rd.npe03__Recurring_Donation_Campaign__c != oldRd.npe03__Recurring_Donation_Campaign__c ||
            rd.EndDate__c != rd.EndDate__c;

        if (!isChanged && isMultiCurrencyEnabled) {
            isChanged = (String) rd.get(CURRENCY_ISO_CODE_FIELD) != (String) oldRd.get(CURRENCY_ISO_CODE_FIELD);
        }

        if (!isChanged) {
            isChanged = customFieldMapper.hasKeyFieldChanged(rd, oldRd);
        }

        return isChanged;
    }

    /**
     * @description Primary processor
     * @return RD2_OpportunityEvaluationService This service instance
     */
    public RD2_OpportunityEvaluationService evaluateOpportunities() {
        //do not evaluate Opps when override is set
        if (skipEvaluationService) {
            return this;
        }

        List<npe03__Recurring_Donation__c> newOppRDs = new List<npe03__Recurring_Donation__c>();
        List<npe03__Recurring_Donation__c> updateOppRDs = new List<npe03__Recurring_Donation__c>();
        List<npe03__Recurring_Donation__c> closedRDs = new List<npe03__Recurring_Donation__c>();
        List<RD2_RecurringDonation> rdRecords = new List<RD2_RecurringDonation>();

        for (npe03__Recurring_Donation__c rd : rds) {
            RD2_RecurringDonation rdRecord = new RD2_RecurringDonation(rd);

            if (!rdRecord.isEnhancedFormat()) {
                continue;
            }

            //continue processing enhanced RD format records only
            rdRecords.add(rdRecord);

            //recalculate the latest Recurring Donation values
            rdRecord
                .setIsNew(newRDIds.contains(rd.Id))
                .revisePaidInstallments(paidInstallmentsByRDId.get(rd.Id))
                .reviseStatus(currentDate, scheduleService)
                .reviseNextDonationDate(scheduleService);

            //evaluate Opportunities
            if (rdRecord.isClosed()) {
                closedRDs.add(rd);

            } else {
                if (isNewOpportunityCandidate(rdRecord)) {
                    newOppRDs.add(rd);
                }

                if (hasOpenOpportunity(rdRecord)) {
                    updateOppRDs.add(rd);
                }
            }
            // TODO Handle Past Due Installment
        }

        toggleTriggerState(false);

        oppService
            .createOpportunities(newOppRDs)
            .updateOpportunities(updateOppRDs, rdIdsWhereScheduleChanged)
            .voidOpenOpportunities(closedRDs);

        handleOutdatedRecurringDonations(rdRecords);

        toggleTriggerState(true);

        dbService.processErrors();

        return this;
    }

    /**
     * @description Update Current/Next Year Value and other outstanding values on Recurring Donation records
     * on Recurring Donations when they are not in sync with existing Opps and projected installments.
     * @return RD2_OpportunityEvaluationService This service instance
     */
    private RD2_OpportunityEvaluationService handleOutdatedRecurringDonations(List<RD2_RecurringDonation> rdRecords) {
        //reset Recurring Donations so just created/updated Opps are retrieved
        //in order to calculate the Current/Next Year Values
        rds = null;

        List<npe03__Recurring_Donation__c> outdatedRDs = new List<npe03__Recurring_Donation__c>();
        for (RD2_RecurringDonation rdRecord : rdRecords) {
            //revise the Year Values only since other other values such as
            //the Next Donation Date, status for fixed-length RD, etc. were revised
            //when Opportunities were evaluated so no need to redo the work
            if (rdRecord
                .reviseYearValues(yearValueProcessor)
                .isOutdated()//checks all changed values on the RD
            ) {
                outdatedRDs.add(rdRecord.getUpdate());
            }
        }

        dbService.updateRecords(outdatedRDs);

        return this;
    }

    /**
     * @description Activate or deactive RD2 triggers
     * @param isActive Indicates if triggers are active
     * @return void
     */
    private void toggleTriggerState(Boolean isActive) {
        TDTM_ProcessControl.toggleTriggerState('npe03__Recurring_Donation__c', 'RD2_RecurringDonations_TDTM', isActive);
        TDTM_ProcessControl.toggleTriggerState('Opportunity', 'RD2_RecurringDonationsOpp_TDTM', isActive);
    }

    /**
     * @description Indicates if a Recurring Donation requires a new installment Opp to be created.
     * @param rd Recurring Donation SObject
     * @return Boolean
     */
    @TestVisible
    private Boolean isNewOpportunityCandidate(npe03__Recurring_Donation__c rd) {
        return isNewOpportunityCandidate(new RD2_RecurringDonation(rd));
    }

    /**
     * @description Indicates if the Recurring Donation require a new installment Opp to be created.
     * Schedules are inserted when the Recurring Donation is created and before Opp evaluation is done.
     * @param rd Recurring Donation record
     * @return Boolean
     */
    private  Boolean isNewOpportunityCandidate(RD2_RecurringDonation rd) {
        Boolean hasMandatoryConditions = (rd.isActive() || rd.isLapsed())
            && rd.hasNextDonationDate()
            && rd.hasSchedule()
            && (!RD2_ElevateIntegrationService.isIntegrationEnabled() || !rd.isElevateRecord());

        if (!hasMandatoryConditions) {
            return false;
        }

        if (isBatchContext) {
            return !rdSettings.isDisableAllInstallments;

        } else if (rd.isNew()) {
            return !rd.isFirstInstallmentDisabled() && rdSettings.isFirstInstallmentEnabled;

        } else if (!rd.hasCurrentOpenOpportunity(currentDate)) {
            return rdSettings.isNextInstallmentEnabled;
        }

        return false;
    }

    /**
     * @description Determines if the Recurring Donation open Opportunity should be updated
     * @param rd Recurring Donation record
     * @return Boolean
     */
    private Boolean hasOpenOpportunity(RD2_RecurringDonation rd) {
        return !isBatchContext
            && (rd.isActive() || rd.isLapsed())
            && rd.hasSchedule()
            && rd.hasOpenOpportunity();
    }

    /***
    * @description Retrieves Recurring Donation current and future closed and open Opportunities
    * required to calculate Next Donation Date
    * @param rdIds Recurring Donation Ids
    * @return Map<Id, List<Opportunity>>
    */
    public Map<Id, List<Opportunity>> getOpportunitiesByRDId(Set<Id> rdIds) { 
        Map<Id, List<Opportunity>> oppsByRDId = new Map<Id, List<Opportunity>>();

        Set<String> queryFields = new Set<String>{ 'Id' };
        queryFields.add(queryService.getOpportunitySubQuery());

        String soql = new UTIL_Query()
            .withFrom(npe03__Recurring_Donation__c.SObjectType)
            .withSelectFields(queryFields)
            .withWhere('Id IN :rdIds')
            .build();

        for (npe03__Recurring_Donation__c rd : Database.query(soql)) {
            oppsByRDId.put(rd.Id, rd.npe03__Donations__r);
        }
    
        return oppsByRDId;
    }

    /**
    * @description Determines which Recurring Donations are new
    * @param rdIds All Recurring Donation Ids to be evaluated
    * @return Set<Id> Ids of new Recurring Donations
    */
    private Set<Id> getNewRDIds(Set<Id> rdIds) {
        Set<Id> newRDIds = new Set<Id>();

        for (npe03__Recurring_Donation__c rd : [
            SELECT Id,
            (
                SELECT Id
                FROM npe03__Donations__r
                LIMIT 1
            )
            FROM npe03__Recurring_Donation__c
            WHERE Id IN :rdIds
        ]) {
            if (rd.npe03__Donations__r.isEmpty()) {
                newRDIds.add(rd.Id);
            }
        }

        return newRDIds;
    }

    /**
    * @description Returns number of paid installments for fixed-length RD records only
    * @return Map<Id, Integer> Number of Paid Installments mapped by the RD Id
    */
    private Map<Id, Integer> getPaidInstallmentsForFixedLength() {
        Map<Id, Integer> paidInstallmentsByRDId = new Map<Id, Integer>();
        for (npe03__Recurring_Donation__c rd : rds) {
            if (new RD2_RecurringDonation(rd).isFixedLength()) {
                paidInstallmentsByRDId.put(rd.Id, 0);
            }
        }

        if (paidInstallmentsByRDId.isEmpty()) {
            return paidInstallmentsByRDId;
        }

        for (AggregateResult result : [
            SELECT COUNT(Id) paidInstallments, npe03__Recurring_Donation__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :rdIds
            AND IsClosed = true
            AND IsWon = true
            GROUP BY npe03__Recurring_Donation__c
        ]) {
            paidInstallmentsByRDId.put((Id) result.get('npe03__Recurring_Donation__c'), (Integer) result.get('paidInstallments'));
        }

        return paidInstallmentsByRDId;
    }
}