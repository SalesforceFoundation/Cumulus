/*
    Copyright (c) 2020, Salesforce.org
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
* @group Elevate Payment Services
* @description Tests verifying Elevate payment services commitment request
*/
@IsTest(IsParallel=false)
private with sharing class PS_CommitmentRequest_TEST {

    private static final String PAYMENT_TOKEN = 'token-abcd-efgh-ijkl-mnop-qrst';
    private static final String COMMITMENT_ID = RD2_ElevateIntegrationService_TEST.COMMITMENT_ID;
    private static final Integer USD_CURRENCY_MULTIPLIER = 100;

    private static final Integer DAY_OF_MONTH = 20;
    private static final Date START_DATE = Date.newInstance(2019, 3, DAY_OF_MONTH);
    private static final Datetime FIRST_PAYMENT_DATE = Datetime.newInstance(2019, 3, DAY_OF_MONTH);
    private static final Date CURRENT_DATE = START_DATE.addDays(-3);
    private static final Integer INSTALLMENT_FREQUENCY = 2;
    private static final String PAYMENT_CHECK = 'Check';
    private static final Double AMOUNT = 100.23;

    private static final TEST_SObjectGateway.RecurringDonationGateway rdGateway = new TEST_SObjectGateway.RecurringDonationGateway();

    /****
    * @description Creates data required for unit tests
    */
    @TestSetup
    private static void setUp() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Contact contact = UTIL_UnitTestData_TEST.getContact();
        insert contact;

        Account account = UTIL_UnitTestData_TEST.buildOrganizationAccount();
        account.npe01__One2OneContact__c = contact.Id;
        insert account;
    }

    /****
    * @description Verifies Commitment Request body to attach to the HttpRequest
    * is built based on Recurring Donation fields and its schedule
    */
    @isTest
    private static void shouldBuildCommitmentRequestBody() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Campaign rdCampaign = getDummyCampaign();

        Contact contact = getContact();
        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
            .withContact(contact.Id)
            .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
            .withCampaign(rdCampaign.Id)
            .withPaymentMethod(RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD)
            .build();

        PS_CommitmentRequest request = new PS_CommitmentRequest();
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(rd, null, PAYMENT_TOKEN);

        System.assertEquals(contact.FirstName, requestBody.firstName, 'First Name should match');
        System.assertEquals(contact.LastName, requestBody.lastName, 'Last Name should match');
        System.assertEquals(PS_IntegrationServiceConfig_TEST.testMerchantId, requestBody.merchantId, 'Merchant Id should match');
        System.assertEquals(PS_IntegrationServiceConfig_TEST.testGatewayId, requestBody.gatewayId, 'Gateway Id should match');
        System.assertEquals(PS_CommitmentRequest.CommitmentType.SUSTAINER.name(), requestBody.type, 'Commitment Type should match');
        System.assertEquals(ElevatePaymentMethod.CARD.name(), requestBody.paymentMethodType, 'Payment method should be CARD');
        System.assertEquals(PAYMENT_TOKEN, requestBody.paymentMethodToken, 'Payment Method Token should match');
        System.assertEquals(UserInfo.getDefaultCurrency(), requestBody.currencyCode, 'Currency Code should match');

        System.assertNotEquals(null, requestBody.productMetadata, 'Product Metadata should be set by default');

        PS_CommitmentRequest.Origin origin = (PS_CommitmentRequest.Origin)requestBody.productMetadata.get('origin');
        PS_CommitmentRequest.Campaign campaign = (PS_CommitmentRequest.Campaign)requestBody.productMetadata.get('campaign');

        System.assertEquals(PS_Request.OriginType.CRM.name(), origin.type,
            'Product Metadata origin type should be CRM');
        System.assertEquals(rd.npe03__Recurring_Donation_Campaign__c, campaign.id,
            'Product Metadata campaign id should be set to RD campaign');
        
        System.assertEquals(1, requestBody.schedules.size(),
            'One schedule should be passed to the API: ' + requestBody.schedules);

        PS_CommitmentRequest.Schedule schedule = requestBody.schedules[0];
        System.assertEquals(AMOUNT * USD_CURRENCY_MULTIPLIER, schedule.amount, 'Recurring Amount should match');
        System.assertEquals('MONTH', schedule.frequency, 'Donation should be made monthly');
        System.assertEquals(INSTALLMENT_FREQUENCY, schedule.frequencyInterval, 'Donation frequency should match');
        System.assertEquals(FIRST_PAYMENT_DATE.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''), schedule.firstOccurrenceOnTimestamp, 'First Payment Date should match');
    }

    /**
    * @description Verifies that the update request body is built based on the Recurring Donation fields
    */
    @isTest
    private static void shouldBuildUpdateCommitmentRequestBody() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Contact contact = getContact();
        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
            .withContact(contact.Id)
            .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
            .withCommitmentId(COMMITMENT_ID)
            .withPaymentMethod(RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD)
            .build();

        insert rd;

        npe03__Recurring_Donation__c oldRd = rd.clone();
        oldRd.npe03__Amount__c = rd.npe03__Amount__c + 1;

        PS_CommitmentRequest request = new PS_CommitmentRequest();

        Test.startTest();
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(rd, oldRd, PAYMENT_TOKEN);
        Test.stopTest();

        System.assertEquals(UserInfo.getDefaultCurrency(), requestBody.currencyCode, 'Currency Code should match');
        System.assertEquals(rd.CommitmentId__c, requestBody.id, 'Commitment Id should match');
        System.assertEquals(ElevatePaymentMethod.CARD.name(), requestBody.paymentMethodType, 'Expect payment method to be card');
        System.assertEquals(PAYMENT_TOKEN, requestBody.paymentMethodToken, 'Payment Method Token should match');
        System.assertEquals(true, requestBody.deactivateAllExistingSchedules, 'Deactivate Existing Schedules Boolean should set to true');
        System.assertEquals(1, requestBody.schedules.size(),
            'One schedule should be passed to the API: ' + requestBody.schedules);

        PS_CommitmentRequest.Schedule schedule = requestBody.schedules[0];
        System.assertEquals(AMOUNT * USD_CURRENCY_MULTIPLIER, schedule.amount, 'Recurring Amount should match');
        System.assertEquals('MONTH', schedule.frequency, 'Donation should be made monthly');
        System.assertEquals(INSTALLMENT_FREQUENCY, schedule.frequencyInterval, 'Donation frequency should match');
        System.assertEquals(FIRST_PAYMENT_DATE.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''), schedule.firstOccurrenceOnTimestamp, 'First Payment Date should match');
    }

    /**
    * @description Verify update request when changing payment method to ACH
    */
    @isTest
    private static void shouldBuildUpdateCommitmentRequestBodyACH() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Contact contact = getContact();
        npe03__Recurring_Donation__c oldRd = getRecurringDonationBuilder()
                .withContact(contact.Id)
                .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
                .withCommitmentId(COMMITMENT_ID)
                .withPaymentMethod(RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD)
                .build();

        insert oldRd;

        npe03__Recurring_Donation__c updateRequestRd = new npe03__Recurring_Donation__c(
                Id = oldRd.Id,
                CommitmentId__c = oldRd.CommitmentId__c,
                PaymentMethod__c = RD2_Constants.PAYMENT_PICKLIST_VALUE_ACH,
                npe03__Contact__c = contact.Id
        );

        PS_CommitmentRequest request = new PS_CommitmentRequest();

        Test.startTest();
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(updateRequestRd, null, PAYMENT_TOKEN);
        Test.stopTest();

        System.assertEquals(ElevatePaymentMethod.ACH.name(), requestBody.paymentMethodType, 'Expected payment method to be ACH');
        PS_CommitmentRequest.AchData achData = requestBody.achData;

        System.assertEquals('WEB', achData.achCode, 'ACH Code should be WEB');
        System.assertEquals('INDIVIDUAL', achData.type, 'AchData type should be INDIVIDUAL');
        System.assertEquals('CHECKING', achData.bankType, 'AchData bankType should be CHECKING');
    }

    /**
    * @description Verifies that the update request body should not set new schedules if there is no data
    */
    @isTest
    private static void shouldBuildLeanUpdateCommitmentRequestBodyIfScheduleDataIsNotChanged() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Contact contact = getContact();
        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            CommitmentId__c = COMMITMENT_ID,
            PaymentMethod__c = RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD,
            npe03__Contact__c = contact.Id
        );

        PS_CommitmentRequest request = new PS_CommitmentRequest();


        Test.startTest();
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(rd, rd.clone(), PAYMENT_TOKEN);
        Test.stopTest();

        System.assertEquals(rd.CommitmentId__c, requestBody.id, 'Commitment Id should match');
        System.assertEquals(ElevatePaymentMethod.CARD.name(), requestBody.paymentMethodType, 'Expect payment method to be card');
        System.assertEquals(PAYMENT_TOKEN, requestBody.paymentMethodToken, 'Payment Method Token should match');
        System.assertEquals(null, requestBody.deactivateAllExistingSchedules, 'Deactivate Existing Schedules Boolean should not be set');
        System.assertEquals(null, requestBody.schedules,
            'no schedule should be set on the request body');
    }

    /****
    * @description Verifies two schedules are populated in the Commitment Request
    * when Installment Period is 1st and 15th.
    */
    @isTest
    private static void shouldBuildTwoSchedulesWhenInstalmentPeriodIs1stAnd15th() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();
        Contact contact = getContact();
        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
            .withContact(contact.Id)
            .withInstallmentPeriod(RD2_Constants.INSTALLMENT_PERIOD_FIRST_AND_FIFTEENTH)
            .withInstallmentFrequency(1)
            .withDayOfMonth(null)
            .build();

        PS_CommitmentRequest request = new PS_CommitmentRequest();
        PS_CommitmentRequest.RequestBody requestBody = new PS_CommitmentRequest.RequestBody();
        request.setSchedules(requestBody, new RD2_ScheduleService().buildNewSchedules(rd), 'USD');

        System.assertEquals(2, requestBody.schedules.size(),
            'Two schedules should be passed to the API: ' + requestBody.schedules);

        for (PS_CommitmentRequest.Schedule schedule : requestBody.schedules) {
            System.assertEquals(AMOUNT * USD_CURRENCY_MULTIPLIER, schedule.amount, 'Recurring Amount should match');
            System.assertEquals('MONTH', schedule.frequency, 'Donation should be made monthly');
            System.assertEquals(1, schedule.frequencyInterval, 'Donation should be made every month');
        }
        String firstScheduleDate = Datetime.newInstance(2019, 04, 01).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String secondDonationDate = Datetime.newInstance(2019, 04, 15).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        System.assertEquals(firstScheduleDate, requestBody.schedules[0].firstOccurrenceOnTimestamp,
            'First Payment Date on the 1st schedule should match');
        System.assertEquals(secondDonationDate, requestBody.schedules[1].firstOccurrenceOnTimestamp,
            'First Payment Date on the 15th schedule should match');
    }

    /****
    * @description Verifies donor information is set to Organization
    * when it is specified regardless if the Contact is specified
    */
    @isTest
    private static void shouldSetDonorInfoWhenOrganizationIsSpecified() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Account organization = UTIL_UnitTestData_TEST.buildOrganizationAccount();
        insert organization;

        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
            .withAccount(organization.Id)
            .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
            .build();

        PS_CommitmentRequest request = new PS_CommitmentRequest();
        PS_CommitmentRequest.RequestBody requestBody = new PS_CommitmentRequest.RequestBody();
        
        request.setDonorInfo(requestBody, rd);

        System.assertEquals(organization.Name, requestBody.firstName, 'Request First Name should match Organization Name');
        System.assertEquals(organization.Name, requestBody.lastName, 'Request Last Name should match Organization Name');
    }

    /**
    * @description Verifies a valid create commitment HttpRequest is returned
    */
    @isTest
    private static void shouldBuildCreateCommitmentRequest() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        final String jsonRequestBody = 'commitment request body';

        Test.startTest();
        String commitmentId = null;
        HttpRequest request = PS_CommitmentRequest.buildRequest(commitmentId, jsonRequestBody);
        Test.stopTest();

        final String expectedEndpoint = PS_IntegrationServiceConfig_TEST.testBaseUrl
            + PS_Request.ENDPOINT_COMMITMENT;
        System.assertEquals(expectedEndpoint, request.getEndpoint(), 'Endpoint should match');

        System.assertEquals(UTIL_Http.Method.POST.name(), request.getMethod(), 'The HttpRequest method should match');
        System.assertEquals(jsonRequestBody, request.getBody(), 'Request body should match');
    }

    /**
    * @description Verifies a valid edit commitment HttpRequest is returned
    */
    @isTest
    private static void shouldBuildEditCommitmentRequest() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        final String jsonRequestBody = 'commitment request body';

        Test.startTest();
        String commitmentId = RD2_ElevateIntegrationService_TEST.COMMITMENT_ID;
        HttpRequest request = PS_CommitmentRequest.buildRequest(commitmentId, jsonRequestBody);
        Test.stopTest();

        final String expectedEndpoint = PS_IntegrationServiceConfig_TEST.testBaseUrl
            + PS_Request.ENDPOINT_COMMITMENT;
        System.assertEquals(expectedEndpoint, request.getEndpoint(), 'Endpoint should match');

        System.assertEquals(UTIL_Http.Method.PATCH.name(), request.getMethod(), 'The HttpRequest method should match');
        System.assertEquals(jsonRequestBody, request.getBody(), 'Request body should match');
    }


    @IsTest
    private static void requestBodyCanSetPaymentMethodCard() {
        PS_CommitmentRequest.RequestBody commitmentBody = new PS_CommitmentRequest.RequestBody();
        System.assertEquals(null,
                commitmentBody.paymentMethodType,
                'Expected payment method for new RequestBody to be empty');

        commitmentBody.withPaymentMethodType(RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD);

        System.assertEquals(ElevatePaymentMethod.CARD.name(),
                commitmentBody.paymentMethodType,
                'Expected payment method to be CARD');
    }

    @IsTest
    private static void requestBodyCanSetPaymentMethodACH() {
        PS_CommitmentRequest.RequestBody commitmentBody = new PS_CommitmentRequest.RequestBody();

        commitmentBody.withPaymentMethodType(RD2_Constants.PAYMENT_PICKLIST_VALUE_ACH);

        System.assertEquals(ElevatePaymentMethod.ACH.name(),
                commitmentBody.paymentMethodType,
                'Expected payment method to be ACH');
    }

    @isTest
    private static void shouldBuildContactACHCommitmentRequestBody() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Campaign rdCampaign = new Campaign(name = 'Annual Campaign');
        insert rdCampaign;

        Contact contact = getContact();
        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
                .withContact(contact.Id)
                .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
                .withCampaign(rdCampaign.Id)
                .withPaymentMethod(RD2_Constants.PAYMENT_PICKLIST_VALUE_ACH)
                .build();

        PS_CommitmentRequest request = new PS_CommitmentRequest();
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(rd, null, PAYMENT_TOKEN);

        System.assertEquals(contact.FirstName, requestBody.firstName, 'First Name should match');
        System.assertEquals(contact.LastName, requestBody.lastName, 'Last Name should match');
        System.assertEquals(PS_CommitmentRequest.CommitmentType.SUSTAINER.name(), requestBody.type, 'Commitment Type should match');
        System.assertEquals(ElevatePaymentMethod.ACH.name(), requestBody.paymentMethodType, 'Payment method should be ACH');
        PS_CommitmentRequest.AchData achData = requestBody.achData;

        System.assertEquals('WEB', achData.achCode, 'ACH Code should be WEB');
        System.assertEquals('INDIVIDUAL', achData.type, 'AchData type should be INDIVIDUAL');
        System.assertEquals('CHECKING', achData.bankType, 'AchData bankType should be CHECKING');
        System.assertEquals(contact.firstName + ' ' + contact.lastName, requestBody.accountName);
        System.assertEquals(PAYMENT_TOKEN, requestBody.paymentMethodToken, 'Payment Method Token should match');
        System.assertEquals(UserInfo.getDefaultCurrency(), requestBody.currencyCode, 'Currency Code should match');

        PS_CommitmentRequest.Origin origin = (PS_CommitmentRequest.Origin)requestBody.productMetadata.get('origin');
        PS_CommitmentRequest.Campaign campaign = (PS_CommitmentRequest.Campaign)requestBody.productMetadata.get('campaign');
        System.assertEquals(PS_Request.OriginType.CRM.name(), origin.type,
                'Product Metadata origin type should be CRM');
        System.assertEquals(rd.npe03__Recurring_Donation_Campaign__c, campaign.id,
                'Product Metadata campaign id should be set to RD campaign');

        System.assertEquals(1, requestBody.schedules.size(),
                'One schedule should be passed to the API: ' + requestBody.schedules);

        PS_CommitmentRequest.Schedule schedule = requestBody.schedules[0];
        System.assertEquals(AMOUNT * USD_CURRENCY_MULTIPLIER, schedule.amount, 'Recurring Amount should match');
        System.assertEquals('MONTH', schedule.frequency, 'Donation should be made monthly');
        System.assertEquals(INSTALLMENT_FREQUENCY, schedule.frequencyInterval, 'Donation frequency should match');
        System.assertEquals(FIRST_PAYMENT_DATE.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''), schedule.firstOccurrenceOnTimestamp, 'First Payment Date should match');
    }

    @isTest
    private static void shouldBuildAccountACHCommitmentRequestBody() {
        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Campaign rdCampaign = getDummyCampaign();

        Contact contact = getContact();
        Account account = getOrganizationAccount(contact.Id);
        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
                .withAccount(account.Id)
                .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
                .withCampaign(rdCampaign.Id)
                .withPaymentMethod(RD2_Constants.PAYMENT_PICKLIST_VALUE_ACH)
                .build();

        PS_CommitmentRequest request = new PS_CommitmentRequest();
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(rd, null, PAYMENT_TOKEN);

        System.assertEquals(account.Name, requestBody.firstName, 'First Name should be company name');
        System.assertEquals(account.Name, requestBody.lastName, 'Last Name should be company name');
        System.assertEquals(account.Name, requestBody.accountName, 'Commitment request account name should be company name');
        System.assertEquals(PS_CommitmentRequest.CommitmentType.SUSTAINER.name(), requestBody.type, 'Commitment Type should match');
        System.assertEquals(ElevatePaymentMethod.ACH.name(), requestBody.paymentMethodType, 'Payment method should be ACH');
        PS_CommitmentRequest.AchData achData = requestBody.achData;

        System.assertEquals('WEB', achData.achCode, 'AchData Code should be WEB');
        System.assertEquals('BUSINESS', achData.type, 'AchData type should be BUSINESS');
        System.assertEquals('CHECKING', achData.bankType, 'AchData bankType should be CHECKING');
    }

    @IsTest
    static void productMetadataPreservesOrigin() {
        String newCampaignId = '701R00000027JNdIAA';
        String serializedProductMetadata = '{"origin":{"type":"CRM"},"campaign":{"id":"701R00000027JNdIAM"}}';
        Map<String, Object> untypedMetadata = (Map<String, Object>) JSON.deserializeUntyped(serializedProductMetadata);

        PS_CommitmentRequest.ProductMetadata productMetadata = new PS_CommitmentRequest.ProductMetadata()
                .withCampaign(newCampaignId);
        Map<String, Object> updatedUntypedMetadata = productMetadata.mergeWithExistingMetadata(untypedMetadata);

        PS_CommitmentRequest.ProductMetadata updatedMetadata = parseUntypedMetadata(updatedUntypedMetadata);
        System.assertEquals(newCampaignId, updatedMetadata.campaign.id);
        System.assertEquals('CRM', updatedMetadata.origin.type);
    }

    @IsTest
    static void productMetadataPreservesAny() {
        String newCampaignId = '701R00000027JNdIAA';
        String serializedProductMetadata = '{"origin":{"type":"CRM"},"campaign":{"id":"701R00000027JNdIAM"},"consent":{"message":"Some message","optin":true}}';
        Map<String, Object> untypedMetadata = (Map<String, Object>) JSON.deserializeUntyped(serializedProductMetadata);

        PS_CommitmentRequest.ProductMetadata productMetadata = new PS_CommitmentRequest.ProductMetadata()
                .withCampaign(newCampaignId);
        Map<String, Object> updatedUntypedMetadata = productMetadata.mergeWithExistingMetadata(untypedMetadata);

        PS_CommitmentRequest.ProductMetadata updatedMetadata = parseUntypedMetadata(updatedUntypedMetadata);
        System.assertEquals(newCampaignId, updatedMetadata.campaign.id);
        System.assertEquals('CRM', updatedMetadata.origin.type);

        Map<String, Object> consentData = (Map<String, Object>) updatedUntypedMetadata.get('consent');

        String consentMessage = (String) consentData.get('message');
        Boolean optin = (Boolean) consentData.get('optin');

        System.assertEquals('Some message', consentMessage);
        System.assertEquals(true, optin);
    }

    @IsTest
    static void campaignUpdateCallsOutForProductMetadata() {
        String MOCK_GET_RESPONSE_BODY = '{"commitment":{"productMetadata":{"origin":{"type":"CRM"},"campaign":{"id":"701R00000027JNdIAM"}}}}';

        RD2_ScheduleService.currentDate = CURRENT_DATE;
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        RD2_EnablementService_TEST.setRecurringDonations2Enabled();

        Contact contact = getContact();
        Campaign rdCampaign = getDummyCampaign();

        npe03__Recurring_Donation__c rd = getRecurringDonationBuilder()
                .withContact(contact.Id)
                .withInstallmentFrequency(INSTALLMENT_FREQUENCY)
                .withPaymentMethod(RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD)
                .withCommitmentId(COMMITMENT_ID)
                .build();

        PS_CommitmentRequest request = new PS_CommitmentRequest();

        npe03__Recurring_Donation__c updatedRd = rd.clone();
        updatedRd.npe03__Recurring_Donation_Campaign__c = rdCampaign.Id;

        Test.startTest();
        UTIL_Http_TEST.mockSuccessCalloutResponse(MOCK_GET_RESPONSE_BODY);
        PS_CommitmentRequest.RequestBody requestBody = request.getRequestBody(updatedRd, rd, PAYMENT_TOKEN);
        Test.stopTest();

        PS_CommitmentRequest.ProductMetadata productMetadata = parseUntypedMetadata(requestBody.productMetadata);

        System.assertEquals('CRM', productMetadata.origin.type);
        System.assertEquals(rdCampaign.Id, productMetadata.campaign.id);
    }

    // Helpers
    ///////////////

    /**
     * @description Base common Recurring Donation record
     * @return TEST_RecurringDonationBuilder instance
     */
    private static TEST_RecurringDonationBuilder getRecurringDonationBuilder() {
        return TEST_RecurringDonationBuilder.constructEnhancedBuilder()
            .withDefaultValues()
            .withAmount(AMOUNT)
            .withCurrencyIsoCode(UserInfo.getDefaultCurrency())
            .withPaymentMethod(PAYMENT_CHECK)
            .withDateEstablished(START_DATE)
            .withStartDate(START_DATE)
            .withDayOfMonth(String.valueOf(DAY_OF_MONTH));
    }


    private static Campaign getDummyCampaign() {
        Campaign rdCampaign = new Campaign(Name = 'Annual Campaign');
        insert rdCampaign;
        return rdCampaign;
    }

    private static Account getOrganizationAccount(Id contactId) {
        return [
                SELECT Name, npe01__One2OneContact__c
                FROM Account
                WHERE npe01__One2OneContact__c = :contactId
                AND npe01__SYSTEMIsIndividual__c = false
                LIMIT 1
        ];
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

    /**
     * @param untypedProductMetadata Parse origin and campaign out of productMetadata Map<String, Object>
     *
     *  @return A ProductMetadata class with any origin/campaign data from what was passed in
     */
    static PS_CommitmentRequest.ProductMetadata parseUntypedMetadata(Map<String, Object> untypedProductMetadata) {
        PS_CommitmentRequest.ProductMetadata productMetadata = new PS_CommitmentRequest.ProductMetadata();

        if (untypedProductMetadata.containsKey('origin')) {
            Object origin = untypedProductMetadata.get('origin');
            if (origin instanceof PS_CommitmentRequest.Origin) {
                productMetadata.origin = (PS_CommitmentRequest.Origin)origin;
            }
            Map<String, Object> untypedOrigin = (Map<String, Object>)origin;
            String originType = (String) untypedOrigin.get('type');
            productMetadata.origin = new PS_CommitmentRequest.Origin(originType);
        }

        if (untypedProductMetadata.containsKey('campaign')) {
            Object campaign = untypedProductMetadata.get('campaign');
            if (campaign instanceof PS_CommitmentRequest.Campaign) {
                productMetadata.campaign = (PS_CommitmentRequest.Campaign)campaign;
            } else {
                Map<String, Object> untypedCampaign = (Map<String, Object>)campaign;
                String campaignId = (String) untypedCampaign.get('id');
                productMetadata.campaign = new PS_CommitmentRequest.Campaign(campaignId);
            }
        }

        return productMetadata;
    }
}
