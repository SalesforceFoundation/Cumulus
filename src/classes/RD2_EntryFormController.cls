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
* @description Enhanced Recurring Donations Entry Form LWC Controller Class
*
*/
public with sharing class RD2_EntryFormController {

    /**
    * @description Set of fields that will be excluded from the RD2_EntryForm Custom Field Section
    */
    @TestVisible
    private static Set<String> excludedCustomFields = new Set<String> {
        'CreatedById',
        'CreatedDate',
        'CurrencyIsoCode',
        'Id',
        'IsDeleted',
        'LastModifiedById',
        'LastModifiedDate',
        'LastReferencedDate',
        'LastViewedDate',
        'Name',
        'OwnerId',
        'SystemModStamp'
    };

    /**
    * @description Handles commitment request creation, response parsing and RD Commitment Id update
    */
    private static CommitmentService commitmentService {
        get {
            if (commitmentService == null) {
                commitmentService = new CommitmentService();
            }
            return commitmentService;
        }
        set;
    }

    /**
    * @description  Gather the org, object and environment setting for Recurring Donation Entry/Edit Form
    * @param parentId The parentId of the new RD
    * @return Map<String, Object>
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRecurringSettings(Id parentId) {
        String parentSObjectType = (parentId == null)
            ? null
            : parentId.getSobjectType().getDescribe().getName();

        return new Map<String, Object> {
            'isAutoNamingEnabled' => RD2_NamingService.isAutomaticNamingEnabled,
            'isMultiCurrencyEnabled' => UserInfo.isMultiCurrencyOrganization(),
            'parentSObjectType' => parentSObjectType,
            'InstallmentPeriodPermissions' => getFieldPermissionsMap('npe03__Installment_Period__c'),
            'InstallmentFrequencyPermissions' => getFieldPermissionsMap(UTIL_Namespace.StrTokenNSPrefix('InstallmentFrequency__c')),
            'customFieldSets' => getCustomFieldSectionFields(),
            'isElevateCustomer' => RD2_ElevateIntegrationService.isIntegrationEnabled()
        };
    }

    /**
    * @description Retrieve the donor type for an existing RD record
    * @param recordId RecurringDonation.RecordId
    * @return Map<String, Object> of specific type of RD data
    */
    @AuraEnabled
    public static Map<String, Object> getRecurringData(String recordId) {
        if (recordId == null) {
            return null;
        }

        npe03__Recurring_Donation__c rd;
        Map<String, Object> response = new Map<String, Object>();
        try {
            rd = getRecurringDonation(recordId);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        if (rd.npe03__Organization__r.RecordTypeId == hhRecordTypeId
            || (rd.npe03__Organization__c == null && rd.npe03__Contact__r.Account.RecordTypeId == hhRecordTypeId)
        ) {
            response.put('DonorType', 'Contact');
        } else {
            response.put('DonorType', 'Account');
        }

        response.put('Period', rd.npe03__Installment_Period__c);
        response.put('Frequency', rd.InstallmentFrequency__c);
        response.put('RecurringType', rd.RecurringType__c);
        response.put('NumInstallments', rd.npe03__Installments__c);

        return response;
    }

    /**
     * @description Validate that the current user has Read access to a specific set of required fields. If this returns
     * false, the custom UI will display a warning message at the top of the page.
     * @return True if the User has Read access to all required fields in the UI
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasRequiredFieldPermissions() {
        Set<String> requiredFields = new Set<String>{
            'npe03__Amount__c',
            'npe03__Contact__c',
            'npe03__Installment_Period__c',
            'npe03__Date_Established__c',
            UTIL_Namespace.StrTokenNSPrefix('InstallmentFrequency__c'),
            UTIL_Namespace.StrTokenNSPrefix('Day_of_Month__c'),
            UTIL_Namespace.StrTokenNSPrefix('StartDate__c')
        };

        Boolean hasPermissions = true;

        for (String fld : requiredFields) {
            DescribeFieldResult dfr = UTIL_Describe.getFieldDescribe('npe03__Recurring_Donation__c', fld);
            if (!dfr.isAccessible()) {
                hasPermissions = false;
                break;
            }
        }

        return hasPermissions;
    }

    /**
    * @param recordId RecurringDonation.RecordId
    * @return Recurring Donation object
    */
    private static npe03__Recurring_Donation__c getRecurringDonation(Id recordId) {
        Set<String> queryFields = new Set<String>{
            'Id',
            'RecurringType__c',
            'npe03__Installment_Period__c',
            'InstallmentFrequency__c',
            'npe03__Organization__c',
            'npe03__Organization__r.RecordTypeId',
            'npe03__Contact__r.Account.RecordTypeId',
            'npe03__Installments__c'
        };

        String soql = new UTIL_Query()
            .withFrom(npe03__Recurring_Donation__c.SObjectType)
            .withSelectFields(queryFields)
            .withWhere('Id = :recordId')
            .withLimit(1)
            .build();

        return Database.query(soql);
    }

    /***
    * @description Retrieves the record type id for the household account record type
    */
    @TestVisible
    private static String hhRecordTypeId {
        get {
            if (hhRecordTypeId == null) {
                hhRecordTypeId = UTIL_CustomSettingsFacade.getContactsSettings().npe01__HH_Account_RecordTypeID__c;
            }
            return hhRecordTypeId;
        }
        private set;
    }

    /**
     * @description Build a map of field permissions for use by LWC so it can validate access permission
     * for custom picklist fields without a return trip to server. Fields using lightning-input-field do not
     * require this additional check.
     * @param fieldApiName Field ApiName
     * @return Map<String, Object> of field permissions
     */
    private static Map<String, Boolean> getFieldPermissionsMap(String fieldApiName) {
        DescribeFieldResult dfr = UTIL_Describe.getFieldDescribe('npe03__Recurring_Donation__c', fieldApiName);
        return new Map<String, Boolean>{
            'Createable' => dfr.isCreateable(),
            'Updateable' => dfr.isUpdateable(),
            'Visible' => dfr.isAccessible()
        };
    }

    /***
    * @description Retrieve RD2_Entry_Form_Custom_Fields Fieldset and eliminate any packaged and already displayed fields
    * @return List<CustomField>
    */
    @TestVisible
    private static List<CustomField> getCustomFieldSectionFields() {
        List<CustomField> fields = new List<CustomField>();
        List<Schema.FieldSetMember> fieldSetFields = Schema.SObjectType.npe03__Recurring_Donation__c.fieldSets.RD2_Entry_Form_Custom_Fields.getFields();

        for (Schema.FieldSetMember field : fieldSetFields) {
            if (excludedCustomFields.contains(field.getFieldPath())
                || field.getFieldPath().startsWith('npsp__')
                || field.getFieldPath().startsWith('npe03__')
                || !UTIL_Describe.getFieldDescribe('npe03__Recurring_Donation__c', field.getFieldPath()).isAccessible()
            ) {
                continue;
            }

            fields.add(new CustomField(field));
        }

        return fields;
    }

    /***
    * @description Wrapper class for custom field info
    */
    public class CustomField {
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean required;

        /***
        * @description Constructor for the CustomField class
        * @param apiName Api name of the field
        * @param required Indicate if the field is required
        */
        public CustomField(Schema.FieldSetMember field) {
            this.apiName = field.getFieldPath();
            this.required = field.getDbRequired() || field.getRequired();
        }
    }

    /***
    * @description Constructs a Recurring Donation record based on the entry form fields, and
    * submits the create or edit commitment request to the Elevate Payments API.
    * @param jsonRecord Recurring Donation fields as entered by the user before the record is saved
    * @param paymentMethodToken Payment Method Token
    * @return String Commitment API response
    */
    @AuraEnabled
    public static String handleCommitment(String jsonRecord, String paymentMethodToken) {
        try {
            npe03__Recurring_Donation__c rd =  (npe03__Recurring_Donation__c) JSON.deserialize(
                jsonRecord, npe03__Recurring_Donation__c.class
            );

            npe03__Recurring_Donation__c oldRd = getOldRecurringDonation(rd.Id);

            commitmentService.adjustAndValidateRD(rd, oldRd);
            UTIL_Http.Response response = commitmentService.handleCommitment(rd, oldRd, paymentMethodToken);

            return JSON.serialize(response);

        } catch (Exception ex) {
            UTIL_AuraEnabledCommon.throwAuraHandledException(ex.getMessage());
        }

        return null;
    }

    /***
    * @description Constructs a Recurring Donation record based on the json record, and
    * submits the update payment commitment request to the Elevate Payments API.
    * @param jsonRecord Recurring Donation fields as entered by the user before the record is saved
    * @param paymentMethodToken Payment Method Token
    * @return String Commitment API response
    */
    @AuraEnabled
    public static String handleUpdatePaymentCommitment(String jsonRecord, String paymentMethodToken) {
        try {
            npe03__Recurring_Donation__c rd =  (npe03__Recurring_Donation__c) JSON.deserialize(
                jsonRecord, npe03__Recurring_Donation__c.class
            );

            UTIL_Http.Response response = commitmentService.handleCommitment(rd, null, paymentMethodToken);

            return JSON.serialize(response);

        } catch (Exception ex) {
            UTIL_AuraEnabledCommon.throwAuraHandledException(ex.getMessage());
        }

        return null;
    }

    /***
    * @description Logs an error when a Recurring Donation cannot be created/updated
    * @param recordId A Recurring Donation, or a donor (Contact/Account) Id
    * @param errorMessage An error message
    */
    @AuraEnabled
    public static void logError(Id recordId, String errorMessage) {
        commitmentService.logError(recordId, errorMessage);
    }


    /**
    * @description Retrives Recurring Donation from database
    * @param recordId Recurring Donation Id
    * @return npe03__Recurring_Donation__c
    */
    private static npe03__Recurring_Donation__c getOldRecurringDonation(Id recordId) {
        npe03__Recurring_Donation__c oldRd = null;

        if (recordId != null) {
            List<npe03__Recurring_Donation__c> oldRds = new RD2_QueryService().getRecurringDonationsBase(new Set<Id>{ recordId });
            if (oldRds != null && !oldRds.isEmpty()) {
                oldRd = oldRds[0];
            }
        }

        return oldRd;
    }

    /**
    * @description Handles sending commitment create and edit requests
    */
    public without sharing class CommitmentService {

        /**
        * @description Sends commitment create/update requests, and constructs a response
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

        /**
        * Used to adjust and validate Recurring Donation data 
        */
        private RD2_DataRegulationService dataService {
            get {
                if (dataService == null) {
                    dataService = new RD2_DataRegulationService();
                }
                return dataService;
            }
            set;
        }

        /**
        * @description Handles validation and Elevate recurring commitment creation
        * @param rd Recurring Donation
        * @param oldRd oldRecurring Donation
        * @param paymentMethodToken Payment Method Token
        * @return UTIL_Http.Response Payments API response
        */
        public UTIL_Http.Response handleCommitment(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd, String paymentMethodToken) {
            UTIL_Http.Response response;

            if (shouldSendToElevate(rd, oldRd, paymentMethodToken)) {
                PS_CommitmentRequest.RequestBody requestBody = new PS_CommitmentRequest().getRequestBody(rd, oldRd, paymentMethodToken);

                response = sendRequest(rd.CommitmentId__c, JSON.serialize(requestBody));

                processResponse(rd, response);
            }

            return response;
        }

        /**
        * @description Constructs Recurring Donation record from received fields specified in the JSON string,
        * updates defaults that are otherwise updated in the trigger context, and
        * validates user entered values for a new or existing RD record.
        * @param rd Modified Recurring Donation record that is not created/updated in DB yet
        * @param oldRd oldRecurring Donation
        * @return void
        */
        private void adjustAndValidateRD(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd) {
            // Populate defaults otherwise applied by the DML operation and available in the trigger context
            if (String.isBlank(rd.Status__c)) {
                rd.Status__c = UTIL_Describe.getDefaultSelectOption(
                    'npe03__Recurring_Donation__c', String.valueOf(npe03__Recurring_Donation__c.Status__c)
                );
            }

            List<npe03__Recurring_Donation__c> newRds = new List<npe03__Recurring_Donation__c>{rd};
            List<npe03__Recurring_Donation__c> oldRds = new List<npe03__Recurring_Donation__c>();
            if (rd.Id != null) {
                oldRds.add(oldRd);
            }

            RD2_DataRegulationService regulationService = new RD2_DataRegulationService();
            regulationService.adjust(newRds, oldRds);
            regulationService.markRDsAsElevate(newRds);
            
            List<RD2_ValidationService.ErrorRecord> errorRds = new RD2_ValidationService(newRds, oldRds)
                .validate();

            regulationService.removeElevateMarker(newRds);
            
            if (!errorRds.isEmpty()) {
                UTIL_AuraEnabledCommon.throwAuraHandledException(
                    errorRds[0].getFirstError()
                );
            }
        }

        /**
        * @description Checks if the commitment record should be sent to Elevate
        * @param rd Recurring Donation record
        * @param oldRd oldRecurring Donation
        * @return Boolean
        */
        private Boolean shouldSendToElevate(npe03__Recurring_Donation__c rd, npe03__Recurring_Donation__c oldRd, String paymentMethodToken) {
            if(new RD2_RecurringDonation(rd).isClosed()) {
                return false;
            }
            PS_CommitmentRequest request = new PS_CommitmentRequest();
            Boolean isElevatedFieldsChanged = request.isElevateScheduleFieldsChanged(rd, oldRd)
                || request.isElevateCampaignChanged(rd, oldRd);


            return rd.Id == null
                || (isElevatedFieldsChanged && rd.CommitmentId__c != null)
                || String.isNotBlank(paymentMethodToken);
        }

        /**
        * @description Sends commitment request to Elevate
        * @param commitmentId Elevate recurring commitment Id
        * @param jsonRequestBody Payment API request in JSON format
        * @return response Payments API response
        */
        private UTIL_Http.Response sendRequest(String commitmentId, String jsonRequestBody) {
            UTIL_Http.Response response;

            try {
                HttpRequest request = PS_CommitmentRequest.buildRequest(commitmentId, jsonRequestBody);

                response = requestService.sendRequest(request);

            } catch (Exception ex) {
                response = requestService.buildErrorResponse(ex);
            }

            return response;
        }

        /**
        * @description Logs an error record on an commitment error response
        * @param rd Recurring Donation record
        * @param response Payments API response
        * @return void
        */
        private void processResponse(npe03__Recurring_Donation__c rd, UTIL_Http.Response response) {
            if (isCommitmentSuccess(response)) {
                return;
            }

            Id recordId = rd.Id != null
                ? rd.Id
                : rd.npe03__Contact__c != null
                    ? rd.npe03__Contact__c
                    : rd.npe03__Organization__c;

            logError(recordId, response.getErrorMessages());
        }

        /**
        * @description Determines if the commitment has been created or updated successfully
        * @param response Payments API response
        * @return Boolean
        */
        private Boolean isCommitmentSuccess(UTIL_Http.Response response) {
            return response.statusCode == UTIL_Http.STATUS_CODE_CREATED
                || response.statusCode == UTIL_Http.STATUS_CODE_OK;
        }

        /**
        * @description Creates an error record for the specified record Id and error message
        * @param recordId A Recurring Donation or a donor (Contact/Account) Id
        * @param errorMessage Error message
        * @return void
        */
        public void logError(Id recordId, String errorMessage) {
            ERR_LogService.Logger logger = new ERR_LogService.Logger(
                ERR_Handler_API.Context.Elevate,
                npe03__Recurring_Donation__c.SObjectType
            );

            String errorType = (recordId.getSobjectType() == Schema.npe03__Recurring_Donation__c.getSObjectType())
                ? RD2_ElevateIntegrationService.LOG_TYPE_COMMITMENT_EDIT
                : RD2_ElevateIntegrationService.LOG_TYPE_COMMITMENT_CREATE;

            logger.addError(recordId, errorMessage, errorType);

            logger.processErrors();
        }
    }

}
