/*
    Copyright (c) 2020 Salesforce.org
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
* @date 2020
* @group Gift Entry
* @group-content ../../ApexDocContent/GiftEntry.htm
* @description Unit tests to cover methods in GE_GiftEntryController.
*/
@isTest
public with sharing class GE_GiftEntryController_TEST {

    @isTest static void createCreditCardElevateBatchShouldReturnFailureResponse() {
        GE_GiftEntryController.elevateBatchService = new ElevateBatchServiceInvalidRequest();
        String errorMessage = new ElevateBatchServiceInvalidRequest().createElevateBatchErrorMessage()
                .errors()[0].message;
        AuraHandledException auraException;

        Test.startTest();
            try {
                GE_GiftEntryController.createElevateBatch();
            } catch (AuraHandledException ex) {
                auraException = ex;
            }
        Test.stopTest();

        System.assertEquals(errorMessage,
                auraException.getMessage(), 'The error message in the elevate batch response ' +
                    'should throw an exception and the message should be the create elevate batch error ' +
                    'message specified in the invalid request data type.');
    }

    @isTest static void createCreditCardElevateBatchShouldReturnSuccessResponse() {
        GE_GiftEntryController.elevateBatchService = new ElevateBatchServiceValidRequest();
        AuraHandledException auraException;
        ElevateBatch elevateBatch;

        Test.startTest();
            try {
                elevateBatch = GE_GiftEntryController.createElevateBatch();
            } catch (AuraHandledException ex) {
                auraException = ex;
            }
        Test.stopTest();

        System.assertEquals(null, auraException, 'The aura exception object should be null since no error should have' +
                ' occurred with a valid request.');
        System.assertEquals(null, auraException, 'The aura exception object should be null since no error should have' +
                ' occurred with a valid request.');
        System.assertEquals('test-id', elevateBatch.elevateBatchId(), 'The elevate batch id should be ' +
                'populated on a successful response.');
    }

    @isTest static void addCreditCardElevateBatchShouldReturnSuccessResponse() {
        GE_GiftEntryController.elevateBatchService = new ElevateBatchServiceValidRequest();
        AuraHandledException auraException;
        ElevateAuthorizedGift authorizedGift;

        Test.startTest();
            try {
                authorizedGift = GE_GiftEntryController.addToElevateBatch(new ElevateTokenizedGift(),
                        'test-valid-id');
            } catch (AuraHandledException ex) {
                auraException = ex;
            }
        Test.stopTest();

        System.assertEquals(null, auraException, 'The aura exception object should be null since no error should have' +
                ' occurred with a valid request.');
        System.assertEquals(null, auraException, 'The aura exception object should be null since no error should have' +
                ' occurred with a valid request.');
        System.assertEquals('test-valid-id', authorizedGift.paymentId(),
                'The elevate batch id should be populated on a successful response.');
    }

    @isTest static void addCreditCardElevateBatchShouldReturnFailureResponse() {
        GE_GiftEntryController.elevateBatchService = new ElevateBatchServiceInvalidRequest();
        String errorMessage = new ElevateBatchServiceInvalidRequest().addElevateBatchErrorMessage()
                .errors()[0].message;
        AuraHandledException auraException;

        Test.startTest();
            try {
                GE_GiftEntryController.addToElevateBatch(new ElevateTokenizedGift(), 'test-valid-group-id');
            } catch (AuraHandledException ex) {
                auraException = ex;
            }
        Test.stopTest();

        System.assert(auraException != null, 'The aura handled exception should not be null since an invalid request ' +
                'has been sent.');
        System.assertEquals(errorMessage,
                auraException.getMessage(), 'The error message in the elevate batch response ' +
                        'should throw an exception and the message should be the create elevate batch error ' +
                        'message specified in the invalid request data type.');
    }

    /***
     * @description Verifies the purchase request response contains status code created
     * when one-time payment has been created in Elevate
     */
    @isTest
    private static void shouldReturnRecordCreatedResponseWhenPurchaseRequestSucceeds() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        String requestBodyParameters = GE_PaymentServices_TEST.GOOD_PURCHASE_CALL_BODY;
        String dataImportRecordId = UTIL_UnitTestData_TEST.mockId(DataImport__c.SObjectType);

        Test.startTest();
        UTIL_Http_TEST.mockRecordCreatedCalloutResponse(GE_PaymentServices_TEST.SUCCESS_RESPONSE_BODY);

        UTIL_Http.Response response = GE_GiftEntryController.processPurchaseRequest(requestBodyParameters, dataImportRecordId);
        Test.stopTest();

        System.assertEquals(UTIL_Http.STATUS_CODE_CREATED, response.statusCode, 'Response status should match: ' + response);
    }

    /***
     * @description Verifies the purchase request response throws an excpetion
     * when building a purchase request body fails with an unexpected error
     */
    @isTest
    private static void shouldThrowExceptionWhenPurchaseRequestGetsUnexpectedError() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        String invalidBodyParameters = '{"amount":2500,"email"';
        String dataImportRecordId = UTIL_UnitTestData_TEST.mockId(DataImport__c.SObjectType);

        Exception actualException;
        try {
            Test.startTest();
            GE_GiftEntryController.processPurchaseRequest(invalidBodyParameters, dataImportRecordId);
            Test.stopTest();

        } catch (Exception e) {
            actualException = e;
        }

        System.assertNotEquals(null, actualException, 'An exception should be returned due an invalid request body');
    }

    /***
     * @description Verifies the purchase request response contains timed out status code and message
     * when the purchase requests times out
     */
    @isTest
    private static void shouldLogErrorWhenPurchaseRequestTimesOut() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        final String requestTimeoutMessage = System.Label.geErrorRequestTimedout;
        String requestBodyParameters = GE_PaymentServices_TEST.GOOD_PURCHASE_CALL_BODY;
        String dataImportRecordId = UTIL_UnitTestData_TEST.mockId(DataImport__c.SObjectType);

        Test.startTest();
        UTIL_Http_TEST.mockErrorCalloutResponse(
            UTIL_Http.STATUS_CODE_REQUEST_TIMEOUT,
            UTIL_Http.STATUS_TIMED_OUT,
            GE_PaymentServices_TEST.FAILED_RESPONSE_BODY
        );

        UTIL_Http.Response response = GE_GiftEntryController.processPurchaseRequest(requestBodyParameters, dataImportRecordId);
        Test.stopTest();

        System.assertEquals(UTIL_Http.STATUS_CODE_REQUEST_TIMEOUT, response.statusCode,
            'Response status code should match: ' + response);

        System.assert(response.body.contains(GE_PaymentServices_TEST.FAILED_RESPONSE_MESSAGE),
            'Response body status should contain the timeout exception or timeout error response message: ' + response);

        System.assert(response.body.contains(requestTimeoutMessage),
            'Response message should contain a generic purchase request timed out message: ' + response);

        List<Error__c> errors = new TEST_SObjectGateway.ErrorGateway().getRecords();
        System.assertEquals(1, errors.size(), 'One error should be created on timeout response: ' + errors);

        final String recordDetailMessage = String.format(
            System.Label.stgErrorInvalidNameFormat,
            new String[] {
                Schema.SObjectType.DataImport__c.getLabel(),
                dataImportRecordId
            }
        );
        System.assertEquals(requestTimeoutMessage + ' ' + recordDetailMessage, errors[0].Full_Message__c,
            'Error log message should contain data import record detail');
    }

    /***
     * @description Confirm that the Data Import upsert method inserts and updates correctly.
     */
    @isTest
    private static void shouldUpsertDataImportRecord() {
        DataImport__c inMemoryDataImport = BDI_DataImport_TEST.newDI('First', 'Last', 100);
        DataImport__c dataImportRecord = GE_GiftEntryController.upsertDataImport(inMemoryDataImport);
        System.assert(dataImportRecord.Id != null);

        dataImportRecord.Payment_Authorization_Token__c = 'TEST_TOKEN';
        DataImport__c updatedDataImportRecord = GE_GiftEntryController.upsertDataImport(dataImportRecord);
        System.assertEquals(dataImportRecord.Id, updatedDataImportRecord.Id);
        System.assertEquals('TEST_TOKEN', updatedDataImportRecord.Payment_Authorization_Token__c);
    }

    /***
     * @description Confirm that the Data Import processes correctly and returns an Opportunity id.
     */
    @isTest
    private static void shouldProcessDataImportRecord() {
        DataImport__c inMemoryDataImport = BDI_DataImport_TEST.newDI('First', 'Last', null);
        inMemoryDataImport.Donation_Amount__c = 10;
        DataImport__c dataImportRecord = GE_GiftEntryController.upsertDataImport(inMemoryDataImport);

        System.assert(dataImportRecord.Id != null);
        System.assert(dataImportRecord.Donation_Amount__c == 10);

        Test.startTest();
        Boolean matchToExistingDonation = false;
        String opportunityId = GE_GiftEntryController.submitDataImportToBDI(dataImportRecord, matchToExistingDonation);
        Test.stopTest();

        System.assert(opportunityId != null);
    }

    /***
     * @description Saves the data import record, dry runs the record, and returns updated
     * totals with the new row.
     */
    @isTest
    private static void testShouldSaveAndDryRunDataImport() {

        // required setting
        UTIL_CustomSettingsFacade.getDataImportSettings();
        // aux vars
        String firstName = 'fooName';
        String lastName = 'fooLastName';
        String batchName = 'fooBatch';
        // test data
        Id batchId = createDataImportBatch( batchName );
        DataImport__c di = createDataImport( firstName, lastName, batchId );

        Test.startTest();
        GE_GiftEntryController.saveAndDryRunDataImport(batchId,di);
        Test.stopTest();

        List<DataImportBatch__c> result = [SELECT Id FROM DataImportBatch__c];
        System.assertEquals( result.size(), 1 );

    }

    /***
     * @description Confirm that a default RenderWrapper is correctly returned
     */
    @isTest
    private static void createAndReturnDefaultFormTemplate() {
        Gift_Entry_Settings__c giftEntryCustomSetting = new Gift_Entry_Settings__c();
        Form_Template__c defaultTemplate = buildFormTemplate();

        GE_Template.Template template = UTIL_UnitTestData_TEST.createSampleTemplate();

        String templateJSON = JSON.serialize(template);
        defaultTemplate.Template_JSON__c = templateJSON;

        insert defaultTemplate;

        giftEntryCustomSetting.Default_Gift_Entry_Template__c = defaultTemplate.Id;

        UTIL_CustomSettingsFacade.getGiftEntrySettingsForTests(giftEntryCustomSetting);

        GE_GiftEntryController.RenderWrapper frw = GE_GiftEntryController.getDefaultSGERenderWrapper();
        System.assert(frw.formTemplate != null);
        System.assert(frw.formTemplate.name == template.name);

        frw = GE_GiftEntryController.getRenderWrapperById(defaultTemplate.Id);
        System.assert(frw.formTemplate != null);
        System.assert(frw.formTemplate.name == template.name);

    }
    @IsTest
    private static void createAndReturnFieldMappings() {

        UTIL_UnitTestData_TEST.createSampleFieldMappings();

        Test.startTest();

        BDI_FieldMappingSet bdiFieldMappingSet = GE_GiftEntryController.getFieldMappings();

        Test.stopTest();

        System.assertNotEquals(null, bdiFieldMappingSet, 'Expected to receive field mappings, got null.');
        System.assertEquals('Default_Field_Mapping_Set', bdiFieldMappingSet.DeveloperName);

    }

    /***
     * @description Tests that widget data can be properly coverted to the BDI_DynamicSourceGroup format required
     * by BDI for N number of objects processing.
     */
    @isTest
    private static void widgetDataShouldBeConvertedIntoDynamicSources() {
        General_Accounting_Unit__c gau1 = new General_Accounting_Unit__c(Name = 'TestGroupA GAU 1',
                Active__c = true);

        General_Accounting_Unit__c gau2 = new General_Accounting_Unit__c(Name = 'TestGroupA GAU 2',
                Active__c = true);
        General_Accounting_Unit__c[] testGAUs = new General_Accounting_Unit__c[]{gau1,gau2};
        insert testGAUs;

        SObject sourceObjA1 = UTIL_Describe.getPrototypeObject(SObjectType.Allocation__c.getName());
        sourceObjA1.put(Allocation__c.General_Accounting_Unit__c.getDescribe().getName(),
                gau1.Id);
        sourceObjA1.put(Allocation__c.Percent__c.getDescribe().getName(),75);

        SObject sourceObjA2 = UTIL_Describe.getPrototypeObject(SObjectType.Allocation__c.getName());
        sourceObjA2.put(Allocation__c.General_Accounting_Unit__c.getDescribe().getName(),
                gau2.Id);
        sourceObjA2.put(Allocation__c.Percent__c.getDescribe().getName(),25);

        SObject[] testWidgetRecords = new SObject[]{sourceObjA1,sourceObjA2};

        Map<String,SObject[]> widgetData = new Map<String,SObject[]>();

        widgetData.put('GAU_Allocation_1',testWidgetRecords);

        String widgetDataString = JSON.serialize(widgetData);

        DataImport__c testDI = new DataImport__c();
        Test.startTest();
        testDI.Additional_Object_JSON__c = GE_GiftEntryController.convertWidgetDataToObjectJSON(widgetDataString);
        Test.stopTest();

        System.assertNotEquals(null,testDI.Additional_Object_JSON__c);

        BDI_DynamicSourceGroup testDSG =
                (BDI_DynamicSourceGroup)JSON.deserialize(testDI.Additional_Object_JSON__c, BDI_DynamicSourceGroup.class);

        System.assertNotEquals(null,testDSG);
        System.assertEquals(2,testDSG.dynamicSourceByObjMappingDevName.size());

        BDI_DynamicSource dynSource1;
        BDI_DynamicSource dynSource2;

        for (String objMappingDevName : testDSG.dynamicSourceByObjMappingDevName.keySet()) {
            BDI_DynamicSource tempDS = testDSG.dynamicSourceByObjMappingDevName.get(objMappingDevName);
            if (tempDS.sourceObj.get('GAU_Allocation_1_GAU__c') == gau1.Id) {
                dynSource1 = tempDS;
            } else if (tempDS.sourceObj.get('GAU_Allocation_1_GAU__c')  == gau2.Id) {
                dynSource2 = tempDS;
            }
        }

        System.assertNotEquals(null, dynSource1);
        System.assertNotEquals(null, dynSource2);
        System.assertEquals(75,dynSource1.sourceObj.get('GAU_Allocation_1_Percent__c'));
        System.assertEquals(25,dynSource2.sourceObj.get('GAU_Allocation_1_Percent__c'));
    }

    /***
    * @description Confirming that method returns the correct number of records
    */
    @isTest
    static void shouldReturnCorrectNumberOfRecords() {
        GE_Template.Template template0 = UTIL_UnitTestData_TEST.createSampleTemplate();
        String templateJSON0 = JSON.serialize(template0);
        GE_GiftEntryController.storeFormTemplate(null,template0.name, template0.description, template0.version, templateJSON0);

        GE_Template.Template template1 = UTIL_UnitTestData_TEST.createSampleTemplate();
        String templateJSON1 = JSON.serialize(template1);
        GE_GiftEntryController.storeFormTemplate(null,template1.name, template1.description, template1.version, templateJSON1);

        System.assertEquals(2, GE_GiftEntryController.getAllFormTemplates().size());
    }

    /***
    * @description Confirming that method deletes Form Template records with given ids.
    */
    @isTest
    static void shouldDeleteFormTemplatesWithGivenIds() {
        GE_Template.Template template0 = UTIL_UnitTestData_TEST.createSampleTemplate();
        String templateJSON0 = JSON.serialize(template0);
        GE_GiftEntryController.storeFormTemplate(null,template0.name, template0.description, template0.version, templateJSON0);

        GE_Template.Template template1 = UTIL_UnitTestData_TEST.createSampleTemplate();
        String templateJSON1 = JSON.serialize(template1);
        GE_GiftEntryController.storeFormTemplate(null,template1.name, template1.description, template1.version, templateJSON1);

        Form_Template__c[] formTemplates = [SELECT Id, Name FROM Form_Template__c];

        System.assertEquals(2, formTemplates.size());
        GE_GiftEntryController.deleteFormTemplates(new String[]{ formTemplates[0].Id, formTemplates[1].Id });

        formTemplates = [SELECT Id, Name FROM Form_Template__c];
        System.assertEquals(0, formTemplates.size());
    }

    /***
    * @description Confirming that the lifecycle of storing and retrieving the template does not corrupt
    * the data.
    */
    @isTest
    static void shouldCommitAndRetrieveTemplate() {
        GE_Template.Template template = UTIL_UnitTestData_TEST.createSampleTemplate();
        Gift_Entry_Settings__c giftEntryCustomSetting = new Gift_Entry_Settings__c();

        String templateJSON = JSON.serialize(template);
        String storedFormTemplateId = GE_GiftEntryController.storeFormTemplate(null,
                template.name,
                template.description,
                template.version,
                templateJSON);

        giftEntryCustomSetting.Default_Gift_Entry_Template__c = storedFormTemplateId;
        UTIL_CustomSettingsFacade.getGiftEntrySettingsForTests(giftEntryCustomSetting);

        GE_Template.Template templateResult = GE_GiftEntryController.retrieveDefaultSGEFormTemplate();
        String templateResultJSON = JSON.serialize(templateResult);

        System.assertEquals(templateJSON, templateResultJSON);
    }

    /***
    * @description Confirm that we're able to retrieve column headers based on a list name.
    */
    @isTest
    static void shouldRetrieveColumnHeaderBasedOnListName() {

        Test.startTest();
        Custom_Column_Header__c[] allHeaders = UTIL_UnitTestData_TEST.createSampleColumnHeaders();
        insert allHeaders;
        Test.stopTest();

        GE_GiftEntryController.ColumnHeaderData selectedHeaders =
                GE_GiftEntryController.retrieveCustomColumnHeaders('Templates');

        System.assertEquals(3, allHeaders.size());
        System.assertEquals(1, selectedHeaders.columnHeaders.size());
    }

    /***
    * @description Confirm that we're able to retrieve column headers based on a list name.
    */
    @isTest
    static void shouldPersistOnlyTheSelectedColumnHeadersForTheGivenList() {

        Test.startTest();
        Custom_Column_Header__c[] allHeaders = UTIL_UnitTestData_TEST.createSampleColumnHeaders();
        insert allHeaders;
        Test.stopTest();

        GE_GiftEntryController.ColumnHeaderData selectedHeaders =
                GE_GiftEntryController.retrieveCustomColumnHeaders('Batches');

        Custom_Column_Header__c columnHeaderToKeep = new Custom_Column_Header__c();
        columnHeaderToKeep.Name = 'sampleColumnHeader4';
        columnHeaderToKeep.List_Name__c = 'Batches';
        columnHeaderToKeep.Index__c = 0;
        columnHeaderToKeep.Field_Api_Name__c = 'Name';

        String columnHeaderStringToKeep = JSON.serialize(new Custom_Column_Header__c[]{columnHeaderToKeep});

        GE_GiftEntryController.upsertCustomColumnHeaders(columnHeaderStringToKeep, 'Batches');

        GE_GiftEntryController.ColumnHeaderData updatedColumnHeadersList =
                GE_GiftEntryController.retrieveCustomColumnHeaders('Batches');

        Custom_Column_Header__c columnHeaderToCheck = updatedColumnHeadersList.columnHeaders[0];

        System.assertEquals(1, selectedHeaders.columnHeaders.size());
        System.assertEquals(1, updatedColumnHeadersList.columnHeaders.size());
        System.assertEquals('Name', columnHeaderToCheck.Field_Api_Name__c);
    }

    /****
    * @description Confirm that we're able to build a query string and retrieve a list of records.
    */
    @isTest
    static void shouldRetrieveRecordsBasedOnAQueryString() {

        Test.startTest();
        Custom_Column_Header__c[] allHeaders = UTIL_UnitTestData_TEST.createSampleColumnHeaders();
        insert allHeaders;
        Test.stopTest();

        String[] selectFields = new String[] {'Id', 'Name'};
        String sObjectApiName = SObjectType.Custom_Column_Header__c.name;
        String[] whereClause = new String[] {};
        String orderByClause = 'LastModifiedDate desc';
        Integer limitClause = 10;

        SObject[] objects = GE_GiftEntryController.retrieveRecords(
                selectFields, sObjectApiName, whereClause, orderByClause, limitClause);

        System.assertEquals(3, objects.size());
    }

    /****
    * @description Confirm that form template name uniqueness is enforced.
    */
    @isTest
    static void shouldReturnFalseForExistingFormTemplateName() {
        GE_Template.Template template = UTIL_UnitTestData_TEST.createSampleTemplate();
        String templateJSON = JSON.serialize(template);
        GE_GiftEntryController.storeFormTemplate(null,template.name, template.description, template.version, templateJSON);

        Form_Template__c[] formTemplates = [SELECT Id, Name, Template_JSON__c FROM Form_Template__c];

        Boolean isExistingName = GE_GiftEntryController.checkNameUniqueness(
                formTemplates[0].Name,
                null);

        Boolean isUniqueName = GE_GiftEntryController.checkNameUniqueness(
                'New Form Template Sample Name',
                null);

        System.assertEquals(false,
                isExistingName,
                'Existing template names should return false from `GE_GiftEntryController.checkNameUniqueness`');
        System.assertEquals(true,
                isUniqueName,
                'New template names should return true from `GE_GiftEntryController.checkNameUniqueness`');
    }

    @isTest
    static void shouldRetrieveSGETemplateWithPermission() {
        UTIL_PermissionsMock utilPermissionsMockInstance = new UTIL_PermissionsMock(true);
        UTIL_Permissions utilPermissionsMock = (UTIL_Permissions) Test.createStub(
                UTIL_Permissions.class,
                utilPermissionsMockInstance);
        UTIL_Permissions.setInstance(utilPermissionsMock);

        GE_Template.Template template = UTIL_UnitTestData_TEST.createSampleTemplate();
        Gift_Entry_Settings__c giftEntrySettings = UTIL_CustomSettingsFacade.getGiftEntrySettings();
        String templateJSON = JSON.serialize(template);
        String storedFormTemplateId = GE_GiftEntryController.storeFormTemplate(null,
                template.name,
                template.description,
                template.version,
                templateJSON);

        giftEntrySettings.Default_Gift_Entry_Template__c = storedFormTemplateId;

        insert giftEntrySettings;

        UTIL_UnitTestData_TEST.createSampleFieldMappings();

        GE_Template.Template updatedTemplate = GE_GiftEntryController.retrieveDefaultSGEFormTemplate();

        System.assert(String.isBlank(updatedTemplate.permissionErrors),
                'There should be no permission errors when the user has all required CRUD and FLS permissions.');
        System.assertEquals(updatedTemplate.permissionErrorType, null,
                'The template should not have a permission error type if the user has all required CRUD and FLS permissions.');
    }

    /***
    * @description Confirms that a form template used by any Data Import Batch cannot be deleted.
    */
    @isTest
    static void shouldPreventDeletionOfTemplateInUse() {
        GE_Template.Template template = UTIL_UnitTestData_TEST.createSampleTemplate();
        String templateJSON = JSON.serialize(template);
        GE_GiftEntryController.storeFormTemplate(null,
                template.name,
                template.description,
                template.version,
                templateJSON);

        Form_Template__c[] formTemplates = [
                SELECT Id, Name, Template_JSON__c
                FROM Form_Template__c
        ];

        DataImportBatch__c batch = createBatch('Test Batch', false);
        batch.Form_Template__c = formTemplates[0].Id;

        insert batch;

        AuraHandledException failure;

        try {
            GE_GiftEntryController.deleteFormTemplates(new String[]{ formTemplates[0].Id });
        } catch (AuraHandledException ex) {
            failure = ex;
        }

        formTemplates = [
                SELECT Id, Name
                FROM Form_Template__c
        ];

        System.assert(String.isNotBlank(failure.getMessage()));
        System.assertEquals(1, formTemplates.size(), 'A Form Template in use should not be deleted');

    }

    /***
    * @description Confirms that a form template used as default on Gift Entry settings cannot be deleted.
    */
    @isTest
    static void shouldPreventDeletionOfTemplateReferencedByGiftEntry() {

        // aux vars
        String templateName = 'fooName';
        AuraHandledException failure;

        // test data
        GE_Template.Template template = createSampleTemplate();
        template.name = templateName;
        String templateJSON = JSON.serialize(template);
        // insert form template using service
        String templateId = GE_GiftEntryController.storeFormTemplate(null,
                template.name,
                template.description,
                template.version,
                templateJSON);

        // gift entry custom settings set up
        Gift_Entry_Settings__c giftEntryCustomSetting = new Gift_Entry_Settings__c();
        giftEntryCustomSetting.Default_Gift_Entry_Template__c = templateId;
        UTIL_CustomSettingsFacade.getGiftEntrySettingsForTests(giftEntryCustomSetting);

        // retrieve templates with id
        Form_Template__c[] formTemplates = [SELECT Id,
                Name,
                Template_JSON__c
        FROM Form_Template__c];

        System.assertEquals( formTemplates.size(), 1,
                'We should have only 1 form temp record at this time' );

        Test.startTest();
        try {
            // delete template using service
            GE_GiftEntryController.deleteFormTemplates(new String[]{ formTemplates[0].Id });
        } catch (AuraHandledException ex) {
            failure = ex;
        }
        Test.stopTest();

        formTemplates = [SELECT Id, Name FROM Form_Template__c];
        System.assert( String.isNotBlank(failure.getMessage()), 'Aura Exception found' );
        System.assertEquals( 1, formTemplates.size(), 'Template was not deleted' );

    }


    // Helpers
    /////////////////

    /***
    * @description Builds a test form template
    * @return Form_Template__c
    */
    private static Form_Template__c buildFormTemplate() {
        return new Form_Template__c(
            Name = 'Test',
            Format_Version__c = '1.0'
        );
    }

    /***
    * @description Sets up a new NPSP_Data_Import_Batch__c Record
    * @return Id of the new NPSP_Data_Import_Batch__c
    */
    private static Id createDataImportBatch( String batchName ) {
        DataImportBatch__c dataImportBatch = new DataImportBatch__c();
        dataImportBatch.Name = batchName;

        insert dataImportBatch;
        return (Id)dataImportBatch.Id;
    }

    /***
    * @description creates a new di record for tests
    * @param firstname the firstname to specify for Contact1
    * @param lastname the lastname to specify for Contact1
    * @param batchId Data Import Batch Id
    * @return DataImport__c the new Data Import record
    */
    public static DataImport__c createDataImport(String firstname, String lastname, Id batchId) {
        return new DataImport__c(
                Contact1_Firstname__c = firstname,
                Contact1_Lastname__c = lastname,
                Contact1_Personal_Email__c = firstname + '@' + lastname + '.com',
                NPSP_Data_Import_Batch__c = batchId
        );
    }

    //Utility method for creating a sample template.
    public static GE_Template.Template createSampleTemplate () {

        GE_Template.Element field = new GE_Template.Element('FormField',
                'True',
                null,
                'CustomLabel',
                new String[]{});

        GE_Template.Element widget = new GE_Template.Element('FormWidget',
                'DisplayRule',
                'ComponentName',
                new String[]{});

        GE_Template.Element[] elements = new GE_Template.Element[]{field,widget};

        GE_Template.Section section = new GE_Template.Section('SectionLabel',
                'Accordion',
                'Expanded',
                'True',
                elements);

        GE_Template.Layout layout = new GE_Template.Layout('DefaultMappingSet',
                new GE_Template.Section[]{section});

        GE_Template.Template template = new GE_Template.Template('Sample Template',
                'This is the description.',
                '1.0',
                layout);

        return template;
    }

    /***
     * @description Utility method that creates an NPSP Data Import Batch
     *
     * @param name
     * @param autoProcess
     *
     * @return DataImportBatch__c
     */
    private static DataImportBatch__c createBatch (String name, Boolean autoProcess) {
        DataImportBatch__c batch = new DataImportBatch__c();
        batch.Name = name;
        batch.Batch_Process_Size__c = 200;
        batch.Contact_Matching_Rule__c = 'Firstname,Lastname,Email';
        batch.Donation_Matching_Rule__c = UTIL_Namespace.StrTokenNSPrefix('Donation_Amount__c') +
                ';' + UTIL_Namespace.StrTokenNSPrefix('Donation_Date__c');
        batch.Donation_Matching_Behavior__c = BDI_DataImport_API.BestMatchOrCreate;
        batch.Process_Using_Scheduled_Job__c = autoProcess;
        return batch;
    }

    private class UTIL_PermissionsMock implements StubProvider {
        Boolean hasPermission;
        public UTIL_PermissionsMock(Boolean hasPermission) {
            this.hasPermission = hasPermission;
        }

        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName,
                Type returnType, List<Type> listOfParamTypes, List<String> listOfParamNames,
                List<Object> listOfArgs) {

            switch on stubbedMethodName {
                when 'canRead' {
                    return hasPermission;
                }
                when 'canCreate' {
                    return hasPermission;
                }
                when 'canUpdate' {
                    return hasPermission;
                }
            }
            return null;
        }
    }

}