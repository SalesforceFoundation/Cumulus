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
* @description Tests for Account Merge scenarios including:
*   HH - HH
*   One2One - One2One
*   Org - Org
*   Org - HH
*   HH - Org
*   Org - One2One
*   One2One - Org
* @group Accounts
*/

@isTest
private with sharing class ACCT_AccountMerge_TEST {

    /*******************************************************************************************************
    * @description set the Account Model processor for the test.
    * @param strProcessor The Processor to set
    */
    private static void setAccountModelForTest(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (
                npe01__Account_Processor__c = strProcessor,
                Organizational_Account_Addresses_Enabled__c = true
                ));
    }
    
    /*******************************************************************************************************
    * @description Merge two Household Accounts and verify: 
    *   the account's names and greetings are updated.
    *   Opps are moved over.
    *   Opp Rollups are recalculated.
    *   Soft Credits are recalculated.
    *   Addresses are merged.
    */
    static testMethod void testMergeTwoHHAccounts() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        integer cHH;
        integer cCon;
        
        setAccountModelForTest(CAO_Constants.HH_ACCOUNT_PROCESSOR);
        
        // create our source account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(CAO_Constants.HH_ACCOUNT_TYPE, 2, 2, 1);        

        // this creates some test opps
        list<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactList(UTIL_UnitTestData_TEST.listConT, null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(), System.Today(), 100, null, null);
        insert listOpp;        

        // decide who wins (and remember who was primary contact)
        Account accWinner = [select Id, Name, npe01__One2OneContact__c from Account where Id = :UTIL_UnitTestData_TEST.listAccT[1].Id];
        Account accLoser = UTIL_UnitTestData_TEST.listAccT[0];
        
        // merge the Accounts
        Test.startTest();
        merge accWinner accLoser;
        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our contacts and accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, npe01__One2OneContact__c, Number_Of_Household_Members__c,
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account order by Id]);
        list<Contact> listCon = [select Id, Firstname, AccountId, 
            is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Id];
            
        // verify the accounts and contacts
        System.assertEquals(1, listAcc.size());
        System.assertEquals(accWinner.Id, listAcc[0].Id);
        System.assertEquals(4, listCon.size());
                    
        // verify the contacts belong to correct account.
        System.assertEquals(listCon[0].AccountId, listAcc[0].Id);
        System.assertEquals(listCon[1].AccountId, listAcc[0].Id);
        System.assertEquals(listCon[2].AccountId, listAcc[0].Id);
        System.assertEquals(listCon[3].AccountId, listAcc[0].Id);
        
        // verify that primary contact did not change
        System.assertEquals(accWinner.npe01__One2OneContact__c, listAcc[0].npe01__One2OneContact__c);        
            
        // verify the account's greetings are updated (lastnames are the same so the account name won't change!)
        System.assertEquals(4, listAcc[0].Number_Of_Household_Members__c);
        System.assertEquals(true, listAcc[0].npo02__Formal_Greeting__c.contains(listCon[0].Firstname));        
        System.assertEquals(true, listAcc[0].npo02__Formal_Greeting__c.contains(listCon[1].Firstname));        
        System.assertEquals(true, listAcc[0].npo02__Formal_Greeting__c.contains(listCon[2].Firstname));        
        System.assertEquals(true, listAcc[0].npo02__Formal_Greeting__c.contains(listCon[3].Firstname));        
        
        // verify opps are moved over
        System.assertEquals(4, [select count() from Opportunity where AccountId = :listAcc[0].Id]);  
            
        // verify Account rollups are updated
        System.assertEquals(4, listAcc[0].npo02__NumberOfClosedOpps__c);            

        // verify Soft Credits recalculated
        System.assertEquals(4, [select count() from OpportunityContactRole where ContactId = :listCon[0].Id]);        
        System.assertEquals(4, [select count() from OpportunityContactRole where ContactId = :listCon[1].Id]);        
        System.assertEquals(4, [select count() from OpportunityContactRole where ContactId = :listCon[2].Id]);        
        System.assertEquals(4, [select count() from OpportunityContactRole where ContactId = :listCon[3].Id]);    
        
        // verify Addresses are merged
        System.assertEquals(4, [select count() from Address__c]);
        System.assertEquals(1, [select count() from Address__c where Default_Address__c = true]);    
    }

    /*******************************************************************************************************
    * @description Merge three Household Accounts with multiple addresses and verify:
    *   - duplicate addresses are removed
    *   - contacts with address overrides to deleted addresses are updated
    *   - only one default address
    *   - default address correctly pushed to appropriate contacts. 
    */
    static testMethod void testMergeThreeHHAccountsManyAddr() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        integer cHH;
        integer cCon;
        
        setAccountModelForTest(CAO_Constants.HH_ACCOUNT_PROCESSOR);

        // this creates 3 Household Accounts, each with 2 Contacts, and a default Address for each HH
        ADDR_Addresses_TEST.createTestData(cHH = 3, cCon = 2);
        
        // create an address override in each household
        for (integer i = 0; i < cHH; i++) {
            Contact con = ADDR_Addresses_TEST.testContacts[i * cCon + 1];
            con.MailingStreet = '123 abc';
            con.MailingCity = 'Seattle';
            con.MailingState = 'Washington';
            con.MailingPostalCode = '98005';
            con.MailingCountry = 'United States';
            con.is_Address_Override__c = true;
        }
        update ADDR_Addresses_TEST.testContacts;

        // decide who wins (and remember who was primary contact)
        Account accWinner = [SELECT Id, Name, npe01__One2OneContact__c FROM Account WHERE Id = :ADDR_Addresses_TEST.testAccounts[1].Id];
        list<Account> listAccLoser = new list<Account>();
        listAccLoser.add(ADDR_Addresses_TEST.testAccounts[0]);
        listAccLoser.add(ADDR_Addresses_TEST.testAccounts[2]);
        
        // merge the Accounts
        Test.startTest();
        merge accWinner listAccLoser;

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our contacts and accounts
        list<Account> listAcc = new list<Account>([SELECT Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, npe01__One2OneContact__c, Number_Of_Household_Members__c,
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            FROM Account ORDER BY Id]);
        list<Contact> listCon = [SELECT Id, Firstname, AccountId, 
            is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            FROM Contact ORDER BY Id];
            
        // verify the accounts and contacts
        System.assertEquals(1, listAcc.size());
        System.assertEquals(accWinner.Id, listAcc[0].Id);
        System.assertEquals(cHH * cCon, listCon.size());
                    
        // verify Addresses are merged
        System.assertEquals(cHH + 1, [SELECT count() FROM Address__c]);
        System.assertEquals(1, [SELECT count() FROM Address__c WHERE Default_Address__c = true]);  
        Address__c addrDefault = [SELECT Id, Default_Address__c, MailingStreet__c, MailingCity__c FROM Address__c WHERE Default_Address__c = true]; 
        
        // verify overrides
        Address__c targetAddr = null;
        for (Address__c addr : [SELECT Id, MailingStreet__c FROM Address__c WHERE Default_Address__c = false]) {
            if (addr.MailingStreet__c == '123 abc') {
                targetAddr = addr;
                break;
            }
        }
        System.assertNotEquals(null, targetAddr, 'A non-default address should be returned.');

        for (integer i = 0; i < listCon.size(); i++) {
        	Contact con = listCon[i];
        	if (con.is_Address_Override__c) {
                System.assertEquals(targetAddr.MailingStreet__c, con.MailingStreet,
                    'The mailing street should match contact mailing street when contact has override address');
                System.assertEquals(targetAddr.Id, con.Current_Address__c,
                'The address should be the current address on the contact when contact has override address');
        	} else {
                System.assertEquals(addrDefault.MailingStreet__c, con.MailingStreet,
                    'The default address should be populated on contact when address is not overrided');
                System.assertEquals(addrDefault.Id, con.Current_Address__c,
                    'The default address should be populated on contact when address is not overrided');        	   
        	}
        } 
    }

    /*******************************************************************************************************
    * @description Merge two One2One Accounts and verify: 
    *   Opps are moved over.
    *   Opp Rollups are recalculated.
    */
    static testMethod void testMergeTwoOne2OneAccounts() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        setAccountModelForTest(CAO_Constants.ONE_TO_ONE_PROCESSOR);
        
        list<Contact> listCon = UTIL_UnitTestData_TEST.CreateMultipleTestContacts(2);
        insert listCon;
        
        List<Opportunity> listOppCon = UTIL_UnitTestData_TEST.OppsForContactList (listCon, null, 
            UTIL_UnitTestData_TEST.getClosedWonStage(), System.Today(), 100, null, null);
        insert listOppCon;

        list<Account> listAcc = [select Id, Name, npe01__One2OneContact__c from Account];
        System.assertEquals(2, listAcc.size());
        List<Opportunity> listOppAcc = UTIL_UnitTestData_TEST.OppsForAccountList (listAcc, null, 
            UTIL_UnitTestData_TEST.getClosedWonStage(), System.Today(), 100, null, null);
        insert listOppAcc;

        // decide who wins (and remember who was primary contact)
        Account accWinner = listAcc[1];
        Account accLoser = listAcc[0];
        
        // merge the Accounts
        Test.startTest();
        merge accWinner accLoser;

        // to flush our future calls that fix related data up!    
        Test.stopTest();

        // reload our contacts and accounts
        listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, npe01__One2OneContact__c from Account order by Id]);
        listCon = [select Id, Firstname, AccountId from Contact order by Id];
            
        // verify the accounts and contacts
        System.assertEquals(1, listAcc.size());
        System.assertEquals(accWinner.Id, listAcc[0].Id);
        System.assertEquals(2, listCon.size());
                    
        // verify the contacts belong to correct account.
        System.assertEquals(listCon[0].AccountId, listAcc[0].Id);
        System.assertEquals(listCon[1].AccountId, listAcc[0].Id);
        
        // verify that primary contact did not change
        System.assertEquals(accWinner.npe01__One2OneContact__c, listAcc[0].npe01__One2OneContact__c);        
                    
        // verify opps are moved over
        System.assertEquals(4, [select count() from Opportunity where AccountId = :listAcc[0].Id]);  
            
        // verify Account rollups are updated
        System.assertEquals(4, listAcc[0].npo02__NumberOfClosedOpps__c);            
    }

    /*******************************************************************************************************
    * @description Merge three Organizational Accounts with multiple addresses and verify:
    *   - duplicate addresses are removed
    *   - only one default address
    */
    static testMethod void testMergeThreeOrgAccountsManyAddr() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        TDTM_DefaultConfig.startTestDataInit();
        integer cAcc = 3;
        
        // enables org account addresses
        setAccountModelForTest(CAO_Constants.HH_ACCOUNT_PROCESSOR);
 
        list<Account> listAcc = UTIL_UnitTestData_TEST.CreateMultipleTestAccounts(cAcc, null);
                
        // create an address override in each account
        for (integer i = 0; i < cAcc; i++) {
            Account acc = listAcc[i];
            acc.BillingStreet = '123 abc';
            acc.BillingCity = 'Seattle';
            acc.BillingState = 'Washington';
            acc.BillingPostalCode = '98005';
            acc.BillingCountry = 'United States';
        }
        
        insert listAcc;

        // create one additional unique address
        Account acc = listAcc[0];
        acc.BillingStreet = '987 xyz';
        acc.BillingCity = 'Bellevue';
        update acc;
        System.assertEquals(4, [select count() from Address__c]);
        System.assertEquals(3, [select count() from Address__c where Default_Address__c = true]);  

        // decide who wins (and remember who was primary contact)
        Account accWinner = listAcc[1];
        list<Account> listAccLoser = new list<Account>();
        listAccLoser.add(listAcc[0]);
        listAccLoser.add(listAcc[2]);
        
        // merge the Accounts
        TDTM_DefaultConfig.stopTestDataInit();
        Test.startTest();
        merge accWinner listAccLoser;

        // to flush our future calls that fix related data up!        
        Test.stopTest();

        // reload our accounts
        listAcc = new list<Account>([select Id, Name, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account order by Id]);
            
        // verify the accounts 
        System.assertEquals(1, listAcc.size());
        System.assertEquals(accWinner.Id, listAcc[0].Id);
                    
        // verify Addresses are merged
        System.assertEquals(2, [select count() from Address__c]);
        System.assertEquals(1, [select count() from Address__c where Default_Address__c = true]);  
        Address__c addrDefault = [select Id, Default_Address__c, MailingStreet__c, MailingCity__c from Address__c where Default_Address__c = true];
        System.assertEquals(addrDefault.MailingStreet__c, listAcc[0].BillingStreet); 
        
    }

    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeHHToHH() {
        testNamesAndOppsMerge(CAO_Constants.HH_ACCOUNT_TYPE, CAO_Constants.HH_ACCOUNT_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOne2OneToOne2One() {
        testNamesAndOppsMerge(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOrgToHH() {
        testNamesAndOppsMerge(null, CAO_Constants.HH_ACCOUNT_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeHHToOrg() {
        testNamesAndOppsMerge(CAO_Constants.HH_ACCOUNT_TYPE, null);
    }

    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOrgToOne2One() {
        testNamesAndOppsMerge(null, CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE);
    }

    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    * are updated as appropriate for the account types.
    */ 
    static testmethod void testNamesAndOppsMergeOne2OneToOrg() {
        testNamesAndOppsMerge(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, null);
    }
    
    /*******************************************************************************************************
    * @description Merge two different Accounts and verifies Opps, OCRs, Rollups, and Names
    *   the account's names and greetings are updated.
    *   Opps moved to winning account
    *   Soft Credits for all Opps are recalculated.
    *   Opp Rollups are recalculated for the winning account
    */
    static void testNamesAndOppsMerge(string accTypeLoser, string accTypeWinner) {
    
        // create our source account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(accTypeLoser, 1, 2, 1);
        Account accLoser = UTIL_UnitTestData_TEST.listAccT[0];
        list<Contact> listConAll = UTIL_UnitTestData_TEST.listConT; 
        
        // create our destination account and contacts
        UTIL_UnitTestData_TEST.createAccountContactTestData(accTypeWinner, 1, 2, 3);
        Account accWinner = UTIL_UnitTestData_TEST.listAccT[0];
        listConAll.addAll(UTIL_UnitTestData_TEST.listConT);        
        
        // create an opp for each contact
        list<Opportunity> listOpp = UTIL_UnitTestData_TEST.OppsForContactList(listConAll, null, 
            UTIL_UnitTestData_TEST.getclosedWonStage(), System.Today(), 100, null, null);
        insert listOpp;
        
        // merge the accounts
        Test.startTest();
        merge accWinner accLoser;
        Test.stopTest();

        // reload our contacts and accounts
        list<Account> listAcc = new list<Account>([select Id, Name, npo02__Formal_Greeting__c, npo02__Informal_Greeting__c, 
            npo02__NumberOfClosedOpps__c, 
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
            from Account order by Id]);
        System.assertEquals(1, listAcc.size());
        accWinner = listAcc[0];
        list<Contact> listCon = [select Id, Firstname, AccountId, 
            is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
            from Contact order by Id];
            
        // verify the contacts belong to correct account.
        System.assertEquals(listCon[0].AccountId, accWinner.Id);
        System.assertEquals(listCon[1].AccountId, accWinner.Id);
        System.assertEquals(listCon[2].AccountId, accWinner.Id);
        System.assertEquals(listCon[3].AccountId, accWinner.Id);
            
        // verify the account's names and greetings are updated
        if (accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            System.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(listCon[0].Firstname));    
            System.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(listCon[1].Firstname));    
            System.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(listCon[2].Firstname));    
            System.assertEquals(true, accWinner.npo02__Formal_Greeting__c.contains(listCon[3].Firstname));    
        } else if (accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            System.assertEquals(false, accWinner.Name.contains('Anonymous'));    
        }
                
        integer cAccOpps = [select count() from Opportunity];
        integer cOCRCon0 = [select count() from OpportunityContactRole where ContactId = :listCon[0].Id];
        integer cOCRCon1 = [select count() from OpportunityContactRole where ContactId = :listCon[1].Id];
        integer cOCRCon2 = [select count() from OpportunityContactRole where ContactId = :listCon[2].Id];
        integer cOCRCon3 = [select count() from OpportunityContactRole where ContactId = :listCon[3].Id];
        
        // verify Opps, OCR's, and Rollups are what we expect!
        if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE && accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            System.assertEquals(4, cAccOpps);
            System.assertEquals(4, cOCRCon0);
            System.assertEquals(4, cOCRCon1);
            System.assertEquals(4, cOCRCon2);
            System.assertEquals(4, cOCRCon3);
            System.assertEquals(4, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE && accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            System.assertEquals(4, cAccOpps);
            System.assertEquals(1, cOCRCon0);
            System.assertEquals(1, cOCRCon1);
            System.assertEquals(1, cOCRCon2);
            System.assertEquals(1, cOCRCon3);
            System.assertEquals(4, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == CAO_Constants.HH_ACCOUNT_TYPE) {
            System.assertEquals(4, cAccOpps);
            System.assertEquals(3, cOCRCon0);
            System.assertEquals(3, cOCRCon1);
            System.assertEquals(2, cOCRCon2);
            System.assertEquals(2, cOCRCon3);
            System.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.HH_ACCOUNT_TYPE && accTypeWinner == null) {
            System.assertEquals(4, cAccOpps);
            System.assertEquals(2, cOCRCon0);
            System.assertEquals(2, cOCRCon1);
            System.assertEquals(1, cOCRCon2);
            System.assertEquals(1, cOCRCon3);
            System.assertEquals(0, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == null && accTypeWinner == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE) {
            System.assertEquals(4, cAccOpps);
            System.assertEquals(1, cOCRCon0);
            System.assertEquals(1, cOCRCon1);
            System.assertEquals(1, cOCRCon2);
            System.assertEquals(1, cOCRCon3);
            System.assertEquals(2, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        else if (accTypeLoser == CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE && accTypeWinner == null) {
            System.assertEquals(4, cAccOpps);
            System.assertEquals(1, cOCRCon0);
            System.assertEquals(1, cOCRCon1);
            System.assertEquals(1, cOCRCon2);
            System.assertEquals(1, cOCRCon3);
            System.assertEquals(0, accWinner.npo02__NumberOfClosedOpps__c);            
        }
        
    }
}