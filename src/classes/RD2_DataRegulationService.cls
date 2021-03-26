/*
    Copyright (c) 2021 Salesforce.org
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
* @date 2021
* @group Recurring Donations
* @description Adjusts Enhanced Recurring Donations records so they can be processed
* in triggers, or data adjusted and validated outside of the trigger context.
*
*/
public inherited sharing class RD2_DataRegulationService {
    
    private Date currentDate {
        get {
            if (currentDate == null) {
                currentDate = RD2_ScheduleService.currentDate;
            }
            return currentDate;
        } set;
    }

    public RD2_DataRegulationService() {
    }

    public RD2_DataRegulationService(Date currentDate) {
        this.currentDate = currentDate;
    }

    /***
    * @description Sets fields on Recurring Donation records based on business logic
    * @param rds Recurring Donation records
    * @param oldRds Old version of the Recurring Donation records
    * @return void
    */
    public void adjust(List<npe03__Recurring_Donation__c> rds, List<npe03__Recurring_Donation__c> oldRds) {

        Map<Id, npe03__Recurring_Donation__c> oldRdsById = oldRds == null
            ? new Map<Id, npe03__Recurring_Donation__c>()
            : new Map<Id, npe03__Recurring_Donation__c>(oldRds);

        autoPopulateAccounts(rds);

        for (npe03__Recurring_Donation__c rd : rds) {
            adjustScheduleFields(rd);   
            adjustEndDateAndStatus(rd, oldRdsById.get(rd.Id));          
        }
    }

    /***
    * @description Auto-populates empty Account field on a Recurring Donation having Contact specified
    * @param rds Recurring Donation records
    * @return void
    */
    private void autoPopulateAccounts(List<npe03__Recurring_Donation__c> rds) {
        if (rds == null || rds.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        for (npe03__Recurring_Donation__c rd : rds) {
            if (rd.npe03__Organization__c == null && rd.npe03__Contact__c != null) {
                contactIds.add(rd.npe03__Contact__c);
            }
        }
        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contactById = new Map<Id, Contact>([
            SELECT Name, AccountId
            FROM Contact
            WHERE Id IN :contactIds
        ]);

        for (npe03__Recurring_Donation__c rd : rds) {
            if (rd.npe03__Organization__c == null
                && rd.npe03__Contact__c != null
                && contactById.containsKey(rd.npe03__Contact__c)
            ) {
                rd.npe03__Organization__c = contactById.get(rd.npe03__Contact__c).AccountId;
            }
        }
    }

    /***
    * @description Sets schedule fields
    * @param rd Recurring Donation record
    * @return void
    */
    private void adjustScheduleFields(npe03__Recurring_Donation__c rd) {
        if (rd.npe03__Installment_Period__c != RD2_Constants.INSTALLMENT_PERIOD_MONTHLY && rd.Day_of_Month__c != null) {
            rd.Day_of_Month__c = null;
        }

        //map the Day of Month value of "31" to the Last_Day value
        if (rd.Day_of_Month__c == '31') {
            rd.Day_of_Month__c = RD2_Constants.DAY_OF_MONTH_LAST_DAY;
        }

        //set the default installment frequency when value is not provided on the RD insert
        if (rd.InstallmentFrequency__c == null && rd.Id == null) {// Record Id is not available in the "before insert" context
            rd.InstallmentFrequency__c = RD2_Constants.DEFAULT_INSTALLMENT_FREQUENCY;
        }
    }
    
    /***
    * @description Evaluate End Date on a Recurring Donation record
    * If the RD is just Closed and the End Date is not provided, auto-populate the End Date to yesterday.
    * If the RD is just Closed but the End Date is in the future, revert the status to the value as it was before the update.
    * If the RD is reopened, clear out the End Date.
    * @param rd Recurring Donation record
    * @param oldRd Old version of the Recurring Donation record
    */
    private void adjustEndDateAndStatus(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {
        RD2_RecurringDonation rdRecord = new RD2_RecurringDonation(rd);

        if (rdRecord.isClosed() && rd.EndDate__c == null) {
            rd.EndDate__c = currentDate.addDays(-1);
        }

        if (oldRd != null) {
            if (!rdRecord.isClosed() && (new RD2_RecurringDonation(oldRd).isClosed())) {
                rd.EndDate__c = null;
            }

            if (
                rdRecord.isOpenEnded()
                && !rdRecord.isElevateRecord()
                && rdRecord.isClosed()
                && rd.EndDate__c != null
                && rd.EndDate__c > currentDate
            ) {
                rd.Status__c = oldRd.Status__c;
            }
        }
    }
    
    /***
    * @description Validates Recurring Donation records
    * @param rds Recurring Donation records
    * @param oldRds Old version of the Recurring Donation records
    * @return List<RD2_ValidationService.Notification>
    */
    public List<RD2_ValidationService.Notification> validate(List<npe03__Recurring_Donation__c> rds, List<npe03__Recurring_Donation__c> oldRds) {

        List<RD2_ValidationService.Notification> notifications = new List<RD2_ValidationService.Notification>();
        RD2_ValidationService validationService = new RD2_ValidationService(rds);

        Boolean isNew = oldRds == null || oldRds.isEmpty();

        if (isNew) {
            notifications = validationService.validate();

        } else {
            notifications = validationService
                .withOldRecurringDonations(oldRds)
                .validateOnChange();
        }

        return notifications;
    }
}
