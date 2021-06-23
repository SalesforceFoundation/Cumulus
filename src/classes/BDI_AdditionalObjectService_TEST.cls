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
* @group Batch Data Import
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Unit tests to cover the creation of additional objects during batch data import.
*/

@isTest(isParallel=true)
private class BDI_AdditionalObjectService_TEST {

    @testSetup
    static void setupTestData() {


        General_Accounting_Unit__c gau1 = new General_Accounting_Unit__c(Name = 'TestGroupA GAU 1',
                                                                        Active__c = true);

        General_Accounting_Unit__c gau2 = new General_Accounting_Unit__c(Name = 'TestGroupA GAU 2',
                                                                        Active__c = true);

        General_Accounting_Unit__c[] testGAUs = new General_Accounting_Unit__c[]{gau1,gau2};
        insert testGAUs;

        Campaign testCampaign = new Campaign(Name = 'TestGroupA Campaign',
                                             IsActive = true,
                                             StartDate = Date.today().addDays(-10), 
                                             EndDate = Date.today().addDays(10));
        insert testCampaign;

        DataImport__c testDataImportA = 
                            new DataImport__c(Account1_City__c = 'Faketown',
                                            Account1_Country__c = 'United States',
                                            Account1_Name__c = 'TestGroupA Org 1',
                                            Account1_Phone__c = '555-123-0001',
                                            Account1_State_Province__c = 'California',
                                            Account1_Street__c = '100 Fakeaccount St',  
                                            Account1_Website__c = 'www.fakeorgacct01.com',
                                            Account1_Zip_Postal_Code__c = '94607',
                                            Account2_City__c = 'Faketown',
                                            Account2_Country__c = 'United States',
                                            Account2_Name__c = 'Org2TestGroupA',
                                            Account2_Phone__c = '555-234-0002',
                                            Account2_State_Province__c = 'California',
                                            Account2_Street__c = '200 FakeOrgaccount St',   
                                            Account2_Website__c = 'www.fakeorgacct02.com',
                                            Account2_Zip_Postal_Code__c = '94100',
                                            Donation_Campaign_Name__c = 'TestGroupA Campaign',
                                            Contact1_Alternate_Email__c = 'testgroupAcontact01Alternate@fakedata.com',
                                            Contact1_Birthdate__c = Date.today().addDays(-1000),
                                            Contact1_Firstname__c = 'Susie',
                                            Contact1_Home_Phone__c = '555-321-0001',
                                            Contact1_Lastname__c = 'TestGroupA01',
                                            Contact1_Mobile_Phone__c ='555-231-0001',
                                            Contact1_Other_Phone__c = '555-456-0001',
                                            Contact1_Personal_Email__c = 'testgroupAcontact01Personal@fakedata.com',
                                            Contact1_Preferred_Email__c = 'testgroupAcontact01Preferred@fakedata.com',
                                            Contact1_Preferred_Phone__c = '555-567-0001',
                                            Contact1_Salutation__c = 'Ms.',
                                            Contact1_Work_Email__c = 'testgroupAcontact01Preferred@fakedata.com',
                                            Contact1_Work_Phone__c = '555-678-0001',
                                            Contact2_Alternate_Email__c = 'testgroupAcontact02Alternate@fakedata.com',
                                            Contact2_Birthdate__c = Date.today().addDays(-1000),
                                            Contact2_Firstname__c = 'John',
                                            Contact2_Home_Phone__c = '555-321-0002',
                                            Contact2_Lastname__c = 'TestGroupA02',
                                            Contact2_Mobile_Phone__c ='555-231-0002',
                                            Contact2_Other_Phone__c = '555-456-0002',
                                            Contact2_Personal_Email__c = 'testgroupAcontact02Personal@fakedata.com',
                                            Contact2_Preferred_Email__c = 'testgroupAcontact02Preferred@fakedata.com',
                                            Contact2_Preferred_Phone__c = '555-567-0002',
                                            Contact2_Salutation__c = 'Mr.',
                                            Contact2_Work_Email__c = 'testgroupAcontact02Preferred@fakedata.com',
                                            Contact2_Work_Phone__c = '555-678-0002',
                                            Donation_Amount__c = 10000,
                                            Donation_Date__c = Date.today(),
                                            Donation_Description__c = 'Most excellent donation',
                                            Donation_Donor__c = 'Contact1',
                                            Donation_Member_Level__c = 'Gold',
                                            Donation_Membership_End_Date__c = Date.today().addDays(200),
                                            Donation_Membership_Origin__c = 'Outer Space',
                                            Donation_Membership_Start_Date__c =  Date.today().addDays(-200),
                                            Donation_Name__c = 'TestGroupA',    
                                            Donation_Stage__c = 'Closed Won',
                                            Donation_Type__c = null,
                                            GAU_Allocation_1_Amount__c = 750,
                                            GAU_Allocation_1_GAU__c = gau1.Id,
                                            GAU_Allocation_1_Percent__c = 75,
                                            GAU_Allocation_2_Amount__c = 250,
                                            GAU_Allocation_2_GAU__c = gau2.Id,
                                            GAU_Allocation_2_Percent__c = 25,
                                            Home_City__c = 'Fakeville',
                                            Home_Country__c = 'United States',
                                            Home_State_Province__c = 'California',
                                            Home_Street__c = '500 Fake Blvd',
                                            Home_Zip_Postal_Code__c = '94105',
                                            Household_Phone__c = '555-789-0001',
                                            Opportunity_Contact_Role_1_Role__c = 'Soft Credit',
                                            Opportunity_Contact_Role_2_Role__c = 'Soft Credit',
                                            Payment_Check_Reference_Number__c = '453',
                                            Payment_Method__c = 'Check');

        DataImport__c testDataImportB = 
                            new DataImport__c(Account1_City__c = 'Faketown',
                                            Account1_Country__c = 'United States',
                                            Account1_Name__c = 'TestGroupB Org 1',
                                            Account1_Phone__c = '554-123-0001',
                                            Account1_State_Province__c = 'California',
                                            Account1_Street__c = '954 Fakey St',    
                                            Account1_Website__c = 'www.groupBfakeorgacct01.com',
                                            Account1_Zip_Postal_Code__c = '20000',
                                            Account2_City__c = 'Faketown',
                                            Account2_Country__c = 'United States',
                                            Account2_Name__c = 'Org2TestGroupB',
                                            Account2_Phone__c = '554-234-0002',
                                            Account2_State_Province__c = 'California',
                                            Account2_Street__c = '546 Main St', 
                                            Account2_Website__c = 'www.groupbfakeorgacct02.com',
                                            Account2_Zip_Postal_Code__c = '10000',
                                            Donation_Campaign_Name__c = 'TestGroupB Campaign',
                                            Contact1_Alternate_Email__c = 'testgroupBcontact01Alternate@fakedata.com',
                                            Contact1_Birthdate__c = Date.today().addDays(-1000),
                                            Contact1_Firstname__c = 'Susie',
                                            Contact1_Home_Phone__c = '554-321-0001',
                                            Contact1_Lastname__c = 'TestGroupB01',
                                            Contact1_Mobile_Phone__c ='554-231-0001',
                                            Contact1_Other_Phone__c = '554-456-0001',
                                            Contact1_Personal_Email__c = 'testgroupBcontact01Personal@fakedata.com',
                                            Contact1_Preferred_Email__c = 'testgroupBcontact01Preferred@fakedata.com',
                                            Contact1_Preferred_Phone__c = '554-567-0001',
                                            Contact1_Salutation__c = 'Ms.',
                                            Contact1_Work_Email__c = 'testgroupBcontact01Preferred@fakedata.com',
                                            Contact1_Work_Phone__c = '554-678-0001',
                                            Contact2_Alternate_Email__c = 'testgroupBcontact02Alternate@fakedata.com',
                                            Contact2_Birthdate__c = Date.today().addDays(-1000),
                                            Contact2_Firstname__c = 'John',
                                            Contact2_Home_Phone__c = '554-321-0002',
                                            Contact2_Lastname__c = 'TestGroupB02',
                                            Contact2_Mobile_Phone__c ='554-231-0002',
                                            Contact2_Other_Phone__c = '554-456-0002',
                                            Contact2_Personal_Email__c = 'testgroupBcontact02Personal@fakedata.com',
                                            Contact2_Preferred_Email__c = 'testgroupBcontact02Preferred@fakedata.com',
                                            Contact2_Preferred_Phone__c = '554-567-0002',
                                            Contact2_Salutation__c = 'Mr.',
                                            Contact2_Work_Email__c = 'testgroupBcontact02Preferred@fakedata.com',
                                            Contact2_Work_Phone__c = '554-678-0002',
                                            Donation_Amount__c = 1000,
                                            Donation_Date__c = Date.today(),
                                            Donation_Description__c = 'Most excellent donation',
                                            Donation_Donor__c = 'Contact1',
                                            Donation_Member_Level__c = 'Gold',
                                            Donation_Membership_End_Date__c = Date.today().addDays(200),
                                            Donation_Membership_Origin__c = 'Outer Space',
                                            Donation_Membership_Start_Date__c =  Date.today().addDays(-200),
                                            Donation_Name__c = 'TestGroupB',    
                                            Donation_Stage__c = 'Closed Won',
                                            Donation_Type__c = null,
                                            GAU_Allocation_1_Amount__c = 750,
                                            GAU_Allocation_1_GAU__c = gau1.Id,
                                            GAU_Allocation_1_Percent__c = 75,
                                            GAU_Allocation_2_Amount__c = 250,
                                            GAU_Allocation_2_GAU__c = gau2.Id,
                                            GAU_Allocation_2_Percent__c = 25,
                                            Home_City__c = 'Fakopolis',
                                            Home_Country__c = 'United States',
                                            Home_State_Province__c = 'California',
                                            Home_Street__c = '333 Fakington Blvd',
                                            Home_Zip_Postal_Code__c = '94115',
                                            Household_Phone__c = '554-789-0001',
                                            Opportunity_Contact_Role_1_Role__c = 'Soft Credit',
                                            Opportunity_Contact_Role_2_Role__c = 'Soft Credit',
                                            Payment_Check_Reference_Number__c = '453',
                                            Payment_Method__c = 'Check');

        insert new DataImport__c[]{testDataImportA,testDataImportB};

    }


    /*******************************************************************************************************
    * @description Tests that GAU allocations and Opportunity contact roles will be created as additional objects
    */

    @isTest static void shouldCreateAdditionalGAUAllocationsAndOCRs() {
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
            BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        Test.StartTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH();
        ID ApexJobId = Database.executeBatch(bdi, 10);
        Test.stopTest();

        DataImport__c testDataImportAResult;
        DataImport__c testDataImportBResult;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01') {
                testDataImportBResult = di;
            }
        }

        System.assertEquals(null,testDataImportAResult.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportAResult.Status__c);
        System.assertNotEquals(null,testDataImportAResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportAResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiMatched,testDataImportAResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_2_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_2_ImportStatus__c);

        System.assertEquals(null,testDataImportBResult.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportBResult.Status__c);
        System.assertNotEquals(null,testDataImportBResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportBResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_2_Import_Status__c);
        System.assertNotEquals(null,testDataImportBResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Opportunity_Contact_Role_2_ImportStatus__c);

        OpportunityContactRole ocrA1;
        OpportunityContactRole ocrA2;
        OpportunityContactRole ocrB1;
        OpportunityContactRole ocrB2;
        OpportunityContactRole[] ocrAll = new OpportunityContactRole[]{};

        for (OpportunityContactRole ocr : [SELECT Id, ContactId, OpportunityId, Role 
                                            FROM OpportunityContactRole]) {

            ocrAll.add(ocr);
            if (ocr.Id == testDataImportAResult.Opportunity_Contact_Role_1_Imported__c ) {
                ocrA1 = ocr;
            } else if (ocr.Id == testDataImportAResult.Opportunity_Contact_Role_2_Imported__c ) {
                ocrA2 = ocr;
            } else if (ocr.Id == testDataImportBResult.Opportunity_Contact_Role_1_Imported__c ) {
                ocrB1 = ocr;
            } else if (ocr.Id == testDataImportBResult.Opportunity_Contact_Role_2_Imported__c ) {
                ocrB2 = ocr;
            }
        }

        // Confirm that the desired ocrs were created correctly
        System.assertEquals(8,ocrAll.size()); // the number 8 includes the automatically created donor and household member OCRs
        System.assertEquals('Soft Credit',ocrA1.Role);
        System.assertEquals('Soft Credit',ocrA2.Role);
        System.assertEquals('Soft Credit',ocrB1.Role);
        System.assertEquals('Soft Credit',ocrB2.Role);

        Allocation__c gauAlloA1;
        Allocation__c gauAlloA2;
        Allocation__c gauAlloB1;
        Allocation__c gauAlloB2;
        Allocation__c[] gauAlloAll = new Allocation__c[]{};

        for (Allocation__c gauAllo : [SELECT Id, Opportunity__c, Payment__c, Percent__c, Amount__c
                                            FROM Allocation__c]){
            gauAlloAll.add(gauAllo);
            if (gauAllo.Id == testDataImportAResult.GAU_Allocation_1_Imported__c ) {
                gauAlloA1 = gauAllo;
            } else if (gauAllo.Id == testDataImportAResult.GAU_Allocation_2_Imported__c ) {
                gauAlloA2 = gauAllo;
            } else if (gauAllo.Id == testDataImportBResult.GAU_Allocation_1_Imported__c ) {
                gauAlloB1 = gauAllo;
            } else if (gauAllo.Id == testDataImportBResult.GAU_Allocation_2_Imported__c ) {
                gauAlloB2 = gauAllo;
            }
        }

        // Confirm that the desired GAU Allocations were created correctly
        System.assertEquals(4,gauAlloAll.size());
        System.assertEquals(75,gauAlloA1.Percent__c);
        System.assertEquals(25,gauAlloA2.Percent__c);
        System.assertEquals(75,gauAlloB1.Percent__c);
        System.assertEquals(25,gauAlloB2.Percent__c);
    }


    /*******************************************************************************************************
    * @description Tests that some of the GAU allocations should not be created due to missing required fields. 
    * Also, some of the OCRs should not be created because all non-relationship fields are missing data..
    */

    @isTest static void shouldNotCreateGAUAllocationsOrOCRs() {
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
            BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        DataImport__c testDataImportA;
        DataImport__c testDataImportB;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {

            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportA = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01') {
                testDataImportB = di;
            }
        }

        testDataImportA.Opportunity_Contact_Role_1_Role__c = null;
        testDataImportB.GAU_Allocation_2_GAU__c = null;
        update new DataImport__c[]{testDataImportA,testDataImportB};

        Test.StartTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH();
        ID ApexJobId = Database.executeBatch(bdi, 10);
        Test.stopTest();

        DataImport__c testDataImportAResult;
        DataImport__c testDataImportBResult;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01') {
                testDataImportBResult = di;
            }

        }

        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportAResult.Status__c);
        System.assertNotEquals(null,testDataImportAResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportAResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiMatched,testDataImportAResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_2_Import_Status__c);
        System.assertEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_2_ImportStatus__c);

        System.assertEquals(BDI_DataImport_API.bdiFailed,testDataImportBResult.Status__c);
        System.assertNotEquals(null,testDataImportBResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportBResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_1_Import_Status__c);
        System.assertEquals(null,testDataImportBResult.GAU_Allocation_2_Imported__c);
        System.assert(testDataImportBResult.GAU_Allocation_2_Import_Status__c.startsWith(
                                                                    System.label.bdiAdditionalObjRequiredFieldsNull));

    }

    /*******************************************************************************************************
    * @description Tests that GAU allocations and Opportunity contact roles will be updated via Batch Data Import. 
    */

    @isTest static void shouldUpdateAdditionalGAUAllocationsAndOCRs() {
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
                                    BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        DataImport__c[] diRecords = Database.query(BDI_DataImportService.strSoqlForBatchProcess(null));

        BDI_DataImportService bdiDIS = new BDI_DataImportService(false, BDI_DataImportService.getDefaultMappingService());
        bdiDIS.process(null, dis, diRecords);
        
        DataImport__c testDataImportAResult;
        DataImport__c testDataImportBResult;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {

            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01'){
                testDataImportBResult = di;
            }

        }

        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportAResult.Status__c);
        System.assertNotEquals(null,testDataImportAResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportAResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiMatched,testDataImportAResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_2_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_2_ImportStatus__c);

        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportBResult.Status__c);
        System.assertNotEquals(null,testDataImportBResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportBResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_2_Import_Status__c);
        System.assertNotEquals(null,testDataImportBResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Opportunity_Contact_Role_2_ImportStatus__c);

        // Changing OCR values to test update clearing out GAU values to avoid errors.
        testDataImportAResult.Status__c = null;
        testDataImportAResult.GAU_Allocation_1_Percent__c = null;
        testDataImportAResult.GAU_Allocation_2_Percent__c = null;
        testDataImportAResult.GAU_Allocation_1_GAU__c = null;
        testDataImportAResult.GAU_Allocation_2_GAU__c = null;
        testDataImportAResult.GAU_Allocation_1_Imported__c = null;
        testDataImportAResult.GAU_Allocation_2_Imported__c = null;
        testDataImportAResult.GAU_Allocation_1_Import_Status__c = null;
        testDataImportAResult.GAU_Allocation_2_Import_Status__c = null;
        testDataImportAResult.Opportunity_Contact_Role_1_Role__c = 'Other';

        testDataImportBResult.Status__c = null;
        testDataImportBResult.GAU_Allocation_1_Percent__c = null;
        testDataImportBResult.GAU_Allocation_2_Percent__c = null;
        testDataImportBResult.GAU_Allocation_1_GAU__c = null;
        testDataImportBResult.GAU_Allocation_2_GAU__c = null;
        testDataImportBResult.GAU_Allocation_1_Imported__c = null;
        testDataImportBResult.GAU_Allocation_2_Imported__c = null;
        testDataImportBResult.GAU_Allocation_1_Import_Status__c = null;
        testDataImportBResult.GAU_Allocation_2_Import_Status__c = null;
        testDataImportBResult.Opportunity_Contact_Role_2_Role__c = 'Other';

        update new DataImport__c[]{testDataImportAResult, testDataImportBResult};

        Test.startTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH();
        ID ApexJobId = Database.executeBatch(bdi, 10);
        Test.stopTest();

        DataImport__c testDataImportAResult2;
        DataImport__c testDataImportBResult2;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult2 = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01'){
                testDataImportBResult2 = di;
            }
        }

        System.assertEquals(System.label.bdiUpdated,testDataImportAResult2.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertEquals(System.label.bdiUpdated,testDataImportAResult2.Opportunity_Contact_Role_2_ImportStatus__c);
        System.assertEquals(System.label.bdiUpdated,testDataImportBResult2.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertEquals(System.label.bdiUpdated,testDataImportBResult2.Opportunity_Contact_Role_2_ImportStatus__c);

        OpportunityContactRole ocrA1;
        OpportunityContactRole ocrA2;
        OpportunityContactRole ocrB1;
        OpportunityContactRole ocrB2;
        OpportunityContactRole[] ocrAll = new OpportunityContactRole[]{};

        for (OpportunityContactRole ocr : [SELECT Id, ContactId, OpportunityId, Role 
                                            FROM OpportunityContactRole]){
            ocrAll.add(ocr);
            if (ocr.Id == testDataImportAResult.Opportunity_Contact_Role_1_Imported__c ) {
                ocrA1 = ocr;
            } else if (ocr.Id == testDataImportAResult.Opportunity_Contact_Role_2_Imported__c ) {
                ocrA2 = ocr;
            } else if (ocr.Id == testDataImportBResult.Opportunity_Contact_Role_1_Imported__c ) {
                ocrB1 = ocr;
            } else if (ocr.Id == testDataImportBResult.Opportunity_Contact_Role_2_Imported__c ) {
                ocrB2 = ocr;
            }
        }

        // Confirm that only the appropriate opportunity contact roles were changed
        // the number 8 includes the automatically created donor and household member OCRs
        System.assertEquals(8,ocrAll.size()); 
        System.assertEquals('Other',ocrA1.Role);
        System.assertEquals('Soft Credit',ocrA2.Role);
        System.assertEquals('Soft Credit',ocrB1.Role);
        System.assertEquals('Other',ocrB2.Role);
    }


    /*******************************************************************************************************
    * @description Tests that parent objects can be created during additional object processing.
    *  Note that this would be an unconvential setup since we don't have a parent object as part of our 
    *  default metadata configuration so we are having to re-use existing DI fields for the 
    *  Imported Record Field Name and Status.
    */
    
    @isTest static void shouldCreateParentAdditionalObjects() {
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
            BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        DataImport__c[] diRecords = Database.query(BDI_DataImportService.strSoqlForBatchProcess(null));

        BDI_DataImportService bdiDIS = new BDI_DataImportService(false, 
                                                                BDI_DataImportService.getDefaultMappingService());
        
        BDI_MappingServiceAdvanced bdiMsAdv = BDI_MappingServiceAdvanced.getInstance();

        String[] objMappingNames = new List<String>(bdiMsAdv.objectMappingByDevName.keySet());
        BDI_ObjectMapping predecessorObjMapping = bdiMsAdv.objectMappingByDevName.get('Opportunity');
        BDI_FieldMapping[] opptFieldMappings = bdiMsAdv.fieldMappingsByObjMappingDevName.get('Opportunity'); 


        Data_Import_Object_Mapping__mdt diom = 
            new Data_Import_Object_Mapping__mdt(DeveloperName = 'TestTestHonoree324',
                            MasterLabel = 'Honoree',
                            Data_Import_Object_Mapping_Set__c = predecessorObjMapping.Data_Import_Object_Mapping_Set,
                            Object_API_Name__c = 'Contact',
                            Predecessor__c = predecessorObjMapping.DeveloperName,
                            Imported_Record_Field_Name__c = UTIL_Namespace.StrTokenNSPrefix('Contact1_Title__c'),
                            Imported_Record_Status_Field_Name__c = UTIL_Namespace.StrTokenNSPrefix('Contact1ImportStatus__c'),
                            Relationship_Field__c = UTIL_Namespace.StrTokenNSPrefix('Honoree_Contact__c'),
                            Relationship_To_Predecessor__c = 'Parent');

        BDI_ObjectMapping testObjMapping = new BDI_ObjectMapping(diom);

        BDI_FieldMapping testFM1 = new BDI_FieldMapping();
        testFM1.MasterLabel = 'fakeHonoreeLastNameSFDOTest34';
        testFM1.DeveloperName = 'fakeHonoreeLastNameSFDOTest34';
        testFM1.Target_Object_API_Name = 'Contact';
        testFM1.Data_Import_Field_Mapping_Set = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        testFM1.Required = 'Yes';
        testFM1.Source_Field_API_Name = DataImport__c.Contact1_Alternate_Email__c.getDescribe().getName();
        testFM1.Target_Field_API_Name = 'LastName';

        BDI_FieldMapping testFM2 = new BDI_FieldMapping();
        testFM2.MasterLabel = 'fakeHonoreeAcctSFDOTest34';
        testFM2.DeveloperName = 'fakeHonoreeAcctSFDOTest34';
        testFM2.Target_Object_API_Name = 'Contact';
        testFM2.Data_Import_Field_Mapping_Set = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        testFM2.Required = 'No';
        testFM2.Source_Field_API_Name = DataImport__c.Account1Imported__c.getDescribe().getName();
        testFM2.Target_Field_API_Name = 'AccountId';

        BDI_FieldMapping[] honoreeFieldMappings = 
            new BDI_FieldMapping[]{testFM1,testFM2};

        bdiMsAdv.objectMappingByDevName.put(testObjMapping.DeveloperName,testObjMapping);
        bdiMsAdv.fieldMappingsByObjMappingDevName.put(testObjMapping.DeveloperName,honoreeFieldMappings);

        bdiDIS.process(null, dis, diRecords);
        
        DataImport__c testDataImportAResult;
        DataImport__c testDataImportBResult;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        Contact1_Title__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {

            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01'){
                testDataImportBResult = di;
            }
        }

        Contact honoreeContA;
        Contact honoreeContB;

        Contact[] createdConts = [SELECT Id, LastName FROM Contact];
        System.assertEquals(6,createdConts.size());

        for (Contact cont : createdConts) {
            if (cont.LastName == 'testgroupAcontact01Alternate@fakedata.com') {
                honoreeContA = cont;
            } else if (cont.LastName == 'testgroupBcontact01Alternate@fakedata.com') {
                honoreeContB = cont;
            }
        }

        // Checking to make sure that the honoree contacts were created.
        System.assert(honoreeContA != null);
        System.assert(honoreeContB != null);

        Opportunity opptA;
        Opportunity opptB;

        Opportunity[] updatedOppts = [SELECT Id, Honoree_Contact__c FROM Opportunity];
        System.assertEquals(2,updatedOppts.size());

        for (Opportunity oppt : updatedOppts) {
            if (oppt.Id == testDataImportAResult.DonationImported__c) {
                opptA = oppt;
            } else if (oppt.Id == testDataImportBResult.DonationImported__c) {
                opptB = oppt;
            }
        }

        //Confirm that the predecessor child opportunities exist and were properly updated with the
        //Honoree contact id.
        System.assert(opptA != null);
        System.assert(opptB != null);
        System.assertEquals(honoreeContA.Id,opptA.Honoree_Contact__c);
        System.assertEquals(honoreeContB.Id,opptB.Honoree_Contact__c);
    
        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportAResult.Status__c);
        System.assertNotEquals(null,testDataImportAResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact2ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiMatched,testDataImportAResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.GAU_Allocation_2_Import_Status__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Opportunity_Contact_Role_2_ImportStatus__c);

        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportBResult.Status__c);
        System.assertNotEquals(null,testDataImportBResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportBResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_1_Import_Status__c);
        System.assertNotEquals(null,testDataImportBResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.GAU_Allocation_2_Import_Status__c);
        System.assertNotEquals(null,testDataImportBResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Opportunity_Contact_Role_2_ImportStatus__c);
    }

    @isTest
    static void givenAdditionalObjectsFailWhenProcessedThenAssertFailureInformation() {

        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c =
                BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;

        General_Accounting_Unit__c testGAU = new General_Accounting_Unit__c(Name = 'testGAU');
        insert testGAU;

        DataImport__c singleErrorDataImport = new DataImport__c(
                Account1_Name__c = 'a0',
                Donation_Donor__c = 'Account1',
                Donation_Amount__c = 100,
                Donation_Date__c = Date.today(),
                GAU_Allocation_1_GAU__c = testGAU.Id,
                GAU_Allocation_1_Amount__c = 110
        );

        DataImport__c doubleErrorDataImport = new DataImport__c(
                Account1_Name__c = 'a1',
                Donation_Donor__c = 'Account1',
                Donation_Amount__c = 100,
                Donation_Date__c = Date.today(),
                GAU_Allocation_1_GAU__c = testGAU.Id,
                GAU_Allocation_1_Amount__c = 110,
                Opportunity_Contact_Role_1_Role__c = 'testOCRole'
        );

        List<DataImport__c> testDIs = new List<DataImport__c>{singleErrorDataImport, doubleErrorDataImport};

        insert testDIs;

        //run batch data import
        Test.StartTest();
        BDI_DataImport_API.processDataImportRecords(dis,testDIs,false);

        Test.stopTest();

        List<DataImport__c> dataImports = [
                SELECT
                        Status__c,
                        FailureInformation__c,
                        GAU_Allocation_1_Imported__c,
                        GAU_Allocation_1_Import_Status__c,
                        DonationImported__c,
                        Opportunity_Contact_Role_1_ImportStatus__c
                FROM DataImport__c
                WHERE Id = :singleErrorDataImport.Id
                OR Id = :doubleErrorDataImport.Id
        ];

        System.assertEquals(2,dataImports.size());

        for (DataImport__c dataImport : dataImports) {
            System.assertEquals(BDI_DataImport_API.bdiFailed, dataImport.Status__c);
            System.assertNotEquals(null, dataImport.GAU_Allocation_1_Import_Status__c);
            System.assertNotEquals(null, dataImport.FailureInformation__c);

            if (dataImport.Id == doubleErrorDataImport.Id) {
                System.assertNotEquals(null,
                        dataImport.Opportunity_Contact_Role_1_ImportStatus__c);
            }
        }
    }

    @isTest
    static void givenOppHasBeenImportedWhenReprocessedThenAssertAdditionalObjectsImported() {
        //Setup: use Advanced Field Mapping with Donation Matching Behavior set to "Single
        // Match or Create"
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c =
                BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        dis.Donation_Matching_Behavior__c = BDI_DataImport_API.ExactMatchOrCreate;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        Account testAccount = new Account(Name = 'testAcct');
        insert testAccount;

        Opportunity testOpp = new Opportunity(
                AccountId = testAccount.Id,
                Name = 'testOpp',
                Amount = 100,
                CloseDate = Date.today(),
                StageName = UTIL_UnitTestData_TEST.getClosedWonStage());
        insert testOpp;

        General_Accounting_Unit__c testGAU = new General_Accounting_Unit__c(
                Name = 'testGAU',
                Active__c = true);
        insert testGAU;

        //Set up the Data Import record to look like it has already been run and created
        //the Opportunity but failed with a reported error on the GAU Allocation additional
        //object.
        DataImport__c dataImport = new DataImport__c(
                Account1_Name__c = 'testAcct',
                Account1Imported__c = testAccount.Id,
                Account1ImportStatus__c = System.Label.bdiCreated,

                Donation_Donor__c = 'Account1',
                Donation_Amount__c = 100,
                Donation_Date__c = Date.today(),
                DonationImported__c = testOpp.Id,
                DonationImportStatus__c = System.Label.bdiCreated,

                GAU_Allocation_1_GAU__c = testGAU.Id,
                //Setting the GAU Allocation Percentage to a legitimate value alongside
                //the Import Status error mimics a User fixing the percentage after the
                //initial processing attempt.  The Data Import record should now be
                //ready to re-process.
                GAU_Allocation_1_Percent__c = 15,
                GAU_Allocation_1_Import_Status__c = System.Label.alloTotalExceedsOppAmt,

                Status__c = BDI_DataImport_API.bdiFailed,
                FailureInformation__c = System.Label.alloTotalExceedsOppAmt
        );
        insert dataImport;

        //Re-run batch data import process
        Test.StartTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH();
        Database.executeBatch(bdi, 10);
        Test.stopTest();

        dataImport = [
                SELECT
                        Status__c,
                        FailureInformation__c,
                        DonationImported__c,
                        DonationImportStatus__c,
                        GAU_Allocation_1_Imported__c,
                        GAU_Allocation_1_Import_Status__c,
                        GAU_Allocation_2_Amount__c,
                        GAU_Allocation_2_Percent__c
                FROM DataImport__c
                WHERE Id = :dataImport.Id
        ];

        System.assertEquals(BDI_DataImport_API.bdiImported, dataImport.Status__c,
                'The Data Import should have been successfully re-processed and have an ' +
                        '\"imported\" status.');
        System.assertEquals(null, dataImport.FailureInformation__c,
                'The Data Import should have been successfully re-processed without any failure ' +
                        'information.');

        System.assertEquals(testOpp.Id, dataImport.DonationImported__c,
                'The Donation Imported lookup value should be unchanged.');
        System.assertEquals(System.Label.bdiCreated, dataImport.DonationImportStatus__c,
                'The Donation Import Status should be unchanged.');

        System.assertNotEquals(null, dataImport.GAU_Allocation_1_Imported__c,
                'An Allocation should have been created.');
        System.assertEquals(System.Label.bdiCreated, dataImport.GAU_Allocation_1_Import_Status__c,
                'An Allocation should have been created.');

        System.assertEquals(1, [
                SELECT COUNT()
                FROM Allocation__c
                WHERE Opportunity__c = :testOpp.Id
                AND General_Accounting_Unit__c = :testGAU.Id
                AND Percent__c = 15.0
        ], 'An Allocation for 15% should have been created.');
    }

    @isTest
    static void givenOppHasBeenMatchedWhenReprocessedThenAssertAdditionalObjectsImported() {
        //Setup: use Advanced Field Mapping with Donation Matching Behavior set to "Single
        // Match or Create"
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c =
                BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        dis.Donation_Matching_Behavior__c = BDI_DataImport_API.ExactMatchOrCreate;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        Account testAccount = new Account(Name = 'testAcct');
        insert testAccount;

        Opportunity testOpp = new Opportunity(
                AccountId = testAccount.Id,
                Name = 'testOpp',
                Amount = 100,
                CloseDate = Date.today(),
                StageName = UTIL_UnitTestData_TEST.getClosedWonStage());
        insert testOpp;

        General_Accounting_Unit__c testGAU = new General_Accounting_Unit__c(
                Name = 'testGAU',
                Active__c = true);
        insert testGAU;

        //Set up the Data Import record to look like it has already been run and created
        //the Opportunity but failed with a reported error on the GAU Allocation additional
        //object.
        DataImport__c dataImport = new DataImport__c(
                Account1_Name__c = 'testAcct',
                Account1Imported__c = testAccount.Id,
                Account1ImportStatus__c = System.Label.bdiCreated,

                Donation_Donor__c = 'Account1',
                Donation_Amount__c = 100,
                Donation_Date__c = Date.today(),
                DonationImported__c = testOpp.Id,
                DonationImportStatus__c = System.Label.bdiMatched,

                GAU_Allocation_1_GAU__c = testGAU.Id,
                //Setting the GAU Allocation Percentage to a legitimate value alongside
                //the Import Status error mimics a User fixing the percentage after the
                //initial processing attempt.  The Data Import record should now be
                //ready to re-process.
                GAU_Allocation_1_Percent__c = 15,
                GAU_Allocation_1_Import_Status__c = System.Label.alloTotalExceedsOppAmt,

                Status__c = BDI_DataImport_API.bdiFailed,
                FailureInformation__c = System.Label.alloTotalExceedsOppAmt
        );
        insert dataImport;

        //Re-run batch data import process
        Test.StartTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH();
        Database.executeBatch(bdi, 10);
        Test.stopTest();

        DataImport__c processedDataImport = [
                SELECT
                        Status__c,
                        FailureInformation__c,
                        DonationImported__c,
                        DonationImportStatus__c,
                        GAU_Allocation_1_Imported__c,
                        GAU_Allocation_1_Import_Status__c
                FROM DataImport__c
                WHERE Id = :dataImport.Id
        ];

        System.assertEquals(BDI_DataImport_API.bdiImported, processedDataImport.Status__c,
                'The Data Import should have been successfully re-processed and have an ' +
                        '\"imported\" status.');
        System.assertEquals(null, processedDataImport.FailureInformation__c,
                'The Data Import should have been successfully re-processed without any failure ' +
                        'information.');

        System.assertEquals(testOpp.Id, processedDataImport.DonationImported__c,
                'The Donation Imported lookup value should be unchanged.');
        System.assertEquals(dataImport.DonationImportStatus__c, processedDataImport.DonationImportStatus__c,
                'The Donation Import Status should be unchanged.');

        System.assertNotEquals(null, processedDataImport.GAU_Allocation_1_Imported__c,
                'An Allocation should have been created.');
        System.assertEquals(System.Label.bdiCreated, processedDataImport.GAU_Allocation_1_Import_Status__c,
                'An Allocation should have been created.');

        System.assertEquals(1, [
                SELECT COUNT()
                FROM Allocation__c
                WHERE Opportunity__c = :testOpp.Id
                AND General_Accounting_Unit__c = :testGAU.Id
                AND Percent__c = 15.0
        ], 'An Allocation for 15% should have been created.');
    }

    @isTest
    static void
    givenDataImportHasAddtlObjectWhenDryRunThenAssertPredecessorErrorsSuppressed() {
        //Setup: use Advanced Field Mapping with Donation Matching Behavior set to "Single
        // Match or Create"
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c =
                BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        dis.Donation_Matching_Behavior__c = BDI_DataImport_API.ExactMatchOrCreate;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        // Create a test GAU
        General_Accounting_Unit__c testGAU = new General_Accounting_Unit__c(
                Name = 'testGAU',
                Active__c = true);
        insert testGAU;

        DataImportBatch__c testBatch = new DataImportBatch__c(
                Name='testBatch'
        );
        insert testBatch;

        // Create a simple Data Import record that will create a new Opp and GAU Allocation
        // when processed.  After dry run the Opp will not be created yet, so the test
        // ensures that the additional objects that depend on the Opp don't fail the Data
        // Import record when dry run process is run.
        DataImport__c dataImport = new DataImport__c(
                NPSP_Data_Import_Batch__c = testBatch.Id,
                Account1_Name__c = 'testAcct',
                Donation_Donor__c = 'Account1',
                Donation_Amount__c = 100,
                Donation_Date__c = Date.today(),
                GAU_Allocation_1_GAU__c = testGAU.Id,
                GAU_Allocation_1_Percent__c = 15
        );
        insert dataImport;

        //Run the data import dry run process
        Test.StartTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH(testBatch.Id, true);
        Database.executeBatch(bdi, 10);
        Test.stopTest();

        DataImport__c processedDataImport = [
                SELECT
                        Status__c,
                        FailureInformation__c,
                        DonationImported__c,
                        DonationImportStatus__c,
                        GAU_Allocation_1_Imported__c,
                        GAU_Allocation_1_Import_Status__c
                FROM DataImport__c
                WHERE Id = :dataImport.Id
        ];

        System.assertEquals(BDI_DataImport_API.bdiDryRunValidated,
                processedDataImport.Status__c,
                'The Batch should have been dry run-validated without errors.');
        System.assertEquals(null, processedDataImport.FailureInformation__c,
                'The Batch should have been dry run-validated without errors.');
    }

    /*******************************************************************************************************
    * @description Tests that the parent of predecessor functionality works correctly for dynamic sources.
    */
    @isTest
    static void dynamicParentAdditionalObjectsShouldBeCreated() {
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
            BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        DataImport__c[] diRecords = Database.query(BDI_DataImportService.strSoqlForBatchProcess(null));

        BDI_DataImportService bdiDIS = 
            new BDI_DataImportService(false, BDI_DataImportService.getDefaultMappingService());
        
        BDI_MappingServiceAdvanced bdiMsAdv = BDI_MappingServiceAdvanced.getInstance();

        String[] objMappingNames = new List<String>(bdiMsAdv.objectMappingByDevName.keySet());
        BDI_ObjectMapping predecessorObjMapping = bdiMsAdv.objectMappingByDevName.get('Opportunity');
        BDI_FieldMapping[] opptFieldMappings = bdiMsAdv.fieldMappingsByObjMappingDevName.get('Opportunity'); 

        String additionalObjJSONFieldName = 
            UTIL_Namespace.alignSchemaNSWithEnvironment('npsp__Additional_Object_JSON__c');

        Data_Import_Object_Mapping__mdt diom = 
            new Data_Import_Object_Mapping__mdt(DeveloperName = 'TestTestHonoree324',
                        MasterLabel = 'Honoree',
                        Data_Import_Object_Mapping_Set__c = predecessorObjMapping.Data_Import_Object_Mapping_Set,
                        Object_API_Name__c = 'Contact',
                        Predecessor__c = predecessorObjMapping.DeveloperName,
                        Imported_Record_Field_Name__c = UTIL_Namespace.StrTokenNSPrefix('Contact1_Title__c'),
                        Imported_Record_Status_Field_Name__c = UTIL_Namespace.StrTokenNSPrefix('Contact1ImportStatus__c'),
                        Relationship_Field__c = UTIL_Namespace.StrTokenNSPrefix('Honoree_Contact__c'),
                        Relationship_To_Predecessor__c = 'Parent');

        BDI_ObjectMapping testObjMapping = new BDI_ObjectMapping(diom);

        BDI_FieldMapping testFM1 = new BDI_FieldMapping();
        testFM1.MasterLabel = 'fakeHonoreeLastNameSFDOTest';
        testFM1.DeveloperName = 'fakeHonoreeLastNameSFDOTest';
        testFM1.Target_Object_API_Name = 'Contact';
        testFM1.Data_Import_Field_Mapping_Set = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        testFM1.Required = 'Yes';
        testFM1.Source_Field_API_Name = DataImport__c.Contact1_Alternate_Email__c.getDescribe().getName();
        testFM1.Target_Field_API_Name = 'LastName';

        BDI_FieldMapping testFM2 = new BDI_FieldMapping();
        testFM2.MasterLabel = 'fakeHonoreeAcctSFDOTest';
        testFM2.DeveloperName = 'fakeHonoreeAcctSFDOTest';
        testFM2.Target_Object_API_Name = 'Contact';
        testFM2.Data_Import_Field_Mapping_Set = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        testFM2.Required = 'No';
        testFM2.Source_Field_API_Name = DataImport__c.Account1Imported__c.getDescribe().getName();
        testFM2.Target_Field_API_Name = 'AccountId';

        BDI_FieldMapping[] honoreeFieldMappings = 
            new BDI_FieldMapping[]{testFM1,testFM2};

        bdiMsAdv.objectMappingByDevName.put(testObjMapping.DeveloperName,testObjMapping);
        bdiMsAdv.fieldMappingsByObjMappingDevName.put(testObjMapping.DeveloperName,honoreeFieldMappings);

        SObject sourceObjA1 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjA1.put(DataImport__c.Contact1_Alternate_Email__c.getDescribe().getName(),
                    'testgroupAcontact01DSAlternate@fakedata.com');    
        SObject sourceObjA2 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjA2.put(DataImport__c.Contact1_Alternate_Email__c.getDescribe().getName(),
                    'testgroupAcontact02DSAlternate@fakedata.com');   

        SObject sourceObjB1 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjB1.put(DataImport__c.Contact1_Alternate_Email__c.getDescribe().getName(),
                    'testgroupBcontact01DSAlternate@fakedata.com');    

        BDI_DynamicSource dynSourceA1 = new BDI_DynamicSource();
        dynSourceA1.objectMappingDevName = testObjMapping.DeveloperName + '01';
        dynSourceA1.objectMappingTemplateDevName = testObjMapping.DeveloperName;
        dynSourceA1.fieldMappingSetDevName = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceA1.sourceObj = sourceObjA1;

        BDI_DynamicSource dynSourceA2 = new BDI_DynamicSource();
        dynSourceA2.objectMappingDevName = testObjMapping.DeveloperName + '02';
        dynSourceA2.objectMappingTemplateDevName = testObjMapping.DeveloperName;
        dynSourceA2.fieldMappingSetDevName = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceA2.sourceObj = sourceObjA2;   

        Map<String,BDI_DynamicSource> dynamicSourceByObjMappingDevNameA = new Map<String,BDI_DynamicSource>();
        dynamicSourceByObjMappingDevNameA.put(dynSourceA1.objectMappingDevName,dynSourceA1);
        dynamicSourceByObjMappingDevNameA.put(dynSourceA2.objectMappingDevName,dynSourceA2);

        BDI_DynamicSourceGroup dynSourceGroupA = new BDI_DynamicSourceGroup();
        dynSourceGroupA.dynamicSourceByObjMappingDevName = dynamicSourceByObjMappingDevNameA;
        dynSourceGroupA.name = additionalObjJSONFieldName;

        BDI_DynamicSource dynSourceB1 = new BDI_DynamicSource();
        dynSourceB1.objectMappingDevName = testObjMapping.DeveloperName + '01';
        dynSourceB1.objectMappingTemplateDevName = testObjMapping.DeveloperName;
        dynSourceB1.fieldMappingSetDevName = opptFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceB1.sourceObj = sourceObjB1;
        
        Map<String,BDI_DynamicSource> dynamicSourceByObjMappingDevNameB = new Map<String,BDI_DynamicSource>();
        dynamicSourceByObjMappingDevNameB.put(dynSourceB1.objectMappingDevName,dynSourceB1);

        BDI_DynamicSourceGroup dynSourceGroupB = new BDI_DynamicSourceGroup();
        dynSourceGroupB.dynamicSourceByObjMappingDevName = dynamicSourceByObjMappingDevNameB;
        dynSourceGroupB.name = additionalObjJSONFieldName;

        String dynSourceGroupStringA = JSON.serialize(dynSourceGroupA);
        String dynSourceGroupStringB = JSON.serialize(dynSourceGroupB);

        for (DataImport__c di : diRecords) {
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                di.Additional_Object_JSON__c = dynSourceGroupStringA;
                di.Contact1_Alternate_Email__c = null; 
            } else if (di.Contact1_Lastname__c == 'TestGroupB01'){
                di.Additional_Object_JSON__c = dynSourceGroupStringB;
                di.Contact1_Alternate_Email__c = null; 
            }
        }

        bdiDIS.process(null, dis, diRecords);
        
        DataImport__c testDataImportAResult;
        DataImport__c testDataImportBResult;


        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        Additional_Object_JSON__c,
                                        Contact1_Title__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        Contact1_Lastname__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {

            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01'){
                testDataImportBResult = di;
            }
        }

        BDI_DynamicSourceGroup dsgA = 
            (BDI_DynamicSourceGroup)JSON.deserialize(testDataImportAResult.Additional_Object_JSON__c,
                                                    BDI_DynamicSourceGroup.class);
        BDI_DynamicSourceGroup dsgB = 
            (BDI_DynamicSourceGroup)JSON.deserialize(testDataImportBResult.Additional_Object_JSON__c,
                                                    BDI_DynamicSourceGroup.class);

        BDI_DynamicSource dsA1 = dsgA.dynamicSourceByObjMappingDevName.get(dynSourceA1.objectMappingDevName);
        BDI_DynamicSource dsA2 = dsgA.dynamicSourceByObjMappingDevName.get(dynSourceA2.objectMappingDevName);
        BDI_DynamicSource dsB1 = dsgB.dynamicSourceByObjMappingDevName.get(dynSourceB1.objectMappingDevName);

        System.assert(dsA1 != null);
        System.assert(dsA2 != null);
        System.assert(dsB1 != null);
        System.assert(dsA1.importedRecordId != null);
        System.assert(dsA2.importedRecordId != null);
        System.assert(dsB1.importedRecordId != null);
        System.assert(dsA1.importedRecordStatus == System.label.bdiCreated);
        System.assert(dsA2.importedRecordStatus == System.label.bdiCreated);
        System.assert(dsB1.importedRecordStatus == System.label.bdiCreated);
        
        //Making sure the created contact record info was not updated on the DI field itself.
        System.assertEquals(null,testDataImportAResult.Contact1_Title__c);
        System.assertEquals(null,testDataImportBResult.Contact1_Title__c);

        Contact honoreeContA1;
        Contact honoreeContA2;
        Contact honoreeContB;

        Contact[] createdConts = [SELECT Id, LastName FROM Contact];
        System.assertEquals(7,createdConts.size());

        for (Contact cont : createdConts) {
            if (cont.LastName == 'testgroupAcontact01DSAlternate@fakedata.com') {
                honoreeContA1 = cont;
            } else if (cont.LastName == 'testgroupAcontact02DSAlternate@fakedata.com') {
                honoreeContA2 = cont;
            } else if (cont.LastName == 'testgroupBcontact01DSAlternate@fakedata.com') {
                honoreeContB = cont;
            }
        }

        // Checking to make sure that the honoree contacts were created.
        System.assert(honoreeContA1 != null);
        System.assert(honoreeContA2 != null);
        System.assert(honoreeContB != null);

        System.assert(testDataImportAResult.Additional_Object_JSON__c != null);
        System.assert(testDataImportBResult.Additional_Object_JSON__c != null);

        
        Opportunity opptA;
        Opportunity opptB;

        Opportunity[] updatedOppts = [SELECT Id, Honoree_Contact__c FROM Opportunity];
        System.assertEquals(2,updatedOppts.size());

        for (Opportunity oppt : updatedOppts) {
            if (oppt.Id == testDataImportAResult.DonationImported__c) {
                opptA = oppt;
            } else if (oppt.Id == testDataImportBResult.DonationImported__c) {
                opptB = oppt;
            }
        }

        Set<Id> honoreeContsA = new Set<Id>{honoreeContA1.Id,honoreeContA2.Id};
        //Since only one of the honoree contacts for oppt A could be on the the oppt, this will look
        //for either
        System.assert(honoreeContsA.contains(opptA.Honoree_Contact__c));
        System.assertEquals(opptB.Honoree_Contact__c, dsB1.importedRecordId);
    }

    /*******************************************************************************************************
    * @description Tests that GAU allocations and Opportunity contact roles will be created as additional objects
    * when using a dynamic JSON data source.  Also tests error handling for Dynamic sources.
    */
    @isTest static void shouldCreateChildDynamicAdditionalObjects() {
        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
            BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

        String additionalObjJSONFieldName = 
            UTIL_Namespace.alignSchemaNSWithEnvironment('npsp__Additional_Object_JSON__c');
        String templateName = 'GAU_Allocation_1';
        String templateNameOCR = 'Opportunity_Contact_Role_1';

        BDI_DataImportService bdiDIS = 
            new BDI_DataImportService(false, BDI_DataImportService.getDefaultMappingService());

        BDI_MappingServiceAdvanced bdiMSA = BDI_MappingServiceAdvanced.getInstance();

        BDI_FieldMapping[] gauAllocFieldMappings = bdiMSA.fieldMappingsByObjMappingDevName.get(templateName);
        BDI_FieldMapping[] ocrFieldMappings = bdiMSA.fieldMappingsByObjMappingDevName.get(templateNameOCR);

        DataImport__c[] diRecords = Database.query(BDI_DataImportService.strSoqlForBatchProcess(null));
        DataImport__c testDataImportA;
        DataImport__c testDataImportB;

        for (DataImport__c di : diRecords) {
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportA = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01') {
                testDataImportB = di;
            }
        }

        SObject sourceObjA1 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjA1.put(DataImport__c.GAU_Allocation_1_Amount__c.getDescribe().getName(),
                    testDataImportA.GAU_Allocation_1_Amount__c);    
        sourceObjA1.put(DataImport__c.GAU_Allocation_1_GAU__c.getDescribe().getName(),
                    testDataImportA.GAU_Allocation_1_GAU__c);    
        sourceObjA1.put(DataImport__c.GAU_Allocation_1_Percent__c.getDescribe().getName(),
                    testDataImportA.GAU_Allocation_1_Percent__c);    

        SObject sourceObjA2 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjA2.put(DataImport__c.GAU_Allocation_1_Amount__c.getDescribe().getName(),
                    testDataImportA.GAU_Allocation_2_Amount__c);    
        sourceObjA2.put(DataImport__c.GAU_Allocation_1_GAU__c.getDescribe().getName(),
                    testDataImportA.GAU_Allocation_2_GAU__c);    
        sourceObjA2.put(DataImport__c.GAU_Allocation_1_Percent__c.getDescribe().getName(),
                    testDataImportA.GAU_Allocation_2_Percent__c);    

        SObject sourceObjA3 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjA3.put(DataImport__c.Opportunity_Contact_Role_1_Role__c.getDescribe().getName(),
                    'Soft Credit');    

        SObject sourceObjB1 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjB1.put(DataImport__c.GAU_Allocation_1_Amount__c.getDescribe().getName(),
                    testDataImportB.GAU_Allocation_1_Amount__c);    
        sourceObjB1.put(DataImport__c.GAU_Allocation_1_GAU__c.getDescribe().getName(),
                    testDataImportB.GAU_Allocation_1_GAU__c);    
        sourceObjB1.put(DataImport__c.GAU_Allocation_1_Percent__c.getDescribe().getName(),
                    testDataImportB.GAU_Allocation_1_Percent__c);    
        
        //This one does not include a GAU allocation Id so it will trigger a required field error.
        SObject sourceObjB2 = UTIL_Describe.getPrototypeObject(SObjectType.DataImport__c.getName());
        sourceObjB2.put(DataImport__c.GAU_Allocation_1_Amount__c.getDescribe().getName(),
                    testDataImportB.GAU_Allocation_2_Amount__c);    
        sourceObjB2.put(DataImport__c.GAU_Allocation_1_Percent__c.getDescribe().getName(),
                    testDataImportB.GAU_Allocation_2_Percent__c);    


        BDI_DynamicSource dynSourceA1 = new BDI_DynamicSource();
        dynSourceA1.objectMappingDevName = templateName +'01';
        dynSourceA1.objectMappingTemplateDevName = templateName;
        dynSourceA1.fieldMappingSetDevName = gauAllocFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceA1.sourceObj = sourceObjA1;

        BDI_DynamicSource dynSourceA2 = new BDI_DynamicSource();
        dynSourceA2.objectMappingDevName = templateName + '02';
        dynSourceA2.objectMappingTemplateDevName = templateName;
        dynSourceA2.fieldMappingSetDevName = gauAllocFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceA2.sourceObj = sourceObjA2;  

        BDI_DynamicSource dynSourceA3 = new BDI_DynamicSource();
        dynSourceA3.objectMappingDevName = templateNameOCR + '01';
        dynSourceA3.objectMappingTemplateDevName = templateNameOCR;
        dynSourceA3.fieldMappingSetDevName = ocrFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceA3.sourceObj = sourceObjA3;   

        Map<String,BDI_DynamicSource> dynamicSourceByObjMappingDevNameA = new Map<String,BDI_DynamicSource>();
        dynamicSourceByObjMappingDevNameA.put(dynSourceA1.objectMappingDevName,dynSourceA1);
        dynamicSourceByObjMappingDevNameA.put(dynSourceA2.objectMappingDevName,dynSourceA2);
        dynamicSourceByObjMappingDevNameA.put(dynSourceA3.objectMappingDevName,dynSourceA3);

        BDI_DynamicSourceGroup dynSourceGroupA = new BDI_DynamicSourceGroup();
        dynSourceGroupA.dynamicSourceByObjMappingDevName = dynamicSourceByObjMappingDevNameA;
        dynSourceGroupA.name = additionalObjJSONFieldName;

        BDI_DynamicSource dynSourceB1 = new BDI_DynamicSource();
        dynSourceB1.objectMappingDevName = templateName +'01';
        dynSourceB1.objectMappingTemplateDevName = templateName;
        dynSourceB1.fieldMappingSetDevName = gauAllocFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceB1.sourceObj = sourceObjB1;

        BDI_DynamicSource dynSourceB2 = new BDI_DynamicSource();
        dynSourceB2.objectMappingDevName = templateName + '02';
        dynSourceB2.objectMappingTemplateDevName = templateName;
        dynSourceB2.fieldMappingSetDevName = gauAllocFieldMappings[0].Data_Import_Field_Mapping_Set;
        dynSourceB2.sourceObj = sourceObjB2;   
        
        Map<String,BDI_DynamicSource> dynamicSourceByObjMappingDevNameB = new Map<String,BDI_DynamicSource>();
        dynamicSourceByObjMappingDevNameB.put(dynSourceB1.objectMappingDevName,dynSourceB1);
        dynamicSourceByObjMappingDevNameB.put(dynSourceB2.objectMappingDevName,dynSourceB2);

        BDI_DynamicSourceGroup dynSourceGroupB = new BDI_DynamicSourceGroup();
        dynSourceGroupB.dynamicSourceByObjMappingDevName = dynamicSourceByObjMappingDevNameB;
        dynSourceGroupB.name = additionalObjJSONFieldName;

        String dynSourceGroupStringA = JSON.serialize(dynSourceGroupA);
        String dynSourceGroupStringB = JSON.serialize(dynSourceGroupB);

        testDataImportA.Additional_Object_JSON__c = dynSourceGroupStringA;
        testDataImportB.Additional_Object_JSON__c = dynSourceGroupStringB;

        //Blank out GAU allocation and OCR fields on DIs so we can test the dynamic source functionality.
        for (DataImport__c di : diRecords) {
            di.GAU_Allocation_1_Amount__c = null;
            di.GAU_Allocation_1_GAU__c = null;
            di.GAU_Allocation_1_Percent__c =  null;
            di.GAU_Allocation_2_Amount__c = null;
            di.GAU_Allocation_2_GAU__c = null;
            di.GAU_Allocation_2_Percent__c = null;
            di.Opportunity_Contact_Role_1_Role__c = null;
            di.Opportunity_Contact_Role_2_Role__c = null;
        }

        Test.StartTest();
        bdiDIS.process(null, dis, diRecords);
        Test.stopTest();

        DataImport__c testDataImportAResult;
        DataImport__c testDataImportBResult;

        for (DataImport__c di : [SELECT Id,
                                        Status__c,
                                        FailureInformation__c,
                                        Contact1_Lastname__c,
                                        Additional_Object_JSON__c,
                                        Account1ImportStatus__c,
                                        Account1Imported__c, 
                                        Account2ImportStatus__c,
                                        Account2Imported__c,
                                        Contact1ImportStatus__c,
                                        Contact1Imported__c,
                                        Contact2ImportStatus__c,
                                        Contact2Imported__c,
                                        DonationCampaignImportStatus__c,
                                        DonationCampaignImported__c,
                                        DonationImportStatus__c,
                                        DonationImported__c,
                                        GAU_Allocation_1_Import_Status__c,
                                        GAU_Allocation_1_Imported__c,
                                        GAU_Allocation_2_Import_Status__c,
                                        GAU_Allocation_2_Imported__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        Opportunity_Contact_Role_1_Imported__c,
                                        Opportunity_Contact_Role_1_ImportStatus__c,
                                        Opportunity_Contact_Role_2_Imported__c,
                                        Opportunity_Contact_Role_2_ImportStatus__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {
            
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDataImportAResult = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01') {
                testDataImportBResult = di;
            }
        }

        System.assertEquals(null,testDataImportAResult.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDataImportAResult.Status__c);
        System.assertNotEquals(null,testDataImportAResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportAResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiMatched,testDataImportAResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportAResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportAResult.HouseholdAccountImported__c);
        System.assertEquals(null,testDataImportAResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(null,testDataImportAResult.GAU_Allocation_1_Import_Status__c);
        System.assertEquals(null,testDataImportAResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(null,testDataImportAResult.GAU_Allocation_2_Import_Status__c);
        System.assertEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(null,testDataImportAResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertEquals(null,testDataImportAResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(null,testDataImportAResult.Opportunity_Contact_Role_2_ImportStatus__c);

        System.assert(testDataImportBResult.FailureInformation__c.contains(
                                                                'Additional Object JSON - GAU_Allocation_102'));
        System.assert(testDataImportBResult.FailureInformation__c.contains(
                                                            'Error: record not created, missing required fields:'));
        System.assert(testDataImportBResult.FailureInformation__c.contains(
                                                            'GAU_Allocation_1_GAU__c'));
        System.assertEquals(BDI_DataImport_API.bdiFailed,testDataImportBResult.Status__c);
        System.assertNotEquals(null,testDataImportBResult.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Account2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Account2ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.Contact2Imported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.Contact2ImportStatus__c);

        System.assertNotEquals(null,testDataImportBResult.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDataImportBResult.DonationImportStatus__c);
        System.assertNotEquals(null,testDataImportBResult.HouseholdAccountImported__c);
        System.assertEquals(null,testDataImportBResult.GAU_Allocation_1_Imported__c);
        System.assertEquals(null,testDataImportBResult.GAU_Allocation_1_Import_Status__c);
        System.assertEquals(null,testDataImportBResult.GAU_Allocation_2_Imported__c);
        System.assertEquals(null,testDataImportBResult.GAU_Allocation_2_Import_Status__c);
        System.assertEquals(null,testDataImportBResult.Opportunity_Contact_Role_1_Imported__c);
        System.assertEquals(null,testDataImportBResult.Opportunity_Contact_Role_1_ImportStatus__c);
        System.assertEquals(null,testDataImportBResult.Opportunity_Contact_Role_2_Imported__c);
        System.assertEquals(null,testDataImportBResult.Opportunity_Contact_Role_2_ImportStatus__c);

        BDI_DynamicSourceGroup dsgA = 
            (BDI_DynamicSourceGroup)JSON.deserialize(testDataImportAResult.Additional_Object_JSON__c,
                                                    BDI_DynamicSourceGroup.class);
        BDI_DynamicSourceGroup dsgB = 
            (BDI_DynamicSourceGroup)JSON.deserialize(testDataImportBResult.Additional_Object_JSON__c,
                                                    BDI_DynamicSourceGroup.class);

        BDI_DynamicSource dsA1 = dsgA.dynamicSourceByObjMappingDevName.get(dynSourceA1.objectMappingDevName);
        BDI_DynamicSource dsA2 = dsgA.dynamicSourceByObjMappingDevName.get(dynSourceA2.objectMappingDevName);
        BDI_DynamicSource dsA3 = dsgA.dynamicSourceByObjMappingDevName.get(dynSourceA3.objectMappingDevName);
        BDI_DynamicSource dsB1 = dsgB.dynamicSourceByObjMappingDevName.get(dynSourceB1.objectMappingDevName);
        BDI_DynamicSource dsB2 = dsgB.dynamicSourceByObjMappingDevName.get(dynSourceB2.objectMappingDevName);

        System.assert(dsA1 != null);
        System.assert(dsA2 != null);
        System.assert(dsA3 != null);
        System.assert(dsB1 != null);
        System.assert(dsB2 != null);
        System.assert(dsA1.importedRecordId != null);
        System.assert(dsA2.importedRecordId != null);
        System.assert(dsA3.importedRecordId != null);
        System.assert(dsB1.importedRecordId != null);
        System.assert(dsB2.importedRecordId == null); //Should not have been created
        System.assert(dsA1.importedRecordStatus == System.label.bdiCreated);
        System.assert(dsA2.importedRecordStatus == System.label.bdiCreated);
        System.assert(dsA3.importedRecordStatus == System.label.bdiCreated);
        System.assert(dsB1.importedRecordStatus == System.label.bdiCreated);
        System.assert(dsB2.importedRecordStatus.contains('Error'));

        Allocation__c gauAlloA1;
        Allocation__c gauAlloA2;
        Allocation__c gauAlloB1;
        Allocation__c gauAlloB2;
        Allocation__c[] gauAlloAll = new Allocation__c[]{};

        for (Allocation__c gauAllo : [SELECT Id, Opportunity__c, Payment__c, Percent__c, Amount__c
                                            FROM Allocation__c]){
            gauAlloAll.add(gauAllo);
            if (gauAllo.Id == dsA1.importedRecordId) {
                gauAlloA1 = gauAllo;
            } else if (gauAllo.Id == dsA2.importedRecordId ) {
                gauAlloA2 = gauAllo;
            } else if (gauAllo.Id == dsB1.importedRecordId ) {
                gauAlloB1 = gauAllo;
            } else if (gauAllo.Id == dsB2.importedRecordId ) {
                gauAlloB2 = gauAllo;
            }
        }

        // Confirm that the desired GAU Allocations were created correctly
        System.assertEquals(3,gauAlloAll.size());
        System.assertEquals(75,gauAlloA1.Percent__c);
        System.assertEquals(25,gauAlloA2.Percent__c);
        System.assertEquals(75,gauAlloB1.Percent__c);
        System.assertEquals(null,gauAlloB2);

        OpportunityContactRole ocrA1;
        OpportunityContactRole[] ocrAll = new OpportunityContactRole[]{};

        for (OpportunityContactRole ocr : [SELECT Id, ContactId, OpportunityId, Role 
                                            FROM OpportunityContactRole]) {

            ocrAll.add(ocr);
            if (ocr.Id == dsA3.importedRecordId ) {
                ocrA1 = ocr;
            } 
        }

        // Confirm that the desired ocr were created correctly
        // the number 5 includes the automatically created donor and household member OCRs
        System.assertEquals(5,ocrAll.size()); 
        System.assertEquals('Soft Credit',ocrA1.Role);
    }
}