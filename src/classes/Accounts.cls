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
* @description Domain class for Accounts in NPSP.
*/
public inherited sharing class Accounts extends fflib_SObjects {

    private Map<Id, Account> oldMap = new Map<Id, Account>();
    @TestVisible
    private HouseholdNamingService householdNamingService {
        get {
            if (householdNamingService == null) {
                householdNamingService = new HouseholdNamingService();
            }
            return householdNamingService;
        }
        set;
    }
    @TestVisible
    private HouseholdSettings settings {
        get {
            if (settings == null) {
                settings = new HouseholdSettings();
            }
            return settings;
        }
        set;
    }

    public Accounts(List<Account> records) {
        this(records, null);
    }

    public Accounts(List<Account> records, List<Account> oldlist) {
        super(records, Account.SObjectType);
        this.oldMap = oldlist == null ? new Map<Id, Account>() : new Map<Id, Account>
                (oldlist);
    }

    public void onBeforeInsert() {
        setAccountTypeAndIndividualFieldValues();
    }

    public void onBeforeUpdate() {
        setAccountTypeAndIndividualFieldValues();
        setSystemAccountTypeAndIndividualFieldValues();
        if (shouldSetCustomNamingFieldAndReplaceGreetings()) {
            setCustomNamingField();
            setNameAndGreetingsToReplacementText();
        }
    }

    public void onAfterUpdate() {
        if (settings.isAdvancedHouseholdNaming()) {
            renameHouseholdsNeedingNameUpdate();
        }
    }

    public void setAccountTypeAndIndividualFieldValues() {
        for (Account acc : (List<Account>) getRecords()) {
            if (needsTypeAndIndividualFieldsSet(acc)) {
                setTypeAndIndividualFields(acc);
            }
        }
    }

    public void setSystemAccountTypeAndIndividualFieldValues() {
        for (Account acc : (List<Account>) getRecords()) {
            if (shouldResetAccountTypeAndIndividualFields(acc)) {
                resetAccountTypeAndIndividualFields(acc);
            }
        }
    }

    /******************************************************************************************************
    * @description utility to return the recordtypeId for a new account, given the account model.
    * @return Id. if none is explicitly specified, returns null.
    */
    public static Id rtIdForNewAccount() {
        return rtIdForAccountModel(CAO_Constants.isHHAccountModel());
    }

    /*******************************************************************************************************
    * @description utility to return the recordtypeId for a new account, given the account model.
    * @param isHHAccountModel whether we are using the Household Account Model
    * @return Id. recordtype Id to use, or null if none is specified for the account model.
    */
    public static Id rtIdForAccountModel(Boolean isHHAccountModel) {
        npe01__Contacts_And_Orgs_Settings__c contactsSettings =
                UTIL_CustomSettingsFacade.getContactsSettings();
        // check if recordtypes are enabled, and if it matches the existing setting
        // we go thru describe to validate that it is a valid recordType ID.
        Id individualRecordTypeId = isHHAccountModel ? contactsSettings.npe01__HH_Account_RecordTypeID__c : contactsSettings.npe01__One_to_One_RecordTypeID__c;
        if (individualRecordTypeId != null) {
            Schema.RecordTypeInfo recordTypeInfo = null;
            Schema.DescribeSObjectResult describeResult = Account.SObjectType.getDescribe();
            Map<Id, Schema.RecordTypeInfo> recordTypeInfoById = describeResult.getRecordTypeInfosById();
            recordTypeInfo = recordTypeInfoById.get(individualRecordTypeId);
            return recordTypeInfo == null
                    ? null
                    : recordTypeInfo.getRecordTypeId();
        }

        return null;
    }

    private void setNameAndGreetingsToReplacementText() {
        householdNamingService.setNameAndGreetingsToReplacementText(householdAccounts());
    }

    private Boolean shouldSetCustomNamingFieldAndReplaceGreetings() {
        return !isHouseholdTriggerContext() && settings.isAdvancedHouseholdNaming();
    }

    private void setCustomNamingField() {
        householdNamingService.setCustomNamingField(householdAccounts(), oldMap);
    }

    private void renameHouseholdsNeedingNameUpdate() {
        HouseholdAccounts.renameHHAccounts(getHouseholdsNeedingNameUpdate());
    }

    private List<Id> getHouseholdsNeedingNameUpdate() {
        return householdNamingService.getHouseholdsNeedingNameUpdates(
                householdAccounts(), oldMap
        );
    }

    private void resetAccountTypeAndIndividualFields(Account acc) {
        acc.npe01__SYSTEMIsIndividual__c = false;
        acc.npe01__SYSTEM_AccountType__c = null;
    }

    private Boolean shouldResetAccountTypeAndIndividualFields(Account acc) {
        return isRecordTypeIdChanged(acc)
                && !isHouseholdAccount(acc)
                && !isOneToOneAccount(acc)
                && !isBucketAccount(acc);
    }

    private Boolean isRecordTypeIdChanged(Account acc) {
        return acc.RecordTypeId != oldVersionOf(acc).RecordTypeId;
    }

    private void setTypeAndIndividualFields(Account acc) {
        if (isHouseholdAccount(acc)) {
            setTypeAndIndividualFieldsForHouseholdAccount(acc);
        } else if (isOneToOneAccount(acc)) {
            setTypeAndIndividualFieldsForOneToOneAccount(acc);
        }
    }

    private void setTypeAndIndividualFieldsForOneToOneAccount(Account acc) {
        acc.npe01__SYSTEM_AccountType__c = CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE;
        acc.npe01__SYSTEMIsIndividual__c = true;
    }

    private void setTypeAndIndividualFieldsForHouseholdAccount(Account acc) {
        acc.npe01__SYSTEM_AccountType__c = CAO_Constants.HH_ACCOUNT_TYPE;
        acc.Type = CAO_Constants.HH_TYPE;
        acc.npe01__SYSTEMIsIndividual__c = true;
    }

    private Boolean needsTypeAndIndividualFieldsSet(Account acc) {
        return isMissingAccountType(acc) || isNotIndividualAccount(acc);
    }

    private Boolean isNotIndividualAccount(Account acc) {
        return acc.npe01__SYSTEMIsIndividual__c != true;
    }

    private Boolean isMissingAccountType(Account acc) {
        return acc.npe01__SYSTEM_AccountType__c == null;
    }

    private List<Account> householdAccounts() {
        return (List<Account>) selectByFieldValue(
                Account.npe01__SYSTEM_AccountType__c,
                CAO_Constants.HH_ACCOUNT_TYPE)
                .getRecords();
    }

    private Account oldVersionOf(Account acc) {
        return oldMap.get(acc.Id);
    }

    private Boolean isOneToOneAccount(Account acc) {
        return acc.RecordTypeId == rtIdForAccountModel(false)
                && acc.RecordTypeId != null;
    }

    private Boolean isHouseholdAccount(Account acc) {
        return acc.RecordTypeId == rtIdForAccountModel(true)
                && acc.RecordTypeId != null;
    }

    private Boolean isBucketAccount(Account acc) {
        return (CAO_Constants.isBucketModel() && acc.Name == CAO_Constants.BUCKET_ACCOUNT_NAME);
    }

    private Boolean isHouseholdTriggerContext() {
        return TDTM_ProcessControl.isRecursive(TDTM_ProcessControl.flag.HH);
    }

}