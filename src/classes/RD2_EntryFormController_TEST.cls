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
* @group Recurring Donations
* @description Enhanced Recurring Donations Entry Form LWC Controller Tests
*
*/
@isTest
private with sharing class RD2_EntryFormController_TEST {

    private static final Date START_DATE = Date.newInstance(2019, 3, 1);
    private static final String COMMITMENT_ID = RD2_ElevateIntegrationService_TEST.COMMITMENT_ID;
    private static final String PAYMENT_METHOD_TOKEN = 'token-abcd-efgh-ijkl-mnop-qrst';
    private static final String CARD_LAST_4 = '1234';
    private static final String CARD_EXPIRATION_MONTH = '11';
    private static final String CARD_EXPIRATION_YEAR = '2019';

    private static final TEST_SObjectGateway.RecurringDonationGateway rdGateway = new TEST_SObjectGateway.RecurringDonationGateway();
    private static final TEST_SObjectGateway.ErrorGateway errorGateway = new TEST_SObjectGateway.ErrorGateway();

    /****
    * @description Creates data required for unit tests
    */
    @TestSetup
    private static void setUp() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Contact c = UTIL_UnitTestData_TEST.getContact();
        insert c;

        npe03__Recurring_Donation__c rd = TEST_RecurringDonationBuilder.constructEnhancedBuilder()
            .withContact(c.Id)
            .withAmount(25)
            .withDefaultValues()
            .withInstallmentPeriodWeekly()
            .withDayOfMonth('1')
            .withInstallmentFrequency(2)
            .build();
        insert rd;
    }

    /***
    * @description Verifies that Entry Form Controller gathers the correct org setting
    */
    @isTest
    private static void shouldReturnSettings() {
        Id accountId =  UTIL_UnitTestData_TEST.mockId(Account.SObjectType);

        Test.startTest();
        Map<String, Object> orgSettingsByKey = RD2_EntryFormController.getRecurringSettings(accountId, null);
        Test.stopTest();

        System.assertEquals(RD2_NamingService.isAutomaticNamingEnabled, ((Boolean) orgSettingsByKey.get('isAutoNamingEnabled')),
            'Recurring Donation Auto Naming setting should be returned accordingly');
        System.assertEquals(UserInfo.isMultiCurrencyOrganization(), (Boolean) orgSettingsByKey.get('isMultiCurrencyEnabled'),
            'Multi Currency Org should be detected in the configuration.');
        System.assertEquals(String.valueOf(Account.SObjectType), (String) orgSettingsByKey.get('parentSObjectType'),
            'Parent Sobject type should be correctly identified when value is not null');

        System.assertEquals(true, ((Map<String,Boolean>)orgSettingsByKey.get('InstallmentPeriodPermissions')).get('Createable'),
            'Installment_Period__c.IsCreatable should return true');
        System.assert(orgSettingsByKey.get('customFieldSets') instanceof List<RD2_EntryFormController.CustomField>,
            'A list of Custom Fields should be returned');
    }

    /***
    * @description Verifies whether the org is the Elevate customer
    * in order to display the Elevate credit card widget if so.
    */
    @isTest
    private static void shouldDisplayElevateWidgetWhenElevateEnabledIsTrue() {
        Id accountId =  UTIL_UnitTestData_TEST.mockId(Account.SObjectType);

        RD2_ElevateIntegrationService_TEST.enableElevateUserPermissions();

        Test.startTest();
        Map<String, Object> orgSettingsByKey = RD2_EntryFormController.getRecurringSettings(accountId, null);
        Test.stopTest();

        System.assertEquals(true, ((Boolean) orgSettingsByKey.get('isElevateCustomer')),
            'The org should be Elevate customer');
    }

    /***
    * @description Verifies whether the org is the Elevate customer
    * in order to display the Elevate credit card widget if so.
    */
    @isTest
    private static void shouldNotDisplayElevateWidgetWhenElevateEnabledAndPilotEnabledIsFalse() {
        Id accountId =  UTIL_UnitTestData_TEST.mockId(Account.SObjectType);

        RD2_ElevateIntegrationService_TEST.enableElevateUserPermissions();
        UTIL_FeatureEnablement_TEST.setPilotEnabledParameter(false);

        Test.startTest();
        Map<String, Object> orgSettingsByKey = RD2_EntryFormController.getRecurringSettings(accountId, null);
        Test.stopTest();

        System.assertEquals(false, ((Boolean) orgSettingsByKey.get('isElevateCustomer')),
            'The org should not be Elevate customer');
    }

    /***
    * @description Verifies that Entry Form Controller returns the expected results for Account for Donor Type
    */
    @isTest
    private static void shouldReturnAccountDonorType() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Account a = UTIL_UnitTestData_TEST.buildOrganizationAccount();
        insert a;

        npe03__Recurring_Donation__c rd = TEST_RecurringDonationBuilder.constructEnhancedBuilder()
            .withAccount(a.Id)
            .withAmount(25)
            .withDefaultValues()
            .withInstallmentPeriodMonthly()
            .withDayOfMonth('1')
            .build();
        insert rd;

        Test.startTest();
        Map<String, Object> response = RD2_EntryFormController.getRecurringData(rd.Id);
        String donorType = (String)response.get('DonorType');
        String period = (String)response.get('Period');
        Test.stopTest();

        System.assertEquals('Account', donorType);
        System.assertEquals('Monthly', period);
    }

    /***
    * @description Verifies that Entry Form Controller returns the expected results for Contact for Donor Type
    */
    @isTest
    private static void shouldReturnContactDonorType() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;
        
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        npe03__Recurring_Donation__c rd = rdGateway.getRecords()[0];

        Test.startTest();
        Map<String, Object> response = RD2_EntryFormController.getRecurringData(rd.Id);
        String donorType = (String)response.get('DonorType');
        String period = (String)response.get('Period');
        Integer frequency = Integer.valueOf(response.get('Frequency'));
        Test.stopTest();

        System.assertEquals('Contact', donorType);
        System.assertEquals('Weekly', period);
        System.assertEquals(2, frequency);
    }

    /**
     * @description Validate that the System Admin User reports that they have the required field permissions
     */
    @IsTest
    private static void shouldReturnTrueWhenUserHasPermissions() {
        Boolean hasPerms = RD2_EntryFormController.hasRequiredFieldPermissions();
        System.assertEquals(true, hasPerms, 'The Admin User should have permissions');
    }

    /**
     * @description Validate that a Standard User w/o Read permission on a single RD  field reports that they
     * are missing the required field permissions
     */
    @IsTest
    private static void shouldReturnFalseWhenUserIsMissingPermissions() {
        User stdUser = UTIL_UnitTestData_TEST.createStandardProfileUser();

        Id stdProfileId = [SELECT Id FROM Profile WHERE Name = :UTIL_Profile.PROFILE_STANDARD_USER LIMIT 1].Id;

        FieldPermissions fldPerm = [
            SELECT Id, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE Parent.ProfileId = :stdProfileId
            AND Field = 'npe03__Recurring_Donation__c.npe03__Installment_Period__c'
        ];
        fldPerm.PermissionsRead = false;
        fldPerm.PermissionsEdit = false;
        update fldPerm;

        Test.startTest();
        System.runAs(stdUser) {
            Boolean hasPerms = RD2_EntryFormController.hasRequiredFieldPermissions();
            System.assertEquals(false, hasPerms, 'The Standard User should be missing permissions');
        }
        Test.stopTest();
    }

    /***
    * @description Verifies that Entry Form Controller excluded all NPSP packaged field and predefined excluded fields
    */
    @isTest
    private static void shouldReturnRD2CustomFieldsWithoutNPSPNameSpaceAndExcludedFields() {
        Test.startTest();
        List<RD2_EntryFormController.CustomField> customFields = RD2_entryFormController.getCustomFieldSectionFields();
        Test.stopTest();

        for (RD2_EntryFormController.CustomField field : customFields) {
            System.assert(!RD2_EntryFormController.excludedCustomFields.contains(field.apiName),
                'Excluded fields should not be return:' + field.apiName);
            System.assert(!field.apiName.startsWith('npsp__'),
                'NPSP package field should not be return:' + field.apiName);
            System.assert(!field.apiName.startsWith('npe03__'),
                'NPSP package field should not be return:' + field.apiName);
        }
    }

    /***
    * @description Verifies Commitment record created response is returned upon successful creation
    */
    @isTest
    private static void shouldReturnCreatedResponseWhenCreateCommitmentSucceeds() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        npe03__Recurring_Donation__c rd = buildRecurringDonation();

        Test.startTest();
        mockRecordCreatedCalloutResponse();

        RD2_EntryFormController.CommitmentService service = new RD2_EntryFormController.CommitmentService();

        UTIL_Http.Response response = service.handleCommitment(rd, PAYMENT_METHOD_TOKEN);
        Test.stopTest();

        System.assertNotEquals(null, response, 'The Commitment response should be returned');
        System.assertEquals(UTIL_Http.STATUS_CODE_CREATED, response.statusCode,
            'The response status code should match: ' + response);
    }

    /**
    * @description Verifies an error record will be created when an error response is received from the Elevate API.
    */
    @isTest
    private static void shouldCreateErrorRecordWhenElevateReturnsErrorResponse() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        npe03__Recurring_Donation__c rd = buildRecurringDonation();

        Test.startTest();
        UTIL_Http_TEST.mockBadRequestCalloutResponse();

        RD2_EntryFormController.handleCommitment(JSON.serialize(rd), PAYMENT_METHOD_TOKEN);
        Test.stopTest();

        List<Error__c> errors = errorGateway.getRecords();
        System.assertEquals(1, errors.size(),
            'An error record should be created for an error response.');
        System.assertEquals(rd.npe03__Contact__c, errors[0].Related_Record_Id__c,
            'The error record should contain donor Contact Id.');
        System.assertEquals(ERR_Handler_API.Context.Elevate.name(),errors[0].Context_Type__c,
            'The error record context type should match with Elevate context.');
        System.assert(errors[0].Full_Message__c.contains(UTIL_Http_TEST.BAD_REQUEST_MESSAGE),
            'The error record should contain error response message.');
    }
    
    /**
    * @description Verifies an error record will be created when update paymnet commitment fail.
    */
    @isTest
    private static void shouldCreateErrorRecordWhenUpdatePaymentInfoReturnsErrorResponse() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        npe03__Recurring_Donation__c rd = buildRecurringDonation();
        insert rd;

        Test.startTest();
        UTIL_Http_TEST.mockBadRequestCalloutResponse();

        RD2_EntryFormController.handleUpdatePaymentCommitment(JSON.serialize(rd), PAYMENT_METHOD_TOKEN);
        Test.stopTest();

        List<Error__c> errors = errorGateway.getRecords();
        System.assertEquals(1, errors.size(),
            'An error record should be created for an error response.');
        System.assertEquals(rd.Id, errors[0].Related_Record_Id__c,
            'The error record should contain donor Contact Id.');
        System.assertEquals(ERR_Handler_API.Context.Elevate.name(),errors[0].Context_Type__c,
            'The error record context type should match with Elevate context.');
        System.assert(errors[0].Full_Message__c.contains(UTIL_Http_TEST.BAD_REQUEST_MESSAGE),
            'The error record should contain error response message.');
    }

    /**
    * @description Verifies commitment success response is returned upon successful update 
    */
    @isTest
    private static void shouldReturnSuccessResponseWhenUpdatePaymentInfoIsSuccess() {
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        npe03__Recurring_Donation__c rd = buildRecurringDonation();
        insert rd;

        rd = new npe03__Recurring_Donation__c(Id = rd.Id, CommitmentId__c = COMMITMENT_ID);

        Test.startTest();
        UTIL_Http_TEST.mockRecordUpdateCalloutResponse(mockSuccessResponseBody());

        String response = 
            RD2_EntryFormController.handleUpdatePaymentCommitment(JSON.serialize(rd), PAYMENT_METHOD_TOKEN);
        Test.stopTest();

        Integer statusCode;
        String status;
        JSONParser parser = JSON.createParser(response);

        while (parser.nextToken() != null) {
            if(parser.getCurrentToken() == JSONToken.FIELD_NAME) {
                if (parser.getText() == 'statusCode') {
                    parser.nextToken();
                    statusCode = parser.getIntegerValue();

                } else if (parser.getText() == 'status') {
                    parser.nextToken();
                    status = parser.getText();
                }
            } 
        }

        System.assertNotEquals(null, response, 'The Commitment response should be returned');
        System.assertEquals(UTIL_Http.STATUS_CODE_OK, statusCode,
            'The response status code should match: ' + response);
            System.assertEquals(UTIL_Http.STATUS_OK, status,
            'The response status should match: ' + response);
    }

    /***
    * @description Verifies Recurring Donation should be validate and handle any error before calling Elevate API
    */
    @isTest
    private static void shouldThrowExceptionWhenRDFieldValueIsInvalid() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);

        npe03__Recurring_Donation__c rd = buildRecurringDonation();
        rd.npe03__Amount__c = -100;

        String errorMessage;

        Test.startTest();

        try {
            RD2_EntryFormController.handleCommitment(JSON.serialize(rd), PAYMENT_METHOD_TOKEN);
    
        } catch(Exception ex) {
            errorMessage = ex.getMessage();
        }
        Test.stopTest();

        System.assertEquals(System.Label.RD2_AmountMustBeValid, errorMessage,
            'RD should be pre-validate before the Elevate Commitment API is called');
    }
    

    // Helpers
    ////////////////

    /****
    * @description Simulates a successful commitment creation callout
    * @return String
    */
    private static void mockRecordCreatedCalloutResponse() {
        UTIL_Http_TEST.mockRecordCreatedCalloutResponse(mockSuccessResponseBody());
    }

    /****
    * @description Returns a mock response body that mimics response body returned from Elevate
    * when a commitment is created
    * @return String
    */
    private static String mockSuccessResponseBody() {
        return '{"id":"' + COMMITMENT_ID
            + '","status":"ACTIVE","statusReason":"COMMITMENT_CREATED"'
            + ',"cardData":{"last4":"' + CARD_LAST_4
            + '","expirationMonth":"' + CARD_EXPIRATION_MONTH
            + '","expirationYear":"' + CARD_EXPIRATION_YEAR
            + '"}}';
    }

    /****
    * @description Returns contact record
    * @return Contact
    */
    private static Contact getContact() {
        return [
            SELECT FirstName, LastName, AccountId, Account.Name
            FROM Contact
            LIMIT 1
        ];
    }

    /****
    * @description Returns a new Recurring Donation record
    * @return npe03__Recurring_Donation__c
    */
    private static npe03__Recurring_Donation__c buildRecurringDonation() {
        return TEST_RecurringDonationBuilder.constructEnhancedBuilder()
            .withDefaultValues()
            .withContact(getContact().Id)
            .withAmount(100)
            .withDateEstablished(START_DATE)
            .withStartDate(START_DATE)
            .withDayOfMonth('1')
            .build();
    }

}