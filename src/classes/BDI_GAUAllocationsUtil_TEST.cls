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
* @group Batch Data Import
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Tests helper methods to validate and process GAUs entered on the Data Import record.
*/
@IsTest
public with sharing class BDI_GAUAllocationsUtil_TEST {

    @IsTest
    static void gauValidationsShouldBeEnforced() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c =
                BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);


        General_Accounting_Unit__c gau1 = new General_Accounting_Unit__c(Name = 'TestGAU1',
                Active__c = true);

        General_Accounting_Unit__c gau2 = new General_Accounting_Unit__c(Name = 'TestGAU2',
                Active__c = true);

        General_Accounting_Unit__c gau3 = new General_Accounting_Unit__c(Name = 'TestGAU3',
                Active__c = true);

        General_Accounting_Unit__c[] testGAUs = new General_Accounting_Unit__c[]{gau1,gau2,gau3};
        insert testGAUs;

        Allocations_Settings__c alloSettings = new Allocations_Settings__c();
        alloSettings.Payment_Allocations_Enabled__c = true;
        alloSettings.Default_Allocations_Enabled__c = true;
        alloSettings.Default__c = gau3.Id;

        UTIL_CustomSettingsFacade.getAllocationsSettingsForTests(alloSettings);

        Campaign testCampaign = new Campaign(Name = 'TestGroupA with GAU',
                IsActive = true,
                StartDate = Date.today().addDays(-10),
                EndDate = Date.today().addDays(10));
        insert testCampaign;

        // RD with contact 1 as owner, should trigger error on having percent over 100
        DataImport__c testDataImportA =
                new DataImport__c(
                        Contact1_Firstname__c = 'Susie',
                        Contact1_Home_Phone__c = '555-321-0001',
                        Contact1_Lastname__c = 'TestGroupA01',
                        Contact1_Other_Phone__c = '555-456-0001',
                        Contact1_Personal_Email__c = 'testgroupAcontact01Personal@fakedata.com',
                        Contact1_Preferred_Email__c = 'testgroupAcontact01Preferred@fakedata.com',
                        Contact1_Preferred_Phone__c = '555-567-0001',
                        Recurring_Donation_Amount__c = 100,
                        Recurring_Donation_Date_Established__c = System.Date.Today(),
                        Recurring_Donation_Day_of_Month__c = '12',
                        Recurring_Donation_Installment_Frequency__c = 1,
                        Recurring_Donation_Installment_Period__c = 'Monthly',
                        Recurring_Donation_Effective_Date__c = System.Date.Today(),
                        Recurring_Donation_End_Date__c = null,
                        Recurring_Donation_Planned_Installments__c = null,
                        Recurring_Donation_Recurring_Type__c = null,
                        Recurring_Donation_Status__c = null,
                        Recurring_Donation_Status_Reason__c = null,
                        Donation_Donor__c = 'Contact1',
                        Donation_Amount__c = 100,
                        Donation_Date__c = System.Date.Today(),
                        Home_City__c = 'Fakeville',
                        Home_Country__c = 'United States',
                        Home_State_Province__c = 'California',
                        Home_Street__c = '100 Fake Blvd',
                        Home_Zip_Postal_Code__c = '94105',
                        Household_Phone__c = '555-789-0001',
                        Payment_Check_Reference_Number__c = '453',
                        Payment_Method__c = 'Check',
                        GAU_Allocation_1_Percent__c = 60,
                        GAU_Allocation_1_GAU__c = gau1.Id,
                        GAU_Allocation_2_Percent__c = 60,
                        GAU_Allocation_2_GAU__c = gau2.Id);

        // This will regression test receiving default gaus.
        DataImport__c testDataImportB =
                new DataImport__c(
                        Contact1_Firstname__c = 'Joe',
                        Contact1_Home_Phone__c = '555-321-0001',
                        Contact1_Lastname__c = 'TestGroupB01',
                        Contact1_Other_Phone__c = '555-456-0001',
                        Contact1_Personal_Email__c = 'testgroupBcontact01Personal@fakedata.com',
                        Contact1_Preferred_Email__c = 'testgroupBcontact01Preferred@fakedata.com',
                        Contact1_Preferred_Phone__c = '555-567-0001',
                        Donation_Donor__c = 'Contact1',
                        Donation_Amount__c = 100,
                        Home_City__c = 'Fakeville',
                        Home_Country__c = 'United States',
                        Home_State_Province__c = 'California',
                        Home_Street__c = '500 Fake Blvd',
                        Home_Zip_Postal_Code__c = '94105',
                        Household_Phone__c = '555-789-0001',
                        Payment_Check_Reference_Number__c = '453',
                        Payment_Method__c = 'Check');

        // RD with Account 1 as donor this should test happy path
        DataImport__c testDataImportC =
                new DataImport__c(Account1_City__c = 'Faketown',
                        Account1_Country__c = 'United States',
                        Account1_Name__c = 'TestGroupC Org 1',
                        Account1_Phone__c = '554-123-0001',
                        Account1_State_Province__c = 'California',
                        Account1_Street__c = '954 Fakey St',
                        Account1_Website__c = 'www.groupBfakeorgacct01.com',
                        Account1_Zip_Postal_Code__c = '20000',
                        Recurring_Donation_Amount__c = 300,
                        Recurring_Donation_Date_Established__c = System.Date.Today(),
                        Recurring_Donation_Day_of_Month__c = '12',
                        Recurring_Donation_Installment_Frequency__c = 1,
                        Recurring_Donation_Installment_Period__c = 'Monthly',
                        Recurring_Donation_Effective_Date__c = System.Date.Today().addDays(5),
                        Recurring_Donation_End_Date__c = null,
                        Recurring_Donation_Planned_Installments__c = null,
                        Recurring_Donation_Recurring_Type__c = null,
                        Recurring_Donation_Status__c = null,
                        Recurring_Donation_Status_Reason__c = null,
                        Donation_Donor__c = 'Account1',
                        Payment_Check_Reference_Number__c = '453',
                        Payment_Method__c = 'Check',
                        GAU_Allocation_1_Percent__c = 50,
                        GAU_Allocation_1_GAU__c = gau1.Id,
                        GAU_Allocation_2_Percent__c = 50,
                        GAU_Allocation_2_GAU__c = gau2.Id);

        // This will test mixing Default GAUs with partially allocated DI GAUs
        DataImport__c testDataImportD =
                new DataImport__c(
                        Contact1_Firstname__c = 'Jake',
                        Contact1_Home_Phone__c = '555-321-0034',
                        Contact1_Lastname__c = 'TestGroupD01',
                        Contact1_Other_Phone__c = '555-456-0034',
                        Contact1_Personal_Email__c = 'testgroupDcontact01Personal@fakedata.com',
                        Contact1_Preferred_Phone__c = '555-567-0034',
                        Donation_Donor__c = 'Contact1',
                        Donation_Amount__c = 100,
                        Home_City__c = 'Fakeville',
                        Home_Country__c = 'United States',
                        Home_State_Province__c = 'California',
                        Home_Street__c = '600 Faked Blvd',
                        Home_Zip_Postal_Code__c = '94105',
                        Household_Phone__c = '555-789-0034',
                        Payment_Check_Reference_Number__c = '452',
                        Payment_Method__c = 'Check',
                        GAU_Allocation_1_Percent__c = 50,
                        GAU_Allocation_1_GAU__c = gau1.Id);

        DataImport__c[] testDIs = new DataImport__c[]{testDataImportA,
                                                        testDataImportB,
                                                        testDataImportC,
                                                        testDataImportD};
        insert testDIs;

        Test.StartTest();
        BDI_DataImport_BATCH bdi = new BDI_DataImport_BATCH();
        ID ApexJobId = Database.executeBatch(bdi, 10);
        Test.stopTest();

        DataImport__c testDIResultA;
        DataImport__c testDIResultB;
        DataImport__c testDIResultC;
        DataImport__c testDIResultD;

        for (DataImport__c di : [SELECT Id,
                Status__c,
                FailureInformation__c,
                Contact1_Lastname__c,
                Account1_Name__c,
                Recurring_Donation_Day_of_Month__c,
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
                Donation_Donor__c,
                GAU_Allocation_1_Imported__c,
                GAU_Allocation_1_Import_Status__c,
                GAU_Allocation_2_Imported__c,
                GAU_Allocation_2_Import_Status__c,
                Recurring_Donation_Amount__c,
                RecurringDonationImported__c,
                RecurringDonationImportStatus__c,
                HomeAddressImportStatus__c,
                HomeAddressImported__c,
                HouseholdAccountImported__c,
                PaymentImportStatus__c,
                PaymentImported__c,
                Payment_Status__c,
                NPSP_Data_Import_Batch__c,
                Additional_Object_JSON__c
        FROM DataImport__c]) {
            if (di.Id == testDataImportA.Id) {
                testDIResultA = di;
            } else if (di.Id == testDataImportB.Id) {
                testDIResultB = di;
            } else if (di.Id == testDataImportC.Id) {
                testDIResultC = di;
            } else if (di.Id == testDataImportD.Id) {
                testDIResultD = di;
            }
        }

        // Test that this record did not process because of the error with the GAU Allocation over 100%
        System.assert(testDIResultA.FailureInformation__c.contains(label.bdiErrorGAUAllocationOver100));
        System.assertEquals(BDI_DataImport_API.bdiFailed,testDIResultA.Status__c);
        System.assertEquals(null,testDIResultA.Contact1Imported__c);
        System.assertEquals(null,testDIResultA.Contact1ImportStatus__c);
        System.assertEquals(null,testDIResultA.RecurringDonationImported__c);
        System.assertEquals(null,testDIResultA.RecurringDonationImportStatus__c);
        System.assertEquals(null,testDIResultA.DonationCampaignImported__c);
        System.assertEquals(null,testDIResultA.DonationImported__c);
        System.assertEquals(null,testDIResultA.DonationImportStatus__c);
        System.assertEquals(null,testDIResultA.HouseholdAccountImported__c);
        System.assertEquals(null,testDIResultA.HomeAddressImported__c);
        System.assertEquals(null,testDIResultA.GAU_Allocation_1_Imported__c);
        System.assertEquals(null,testDIResultA.GAU_Allocation_2_Imported__c);

        // Test that this record was created successfully, and later we will check that the default GAU was assigned.
        System.assertEquals(null,testDIResultB.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDIResultB.Status__c);
        System.assertNotEquals(null,testDIResultB.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultB.Contact1ImportStatus__c);
        System.assertEquals('Contact1',testDIResultB.Donation_Donor__c);
        System.assertNotEquals(null,testDIResultB.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultB.DonationImportStatus__c);
        System.assertNotEquals(null,testDIResultB.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDIResultB.HomeAddressImported__c);
        System.assertEquals(null,testDIResultB.GAU_Allocation_1_Imported__c);
        System.assertEquals(null,testDIResultB.GAU_Allocation_2_Imported__c);

        // Test that this DI did process successfully and created records appropriately
        System.assertEquals(null,testDIResultC.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDIResultC.Status__c);
        System.assertNotEquals(null,testDIResultC.Account1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultC.Account1ImportStatus__c);
        System.assertEquals(null,testDIResultC.DonationCampaignImported__c);
        System.assertEquals(null,testDIResultC.DonationCampaignImportStatus__c);
        System.assertNotEquals(null,testDIResultC.RecurringDonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultC.RecurringDonationImportStatus__c);
        System.assertEquals(null,testDIResultC.DonationImported__c);
        System.assertEquals(null,testDIResultC.DonationImportStatus__c);
        System.assertEquals(null,testDIResultC.HouseholdAccountImported__c);
        System.assertEquals(null,testDIResultC.HomeAddressImported__c);
        System.assertNotEquals(null,testDIResultC.GAU_Allocation_1_Imported__c);
        System.assertNotEquals(null,testDIResultC.GAU_Allocation_2_Imported__c);

        // Test that this record was created successfully, and the partial GAU allocation was created
        System.assertEquals(null,testDIResultD.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDIResultD.Status__c);
        System.assertNotEquals(null,testDIResultD.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultD.Contact1ImportStatus__c);
        System.assertEquals('Contact1',testDIResultD.Donation_Donor__c);
        System.assertNotEquals(null,testDIResultD.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultD.DonationImportStatus__c);
        System.assertNotEquals(null,testDIResultD.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDIResultD.HomeAddressImported__c);
        System.assertNotEquals(null,testDIResultD.GAU_Allocation_1_Imported__c);

        Allocation__c opptB1Alloc;
        Allocation__c pymtB1Alloc;
        Allocation__c opptDgau1Alloc;
        Allocation__c opptDgau3Alloc;
        Allocation__c pymtDgau1Alloc;
        Allocation__c pymtDgau3Alloc;

        for(Allocation__c alloc : [SELECT Id,
                Opportunity__c,
                Recurring_Donation__c,
                Payment__c,
                General_Accounting_Unit__c,
                Amount__c,
                Percent__c
        FROM Allocation__c]) {
            System.debug('Allocation is: ' + alloc);
            if (alloc.Opportunity__c == testDIResultB.DonationImported__c) {
                opptB1Alloc = alloc;
            } else if (alloc.Payment__c == testDIResultB.PaymentImported__c) {
                pymtB1Alloc = alloc;
            } else if (alloc.Opportunity__c == testDIResultD.DonationImported__c &&
                    alloc.General_Accounting_Unit__c == gau1.Id) {
                opptDgau1Alloc = alloc;
            } else if (alloc.Opportunity__c == testDIResultD.DonationImported__c &&
                    alloc.General_Accounting_Unit__c == gau3.Id) {
                opptDgau3Alloc = alloc;
            } else if (alloc.Payment__c == testDIResultD.PaymentImported__c &&
                    alloc.General_Accounting_Unit__c == gau1.Id) {
                pymtDgau1Alloc = alloc;
            } else if (alloc.Payment__c == testDIResultD.PaymentImported__c &&
                    alloc.General_Accounting_Unit__c == gau3.Id) {
                pymtDgau3Alloc = alloc;
            }
        }

        System.assertNotEquals(null,opptB1Alloc);
        System.assertNotEquals(null,pymtB1Alloc);
        System.assertNotEquals(null,opptDgau1Alloc);
        System.assertNotEquals(null,opptDgau3Alloc);
        System.assertNotEquals(null,pymtDgau1Alloc);
        System.assertNotEquals(null,pymtDgau3Alloc);
        System.assertEquals(opptB1Alloc.General_Accounting_Unit__c,gau3.id);
        System.assertEquals(pymtB1Alloc.General_Accounting_Unit__c,gau3.id);

        // This test record should trigger errors for both donation and payment allocations existing.
        DataImport__c testDIB2 = new DataImport__c(Account1Imported__c = testDIResultB.Account1Imported__c,
                                                    DonationImported__c = testDIResultB.DonationImported__c,
                                                    PaymentImported__c = testDIResultB.PaymentImported__c,
                                                    GAU_Allocation_1_GAU__c = gau1.Id,
                                                    GAU_Allocation_1_Percent__c = 100);

        // Modify the existing test Data import C record with a new GAU to simulate trying to update Oppt with
        testDIB2.GAU_Allocation_1_Import_Status__c = null;
        testDIB2.GAU_Allocation_1_Imported__c = null;
        testDIB2.GAU_Allocation_1_Percent__c = 100;
        testDIB2.GAU_Allocation_1_GAU__c = gau3.Id;
        testDIB2.Status__c = null;
        testDIB2.FailureInformation__c = null;
        testDIB2.GAU_Allocation_2_Import_Status__c = null;
        testDIB2.GAU_Allocation_2_Imported__c = null;
        testDIB2.GAU_Allocation_2_Percent__c = null;
        testDIB2.GAU_Allocation_2_GAU__c = null;

        DataImport__c[] testDIs2 = new DataImport__c[]{testDIB2};
        insert testDIs2;

        BDI_DataImport_API.processDataImportRecords(dis,testDIs2, false);

        DataImport__c testDIResultB2 = [SELECT Id,
                                                Status__c,
                                                FailureInformation__c,
                                                Contact1_Lastname__c,
                                                Account1_Name__c,
                                                Recurring_Donation_Day_of_Month__c,
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
                                                Donation_Donor__c,
                                                GAU_Allocation_1_Imported__c,
                                                GAU_Allocation_1_Import_Status__c,
                                                GAU_Allocation_2_Imported__c,
                                                GAU_Allocation_2_Import_Status__c,
                                                Recurring_Donation_Amount__c,
                                                RecurringDonationImported__c,
                                                RecurringDonationImportStatus__c,
                                                HomeAddressImportStatus__c,
                                                HomeAddressImported__c,
                                                HouseholdAccountImported__c,
                                                PaymentImportStatus__c,
                                                PaymentImported__c
                                        FROM DataImport__c
                                        WHERE Id =: testDIB2.Id LIMIT 1];

        System.assertNotEquals(null,testDIResultB2);
        // Confirm that both error messages were logged in FailureInformation
        System.assert(testDIResultB2.FailureInformation__c.contains(label.bdiErrorExistingDonationAllocations));
        System.assert(testDIResultB2.FailureInformation__c.contains(label.bdiErrorExistingPaymentAllocations));
    }
}