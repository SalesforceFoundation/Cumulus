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
* @description Recurring Donations Validation Service
*
*/
public with sharing class RD2_ValidationService {

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
    * @description New or updated Recurring Donation records
    */
    private List<npe03__Recurring_Donation__c> rds = new List<npe03__Recurring_Donation__c>();

    /**
    * @description Old Recurring Donation records available in the update/delete dml operation.
    * The list should have the same size and records the same index as the new/updated "rds" list.
    */
    private List<npe03__Recurring_Donation__c> oldRds = new List<npe03__Recurring_Donation__c>();

    /**
    * @description Accounts on provided Recurring Donations
    */
    private Map<Id, Account> accountById {
        get {
            if (accountById == null) {
                accountById = getAccounts();
            }
            return accountById;
        } set;
    }

    /**
    * @description Contacts on provided Recurring Donations
    */
    private Map<Id, Contact> contactById {
        get {
            if (contactById == null) {
                Set<Id> contactIds = UTIL_SObject.extractId(
                    rds, npe03__Recurring_Donation__c.npe03__Contact__c
                );

                contactById = new Map<Id, Contact>([
                    SELECT Name, AccountId
                    FROM Contact
                    WHERE Id IN :contactIds
                ]);
            }
            return contactById;
        }
        set;
    }

    /***
    * @descripton Recurring Donations that do not have any Closed Won/Lost Opportunity assigned.
    * These records can have donor information modified
    */
    private Set<Id> noClosedOppRDIds {
        get {
            if (noClosedOppRDIds == null) {
                noClosedOppRDIds = getNoClosedOppRDIds();
            }
            return noClosedOppRDIds;
        }
        set;
    }

    /***
    * @descripton Recurring Donations to its most recent closed won opportunity's close date.
    */
    private Map<Id, Date> closeWonDateByRdId {
        get {
            if (closeWonDateByRdId == null) {
                closeWonDateByRdId = getMostRecentCloseWonDateByRdId();
            }
            return closeWonDateByRdId;
        }
        set;
    }

    /***
    * @descripton Elevate integration service
    */
    private RD2_ElevateIntegrationService elevateService {
        get {
            if (elevateService == null) {
                elevateService = new RD2_ElevateIntegrationService();
            }
            return elevateService;
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

    /**
    * @description Constructor for the RD2_ValidationService class
    * @param rds New rds that will be validated
    */
    public RD2_ValidationService(List<npe03__Recurring_Donation__c> rds) {
        this.rds = rds;
    }

    /**
    * @description Constructor for the RD2_ValidationService class for Update context
    * @param rds New rds that will be validated
    * @param oldRds old rds which are available in the database, the size and Id should match rds
    */
    public RD2_ValidationService(List<npe03__Recurring_Donation__c> rds, List<npe03__Recurring_Donation__c> oldRds) {
        this.rds = rds;
        this.oldRds = oldRds;
    }

    /***
    * @description Validates Recurring Donation records
    * @return List<RD2_ValidationService.ErrorRecord>
    */
    public List<RD2_ValidationService.ErrorRecord> validate() {
        List<RD2_ValidationService.ErrorRecord> errorRds = new List<RD2_ValidationService.ErrorRecord>();

        Boolean isNew = oldRds == null || oldRds.isEmpty();

        if (isNew) {
            errorRds = validateOnInsert();

        } else {
            errorRds = validateOnChange();
        }

        return errorRds;
    }

    /**
    * @description Validate RD data on insert
    * @return List<Notification>
    */
    public List<ErrorRecord> validateOnInsert() {
        List<ErrorRecord> errorRecords = new List<ErrorRecord>();

        for (npe03__Recurring_Donation__c rd : rds) {
            ErrorRecord errorCollection = new ErrorRecord(rd);

            validateActiveRecurringDonation(rd, errorCollection);
            validateInstallmentFrequency(rd, errorCollection);
            validateDonor(rd, accountById.get(rd.npe03__Organization__c), errorCollection);
            validateStatus(rd, errorCollection);
            validateRD2MetadataDeployed(rd, errorCollection);

            if (errorCollection.hasError()) {
                errorRecords.add(errorCollection);
            }
        }

        return errorRecords;
    }

    /**
    * @description Validates Recurring Donation on update DML
    * @return List<Notification>
    */
    public List<ErrorRecord> validateOnChange() {
        List<ErrorRecord> errorRecords = new List<ErrorRecord>();

        for (Integer i = 0; i < rds.size(); i++) {
            npe03__Recurring_Donation__c rd = rds[i];
            npe03__Recurring_Donation__c oldRd = oldRds[i];
            ErrorRecord errorCollection = new ErrorRecord(rd);

            if (elevateService.isElevateRecordReactivated(rd, oldRd)) {
                errorCollection.addError(System.Label.RD2_ElevateRDClosedStatusCannotBeChanged);
            }

            if (!elevateService.hasUpdatePermissions(rd, oldRd)) {
                errorCollection.addError(System.Label.RD2_ElevatePermissionRequired);
            }

            validateActiveRecurringDonation(rd, errorCollection);
            validateInstallmentFrequency(rd, errorCollection);
            validateCurrencyChange(rd, oldRd, errorCollection);
            validateRecurringDonationEndDate(rd, errorCollection);
            validateStatus(rd, errorCollection);

            Boolean isValid = validateDonorChange(rd, oldRd, errorCollection);
            if (isValid) {
                validateDonor(rd, accountById.get(rd.npe03__Organization__c), errorCollection);
            }

            validateRD2MetadataDeployed(rd, errorCollection);

            if (errorCollection.hasError()) {
                errorRecords.add(errorCollection);
            }
        }

        return errorRecords;
    }

    /**
    * @description Validates if Enhanced Recurring Donation Paused Status is Active
    * @return Boolean 
    */
    public static Boolean isStatusPausedActive() {
        return UTIL_Describe.isValidPicklistOption(
            'npe03__Recurring_Donation__c',
            String.valueOf(npe03__Recurring_Donation__c.Status__c),
            RD2_Constants.STATUS_PAUSED
        );
    }

    /***
    * @description Validates Enhanced Recurring Donations metadata has been deployed
    * @param rd The Recurring Donation to validate
    * @return void
    */
    private void validateRD2MetadataDeployed(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        if (!RD2_EnablementService.isMetadataDeployed) {
            errorCollection.addError(System.Label.RD2_EnablementIncomplete);
        }
    }

    /***
    * @description Validates data on Recurring Donation is valid
    * @param rd The Recurring Donation to validate
    * @return void
    */
    private void validateActiveRecurringDonation(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        if (new RD2_RecurringDonation(rd).isClosed()) {
            return;
        }

        if (rd.npe03__Amount__c == null || rd.npe03__Amount__c == 0 || rd.npe03__Amount__c < 0) {
            errorCollection.addError(System.Label.RD2_AmountMustBeValid);
        }

        if (!RD2_Constants.allInstallmentPeriods.contains(rd.npe03__Installment_Period__c)) {
            errorCollection.addError(
                String.format(
                    System.Label.RD2_InstallmentPeriodMustBeValid,
                    new String[]{ rd.npe03__Installment_Period__c }
                )
            );
        }

        validateDayOfMonth(rd, errorCollection);

        validateFixedLength(rd, errorCollection);
    }

    /***
     * @description Validate Installment Frequency to be in the range
     * @param rd Recurring Donation record to validate
     */
    private void validateInstallmentFrequency(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        if (!(new RD2_RecurringDonation(rd)).isValidInstallmentFrequency()) {
            errorCollection.addError(System.Label.RD2_InstallmentFrequencyMustBeValid);
        }
    }

    /***
    * @description Validates missing account or contact data on Recurring Donation
    * @param rd The Recurring Donation to validate
    * @param acct The associated account for the Recurring Donation
    * @return void
    */
    private void validateDonor(npe03__Recurring_Donation__c rd, Account acct, ErrorRecord errorCollection) {
        //either Account or Contact must be specified
        if (rd.npe03__Organization__c == null && rd.npe03__Contact__c == null) {
            errorCollection.addError(System.Label.RD_DonorIsRequired);
            return;
        }

        //no further check is required if the Contact is specified only or the Account is an Organization
        if (acct == null || acct.npe01__SYSTEMIsIndividual__c != true) {
            return;
        }

        if (rd.npe03__Contact__c == null) {
            errorCollection.addError(System.Label.RD_ContactMustBelongToAccount);
        } else if (!UTIL_SObject.extractIds(acct.Contacts).contains(rd.npe03__Contact__c)) {
            errorCollection.addError(System.Label.RD_ContactMustBelongToAccount);
        }
    }

    /**
    * @description Validate when contact or account change is permitted on update of the Recurring Donation
    * @param rd The Recurring Donation to validate
    * @param oldRd The previous version of the Recurring Donation
    * @return Boolean True when the validation pass, otherwise, false
    */
    private Boolean validateDonorChange(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd, ErrorRecord errorCollection) {
        if (rd.npe03__Organization__c == oldRd.npe03__Organization__c
            && rd.npe03__Contact__c == oldRd.npe03__Contact__c
        ) {
            return true;
        }

        if (noClosedOppRDIds.contains(rd.Id)
            || isOrganizationChange(accountById.get(rd.npe03__Organization__c), accountById.get(oldRd.npe03__Organization__c))
            || isAccountAutoPopulatedOnChange(rd, oldRd)
        ) {
            return true;
        }

        errorCollection.addError(System.Label.RD2_ContactChangeIsRestricted);
        return false;
    }

    /**
    * @description Validate the currency change on the Recurring Donation
    * that is applicable when the multi-currency is enabled and
    * the RD has at least one Closed Won/Lost Opportunity.
    * @param rd The Recurring Donation to validate
    * @param oldRd The previous version of the Recurring Donation
    * @return void
    */
    private void validateCurrencyChange(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd, ErrorRecord errorCollection) {
        if (!isMultiCurrencyEnabled) {
            return;
        }

        //Prevent the RD update if the currency has changed and the record has a closed Opportunity
        if ((String) rd.get(CURRENCY_ISO_CODE_FIELD) != (String) oldRd.get(CURRENCY_ISO_CODE_FIELD)
            && !noClosedOppRDIds.contains(rd.Id)
        ) {
            errorCollection.addError(System.Label.RD2_CurrencyChangeIsRestrictedOnRD);
        }
    }

    /**
    * @description Validate the End Date on the Recurring Donation
    * @param rd The Recurring Donation to validate
    * @return void
    */
    private void validateRecurringDonationEndDate(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        if (rd.EndDate__c == null) {
            return;
        }

        RD2_RecurringDonation rdRecord = new RD2_RecurringDonation(rd);

        if (rdRecord.isElevateRecord()
            && rdRecord.isClosed()
            && rd.EndDate__c > currentDate
        ) {
            errorCollection.addError(System.Label.RD2_EndDateElevateCannotBeInFuture);
        }

        if (rdRecord.isFixedLength()
            && rdRecord.isClosed()
            && rd.EndDate__c > currentDate
        ) {
            errorCollection.addError(System.Label.RD2_EndDateMustBeValidForFixedLength); 
        }

        Date mostRecentCloseWonDate = closeWonDateByRdId.get(rd.Id);
        if (mostRecentCloseWonDate == null) {
            return;
        }

        if (rd.EndDate__c < mostRecentCloseWonDate) {
            errorCollection.addError(System.Label.RD2_EndDateMustBeLaterThanCloseWonOpp);
        }

    }

    /**
    * @description Validates RD status is mapped to a valid state
    * @param rd The Recurring Donation to validate
    * @return void
    */
    @TestVisible
    private void validateStatus(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        if (String.isBlank((new RD2_RecurringDonation(rd)).getState())) {
            errorCollection.addError(
                String.format(
                    System.Label.RD2_StatusMustBeMapped + ' ' + System.Label.RD2_StatusMustBeMappedSolution,
                    new String[]{rd.Status__c}
                )
            );
        }
    }

    /***
    * @description Return true when both new and old account on the RD are organization accounts.
    * @param newAcct Account on the DML new RD
    * @param oldAcct Acocunt on the DML old RD
    * @return Boolean True when both new and old account are organization accounts
    */
    private Boolean isOrganizationChange(Account newAcct, Account oldAcct) {
        return
            newAcct != null
            && oldAcct != null
            && newAcct.npe01__SYSTEMIsIndividual__c == false
            && oldAcct.npe01__SYSTEMIsIndividual__c == false;
    }

    /***
    * @description Returns true when Account on RD is changed from null to the Contact's Account
    * and the Contact on RD is not changed
    * @param new Updated Recurring Donation record
    * @param old Recurring Donation record containing old values
    * @return Boolean
    */
    private Boolean isAccountAutoPopulatedOnChange(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {

        if (rd.npe03__Contact__c == null //The Contact is not specified
            || rd.npe03__Contact__c != oldRd.npe03__Contact__c //The Contact is changed on update
            || oldRd.npe03__Organization__c != null //The Account existed previously
        ) {
            return false;
        }

        Contact rdContact = contactById.get(rd.npe03__Contact__c);

        return rdContact != null
            && rd.npe03__Organization__c == rdContact.AccountId;
    }

    /***
    * @description Validates Day of Month on Recurring Donation
    * @param rd The Recurring Donation to validate
    * @return void
    */
    private void validateDayOfMonth(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        if (rd.npe03__Installment_Period__c != RD2_Constants.INSTALLMENT_PERIOD_MONTHLY) {
            return;
        }

        if (String.IsBlank(rd.Day_of_Month__c)) {
            errorCollection.addError(System.Label.RD2_DayOfMonthIsRequiredForMonthlyInstallment);
            return;
        }

        if (rd.Day_of_Month__c == RD2_Constants.DAY_OF_MONTH_LAST_DAY) {
            return;
        }

        Integer dayOfMonth;
        try {
            dayOfMonth = Integer.valueOf(rd.Day_of_Month__c);
        } catch (Exception e) {
        }

        Boolean isValid = dayOfMonth > 0 && dayOfMonth < 31;

        if (!isValid) {
            errorCollection.addError(
                String.format(
                    System.Label.RD2_DayOfMonthMustBeValid,
                    new String[]{ rd.Day_of_Month__c }
                )
            );
        }
    }

    /**
     * @description Validate the NumberOfPlannedInstallments field value for Fixed Length and
     * Open Recurring Donations
     * @param rd The recurring donation to validate
     */
    private void validateFixedLength(npe03__Recurring_Donation__c rd, ErrorRecord errorCollection) {
        RD2_RecurringDonation rdRecord = new RD2_RecurringDonation(rd);
        
        if (rdRecord.isOpenEnded()
            && rd.npe03__Installments__c > 1
        ) {
            errorCollection.addError(System.Label.RD2_NumberInstallmentsNotAllowedWhenOpen);
        }

        if (!rdRecord.isFixedLength()) {
            return;
        }

        if (rd.npe03__Installments__c == null || rd.npe03__Installments__c < 0) {
            errorCollection.addError(System.Label.RD2_NumberInstallmentsRequiredWhenFixed);

        } else if (rd.npe03__Total_Paid_Installments__c > 0
            && rd.npe03__Installments__c < rd.npe03__Total_Paid_Installments__c
        ) {
            errorCollection.addError(System.Label.RD2_NumberInstallmentsCannotBeLessThanPaid);
        }
    }

    /**
    * @description Get account map on the RDs from both new and old recurring donation context
    * @return Map<Id, Account>
    */
    private Map<Id, Account> getAccounts() {
        Set<Id> accountIds = UTIL_SObject.extractId(rds, npe03__Recurring_Donation__c.npe03__Organization__c);
        Set<Id> contactIds = UTIL_SObject.extractId(rds, npe03__Recurring_Donation__c.npe03__Contact__c);

        accountIds.addAll(UTIL_SObject.extractId(oldRds, npe03__Recurring_Donation__c.npe03__Organization__c));
        contactIds.addAll(UTIL_SObject.extractId(oldRds, npe03__Recurring_Donation__c.npe03__Contact__c));

        accountIds.remove(null);
        contactIds.remove(null);

        return new Map<Id, Account>([
            SELECT Id, npe01__SYSTEMIsIndividual__c,
            (
                SELECT Id
                FROM Contacts
                WHERE Id IN :contactIds
            )
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    /***
    * @description Get Recurring Donation Ids that do not have any Closed Won/Lost Opportunity
    * @return Set<Id>
    */
    private Set<Id> getNoClosedOppRDIds() {
        Set<Id> rdIds = new Set<Id>();

        for (npe03__Recurring_Donation__c rd : [
            SELECT (
                SELECT Id
                FROM npe03__Donations__r
                WHERE IsClosed = true
                LIMIT 1
            )
            FROM npe03__Recurring_Donation__c
            WHERE Id IN : rds
        ]) {
            if (rd.npe03__Donations__r.isEmpty()) {
                rdIds.add(rd.Id);
            }
        }

        return rdIds;
    }

    /***
    * @description Get each Recurring Donation's most recent Closed Won opp close date group by Id
    * @return map<Id, Date>
    */
    private map<Id, Date> getMostRecentCloseWonDateByRdId() {
        Map<Id, Date> closeWonDateByRdId = new Map<Id, Date>();
        for (npe03__Recurring_Donation__c rd : [
            SELECT (
                SELECT CloseDate
                FROM npe03__Donations__r
                WHERE IsClosed = true
                    AND IsWon = true
                ORDER BY CloseDate DESC
                LIMIT 1
            )
            FROM npe03__Recurring_Donation__c
            WHERE Id IN : rds
        ]) {
            if (!rd.npe03__Donations__r.isEmpty()) {
                closeWonDateByRdId.put(rd.Id, rd.npe03__Donations__r[0].CloseDate);
            }
        }

        return closeWonDateByRdId;
    }

    /**
    * @description ErrorRecord class with all the validation errors related to the Recurring Donation
    */
    public class ErrorRecord {
        npe03__Recurring_Donation__c recurringDonation;
        List<String> errors = new List<String>();

        /**
        * @descripion Construct the Error Record class
        * @param rd The Recurring Donation that will be tracked 
        */
        public ErrorRecord(npe03__Recurring_Donation__c rd) {
            this.recurringDonation = rd;
        }

        /**
        * @description Append a single error to the collection
        * @param error The specific error message that will be added
        * @return ErrorRecord
        */
        public ErrorRecord addError(String error) {
            if (String.isNotBlank(error)) {
                this.errors.add(error);
            }

            return this;
        }

        /**
        * @description Append a colleciton of errors to the collection
        * @param errors The specific error messages that will be added
        * @return ErrorRecord
        */
        public ErrorRecord addErrors(List<String> errors) {
            if (errors != null) {
                this.errors?.addAll(errors);
            }

            return this;
        }

        /**
        * @description Returns Recurring Donation record
        * @return npe03__Recurring_Donation__c
        */
        public npe03__Recurring_Donation__c getRecord() {
            return this.recurringDonation;
        }

        /**
        * @description Check if the current Recurring Donation has any validation error
        */
        public Boolean hasError() {
            return !this.errors.isEmpty();
        }

        /***
        * @description Returns errors
        * @return List<String>
        */
        public List<String> getErrors() {
            return this.errors?.clone();
        }

        /***
        * @description Returns the first added error
        * @return String
        */
        public String getFirstError() {
            return this.errors.isEmpty()
                ? null
                : this.errors[0];
        }
    }

}