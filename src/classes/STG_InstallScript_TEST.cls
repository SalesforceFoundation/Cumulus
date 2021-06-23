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
* @date 2014
* @group Settings
* @description Test Class for the Install Script for the NPSP package.
*/
@isTest
public with sharing class STG_InstallScript_TEST {

    private static final Integer ROLLUP_BATCH_SIZE = 333;

    /*******************************************************************************************************
    * @description A test exception class
    */
    private class STG_InstallException extends Exception {}

    /*********************************************************************************************************
    @description
        Test install on a new org populates the default settings and
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults.
    **********************************************************************************************************/
    @isTest
    public static void newInstallCreatesDefaultSettings() {
        Test.testInstall(new STG_InstallScript(), null);
        verifyAllSettingsCreated();
    }

    /*********************************************************************************************************
    @description
        Test install on org with some partial settings will still populate the default settings and
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults.
    **********************************************************************************************************/
    @isTest
    public static void newInstallPopulatesMissingSettings() {
        createSomeDefaultSettings();
        Test.testInstall(new STG_InstallScript(), null);
        verifyAllSettingsCreated();
    }

    /*********************************************************************************************************
    @description
        Test install on org with some deprecated settings will still populate the default settings and
        remove the deprecated setting
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults.
    **********************************************************************************************************/
    @isTest
    public static void newInstallRemovesDeprecatedSettings() {
        createSomeDefaultSettings();

        insert new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
              Class__c = 'OPP_OpportunityNaming_TDTM', Load_Order__c = 0, Object__c = 'Opportunity',
              Trigger_Action__c = 'AfterInsert;AfterUpdate;AfterDelete');

        Test.testInstall(new STG_InstallScript(), null);
        verifyAllSettingsCreated();
    }

    /*********************************************************************************************************
    @description
        Test a push install will create the default settings and update any partial settings
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults
    **********************************************************************************************************/
    @isTest
    public static void pushInstallCreatesDefaultSettingsAndPopulatesPartialSettings() {
        createSomeDefaultSettings();
        Customizable_Rollup_Settings__c expectedConfig = buildRollupSettingsWithPartialValues();
        Test.testInstall(new STG_InstallScript(), new Version(1,0), true);
        verifyAllSettingsCreated();
        assertRollupSettingsEqual(expectedConfig);
    }

    /*********************************************************************************************************
    @description
        Test a manual upgrade install will create the default settings and update any partial settings
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults
    **********************************************************************************************************/
    @isTest
    public static void upgradeInstallCreatesDefaultSettingsAndPopulatesPartialSettings() {
        createSomeDefaultSettings();
        Customizable_Rollup_Settings__c expectedConfig = buildRollupSettingsWithPartialValues();
        Test.testInstall(new STG_InstallScript(), new Version(1,0), false);
        verifyAllSettingsCreated();
        assertRollupSettingsEqual(expectedConfig);
    }

    /*********************************************************************************************************
    @description
        Test new install with flags all disable flags off will still create all the default settings
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults
    **********************************************************************************************************/
    @isTest
    public static void newInstallWithDisableFlagsOffCreatesDefaultSettings() {
        setAllNpspFlags(false);
        Test.testInstall(new STG_InstallScript(), null);
        verifyAllSettingsCreated();
    }

    /*********************************************************************************************************
    @description
        Test new install with flags all disable flags on will still create all the default settings
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults
    **********************************************************************************************************/
    @isTest
    public static void newInstallWithDisableFlagsEnabledCreatesDefaultSettings() {
        setAllNpspFlags(true);
        Test.testInstall(new STG_InstallScript(), null);

        List<String> tdtmClasses = TDTM_DefaultConfig.getNpspToCumulusMap().values();
        Set<String> tdtmClassesWithValues = new Set<String>();
        for(String tdtmClass : tdtmClasses) {
            if(!String.isBlank(tdtmClass)) {
                tdtmClassesWithValues.add(tdtmClass);
            }
        }

        //Verify that all the TDTM classes have been deactivated (since all the NPSP disable flags were on)
        Set<String> afterScriptConfigClassNames = new Set<String>();
        for(Trigger_Handler__c handler : [select Active__c, Class__c from Trigger_Handler__c where Class__c IN :tdtmClasses]) {
            System.assertEquals(false, handler.Active__c, 'This handler should have be marked as inactive: ' + handler);
            afterScriptConfigClassNames.add(handler.Class__c);
        }

        System.assertEquals(tdtmClassesWithValues.size(), afterScriptConfigClassNames.size(),
                'The number of inactive handler classes does not match the expected value');

        assertNpspFlagsDeactivated();
    }

    /*********************************************************************************************************
    @description
        Test new install with flags some disable flags on will still create all the default settings
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults
    **********************************************************************************************************/
    @isTest
    public static void newInstallWithSomeDisableFlagsEnabledCreatesDefaultSettings() {
        //Create NPSP custom settings with some disable flags on
        List<SObject> settingsToUpdate = new List<SObject>();

        //Modify settings only in-memory for the test, so it can be run in parallel
        npe01__Contacts_And_Orgs_Settings__c npe01Settings = UTIL_CustomSettingsFacade.getOrgContactsSettings();
        npe01Settings.npe01__DISABLE_IndividualAccounts_trigger__c = true;
        npe01Settings.npe01__DISABLE_OpportunityAccount_trigger__c = true;

        npo02__Households_Settings__c npo02Settings = UTIL_CustomSettingsFacade.getOrgHouseholdsSettings();
        npo02Settings.npo02__DISABLE_Household_Opportunity_trigger__c = true;

        Test.testInstall(new STG_InstallScript(), null);

        //Verify that the right TDTM classes have been deactivated
        List<String> mappedTdtmClasses = new String[] {'ACCT_IndividualAccounts_TDTM', 'OPP_OpportunityContactRoles_TDTM',
                                                               'HH_OppContactRoles_TDTM'};
        List<Trigger_Handler__c> afterScriptConfig = [select Active__c, Class__c from Trigger_Handler__c where Class__c IN :mappedTdtmClasses];
        for(Trigger_Handler__c handler : afterScriptConfig) {
            System.assertEquals(false, handler.Active__c, 'The handler class ' + handler.Class__c + ' should not be active');
        }

        //Assert old flags have been properly disabled
        assertNpspFlagsDeactivated();
    }

    /*********************************************************************************************************
    @description
        Test new install with custom settings explicitly deleted will still create the default settings
        no exception is thrown if the custom settings don't exist
    verify:
        Settings match the expected defaults
    **********************************************************************************************************/
    @isTest
    public static void newInstallWithDeletedCustomSettingsCreatesDefaultSettings() {
        deleteAllCustomSettings();

        Test.testInstall(new STG_InstallScript(), null);

        npe01__Contacts_And_Orgs_Settings__c npe01Settings = UTIL_CustomSettingsFacade.getOrgContactsSettings();
        npo02__Households_Settings__c npo02Settings = UTIL_CustomSettingsFacade.getOrgHouseholdsSettings();
        npe03__Recurring_Donations_Settings__c npe03Settings = UTIL_CustomSettingsFacade.getOrgRecurringDonationsSettings();
        npe4__Relationship_Settings__c npe04Settings = UTIL_CustomSettingsFacade.getOrgRelationshipSettings();
        npe5__Affiliations_Settings__c npe05Settings = UTIL_CustomSettingsFacade.getOrgAffiliationsSettings();
        Error_Settings__c errorSettings = UTIL_CustomSettingsFacade.getOrgErrorSettings();
        Addr_Verification_Settings__c addrVerificationSetgs = UTIL_CustomSettingsFacade.getOrgAddressVerificationSettings();
        Batch_Data_Entry_Settings__c batchDataEntrySetgs = UTIL_CustomSettingsFacade.getOrgBDESettings();
        Household_Naming_Settings__c householdNamingSettings = UTIL_CustomSettingsFacade.getOrgHouseholdNamingSettings();
        Allocations_Settings__c allocationsSettings = UTIL_CustomSettingsFacade.getOrgAllocationsSettings();
        Data_Import_Settings__c dataImportSettings = UTIL_CustomSettingsFacade.getOrgDataImportSettings();
        Gift_Entry_Settings__c geSettings = UTIL_CustomSettingsFacade.getOrgGiftEntrySettings();
        Package_Settings__c pkgSettings = Package_Settings__c.getOrgDefaults();

        //If it's a new install we want to set the Household model by default
        System.assertEquals(CAO_Constants.HH_ACCOUNT_PROCESSOR, npe01Settings.npe01__Account_Processor__c);
        System.assertEquals(false, npe01Settings.npe01__Enable_Opportunity_Contact_Role_Trigger__c);
        System.assertEquals(true, npe01Settings.npe01__Payments_Enabled__c);
        Recordtypeinfo householdAccount = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(CAO_Constants.HH_ACCOUNT_RT_DEVELOPER_NAME);
        Id householdAccountId = (householdAccount == null ? null : householdAccount.getRecordTypeId());
        System.assertEquals(householdAccountId, npe01Settings.npe01__HH_Account_RecordTypeID__c);

        System.assertEquals(HH_Households.NO_HOUSEHOLDS_PROCESSOR, npo02Settings.npo02__Household_Rules__c);
        System.assertEquals(CAO_Constants.HH_MEMBER_CONTACT_ROLE, npo02Settings.npo02__Household_Member_Contact_Role__c);
        System.assertEquals(false, npo02Settings.npo02__Always_Rollup_to_Primary_Contact__c);
        System.assertEquals(true, npo02Settings.npo02__Enable_Opp_Rollup_Triggers__c);
        System.assertEquals(null, npo02Settings.npo02__Excluded_Account_Opp_Rectypes__c);
        System.assertEquals(null, npo02Settings.npo02__Excluded_Account_Opp_Types__c);
        System.assertEquals(null, npo02Settings.npo02__Excluded_Contact_Opp_Rectypes__c);
        System.assertEquals(null, npo02Settings.npo02__Excluded_Contact_Opp_Types__c);
        System.assertEquals(null, npo02Settings.npo02__Membership_Record_Types__c);
        System.assertEquals(365, npo02Settings.npo02__Rollup_N_Day_Value__c);
        System.assertEquals(30, npo02Settings.npo02__Membership_Grace_Period__c);
        System.assertEquals(true, npo02Settings.npo02__Advanced_Household_Naming__c);
        System.assertEquals(false, npo02Settings.npo02__Async_Household_Naming__c);
        System.assertEquals(UserInfo.getOrganizationId(), npo02Settings.Setupownerid);
        System.assertEquals(25, npo02Settings.npo02__Schedule_Job_Limit__c);
        System.assertEquals(null, npo02Settings.npo02__Household_OCR_Excluded_Recordtypes__c);
        System.assertEquals(null, npo02Settings.npo02__Household_Creation_Excluded_Recordtypes__c);
        System.assertEquals(HH_Households.NO_HOUSEHOLDS_PROCESSOR, npo02Settings.npo02__Household_Rules__c);
        System.assertEquals(true, npo02Settings.npo02__Enable_Soft_Credit_Rollups__c);
        System.assertEquals('Matched Donor;Soft Credit;Household Member', npo02Settings.npo02__Soft_Credit_Roles__c);
        System.assertEquals(true, npo02Settings.npo02__Household_Contact_Roles_On__c);

        System.assertEquals(RD_RecurringDonations.RecurringDonationCloseOptions.Mark_Opportunities_Closed_Lost.name(), npe03Settings.npe03__Open_Opportunity_Behavior__c);
        System.assertEquals(true, npe03Settings.npe03__Add_Campaign_to_All_Opportunites__c);
        System.assertEquals(true, npe03Settings.npe03__Enable_Update_Check__c);
        System.assertEquals(50, npe03Settings.npe03__Maximum_Donations__c);
        System.assertEquals(12, npe03Settings.npe03__Opportunity_Forecast_Months__c);
        System.assertEquals(90, npe03Settings.npe03__Update_Check_Interval__c);
        System.assertEquals([select id from RecordType where sobjecttype = 'Opportunity' limit 1].id, npe03Settings.npe03__Record_Type__c);

        System.assertEquals('List Setting', npe04Settings.npe4__Reciprocal_Method__c);

        System.assertEquals(true, npe05Settings.npe5__Automatic_Affiliation_Creation_Turned_On__c);

        System.assertEquals(true, errorSettings.Store_Errors_On__c);
        System.assertEquals(true, errorSettings.Error_Notifications_On__c);
        System.assertEquals(ERR_Notifier.ERROR_NOTIFICATION_RECIPIENT_ALL_SYS_ADMINS, errorSettings.Error_Notifications_To__c);

        System.assertEquals(false, addrVerificationSetgs.Enable_Automatic_Verification__c);
        System.assertEquals(false, addrVerificationSetgs.Reject_Ambiguous_Addresses__c);

        System.assertEquals(true, batchDataEntrySetgs.Allow_Blank_Opportunity_Names__c);
        System.assertEquals(true, batchDataEntrySetgs.Opportunity_Naming__c);

        System.assertEquals('HH_NameSpec',householdNamingSettings.Implementing_Class__c);
        System.assertEquals(365,allocationsSettings.Rollup_N_Day_Value__c);

        System.assertEquals(50,dataImportSettings.Batch_Size__c);

        System.assertEquals(UserInfo.getOrganizationId(), geSettings.SetupOwnerId);

        System.assertNotEquals(pkgSettings.Id, null, 'A default PackageSettings record should have been created');

    }

    /*********************************************************************************************************
    @description
        Test onInstall applies separate independent install actions
    verify:
        Successful install actions are applied if another install action results in an error
    **********************************************************************************************************/
    @isTest
    private static void testInstallActionsAreIndependent() {
        UTIL_RecordTypeSettingsUpdate_TEST.UpdateSettingsMock mockUpdateSettings =
        new UTIL_RecordTypeSettingsUpdate_TEST.UpdateSettingsMock().throwException();
        UTIL_RecordTypeSettingsUpdate.instance = mockUpdateSettings;

        List<Trigger_Handler__c> triggerHandlers = getTriggerHandlers();
        System.assertEquals(0, triggerHandlers.size(), 'No trigger handler should exist: ' + triggerHandlers);

        Test.testInstall(new STG_InstallScript(), new Version(1,0), false);

        triggerHandlers = getTriggerHandlers();
        System.assert(triggerHandlers.size() > 0, 'Thrigger handler should be successful when Record Type Settings cleanup fails: ' + triggerHandlers);

        List<Error__c> errors = getErrors();
        System.assertEquals(1, errors.size(), 'One exception error should be created for the invalid Record Type settings: ' + errors);
        System.assertEquals('Test Exception', errors[0].Full_Message__c, 'Error message has not been applied correctly.');
    }

    /*********************************************************************************************************
    @description
        Test install on a new org populates Recurring Donation Installment Number
    verify:
        Opportunities' Recurring Donation Installment Number is populated.
    **********************************************************************************************************/
    @isTest
    private static void testNewInstallSetsRecurringDonationInstallmentNumber() {
        npe03__Recurring_Donation__c rd = createRecurringDonation();
        List<Opportunity> opps = getRecurringDonationOpportunities(rd.Id);
        System.assertEquals(false, opps.isEmpty(), 'At least one Opportunity should be created for the Recurring Donation');

        for (Opportunity opp : opps) {
            opp.Recurring_Donation_Installment_Number__c = null;
        }
        update opps;

        opps = getRecurringDonationOpportunities(rd.Id);
        for (Opportunity opp : opps) {
            System.assertEquals(null, opp.Recurring_Donation_Installment_Number__c, 'Recurring Donation Installment Number should be empty');
        }

        Test.startTest();
        Test.testInstall(new STG_InstallScript(), null);
        Test.stopTest();

        opps = getRecurringDonationOpportunities(rd.Id);
        for (Opportunity opp : opps) {
            System.assertNotEquals(null, opp.Recurring_Donation_Installment_Number__c, 'Recurring Donation Installment Number should be set by the installation script');
        }

        List<Error__c> errors = getErrors();
        System.assertEquals(0, errors.size(), 'No exception error should be created: ' + errors);
    }

    /*********************************************************************************************************
    @description
        Test hasErrors() returns true if the logger has at least one exception stored
    verify:
        hasErrors() returns true
    **********************************************************************************************************/
    @isTest
    private static void testErrorLoggerHasErrorsReturnsTrue() {
        STG_InstallScript.ErrorLogger logger = new STG_InstallScript.ErrorLogger(null, ERR_Handler_API.Context.STTG);

        logger.add(new STG_InstallException('Test Exception'));

        System.assert(logger.hasErrors(), 'Logger should return true since it contains one exception');
    }

    /*********************************************************************************************************
    @description
        Test hasErrors() returns false if the logger has no exceptions
    verify:
        hasErrors() returns false
    **********************************************************************************************************/
    @isTest
    private static void testErrorLoggerHasErrorsReturnsFalse() {
        STG_InstallScript.ErrorLogger logger = new STG_InstallScript.ErrorLogger(null, ERR_Handler_API.Context.STTG);

        System.assert(!logger.hasErrors(), 'Logger should return false since it contains no exception');
    }

    /*********************************************************************************************************
    @description
        Test email sent by the logger contains all exceptions
    verify:
        The email body contains exception message and stack trace
    **********************************************************************************************************/
    @isTest
    private static void testErrorLoggerCorrectlyBuildsEmailBody() {
        STG_InstallScript.ErrorLogger logger = new STG_InstallScript.ErrorLogger(null, ERR_Handler_API.Context.STTG);

        logger.add(new STG_InstallException('Test Exception 1'));
        logger.add(new STG_InstallException('Test Exception 2'));

        String emailBody = logger.buildEmailBody();

        String expectedEmailBodyPrefix = Label.stgInstallScriptError +
            '\n\n==========================. \n\nError messages:';

        System.assert(emailBody.startsWith(expectedEmailBodyPrefix), 'The email is not constructed as expected: ' + emailBody);
        System.assert(emailBody.contains('Test Exception 1'), 'The email should contain the first exception: ' + emailBody);
        System.assert(emailBody.contains('Test Exception 2'), 'The email should contain the second exception: ' + emailBody);
    }

    /*********************************************************************************************************
    @description
        Test exceptions on install are emailed and stored as error handler errors
    verify:
        - Exceptions are emailed.
        - Exception is stored as the error sObject record.
    **********************************************************************************************************/
    @isTest
    private static void testExceptionsAreEmailedAndLogged() {
        Integer emailInvocations = Limits.getEmailInvocations();

        UTIL_RecordTypeSettingsUpdate_TEST.UpdateSettingsMock mockUpdateSettings = new UTIL_RecordTypeSettingsUpdate_TEST.UpdateSettingsMock().throwException();
        UTIL_RecordTypeSettingsUpdate.instance = mockUpdateSettings;

        Test.startTest();
        Test.testInstall(new STG_InstallScript(), new Version(1,0), false);
        Integer actualEmailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        List<Error__c> errors = getErrors();
        System.assertEquals(1, errors.size(), 'One exception error should be created for the invalid Record Type settings: ' + errors);
        System.assertEquals('Test Exception', errors[0].Full_Message__c, 'Error message has not been applied correctly.');

        System.assert(actualEmailInvocations > emailInvocations, 'Email Invocations should increase if the email has been sent');
    }

    /*********************************************************************************************************
    @description
        Test no email is sent and no error is created for the successful install
    verify:
        - No email is sent.
        - No exception is stored as the error sObject record.
    **********************************************************************************************************/
    @isTest
    private static void testNoEmailIsSentOrErrorLoggedOnSuccessfulInstall() {
        Integer emailInvocations = Limits.getEmailInvocations();

        UTIL_RecordTypeSettingsUpdate.instance = new UTIL_RecordTypeSettingsUpdate_TEST.UpdateSettingsMock();

        Test.startTest();
        Test.testInstall(new STG_InstallScript(), new Version(1,0), false);
        Integer actualEmailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        List<Error__c> errors = getErrors();
        System.assertEquals(0, errors.size(), 'No exception error should be created: ' + errors);

        System.assertEquals(emailInvocations, actualEmailInvocations, 'Email Invocations should not increase');
    }

    /***
    * @description Verifies Oportunity naming Settings Attribution gets updated with
    * API AttributionOptions enum value post push install
    */
    @isTest
    public static void shouldUpdateOppNamingSettingsAttribution() {
        OPP_OpportunityNaming_TEST.setUpOppNamingSettings(new Map<String, Object>{
            'Attribution__c' => System.Label.oppNamingIndividual
        });

        Test.testInstall(new STG_InstallScript(), new Version(1,0), true);

        Opportunity_Naming_Settings__c settings = UTIL_ListCustomSettingsFacade.getMapOppNamingSettings().values()[0];

        System.assertEquals(STG_PanelOppNaming_CTRL.AttributionOptions.Contact_Donations.name(), settings.Attribution__c,
            'The Attribution should be updated to the AttributionOptions value');
    }

    /***
    * @description Verifies no error is raised when Oportunity naming Settings Attribution
    * is empty post push install
    */
    @isTest
    public static void shouldNotThrowExceptionWhenOppNamingSettingsAttributionIsEmpty() {
        OPP_OpportunityNaming_TEST.setUpOppNamingSettings(new Map<String, Object>{
            'Attribution__c' => null
        });

        Test.testInstall(new STG_InstallScript(), new Version(1,0), true);

        Opportunity_Naming_Settings__c settings = UTIL_ListCustomSettingsFacade.getMapOppNamingSettings().values()[0];

        System.assertEquals(null, settings.Attribution__c, 'The Attribution should stay empty');
    }

    /*******************************************************************************************************
    * @description Tests that Default Field Mappings are migrated if Advanced Mapping is enabled
    */
    @isTest
    public static void shouldCreateMigratedCustomFieldMappingOnUpdate() {
        Data_Import_Settings__c setting = new Data_Import_Settings__c();
        setting.Field_Mapping_Method__c = BDI_MigrationMappingUtility.DATA_IMPORT_FIELD_MAPPING;
        insert setting;

        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
                (BDI_MigrationMappingHelper) Test.createStub(
                        BDI_MigrationMappingHelper.class,
                        new BDI_MigrationMappingHelperMock());
        BDI_MigrationMappingUtility util= new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);

        Test.testInstall(new STG_InstallScript(util), new Version(1,0), true);     
        // we should have 2 field mappings queued for deployment   
        System.assertEquals(2, util.queuedMetadataTypesForDeploy.size(), 
            'We should have 2 mapping metadata records queued for deployment.');
    }


    /*********************************************************************************************************
     * Helpers
    **********************************************************************************************************/

    private static void assertTriggerHandlersEqual(List<Trigger_Handler__c> afterScriptConfig, List<Trigger_Handler__c> defaultConfig) {
        afterScriptConfig.sort();
        defaultConfig.sort();

        System.assertEquals(defaultConfig.size(), afterScriptConfig.size(), 'Number of created trigger handlers should match the number of handlers in TDTM_DefaultConfig.');
        for(Integer i = 0; i < defaultConfig.size(); i++) {
            System.assertEquals(afterScriptConfig[i].Class__c, defaultConfig[i].Class__c);
            System.assertEquals(afterScriptConfig[i].Load_Order__c, defaultConfig[i].Load_Order__c);
            System.assertEquals(afterScriptConfig[i].Object__c, defaultConfig[i].Object__c);
            System.assertEquals(afterScriptConfig[i].Active__c, defaultConfig[i].Active__c);
            System.assertEquals(afterScriptConfig[i].Asynchronous__c, defaultConfig[i].Asynchronous__c);
            //split and sort trigger actions so the test doesn't fail for different orders
            List<String> afterTriggerAction = afterScriptConfig[i].Trigger_Action__c.split(';');
            List<String> defaultTriggerAction = defaultConfig[i].Trigger_Action__c.split(';');
            afterTriggerAction.sort();
            defaultTriggerAction.sort();
            System.assertEquals(afterTriggerAction, defaultTriggerAction);
        }
    }

    /*********************************************************************************************************
    @description
        Verify that the Customizable Rollup Settings matches the expected Configuration
    **********************************************************************************************************/
    private static void assertRollupSettingsEqual(Customizable_Rollup_Settings__c expectedConfig) {

        Customizable_Rollup_Settings__c afterScriptConfig = UTIL_CustomSettingsFacade.getOrgCustomizableRollupSettings();

        System.assertEquals(expectedConfig.Customizable_Rollups_Enabled__c, afterScriptConfig.Customizable_Rollups_Enabled__c, 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Account_Batch_Size__c, afterScriptConfig.Rollups_Account_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Contact_Batch_Size__c, afterScriptConfig.Rollups_Contact_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Account_SkewMode_Batch_Size__c, afterScriptConfig.Rollups_Account_SkewMode_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Contact_SkewMode_Batch_Size__c, afterScriptConfig.Rollups_Contact_SkewMode_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Account_Soft_Credit_Batch_Size__c, afterScriptConfig.Rollups_Account_Soft_Credit_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Contact_Soft_Credit_Batch_Size__c, afterScriptConfig.Rollups_Contact_Soft_Credit_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_AcctContactSoftCredit_Batch_Size__c, afterScriptConfig.Rollups_AcctContactSoftCredit_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_GAU_Batch_Size__c, afterScriptConfig.Rollups_GAU_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Skew_Dispatcher_Batch_Size__c, afterScriptConfig.Rollups_Skew_Dispatcher_Batch_Size__c , 'The settings should match');
        System.assertEquals(expectedConfig.Rollups_Limit_on_Attached_Opps_for_Skew__c, afterScriptConfig.Rollups_Limit_on_Attached_Opps_for_Skew__c , 'The settings should match');
        System.assertEquals(expectedConfig.Disable_Related_Records_Filter__c, afterScriptConfig.Disable_Related_Records_Filter__c , 'The settings should match');
        System.assertEquals(expectedConfig.AccountHardCreditNonSkew_Incremental__c, afterScriptConfig.AccountHardCreditNonSkew_Incremental__c , 'The settings should match');
        System.assertEquals(expectedConfig.ContactHardCreditNonSkew_Incremental__c, afterScriptConfig.ContactHardCreditNonSkew_Incremental__c , 'The settings should match');

        System.assertEquals(ROLLUP_BATCH_SIZE, afterScriptConfig.Rollups_AcctContactSoftCredit_Batch_Size__c, 'The setting should be set to the batch size');
    }

    /*********************************************************************************************************
    @description Enables or disables all NPSP flag settings based on the flag value
    **********************************************************************************************************/
    private static void setAllNpspFlags(Boolean flagValue) {
        npe01__Contacts_And_Orgs_Settings__c npe01Settings = UTIL_CustomSettingsFacade.getOrgContactsSettings();
        npe01Settings.npe01__DISABLE_IndividualAccounts_trigger__c = flagValue;
        npe01Settings.npe01__DISABLE_OpportunityAccount_trigger__c = flagValue;
        npe01Settings.npe01__DISABLE_OpportunityContactRoles_trigger__c = flagValue;
        npe01Settings.npe01__DISABLE_OpportunityPayments_trigger__c = flagValue;

        npo02__Households_Settings__c npo02Settings = UTIL_CustomSettingsFacade.getOrgHouseholdsSettings();
        npo02Settings.npo02__DISABLE_Household_Opportunity_trigger__c = flagValue;
        npo02Settings.npo02__DISABLE_HouseholdAfter_trigger__c = flagValue;
        npo02Settings.npo02__DISABLE_HouseholdBefore_trigger__c = flagValue;
        npo02Settings.npo02__DISABLE_Households_trigger__c = flagValue;
        npo02Settings.npo02__DISABLE_OpportunityRollup_trigger__c = flagValue;

        npe03__Recurring_Donations_Settings__c npe03Settings = UTIL_CustomSettingsFacade.getOrgRecurringDonationsSettings();
        npe03Settings.npe03__DISABLE_Donations_trigger__c = flagValue;
        npe03Settings.npe03__DISABLE_RecurringDonations_trigger__c = flagValue;

        npe4__Relationship_Settings__c npe04Settings = UTIL_CustomSettingsFacade.getOrgRelationshipSettings();
        npe04Settings.npe4__DISABLE_RelationshipCM_trigger__c = flagValue;
        npe04Settings.npe4__DISABLE_RelationshipContacts_trigger__c = flagValue;
        npe04Settings.npe4__DISABLE_Relationships_trigger__c = flagValue;
    }

    private static void assertNpspFlagsDeactivated() {
        npe01__Contacts_And_Orgs_Settings__c npe01Settings = UTIL_CustomSettingsFacade.getOrgContactsSettings();
        System.assertEquals(false, npe01Settings.npe01__DISABLE_IndividualAccounts_trigger__c);
        System.assertEquals(false, npe01Settings.npe01__DISABLE_OpportunityAccount_trigger__c);
        System.assertEquals(false, npe01Settings.npe01__DISABLE_OpportunityContactRoles_trigger__c);
        System.assertEquals(false, npe01Settings.npe01__DISABLE_OpportunityPayments_trigger__c);

        npo02__Households_Settings__c npo02Settings = UTIL_CustomSettingsFacade.getOrgHouseholdsSettings();
        System.assertEquals(false, npo02Settings.npo02__DISABLE_Household_Opportunity_trigger__c);
        System.assertEquals(false, npo02Settings.npo02__DISABLE_HouseholdAfter_trigger__c);
        System.assertEquals(false, npo02Settings.npo02__DISABLE_HouseholdBefore_trigger__c);
        System.assertEquals(false, npo02Settings.npo02__DISABLE_Households_trigger__c);
        System.assertEquals(false, npo02Settings.npo02__DISABLE_OpportunityRollup_trigger__c);

        npe03__Recurring_Donations_Settings__c npe03Settings = UTIL_CustomSettingsFacade.getOrgRecurringDonationsSettings();
        System.assertEquals(false, npe03Settings.npe03__DISABLE_Donations_trigger__c);
        System.assertEquals(false, npe03Settings.npe03__DISABLE_RecurringDonations_trigger__c);

        npe4__Relationship_Settings__c npe04Settings = UTIL_CustomSettingsFacade.getOrgRelationshipSettings();
        System.assertEquals(false, npe04Settings.npe4__DISABLE_RelationshipCM_trigger__c);
        System.assertEquals(false, npe04Settings.npe4__DISABLE_RelationshipContacts_trigger__c);
        System.assertEquals(false, npe04Settings.npe4__DISABLE_Relationships_trigger__c);
    }

    public static void deleteAllCustomSettings() {
        npe01__Contacts_And_Orgs_Settings__c npe01Settings = npe01__Contacts_And_Orgs_Settings__c.getInstance();
        npo02__Households_Settings__c npo02Settings = npo02__Households_Settings__c.getInstance();
        npe03__Recurring_Donations_Settings__c npe03Settings = npe03__Recurring_Donations_Settings__c.getInstance();
        npe4__Relationship_Settings__c npe04Settings = npe4__Relationship_Settings__c.getInstance();
        npe5__Affiliations_Settings__c npe05Settings = npe5__Affiliations_Settings__c.getInstance();
        Error_Settings__c errorSettings = Error_Settings__c.getInstance();
        if(npe01Settings.Id != null) delete npe01Settings;
        if(npo02Settings.Id != null) delete npo02Settings;
        if(npe03Settings.Id != null) delete npe03Settings;
        if(npe04Settings.Id != null) delete npe04Settings;
        if(npe05Settings.Id != null) delete npe05Settings;
        if(errorSettings.Id != null) delete errorSettings;
    }


    public static void createSomeDefaultSettings() {
        List<Trigger_Handler__c> handlers = new List<Trigger_Handler__c>();

        //Relationships on npe4__Relationship__c
        handlers.add(new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
              Class__c = 'REL_Relationships_TDTM', Load_Order__c = 1, Object__c = 'npe4__Relationship__c',
              Trigger_Action__c = 'BeforeInsert;BeforeUpdate;AfterInsert;AfterUpdate;AfterDelete'));

        //Account Management on Contact
        handlers.add(new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
              Class__c = 'ACCT_IndividualAccounts_TDTM', Load_Order__c = 1, Object__c = 'Contact',
              Trigger_Action__c = 'BeforeInsert;BeforeUpdate;AfterInsert;AfterUpdate;AfterDelete'));

        // OpportunityContactRole support
        handlers.add(new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
              Class__c = 'HH_OppContactRoles_TDTM', Load_Order__c = 1, Object__c = 'Opportunity',
              Trigger_Action__c = 'AfterInsert'));

        // HH Object support
        handlers.add(new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
              Class__c = 'HH_HHObject_TDTM', Load_Order__c = 1, Object__c = 'npo02__Household__c',
              Trigger_Action__c = 'BeforeUpdate;AfterUpdate'));

        // HH Object contact trigger support
        handlers.add(new Trigger_Handler__c(Active__c = true, Asynchronous__c = false,
              Class__c = 'HH_Households_TDTM', Load_Order__c = 0, Object__c = 'Contact',
              Trigger_Action__c = 'AfterInsert;AfterUpdate;AfterDelete'));

        insert handlers;
    }

    public static void verifyAllSettingsCreated() {
        assertTriggerHandlersEqual(getTriggerHandlers(), TDTM_DefaultConfig.getDefaultRecords());
    }

    private static Trigger_Handler__c[] getTriggerHandlers() {
        return [
            SELECT
                Active__c, Asynchronous__c, Class__c,
                Load_Order__c, Object__c, Trigger_Action__c
            FROM Trigger_Handler__c
        ];
    }

    /*********************************************************************************************************
    @description
        Create a new Rollup With Partial Values Set
    **********************************************************************************************************/
    private static Customizable_Rollup_Settings__c buildRollupSettingsWithPartialValues() {
        return UTIL_CustomSettingsFacade.getRollupSettingsForTests(
            new Customizable_Rollup_Settings__c (
                Customizable_Rollups_Enabled__c = true,
                Rollups_Limit_on_Attached_Opps_for_Skew__c = 150,
                Rollups_Account_Batch_Size__c = 20,
                Rollups_GAU_Batch_Size__c = 400,
                Rollups_Account_SkewMode_Batch_Size__c = 100,
                Rollups_Contact_SkewMode_Batch_Size__c = 100,
                Rollups_Contact_Soft_Credit_Batch_Size__c = 100,
                Rollups_Account_Soft_Credit_Batch_Size__c = ROLLUP_BATCH_SIZE,
                Rollups_AcctContactSoftCredit_Batch_Size__c = null
            )
        );
    }

    private static npe03__Recurring_Donation__c createRecurringDonation() {
        Account acc = new Account(Name = 'foo');
        insert acc;

        npe03__Recurring_Donation__c rd = new TEST_RecurringDonationBuilder()
            .withAccount(acc.Id)
            .withInstallmentPeriodYearly()
            .withDateEstablished(Date.newInstance(1984,01,29))
            .withAmount(20)
            .withScheduleTypeMultiplyValue()
            .withOpenEndedStatusOpen()
            .build();

        insert rd;
        return rd;
    }

    /*******************************************************************************************************
    * @description Gets errors.
    * @return List<Error__c> The List of errors.
    ********************************************************************************************************/
    private static List<Opportunity> getRecurringDonationOpportunities(Id rdId) {
        return [
            SELECT Id, Recurring_Donation_Installment_Number__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c = :rdId
        ];
    }

    /*******************************************************************************************************
    * @description Gets errors.
    * @return List<Error__c> The List of errors.
    ********************************************************************************************************/
    public static List<Error__c> getErrors() {
        return [
            SELECT Id, Object_Type__c, Full_Message__c, Stack_Trace__c
            FROM Error__c
        ];
    }

    /*******************************************************************************************************
    * @description Creates a mock BDI_MigrationMappingHelper in support of testing createMigratedCustomFieldMappings
    */
    private class BDI_MigrationMappingHelperMock implements System.StubProvider {

        private Integer startingNumber = 1;
        private String getFakeId(Schema.SObjectType sObjectTypeSchema) {
            String result = String.valueOf(startingNumber++);
            return sObjectTypeSchema.getDescribe().getKeyPrefix()
                    + '0'.repeat(12-result.length()) + result;
        }

        private String account1ObjectMappingId =
                getFakeId(Schema.Data_Import_Object_Mapping__mdt.SObjectType);
        private String account1MigratedObjectMappingId =
                getFakeId(Schema.Data_Import_Object_Mapping__mdt.SObjectType);
        private String account2ObjectMappingId =
                getFakeId(Schema.Data_Import_Object_Mapping__mdt.SObjectType);
        private String gauObjectMappingId =
                getFakeId(Schema.Data_Import_Object_Mapping__mdt.SObjectType);

        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, Type returnType,
                List<Type> listOfParamTypes, List<String> listOfParamNames, List<Object> listOfArgs) {

            if (stubbedMethodName == 'getFieldMappingKeysByDeveloperName') {
                Data_Import_Field_Mapping_Set__mdt fieldMappingSet;
                String targetObjectMapping = UTIL_Namespace.alignSchemaNSWithEnvironment(
                        'npsp__Target_Object_Mapping__r');
                String legacyDataImportObjectName = UTIL_Namespace.alignSchemaNSWithEnvironment(
                        'npsp__Legacy_Data_Import_Object_Name__c');
                String objectAPIName = UTIL_Namespace.alignSchemaNSWithEnvironment(
                        'npsp__Object_API_Name__c');

                if (listOfArgs.contains('Migrated_Custom_Field_Mapping_Set')) {
                    fieldMappingSet = new Data_Import_Field_Mapping_Set__mdt(
                            Id=getFakeId(Schema.Data_Import_Field_Mapping_Set__mdt.SObjectType),
                            DeveloperName='Migrated_Custom_Field_Mapping_Set',
                            MasterLabel='Migrated Custom Field Mapping Set',
                            Label='Migrated Custom Field Mapping Set');
                } else {
                    fieldMappingSet = new Data_Import_Field_Mapping_Set__mdt(
                            Id=getFakeId(Schema.Data_Import_Field_Mapping_Set__mdt.SObjectType),
                            DeveloperName='Default_Field_Mapping_Set',
                            MasterLabel='Default Field Mapping Set',
                            Label='Default Field Mapping Set');
                }
                Data_Import_Object_Mapping__mdt account1ObjectMapping =
                        new Data_Import_Object_Mapping__mdt(
                                Id=account1ObjectMappingId,
                                DeveloperName='Account1',
                                MasterLabel='Account 1',
                                Label='Account 1',
                                Object_API_Name__c='Account',
                                Imported_Record_Field_Name__c='npsp__Account1Imported__c',
                                Legacy_Data_Import_Object_Name__c = 'Account1',
                                Imported_Record_Status_Field_Name__c='npsp__Account1ImportStatus__c');

                Data_Import_Field_Mapping__mdt fieldMapping1 =
                        (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                                '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                                        '"MasterLabel":"Account 1 City",' +
                                        '"Label":"Account 1 City",' +
                                        '"DeveloperName":"npsp__Account1_City",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Source_Field_API_Name__c +
                                        '":"npsp__Account1_City__c",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Target_Field_API_Name__c +
                                        '":"BillingCity",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Required__c +
                                        '":"No",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Data_Import_Field_Mapping_Set__c +
                                        '":"' + fieldMappingSet.Id + '",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Target_Object_Mapping__c +
                                        '":"' + account1ObjectMapping.Id +
                                        '","' + targetObjectMapping +
                                        '":{"Id":"' + account1ObjectMapping.Id +
                                        '","DeveloperName":"Account1","MasterLabel":"Account1",' +
                                        '"' + legacyDataImportObjectName + '":"Account1","' +
                                        objectAPIName + '":"Account"}}',
                                Data_Import_Field_Mapping__mdt.class);

                Data_Import_Field_Mapping__mdt fieldMapping2 =
                        (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                                '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                                        '"MasterLabel":"Account 1 Country",' +
                                        '"Label":"Account 1 Country",' +
                                        '"DeveloperName":"npsp__Account1_Country",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Source_Field_API_Name__c +
                                        '":"npsp__Account1_Country__c",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Target_Field_API_Name__c +
                                        '":"BillingCountry",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Required__c +
                                        '":"No",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Data_Import_Field_Mapping_Set__c +
                                        '":"' + fieldMappingSet.Id + '",' +
                                        '"' + Schema.Data_Import_Field_Mapping__mdt.Target_Object_Mapping__c +
                                        '":"' + account1ObjectMapping.Id +
                                        '","' + targetObjectMapping +
                                        '":{"Id":"' + account1ObjectMapping.Id +
                                        '","DeveloperName":"Account1","MasterLabel":"Account1",' +
                                        '"' + legacyDataImportObjectName + '":"Account1","' +
                                        objectAPIName + '":"Account"}}',
                                Data_Import_Field_Mapping__mdt.class);

                List<String> referenceFieldMappings = new List<String>();
                String referenceFieldMapping1 =
                        fieldMapping1.Target_Object_Mapping__r.Object_API_Name__c
                                + '.'
                                + fieldMapping1.Target_Object_Mapping__r.Legacy_Data_Import_Object_Name__c
                                + '.'
                                + fieldMapping1.Target_Field_API_Name__c
                                + '.'
                                + fieldMapping1.Source_Field_API_Name__c;

                String referenceFieldMapping2 =
                        fieldMapping2.Target_Object_Mapping__r.Object_API_Name__c
                                + '.'
                                + fieldMapping2.Target_Object_Mapping__r.Legacy_Data_Import_Object_Name__c
                                + '.'
                                + fieldMapping2.Target_Field_API_Name__c
                                + '.'
                                + fieldMapping2.Source_Field_API_Name__c;
                referenceFieldMappings.add(referenceFieldMapping1);
                referenceFieldMappings.add(referenceFieldMapping2);

                return referenceFieldMappings;
            }
            if (stubbedMethodName == 'getFieldMappingStringsBySetDeveloperName') {
                Data_Import_Field_Mapping_Set__mdt fieldMappingSet;

                if (listOfArgs.contains('Migrated_Custom_Field_Mapping_Set')) {
                    fieldMappingSet = new Data_Import_Field_Mapping_Set__mdt(
                            Id=getFakeId(Schema.Data_Import_Field_Mapping_Set__mdt.SObjectType),
                            DeveloperName='Migrated_Custom_Field_Mapping_Set',
                            MasterLabel='Migrated Custom Field Mapping Set',
                            Label='Migrated Custom Field Mapping Set');
                } else {
                    fieldMappingSet = new Data_Import_Field_Mapping_Set__mdt(
                            Id=getFakeId(Schema.Data_Import_Field_Mapping_Set__mdt.SObjectType),
                            DeveloperName='Default_Field_Mapping_Set',
                            MasterLabel='Default Field Mapping Set',
                            Label='Default Field Mapping Set');
                }

                Data_Import_Object_Mapping__mdt account1ObjectMapping =
                        new Data_Import_Object_Mapping__mdt(
                                Id=account1ObjectMappingId,
                                DeveloperName='Account1',
                                MasterLabel='Account 1',
                                Label='Account 1',
                                Object_API_Name__c='Account',
                                Legacy_Data_Import_Object_Name__c = 'Account1',
                                Imported_Record_Field_Name__c='npsp__Account1Imported__c',
                                Imported_Record_Status_Field_Name__c='npsp__Account1ImportStatus__c');

                Data_Import_Field_Mapping__mdt fieldMapping =
                        (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                                '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                                        '"MasterLabel":"Account 1 Name",' +
                                        '"Label":"Account 1 Name",' +
                                        '"DeveloperName":"npsp__Account1_Name",' +
                                        '"Source_Field_API_Name__c":"npsp__Account1_Name__c",' +
                                        '"Target_Field_API_Name__c":"Name",' +
                                        '"Required__c":"No",' +
                                        '"Data_Import_Field_Mapping_Set__c":"' + fieldMappingSet.Id + '",' +
                                        '"Target_Object_Mapping__c":"' + account1ObjectMapping.Id +
                                        '","Target_Object_Mapping__r":{"Id":"' + account1ObjectMapping.Id +
                                        '","DeveloperName":"Account1","MasterLabel":"Account1",' +
                                        '"Legacy_Data_Import_Object_Name__c":"Account1","Object_API_Name__c":"Account"}}',
                                Data_Import_Field_Mapping__mdt.class);

                if (listOfArgs.contains('Migrated_Custom_Field_Mapping_Set')) {
                    return new Map<String, Data_Import_Field_Mapping__mdt>{
                            'Account.Account1.Name.npsp__Account1_Name__c' => fieldMapping
                    };
                }

                if (!listOfArgs.contains('Migrated_Custom_Field_Mapping_Set')){
                    Data_Import_Field_Mapping__mdt fieldMapping1 =
                            (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                                    '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                                            '"MasterLabel":"Account 1 City",' +
                                            '"Label":"Account 1 City",' +
                                            '"DeveloperName":"npsp__Account1_City",' +
                                            '"Source_Field_API_Name__c":"npsp__Account1_City__c",' +
                                            '"Target_Field_API_Name__c":"BillingCity",' +
                                            '"Required__c":"No",' +
                                            '"Data_Import_Field_Mapping_Set__c":"' + fieldMappingSet.Id + '",' +
                                            '"Target_Object_Mapping__c":"' + account1ObjectMapping.Id +
                                            '","Target_Object_Mapping__r":{"Id":"' + account1ObjectMapping.Id +
                                            '","DeveloperName":"Account1","MasterLabel":"Account1",' +
                                            '"Legacy_Data_Import_Object_Name__c":"Account1","Object_API_Name__c":"Account"}}',
                                    Data_Import_Field_Mapping__mdt.class);
                    Data_Import_Field_Mapping__mdt fieldMapping2 =
                            (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                                    '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                                            '"MasterLabel":"Account 1 Country",' +
                                            '"Label":"Account 1 Country",' +
                                            '"DeveloperName":"npsp__Account1_Country",' +
                                            '"Source_Field_API_Name__c":"npsp__Account1_Country__c",' +
                                            '"Target_Field_API_Name__c":"BillingCountry",' +
                                            '"Required__c":"No",' +
                                            '"Data_Import_Field_Mapping_Set__c":"' + fieldMappingSet.Id + '",' +
                                            '"Target_Object_Mapping__c":"' + account1ObjectMapping.Id +
                                            '","Target_Object_Mapping__r":{"Id":"' + account1ObjectMapping.Id +
                                            '","DeveloperName":"Account1","MasterLabel":"Account1",' +
                                            '"Legacy_Data_Import_Object_Name__c":"Account1","Object_API_Name__c":"Account"}}',
                                    Data_Import_Field_Mapping__mdt.class);

                    return new Map<String, Data_Import_Field_Mapping__mdt>{
                            'Account.Account1.Name.npsp__Account1_Name__c' => fieldMapping,
                            'Account.Account1.BillingCity.npsp__Account1_City__c' => fieldMapping1,
                            'Account.Account1.BillingCountry.npsp__Account1_Country__c' => fieldMapping2
                    };
                }
            }
            if (stubbedMethodName == 'getDataImportObjectDeveloperNamesByLabel') {
                // create object mapping sets
                Data_Import_Object_Mapping_Set__mdt migratedObjectMappingSet =
                        new Data_Import_Object_Mapping_Set__mdt(
                                Label='Migrated Custom Object Mapping Set',
                                DeveloperName='Migrated_Custom_Object_Mapping_Set');
                Data_Import_Object_Mapping_Set__mdt defaultObjectMappingSet =
                        new Data_Import_Object_Mapping_Set__mdt(
                                Label='Default Object Mapping Set',
                                DeveloperName='Default_Object_Mapping_Set');
                // create object mappings
                Data_Import_Object_Mapping__mdt account1ReferenceObjectMapping =
                        new Data_Import_Object_Mapping__mdt(
                                Id=account1ObjectMappingId,
                                Data_Import_Object_Mapping_Set__c = defaultObjectMappingSet.Id,
                                DeveloperName='Account1',
                                MasterLabel='Account 1',
                                Label='Account 1',
                                Object_API_Name__c='Account',
                                Imported_Record_Field_Name__c='npsp__Account1Imported__c',
                                Legacy_Data_Import_Object_Name__c = 'Account1',
                                Imported_Record_Status_Field_Name__c='npsp__Account1ImportStatus__c');
                Data_Import_Object_Mapping__mdt account1MigratedObjectMapping =
                        new Data_Import_Object_Mapping__mdt(
                                Id=account1MigratedObjectMappingId,
                                Data_Import_Object_Mapping_Set__c = migratedObjectMappingSet.Id,
                                DeveloperName='Account1_7aad87e8d',
                                MasterLabel='Account 1',
                                Label='Account 1',
                                Object_API_Name__c='Account',
                                Imported_Record_Field_Name__c='npsp__Account1Imported__c',
                                Legacy_Data_Import_Object_Name__c = 'Account1',
                                Imported_Record_Status_Field_Name__c='npsp__Account1ImportStatus__c');

                Map<String, String> legacyDataImportObjectNameByDeveloperName = new Map<String, String>();
                legacyDataImportObjectNameByDeveloperName.put(account1MigratedObjectMapping.DeveloperName,
                        account1MigratedObjectMapping.MasterLabel);
                return legacyDataImportObjectNameByDeveloperName;
            }
            return null;
        }
    }

}