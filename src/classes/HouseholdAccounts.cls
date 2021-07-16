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
* @description Contact repository responsible for retrieval and storing of Contacts for specified Accounts
*/
public inherited sharing class HouseholdAccounts extends fflib_SObjects {

    /*******************************************************************************************************
    * @description Account filter when querying Contacts
    */
    private Set<Id> queryAccountIds;

    @TestVisible
    private static AddressService addressService {
        get {
            if (addressService == null) {
                addressService = new AddressService();
            }
            return addressService;
        }
        set;
    }

    @TestVisible
    private static HouseholdNamingService householdNamingService {
        get {
            if (householdNamingService == null) {
                householdNamingService = new HouseholdNamingService();
            }
            return householdNamingService;
        }
        set;
    }

    /*******************************************************************************************************************
     * @description a set of languages that require different naming conventions
     */
    private static final Set<String> EASTERN_ORDER_LANGUAGES = new Set<String>{
            'ja',
            'ko',
            'vi',
            'hu',
            'ro',
            'zh_CN',
            'zh_TW'
    };

    /*******************************************************************************************************************
     * @description the current user's Locale/Language
     */
    private static String userLocale {
        get {
            if (userLocale == null) {
                userLocale = UserInfo.getLocale();
            }

            return userLocale;
        }
        set;
    }

    /*******************************************************************************************************
    * @description Contains list of retrieved Contacts by an Account Id
    */
    private Map<Id, Contact[]> contactsByAccountId {
        get {
            return contactsByAccountId = contactsByAccountId == null
                    ? findContactsByAccount()
                    : contactsByAccountId;
        }
        set;
    }

    /*******************************************************************************************************
    * @description Constructor
    * @param accountIds Account Ids to initialize the Contact Repository with
    */
    public HouseholdAccounts(Set<Id> accountIds) {
        super(new List<Account>());
        queryAccountIds = accountIds == null
                ? new Set<Id>()
                : accountIds;
    }

    /*******************************************************************************************************
    * @description Constructor
    * @param accountIds Account Ids to initialize the Contact Repository with
    */
    public HouseholdAccounts(List<Account> accounts) {
        super(accounts);
    }

    /*******************************************************************************************************
    * @description Returns Contacts for the specified Account
    * @param accountId The Id of an Account to retrieve Contacts for
    * @return Contact[] List of Contacts for the specified Account. Empty list if the Account has no Contacts.
    */
    public Contact[] membersOf(Id accountId) {
        if (!queryAccountIds.contains(accountId)) {
            queryAccountIds.add(accountId);

            //reset Contacts repo so the next reference to the variable retrieves data from DB
            contactsByAccountId = null;
        }

        Contact[] contacts = contactsByAccountId.get(accountId);
        return contacts == null ? new Contact[0] : contacts;
    }

    /*******************************************************************************************************
    * @description Queries DB for specified ContactRepository Account Ids
    * @return Map<Id, Contact[]> Map of Contacts by an Account Id
    */
    private Map<Id, Contact[]> findContactsByAccount() {
        Map<Id, Contact[]> contactsByAccountId = new Map<Id, Contact[]>();

        if (queryAccountIds.isEmpty()) {
            return contactsByAccountId;
        }

        for (Contact c : [SELECT Id, AccountId, Current_Address__c FROM Contact WHERE AccountId IN :queryAccountIds]) {
            if (!contactsByAccountId.containsKey(c.AccountId)) {
                contactsByAccountId.put(c.AccountId, new Contact[0]);
            }
            contactsByAccountId.get(c.AccountId).add(c);
        }

        return contactsByAccountId;
    }

    /*******************************************************************************************************
    * @description Updates the accounts for contacts that have been deleted if they have other hh members
    */
    public void handleContactDeletion(TDTM_Runnable.DmlWrapper dmlWrapper) {
        Set<Id> householdIdsToUpdate = new Set<Id>();

        for (Account accountRecord : (List<Account>) getRecords()) {
            Boolean needsAccountUpdate =
                    (!accountRecord.Contacts.isEmpty()
                            || !accountRecord.Opportunities.isEmpty());

            if (needsAccountUpdate) {
                householdIdsToUpdate.add(accountRecord.Id);
            }
        }

        updateHouseholds(new List<Id>(householdIdsToUpdate), dmlWrapper);
    }

    /*******************************************************************************************************
    * @description Updates an HH Account's naming, primary contact, and rollups
    * @param accountIds the list of Account (Id's) that need updating.
    */
    public static void updateHouseholds(List<Id> accountIds, TDTM_Runnable.DmlWrapper dmlWrapper) {
        if (accountIds.isEmpty()) {
            return;
        }

        resetPrimaryContactForAccount(accountIds, dmlWrapper);
        renameHHAccounts(accountIds);
        rollupAccounts(accountIds);
    }

    /*******************************************************************************************************
    * @description for the list of Household or Account Ids, update their Household Names
    * @param accountIds the list of Household or Account Ids that need updating.
    * @return void
    */
    public static void renameHHAccounts(List<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return;
        }

        if (shouldProcessSynchronously(accountIds)) {
            HouseholdNamingService householdNamingService = new HouseholdNamingService();
            householdNamingService.updateHouseholdNameAndMemberCount(accountIds);
        } else {
            householdNamingService.updateHouseholdNameAndMemberCountAsync(accountIds);
        }
    }

    private static Boolean shouldProcessSynchronously(List<Id> accountIds) {
        return accountIds.size() == 1 || System.isFuture() || System.isBatch() || System.isQueueable();
    }

    /*******************************************************************************************************
    * @description sets the Primary Account for each Account in the list of Accounts
    * @param accountIds the list of Account (Id's) that need updating.
    */
    private static void resetPrimaryContactForAccount(List<Id>
            accountIds, TDTM_Runnable.DmlWrapper dmlWrapper) {

        // for each account, we need a set of their contacts.
        Map<Id, Set<Id>> contactIdsByAccountId = new Map<Id, Set<Id>>();

        for (Contact contactRecord : [
                SELECT Id, AccountId, Account.npe01__One2OneContact__c
                FROM Contact
                WHERE AccountId IN :accountIds
        ]) {
            Set<Id> contactIds = contactIdsByAccountId.get(contactRecord.AccountId);
            if (contactIds == null) {
                contactIds = new Set<Id>();
                contactIdsByAccountId.put(contactRecord.AccountId, contactIds);
            }
            contactIds.add(contactRecord.Id);
        }

        // now go thru each account and update their primary contact if the current one isn't valid
        List<Account> accounts = new List<Account>();
        for (Account accountRecord : [SELECT Id, npe01__One2OneContact__c FROM Account WHERE Id IN :accountIds]) {
            Set<Id> contactIds = contactIdsByAccountId.get(accountRecord.Id);
            if (contactIds != null && !contactIds.contains(accountRecord.npe01__One2OneContact__c)) {
                accountRecord.npe01__One2OneContact__c = extractFirstId(contactIds);
                accounts.add(accountRecord);
            }
        }

        if (accounts != null && !accounts.isEmpty()) {
            dmlWrapper.objectsToUpdate.addAll(accounts);
        }
    }

    /*******************************************************************************************************
    * @description returns the first Id from the specified set
    * @param ids a set of Id's
    * @return Id.  null if the set is empty.
    */
    private static Id extractFirstId(Set<Id> ids) {
        for (Id recordId : ids) {
            return recordId;
        }

        return null;
    }

    /*******************************************************************************************************
    * @description for the list of AccountId's, recalc their rollups
    * @param accountIds the list of Account (Id's) that need updating.
    */
    public static void rollupAccounts(List<Id> accountIds) {
        new RLLP_OppRollup().rollupAccounts(new Set<Id>(accountIds));
    }

    /*******************************************************************************************************
    * @description Inserts a new 1:1 or HH Account for an Individual Contact
    * @param contactsWithoutAccounts the list of Contacts that need updating.
    */
    public static void createOneToOneAndHouseholdAccountsFor(List<Contact>
            contactsWithoutAccounts){
        if (contactsWithoutAccounts.isEmpty()) {
            return;
        }

        List<Id> contactIds = new List<Id>();
        Map<Id, Account> accountByPrimaryContactId = new Map<Id, Account>();
        List<Contact> contacts = new List<Contact>();

        for (Contact contactRecord : contactsWithoutAccounts) {
            //track which contacts are being inserted vs. updated
            if (contactRecord.Id != null) {
                contactIds.add(contactRecord.Id);
            }
        }
        // get all the Accounts that are connected to the existing Contacts
        for (Account accountRecord : [
                SELECT Id, npe01__One2OneContact__c, npe01__SYSTEM_AccountType__c
                FROM Account
                WHERE npe01__One2OneContact__c IN :contactIds
        ]) {
            accountByPrimaryContactId.put(accountRecord.npe01__One2OneContact__c, accountRecord);
        }

        List<Account> accountInserts = new List<Account>();
        Id individualRecordTypeId = Accounts.rtIdForNewAccount();

        for (Contact contactRecord : contactsWithoutAccounts) {
            // if we found an Account already connected to this Contact, connect the Contact to that Account if it
            // is the correct type for the current account processor
            Account accountRecord = accountByPrimaryContactId.get(contactRecord.Id);
            if (accountRecord != null &&
                    ((CAO_Constants.isHHAccountModel() && accountRecord.npe01__SYSTEM_AccountType__c == CAO_Constants.HH_ACCOUNT_TYPE) ||
                            (CAO_Constants.isOneToOne() && accountRecord.npe01__SYSTEM_AccountType__c == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE)) ) {
                // if a user has blanked out the Account for a Contact, this will put it right back
                contactRecord.AccountId = accountRecord.Id;
            } else {
                // construct the individul account for the Contact
                accountRecord = new Account();

                // construct the Account name
                accountRecord.Name = CAO_Constants.isHHAccountModel() ? strNameHHAccountForContact(contactRecord) : strNameOne2OneAccountForContact(contactRecord);

                // connect the Account to the Contact for 1:1 and HHAccount
                if (contactRecord.Id != null) {
                    accountRecord.npe01__One2OneContact__c = contactRecord.Id;
                }

                accountRecord.Phone = contactRecord.Phone;
                accountRecord.Fax = contactRecord.Fax;
                accountRecord.OwnerId = contactRecord.OwnerId;

                if (UserInfo.isMultiCurrencyOrganization()) {
                    accountRecord.put('CurrencyIsoCode', (String) contactRecord.get('CurrencyIsoCode'));
                }

                // Always copy the Contact's Mailing & Others address to the new Account's
                // Billing & Shipping address.
                if (contactRecord.is_Address_Override__c != true) {
                    addressService.copyAddressStdSObj(contactRecord, 'Mailing', accountRecord, 'Billing');
                    addressService.copyAddressStdSObj(contactRecord, 'Other', accountRecord, 'Shipping');
                }

                accountRecord.npe01__SYSTEM_AccountType__c = CAO_Constants.isHHAccountModel() ? CAO_Constants.HH_ACCOUNT_TYPE : CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE;
                if (individualRecordTypeId != null) {
                    accountRecord.put('RecordTypeID', individualRecordTypeId);
                }
                accountRecord.Type = CAO_Constants.isHHAccountModel() ? CAO_Constants.HH_TYPE : '';
                accountRecord.npe01__SYSTEMIsIndividual__c = true;
                accountInserts.add(accountRecord);
                contacts.add(contactRecord);
            }
        }

        if (accountInserts.isEmpty()) {
            return;
        }

        // with current TDTM design, we can't use dmlWrapper
        // because we need to get the new AccountID's into the Contacts.

        // identify the specific records that had the problem, and don't fail the whole batch
        //Note: this insert inserts both Accounts and Addresses (in the Acct triggers)
        List<Database.SaveResult> insertResults = UTIL_DMLService.insertRecords(accountInserts, false);
        for (Integer index = 0; index < insertResults.size(); index++) {
            Database.SaveResult insertResult = insertResults[index];
            if (!insertResult.isSuccess()) {
                for (Database.Error err : insertResult.getErrors()) {
                    accountInserts[index].addError(err.getMessage());
                    Contact contactRecord = contacts[index];
                    contactRecord.addError(String.format(System.Label.conFailedAccountCreate, new String[]{contactRecord.FirstName, contactRecord.LastName, err.getMessage()}));
                }
            }
        }

        // now update each contact's accountId
        Integer index = 0;
        for (Contact contactRecord : contacts) {
            contactRecord.AccountId = accountInserts[index].Id;
            index++;
        }
    }

    /*******************************************************************************************************
    * @description returns the default name for a new HH Account. Custom household naming will update this
    * account later if enabled, but we still need one if not enabled.
    * @param contactRecord the Contact
    * @return String. the Household account name
    */
    public static String strNameHHAccountForContact(Contact contactRecord) {
        return contactRecord.LastName + ' ' + System.Label.npo02.DefaultHouseholdName;
    }

    /*******************************************************************************************************
    * @description returns the default name for a new 1:1 Account
    * @param contactRecord the Contact
    * @return String. the 1:1 account name
    */
    public static String strNameOne2OneAccountForContact(Contact contactRecord) {
        String accountName = '';

        if (contactRecord.FirstName != null) {
            accountName += contactRecord.FirstName;
            accountName += ' ' ;
        }

        if (EASTERN_ORDER_LANGUAGES.contains(userLocale)) {
            accountName = contactRecord.LastName + ' ' + accountName;

        } else {
            accountName += contactRecord.LastName;
        }

        return accountName;
    }

    public static void renameHouseholdAccountsAfterInsert(List<Contact> contacts) {

        List<Id> householdIdsToRename = new List<Id>();

        for (Contact contactRecord : contacts) {
            if (contactRecord.AccountId == null) {
                continue;
            }

            if (isHouseholdMember(contactRecord)) {
                householdIdsToRename.add(contactRecord.AccountId);
            }
        }

        renameHHAccounts(householdIdsToRename);
    }

    /**
     * isHouseholdMember Determines whether or not the contact belongs to a household account.
     * @param  contactRecord The contact record to verify.
     * @return Boolean - true when the contact belongs to a household account.
     */
    private static Boolean isHouseholdMember(Contact contactRecord) {
        return contactRecord.Account.npe01__SYSTEM_AccountType__c == CAO_Constants.HH_ACCOUNT_TYPE;
    }

    public static List<Id> moveOppsForContactsSwitchingAccounts(Contacts contacts) {
        Map<Id, Id> oldHouseholdIdByContactId = new Map<Id, Id>();
        Map<Id, Id> newHouseholdIdByContactId = new Map<Id, Id>();

        List<Id> householdIdsToUpdate = new List<Id>();
        for (Contact contactRecord : (List<Contact>) contacts.getRecords()) {
            Contact oldContact = contacts.oldVersionOf(contactRecord);

            if (contactRecord.AccountId != oldContact.AccountId) {
                addHouseholdIds(householdIdsToUpdate, newHouseholdIdByContactId, contactRecord);
                addHouseholdIds(householdIdsToUpdate, oldHouseholdIdByContactId, oldContact);

            }
        }

        moveOppsToContactAccount(newHouseholdIdByContactId, oldHouseholdIdByContactId);
        return householdIdsToUpdate;
    }

    /**
     * addHouseholdIds Adds the account ids from all of the contacts belonging to a household
     * @param  householdIds           The collection of householdIds to add the account ids to
     * @param  householdIdByContactId The map of household by their id.
     * @param  contactRecord          The contact to extract the id from.
     */
    private static void addHouseholdIds(List<Id> householdIds, Map<Id, Id>
            householdIdByContactId, Contact contactRecord) {
        if (contactRecord.npe01__Organization_Type__c == CAO_Constants.HH_ACCOUNT_TYPE) {
            householdIds.add(contactRecord.AccountId);
            householdIdByContactId.put(contactRecord.Id, contactRecord.AccountId);
        }
    }

    /*******************************************************************************************************
    * @description Moves all opps for the Primary OCR provided contacts to their new account.  Note that it
    * is the caller's responsibility to decide whether moving opps is appropriate for the involved accounts.
    * @param newHouseholdIdByContactId a map of Contact Id to Account Id, for the Accounts to move opps to
    * @param oldHouseholdIdByContactId a map of Contact Id to Account Id, for the Accounts to move opps from
    */
    public static void moveOppsToContactAccount(Map<Id,Id> newHouseholdIdByContactId, Map<Id,Id>
            oldHouseholdIdByContactId) {
        if (newHouseholdIdByContactId.isEmpty()) {
            return;
        }

        List<Opportunity> opportunities = new List<Opportunity>();
        Set<Id> oppIds = new Set<Id>();

        for (OpportunityContactRole role : [
                SELECT ContactId, OpportunityId, Opportunity.AccountId
                FROM OpportunityContactRole
                WHERE IsPrimary = TRUE
                AND Opportunity.AccountId IN :oldHouseholdIdByContactId.values()
                AND ContactId IN :newHouseholdIdByContactId.keySet()
        ]) {
            Boolean shouldMoveOpp = oldHouseholdIdByContactId.get(role.ContactId) == role.Opportunity.AccountId
                    && oppIds.add(role.OpportunityId);

            if (shouldMoveOpp) {
                opportunities.add(new Opportunity(
                        Id = role.OpportunityId,
                        AccountId = newHouseholdIdByContactId.get(role.ContactId)));
            }
        }

        if (!opportunities.isEmpty()) {
            UTIL_DMLService.updateRecords(opportunities);
        }
    }

    public static void handleContactsAfterUpdate(Contacts contacts, TDTM_Runnable.DmlWrapper dmlWrapper) {
        List<Id> householdIdsToUpdate =
                moveOppsForContactsSwitchingAccounts(contacts);
        updateHouseholds(householdIdsToUpdate, dmlWrapper);
    }

}