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
* @description Unit Test for the Migration Mapping Utility
*/

@IsTest
private class BDI_MigrationMappingUtility_TEST {

    /*******************************************************************************************************
    * @description Test that the migration utility will only create and enqueue usable help text mappings
    */
    @isTest
    static void shouldCreateCustomMetadataRecordsFromHelpText() {
        // Create a mock version of the BDI_MigrationUtilityHelper class
        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
            (BDI_MigrationMappingHelper) Test.createStub(
                BDI_MigrationMappingHelper.class,
                new BDI_MigrationMappingHelperMock());

        BDI_MigrationMappingUtility util = new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);
        BDI_MigrationMappingHelper helper = new BDI_MigrationMappingHelper();

        util.dataImportFieldMappings = buildDataImportFieldMappingsFromHelpText();
        util.badHelpTextMappings = buildBadHelpTextMappings();

        util.migrateHelpTextToCustomMetadata();

        if (util.fieldMappingSetName == BDI_MigrationMappingUtility.MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME) {
            System.assertEquals(8, util.queuedMetadataTypesForDeploy.size(),
                'We have 8 metadata records queued for deployment.');
        } else {
            System.assertEquals(9, util.queuedMetadataTypesForDeploy.size(),
                'We have 9 metadata records queued for deployment including the custom field mapping set.');
        }

        System.assertEquals(2, util.badHelpTextMappings.size(),
            'We have 2 bad help text field mappings.');
    }

    /*******************************************************************************************************
    * @description Test that the migration utility handles 'npsp' namespaced custom and standard fields
    */
    @isTest
    static void shouldCreateCustomMetadataRecordsFromHelpTextWithNamespaces() {
        // Create a mock version of the BDI_MigrationUtilityHelper class
        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
            (BDI_MigrationMappingHelper) Test.createStub(
                BDI_MigrationMappingHelper.class,
                new BDI_MigrationMappingHelperMock());

        BDI_MigrationMappingUtility util = new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);

        BDI_MigrationMappingUtility.DataImportFieldMapping namespacedCustomHelpTextMapping =
            buildDataImportFieldMapping(
                'Account 1 Namespaced Custom Field',
                'npsp__Account1_Namespaced_Custom_Field__c',
                'Account1',
                'npsp__Custom_Field__c',
                'Account');

        BDI_MigrationMappingUtility.DataImportFieldMapping namespacedStandardHelpTextMapping =
            buildDataImportFieldMapping(
                'Account 1 Namespaced City',
                'npsp__Account1_Namespaced_City__c',
                'Account1',
                'npsp__BillingCity',
                'Account');

        util.dataImportFieldMappings.add(namespacedCustomHelpTextMapping);
        util.dataImportFieldMappings.add(namespacedStandardHelpTextMapping);

        util.migrateHelpTextToCustomMetadata();

        for (Metadata.CustomMetadataValue cmv : util.queuedMetadataTypesForDeploy[0].values) {
            if (cmv.field == 'Target_Field_API_Name__c') {
                System.assertEquals('Custom_Field__c', cmv.value);
            }
        }

        for (Metadata.CustomMetadataValue cmv : util.queuedMetadataTypesForDeploy[1].values) {
            if (cmv.field == 'Target_Field_API_Name__c') {
                System.assertEquals('BillingCity', cmv.value);
            }
        }
    }

    /*******************************************************************************************************
    * @description Test that the migration utility will overwrite a preexisting data import field mapping
    * and not create a new custom metadata record
    */
    @isTest
    static void shouldOverwriteExistingCustomMetadataRecordsFromHelpText() {
        // Create a mock version of the BDI_MigrationUtilityHelper class
        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
            (BDI_MigrationMappingHelper) Test.createStub(
                BDI_MigrationMappingHelper.class,
                new BDI_MigrationMappingHelperMock());

        BDI_MigrationMappingUtility util = new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);

        util.dataImportFieldMappings = buildDataImportFieldMappingsFromHelpText();
        util.badHelpTextMappings = buildBadHelpTextMappings();
        util.fieldMappingSetName = BDI_MigrationMappingUtility.MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME;

        util.migrateHelpTextToCustomMetadata();

        System.assertEquals(8, util.queuedMetadataTypesForDeploy.size(),
            'We have 8 metadata records queued for deployment.');

        System.assertEquals(2, util.badHelpTextMappings.size(),
            'We have 2 bad help text field mappings.');
    }

    /*******************************************************************************************************
    * @description Test that the migration utility will not create a duplicate record when the target
    * mapping exists and the help text mapping equivalent has the 'npsp' prefix
    */
    @isTest
    static void shouldNotCreateDuplicateCustomMetadataRecordsFromHelpTextWithNamespaces() {
        // Create a mock version of the BDI_MigrationUtilityHelper class
        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
            (BDI_MigrationMappingHelper) Test.createStub(
                BDI_MigrationMappingHelper.class,
                new BDI_MigrationMappingHelperMock());

        BDI_MigrationMappingUtility util = new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);
        BDI_MigrationMappingHelper helper = new BDI_MigrationMappingHelper();

        BDI_MigrationMappingUtility.DataImportFieldMapping namespacedStandardHelpTextMapping =
            buildDataImportFieldMapping(
                'Account 1 City',
                'npsp__Account1_City__c',
                'Account1',
                'npsp__BillingCity',
                'Account');

        util.dataImportFieldMappings.add(namespacedStandardHelpTextMapping);

        util.migrateHelpTextToCustomMetadata();

        if (util.fieldMappingSetName == BDI_MigrationMappingUtility.MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME) {
            System.assertEquals(6, util.queuedMetadataTypesForDeploy.size(),
                'We have 6 metadata records queued for deployment.');
        } else {
            System.assertEquals(7, util.queuedMetadataTypesForDeploy.size(),
                'We have 7 metadata records queued for deployment including the custom field mapping set.');
        }
    }

    /*******************************************************************************************************
    * @description Test that the migration utility populates the dataImportFieldMappings and
    * badHelpTextMappings respectively with the appropriate records
    */
    @IsTest
    static void shouldPopulateListsFromHelpText() {
        // Create a mock version of the BDI_MigrationUtilityHelper class
        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
            (BDI_MigrationMappingHelper) Test.createStub(
                BDI_MigrationMappingHelper.class,
                new BDI_MigrationMappingHelperMock());

        // Start migration
        BDI_MigrationMappingUtility util = new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);
        util.populateListsFromHelpTextMappings();

        System.assertEquals(5, util.badHelpTextMappings.size(),
            'We have 5 bad help text mappings.');
        System.assertEquals(2, util.dataImportFieldMappings.size(),
            'We have 2 good help text mappings.');
    }

    /*******************************************************************************************************
    * @description Test that the migration utility updates the Data Import Custom Settings when Advanced
    * Mapping is turned on
    */
    @IsTest
    static void shouldUpdateCustomSettingsForDataImportFieldMapping() {
        Test.startTest();

        // Confirm custom settings updated accordingly
        BDI_MigrationMappingUtility.DeploymentCallback callback = new BDI_MigrationMappingUtility.DeploymentCallback();

        // Construct a dummy Context
        TestingDeployCallbackContext context = new TestingDeployCallbackContext();

        Metadata.DeployResult deployResult = new Metadata.DeployResult();
        deployResult.status = Metadata.DeployStatus.SUCCEEDED;

        // Call the handleResult() method of our main Callback with our dummy context var
        callback.handleResult(deployResult, context);

        Test.stopTest();

        // Confirm that we've updated the CMT API Status field in Data Import Settings
        Data_Import_Settings__c dataImportSettings = UTIL_CustomSettingsFacade.getDataImportSettings();
        Map<String,String> result =
            (Map<String,String>)JSON.deserialize(dataImportSettings.CMT_API_Status__c, Map<String,String>.class);

        System.assertNotEquals(null, result.get('Status'), result);
        System.assertEquals(result.get('Field Mapping Method'), 'Data Import Field Mapping');
    }

    /*******************************************************************************************************
    * @description Test that the migration utility updates the Data Import Custom Settings when Advanced
    * Mapping is turned off
    */
    @IsTest
    static void shouldUpdateCustomSettingsForHelpText() {
        BDI_MigrationMappingUtility.updateCustomSettings(
            BDI_MigrationMappingUtility.HELP_TEXT,
            String.valueOf(Metadata.DeployStatus.Succeeded));

        // Confirm that we've updated the CMT API Status field in Data Import Settings
        Data_Import_Settings__c dataImportSettings = UTIL_CustomSettingsFacade.getDataImportSettings();
        Map<String,String> result =
            (Map<String,String>)JSON.deserialize(dataImportSettings.CMT_API_Status__c, Map<String,String>.class);

        System.assertEquals(result, new Map<String, String>());
    }

    /*******************************************************************************************************
    * @description Test that the migration utility creates Migrated Custom Settings
    */
    @isTest
    static void shouldCreateCustomMetadataRecordsFromNewDefault() {
        BDI_MigrationMappingHelper mock_BDI_MigrationMappingHelper =
                (BDI_MigrationMappingHelper) Test.createStub(
                        BDI_MigrationMappingHelper.class,
                        new BDI_MigrationMappingHelperMock());
        BDI_MigrationMappingUtility util = new BDI_MigrationMappingUtility(mock_BDI_MigrationMappingHelper);

        List<String> newDefaultMappingStrings = new List<String>{'Account_1_City__c', 'Account_1_Country__c'};
        util.migrateNewDefaultToCustomMetadata(newDefaultMappingStrings);
        // we should have 2 field mappings queued for deployment
        System.assertEquals(2, util.queuedMetadataTypesForDeploy.size(), 
            'We should have 2 mapping metadata records queued for deployment.');
    }

    /*******************************************************************************************************
    * @description Method builds an instance of the BDI_MigrationMappingUtility.DataImportFieldMapping
    *
    * @param label: Label of the Data Import field
    * @param sourceFieldAPIName: API name of the Data Import Field
    * @param dataImportObjectName: Object name of the target object in the Data Import help text
    * (i.e. Account1)
    * @param targetFieldAPIName: API name of the target field in the Data Import help text
    * @param targetObjectAPIName: API Name of the target object in the Data Import help text
    * (i.e. Account)
    */
    private static BDI_MigrationMappingUtility.DataImportFieldMapping buildDataImportFieldMapping(
        String label, String sourceFieldAPIName, String dataImportObjectName,
        String targetFieldAPIName, String targetObjectAPIName) {

        BDI_MigrationMappingUtility.DataImportFieldMapping difm =
            new BDI_MigrationMappingUtility.DataImportFieldMapping();
        difm.label = label;
        difm.sourceFieldAPIName = sourceFieldAPIName;
        difm.dataImportObjectName = dataImportObjectName;
        difm.targetFieldAPIName = targetFieldAPIName;
        difm.targetObjectAPIName = targetObjectAPIName;

        return difm;
    }

    /*******************************************************************************************************
    * @description Method builds an instance of the BDI_MigrationMappingUtility.HelpTextFieldMapping
    *
    * @param sourceFieldLabel: Label of the Data Import field
    * @param sourceFieldAPIName: API name of the Data Import Field
    * @param dataImportObjectName: Object name of the target object in the Data Import help text
    * (i.e. Account1)
    * @param targetFieldAPIName: API name of the target field in the Data Import help text
    * @param helpText: Value of Data Import help text field (i.e. Account1.BillingCity)
    */
    private static BDI_MigrationMappingUtility.HelpTextFieldMapping buildHelpTextFieldMapping(
        String sourceFieldLabel, String sourceFieldAPIName, String dataImportObjectName,
        String targetFieldAPIName, String helpText) {

        BDI_MigrationMappingUtility.HelpTextFieldMapping htfm =
            new BDI_MigrationMappingUtility.HelpTextFieldMapping();
        htfm.dataImportObjectName = dataImportObjectName;
        htfm.targetFieldAPIName = targetFieldAPIName;
        htfm.dataImportFieldName = sourceFieldLabel;
        htfm.dataImportFieldAPIName = sourceFieldAPIName;
        htfm.helpText = helpText;

        return htfm;
    }

    /*******************************************************************************************************
    * @description Builds a list of test DataImportFieldMappings
    */
    private static List<BDI_MigrationMappingUtility.DataImportFieldMapping> buildDataImportFieldMappingsFromHelpText() {
        BDI_MigrationMappingUtility.DataImportFieldMapping account1NameHelpText =
            buildDataImportFieldMapping(
                'Account 1 Name',
                'npsp__Account1_Name__c',
                'Account1',
                'Custom_Name__c',
                'Account');

        BDI_MigrationMappingUtility.DataImportFieldMapping account1CityHelpText =
            buildDataImportFieldMapping(
                'Account 1 City',
                'npsp__Account1_City__c',
                'Account1',
                'BillingCity',
                'Account');

        BDI_MigrationMappingUtility.DataImportFieldMapping account1CustomFieldHelpText =
            buildDataImportFieldMapping(
                'Account 1 Custom Field',
                'npsp__Account1_Custom_Field__c',
                'Account1',
                'Custom_Field__c',
                'Account');

        BDI_MigrationMappingUtility.DataImportFieldMapping account1CustomFieldHelpText2 =
            buildDataImportFieldMapping(
                'Account 1 Long Custom Field',
                'npsp__Account1_Long_Custom_Field__c',
                'Account1',
                'Custom_Field_Long_Name_xxxxxxxxxxxxxxxxxxxx__c',
                'Account');

        BDI_MigrationMappingUtility.DataImportFieldMapping account2CityHelpText =
            buildDataImportFieldMapping(
                'Account 2 Name',
                'npsp__Account2_City__c',
                'Account2',
                'BillingCity',
                'Account');

        return new List<BDI_MigrationMappingUtility.DataImportFieldMapping>{
            account1NameHelpText,
            account1CityHelpText,
            account2CityHelpText,
            account1CustomFieldHelpText,
            account1CustomFieldHelpText2};
    }

    /*******************************************************************************************************
    * @description Builds a list of test good HelpTextFieldMapping
    */
    private static List<BDI_MigrationMappingUtility.HelpTextFieldMapping> buildHelpTextMappings() {
        BDI_MigrationMappingUtility.HelpTextFieldMapping account1NameHelpText =
            buildHelpTextFieldMapping(
                'Account 1 Name',
                'npsp__Account1_Name__c',
                'Account1',
                'Custom_Name__c',
                'Account1.Custom_Name__c');

        BDI_MigrationMappingUtility.HelpTextFieldMapping account1CityHelpText =
            buildHelpTextFieldMapping(
                'Account 1 City',
                'npsp__Account1_City__c',
                'Account1',
                'BillingCity',
                'Account1.BillingCity');

        BDI_MigrationMappingUtility.HelpTextFieldMapping account1CustomFieldHelpText =
            buildHelpTextFieldMapping(
                'Account 1 Custom Field',
                'npsp__Account1_Custom_Field__c',
                'Account1',
                'Custom_Field__c',
                'Account1.Custom_Field__c');

        BDI_MigrationMappingUtility.HelpTextFieldMapping account1CustomFieldHelpText2 =
            buildHelpTextFieldMapping(
                'Account 1 Long Custom Field',
                'npsp__Account1_Long_Custom_Field__c',
                'Account1',
                'Custom_Field_Long_Name_xxxxxxxxxxxxxxxxxxxx__c',
                'Account1.Custom_Field_Long_Name_xxxxxxxxxxxxxxxxxxxx__c');

        BDI_MigrationMappingUtility.HelpTextFieldMapping account2CityHelpText =
            buildHelpTextFieldMapping(
                'Account 2 Name',
                'npsp__Account2_City__c',
                'Account2',
                'BillingCity',
                'Account2.BillingCity');

        return new List<BDI_MigrationMappingUtility.HelpTextFieldMapping>{
            account1NameHelpText,
            account1CityHelpText,
            account2CityHelpText,
            account1CustomFieldHelpText,
            account1CustomFieldHelpText2};
    }

    /*******************************************************************************************************
    * @description Builds a list of test bad HelpTextFieldMapping
    */
    private static List<BDI_MigrationMappingUtility.HelpTextFieldMapping> buildBadHelpTextMappings() {
        BDI_MigrationMappingUtility.HelpTextFieldMapping badAccount1Mapping =
            buildHelpTextFieldMapping(
                'Account 1 Country',
                'npsp__Account1_Country__c',
                'AcCount1',
                'BillingCountry',
                'AcCount1.BillingCountry');

        BDI_MigrationMappingUtility.HelpTextFieldMapping badAccount3Mapping =
            buildHelpTextFieldMapping(
                'Account 3 Name',
                'npsp__Account3_Name__c',
                'Account3',
                'Name',
                'Account3.Name');

        return new List<BDI_MigrationMappingUtility.HelpTextFieldMapping>{
            badAccount1Mapping,
            badAccount3Mapping};
    }

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

            if (stubbedMethodName == 'getObjectMappingSet') {
                Data_Import_Object_Mapping_Set__mdt objectMappingSet =
                    new Data_Import_Object_Mapping_Set__mdt(
                        Label='Migrated Custom Object Mapping Set',
                        DeveloperName='Migrated_Custom_Object_Mapping_Set');

                return new List<Data_Import_Object_Mapping_Set__mdt>{objectMappingSet};
            }

            if (stubbedMethodName == 'getObjectMappingsBySetDeveloperName') {
                Data_Import_Object_Mapping__mdt objectMapping1 =
                    new Data_Import_Object_Mapping__mdt(
                        Id=account1ObjectMappingId,
                        Label='Account 1',
                        DeveloperName='Account1',
                        Object_API_Name__c='Account',
                        Imported_Record_Field_Name__c='npsp__Account1Imported__c',
                        Imported_Record_Status_Field_Name__c='npsp__Account1ImportStatus__c');

                Data_Import_Object_Mapping__mdt objectMapping2 =
                    new Data_Import_Object_Mapping__mdt(
                        Id=account2ObjectMappingId,
                        Label='Account 2',
                        DeveloperName='Account2',
                        Object_API_Name__c='Account',
                        Imported_Record_Field_Name__c='npsp__Account2Imported__c',
                        Imported_Record_Status_Field_Name__c='npsp__Account2ImportStatus__c');

                return new Map<String, Data_Import_Object_Mapping__mdt>{
                    'Account1' => objectMapping1,
                    'Account2' => objectMapping2};
            }

            if (stubbedMethodName == 'getAllHelpTextFieldMappings') {
                List<BDI_MigrationMappingUtility.HelpTextFieldMapping> helpTextFieldMappings =
                    new List<BDI_MigrationMappingUtility.HelpTextFieldMapping>();
                helpTextFieldMappings.addAll(buildHelpTextMappings());
                helpTextFieldMappings.addAll(buildBadHelpTextMappings());

                return helpTextFieldMappings;
            }

            if (stubbedMethodName == 'getFieldMappingsByFieldMappingSetDeveloperName') {
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
                        Imported_Record_Field_Name__c='npsp__Account1Imported__c',
                        Imported_Record_Status_Field_Name__c='npsp__Account1ImportStatus__c');

                Data_Import_Object_Mapping__mdt account2ObjectMapping =
                    new Data_Import_Object_Mapping__mdt(
                        Id=account2ObjectMappingId,
                        DeveloperName='Account2',
                        MasterLabel='Account 2',
                        Label='Account 2',
                        Object_API_Name__c='Account',
                        Imported_Record_Field_Name__c='npsp__Account2Imported__c',
                        Imported_Record_Status_Field_Name__c='npsp__Account2ImportStatus__c');

                Data_Import_Object_Mapping__mdt gauObjectMapping =
                    new Data_Import_Object_Mapping__mdt(
                        Id=gauObjectMappingId,
                        DeveloperName='GAU_Allocation_1',
                        MasterLabel='GAU Allocation 1',
                        Label='GAU Allocation 1',
                        Object_API_Name__c='npsp__Allocation__c',
                        Imported_Record_Field_Name__c='npsp__GAU_Allocation_1_Imported__c',
                        Imported_Record_Status_Field_Name__c='npsp__GAU_Allocation_1_Import_Status__c');

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
                            '","DeveloperName":"Account1","MasterLabel":"Account1"}}',
                        Data_Import_Field_Mapping__mdt.class);

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
                            '","DeveloperName":"Account1","MasterLabel":"Account1"}}',
                        Data_Import_Field_Mapping__mdt.class);

                Data_Import_Field_Mapping__mdt fieldMapping2 =
                    (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                        '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                        '"MasterLabel":"Account 2 City",' +
                        '"Label":"Account 2 City",' +
                        '"DeveloperName":"npsp__Account2_City",' +
                        '"Source_Field_API_Name__c":"npsp__Account2_City__c",' +
                        '"Target_Field_API_Name__c":"BillingCity",' +
                        '"Required__c":"No",' +
                        '"Data_Import_Field_Mapping_Set__c":"' + fieldMappingSet.Id + '",' +
                        '"Target_Object_Mapping__c":"' + account2ObjectMapping.Id +
                            '","Target_Object_Mapping__r":{"Id":"' + account2ObjectMapping.Id +
                            '","DeveloperName":"Account2","MasterLabel":"Account2"}}',
                        Data_Import_Field_Mapping__mdt.class);

                Data_Import_Field_Mapping__mdt fieldMapping3 =
                    (Data_Import_Field_Mapping__mdt)JSON.deserialize(
                        '{"Id":"' + getFakeId(Schema.Data_Import_Field_Mapping__mdt.SObjectType) + '",' +
                        '"MasterLabel":"GAU Allocation 1: Amount",' +
                        '"Label":"GAU Allocation 1: Amount",' +
                        '"DeveloperName":"GAU_Allocation_1_Amount",' +
                        '"Source_Field_API_Name__c":"npsp__GAU_Allocation_1_Amount__c",' +
                        '"Target_Field_API_Name__c":"npsp__Amount__c",' +
                        '"Required__c":"No",' +
                        '"Data_Import_Field_Mapping_Set__c":"' + fieldMappingSet.Id + '",' +
                        '"Target_Object_Mapping__c":"' + gauObjectMapping.Id +
                            '","Target_Object_Mapping__r":{"Id":"' + gauObjectMapping.Id +
                            '","DeveloperName":"GAU_Allocation_1","MasterLabel":"GAU Allocation 1"}}',
                        Data_Import_Field_Mapping__mdt.class);

                return new Map<String, Data_Import_Field_Mapping__mdt>{
                    'Account.Account1.npsp__Account1_Name__c' => fieldMapping,
                    'Account.Account1.npsp__Account1_City__c' => fieldMapping1,
                    'Account.Account2.npsp__Account2_City__c' => fieldMapping2,
                    'npsp__Allocation__c.GAU_Allocation_1.npsp__GAU_Allocation_1_Amount__c' => fieldMapping3};
            }

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

    // DeployCallbackContext subclass for testing that returns jobId
    public class TestingDeployCallbackContext extends Metadata.DeployCallbackContext {
        public override Id getCallbackJobId() {
            return '000000000122345';
        }
    }
}
