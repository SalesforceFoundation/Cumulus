/*
    Copyright (c) 2009, Salesforce.org
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
* @date 2015
* @description Tests Contact Merge when done through the API
* @group ContactMerge
*/
@IsTest
private with sharing class CON_ContactMergeTDTM_TEST {
    private static final Integer MOCK_IDS_SIZE = 5;
    private static final Integer ADDR_OVERRIDE_INDEX = 3;
    private static final String DEFAULT_ACCT_TYPE = CAO_Constants.HH_ACCOUNT_PROCESSOR;
    private static List<Account> existingAccounts;
    private static List<Contact> existingContacts;
    private static List<Opportunity> existingOpps;
    private static Account organizationAcct;

    /***************************************************************************************************************
     * @description Create household account records with 2 contacts per account and 1 opp per contact as well
     * as one organization type account. Also, sets a contact record with an override.
     */
    @TestSetup
    private static void createRecordData() {
        ADDR_Addresses_TEST.createTestData(3, 2);
        Contact overrideContact = ADDR_Addresses_TEST.testContacts[ADDR_OVERRIDE_INDEX];

        overrideContact.MailingStreet = '1007 Mountain Drive';
        overrideContact.MailingCity = 'Gotham';
        overrideContact.MailingState = 'New York';
        overrideContact.is_Address_Override__c = true;
        update overrideContact;

        createOpps(getContacts());

        insert new Account(Name = 'TDTM Merge TEST Account');
    }

    /*******************************************************************************************************
    * @description merge two Contacts in the same Household Account.
    * verify: 
    *   the account's names and greetings are updated.
    *   Soft Credits are recalculated.
    *   Opportunity Rollups on Contact are recalculated
    *   No Duplicate and Primary Affiliations
    */
    @IsTest
    private static void mergeContactsSameHHAccount() {
        setRecordData();

        Account household = existingAccounts[0];
        Contact masterContact = existingContacts[1];
        Contact oldContact = existingContacts[0];
        List<Contact> contacts = new List<Contact>{ masterContact, oldContact };
        System.assertEquals(household.Id, masterContact.AccountId, 'Expected the master contact to belong to the first household.');
        System.assertEquals(household.Id, oldContact.AccountId, 'Expected the old contact to belong to the first household.');

        enableAffiliationCreationSetting();
        updatePrimaryAffiliation(contacts, organizationAcct.Id);

        Test.startTest();
        merge masterContact oldContact;
        Test.stopTest();

        List<Account> accounts = getAccounts();
        contacts = getContacts();
        System.assertEquals(existingAccounts.size(), accounts.size(), 'All accounts should still exist.');
        System.assertEquals(existingContacts.size() - 1, contacts.size(), 'One contact should no longer exist.');
        System.assertEquals(masterContact.Id, contacts[0].Id, 'The first contact record should be the master contact record.');
        System.assertNotEquals(oldContact.Id, contacts[1].Id, 'The second contact record should no longer be the old contact record.');
        System.assert(!accounts[0].npo02__Formal_Greeting__c.contains(oldContact.FirstName), 'The account should not contain the old contacts name.');
        System.assert(accounts[0].npo02__Formal_Greeting__c.contains(masterContact.FirstName), 'The account should contain the master contacts name.');

        List<Opportunity> opps = getOpps(accounts[0].Id);
        System.assertEquals(2, opps.size(), 'Expected both opportunities to be related to the account.');
        System.assertEquals(2, accounts[0].npo02__NumberOfClosedOpps__c, 'The rollup process should rollup the number of opps to the account.');
        System.assertEquals(2, contacts[0].npo02__NumberOfClosedOpps__c, 'The rollup process should rollup the number of opps to the contact.');

        List<OpportunityContactRole> roles = [SELECT Id, ContactId, IsPrimary FROM OpportunityContactRole WHERE OpportunityId IN :opps];
        System.assertEquals(opps.size(), roles.size(), 'A role for each opp should still exist.');

        for (OpportunityContactRole role : roles) {
            System.assertEquals(masterContact.Id, role.ContactId, 'All roles should now be associated with the master contact.');
            System.assert(role.IsPrimary, 'All roles should be primary roles.');
        }

        List<npe5__Affiliation__c> affiliations = [SELECT npe5__Primary__c FROM npe5__Affiliation__c];
        System.assertEquals(1, affiliations.size(), 'There should only be one affiliation record remaining.');
        System.assert(affiliations[0].npe5__Primary__c, 'The affiliation should be marked primary.');
    }

    /*******************************************************************************************************
    * @description merge two Contacts from different Household Accounts.  
    * verify: 
    *   the account's names and greetings are updated.
    *   Opps are moved to the Winning Contact's account
    *   Soft Credits are recalculated.
    *   Opp Rollups are recalculated.
    *   Addresses are dealt with
    *   No Duplicate and Primary Affiliations
    */
    @IsTest
    private static void mergeContactsDifferentHHAccount() {
        setRecordData();

        List<Account> households = new List<Account>{ existingAccounts[0], existingAccounts[1] };
        Contact masterContact = existingContacts[1];
        Contact oldContact = existingContacts[ADDR_OVERRIDE_INDEX];
        List<Contact> contacts = new List<Contact>{ masterContact, oldContact };
        System.assertEquals(households[0].Id, masterContact.AccountId, 'Expected the master contact to belong to the first household.');
        System.assertEquals(households[1].Id, oldContact.AccountId, 'Expected the old contact to belong to the second household.');

        enableAffiliationCreationSetting();
        updatePrimaryAffiliation(contacts, organizationAcct.Id);

        Test.startTest();
        merge masterContact oldContact;
        Test.stopTest();

        List<Account> accounts = getAccounts();
        contacts = getContacts();
        System.assertEquals(existingAccounts.size(), accounts.size(), 'All accounts should still exist.');
        System.assertEquals(existingContacts.size() - 1, contacts.size(), 'One contact should no longer exist.');
        System.assertEquals(masterContact.Id, contacts[1].Id, 'The second contact record should be the master contact record.');
        System.assertNotEquals(oldContact.Id, contacts[3].Id, 'The fourth contact record should no longer be the old contact record.');
        masterContact = contacts[1];

        System.assertEquals(2, [SELECT count() FROM Contact WHERE AccountId = :masterContact.AccountId], 'The master contacts account should still have two related contacts.');
        System.assertEquals(1, [SELECT count() FROM Contact WHERE AccountId = :oldContact.AccountId], 'The old contacts account should have one related contact.');
        System.assert(accounts[0].npo02__Formal_Greeting__c.contains(masterContact.FirstName), 'The master contacts account should contain the master contacts first name.');
        System.assert(!accounts[0].npo02__Formal_Greeting__c.contains(oldContact.FirstName), 'The master contacts account should not contain the old contacts first name.');
        System.assert(!accounts[1].npo02__Formal_Greeting__c.contains(oldContact.FirstName), 'The old contacts account should not contain the old contacts first name.');
        System.assert(!accounts[1].npo02__Formal_Greeting__c.contains(masterContact.FirstName), 'The old contacts account should not contain the master contacts first name.');

        List<Opportunity> newAcctOpps = getOpps(masterContact.AccountId);
        List<Opportunity> oldAcctOpps = getOpps(oldContact.AccountId);

        System.assertEquals(3, newAcctOpps.size(), 'Expected the opps from the merged contacts to be related to the master contacts account.');
        System.assertEquals(1, oldAcctOpps.size(), 'Expected the opp from the old contacts account for the remaining contact to still be related to the account.');
        System.assertEquals(3, accounts[0].npo02__NumberOfClosedOpps__c, 'The rollups should have recalculated for the new account.');
        System.assertEquals(1, accounts[1].npo02__NumberOfClosedOpps__c, 'The rollups should have recalculated for the old account.');
        System.assertEquals(2, masterContact.npo02__NumberOfClosedOpps__c, 'The rollups should have recalculated for the master contact.');

        List<OpportunityContactRole> roles = [SELECT Id, ContactId, IsPrimary FROM OpportunityContactRole WHERE OpportunityId IN :newAcctOpps];
        System.assertEquals(newAcctOpps.size() * 2, roles.size(), 'Expected a role for both contacts related to the accounts opps.');

        Integer countMasterId = 0, countPrimary = 0;
        for (OpportunityContactRole role : roles) {
            countMasterId += role.ContactId == masterContact.Id ? 1 : 0;
            countPrimary += role.IsPrimary ? 1 : 0;
        }
        System.assertEquals(newAcctOpps.size(), countMasterId, 'The master contact should be associated with each opp.');
        System.assertEquals(newAcctOpps.size(), countPrimary, 'There should be a primary contact associated with each opp.');

        roles = [SELECT Id, ContactId, IsPrimary FROM OpportunityContactRole WHERE OpportunityId IN :oldAcctOpps];
        System.assertEquals(oldAcctOpps.size(), roles.size(), 'A role for each opp should still exist.');
        System.assert(roles[0].IsPrimary, 'The role should be a primary role.');

        System.assert(!masterContact.is_Address_Override__c, 'The override should not be set on the master contact record.');
        System.assertEquals(masterContact.MailingStreet, accounts[0].BillingStreet, 'The contacts mailing address should match the accounts mailing address.');
        System.assertEquals(
            masterContact.AccountId,
            [SELECT Household_Account__c FROM Address__c WHERE Id = :masterContact.Current_Address__c].Household_Account__c,
            'The address should be related to the master contacts account.');

        List<npe5__Affiliation__c> affiliations = [SELECT npe5__Primary__c FROM npe5__Affiliation__c];
        System.assertEquals(1, affiliations.size(), 'There should only be one affiliation record remaining.');
        System.assert(affiliations[0].npe5__Primary__c, 'The affiliation should be marked primary.');
    }

    /*******************************************************************************************************
    * @description merge three Contacts from different Household Accounts with many affiliations.  
    * verify: 
    *   No Duplicate and Primary Affiliations
    */
    @IsTest
    private static void mergeContactsDifferentHHAccountManyAffl() {
        setRecordData();

        Contact masterContact = existingContacts[1];
        Contact oldContact1 = existingContacts[3];
        Contact oldContact2 = existingContacts[4];
        List<Contact> contacts = new List<Contact>{ masterContact, oldContact1, oldContact2 };
        System.assertEquals(existingAccounts[0].Id, masterContact.AccountId, 'Expected the master contact to belong to the first household.');
        System.assertEquals(existingAccounts[1].Id, oldContact1.AccountId, 'Expected the first old contact to belong to the second household.');
        System.assertEquals(existingAccounts[2].Id, oldContact2.AccountId, 'Expected the second old contact to belong to the third household.');

        enableAffiliationCreationSetting();
        updatePrimaryAffiliation(contacts, organizationAcct.Id);
        
        // create additional affiliations
        List<npe5__Affiliation__c> affiliations = new List<npe5__Affiliation__c>();
        affiliations.add(new npe5__Affiliation__c(npe5__Contact__c = masterContact.Id, npe5__Organization__c = organizationAcct.Id, npe5__Status__c = 'inactive'));
        affiliations.add(new npe5__Affiliation__c(npe5__Contact__c = oldContact1.Id, npe5__Organization__c = organizationAcct.Id, npe5__Status__c = 'inactive'));
        affiliations.add(new npe5__Affiliation__c(npe5__Contact__c = oldContact2.Id, npe5__Organization__c = organizationAcct.Id, npe5__Status__c = 'inactive'));
        affiliations.add(new npe5__Affiliation__c(npe5__Contact__c = oldContact2.Id, npe5__Organization__c = organizationAcct.Id, npe5__Status__c = 'random'));
        insert affiliations;
        System.assertEquals(7, [SELECT count() FROM npe5__Affiliation__c], 'The number of total affiliation records is not as expected.');

        Test.startTest();
        merge masterContact new List<Contact>{oldContact1, oldContact2};
        Test.stopTest();

        contacts = getContacts();
        System.assertEquals(masterContact.Id, contacts[1].Id, 'The second contact record should be the master contact record.');
        masterContact = contacts[1];

        System.assertEquals(existingContacts.size() - 2, contacts.size(), 'There should be 2 less contacts in the system.');
        System.assertEquals(2, [SELECT count() FROM Contact WHERE AccountId = :masterContact.AccountId], 'The master contacts account should still have two related contacts.');
        System.assertEquals(1, [SELECT count() FROM Contact WHERE AccountId = :oldContact1.AccountId], 'The first old contacts account should have one related contact.');
        System.assertEquals(1, [SELECT count() FROM Contact WHERE AccountId = :oldContact2.AccountId], 'The second old contacts account should have one related contact.');

        System.assertEquals(1, [SELECT count() from npe5__Affiliation__c where npe5__Primary__c = true], 'There should be only one affiliation record marked primary.');
        System.assertEquals(3, [SELECT count() from npe5__Affiliation__c], 'There should be three affiliation records remaining.');
    }

    /*******************************************************************************************************
    * @description Merge a Contact with an Address Override to a different Account, and verify: 
    *   the Address Override is copied to the new Account
    *   the Contact's Address Override lookup is updated
    *   the Contact's mailing address matches the override
    */
    @IsTest
    private static void mergeContactsDifferentHHAccountAddressOverride() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        setRecordData();

        List<Account> households = new List<Account>{ existingAccounts[0], existingAccounts[1] };
        Contact masterContact = existingContacts[ADDR_OVERRIDE_INDEX];
        Contact oldContact = existingContacts[0];
        List<Contact> contacts = new List<Contact>{ masterContact, oldContact };
        System.assertEquals(households[0].Id, oldContact.AccountId, 'Expected the old contact to belong to the first household.');
        System.assertEquals(households[1].Id, masterContact.AccountId, 'Expected the master contact to belong to the second household.');
        Address__c overrideAddress = [SELECT Default_Address__c FROM Address__c WHERE Id = :masterContact.Current_Address__c];
        System.assert(!overrideAddress.Default_Address__c, 'The override address should not be the default address on the account.');

        Test.startTest();
        merge masterContact oldContact;
        Test.stopTest();

        List<Account> accounts = getAccounts();
        System.assertEquals(masterContact.AccountId, accounts[1].Id, 'Expected the master contacts account to be the second account.');
        System.assertEquals(oldContact.AccountId, accounts[0].Id, 'Expected the old contacts account to be the first account.');

        contacts = getContacts();
        System.assertEquals(existingContacts.size() - 1, contacts.size(), 'There should be one less contact in the system.');
        System.assertEquals(masterContact.Id, contacts[2].Id, 'Expected the third contact to be the master contact.');
        masterContact = contacts[2];

        System.assertEquals(contacts[0].AccountId, accounts[0].Id, 'Expected the first contact to belong to the first account.');
        System.assertEquals(contacts[1].AccountId, accounts[1].Id, 'Expected the second contact to belong to the second account.');
        System.assertEquals(contacts[2].AccountId, accounts[1].Id, 'Expected the third contact to belong to the second account.');
        households = new List<Account>{ accounts[0], accounts[1] };

        List<Address__c> addresses = [
            SELECT Id, Default_Address__c
            FROM Address__c
            WHERE Household_Account__c IN :households
            ORDER BY Id
        ];
        overrideAddress = [SELECT Id, Household_Account__c, MailingStreet__c, MailingCity__c FROM Address__c WHERE Id = :overrideAddress.Id];

        System.assertEquals(3, addresses.size(), 'Expected both accounts to have an address each with an additional address for the master contacts address override.');
        System.assert(masterContact.is_Address_Override__c, 'The master contact should still be set to override the address.');
        System.assertEquals(masterContact.Current_Address__c, overrideAddress.Id, 'The master contact should still be set to the override address.');
        System.assertEquals(masterContact.AccountId, overrideAddress.Household_Account__c, 'The second address should belong to the master contacts account.');
        System.assertEquals(masterContact.MailingStreet, overrideAddress.MailingStreet__c, 'The second address should match the contacts street address override.');
        System.assertEquals(masterContact.MailingCity, overrideAddress.MailingCity__c, 'The second address should match the contacts city address override.');
        for (Address__c record : addresses) {
            if (overrideAddress.Id == record.Id) {
                System.assert(!record.Default_Address__c, 'The override address should not be the default address on the account.');

            } else {
                System.assert(record.Default_Address__c, 'The other addresses should be the default address for each account.');
            }
        }
    }

    /***************************************************************************************************************
     * @description Verifies the list of merge keys is split into each list of ids
     */
    @IsTest
    private static void shouldSetMergeKeyIds() {
        List<String> oldAccountIds = UTIL_UnitTestData_TEST.mockIds(Account.SObjectType, MOCK_IDS_SIZE);
        List<String> oldContactIds = UTIL_UnitTestData_TEST.mockIds(Contact.SObjectType, MOCK_IDS_SIZE);
        List<String> masterContactIds = UTIL_UnitTestData_TEST.mockIds(Contact.SObjectType, MOCK_IDS_SIZE);
        List<String> mergeKeys = new String[MOCK_IDS_SIZE];

        for (Integer index = 0; index < MOCK_IDS_SIZE; index++) {
            mergeKeys[index] = oldContactIds[index] + ':' + oldAccountIds[index] + ':' + masterContactIds[index];
        }

        CON_ContactMerge_TDTM.mergeProcessor.setMergeKeyIds(mergeKeys);
        System.assert(new Set<String>(oldAccountIds).equals(new Set<String>(CON_ContactMerge_TDTM.mergeProcessor.oldAccountIds)), 'Expected all of the oldAccountIds from the mockKeys to be extracted.');
        System.assert(new Set<String>(oldContactIds).equals(new Set<String>(CON_ContactMerge_TDTM.mergeProcessor.oldContactIds)), 'Expected all of the oldContactIds from the mockKeys to be extracted.');
        System.assert(new Set<String>(masterContactIds).equals(new Set<String>(CON_ContactMerge_TDTM.mergeProcessor.masterContactIds)), 'Expected all of the masterContactIds from the mockKeys to be extracted.');
    }

    /***************************************************************************************************************
     * @description Verifies the account ids are returned when household
     */
    @IsTest
    private static void shouldReturnAccountIdsWhenAccountsAreHouseholds() {
        List<Account> accounts = createMockAccounts(DEFAULT_ACCT_TYPE);

        List<Id> actualIds = CON_ContactMerge_TDTM.mergeProcessor.extractHouseholdIds(accounts);
        System.assert(UTIL_SObject.extractIds(accounts).equals(new Set<Id>(actualIds)), 'Expected the returned Ids to match the account Ids passed in.');
    }

    /***************************************************************************************************************
     * @description Verifies the contacts account ids are returned when household
     */
    @IsTest
    private static void shouldReturnAccountIdsWhenContactsAccountsAreHouseholds() {
        List<Account> accounts = createMockAccounts(DEFAULT_ACCT_TYPE);
        List<Contact> contacts = createMockContacts(accounts);

        List<Id> actualIds = CON_ContactMerge_TDTM.mergeProcessor.extractHouseholdIds(contacts);
        System.assert(UTIL_SObject.extractIds(accounts).equals(new Set<Id>(actualIds)), 'Expected the returned Ids to match the account Ids of the contacts passed in.');
    }

    /***************************************************************************************************************
     * @description Verifies the account ids are returned when household
     */
    @IsTest
    private static void shouldReturnEmptyListWhenAccountsAreNotHouseholds() {
        List<Account> accounts = createMockAccounts(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);

        List<Id> actualIds = CON_ContactMerge_TDTM.mergeProcessor.extractHouseholdIds(accounts);
        System.assert(actualIds.isEmpty(), 'Expected an empty list to be returned.');
    }

    /***************************************************************************************************************
     * @description Verifies the contacts account ids are returned when household
     */
    @IsTest
    private static void shouldReturnEmptyListWhenContactsAccountsAreNotHouseholds() {
        List<Account> accounts = createMockAccounts(CAO_Constants.BUCKET_ORGANIZATION_TYPE);
        List<Contact> contacts = createMockContacts(accounts);

        List<Id> actualIds = CON_ContactMerge_TDTM.mergeProcessor.extractHouseholdIds(contacts);
        System.assert(actualIds.isEmpty(), 'Expected an empty list to be returned.');
    }

    /***************************************************************************************************************
     * @description Verifies the account id by contact id are returned when any individual type of account
     */
    @IsTest
    private static void shouldReturnAccountIdByMasterContactIdWhenAccountsAreIndividualType() {
        List<Account> accounts = createMockAccounts(DEFAULT_ACCT_TYPE);
        Set<Id> accountIds = UTIL_SObject.extractIds(accounts);
        Set<Id> contactIds = new Set<Id>(UTIL_UnitTestData_TEST.mockIds(Contact.SObjectType, accounts.size()));
        CON_ContactMerge_TDTM.mergeProcessor.oldAccountIds = new List<Id>(accountIds);
        CON_ContactMerge_TDTM.mergeProcessor.masterContactIds = new List<Id>(contactIds);

        Map<Id, Id> accountIdsByContactId = CON_ContactMerge_TDTM.mergeProcessor.extractAcctIdByMasterId(accounts);
        System.assert(accountIds.equals(new Set<Id>(accountIdsByContactId.values())), 'Expected the returned Ids to match the account Ids of the accounts passed in.');
        System.assert(contactIds.equals(new Set<Id>(accountIdsByContactId.keySet())), 'Expected the returned Ids to match the master contact Ids.');
    }

    /***************************************************************************************************************
     * @description Verifies the contacts account id by contact id are returned when any individual type of account
     */
    @IsTest
    private static void shouldReturnAccountIdByMasterContactIdWhenContactsAccountsAreIndividualType() {
        List<Account> accounts = createMockAccounts(CAO_Constants.BUCKET_ORGANIZATION_TYPE);
        List<Contact> contacts = createMockContacts(accounts);
        Set<Id> accountIds = UTIL_SObject.extractIds(accounts);
        Set<Id> contactIds = UTIL_SObject.extractIds(contacts);

        Map<Id, Id> accountIdsByContactId = CON_ContactMerge_TDTM.mergeProcessor.extractAcctIdByMasterId(contacts);
        System.assert(contactIds.equals(accountIdsByContactId.keySet()), 'Expected the returned Ids to match the master contact Ids.');
        System.assert(accountIds.equals(new Set<Id>(accountIdsByContactId.values())), 'Expected the returned Ids to match the account Ids of the contacts passed in.');
    }

    /***************************************************************************************************************
     * @description Verifies an empty map is returned when the losing account is not an individual type of account
     */
    @IsTest
    private static void shouldReturnEmptyMapWhenAccountsAreIndividualType() {
        List<Account> accounts = createMockAccounts('');
        Set<Id> accountIds = UTIL_SObject.extractIds(accounts);
        Set<Id> contactIds = new Set<Id>(UTIL_UnitTestData_TEST.mockIds(Contact.SObjectType, accounts.size()));
        CON_ContactMerge_TDTM.mergeProcessor.oldAccountIds = new List<Id>(accountIds);
        CON_ContactMerge_TDTM.mergeProcessor.masterContactIds = new List<Id>(contactIds);

        Map<Id, Id> accountIdsByContactId = CON_ContactMerge_TDTM.mergeProcessor.extractAcctIdByMasterId(accounts);
        System.assert(accountIdsByContactId.isEmpty(), 'Expected an empty map to be returned.');
    }

    /***************************************************************************************************************
     * @description Verifies an empty map is returned when the master contacts account 
     * is not an individual type of account
     */
    @IsTest
    private static void shouldReturnEmptyMapWhenContactsAccountsAreIndividualType() {
        List<Account> accounts = createMockAccounts('');
        List<Contact> contacts = createMockContacts(accounts);
        Set<Id> accountIds = UTIL_SObject.extractIds(accounts);
        Set<Id> contactIds = UTIL_SObject.extractIds(contacts);

        Map<Id, Id> accountIdsByContactId = CON_ContactMerge_TDTM.mergeProcessor.extractAcctIdByMasterId(contacts);
        System.assert(accountIdsByContactId.isEmpty(), 'Expected an empty map to be returned.');
    }


    // Helpers
    ////////////

    /***************************************************************************************************************
     * @description Create accounts with mock ids and for the account type provided.
     */
    private static List<Account> createMockAccounts(String acctType) {
        List<Account> accounts = new List<Account>();

        for (Id recordId : UTIL_UnitTestData_TEST.mockIds(Account.SObjectType, MOCK_IDS_SIZE)) {
            accounts.add(new Account(Id = recordId, npe01__SYSTEM_AccountType__c = acctType));
        }

        return accounts;
    }

    /***************************************************************************************************************
     * @description Create contacts with mock ids and related to the accounts provided.
     */
    private static List<Contact> createMockContacts(List<Account> accounts) {
        List<Id> contactIds = UTIL_UnitTestData_TEST.mockIds(Contact.SObjectType, accounts.size());
        List<Contact> contacts = new List<Contact>();

        for (Integer index = 0; index < MOCK_IDS_SIZE; index++) {
            Contact contactRecord = new Contact(Id = contactIds[index]);
            contactRecord.Account = accounts[index];
            contactRecord.AccountId = accounts[index].Id;
            contacts.add(contactRecord);
        }

        return contacts;
    }

    /***************************************************************************************************************
     * @description Query for existing record data, the records will always be returned in creation order when
     * sorted by Id in Test classes
     */
    private static void setRecordData() {
        existingAccounts = getAccounts();
        existingContacts = getContacts();
        organizationAcct = getAccounts('')[0];
    }

    /***************************************************************************************************************
     * @description Create opportunity records
     */
    private static void createOpps(List<Contact> contacts) {
        List<Opportunity> opps = UTIL_UnitTestData_TEST.OppsForContactList(
            contacts,
            null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(),
            System.Today(),
            100,
            null,
            null
        );
    
        insert opps;
    }

    /***************************************************************************************************************
     * @description Enables the automatic affiliation creation setting
     */
    private static void enableAffiliationCreationSetting() {
        UTIL_CustomSettingsFacade.getAffiliationsSettingsForTests(
            new npe5__Affiliations_Settings__c(npe5__Automatic_Affiliation_Creation_Turned_On__c = true)
        );
    }

    /***************************************************************************************************************
     * @description Set the account provided as the primary affiliation on each contact provided
     */
    private static void updatePrimaryAffiliation(List<Contact> contacts, Id acctId) {
        for (Contact record : contacts) {
            record.Primary_Affiliation__c = acctId;
        }

        update contacts;
        System.assertEquals(contacts.size(), [SELECT count() FROM npe5__Affiliation__c], 'Expected affiliation records to be created for both contacts.');
    }

    /***************************************************************************************************************
     * @description Retrieve accounts by default account type
     */
    private static List<Account> getAccounts() {
        return getAccounts(DEFAULT_ACCT_TYPE);
    }

    /***************************************************************************************************************
     * @description Retrieve accounts by account type
     */
    private static List<Account> getAccounts(String acctType) {
        return [
            SELECT Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, npo02__NumberOfClosedOpps__c, 
                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            FROM Account
            WHERE npe01__SYSTEM_AccountType__c = :acctType
            ORDER BY Id
        ];
    }

    /***************************************************************************************************************
     * @description Retrieve all contacts
     */
    private static List<Contact> getContacts() {
        return [
            SELECT Id, Firstname, LastName, AccountId, npo02__NumberOfClosedOpps__c, is_Address_Override__c,
                Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            ORDER BY Id
        ];
    }

    /***************************************************************************************************************
     * @description Returns the opps related to the account provided
     */
    private static List<Opportunity> getOpps(Id acctId) {
        return [SELECT Id FROM Opportunity WHERE AccountId = :acctId];
    }

}