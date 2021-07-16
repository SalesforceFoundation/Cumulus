/*
    Copyright (c) 2014, Salesforce.org
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
* @date 2013
* @group Address Management
* @description Tests specific to Address Management. 
*/

@IsTest
public with sharing class ADDR_Addresses_TEST2 {

    /*********************************************************************************************************
    * @description Holds the number of Households to create in tests.
    */
    static Integer cHH = 2;

    /*********************************************************************************************************
    * @description Holds the number of Contacts per Household to create in tests.
    */
    static Integer cCon = 2;

    /*********************************************************************************************************
    * @description The list of created test Contacts.
    */
    private static List<Contact> listConT;

    /*********************************************************************************************************
    * @description The list of created test Accounts.
    */
    private static List<Account> listAccT;

    /*********************************************************************************************************
    * @description The list of created test Addresses.
    */
    private static List<Address__c> listAddrT;

    private static OrgConfig orgConfig = new OrgConfig();

    /*********************************************************************************************************
    * @description
    * utility to set up common test data for the Address tests.
    *    - this will create & insert N household Accounts, each with M contacts
    *    - also will create a Default Addresses for each HH Account
    *    - will also setup the default Account Processor to be HH Accounts
    * @param cHHT the number of Household Accounts to create
    * @param cConT the number of Contacts to create per Household
    **********************************************************************************************************/
    private static void createHHTestData(Integer cHHT, Integer cConT) {
        ADDR_Addresses_TEST.createTestData(cHHT, cConT);
        listConT = ADDR_Addresses_TEST.testContacts;
        listAccT = ADDR_Addresses_TEST.testAccounts;
        listAddrT = ADDR_Addresses_TEST.testAddresses;
    }

    /*********************************************************************************************************
    * @description Initializes (but not inserts) N new Address objects.
    * @param cAddr the number of Address objects to create
    **********************************************************************************************************/
    private static void initTestAddr(Integer cAddr) {
        ADDR_Addresses_TEST.buildTestAddress(cAddr);
        listAddrT = ADDR_Addresses_TEST.testAddresses;
    }
    
    /*********************************************************************************************************
    @description
        update seasonal addresses to current, on HH w/ existing default addresses  
    verify:
        contact's && hh address updated to seasonal address
        old default addresses still marked default
    **********************************************************************************************************/
    @IsTest
    static void updateSeasonalAddr() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional seasonal addresses not current
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(1).month());
            listAddrT[i].Seasonal_Start_Day__c = '1';
            listAddrT[i].Seasonal_End_Month__c = String.valueOf(System.today().addMonths(2).month());
            listAddrT[i].Seasonal_End_Day__c = '28';
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        insert listAddrT;

        // now make them current
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(-1).month());
        }
        Test.startTest();
        update listAddrT;
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.contains('New Seasonal Street'));
            System.assert(con.MailingCity.contains('New Seasonal City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
        
        // verify the previous addresses still are Default
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c, Latest_Start_Date__c, Latest_End_Date__c FROM Address__c];
        System.assertEquals(cHH * 2, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean fSeasonal = (addr.MailingStreet__c.contains('New Seasonal Street'));
            System.assertEquals(!fSeasonal, addr.Default_Address__c);
        }        
    }

    /*********************************************************************************************************
    @description
        delete current seasonal addresses  
    verify:
        contact's && hh address updated to default
    **********************************************************************************************************/
    @IsTest
    static void deleteSeasonalAddr() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional seasonal addresses current
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(-1).month());
            listAddrT[i].Seasonal_Start_Day__c = '1';
            listAddrT[i].Seasonal_End_Month__c = String.valueOf(System.today().addMonths(2).month());
            listAddrT[i].Seasonal_End_Day__c = '28';
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        insert listAddrT;

        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.contains('New Seasonal Street'));
            System.assert(con.MailingCity.contains('New Seasonal City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
        
        // now delete the seasonal addresses
        Test.startTest();
        delete listAddrT;                
        Test.stopTest();
        
        // verify the default address is restored
        mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals(false, con.MailingStreet.contains('New Seasonal Street'));
            System.assertEquals(false, con.MailingCity.contains('New Seasonal City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
    }

    /*********************************************************************************************************
    @description
        create multiple seasonal address that overlap with eachother  
    verify:
        overlap detected, seasonal addresses don't save
    **********************************************************************************************************/
    @IsTest
    static void insertSeasonalAddrWithOverlap() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional seasonal addresses not current
        initTestAddr(cHH * 2);
        for (Integer i = 0; i < cHH * 2; i++) {
            Integer iacc = i < cHH ? i : i-cHH;
            if (Math.mod(i, 2) == 0) {
                listAddrT[i].Household_Account__c = listAccT[iacc].Id;
                listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(1).month());
                listAddrT[i].Seasonal_Start_Day__c = '1';
                listAddrT[i].Seasonal_End_Month__c = String.valueOf(System.today().addMonths(3).month());
                listAddrT[i].Seasonal_End_Day__c = '28';
            } else {
                listAddrT[i].Household_Account__c = listAccT[iacc-1].Id;
                listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(-1).month());
                listAddrT[i].Seasonal_Start_Day__c = '1';
                listAddrT[i].Seasonal_End_Month__c = String.valueOf(System.today().addMonths(2).month());
                listAddrT[i].Seasonal_End_Day__c = '28';            
            }
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        try {
            Test.startTest();
            insert listAddrT;
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains(Label.addrSeasonalOverlap));
            return;
        }
        System.assert(false); //we shouldn't get here!
        
    }

    /*********************************************************************************************************
    @description
        create multiple seasonal address that overlap with eachother  
    verify:
        overlap detected
    **********************************************************************************************************/
    @IsTest
    static void testSeasonalAddrOverlapLogic() {
        Address__c a1 = new Address__c();
        Address__c a2 = new Address__c();

        // test both increasing ranges, no overlap
        a1.Seasonal_Start_Month__c = '1';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '3';
        a1.Seasonal_End_Day__c = '28';
        a2.Seasonal_Start_Month__c = '4';
        a2.Seasonal_Start_Day__c = '1';
        a2.Seasonal_End_Month__c = '6';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(false, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(false, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));
        
        // test both increasing ranges, with overlap
        a2.Seasonal_Start_Month__c = '2';
        a2.Seasonal_End_Month__c = '6';
        System.assertEquals(true, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(true, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));
        
        // test one increasing range, one decreasing range, no overlap
        a1.Seasonal_Start_Month__c = '3';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '5';
        a1.Seasonal_End_Day__c = '28';
        a2.Seasonal_Start_Month__c = '11';
        a2.Seasonal_Start_Day__c = '1';
        a2.Seasonal_End_Month__c = '2';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(false, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(false, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));

        // test one increasing range, one decreasing range, with overlap
        a2.Seasonal_Start_Month__c = '11';
        a2.Seasonal_Start_Day__c = '1';
        a2.Seasonal_End_Month__c = '4';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(true, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(true, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));

        // test both decreasing ranges, always overlap
        a1.Seasonal_Start_Month__c = '9';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '2';
        a1.Seasonal_End_Day__c = '28';
        a2.Seasonal_Start_Month__c = '12';
        a2.Seasonal_Start_Day__c = '1';
        a2.Seasonal_End_Month__c = '3';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(true, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(true, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));
        
        // test both increasing ranges in the same month, no overlap
        a1.Seasonal_Start_Month__c = '2';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '2';
        a1.Seasonal_End_Day__c = '10';
        a2.Seasonal_Start_Month__c = '2';
        a2.Seasonal_Start_Day__c = '11';
        a2.Seasonal_End_Month__c = '2';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(false, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(false, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));

        // test both increasing ranges in the same month, with overlap
        a1.Seasonal_Start_Month__c = '2';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '2';
        a1.Seasonal_End_Day__c = '10';
        a2.Seasonal_Start_Month__c = '2';
        a2.Seasonal_Start_Day__c = '10';
        a2.Seasonal_End_Month__c = '2';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(true, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(true, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));

        // test one increasing range, one decreasing range in the same month, no overlap
        a1.Seasonal_Start_Month__c = '2';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '2';
        a1.Seasonal_End_Day__c = '10';
        a2.Seasonal_Start_Month__c = '2';
        a2.Seasonal_Start_Day__c = '11';
        a2.Seasonal_End_Month__c = '1';
        a2.Seasonal_End_Day__c = '28';
        System.assertEquals(false, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(false, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));

        // test one increasing range, one decreasing range in the same month, with overlap
        a1.Seasonal_Start_Month__c = '2';
        a1.Seasonal_Start_Day__c = '1';
        a1.Seasonal_End_Month__c = '2';
        a1.Seasonal_End_Day__c = '10';
        a2.Seasonal_Start_Month__c = '2';
        a2.Seasonal_Start_Day__c = '11';
        a2.Seasonal_End_Month__c = '2';
        a2.Seasonal_End_Day__c = '1';
        System.assertEquals(true, new NPSP_Address(a1).overlapsWith(new NPSP_Address(a2)));
        System.assertEquals(true, new NPSP_Address(a2).overlapsWith(new NPSP_Address(a1)));
    }

    /*********************************************************************************************************
    @description
        create multiple seasonal address that overlap existing seasonal addresses  
    verify:
        overlap detected, seasonal addresses don't save
    **********************************************************************************************************/
    @IsTest
    static void insertSeasonalAddrOverlapExisting() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional seasonal addresses not current
        initTestAddr(cHH);
        Date dtTest = Date.newInstance(System.today().year(), 6, 1);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(dtTest.addMonths(1).month());
            listAddrT[i].Seasonal_Start_Day__c = '1';
            listAddrT[i].Seasonal_End_Month__c = String.valueOf(dtTest.addMonths(3).month());
            listAddrT[i].Seasonal_End_Day__c = '28';
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        insert listAddrT;
        
        // create additional seasonal addresses that overlap existing seasonal addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(dtTest.addMonths(2).month());
            listAddrT[i].Seasonal_Start_Day__c = '1';
            listAddrT[i].Seasonal_End_Month__c = String.valueOf(dtTest.addMonths(4).month());
            listAddrT[i].Seasonal_End_Day__c = '28';
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        try {
            Test.startTest();
            insert listAddrT;
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains(Label.addrSeasonalOverlap));
            return;
        }
        System.assert(false); //we shouldn't get here!
        
    }

    /*********************************************************************************************************
    @description
        create multiple partial seasonal address  
    verify:
        partial seasonal detected, seasonal addresses don't save
    **********************************************************************************************************/
    @IsTest
    static void insertPartialSeasonalAddr() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional seasonal addresses not current
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(1).month());
            listAddrT[i].Seasonal_Start_Day__c = '1';
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        try {
            Test.startTest();
            insert listAddrT;
            Test.stopTest();
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains(Label.addrSeasonalPartial));
            return;
        }
        System.assert(false); //we shouldn't get here!
        
    }

    /*********************************************************************************************************
    @description
        schedule a seasonal address update 
    verify:
        contact's && hh address matches new seasonal
        old default addresses still marked default
    **********************************************************************************************************/
    @IsTest
    static void scheduleSeasonalAddrUpdate() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().month());
            listAddrT[i].Seasonal_Start_Day__c = String.valueOf(System.today().day());
            listAddrT[i].Seasonal_End_Month__c = String.valueOf(System.today().addMonths(1).month());
            listAddrT[i].Seasonal_End_Day__c = '28';
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        
        // Hack!  by setting our trigger handler as run,
        // we can insert the new seasonal addresses but not have them processed.
        // this way we can test the scheduled job!
        insert listAddrT;

        setSeasonalAddressBatchSize(10);

        // run the scheduled batch directly
        Test.startTest();
        new ADDR_Seasonal_SCHED().execute(null);
        Test.stopTest();

        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.contains('New Seasonal Street'));
            System.assert(con.MailingCity.contains('New Seasonal City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
        
        // verify the previous addresses still are Default
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c, Latest_Start_Date__c, Latest_End_Date__c FROM Address__c];
        System.assertEquals(cHH * 2, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean fSeasonal = (addr.MailingStreet__c.contains('New Seasonal Street'));
            System.assertEquals(!fSeasonal, addr.Default_Address__c);
        }        
    }

    /*********************************************************************************************************
    @description
        reset a seasonal address thru the scheduler 
    verify:
        contact's && hh address matches new seasonal
        old default addresses still marked default
    **********************************************************************************************************/
    @IsTest
    static void scheduleSeasonalAddrReset() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].Seasonal_Start_Month__c = String.valueOf(System.today().addMonths(-2).month());
            listAddrT[i].Seasonal_Start_Day__c = '1';
            listAddrT[i].Seasonal_End_Month__c = String.valueOf(System.today().addMonths(1).month());
            listAddrT[i].Seasonal_End_Day__c = '1';
            listAddrT[i].MailingStreet__c = 'New Seasonal Street' + i;
            listAddrT[i].MailingCity__c = 'New Seasonal City' + i;
        }
        
        // this should update the hh and contacts to the seasonal addresses
        insert listAddrT;
        
        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.contains('New Seasonal Street'));
            System.assert(con.MailingCity.contains('New Seasonal City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }

        // now let's update the seasonal addresses to no longer be active, but disable triggers for now
        // this way we can test the scheduled job!
        for (Address__c addr : listAddrT) {
            addr.Seasonal_End_Month__c = String.valueOf(System.today().addMonths(-1).month());
        }
        // Hack!  by setting our trigger handler as run,
        // we can insert the new seasonal addresses but not have them processed.
        // this way we can test the scheduled job!
        update listAddrT;

        setSeasonalAddressBatchSize(10);

        // run the scheduled batch directly
        Test.startTest();
        new ADDR_Seasonal_SCHED().execute(null);
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address and it's the old default!
        mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.startsWith('Street'));
            System.assert(con.MailingCity.startsWith('City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
        
        // verify the previous addresses still are Default
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c, Latest_Start_Date__c, Latest_End_Date__c FROM Address__c];
        System.assertEquals(cHH * 2, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean fSeasonal = (addr.MailingStreet__c.contains('New Seasonal Street'));
            System.assertEquals(!fSeasonal, addr.Default_Address__c);
        }        
    }

    /*********************************************************************************************************
    @description
        create N new duplicate Addresses from Account  
    verify:
        duplicates not created
    **********************************************************************************************************/
    @IsTest
    static void newDupeAccountAddr() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // create additional addresses thru the account.
        for (Integer i = 0; i < cHH; i++) {
            listAccT[i].BillingStreet = listAddrT[i].MailingStreet__c;
            listAccT[i].BillingCity = listAddrT[i].MailingCity__c;
            listAccT[i].BillingState = listAddrT[i].MailingState__c;
            listAccT[i].BillingPostalCode = listAddrT[i].MailingPostalCode__c;
            listAccT[i].BillingCountry = listAddrT[i].MailingCountry__c;
        }        
        Test.startTest();
        update listAccT;
        Test.stopTest();
        
        // verify that we don't have new Addresses
        List<Address__c> listAddr = [SELECT Id FROM Address__c];
        System.assertEquals(cHH, listAddr.size());
    }

    /*********************************************************************************************************
    @description
        create N new duplicate Addresses from Contact  
    verify:
        duplicates not created
    **********************************************************************************************************/
    @IsTest
    static void newDupeContactAddr() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // create additional addresses thru the contact.
        for (Integer i = 0; i < cHH; i++) {
            for (Integer j = 0; j < cCon; j++) {
                listConT[(i * cHH) + j].MailingStreet = listAddrT[i].MailingStreet__c;
                listConT[(i * cHH) + j].MailingCity = listAddrT[i].MailingCity__c;
                listConT[(i * cHH) + j].MailingState = listAddrT[i].MailingState__c;
                listConT[(i * cHH) + j].MailingPostalCode = listAddrT[i].MailingPostalCode__c;
                listConT[(i * cHH) + j].MailingCountry = listAddrT[i].MailingCountry__c;
            }
        }
        Test.startTest();
        update listConT;
        Test.stopTest();
        
        // verify that we don't have new Addresses
        List<Address__c> listAddr = [SELECT Id FROM Address__c];
        System.assertEquals(cHH, listAddr.size());
    }

    /*********************************************************************************************************
    @description
        create N new duplicate Addresses from Account, with non-default existing  
    verify:
        duplicates not created
        found match becomes Default
    **********************************************************************************************************/
    @IsTest
    static void newDupeAccountAddrNonDefault() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

         // create additional non-default addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'New Street' + i;
            listAddrT[i].MailingCity__c = 'New City' + i;
        }
        insert listAddrT;

        // create additional addresses thru the account.
        for (Integer i = 0; i < cHH; i++) {
            listAccT[i].BillingStreet = listAddrT[i].MailingStreet__c;
            listAccT[i].BillingCity = listAddrT[i].MailingCity__c;
            listAccT[i].BillingState = listAddrT[i].MailingState__c;
            listAccT[i].BillingPostalCode = listAddrT[i].MailingPostalCode__c;
            listAccT[i].BillingCountry = listAddrT[i].MailingCountry__c;
        }        
        Test.startTest();
        update listAccT;
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.contains('New Street'));
            System.assert(con.MailingCity.contains('New City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
        
        // verify the new addresses still are Default and we don't have too many
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c, Latest_Start_Date__c, Latest_End_Date__c FROM Address__c];
        System.assertEquals(cHH * 2, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean isNew = (addr.MailingStreet__c.contains('New Street'));
            System.assertEquals(isNew, addr.Default_Address__c);
        }        
 
    }

    /*********************************************************************************************************
    @description
        create N new duplicate Addresses from Contact, with non-default existing  
    verify:
        duplicates not created
        found match becomes Default
    **********************************************************************************************************/
    @IsTest
    static void newDupeContactAddrNonDefault() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

         // create additional non-default addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'New Street' + i;
            listAddrT[i].MailingCity__c = 'New City' + i;
        }
        insert listAddrT;

        // create additional addresses thru the contact.
        for (Integer i = 0; i < cHH; i++) {
            for (Integer j = 0; j < cCon; j++) {
                listConT[(i * cHH) + j].MailingStreet = listAddrT[i].MailingStreet__c;
                listConT[(i * cHH) + j].MailingCity = listAddrT[i].MailingCity__c;
                listConT[(i * cHH) + j].MailingState = listAddrT[i].MailingState__c;
                listConT[(i * cHH) + j].MailingPostalCode = listAddrT[i].MailingPostalCode__c;
                listConT[(i * cHH) + j].MailingCountry = listAddrT[i].MailingCountry__c;
            }
        }        
        Test.startTest();
        update listConT;
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assert(con.MailingStreet.contains('New Street'));
            System.assert(con.MailingCity.contains('New City'));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
        
        // verify the new addresses still are Default and we don't have too many
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c, Latest_Start_Date__c, Latest_End_Date__c FROM Address__c];
        System.assertEquals(cHH * 2, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean isNew = (addr.MailingStreet__c.contains('New Street'));
            System.assertEquals(isNew, addr.Default_Address__c);
        }        
 
    }

    /*********************************************************************************************************
    @description
        update contacts' mailing address when they have an address override
    verify:
        new non-default Address created
        contact override updated to new address
        only the contact gets the new Address
    **********************************************************************************************************/
    @IsTest
    static void updateConAddrWithOverride() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // create additional addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'override' + i;
            listAddrT[i].MailingCity__c = 'override' + i;
        }
        insert listAddrT;

        // set the contacts' address overrides
        List<Contact> listCon = new List<Contact>();
        for (Integer i = 0; i < cHH; i++) {
            Contact con = listConT[i*cHH + i];
            con.Current_Address__c = listAddrT[i].Id;
            con.is_Address_Override__c = true;
            listCon.add(con);
        }
        update listCon;

        // modify some of the contact addresses directly
        for (Contact con : listCon) {
            con.MailingStreet = 'Direct Street Edit';
            con.MailingCity = 'Direct City Edit';
        }
        Test.startTest();
        update listCon;
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            if (con.is_Address_Override__c == false) {
                System.assertNotEquals(null, con.Current_Address__c);
                System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
                System.assert(!con.MailingStreet.contains('Direct Street Edit'));
                System.assert(!con.MailingCity.contains('Direct City Edit'));
                System.assert(!con.MailingStreet.contains('override'));
                System.assert(!con.MailingCity.contains('override'));
            } else {
                System.assertEquals(false, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
                System.assert(con.MailingStreet.contains('Direct Street Edit'));
                System.assert(con.MailingCity.contains('Direct City Edit'));
                System.assertEquals(true, con.is_Address_Override__c);
                System.assertNotEquals(null, con.Current_Address__c);
            }
        }
 
         // verify the new overrides are not marked default, and that the contact points to them
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c FROM Address__c];
        System.assertEquals(cHH * 3, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean fOverride = (addr.MailingStreet__c.contains('Direct Street Edit'));
            if (fOverride) {
                System.assertEquals(false, addr.Default_Address__c);
                Boolean isSetOnContact = false;
                for (Contact con : listCon) {
                    if (con.is_Address_Override__c && con.Current_Address__c == addr.Id) {
                        isSetOnContact = true;
                    }
                }
                System.assertEquals(true, isSetOnContact);
            }
        }                
    }

    /*********************************************************************************************************
    @description
        update contact's address override to an address in another account
    verify:
        new non-default Address created
        contact override updated to new address
        only the contact gets the new Address
    **********************************************************************************************************/
    @IsTest
    static void updateConAddrWithExternalOverride() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // create additional addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = false;
            listAddrT[i].MailingStreet__c = 'override' + i;
            listAddrT[i].MailingCity__c = 'override' + i;
        }
        insert listAddrT;

        // set the contacts' address overrides to an address in a different household
        List<Contact> listCon = new List<Contact>();
        for (Integer i = 0; i < cHH; i++) {
            Contact con = listConT[i*cHH];  // first contact in the household
            con.Current_Address__c = listAddrT[i == cHH-1 ? 0 : i + 1].Id;  // address in the next household
            con.is_Address_Override__c = true;
            listCon.add(con);
        }
        Test.startTest();
        update listCon;
        Test.stopTest();

        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, MailingCity__c, Household_Account__c FROM Address__c];
        System.debug('****DJH: mapAccIdAcc: ' + mapAccIdAcc);
        System.debug('****DJH: listCon: ' + listCon);
        System.debug('****DJH: listAddr: ' + listAddr);
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            if (con.is_Address_Override__c == false) {
                System.assertNotEquals(null, con.Current_Address__c);
                System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
                System.assert(!con.MailingStreet.contains('override'));
                System.assert(!con.MailingCity.contains('override'));
            } else {
                //system.assertEquals(false, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
                System.assert(con.MailingStreet.contains('override'));
                System.assert(con.MailingCity.contains('override'));
                System.assertEquals(true, con.is_Address_Override__c);
                System.assertNotEquals(null, con.Current_Address__c);
            }
        }
 
         // verify the overrides were copied to their new households
        System.assertEquals(cHH * 3, listAddr.size());
        for (Address__c addr : listAddr) {
            Boolean fOverride = (addr.MailingStreet__c.contains('override'));
            if (fOverride) {
                System.assertEquals(false, addr.Default_Address__c);
                for (Contact con : listCon) {
                    if (con.is_Address_Override__c && con.Current_Address__c == addr.Id) {
                        System.assertEquals(con.AccountId, addr.Household_Account__c);
                    }
                }
            }
        }                
    }

    /*********************************************************************************************************
    @description
        insert new contacts with no addresses to existing households that have default addresses
    verify:
        new contacts get the default hh address
    **********************************************************************************************************/
    @IsTest
    static void insertConWithNoAddrToExistingHH() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // insert new contacts to the HH without any addresses
        List<Contact> listCon = UTIL_UnitTestData_TEST.createMultipleTestContacts(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listCon[i].FirstName = 'insertConWithNoAddrToExistingHH ' + i;
            listCon[i].AccountId = listAccT[i].Id;
        }
        Test.startTest();
        insert listCon;         
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
    }

    /*********************************************************************************************************
    @description
        insert new contacts with addresses to existing households that have default addresses
    verify:
        all contacts and hh get the new default hh address from the new contacts
    **********************************************************************************************************/
    @IsTest
    static void insertConWithAddrToExistingHH() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // insert new contacts to the HH with new addresses
        List<Contact> listCon = UTIL_UnitTestData_TEST.createMultipleTestContacts(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listCon[i].FirstName = 'insertConWithAddrToExistingHH ' + i;
            listCon[i].AccountId = listAccT[i].Id;
            listCon[i].MailingStreet = 'New Mailing Street' + i;
            listCon[i].MailingCity = 'New Mailing City' + i;
            listCon[i].MailingState = 'California';
            listCon[i].MailingCountry = 'United States';
        }
        Test.startTest();
        insert listCon;         
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
            System.assert(con.MailingStreet.contains('New Mailing Street'));
            System.assert(con.MailingCity.contains('New Mailing City'));
        }
    }

    /*********************************************************************************************************
    @description
        insert new contacts with default addresses to existing households that have default addresses       
        (this is to mimic the behavior of doing New Contact from the HH Account, in which case Salesforce
        brings up the new contact page in edit mode, with the account's billing address copied into the 
        contact's mailing address fields).
    verify:
        no new addresses created
        new contacts point at the default address
    **********************************************************************************************************/
    @IsTest
    static void insertConWithDefaultAddrToExistingHH() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // reload accounts to get their default addresses
        listAccT = [SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account];
        System.assertEquals(cHH, listAccT.size());
        
        // insert new contacts to the HH with the current default addresses
        List<Contact> listCon = UTIL_UnitTestData_TEST.createMultipleTestContacts(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listCon[i].FirstName = 'insertConWithDefaultAddrToExistingHH ' + i;
            listCon[i].AccountId = listAccT[i].Id;
            listCon[i].MailingStreet = listAccT[i].BillingStreet;
            listCon[i].MailingCity = listAccT[i].BillingCity;
            listCon[i].MailingState = listAccT[i].BillingState;
            listCon[i].MailingPostalCode = listAccT[i].BillingPostalCode;
            listCon[i].MailingCountry = listAccT[i].BillingCountry;            
            listCon[i].MailingLatitude = listAccT[i].BillingLatitude;
            listCon[i].MailingLongitude = listAccT[i].BillingLongitude;
        }
        Test.startTest();
        insert listCon;         
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * (cCon + 1), listCon.size());
        
        Integer cAddr = [SELECT COUNT() FROM Address__c];
        System.assertEquals(cHH, cAddr);
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
    }

    /*********************************************************************************************************
    @description
        insert contact w/ multiline street address
    verify:
        new default Address created and the street address is broken up into street and street2
        the HH Account gets the new multiline address
    **********************************************************************************************************/
    @IsTest
    static void insertContactWithMultilineStreetAddress() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_And_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettings();
            
        listConT = UTIL_UnitTestData_TEST.createMultipleTestContacts(cCon);
        for (Contact con : listConT) {
            con.MailingStreet = 'new street\r\nsecond line';
            con.MailingCity = 'new city';
        }
        Test.startTest();
        insert listConT;
        Test.stopTest();       
        
        // verify the Address objects split street.
        List<Address__c> listAddr = [SELECT Id, MailingStreet__c, MailingStreet2__c, Formula_MailingStreetAddress__c FROM Address__c];
        for (Address__c addr : listAddr) {
            System.assertEquals('new street', addr.MailingStreet__c);
            System.assertEquals('second line', addr.MailingStreet2__c);
            System.assertEquals('new street, second line', addr.Formula_MailingStreetAddress__c);
        }

        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals('new street\r\nsecond line', con.MailingStreet);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
    }

    /*********************************************************************************************************
    @description
        insert new default multiline street addresses to HH w/ existing default addresses  
    verify:
        contact's && hh address matches new default
        street & street2 combined into contact and account single street field
    **********************************************************************************************************/
    @IsTest
    static void insertNewDefaultMultilineStreetAddr() {
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // create additional addresses
        initTestAddr(cHH);
        for (Integer i = 0; i < cHH; i++) {
            listAddrT[i].Household_Account__c = listAccT[i].Id;
            listAddrT[i].Default_Address__c = true;
            listAddrT[i].MailingStreet__c = 'New Default Street';
            listAddrT[i].MailingStreet2__c = 'Second Line';
            listAddrT[i].MailingCity__c = 'New Default City' + i;
        }
        Test.startTest();
        insert listAddrT;
        Test.stopTest();

        // verify that the HH and Contacts share the same address and it's new!
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        System.assertEquals(cHH * cCon, listCon.size());
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals('New Default Street\r\nSecond Line', con.MailingStreet);
            System.assertEquals('New Default Street\r\nSecond Line', acc.BillingStreet);
        }
        
    }
    
    /*********************************************************************************************************
    @description
        update accounts' billing address with multiline street address  
    verify:
        new Default Address created
        HH and Contacts get new Address
        new Addresss has multiline street split into Street and Street2 fields
    **********************************************************************************************************/
    @IsTest
    static void updateAccMultilineStreetAddr() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // modify some of the account addresses directly
        for (Integer i = 0; i < cHH; i++) {
            Account acc = listAccT[i];
            acc.BillingStreet = 'Direct Street Edit\r\nSecond Line';
            acc.BillingCity = 'Direct City Edit';
        }
        Test.startTest();
        update listAccT;
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals('Direct Street Edit\r\nSecond Line', acc.BillingStreet);
            System.assertEquals('Direct Street Edit\r\nSecond Line', con.MailingStreet);
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
 
        // verify the Address objects split street.
        List<Address__c> listAddr = [SELECT Id, MailingStreet__c, MailingStreet2__c, Formula_MailingStreetAddress__c, Default_Address__c FROM Address__c];
        for (Address__c addr : listAddr) {
            if (addr.Default_Address__c) {
                System.assertEquals('Direct Street Edit', addr.MailingStreet__c);
                System.assertEquals('Second Line', addr.MailingStreet2__c);
                System.assertEquals('Direct Street Edit, Second Line', addr.Formula_MailingStreetAddress__c);
            }
        }

    }

    /*********************************************************************************************************
    @description
        update accounts' billing address with multiline street address  (this version only has Newline only)
    verify:
        new Default Address created
        HH and Contacts get new Address
        new Addresss has multiline street split into Street and Street2 fields
    **********************************************************************************************************/
    @IsTest
    static void updateAccMultilineStreetAddrNL() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // modify some of the account addresses directly
        for (Integer i = 0; i < cHH; i++) {
            Account acc = listAccT[i];
            acc.BillingStreet = 'Direct Street Edit\nSecond Line';
            acc.BillingCity = 'Direct City Edit';
        }
        Test.startTest();
        update listAccT;
        Test.stopTest();
        
        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals('Direct Street Edit\r\nSecond Line', acc.BillingStreet);
            System.assertEquals('Direct Street Edit\r\nSecond Line', con.MailingStreet);
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertNotEquals(null, con.Current_Address__c);
        }
 
        // verify the Address objects split street.
        List<Address__c> listAddr = [SELECT Id, MailingStreet__c, MailingStreet2__c, Formula_MailingStreetAddress__c, Default_Address__c FROM Address__c];
        for (Address__c addr : listAddr) {
            if (addr.Default_Address__c) {
                System.assertEquals('Direct Street Edit', addr.MailingStreet__c);
                System.assertEquals('Second Line', addr.MailingStreet2__c);
                System.assertEquals('Direct Street Edit, Second Line', addr.Formula_MailingStreetAddress__c);
            }
        }

    }

    /*********************************************************************************************************
    @description
        create N new organizational accounts with billing addresses 
    verify:
        N addresses created
        account address matches address object address
    **********************************************************************************************************/
    @IsTest
    static void newOrgAccounts() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_And_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_And_Orgs_Settings__c (
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                Organizational_Account_Addresses_Enabled__c = true
        ));
 
        Integer cAcc = 3;
        List<Account> listAcc = UTIL_UnitTestData_TEST.createMultipleTestAccounts(cAcc, null);
        for (Account acc : listAcc) {
            acc.BillingStreet = '123 45th';
            acc.BillingCity = 'Seattle';
        }
        Test.startTest();
        insert listAcc;
        Test.stopTest();

        // verify results
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        System.assertEquals(cAcc, mapAccIdAcc.size());
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, MailingCity__c, Household_Account__c, Latest_Start_Date__c, Latest_End_Date__c FROM Address__c];
        System.assertEquals(cAcc, listAddr.size());
        
        for (Address__c addr : listAddr) {
            Account acc = mapAccIdAcc.get(addr.Household_Account__c);
            System.assertEquals(acc.BillingStreet, addr.MailingStreet__c);
            System.assertEquals(acc.BillingCity, addr.MailingCity__c);
            System.assertEquals(true, addr.Default_Address__c);
        }
    }

    /*********************************************************************************************************
    @description
        update N organizational accounts with billing addresses 
    verify:
        N addresses created
        account addresses updated
        contact addresses not updated
    **********************************************************************************************************/
    @IsTest
    static void updateOrgAccounts() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_And_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_And_Orgs_Settings__c (
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                Organizational_Account_Addresses_Enabled__c = true
        ));
 
        // create accounts without addresses
        Integer cAcc = 3;
        List<Account> listAcc = UTIL_UnitTestData_TEST.createMultipleTestAccounts(cAcc, null);
        insert listAcc;
        
        // add a contact to each account.
        List<Contact> listCon = UTIL_UnitTestData_TEST.createMultipleTestContacts(cAcc);
        for (Integer i = 0; i < cAcc; i++) {
            listCon[i].AccountId = listAcc[i].Id;
        }
        insert listCon;

        // update the accounts' address
        for (Account acc : listAcc) {
            acc.BillingStreet = '123 45th';
            acc.BillingCity = 'Seattle';
        }
        Test.startTest();
        update listAcc;
        Test.stopTest();

        // verify results
        listAcc = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode,
                BillingCountry, BillingLatitude, BillingLongitude
            FROM Account
            ORDER BY Id
        ];
        System.assertEquals(cAcc, listAcc.size());
        List<Address__c> listAddr = [
            SELECT Id, Default_Address__c, MailingStreet__c, MailingCity__c, Household_Account__c,
                Latest_Start_Date__c, Latest_End_Date__c
            FROM Address__c
            ORDER BY Household_Account__c
        ];
        System.assertEquals(cAcc, listAddr.size());
        listCon = [
            SELECT Id, AccountId, Name, Current_Address__c, MailingStreet, MailingCity
            FROM Contact
            ORDER BY AccountId
        ];
        System.assertEquals(cAcc, listCon.size());
        
        for (Integer i = 0; i < cAcc; i++) {
            Account acc = listAcc[i];
            Address__c addr = listAddr[i];
            Contact con = listCon[i];
            System.assertEquals(acc.BillingStreet, addr.MailingStreet__c);
            System.assertEquals(acc.BillingCity, addr.MailingCity__c);
            System.assertEquals(true, addr.Default_Address__c);
            System.assertEquals(null, con.Current_Address__c);
            System.assertEquals(null, con.MailingStreet);
            System.assertEquals(null, con.MailingCity);
        }
    }
    
    /*********************************************************************************************************
    @description
        update N organizational accounts with address objects 
    verify:
        account addresses updated
        contact addresses not updated
    **********************************************************************************************************/
    @IsTest
    static void newAddrForOrgAccounts() {
        TDTM_DefaultConfig.startTestDataInit();
        
        npe01__Contacts_And_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_And_Orgs_Settings__c (
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                Organizational_Account_Addresses_Enabled__c = true
        ));
 
        // create accounts without addresses
        Integer cAcc = 3;
        List<Account> listAcc = UTIL_UnitTestData_TEST.createMultipleTestAccounts(cAcc, null);
        insert listAcc;
        
        // add a contact to each account.
        List<Contact> listCon = UTIL_UnitTestData_TEST.createMultipleTestContacts(cAcc);
        for (Integer i = 0; i < cAcc; i++) {
            listCon[i].AccountId = listAcc[i].Id;
        }
        insert listCon;

         // create addresses for the accounts
        initTestAddr(cAcc);
        for (Integer i = 0; i < cAcc; i++) {
            listAddrT[i].Household_Account__c = listAcc[i].Id;
            listAddrT[i].Default_Address__c = true;
        }
        TDTM_DefaultConfig.stopTestDataInit();
        Test.startTest();
        insert listAddrT;
        Test.stopTest();
        
        // verify results
        listAcc = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode,
                BillingCountry, BillingLatitude, BillingLongitude
            FROM Account
            ORDER BY Id
        ];
        System.assertEquals(cAcc, listAcc.size());
        listAddrT = [
            SELECT Id, Default_Address__c, MailingStreet__c, MailingCity__c, Household_Account__c,
                Latest_Start_Date__c, Latest_End_Date__c
            FROM Address__c
            ORDER BY Household_Account__c
        ];
        System.assertEquals(cAcc, listAddrT.size());
        listCon = [
            SELECT Id, AccountId, Name, Current_Address__c, MailingStreet, MailingCity
            FROM Contact
            ORDER BY AccountId
        ];
        System.assertEquals(cAcc, listCon.size());
        
        for (Integer i = 0; i < cAcc; i++) {
            Account acc = listAcc[i];
            Address__c addr = listAddrT[i];
            Contact con = listCon[i];
            System.assertEquals(acc.BillingStreet, addr.MailingStreet__c);
            System.assertEquals(acc.BillingCity, addr.MailingCity__c);
            System.assertEquals(true, addr.Default_Address__c);
            System.assertEquals(null, con.Current_Address__c);
            System.assertEquals(null, con.MailingStreet);
            System.assertEquals(null, con.MailingCity);
        }
    }

    /*********************************************************************************************************
    @description
        create N contacts with Household Accounts when the setting for Address Mgmt is off. 
    verify:
        no Address objects created
        HH Account addresses set
        Contact addresses set
    **********************************************************************************************************/
    @IsTest
    static void testDisabledHHAccountAddr() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_And_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_And_Orgs_Settings__c (
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                Household_Account_Addresses_Disabled__c = true
        ));
 
        listConT = UTIL_UnitTestData_TEST.createMultipleTestContacts(cCon);
        for (Contact con : listConT) {
            con.MailingStreet = 'new street';
            con.MailingCity = 'new city';
        }
        Test.startTest();
        insert listConT;
        Test.stopTest();       

        // verify that the HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        List<Contact> listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            Account acc = mapAccIdAcc.get(con.AccountId);
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(acc, con));
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertEquals(null, con.Current_Address__c);
        }
        
        // verify no address objects created
        List<Address__c> listAddr = [SELECT Id FROM Address__c];
        System.assertEquals(0, listAddr.size());
    }

    /*********************************************************************************************************
    @description
        update contacts' mailing address fields to empty cause clearing the default address  
    verify:
        no new Address created
        existing Default Address updated to be non-default
        HH and Contacts get updated to empty address fields
    **********************************************************************************************************/
    @IsTest
    static void clearConAddrExisting() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_And_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_And_Orgs_Settings__c (
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                Simple_Address_Change_Treated_as_Update__c = true
        ));
                
        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);

        // clear some of the contact addresses directly
        List<Contact> listCon = new List<Contact>();
        for (Integer i = 0; i < cHH; i++) {
            Contact con = listConT[i*cHH + i];
            con.MailingStreet = null;
            con.MailingCity = null;
            con.MailingPostalCode = null;
            con.MailingState = null;
            con.MailingCountry = null;
	        if (orgConfig.isStateCountryPicklistsEnabled()) {
	            con.put('MailingStateCode', null);
	            con.put('MailingCountryCode', null);
	        }                
            listCon.add(con);
        }

        Test.startTest();
        update listCon;
        Test.stopTest();
        
        // verify that the HH and Contacts have empty addresses
        List<Account> listAcc = [SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account];
        listCon = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact];
        
        for (Contact con : listCon) {
            System.assertEquals(false, con.is_Address_Override__c);
            System.assertEquals(null, con.Current_Address__c);
            System.assertEquals(null, con.MailingStreet);
            System.assertEquals(null, con.MailingCity);
            System.assertEquals(null, con.MailingPostalCode);
            System.assertEquals(null, con.MailingState);
            System.assertEquals(null, con.MailingCountry);
        }
 
        for (Account acc : listAcc) {
            System.assertEquals(null, acc.BillingStreet);
            System.assertEquals(null, acc.BillingCity);
            System.assertEquals(null, acc.BillingPostalCode);
            System.assertEquals(null, acc.BillingState);
            System.assertEquals(null, acc.BillingCountry);
        }
        
        // verify that no new address was created
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c FROM Address__c];
        System.assertEquals(cHH, listAddr.size());
        for (Address__c addr : listAddr) {
            System.assertEquals(false, addr.Default_Address__c);
        }                
    }

    /*********************************************************************************************************
    @description
        set contact address override and address lookup on a new household contact  
    verify:
        contact's address fields correctly set
    **********************************************************************************************************/
    @IsTest
    static void setConAddrOverrideAndLookupOnNewContact() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        Contact con = new Contact();
        con.LastName = 'test';
        con.AccountId = listAccT[0].Id;
        con.is_Address_Override__c = true;
        con.Current_Address__c = listAddrT[0].Id;
        
        Test.startTest();
        insert con;
        Test.stopTest();
        
        con = [SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c, MailingStreet, MailingCity,
            MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact WHERE Id = :con.Id];
        System.assertEquals(true, con.is_Address_Override__c);
        System.assertEquals(listAddrT[0].Id, con.Current_Address__c);
        System.assertEquals(listAddrT[0].MailingStreet__c, con.MailingStreet);
        System.assertEquals(listAddrT[0].MailingCity__c, con.MailingCity);
        System.assertEquals(listAddrT[0].MailingPostalCode__c, con.MailingPostalCode);
        System.assertEquals(listAddrT[0].MailingState__c, con.MailingState);
        System.assertEquals(listAddrT[0].MailingCountry__c, con.MailingCountry);
    }

    /*********************************************************************************************************
    @description
        update an org contact to be a household contact 
    verify:
        HH address created
        account address matches address object address
        contact address matches address object address
    **********************************************************************************************************/
    @IsTest
    static void updateOrgContactToHH() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;
        
        Account acc = new Account(Name='Org Account');
        insert acc;
        Contact con = new Contact(LastName='Testy', AccountId=acc.Id);
        insert con;
        
        // now give the contact an address and change it to get a hh account
        con.AccountId = null;
        con.MailingStreet = '123 abc';
        Test.startTest();
        update con;
        Test.stopTest();

        // verify results
        acc = [SELECT Id, Name, BillingStreet FROM Account WHERE Id != :acc.Id];
        List<Address__c> listAddr = [SELECT Id, Default_Address__c, MailingStreet__c FROM Address__c];
        System.assertEquals(1, listAddr.size());
        con = [SELECT Id, LastName, MailingStreet, Current_Address__c FROM Contact];
        System.assertEquals('Testy', con.LastName);
        System.assertEquals('123 abc', con.MailingStreet);
        System.assertEquals(listAddr[0].Id, con.Current_Address__c);
        System.assertEquals(listAddr[0].MailingStreet__c, con.MailingStreet);
        System.assertEquals(listAddr[0].MailingStreet__c, acc.BillingStreet);
        
    }

    /*********************************************************************************************************
    * @description update a household contact to be removed from existing household and verify that a new 
    * household is created and the contact address matches the new HH Account Address and new Address created
    **********************************************************************************************************/
    @IsTest
    static void updateHHContactToNewHH() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        // this creates a default Address for each HH
        createHHTestData(cHH, cCon);
        
        // update existing contacts to new HH with new addresses
        for (Contact conT : listConT) {
            conT.AccountId = null;
        }

        Test.startTest();
        update listConT;
        Test.stopTest();
        
        // verify that the new HH and Contacts share the same address
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([SELECT Id, Name, BillingStreet, BillingCity, BillingState,
            BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude FROM Account]);
        Map<Id, Contact> mapConIdCon = new Map<Id, Contact>([SELECT Id, Name, AccountId, is_Address_Override__c, Current_Address__c,
            MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, MailingLatitude, MailingLongitude FROM Contact]);
        Map<Id, Address__c> mapAddrIdAddr = new Map<Id, Address__c>([SELECT Id, Default_Address__c, MailingStreet__c, Household_Account__c FROM Address__c]);

        // verify new accounts with new addresses were created and previous accounts and addresses were removed
        for (Contact conT : listConT) {
            Contact updatedCon = mapConIdCon.get(conT.Id);
            Account updatedAcc = mapAccIdAcc.get(updatedCon.AccountId);

            System.assertNotEquals(conT.AccountId, updatedCon.AccountId, 'New Account should be created for the Contact.');
            System.assert(!mapAccIdAcc.containsKey(conT.AccountId), 'The original account should have been deleted.');
            System.assert(!mapAddrIdAddr.containsKey(conT.Current_Address__c), 'The original address should have been deleted.');
            System.assert(mapAddrIdAddr.containsKey(updatedCon.Current_Address__c), 'A new address should have been created.');
            System.assertEquals(true, ADDR_Addresses_TEST.isMatchAddressAccCon(updatedAcc, updatedCon), 'The new account address should match the contact.');
            System.assertEquals(false, updatedCon.is_Address_Override__c, 'The contact\'s override should not be set.');
        }
    }

    /*********************************************************************************************************
    * @description Confirms default value is used if Seasonal_Addresses_Batch_Size__c is negative
    **********************************************************************************************************/
    @IsTest
    private static void batchSizeShouldUseDefaultIfSeasonalAddressBatchSizeIsNegative() {
        setSeasonalAddressBatchSize(-1);
        System.assertEquals(ADDR_Seasonal_SCHED.DEFAULT_BATCH_SIZE, new ADDR_Seasonal_SCHED().batchSize,
            'The default batch size should be used'
        );
    }

    /*********************************************************************************************************
    * @description Confirms default value is used if Seasonal_Addresses_Batch_Size__c is zero
    **********************************************************************************************************/
    @IsTest
    private static void batchSizeShouldUseDefaultIfSeasonalAddressBatchSizeIsZero() {
        setSeasonalAddressBatchSize(0);
        System.assertEquals(ADDR_Seasonal_SCHED.DEFAULT_BATCH_SIZE, new ADDR_Seasonal_SCHED().batchSize,
            'The default batch size should be used'
        );
    }

    /*********************************************************************************************************
    * @description Confirms default value is used if Seasonal_Addresses_Batch_Size__c is null
    **********************************************************************************************************/
    @IsTest
    private static void batchSizeShouldUseDefaultIfSeasonalAddressBatchSizeIsNull() {
        setSeasonalAddressBatchSize(null);
        System.assertEquals(ADDR_Seasonal_SCHED.DEFAULT_BATCH_SIZE, new ADDR_Seasonal_SCHED().batchSize,
            'The default batch size should be used'
        );
    }

    /*********************************************************************************************************
    * @description Test Household naming executes properly when a custom TDTM trigger updates Account properly
    * on Address change.
    **********************************************************************************************************/
    @IsTest
    private static void shouldCreateNamedHHWhenCustomTDTMTriggerUpdatesAccountOnAddressChange() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        final String firstName = 'Test_First_Name';
        final String lastName = 'Test_Last_Name';

        List<Trigger_Handler__c> triggerHandlers = TDTM_Config_API.getDefaultRecords();
        triggerHandlers.add(new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
            Class__c = 'ADDR_Addresses_TEST2.TEST_Account_TDTM', Load_Order__c = 2, Object__c = 'Address__c',
            Trigger_Action__c = 'AfterInsert;AfterUpdate'));
        insert triggerHandlers;

        Contact testContact = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Salutation = 'Mr.',
            Email = 'test@email.com',
            MailingStreet = '123 Main Street',
            MailingCity = 'San Francisco',
            MailingState = 'California',
            MailingPostalCode = '94105',
            MailingCountry = 'United States'
        );

        Test.startTest();
        insert testContact;
        Test.stopTest();

        testContact = [
            SELECT
                Account.Name,
                Account.npo02__Informal_Greeting__c,
                Account.npo02__Formal_Greeting__c,
                Account.AccountNumber
            FROM Contact
            WHERE Id = :testContact.Id];

        System.assertEquals(lastName + ' ' +  System.Label.npo02.DefaultHouseholdName, testContact.Account.Name,
            'Account Name should equal Last Name + Default Household Name');
        System.assertEquals(firstName, testContact.Account.npo02__Informal_Greeting__c,
            'Informal Greeting should equal First Name');
        System.assert(testContact.Account.npo02__Formal_Greeting__c.endsWith(firstName + ' ' + lastName),
            'Formal Greeting should end with First Name + Last Name');
        System.assert(String.isNotBlank(testContact.Account.AccountNumber),
            'Account Number should be populated');
    }

    /*********************************************************************************************************
    * @description sets Seasonal_Addresses_Batch_Size__c on npo02__Households_Settings__c
    * @param batchSize: value for Seasonal_Addresses_Batch_Size__c
    **********************************************************************************************************/
    private static void setSeasonalAddressBatchSize(Integer batchSize) {
        UTIL_CustomSettingsFacade.getHouseholdsSettingsForTests(
            new npo02__Households_Settings__c (
                Seasonal_Addresses_Batch_Size__c = batchSize
            ));
    }

    /*********************************************************************************************************
    * @description TDTM Class that updates Account on update of Address. The point of this class is to
    * simulate customer processing that fires on update of Address
    **********************************************************************************************************/
    public class TEST_Account_TDTM extends TDTM_Runnable {

        public override DmlWrapper run(
            List<SObject> newlist,
            List<SObject> oldlist,
            Action triggerAction,
            Schema.DescribeSObjectResult objResult
        ) {
            List<Account> accounts = new List<Account>();
            for (SObject sObj : newlist) {
                Account acc = new Account(
                    Id = (Id) sObj.get('Household_Account__c'),
                    AccountNumber = (String.valueOf(System.Crypto.getRandomLong()).right(9))
                );
                accounts.add(acc);
            }
            update accounts;

            return null;
        }
    }
}