@isTest
private class BDI_RecurringDonations_TEST {
    static final String RD_STATUS_CLOSED = 'Closed';

    @TestSetup
    static void setupTestData(){

        General_Accounting_Unit__c gau1 = new General_Accounting_Unit__c(Name = 'TestGAU1',
                Active__c = true);

        General_Accounting_Unit__c gau2 = new General_Accounting_Unit__c(Name = 'TestGAU2',
                Active__c = true);

        General_Accounting_Unit__c gau3 = new General_Accounting_Unit__c(Name = 'TestGAU3',
                Active__c = true);

        General_Accounting_Unit__c[] testGAUs = new General_Accounting_Unit__c[]{gau1,gau2,gau3};
        insert testGAUs;

        Campaign testCampaign = new Campaign(Name = 'TestGroupA Campaign',
                                        IsActive = true,
                                        StartDate = Date.today().addDays(-10), 
                                        EndDate = Date.today().addDays(10));
        insert testCampaign;

        //RD with contact1 as donor and with donation being created at same time.
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
                    DonationCampaignImported__c = testCampaign.Id,
                    Home_City__c = 'Fakeville',
                    Home_Country__c = 'United States',
                    Home_State_Province__c = 'California',
                    Home_Street__c = '100 Fake Blvd',
                    Home_Zip_Postal_Code__c = '94105',
                    Household_Phone__c = '555-789-0001',
                    Payment_Check_Reference_Number__c = '453',
                    Payment_Method__c = 'Check',
                    GAU_Allocation_1_Percent__c = 100,
                    GAU_Allocation_1_GAU__c = gau1.Id);


        //RD with Contact1 as donor, yearly schedule, and creation of new campaign
        DataImport__c testDataImportB = 
                new DataImport__c(
                    Contact1_Firstname__c = 'Joe',
                    Contact1_Home_Phone__c = '555-321-0001',
                    Contact1_Lastname__c = 'TestGroupB01',
                    Contact1_Other_Phone__c = '555-456-0001',
                    Contact1_Personal_Email__c = 'testgroupBcontact01Personal@fakedata.com',
                    Contact1_Preferred_Email__c = 'testgroupBcontact01Preferred@fakedata.com',
                    Contact1_Preferred_Phone__c = '555-567-0001',
                    Recurring_Donation_Amount__c = 200,
                    Recurring_Donation_Date_Established__c = System.Date.Today(),
                    Recurring_Donation_Day_of_Month__c = '15',
                    Recurring_Donation_Installment_Frequency__c = 1,
                    Recurring_Donation_Installment_Period__c = 'Yearly',	
                    Recurring_Donation_Effective_Date__c = System.Date.Today().addDays(5),
                    Recurring_Donation_End_Date__c = null,
                    Recurring_Donation_Planned_Installments__c = null,
                    Recurring_Donation_Recurring_Type__c = null,
                    Recurring_Donation_Status__c = null,
                    Recurring_Donation_Status_Reason__c = null,	
                    Donation_Campaign_Name__c = 'Test Campaign 2',
                    Donation_Donor__c = null, //leaving this null to test defaulting of contact1
                    Home_City__c = 'Fakeville',
                    Home_Country__c = 'United States',
                    Home_State_Province__c = 'California',
                    Home_Street__c = '500 Fake Blvd',
                    Home_Zip_Postal_Code__c = '94105',
                    Household_Phone__c = '555-789-0001',
                    Payment_Check_Reference_Number__c = '453',
                    Payment_Method__c = 'Check');

        //RD with Account 1 as donor 
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
                    Payment_Method__c = 'Check');

        //RD with Account1 as donor, but no donor info
        DataImport__c testDataImportD = 
                    new DataImport__c(Account1_City__c = null,
                        Account1_Country__c = null,
                        Account1_Name__c = null,
                        Account1_Phone__c = null,
                        Account1_State_Province__c = null,
                        Account1_Street__c = null,    
                        Account1_Website__c = null,
                        Account1_Zip_Postal_Code__c = null,
                        Recurring_Donation_Amount__c = 400,
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
                        Payment_Method__c = 'Check');
        insert new DataImport__c[]{testDataImportA,testDataImportB,testDataImportC,testDataImportD};
        
    }


    @isTest
    static void shouldCreateAndUpdateRecurringDonation() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        General_Accounting_Unit__c gau1;
        General_Accounting_Unit__c gau2;
        General_Accounting_Unit__c gau3;

        for (General_Accounting_Unit__c gau : [SELECT Id, Name
                                                FROM General_Accounting_Unit__c
                                                LIMIT 10]) {
            if (gau.Name == 'TestGAU1') {
                gau1 = gau;
            } else if (gau.Name == 'TestGAU2') {
                gau2 = gau;
            } else if (gau.Name == 'TestGAU3') {
                gau3 = gau;
            }
        }

        Allocations_Settings__c alloSettings = new Allocations_Settings__c();
        alloSettings.Payment_Allocations_Enabled__c = true;
        alloSettings.Default_Allocations_Enabled__c = true;
        alloSettings.Default__c = gau3.Id;

        UTIL_CustomSettingsFacade.getAllocationsSettingsForTests(alloSettings);

        Data_Import_Settings__c dis = UTIL_CustomSettingsFacade.getDataImportSettings();
        dis.Field_Mapping_Method__c = BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING;
        dis.Default_Data_Import_Field_Mapping_Set__c = 
            BDI_MappingServiceAdvanced.DEFAULT_DATA_IMPORT_FIELD_MAPPING_SET_NAME;
        UTIL_CustomSettingsFacade.setDataImportSettings(dis);

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
                                        Recurring_Donation_Amount__c,
                                        RecurringDonationImported__c,
                                        RecurringDonationImportStatus__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {
            if (di.Contact1_Lastname__c == 'TestGroupA01') {
                testDIResultA = di;
            } else if (di.Contact1_Lastname__c == 'TestGroupB01') {
                testDIResultB = di;
            } else if (di.Account1_Name__c == 'TestGroupC Org 1') {
                testDIResultC = di;
            } else if (di.Recurring_Donation_Amount__c == 400) {
                testDIResultD = di;
            }
        }

        //RD with contact1 as donor and with donation being created at same time.
        System.assertEquals(null,testDIResultA.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDIResultA.Status__c);
        System.assertNotEquals(null,testDIResultA.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultA.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDIResultA.RecurringDonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultA.RecurringDonationImportStatus__c);
        System.assertNotEquals(null,testDIResultA.DonationCampaignImported__c);
        System.assertNotEquals(null,testDIResultA.DonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultA.DonationImportStatus__c);
        System.assertNotEquals(null,testDIResultA.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDIResultA.HomeAddressImported__c);
        System.assertNotEquals(null,testDIResultA.GAU_Allocation_1_Imported__c);
        System.assertNotEquals(null,testDIResultA.PaymentImported__c);

        //RD with Contact1 as donor, yearly schedule, and creation of new campaign
        System.assertEquals(null,testDIResultB.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiImported,testDIResultB.Status__c);
        System.assertNotEquals(null,testDIResultB.Contact1Imported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultB.Contact1ImportStatus__c);
        System.assertNotEquals(null,testDIResultB.RecurringDonationImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultB.RecurringDonationImportStatus__c);
        System.assertNotEquals(null,testDIResultB.DonationCampaignImported__c);
        System.assertEquals(System.label.bdiCreated,testDIResultB.DonationCampaignImportStatus__c);
        System.assertEquals('Contact1',testDIResultB.Donation_Donor__c); //should have been defaulted
        System.assertEquals(null,testDIResultB.DonationImported__c);
        System.assertEquals(null,testDIResultB.DonationImportStatus__c);
        System.assertNotEquals(null,testDIResultB.HouseholdAccountImported__c);
        System.assertNotEquals(null,testDIResultB.HomeAddressImported__c);

        //RD with Account 1 as donor 
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

        //RD with Account1 as donor, but no donor info
        System.assertNotEquals(null,testDIResultD.FailureInformation__c);
        System.assertEquals(BDI_DataImport_API.bdiFailed,testDIResultD.Status__c);
        System.assertEquals(null,testDIResultD.Account1Imported__c);
        System.assertEquals(null,testDIResultD.Account1ImportStatus__c);
        System.assertEquals(null,testDIResultD.RecurringDonationImported__c);
        System.assert(
            testDIResultD.RecurringDonationImportStatus__c.contains(System.label.bdiErrorInvalidDonor));
        System.assertEquals(null,testDIResultD.DonationImported__c);
        System.assertEquals(null,testDIResultD.DonationImportStatus__c);
        System.assertEquals(null,testDIResultD.HouseholdAccountImported__c);
        System.assertEquals(null,testDIResultD.HomeAddressImported__c);

        npe03__Recurring_Donation__c rdA;
        npe03__Recurring_Donation__c rdB;
        npe03__Recurring_Donation__c rdC;

        npe03__Recurring_Donation__c[] rdResults = [SELECT Id, 
                                                        npe03__Amount__c,
                                                        npe03__Contact__c,
                                                        npe03__Organization__c,
                                                        InstallmentFrequency__c,
                                                        npe03__Installment_Period__c,
                                                        npe03__Recurring_Donation_Campaign__c,
                                                        RecurringType__c,
                                                        CommitmentId__c,
                                                        StartDate__c,
                                                        npe03__Date_Established__c,
                                                        Day_of_Month__c,
                                                        Status__c,
                                                        npe03__Installments__c,
                                                        npe03__Total__c
                                                    FROM npe03__Recurring_Donation__c];
        System.assertEquals(3,rdResults.size());

        for (npe03__Recurring_Donation__c rd : rdResults){
            if (rd.Id == testDIResultA.RecurringDonationImported__c) {
                rdA = rd;
            } else if (rd.Id == testDIResultB.RecurringDonationImported__c) {
                rdB = rd;
            } else if (rd.Id == testDIResultC.RecurringDonationImported__c) {
                rdC = rd;
            }
        }

        System.assertNotEquals(null,rdA);
        System.assertEquals(testDIResultA.Contact1Imported__c, rdA.npe03__Contact__c);
        System.assertEquals(100, rdA.npe03__Amount__c);
        System.assertEquals(null,rdA.CommitmentId__c);
        System.assertEquals(testDIResultA.HouseholdAccountImported__c,rdA.npe03__Organization__c);
        System.assertEquals('Active',rdA.Status__c);
        System.assertEquals('Monthly',rdA.npe03__Installment_Period__c);
        System.assertEquals(testDIResultA.DonationCampaignImported__c,rdA.npe03__Recurring_Donation_Campaign__c);
        System.assertEquals(testDIResultA.Recurring_Donation_Day_Of_Month__c,rdA.Day_Of_Month__c);
        System.assertEquals(1,rdA.InstallmentFrequency__c);

        System.assertNotEquals(null,rdB);
        System.assertEquals(testDIResultB.Contact1Imported__c, rdB.npe03__Contact__c);
        System.assertEquals(200, rdB.npe03__Amount__c);
        System.assertEquals(null,rdB.CommitmentId__c);
        System.assertEquals(testDIResultB.HouseholdAccountImported__c,rdB.npe03__Organization__c);
        System.assertEquals(testDIResultB.DonationCampaignImported__c,rdB.npe03__Recurring_Donation_Campaign__c);
        System.assertEquals('Active',rdB.Status__c);
        System.assertEquals('Yearly',rdB.npe03__Installment_Period__c);
        System.assertEquals(1,rdB.InstallmentFrequency__c);

        System.assertNotEquals(null,rdC);
        System.assertEquals(null, rdC.npe03__Contact__c);
        System.assertEquals(300, rdC.npe03__Amount__c);
        System.assertEquals(null,rdC.CommitmentId__c);
        System.assertEquals(testDIResultC.Account1Imported__c,rdC.npe03__Organization__c);
        System.assertEquals('Active',rdC.Status__c);
        System.assertEquals('Monthly',rdC.npe03__Installment_Period__c);
        System.assertEquals(testDIResultC.Recurring_Donation_Day_Of_Month__c,rdC.Day_Of_Month__c);
        System.assertEquals(1,rdC.InstallmentFrequency__c);

        Allocation__c rdA1Alloc;
        Allocation__c opptA1Alloc;
        Allocation__c pymtA1Alloc;

        for(Allocation__c alloc : [SELECT Id,
                                    Opportunity__c,
                                    Recurring_Donation__c,
                                    Payment__c,
                                    General_Accounting_Unit__c,
                                    Amount__c,
                                    Percent__c
                                    FROM Allocation__c]) {
            System.debug('Allocation is: ' + alloc);
            if (alloc.Recurring_Donation__c == testDIResultA.RecurringDonationImported__c) {
                rdA1Alloc = alloc;
            } else if (alloc.Opportunity__c == testDIResultA.DonationImported__c) {
                opptA1Alloc = alloc;
            } else if (alloc.Payment__c == testDIResultA.PaymentImported__c) {
                pymtA1Alloc = alloc;
            }
        }

        System.assertNotEquals(null,rdA1Alloc);
        System.assertEquals(gau1.Id,rdA1Alloc.General_Accounting_Unit__c);
        System.assertNotEquals(null,opptA1Alloc);
        System.assertEquals(gau1.Id,opptA1Alloc.General_Accounting_Unit__c);
        System.assertNotEquals(null,pymtA1Alloc);
        System.assertEquals(gau1.Id,pymtA1Alloc.General_Accounting_Unit__c);

        //Updating this DI to close RD
        DataImport__c diAUpdate = 
            new DataImport__c(
                            Contact1Imported__c = testDIResultA.Contact1Imported__c,
                            RecurringDonationImported__c = testDIResultA.RecurringDonationImported__c,
                            Recurring_Donation_Status__c = RD_STATUS_CLOSED,
                            Recurring_Donation_End_Date__c = System.Date.Today(),
                            Recurring_Donation_Status_Reason__c = 'No Longer Interested');

        DataImport__c diBUpdate = 
            new DataImport__c(
                            Contact1Imported__c = testDIResultB.Contact1Imported__c,
                            RecurringDonationImported__c = testDIResultB.RecurringDonationImported__c,
                            Recurring_Donation_Amount__c = 250);

        DataImport__c diCUpdate = 
            new DataImport__c(
                            RecurringDonationImported__c = testDIResultC.RecurringDonationImported__c,
                            Recurring_Donation_Status__c = RD_STATUS_CLOSED,
                            Recurring_Donation_End_Date__c = System.Date.Today().addDays(-1),
                            Recurring_Donation_Status_Reason__c = 'No Longer Interested');

        DataImport__c[] disForUpdate = new DataImport__c[]{diAUpdate,diBUpdate,diCUpdate};
        insert disForUpdate;

        //Process updated DIs
        BDI_DataImport_API.processDataImportRecords(dis, disForUpdate, false);

        DataImport__c testDIResultA2;
        DataImport__c testDIResultB2;
        DataImport__c testDIResultC2;
        
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
                                        RecurringDonationImported__c,
                                        RecurringDonationImportStatus__c,
                                        Recurring_Donation_Status__c,
                                        Recurring_Donation_Amount__c,
                                        HomeAddressImportStatus__c,
                                        HomeAddressImported__c,
                                        HouseholdAccountImported__c,
                                        PaymentImportStatus__c,
                                        PaymentImported__c
                                    FROM DataImport__c]) {
            if (di.Id == diAUpdate.Id) {
                testDIResultA2 = di;
            } else if (di.Id == diBUpdate.Id) {
                testDIResultB2 = di;
            } else if (di.Id == diCUpdate.Id) {
                testDIResultC2 = di;
            }
        }
        
        System.assertEquals(System.Label.bdiImported,testDIResultA2.Status__c);
        System.assertEquals(System.Label.bdiUpdated,testDIResultA2.RecurringDonationImportStatus__c);

        System.assertEquals(System.Label.bdiImported,testDIResultB2.Status__c);
        System.assertEquals(System.Label.bdiUpdated,testDIResultB2.RecurringDonationImportStatus__c);

        npe03__Recurring_Donation__c rdA2;
        npe03__Recurring_Donation__c rdB2;
        npe03__Recurring_Donation__c rdC2;

        npe03__Recurring_Donation__c[] rdResults2 = [SELECT Id, 
                                                        npe03__Amount__c,
                                                        npe03__Contact__c,
                                                        npe03__Organization__c,
                                                        InstallmentFrequency__c,
                                                        npe03__Installment_Period__c,
                                                        RecurringType__c,
                                                        CommitmentId__c,
                                                        ClosedReason__c,
                                                        StartDate__c,
                                                        EndDate__c,
                                                        npe03__Date_Established__c,
                                                        Day_of_Month__c,
                                                        Status__c,
                                                        npe03__Installments__c,
                                                        npe03__Total__c
                                                    FROM npe03__Recurring_Donation__c];
        System.assertEquals(3,rdResults2.size());

        for (npe03__Recurring_Donation__c rd : rdResults2){
            if (rd.Id == testDIResultA.RecurringDonationImported__c) {
                rdA2 = rd;
            } else if (rd.Id == testDIResultB.RecurringDonationImported__c) {
                rdB2 = rd;
            } else if (rd.Id == testDIResultC.RecurringDonationImported__c) {
                rdC2 = rd;
            }
        }
        System.assertNotEquals(null,rdA2);
        System.assertEquals(100, rdA2.npe03__Amount__c);
        System.assertEquals('No Longer Interested',rdA2.ClosedReason__c);
        System.assertEquals(RD_STATUS_CLOSED, rdA2.Status__c);
        System.assertEquals(testDIResultA.Contact1Imported__c, rdA2.npe03__Contact__c);

        System.assertNotEquals(null,rdB2);
        System.assertEquals(250, rdB2.npe03__Amount__c);

        System.assertNotEquals(null,rdC2);
        System.assertEquals(300, rdC2.npe03__Amount__c);
        System.assertEquals('No Longer Interested',rdC2.ClosedReason__c);
        System.assertEquals(RD_STATUS_CLOSED, rdC2.Status__c);
    }

    /*******************************************************************************************************
    * @description This unit test validates that the basic Id matching functionality works for recurring donation and
    * that the correct status is set during dry run for recurring donations.  It also verifies that just specifying an
    * Id for the Recurring Donation will allow the user to create a new Donation for that Recurring Donation and link
    * it correctly.
    */
    @isTest
    static void shouldRunBDIDryRunAndMatchAndImportNewDonationOnExistingRD() {

        Account testAccount = new Account(name = 'testAcct');
        insert testAccount;

        // Insert recurring donation with commitmentId to test dupe suppression for accounts.
        npe03__Recurring_Donation__c testExistingRD = new npe03__Recurring_Donation__c(
                npe03__Organization__c = testAccount.Id,
                npe03__Amount__c = 200,
                InstallmentFrequency__c = 1,
                npe03__Installment_Period__c = 'Monthly',
                Day_of_Month__c = String.valueOf(System.date.today().day()),
                RecurringType__c = 'Open',
                Status__c = 'Active',
                StartDate__c = System.date.today());

        insert testExistingRD;


        DataImport__c testDI1 = new DataImport__c(Account1Imported__c = testAccount.Id,
                                                    RecurringDonationImported__c = testExistingRD.Id,
                                                    Donation_Donor__c = 'Account1',
                                                    Donation_Amount__c = 100,
                                                    Donation_Date__c = System.Date.Today().addDays(10),
                                                    Payment_Check_Reference_Number__c = '501',
                                                    Payment_Method__c = 'Check');
        insert testDI1;

        DataImport__c[] testDIs = new DataImport__c[]{testDI1};

        Data_Import_Settings__c diSettings = UTIL_CustomSettings_API.getDataImportSettings();
        diSettings.Field_Mapping_Method__c = 'Data Import Field Mapping';

        // Run BDI in dry run mode to make sure the Recurring Donation matched and is in the correct import status
        BDI_DataImport_API.processDataImportRecords(diSettings,testDIs, true);

        testDI1 = [SELECT Id,
                            Status__c,
                            FailureInformation__c,
                            Contact1_Lastname__c,
                            Account1_Name__c,
                            Account1ImportStatus__c,
                            Account1Imported__c,
                            Account2ImportStatus__c,
                            Account2Imported__c,
                            DonationImportStatus__c,
                            DonationImported__c,
                            RecurringDonationImported__c,
                            RecurringDonationImportStatus__c,
                            Recurring_Donation_Status__c,
                            Recurring_Donation_Amount__c,
                            HomeAddressImportStatus__c,
                            HomeAddressImported__c,
                            HouseholdAccountImported__c,
                            PaymentImportStatus__c,
                            PaymentImported__c
                    FROM DataImport__c
                    WHERE Id =: testDI1.Id LIMIT 1];


        System.assertEquals(BDI_DataImport_API.bdiDryRunValidated, testDI1.Status__c);
        System.assertEquals(null, testDI1.FailureInformation__c);
        System.assertEquals(System.Label.bdiDryRunMatched,testDI1.Account1ImportStatus__c);
        System.assertEquals(System.Label.bdiDryRunMatched,testDI1.RecurringDonationImportStatus__c);


        // Now run BDI on the DI record with dry run set to false to validate that the records are imported.
        Test.startTest();
        BDI_DataImport_API.processDataImportRecords(diSettings,testDIs, false);
        Test.stopTest();

        // Requery the DI record to see the results after non-DryRun processing.
        testDI1 = [SELECT Id,
                        Status__c,
                        FailureInformation__c,
                        Contact1_Lastname__c,
                        Account1_Name__c,
                        Account1ImportStatus__c,
                        Account1Imported__c,
                        Account2ImportStatus__c,
                        Account2Imported__c,
                        DonationImportStatus__c,
                        DonationImported__c,
                        RecurringDonationImported__c,
                        RecurringDonationImportStatus__c,
                        Recurring_Donation_Status__c,
                        Recurring_Donation_Amount__c,
                        HomeAddressImportStatus__c,
                        HomeAddressImported__c,
                        HouseholdAccountImported__c,
                        PaymentImportStatus__c,
                        PaymentImported__c
                FROM DataImport__c
                WHERE Id =: testDI1.Id LIMIT 1];

        // Verify that the donation was imported and that the import status on the Recurring Donation is correct.
        System.assertEquals(System.Label.bdiImported, testDI1.Status__c);
        System.assertNotEquals(null,testDI1.DonationImported__c);
        System.assertEquals(null, testDI1.FailureInformation__c);
        System.assertEquals(System.Label.bdiCreated,testDI1.DonationImportStatus__c);
        System.assertEquals(System.Label.bdiMatched,testDI1.RecurringDonationImportStatus__c);
        System.assertNotEquals(null,testDI1.RecurringDonationImported__c);

        // Query the opportunity to make sure it was correctly linked to the RD.
        Opportunity rdOppt1 = [SELECT Id, npe03__Recurring_Donation__c
                                FROM Opportunity
                                WHERE Id =: testDI1.DonationImported__c LIMIT 1];

        System.assertEquals(testDI1.RecurringDonationImported__c,rdOppt1.npe03__Recurring_Donation__c);
    }
}