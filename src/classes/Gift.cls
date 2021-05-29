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
* @description Gift entity class in NPSP.
*/

public with sharing class Gift {
    // from ElevateAuthorizedGift
    @AuraEnabled public ElevateTokenizedGift tokenizedGift;
    @AuraEnabled public String paymentId;
    @AuraEnabled public DateTime authExpiration;
    @AuraEnabled public String status;
    @AuraEnabled public String paymentMethod;
    @AuraEnabled public String originalTransactionId;
    @AuraEnabled public String groupId;
    @AuraEnabled public String declineReason;
    @AuraEnabled public String cardLast4;
    @AuraEnabled public String cardNetwork;
    @AuraEnabled public String cardExpirationMonth;
    @AuraEnabled public String cardExpirationYear;
    @AuraEnabled public DateTime authorizedAt;
    @AuraEnabled public String gatewayTransactionId;
    @AuraEnabled public String gatewayId;

    // From ElevateTokenizedGift
    @AuraEnabled public Decimal amount {get; set;}
    @AuraEnabled public String firstName {get; set;}
    @AuraEnabled public String paymentMethodToken {get; set;}
    public String merchantId;
    @AuraEnabled public String lastName {get; set;}
    @AuraEnabled public String currencyCode {get; set;}
    public PS_IntegrationServiceConfig.Service configService;

    @TestVisible
    private DataImport__c dataImport;
    private List<String> availableFields;
    private GiftSelector giftSelector {
        get {
            if (giftSelector == null) {
                giftSelector = new GiftSelector();
            }
            return giftSelector;
        }
        set;
    }
    
    public Gift() {
        this.currencyCode = UserInfo.getDefaultCurrency();
        setConfigServiceInstance();
        setGatewayId();
        setMerchantId();        
    }

    public Gift(DataImport__c dataImport) {
        this();
        this.dataImport = dataImport;
        this.populateAvailableFields();
    }

    public Gift(Gift tokenizedGift, ElevateAuthorizedGiftResponse authorizedGiftResponse) {

        //this.tokenizedGift = tokenizedGift;
        this.amount = tokenizedGift.amount;
        this.firstName = tokenizedGift.firstName;
        this.paymentMethodToken = tokenizedGift.paymentMethodToken;
        this.merchantId = tokenizedGift.merchantId;
        this.lastName = tokenizedGift.lastName;
        this.currencyCode = tokenizedGift.currencyCode;
        this.configServie = tokenizedGift.configService;

        this.paymentId = authorizedGiftResponse.id();
        this.authExpiration = authorizedGiftResponse.authExpiration();
        this.status = authorizedGiftResponse.status().name();
        this.gatewayTransactionId = authorizedGiftResponse.gatewayTransactionId();
        this.paymentMethod = authorizedGiftResponse.paymentMethod();
        this.groupId = authorizedGiftResponse.groupId();
        this.originalTransactionId = authorizedGiftResponse.originalTransactionId();
        this.declineReason = authorizedGiftResponse.declineReason();
        this.cardLast4 = authorizedGiftResponse.last4();
        this.cardNetwork = authorizedGiftResponse.brand();
        this.cardExpirationMonth = authorizedGiftResponse.expirationMonth();
        this.cardExpirationYear = authorizedGiftResponse.expirationYear();
        this.authorizedAt = authorizedGiftResponse.authorizedAt();
        this.gatewayId = authorizedGiftResponse.gatewayId();
        this.gatewayTransactionId = authorizedGiftResponse.gatewayTransactionId();
    }
    
    public Boolean isTokenized() {
        return paymentMethodToken != null;
    }

    public Boolean isAuthorized() {
        return status == ElevateTransactionStatus.AUTHORIZED.name();
    }

    public Boolean requiresReauthorizationBeforeChange() {
        if (dataImport.Payment_Status__c != ElevateTransactionStatus.AUTHORIZED.name()) { 
            return false; 
        }

        return this.hasPaymentFieldsChanged();
    }

    private void populateAvailableFields() {
        Map<String, Object> dataImportFields = this.dataImport.getPopulatedFieldsAsMap();
        List<String> fields = new List<String>();

        for (String field : dataImportFields.keySet()) {
            if (GiftBatchService.PAYMENT_INTEGRATION_FIELDS.contains(field)) {
                fields.add(field);
            }
        }

        this.availableFields = fields;
    }

    private Boolean hasPaymentFieldsChanged() {
        DataImport__c databaseDataImport = giftSelector.getGiftById(this.dataImport.Id, this.availableFields);

        for (String field : this.availableFields) {
            if (this.dataImport.get(field) != databaseDataImport.get(field)) {
                return true;
            }
        }

        return false;
    }

    private void setMerchantId() {
        if (String.isBlank(merchantId)) {
            merchantId = configService.getMerchantIds();
        }
    }

    private void setGatewayId() {
        if (String.isBlank(gatewayId)) {
            gatewayId = configService.getGatewayIds();
        }
    }

    private void setConfigServiceInstance() {
        configService = new PS_IntegrationServiceConfig.Service();
    }

    public virtual Decimal amount() {
        return amount;
    }

    public virtual String firstName() {
        return firstName;
    }

    public String lastName() {
        return lastName;
    }

    public String currencyCode() {
        return currencyCode;
    }

    public String gatewayId() {
        return gatewayId;
    }

    public String merchantId() {
        return merchantId;
    }

    public String token() {
        return paymentMethodToken;
    }

    public String groupId() {
        return groupId;
    }

    public String gatewayId() {
        return gatewayId;
    }

    public String gatewayTransactionId() {
        return gatewayTransactionId;
    }

    public DateTime authorizedAt() {
        return authorizedAt;
    }

    public String cardLast4() {
        return cardLast4;
    }

    public String cardNetwork() {
        return cardNetwork;
    }

    public String cardExpirationMonth() {
        return cardExpirationMonth;
    }

    public String cardExpirationYear() {
        return cardExpirationYear;
    }

    public String paymentId() {
        return paymentId;
    }

    public DateTime authExpiration() {
        return authExpiration;
    }

    public String status() {
        return status;
    }

    public String paymentMethod() {
        return paymentMethod;
    }

    public String originalTransactionId() {
        return originalTransactionId;
    }

    public String declineReason() {
        return declineReason;
    }    
}
