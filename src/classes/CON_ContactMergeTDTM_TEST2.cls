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

@isTest(IsParallel=true)

public with sharing class CON_ContactMergeTDTM_TEST2 {
    /*******************************************************************************************************************
    * @description Counter for creating unique contacts
    */
    private static Integer uniqueCounter {
        get {
            if (uniqueCounter == null) {
                uniqueCounter = 0;
            }
            uniqueCounter++;
            return uniqueCounter;
        }
        set;
    }

    /*******************************************************************************************************
    * @description merge three Contacts from different Household Accounts with many Relationships.  
    * verify: 
    *   No Duplicate Relationships
    */
    @isTest
    private static void mergeContactsDifferentHHAccountManyRel() {
        // this creates 3 Household Accounts, each with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createTestData(3, 2);
        
        Contact conWinner = ADDR_Addresses_TEST.testContacts[1];
        Contact conLoser1 = ADDR_Addresses_TEST.testContacts[3];
        Contact conLoser2 = ADDR_Addresses_TEST.testContacts[4];
        
        // create relationships between the contacts in each household
        list<npe4__Relationship__c> listRel = new list<npe4__Relationship__c>();
        for (integer i = 0; i < 3; i++) {
            npe4__Relationship__c rel = new npe4__Relationship__c(
                npe4__Contact__c = ADDR_Addresses_TEST.testContacts[i * 2].id,
                npe4__RelatedContact__c = ADDR_Addresses_TEST.testContacts[i * 2 + 1].id,
                npe4__Type__c='Friend',
                npe4__Status__c='Active',
                npe4__Description__c='notes');
            listRel.add(rel);
        }
        
        // create relationships between the winners & losers, and one of the other contacts
        // these will be the duplicate relationships that should be merged.
        Contact conRel = ADDR_Addresses_TEST.testContacts[0];
        listRel.add(new npe4__Relationship__c(npe4__Contact__c=conWinner.Id, npe4__RelatedContact__c=conRel.Id));
        listRel.add(new npe4__Relationship__c(npe4__Contact__c=conLoser1.Id, npe4__RelatedContact__c=conRel.Id));
        listRel.add(new npe4__Relationship__c(npe4__Contact__c=conLoser2.Id, npe4__RelatedContact__c=conRel.Id));
        insert listRel;
        
        // verify rels all there
        system.assertEquals(12, [select count() from npe4__Relationship__c]);
        
        // now let's do the merge!
        Test.startTest();
        merge conWinner new list<Contact>{conLoser1, conLoser2};

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our contacts
        list<Contact> listCon = [select Id, Firstname, AccountId, npo02__NumberOfClosedOpps__c,
            is_Address_Override__c, Current_Address__c, Current_Address__r.Household_Account__c,
            MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Id];
        system.assertEquals(conWinner.Id, listCon[1].Id);
        conWinner = listCon[1];            
            
        // verify the merge
        system.assertEquals(4, listCon.size());
        system.assertEquals(2, [select count() from Contact where AccountId = :conWinner.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser1.AccountId]);
        system.assertEquals(1, [select count() from Contact where AccountId = :conLoser2.AccountId]);
                    
        // verify the expected relationships
        system.assertEquals(8, [select count() from npe4__Relationship__c]);
        system.assertEquals(4, [select count() from npe4__Relationship__c where npe4__Contact__c = :conWinner.Id]);              
        system.assertEquals(4, [select count() from npe4__Relationship__c where npe4__RelatedContact__c = :conWinner.Id]);              
    }
    
    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeHHToHH() {
        testNamesAndOppsMerge(CAO_Constants.HH_ACCOUNT_TYPE, CAO_Constants.HH_ACCOUNT_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeOne2OneToOne2One() {
        testNamesAndOppsMerge(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeOrgToHH() {
        testNamesAndOppsMerge(null, CAO_Constants.HH_ACCOUNT_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeHHToOrg() {
        testNamesAndOppsMerge(CAO_Constants.HH_ACCOUNT_TYPE, null);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeOrgToOne2One() {
        testNamesAndOppsMerge(null, CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeOne2OneToOrg() {
        testNamesAndOppsMerge(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, null);
    }
    
    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    @isTest
    private static void testNamesAndOppsMergeOrgToOrg() {
        testNamesAndOppsMerge(null, null);
    }

    /*******************************************************************************************************
    * @description Merge two Contacts in different Accounts and verifies Opps, OCRs, Rollups, and Names
    *   the account's names and greetings are updated.
    *   Opps owned by the contact are moved over.
    *   Soft Credits for the moved Opps are recalculated.
    *   Soft Credits the contact previously had are still there.
    *   Opp Rollups are recalculated for both accounts.
    */
    private static void testNamesAndOppsMerge(string accTypeLoser, string accTypeWinner) {
    
        // create our losing account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(accTypeLoser, 1, 2, 1);
        Account accLoser = UTIL_UnitTestData_TEST.listAccT[0];
        list<Contact> listConAll = UTIL_UnitTestData_TEST.listConT; 
        
        // create our winning account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(accTypeWinner, 1, 2, 3);
        Account accWinner = UTIL_UnitTestData_TEST.listAccT[0];
        listConAll.addAll(UTIL_UnitTestData_TEST.listConT);        
        
        // create an opp for each contact
        // note that for Org accounts, these Opps won't generate Soft Credits.
        list<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactWithAccountList(listConAll, null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(), system.Today(), 100, null, null);
        insert listOpp;
        
        // Merge the first contact in the first account to the first contact in the other account.
        Contact conWinner = listConAll[2];
        Contact conLoser = listConAll[0];
        Test.startTest();
        merge conWinner conLoser;
        Test.stopTest();

        // reload our contacts and accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account order by Id]);
        list<Contact> listCon = [select Id, Firstname, Lastname, AccountId, 
            is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Id];
            
        // verify the contacts belong to correct account.
        system.assertEquals(accLoser.Id, listAcc[0].Id);
        accLoser = listAcc[0];
        system.assertEquals(accWinner.Id, listAcc[1].Id);
        accWinner = listAcc[1];
        system.assertEquals(3, listCon.size());
        system.assertEquals(conWinner.Id, listCon[1].Id);
        conWinner = listCon[1];
        system.assertEquals(listCon[0].AccountId, accLoser.Id);
        system.assertEquals(conWinner.AccountId, accWinner.Id);
        system.assertEquals(listCon[2].AccountId, accWinner.Id);
            
        // verify the account's names and greetings are updated
        if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE)
            system.assertEquals(false, accLoser.npo02__Formal_Greeting__c.contains(conLoser.Firstname));        
        if (accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            system.assertEquals(false, accWinner.npo02__Formal_Greeting__c.contains(conLoser.Firstname));
            system.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(conWinner.Firstname));
        }                
        system.assertEquals(false, accWinner.Name.contains('Anonymous'));    
        
        integer cAccLoserOpps = [select count() from Opportunity where AccountId = :accLoser.Id];
        integer cAccWinnerOpps = [select count() from Opportunity where AccountId = :accWinner.Id];
        integer cOCRCon0 = [select count() from OpportunityContactRole where ContactId = :listCon[0].Id];
        integer cOCRConWinner = [select count() from OpportunityContactRole where ContactId = :conWinner.Id];
        integer cOCRCon2 = [select count() from OpportunityContactRole where ContactId = :listCon[2].Id];
        
        // verify Opps, OCR's, and Rollups are what we expect!
        if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE && accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            system.assertEquals(1, cAccLoserOpps);
            system.assertEquals(3, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(3, cOCRConWinner);
            system.assertEquals(3, cOCRCon2);
            system.assertEquals(1, accLoser.npo02__NumberOfClosedOpps__c);
            system.assertEquals(3, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE && accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            system.assertEquals(1, cAccLoserOpps);
            system.assertEquals(3, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(1, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(3, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(3, cOCRConWinner);
            system.assertEquals(2, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE && accTypeWinner == null) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE && accTypeWinner == null) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == null) {
            system.assertEquals(2, cAccLoserOpps);
            system.assertEquals(2, cAccWinnerOpps);
            system.assertEquals(1, cOCRCon0);
            system.assertEquals(2, cOCRConWinner);
            system.assertEquals(1, cOCRCon2);
            system.assertEquals(2, accLoser.npo02__NumberOfClosedOpps__c);            
            system.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
    }

    /*******************************************************************************************************
    * @description Verifies rollup is calculated on merge using Customizable Rollups
    */
    @isTest
    private static void contactMergeShouldRecalculateWithCustomizableRollups() {
        UTIL_CustomSettingsFacade.getRollupSettingsForTests(new Customizable_Rollup_Settings__c (
            Customizable_Rollups_Enabled__c = true
        ));
        CMT_UnitTestData_TEST.mockFullSetOfRollupDefinitions();

        List<Contact> contactsToMerge = buildContactsWithOppsForAccount();

        Test.startTest();
        List<Contact> contacts = [SELECT npo02__NumberOfClosedOpps__c FROM Contact];
        System.assertEquals(0, contacts[0].npo02__NumberOfClosedOpps__c, 'There should be no calculated rollups at this point');
        System.assertEquals(0, contacts[1].npo02__NumberOfClosedOpps__c, 'There should be no calculated rollups at this point');
        merge contactsToMerge[0] contactsToMerge[1];
        Test.stopTest();

        contacts = [SELECT npo02__NumberOfClosedOpps__c FROM Contact];
        System.assertEquals(1, contacts.size(), 'There should only be one contact after merge');
        System.assertEquals(2, contacts[0].npo02__NumberOfClosedOpps__c, 'The rollup should have been calculated on the remaining contact');
    }

    /*******************************************************************************************************
    * @description Verifies rollup is calculated on merge using Legacy Rollups
    */
    @isTest
    private static void contactMergeShouldRecalculateWithLegacyRollups() {
        UTIL_CustomSettingsFacade.getRollupSettingsForTests(new Customizable_Rollup_Settings__c (
            Customizable_Rollups_Enabled__c = false
        ));

        List<Contact> contactsToMerge = buildContactsWithOppsForAccount();

        Test.startTest();
        List<Contact> contacts = [SELECT npo02__NumberOfClosedOpps__c FROM Contact];
        System.assertEquals(0, contacts[0].npo02__NumberOfClosedOpps__c, 'There should be no calculated rollups at this point');
        System.assertEquals(0, contacts[1].npo02__NumberOfClosedOpps__c, 'There should be no calculated rollups at this point');
        merge contactsToMerge[0] contactsToMerge[1];
        Test.stopTest();

        contacts = [SELECT npo02__NumberOfClosedOpps__c FROM Contact];
        System.assertEquals(1, contacts.size(), 'There should only be one contact after merge');
        System.assertEquals(2, contacts[0].npo02__NumberOfClosedOpps__c, 'The rollup should have been calculated on the remaining contact');
    }

    /*******************************************************************************************************************
    * @description Builds and inserts contacts with one opportunity each for a single account; disables all Rollup
    * related triggers prior to inserting the test data. This is needed more to prevent any async methods from being
    * queued/executed during insert that might impact other async methods that are supposed to be executed during
    * the merge. For purposes of these tests, we're more interested in ensuring the rollups execute after the
    * merge completes as opposed to when test records are inserted.
    */
    private static List<Contact> buildContactsWithOppsForAccount() {

        // Disable all rollup triggers before creating test data
        UTIL_UnitTestData_TEST.disableRollupTriggers();
        UTIL_UnitTestData_TEST.disableCustomizableRollupTriggers();

        UTIL_UnitTestData_TEST.createAccountContactTestData(CAO_Constants.HH_ACCOUNT_TYPE, 1, 2, uniqueCounter);
        List<Contact> contacts = UTIL_UnitTestData_TEST.listConT;

        List<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactWithAccountList(
            contacts,
            null,
            UTIL_UnitTestData_TEST.getclosedWonStage(),
            System.Today(),
            100,
            null,
            null
        );

        insert listOpp;

        // Re-enable Legacy Rollup Triggers
        TDTM_ProcessControl.toggleTriggerState('Opportunity', 'RLLP_OppRollup_TDTM', true);
        TDTM_ProcessControl.toggleTriggerState('Task', 'EP_TaskRollup_TDTM', true);

        // Re-enable CRLP Rollup Triggers
        TDTM_ProcessControl.toggleTriggerState('Opportunity', 'CRLP_Rollup_TDTM', true);
        TDTM_ProcessControl.toggleTriggerState('npe01__OppPayment__c', 'CRLP_Rollup_TDTM', true);

        return contacts;
    }

}