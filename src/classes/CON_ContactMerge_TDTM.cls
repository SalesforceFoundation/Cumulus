/*
    Copyright (c) 2015 Salesforce.org
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
*
* @group ContactMerge
*
* @description Trigger Handler on Contact that handles detecting when a Contact Merge 
* has completed, in order to fixup an assortment of affected information.
*/
public class CON_ContactMerge_TDTM extends TDTM_Runnable {
    @TestVisible
    private static ContactMergeProcessor mergeProcessor {
        get {
            if (mergeProcessor == null) {
                mergeProcessor = new ContactMergeProcessor();
            }

            return mergeProcessor;
        }
        set;
    }

    /*******************************************************************************************************
    * @description Trigger Handler on Contact that handles detecting when an Contact Merge 
    * has completed, in order to fixup an assortment of affected information.
    * @param newContacts the list of Contacts from trigger new. 
    * @param oldContacts the list of Contacts from trigger old. 
    * @param triggerAction which trigger event (BeforeInsert, AfterInsert, etc.). 
    * @param objResult the describe for Contacts 
    * @return dmlWrapper.  always null.
    ********************************************************************************************************/
    public override DmlWrapper run(List<SObject> newContacts, List<SObject> oldContacts,
        TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult) {

        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        if (triggerAction == TDTM_Runnable.Action.AfterDelete) {
            List<String> mergeKeys = new List<String>();

            for (SObject sObj : oldContacts) {
                Contact oldContact = (Contact)sObj;
                if (skipContactMergeFixup(oldContact)) {
                    continue;
                }

                mergeKeys.add(generateMergeKey(oldContact.Id, oldContact.AccountId, oldContact.MasterRecordId));
            }

            System.enqueueJob(new ContactMergeFixupQueueable(mergeKeys));
        }

        return dmlWrapper;
    }

    /*******************************************************************************************************
    * @description Determine if the record provided should be skipped.
    * @param record - the Contact to check if merge fixup is required.
    *
    * @return Boolean - true when contact merge fixup is not needed
    ********************************************************************************************************/
    private Boolean skipContactMergeFixup(Contact record) {
        return record == null || record.MasterRecordId == null;
    }

    /*******************************************************************************************************
    * @description returns a unique key for a tracking a merged Contact, their account, and the master
    * Contact Record Id.
    * @param oldContactId The merged Contact's Id
    * @param oldAccountId The merged Contact's Account Id
    * @param masterContactId The master Contact Record Id
    * @return String
    ********************************************************************************************************/
    private String generateMergeKey(String oldContactId, String oldAccountId, String masterContactId) {
        return (oldContactId + ':' + oldAccountId + ':' + masterContactId);
    }

    /*******************************************************************************************************
    * @description After a Contact Merge, call this async routine to perform assorted fixups that need to
    * occur which include:
    *   - update the Account name and greetings 
    *   - move Opps to the Master Contact's Account 
    *   - recalculate Household Soft Credit OCRs 
    *   - recalculate Opportunity Rollups
    *
    ********************************************************************************************************/
    private class ContactMergeFixupQueueable implements Queueable {
        List<String> mergeKeys;

        /***************************************************************************************************************
         * @description Constructor
         * @param mergeKeys - the ids relevant to the merge process
         */
        private ContactMergeFixupQueueable(List<String> mergeKeys) {
            this.mergeKeys = mergeKeys;
        }

        public void execute(QueueableContext qc) {
            if (mergeKeys == null || mergeKeys.isEmpty()) {
                return;
            }

            mergeProcessor.fixup(mergeKeys);
        }
    }

    /*******************************************************************************************************
    * @description Fixes records related to merged contacts
    ********************************************************************************************************/
    @TestVisible
    private class ContactMergeProcessor {
        @TestVisible
        private List<String> oldContactIds = new List<String>();
        @TestVisible
        private List<String> oldAccountIds = new List<String>();
        @TestVisible
        private List<String> masterContactIds = new List<String>();

        private List<Id> householdIds = new List<Id>();
        private Map<Id, Id> oldIndividualAcctIdByMasterId = new Map<Id, Id>();
        private Map<Id, Id> newIndividualAcctIdByMasterId = new Map<Id, Id>();

        /***************************************************************************************************************
         * @description Fixes records involved in the merge process
         * @param mergeKeys - the ids relevant to the merge process
         */
        private void fixup(List<String> mergeKeys) {
            setMergeKeyIds(mergeKeys);

            List<Account> oldAccounts = getAccounts(oldAccountIds);
            List<Contact> masterContacts = getContacts(masterContactIds);

            householdIds = extractHouseholdIds(oldAccounts);
            householdIds.addAll(extractHouseholdIds(masterContacts));

            oldIndividualAcctIdByMasterId = extractAcctIdByMasterId(oldAccounts);
            newIndividualAcctIdByMasterId = extractAcctIdByMasterId(masterContacts);

            fixupAccountData();
            fixupContactData(masterContacts);
        }

        /*******************************************************************************************************
        * @description Returns the account Id of accounts with household account types
        * @param accounts - The accounts to return the Id for when they are a household account
        * @return List<Id> - The list of household account Ids
        ********************************************************************************************************/
        @TestVisible
        private List<Id> extractHouseholdIds(List<Account> accounts) {
            List<Id> accountIds = new List<Id>();

            for (Account record : accounts) {
                if (isHousehold(record.npe01__SYSTEM_AccountType__c)) {
                    accountIds.add(record.Id);
                }
            }

            return accountIds;
        }

        /*******************************************************************************************************
        * @description Returns the account Id of the master contacts accounts with household account types
        ********************************************************************************************************/
        @TestVisible
        private List<Id> extractHouseholdIds(List<Contact> contacts) {
            List<Id> accountIds = new List<Id>();

            for (Contact record: contacts) {
                if (isHousehold(record.Account.npe01__SYSTEM_AccountType__c)) {
                    accountIds.add(record.AccountId);
                }
            }

            return accountIds;
        }

        /*******************************************************************************************************
        * @description Adds the account Id of the losing contacts account when it
        * is any type of individual account
        ********************************************************************************************************/
        @TestVisible
        private Map<Id, Id> extractAcctIdByMasterId(List<Account> oldAccounts) {
            Map<Id, Id> accountIdByContactId = new Map<Id, Id>();

            Map<Id, Account> oldAccountById = new Map<Id, Account>(oldAccounts);

            for (integer i = 0; i < oldAccountIds.size(); i++) {
                if (oldAccountIds[i] == null) {
                    continue;
                }

                Account oldAccount = oldAccountById.get(oldAccountIds[i]);
                if (oldAccount == null) {
                    continue;
                }

                if (isIndividual(oldAccount.npe01__SYSTEM_AccountType__c)) {
                    accountIdByContactId.put(masterContactIds[i], oldAccountIds[i]);
                }
            }

            return accountIdByContactId;
        }

        /*******************************************************************************************************
        * @description Adds the account Id of the master contacts account when it
        * is any type of individual account
        *
        * @param masterContacts the collection of contacts to extract the ids from
        ********************************************************************************************************/
        @TestVisible
        private Map<Id, Id> extractAcctIdByMasterId(List<Contact> masterContacts) {
            Map<Id, Id> accountIdByContactId = new Map<Id, Id>();

            for (Contact masterContact : masterContacts) {
                if (masterContact.AccountId == null) {
                    continue;
                }

                if (isIndividual(masterContact.Account.npe01__SYSTEM_AccountType__c)) {
                    accountIdByContactId.put(masterContact.Id, masterContact.AccountId);
                }
            }

            return accountIdByContactId;
        }

        /*******************************************************************************************************
        * @description Determines if the account type provided matches the Household Account Type
        *
        * @param acctType The account type to compare
        * @return Boolean true if the string passed in matches the Household Account Type
        ********************************************************************************************************/
        private Boolean isHousehold(String acctType) {
            return acctType == CAO_Constants.HH_ACCOUNT_TYPE;
        }

        /*******************************************************************************************************
        * @description Determines if the account type provided matches any of the Individual Account Types
        *
        * @param acctType The account type to compare
        * @return Boolean true if the string passed in matches any of the Individual Account Types
        ********************************************************************************************************/
        private Boolean isIndividual(String acctType) {
            return isHousehold(acctType)
                || acctType == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE
                || acctType == CAO_Constants.BUCKET_ORGANIZATION_TYPE;
        }

        /*******************************************************************************************************
        * @description Performs household naming, moves opportunities from the old accounts to the master contacts
        * account, recreates Household Soft Credits and performs rollups on all Accounts
        *
        ********************************************************************************************************/
        private void fixupAccountData() {
            List<Id> accountIds = new List<Id>();
            accountIds.addAll(oldIndividualAcctIdByMasterId.values());
            accountIds.addAll(newIndividualAcctIdByMasterId.values());
            if (accountIds.isEmpty()) {
                return;
            }

            HouseholdAccounts.renameHHAccounts(householdIds);
            HouseholdAccounts.moveOppsToContactAccount(
                newIndividualAcctIdByMasterId,
                oldIndividualAcctIdByMasterId
            );
            HH_OppContactRoles_TDTM.recreateHouseholdSoftCredits(accountIds);
            HouseholdAccounts.rollupAccounts(accountIds);
        }

        /*******************************************************************************************************
        * @description Performs rollups, affiliation and relationship cleanup on the master contacts
        *
        * @param masterContacts the collection of master contacts
        ********************************************************************************************************/
        private void fixupContactData(List<Contact> masterContacts) {
            new RLLP_OppRollup().rollupContacts(new Map<Id, SObject>(masterContacts).keySet());

            AFFL_Affiliations_TDTM.cleanupContactAffiliations(masterContacts);
            REL_Relationships_TDTM.cleanupContactRelationships(masterContacts);
        }

        /*******************************************************************************************************
        * @description Queries for the accounts and fields needed for processing
        *
        * @return List<Account> the list of accounts that match the ids provided
        ********************************************************************************************************/
        private List<Account> getAccounts(List<Id> accountIds) {
            return [SELECT Id, npe01__SYSTEM_AccountType__c FROM Account WHERE Id IN :accountIds];
        }

        /*******************************************************************************************************
        * @description Uses the opp rollup util to build the query then modifies the query to include additional
        * fields necessary for processing merged contacts
        *
        * @return List<Contact> the list of contacts that match the ids provided
        ********************************************************************************************************/
        private List<Contact> getContacts(List<Id> contactIds) {
            RLLP_OppRollup_UTIL oppRollupUtil = new RLLP_OppRollup_UTIL(); 
            String query = oppRollupUtil.buildContactQuery();

            query = query.replace('from Contact', '');
            query += ', AccountId, Account.npe01__SYSTEM_AccountType__c, Primary_Affiliation__c FROM Contact WHERE Id IN :contactIds';
            return Database.query(query);
        }

        /*******************************************************************************************************
        * @description Splits the ids from the list of merge keys provided.
        *
        * @param mergeKeys A list of merged Ids, each merge key is expected to have an id for each collection
        ********************************************************************************************************/
        @TestVisible
        private void setMergeKeyIds(List<String> mergeKeys) {
            oldAccountIds = new List<String>();
            oldContactIds = new List<String>();
            masterContactIds = new List<String>();

            for (String mergeKey : mergeKeys) {
                List<String> ids = mergeKey.split(':');
                if (ids == null || ids.size() < 3) {
                    continue;
                }

                oldContactIds.add(convertNull(ids[0]));
                oldAccountIds.add(convertNull(ids[1]));
                masterContactIds.add(convertNull(ids[2]));
            }
        }

        /*******************************************************************************************************
        * @description Checks for the string value of null
        *
        * @param val The value to compare
        * @return String null when val passed in is the String value of null
        ********************************************************************************************************/
        private String convertNull(String val) {
            final String nullVal = 'null';

            return val == nullVal ? null : val;
        }
    }

}