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
* @description Contains Elevate payment services methods specific to building a commitment request
*/
public inherited sharing class PS_CommitmentRequest {

    /***
     * @description Commitment type
     */
    public enum CommitmentType {
        SUSTAINER
    }

    public enum ElevateBankAccountType {
        INDIVIDUAL,
        BUSINESS
    }

    /***
     * @description Commitment Status
     * Commitments start in the NEW state, then transition to ACTIVE after the first payment.
     * The Status cannot be an enum since NEW is a reserved keyword.
     */
    public static final String STATUS_NEW = 'NEW';
    public static final String STATUS_ACTIVE = 'ACTIVE';
    public static final String STATUS_INACTIVE = 'INACTIVE';
    public static final String STATUS_FAILING = 'FAILING';

    /***
     * @description Commitment Status Reason
     */
    public enum CommitmentStatusReason {
        COMMITMENT_CREATED,
        PAID_AS_AGREED,
        PARTIALLY_PAID,
        PAYMENT_ERROR,
        PAYMENT_DECLINE,
        DONOR_CANCELED,
        MULTIPLE_FAILURES,
        NEVER_PAID
    }

    /***
     * @description Commitment schedule frequency
     */
    public enum Frequency {
        DAY, WEEK, MONTH, YEAR
    }

    /***
     * @description Translates the Installment Period into the Elevate API frequency value
     */
    private static final Map<String, String> frequencyByInstallmentPeriod = new Map<String, String>{
        RD2_Constants.INSTALLMENT_PERIOD_YEARLY => Frequency.YEAR.name(),
        RD2_Constants.INSTALLMENT_PERIOD_MONTHLY => Frequency.MONTH.name(),
        RD2_Constants.INSTALLMENT_PERIOD_WEEKLY => Frequency.WEEK.name(),
        RD2_Constants.INSTALLMENT_PERIOD_DAILY => Frequency.DAY.name(),
        RD2_Constants.INSTALLMENT_PERIOD_FIRST_AND_FIFTEENTH => Frequency.MONTH.name()
    };

    /***
     * @description Translates the currency amount into the lowest denominator; e.g. dollars into cents
     */
    private static final Map<String, Integer> currencyMultiplierByIsoCode = new Map<String, Integer>{
        'USD' => 100
    };

    /***
     * @description Default currency multiplier
     */
    private static final Integer DEFAULT_CURRENCY_MULTIPLIER = 100;

    /***
     * @description Contains max length for a first/last name passed to the Elevate commitment request
     */
    private static final Integer MAX_NAME_LENGTH = 60;

    private static final String ACH_BANK_TYPE_CHECKING = 'CHECKING';
    private static final String ACH_CODE_WEB = 'WEB';
    private static final String ACH_CONSENT_MESSAGE = 'true';

    private static final Map<SObjectType, ElevateBankAccountType> BANK_ACCOUNT_TYPE_MAP = new Map<SObjectType, ElevateBankAccountType>{
        Contact.SObjectType => ElevateBankAccountType.INDIVIDUAL,
        Account.SObjectType => ElevateBankAccountType.BUSINESS
    };

    /***
     * @description Payment Services configuration
     */
    @TestVisible
    private PS_IntegrationServiceConfig.Service configService {
        get {
            if (configService == null) {
                configService = new PS_IntegrationServiceConfig.Service();
            }
            return configService;
        }
        set;
    }

    /**
    * @description Recurring Donation schedule service user to build schedules used in a commitment request
    */
    private RD2_ScheduleService scheduleService {
        get {
            if (scheduleService == null) {
                scheduleService = new RD2_ScheduleService();
            }
            return scheduleService;
        }
        set;
    }

    /**
    * @description Sends requests and constructs the response
    */
    private UTIL_Http.RequestService requestService {
        get {
            if (requestService == null) {
                requestService = new UTIL_Http.RequestService();
            }
            return requestService;
        }
        set;
    }

    /***
    * @description Creates an HttpRequest for a new commitment creation or
    * existing commitment update depending on the provided commitment Id
    * @param commitmentId Elevate recurring commitment Id
    * @param jsonRequestBody JSON containing parameters for the purchase call request body
    * @return HttpRequest
    */
    public static HttpRequest buildRequest(String commitmentId, String jsonRequestBody) {
        UTIL_Http.Method method = String.isBlank(commitmentId)
            ? UTIL_Http.Method.POST
            : UTIL_Http.Method.PATCH;

        return new PS_Request.Builder()
            .withMethod(method)
            .withEndpoint(PS_Request.ElevateEndpoint.COMMITMENT)
            .withRecommendedTimeout()
            .withBody(jsonRequestBody)
            .build();
    }

    /**
    * @description Builds a commitment GET request for the provided commitment Id
    * @param commitmentId Elevate recurring commitment Id
    * @return HttpRequest
    */
    public static HttpRequest buildGetRequest(String commitmentId) {
        return new PS_Request.Builder()
                .withCommitmentId(commitmentId)
                .withEndpoint(PS_Request.ElevateEndpoint.COMMITMENT)
                .withMethod(UTIL_Http.Method.GET)
                .build();
    }

    /***
    * @description Constructs the commitment request body for the specified Recurring Donation.
    * The commitment Id is used to differentiate between the create and edit commitment request content.
    * @param rd Recurring Donation record
    * @param token Payment Method Token
    * @return RequestBody
    */
    public RequestBody getRequestBody(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd, String token) {
        Boolean isCreateCommitment = String.isBlank(rd.CommitmentId__c);

        return isCreateCommitment
            ? getCreateRequestBody(rd, token)
            : getUpdateRequestBody(rd, oldRd, token);
    }

    /***
    * @description Constructs the create commitment request body for the specified Recurring Donation.
    * @param rd Recurring Donation record
    * @param token Payment Method Token
    * @return RequestBody
    */
    public RequestBody getCreateRequestBody(npe03__Recurring_Donation__c rd, String token) {

        String currencyCode = UserInfo.isMultiCurrencyOrganization()
            ? (String) rd.get('CurrencyIsoCode')
            : UserInfo.getDefaultCurrency();

        ProductMetadata productMetadata = new ProductMetadata()
            .withCampaign(rd.npe03__Recurring_Donation_Campaign__c)
            .withOrigin(PS_Request.OriginType.CRM.name());
    
        RequestBody reqBody =  new RequestBody()
            .withMerchantId(configService.getMerchantIds())
            .withGatewayId(configService.getGatewayIds())
            .withPaymentMethodToken(token)
            .withPaymentMethodType(rd.PaymentMethod__c)
            .withCurrency(currencyCode)
            .withProductMetadata(productMetadata.toUntypedMap());


        ElevateBankAccountType accountHolderType = setDonorInfo(reqBody, rd);
        if(reqBody.isACH()) {
            reqBody.withACHAccountHolder(accountHolderType);
        }
        setSchedules(reqBody, scheduleService.buildNewSchedules(rd), currencyCode);

        return reqBody;
    }

    /***
    * @description Constructs the edit commitment request body for the specified Recurring Donation.
    * @param rd Recurring Donation record
    * @param token Payment Method Token
    * @return RequestBody
    */
    private RequestBody getUpdateRequestBody(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd, String token) {
        RequestBody reqBody = new RequestBody()
            .withCommitmentId(rd.CommitmentId__c)
            .withPaymentMethodType(rd.PaymentMethod__c)
            .withPaymentMethodToken(token);

        SObject donor = getDonorRecord(rd);
        ElevateBankAccountType accountHolderType = getAccountHolderType(donor);

        if(reqBody.isACH()) {
            reqBody.withAchData(accountHolderType);
        }

        String currencyCode = UserInfo.isMultiCurrencyOrganization()
            ? (String) rd.get('CurrencyIsoCode')
            : UserInfo.getDefaultCurrency();

        if (isElevateScheduleFieldsChanged(rd, oldRd)) {
            reqBody.deactivateOldSchedules();
            setSchedules(reqBody, scheduleService.buildNewSchedules(rd), currencyCode);
        }

        if (isElevateCampaignChanged(rd, oldRd)) {
            Map<String, Object> updatedMetadata = buildUpdatedProductMetadata(rd);
            reqBody.withProductMetadata(updatedMetadata);
        }

        return reqBody;
    }

    private Map<String, Object> buildUpdatedProductMetadata(npe03__Recurring_Donation__c rd) {
        Map<String, Object> existingProductMetadata = getExistingProductMetadata(rd.CommitmentId__c);
        ProductMetadata productMetadata = new ProductMetadata()
                .withCampaign(rd.npe03__Recurring_Donation_Campaign__c);

        Map<String, Object> mergedMetadata = productMetadata.mergeWithExistingMetadata(existingProductMetadata);
        return mergedMetadata;
    }

    private Map<String, Object> getExistingProductMetadata(String commitmentId) {
        Map<String, Object> responseBody = getElevateCommitment(commitmentId);

        Map<String, Object> commitment = (Map<String, Object>) responseBody.get('commitment');
        Map<String, Object> productMetadata = (Map<String, Object>) commitment.get('productMetadata');

        return productMetadata;
    }

    private Map<String, Object> getElevateCommitment(String commitmentId) {
        HttpRequest commitmentGetRequest = buildGetRequest(commitmentId);
        UTIL_Http.Response response = requestService.sendRequest(commitmentGetRequest);

        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.body);
        return responseBody;
    }

    /**
    * @description Check if Elevate schedule needs to be update
    * @param rd new Recurring Donation
    * @param oldRd old Recurring Donation
    */
    public Boolean isElevateScheduleFieldsChanged(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {
        if (oldRd == null) {
            return false;
        }

        return rd.npe03__Amount__c != oldRd.npe03__Amount__c
            || rd.InstallmentFrequency__c != oldRd.InstallmentFrequency__c
            || rd.npe03__Installment_Period__c != oldRd.npe03__Installment_Period__c;
    }

    public Boolean isElevateCampaignChanged(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {
        return rd.npe03__Recurring_Donation_Campaign__c != oldRd?.npe03__Recurring_Donation_Campaign__c;
    }
    /**
    * @description Sets donor info on the commitment request body
    * @param reqBody RequestBody
    * @param rd Recurring Donation record
    * @return void
    */
    @TestVisible
    private ElevateBankAccountType setDonorInfo(RequestBody reqBody, npe03__Recurring_Donation__c rd) {
        SObject donor = getDonorRecord(rd);
        return setDonorFromSObject(reqBody, donor);
    }

    private ElevateBankAccountType setDonorFromSObject(RequestBody reqBody, SObject donor) {
        Schema.SObjectType donorSObjectType = donor.getSObjectType();
        if (donorSObjectType == Contact.SObjectType) {
            reqBody.withDonor((Contact)donor);
        } else {
            reqBody.withDonor((Account)donor);
        }
        return getAccountHolderType(donor);
    }

    private SObject getDonorRecord(npe03__Recurring_Donation__c rd) {
        Contact contactDonor = rd.npe03__Contact__c != null
                ? getContact(rd.npe03__Contact__c)
                : null;

        Boolean isHouseholdDonor = donorIsInHousehold(contactDonor, rd.npe03__Organization__c);

        if (isHouseholdDonor) {
            return contactDonor;
        } else {
            return getAccount(rd.npe03__Organization__c);
        }
    }

    private Boolean donorIsInHousehold(Contact contactDonor, Id rdAccountId) {
        Boolean isHouseholdDonor = contactDonor != null
                && ( rdAccountId == null || rdAccountId == contactDonor.AccountId);
        return isHouseholdDonor;
    }

    private ElevateBankAccountType getAccountHolderType(SObject donor) {
        Schema.SObjectType donorSObjectType = donor.getSObjectType();
        return BANK_ACCOUNT_TYPE_MAP.get(donorSObjectType);
    }

    /**
    * @description Sets schedules on the commitment request body
    * @param reqBody RequestBody
    * @param rdSchedules Recurring Donation Schedules
    * @param currencyCode Currency ISO Code
    * @return void
    */
    @TestVisible
    private void setSchedules(RequestBody reqBody, List<RecurringDonationSchedule__c> rdSchedules, String currencyCode) {
        Integer currencyMultiplier = getCurrencyMultiplier(currencyCode);

        List<Schedule> schedules = new List<Schedule>();
        for (RecurringDonationSchedule__c rdSchedule : rdSchedules) {
            schedules.add(new Schedule(rdSchedule, currencyMultiplier, reqBody.isCommitmentUpdate()));
        }

        reqBody.withSchedules(schedules);
    }

    /**
    * @description Determines the currency multiplier
    * @param currencyCode Currency ISO Code
    * @return Integer
    */
    private Integer getCurrencyMultiplier(String currencyCode) {
        Integer currencyMultiplier = currencyMultiplierByIsoCode.get(currencyCode);

        return currencyMultiplier == null
            ? DEFAULT_CURRENCY_MULTIPLIER
            : currencyMultiplier;
    }

    /***
    * @description Retrieves Contact data specified as the donor on the Recurring Donation record
    * that is not yet saved into database
    * @param contactId Contact Id
    * @return Contact
    */
    private Contact getContact(Id contactId) {
        List<Contact> contacts = [
            SELECT
                AccountId, FirstName, LastName
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        
        return contacts.isEmpty() ? null : contacts[0];
    }

    /***
    * @description Retrieves Account data specified as the donor on the Recurring Donation record
    * that is not yet saved into database
    * @param accountId Account Id
    * @return Account
    */
    private Account getAccount(Id accountId) {
        List<Account> accounts = [
            SELECT Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        return accounts.isEmpty() ? null : accounts[0];
    }

    public with sharing class AchData {
        public String achCode;
        public String consent;
        public String type;
        public String bankType;
    }


    /***
    * @description Assists in constructing the Commitment HttpRequest body.
    */
    public class RequestBody {
        /***
         * Required properties
         */
        public String id;
        public String firstName;
        public String lastName;
        public String accountName;
        public String merchantId;
        public String gatewayId;
        public String type;
        public String paymentMethodType;
        public String paymentMethodToken;
        public String currencyCode;
        public Boolean deactivateAllExistingSchedules;
        public List<Schedule> schedules;
        public AchData achData;
        public String productMetadataSchemaUri;
        /***
         * Optional properties
         */
        public Map<String, Object> productMetadata;

        /***
         * @description Constructor
         */
        public RequestBody() {
            //set defaults
            currencyCode = UserInfo.getDefaultCurrency();
            type = CommitmentType.SUSTAINER.name();
        }

        /***
        * @description Set boolean to de activate all existing schedule
        * @return RequestBody This request body instance 
        */
        public RequestBody deactivateOldSchedules() {
            this.deactivateAllExistingSchedules = true;
            return this;
        }

        /**
         * @description Sets merchant Id
         * @param commitmentId Recurring commitment Id
         * @return RequestBody This request body instance
         */
        public RequestBody withCommitmentId(String commitmentId) {
            this.id = commitmentId;
            return this;
        }

        /**
         * @description Sets merchant Id
         * @param merchantId Payments merchant Id
         * @return RequestBody This request body instance
         */
        public RequestBody withMerchantId(String merchantId) {
            this.merchantId = merchantId;
            return this;
        }

        /**
         * @description Sets gateway Id
         * @param gatewayId Payments gateway Id
         * @return RequestBody This request body instance
         */
        public RequestBody withGatewayId(String gatewayId) {
            this.gatewayId = gatewayId;
            return this;
        }

        /**
         * @description Sets currency code value
         * @param currencyCode Currency ISO Code
         * @return RequestBody This request body instance
         */
        public RequestBody withCurrency(String currencyCode) {
            this.currencyCode = currencyCode;
            return this;
        }

        /**
         * @description Sets payment token, for example credit card token
         * @param token Token
         * @return RequestBody This request body instance
         */
        public RequestBody withPaymentMethodToken(String token) {
            if (String.isNotBlank(token)) {
                this.paymentMethodToken = token;
            }
            return this;
        }

        public RequestBody withPaymentMethodType(String paymentMethodPicklistValue) {
            if(paymentMethodPicklistValue == RD2_Constants.PAYMENT_PICKLIST_VALUE_ACH) {
                this.paymentMethodType = ElevatePaymentMethod.ACH.name();
            } else if(paymentMethodPicklistValue == RD2_Constants.PAYMENT_PICKLIST_VALUE_CARD) {
                this.paymentMethodType = ElevatePaymentMethod.CARD.name();
            }
            return this;
        }

        public RequestBody withACHAccountHolder(ElevateBankAccountType accountHolderType) {
            withAchData(accountHolderType);
            this.accountName = getAccountName(accountHolderType);
            return this;
        }

        public RequestBody withAchData(ElevateBankAccountType accountHolderType) {
            this.achData = new AchData();
            this.achData.achCode = ACH_CODE_WEB;
            this.achData.bankType = ACH_BANK_TYPE_CHECKING;
            this.achData.consent = ACH_CONSENT_MESSAGE;
            this.achData.type = accountHolderType.name();
            return this;
        }

        private String getAccountName(ElevateBankAccountType accountHolderType) {
            if (accountHolderType == ElevateBankAccountType.INDIVIDUAL) {
                return String.format('{0} {1}', new List<String>{
                        this.firstName, this.lastName
                });
            } else {
                return this.lastName;
            }
        }

        /**
         * @description Sets donor related info such as first and last name required fields
         * @param contact Donor
         * @return RequestBody This request body instance
         */
        public RequestBody withDonor(Contact contact) {
            if (contact == null) {
                return this;
            }

            this.firstName = trimNameField(contact.FirstName);
            this.lastName = trimNameField(contact.LastName);

            return this;
        }

        /**
         * @description Sets donor related info
         * @param organization Donor
         * @return RequestBody This request body instance
         */
        public RequestBody withDonor(Account organization) {
            if (organization == null) {
                return this;
            }

            this.firstName = trimNameField(organization.Name);
            this.lastName = trimNameField(organization.Name);

            return this;
        }

        /**
         * @description Return max number of character allowed for the first/last name in Elevate
         * @param name First or Last Name
         * @return String
         */
        private String trimNameField(String name) {
            return String.isBlank(name) ? name : name.abbreviate(MAX_NAME_LENGTH);
        }

        /**
         * @description Sets schedules data
         * @param schedules Payments API schedules
         * @return RequestBody This request body instance
         */
        public RequestBody withSchedules(List<Schedule> schedules) {
            this.schedules = schedules;
            return this;
        }

        /**
         * @description Sets product metadata
         * @param productMetadata Payments API product metadata
         * @return RequestBody This request body instance
         */
        public RequestBody withProductMetadata(Map<String, Object> productMetadata) {
            this.productMetadata = productMetadata;
            this.productMetadataSchemaUri = PS_Request.PRODUCT_METADATA_SCHEMA_URI;
            return this;
        }

        /**
         * @description Returns this request body as a JSON string
         * @return String
         */
        public String getAsJson() {
            return JSON.serialize(this);
        }

        public Boolean isACH() {
            return this.paymentMethodType == ElevatePaymentMethod.ACH.name();
        }

        /**
         * @description Returns true if this request has a Commitment Id
         * @return Boolean
         */
        public Boolean isCommitmentUpdate() {
            return this.id != null;
        }
    }

    /***
     * @description Contains Recurring Donation Schedule info to be relayed to the Elevate API
     */
    public class Schedule {
        public Integer amount;
        public String frequency;
        public Integer frequencyInterval;
        public String firstOccurrenceOnTimestamp;
        public String operation;

        /**
         * @description Default Schedule constructor
         * @param rdSchedule Recurring Donation Schedule
         * @param currencyMultiplier Currency multiplier
         */
        public Schedule(RecurringDonationSchedule__c rdSchedule, Integer currencyMultiplier){
            this(rdSchedule, currencyMultiplier, false);
        }

        /**
         * @description Schedule constructor for Update requests
         * @param rdSchedule Recurring Donation Schedule
         * @param currencyMultiplier Currency multiplier
         * @param isUpdate True if this Request has a Commitment Id
         */
        public Schedule(RecurringDonationSchedule__c rdSchedule, Integer currencyMultiplier, Boolean isUpdate) {
            Double amount = rdSchedule.InstallmentAmount__c * currencyMultiplier;
            this.amount = amount == null ? null : Integer.valueOf(amount);

            this.frequency = frequencyByInstallmentPeriod.get(rdSchedule.InstallmentPeriod__c);
            this.frequencyInterval = rdSchedule.InstallmentFrequency__c == null
                ? null
                : Integer.valueOf(rdSchedule.InstallmentFrequency__c);

            this.firstOccurrenceOnTimestamp = getNextDonationDate(rdSchedule, isUpdate);

            this.operation = 'CREATE';
        }

        /***
         * @description Determins the first payment date based on the provided schedule
         * @param rdSchedule Recurring Donation Schedule
         * @return String ISO8601 date-time string
         */
        private String getNextDonationDate(RecurringDonationSchedule__c rdSchedule, Boolean isUpdate) {

            Date earliestDonationDate = RD2_ScheduleService.currentDate;
            // If this is an update, don't use current Date
            if(isUpdate){
                earliestDonationDate = earliestDonationDate.addDays(1);
            }

            Date donationDate = new RD2_ScheduleService()
                .getNextDonationDateGreaterThan(rdSchedule, earliestDonationDate);

            Datetime donationDatetime = donationDate == Datetime.now().date()
                ? Datetime.now()
                : Datetime.newInstance(donationDate.year(), donationDate.month(), donationDate.day());
            
            return donationDatetime.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        }
    }

    /**
     * @description Contains Elevate recurring commitment data in the response body
     */
    public class ResponseBody {
        public String id;
        public String status;
        public String statusReason;
        public CardData cardData;

        /**
         * @description Returns true if the commitment data has the id specified
         * @return Boolean
         */
        public Boolean hasId() {
            return String.isNotBlank(id);
        }

        /**
         * @description Returns true if the commitment has new or active status
         * @return Boolean
         */
        public Boolean isActive() {
            return status == STATUS_NEW || status == STATUS_ACTIVE;
        }

        /**
         * @description Returns true if the commitment has just been created
         * @return Boolean
         */
        public Boolean isCreated() {
            return isActive()
                && statusReason == CommitmentStatusReason.COMMITMENT_CREATED.name();
        }

        /**
         * @description Returns true if the commitment credit card data has been returned
         * @return Boolean
         */
        public Boolean hasCardData() {
            return cardData != null;
        }

        /**
         * @description Returns credit card last 4 digits
         * @return String
         */
        public String getCardLast4() {
            return hasCardData() ? cardData.last4 : null;
        }

        /**
         * @description Returns credit card expiration month
         * @return String
         */
        public String getCardExpirationMonth() {
            return hasCardData() ? cardData.expirationMonth : null;
        }

        /**
         * @description Returns credit card expiration year
         * @return String
         */
        public String getCardExpirationYear() {
            return hasCardData() ? cardData.expirationYear : null;
        }
    }

    /**
     * @description Contains credit card data on the commitment
     */
    public class CardData {
        public String last4;
        public String expirationMonth;
        public String expirationYear;
    }

    /***
    * @description Product metadata property on the commitment request
    */
    public class ProductMetadata {
        public Origin origin;
        public Campaign campaign;

        /**
        * @description Sets origin info
        * @param type origin type
        * @return productMetadata This product metadata instance
        */
        public ProductMetadata withOrigin(String type) {
            this.origin = new Origin(type);
            return this;
        }

        /**
        * @description Sets campaign info
        * @param campaignId campaign Id
        * @return productMetadata This product metadata instance
        */
        public ProductMetadata withCampaign(Id campaignId) {
            if (campaignId != null) {
                this.campaign = new Campaign(campaignId);
            }

            return this;
        }

        private Boolean hasCampaign() {
            return this.campaign?.id != null;
        }

        private Boolean hasOrigin() {
            return this.origin?.type != null;
        }

        public Map<String, Object> mergeWithExistingMetadata(Map<String, Object> existingMetadata) {
            Map<String, Object> updatedMetadata = this.toUntypedMap();

            for(String key : updatedMetadata.keySet()) {
                existingMetadata.put(key, updatedMetadata.get(key));
            }

            return existingMetadata;
        }

        public Map<String, Object> toUntypedMap() {
            Map<String, Object> productMetadataMap = new Map<String, Object>();

            if (hasOrigin()) {
                productMetadataMap.put('origin', this.origin);
            }

            if (hasCampaign()) {
                productMetadataMap.put('campaign', this.campaign);
            }

            return productMetadataMap;
        }
    }

    /***
    * @description Origin property on the commitment product metadata request
    */
    public class Origin {
        public String type;

        public Origin(String type) {
            this.type = type;
        }
    }

    /***
    * @description Campaign property on the commitment product metadata request
    */
    public class Campaign {
        public String id;

        public Campaign(Id campaignId) {
            this.id = campaignId;
        }
    }
}
