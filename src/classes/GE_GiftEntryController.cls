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
* @group HGE
* @group-content
* @description Controller for the Gift Entry lightning web components and processing
* form save.
*/
public with sharing class GE_GiftEntryController {

    public static final String PURCHASE_CALL_TIMEOUT_MESSAGE = System.Label.geErrorRequestTimedout;
    private static final String BOOLEAN_DATA_TYPE = 'BOOLEAN';
    private static GiftBatchService giftBatchService = new GiftBatchService();

    @AuraEnabled
    public static Map<String, Integer> getGiftBatchTotalsBy(String batchId) {
        return giftBatchService.getGiftBatchTotalsMapFor((Id) batchId);
    }

    /*******************************************************************************************************
    * @description Indicates if the org is connected to Elevate
    * @return Boolean
    */
    @AuraEnabled(cacheable=true)
    public static Boolean isElevateCustomer() {
        try {
            return new GE_PaymentServices().isElevateCustomer();
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Creates and posts an elevate purchase request
    *
    * @param requestBodyParameters: JSON containing parameters for the purchase call request body
    * @param dataImportRecordId: Record ID of the related Data Import
    *
    * @return String: http response wrapper
    */
    @AuraEnabled
    public static String sendPurchaseRequest(String requestBodyParameters, String dataImportRecordId) {
        UTIL_Http.Response response = processPurchaseRequest(requestBodyParameters, dataImportRecordId);

        return response.body;
    }

    /***
    * @description Sends the purchase request to Elevate and logs an error on a timeout error.
    * This method is used in tests instead of the sendPurchaseRequest() in order to skip JSON.deserialize(response)
    * due to it erroring out because the response header contains the Object data type.
    * @param requestBodyParameters: JSON containing parameters for the purchase call request body
    * @param dataImportRecordId: Record ID of the related Data Import
    * @return UTIL_Http.Response
    */
    @TestVisible
    private static UTIL_Http.Response processPurchaseRequest(String requestBodyParameters, String dataImportRecordId) {
        UTIL_Http.Response response = new UTIL_Http.Response();

        try {
            GE_PaymentServices paymentServices = new GE_PaymentServices();
            response = paymentServices.createTransaction(requestBodyParameters);

            if (response.statusCode == UTIL_Http.STATUS_CODE_REQUEST_TIMEOUT) {
                processPurchaseTimeoutResponse(response, dataImportRecordId);
            }            

        } catch (Exception ex) {
            String JSONExceptionData = ERR_ExceptionData.createExceptionWrapperJSONString(ex);
            throw buildDmlException(JSONExceptionData);
        } 

        return response;
    }

    /*******************************************************************************************************
    * @description Updates the timeout response so it can be read by the GE forms.
    * The status code stays the same (408), however the status is changed to contain the error message
    * and the response body is changed to contain a generic GE request timed out message.
    * @param response: timeout response
    * @param dataImportRecordId: Record ID of the related Data Import to include in our error logs
    * @return void
    */
    private static void processPurchaseTimeoutResponse(UTIL_Http.Response response, String dataImportRecordId) {   
        response.body = JSON.serialize(new Map<String, String> {
            'message' => PURCHASE_CALL_TIMEOUT_MESSAGE,
            'statusCode' => String.valueOf(response.statusCode),
            'status' => response.getErrorMessages()
        });
        logTimeoutError(dataImportRecordId);
    }

    /*******************************************************************************************************
    * @description Logs an error when the purchase request timed out
    * @param dataImportRecordId: Record ID of the related Data Import to include in our error logs
    * @return void
    */
    private static void logTimeoutError(String dataImportRecordId) {
        String objectAndRecordId = String.format(
            System.Label.stgErrorInvalidNameFormat,
            new String[] {
                Schema.SObjectType.DataImport__c.getLabel(),
                dataImportRecordId
            }
        );

        String errorMsg = PURCHASE_CALL_TIMEOUT_MESSAGE + ' ' + objectAndRecordId;
        BDIException ex = new BDIException(errorMsg);
        ex.setMessage(errorMsg);

        ERR_Handler.processError(ex, ERR_Handler_API.Context.GE);
    }

    // TODO elevateBatchId should come from ElevateBatchService, not front end
    @AuraEnabled
    public static Gift stageGift(Gift tokenizedGift, String elevateBatchId) {
        Gift authorizedGift;
        if( tokenizedGift.isTokenized() ) {
            try {
                authorizedGift = elevateBatchService.addToElevateBatch(tokenizedGift, elevateBatchId);
            } catch (AuraHandledException ex) {
                UTIL_AuraEnabledCommon.throwAuraHandledException(ex.getMessage());
            }
            return authorizedGift;
        }
        return tokenizedGift;
    }

    @AuraEnabled
    public static ElevateBatch createElevateBatch() {
        ElevateBatch elevateBatch = elevateBatchService.createElevateBatch();
        return elevateBatch;
    }

    /*******************************************************************************************************
    * @description Creates an DmlException with the specified error message
    *
    * @param errorMsg contents of the exception error message
    *
    * @return DmlException
    */
    private static DmlException buildDmlException(String errorMsg) {
        DmlException ex = new DmlException(errorMsg);
        ex.setMessage(errorMsg);
        return ex;
    }

    /*******************************************************************************************************
    * @description Saves the data import record, dry runs the record, and returns updated
    * totals with the new row.
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @param dataImport: the NPSP_Data_Import__c record to update
    * @return String serialized DataImportModel
    */
    @AuraEnabled
    public static String saveAndDryRunDataImport(Id batchId, DataImport__c dataImport) {

        try {
            if (!areCurrenciesValid(batchId)) {
                return null;
            }

            dataImport.Additional_Object_JSON__c =
                convertWidgetDataToObjectJSON(dataImport.Additional_Object_JSON__c);

            upsertDataImport(dataImport);
            return BGE_DataImportBatchEntry_CTRL.runSingleDryRun(dataImport.Id, batchId);

        } catch (Exception ex) {
            // create custom lwc exception and throw it
            String JSONExceptionData = ERR_ExceptionData.createExceptionWrapperJSONString(ex);

            throw buildDmlException(JSONExceptionData);
        }
    }

    @AuraEnabled
    public static void validateAuthorizedGiftEdit(DataImport__c dataImport){
        Gift editedGift = new Gift(dataImport);
        if (editedGift.requiresReauthorizationBeforeChange()) { 
            throw new AuraHandledException(Label.geErrorBatchGiftEntryReauthRequired);
        }
    }

    @AuraEnabled
    public static void processPaymentsFor(Id batchId) {
       try {
           NPSP_Batch batch = new NPSP_Batch(batchId);
           batch.processPayments();
       } catch (Exception ex) {
          throw new AuraHandledException(ex.getMessage());
       }
    }

    /**
     * @description Validates that the currency of a batch matches the currently logged in
     * user's currency
     * @param batchId : ID of the NPSP_Data_Import_Batch__c
     */
    private static Boolean areCurrenciesValid (Id batchId) {
        if (!UserInfo.isMultiCurrencyOrganization()) {
            return true;
        }

        String batchCurrencyIsoCode = retrieveBatchCurrencyIsoCode(batchId);

        if (batchCurrencyIsoCode != null && batchCurrencyIsoCode == UserInfo.getDefaultCurrency()) {
            return true;
        }
        throw new CurrencyMismatchException(String.format(
            System.Label.geErrorBatchGiftEntryCurrencyMismatch, new List<String>{batchCurrencyIsoCode}
        ));
    }

    /*******************************************************************************************************
    * @description Saves the data import record, dry runs the record, and returns updated
    * totals with the new row.
    * @param dataImport: the NPSP_Data_Import__c record to update
    * @param updateGift: If true, BDI will attempt to match to an existing opportunity/payment
    * @return String serialized DataImportModel
    */
    @AuraEnabled
    public static Id submitDataImportToBDI(DataImport__c dataImport, Boolean updateGift) {
        dataImport.Additional_Object_JSON__c =
                convertWidgetDataToObjectJSON(dataImport.Additional_Object_JSON__c);

        // Run the BDI process on this new Data Import
        processDataImport(dataImport, false, updateGift);

        // Get the ID of the created Opportunity so we can return it
        Id oppId = getOpportunityIdFromImport(dataImport.Id);

        return oppId;
    }

    /*******************************************************************************************************
    * @description Set DataImport Settings that are important to Gift Entry matching
    * @return Data_Import_Settings__c diSettings object used to process gifts
    */
    private static Data_Import_Settings__c getGiftEntrySettingsWithUpdateGiftFlag(Boolean updateGift) {
        Data_Import_Settings__c diSettings = Data_Import_Settings__c.getOrgDefaults();
        // If we are updating an existing gift, set the matching logic accordingly
        diSettings.Donation_Matching_Behavior__c =
            updateGift ? BDI_DataImport_API.ExactMatchOrCreate : BDI_DataImport_API.DoNotMatch;
        return diSettings;
    }

    /*******************************************************************************************************
    * @description Takes a Data Import record and saves it to the database. If the id is already defined
    * update the record; otherwise, insert it.
    *
    * @param dataImport - The DataImport__c record, as filled in by the user.
    * @return The DataImport__c record that was saved
    */
    @AuraEnabled
    public static DataImport__c upsertDataImport(DataImport__c dataImport) {
        try {
            upsert dataImport Id;

            return dataImport;
        } catch (Exception e) {
            String JSONExceptionData = ERR_ExceptionData.createExceptionWrapperJSONString(e);

            throw buildDmlException(JSONExceptionData);
        }
    }

    /*******************************************************************************************************
    * @description Run the DataImport process on a single gift
    * @param dataImport DataImport record to be processed
    * @param isDryRun Boolean to set if the process should only return import results and not process
    * @param updateGift Boolean to determine our matching criteria.
    *                   true = "single match or create" and means we are updating
    *                   false = "do not match"
    */
    private static void processDataImport(DataImport__c dataImport, Boolean isDryRun, Boolean updateGift) {
        try {

            Data_Import_Settings__c diSettings = getGiftEntrySettingsWithUpdateGiftFlag(updateGift);

            List<DataImport__c> listDI = new List<DataImport__c>{dataImport};

            BDI_DataImport_API.processDataImportRecords(diSettings, listDI, isDryRun);
        } catch (Exception e) {
            String JSONExceptionData = ERR_ExceptionData.createExceptionWrapperJSONString(e);

            throw buildDmlException(JSONExceptionData);
        }
    }

    /*******************************************************************************************************
    * @description Return the imported Opportunity (Donation) from a DataImport process
    * @param dataImportId Id of DataImport object that created or matching this Opportunity
    * @return Id of the Opportunity
    */
    private static String getOpportunityIdFromImport(Id dataImportId) {
        try {
            DataImport__c di = [
                    SELECT DonationImported__c,
                            FailureInformation__c
                    FROM DataImport__c
                    WHERE Id = :dataImportId
            ];
            if(di.FailureInformation__c != null) {
                throw new BDIException(di.FailureInformation__c);
            }
            return di.DonationImported__c;
        } catch(Exception e) {

            String JSONExceptionData = ERR_ExceptionData.createExceptionWrapperJSONString(e);

            throw UTIL_AuraEnabledCommon.buildAuraException(JSONExceptionData);
        }
    }

    /*******************************************************************************************************
    * @description Retrieves all open Opportunities, and Opportunities with unpaid Payments, for the
    * selected Donor (Account or Contact)
    * @return JSON stringified Map<String, List<SObject>> of all openOpportunities for the given donor
    */
    @AuraEnabled(cacheable=true)
    public static String getOpenDonations(Id donorId, String donorType) {
        if (donorId == null) {
            return null;
        }

        String relationshipField;
        if (donorType == SObjectType.Account.Name) {
            relationshipField = SObjectType.Opportunity.fields.AccountId.Name;
        } else if (donorType == SObjectType.Contact.Name) {
            relationshipField = SObjectType.Opportunity.fields.Primary_Contact__c.Name;
        }

        // Could eventually be used to display unpaid payments on the donation matching modal
        String paymentSOQL = 'SELECT Id, ' +
                'Name, ' +
                'npe01__Scheduled_Date__c, ' +
                'npe01__Opportunity__r.Name, ' +
                'npe01__Opportunity__c, ' +
                'npe01__Payment_Amount__c, ' +
                'Elevate_Payment_API_Status__c ' +
                'FROM npe01__OppPayment__c ' +
                'WHERE npe01__Opportunity__r.' + relationshipField + ' = :donorId ' +
                'AND npe01__Written_Off__c = false ' +
                'AND npe01__Paid__c = false ' +
                'WITH SECURITY_ENFORCED';

        try {
            // CRUD / FLS of this operation already verified by checkCRUDFLS()
            List<npe01__OppPayment__c> unpaidPayments = Database.query(paymentSOQL);
            Set<Id> oppIdsWithUnpaidPayments = new Set<Id>();
            for (npe01__OppPayment__c payment : unpaidPayments) {
                oppIdsWithUnpaidPayments.add(payment.npe01__Opportunity__c);
            }

            String opportunitySOQL = 'SELECT Id, ' +
                    'Name, ' +
                    'StageName, ' +
                    'CloseDate, ' +
                    'IsClosed, ' +
                    'Amount, ' +
                    'npe01__Number_of_Payments__c, ' +
                    '(SELECT Id, ' +
                    'Name, ' +
                    'npe01__Scheduled_Date__c, ' +
                    'npe01__Opportunity__r.Name, ' +
                    'npe01__Opportunity__c, ' +
                    'npe01__Payment_Amount__c,' +
                    'npe01__Payment_Date__c,' +
                    'npe01__Paid__c, ' +
                    'npe01__Written_Off__c, ' +
                    'Elevate_Payment_API_Status__c ' +
                    'FROM npe01__OppPayment__r ' +
                    'WHERE npe01__Written_Off__c = false ' +
                    'AND npe01__Paid__c = false)' +
                    'FROM Opportunity ' +
                    'WHERE ' + relationshipField + ' = :donorId ' +
                    'AND IsClosed = false ' +
                    'WITH SECURITY_ENFORCED ' +
                    'ORDER BY CloseDate ASC';

            // CRUD / FLS of this operation already verified by checkCRUDFLS()
            List<Opportunity> openOpportunities = Database.query(opportunitySOQL);

            List<OpportunityWrapper> opportunityWrappers = new List<OpportunityWrapper>();
            for (Opportunity opportunity : openOpportunities) {
                opportunityWrappers.add(new OpportunityWrapper(opportunity));
            }

            return JSON.serialize(opportunityWrappers);
        } catch (Exception ex){
            throw UTIL_AuraEnabledCommon.buildAuraException(ex.getMessage());
        }
    }

    /**
    * @description Wrapper class used to hold only the information needed in the
    * component for each Opportunity.  The component does not need to store any of
    * the paid or written-off Payments for a donor, but it does need to know if the Donation
    * has related Payments that have not been written-off. In that case the User should not
    * be able to update the Opportunity in the BGE Donation Selector.
    */
    @TestVisible
    private class OpportunityWrapper {
        @TestVisible Opportunity opportunity {get; private set;}
        @TestVisible List<npe01__OppPayment__c> unpaidPayments {get; private set;}
        @TestVisible Boolean hasNonWrittenOffPayments {get; private set;}

        private OpportunityWrapper(Opportunity opportunity) {
            this.opportunity = opportunity;
            initialize();
        }

        private void initialize() {
            if (unpaidPayments == null) {
                unpaidPayments = new List<npe01__OppPayment__c>();
            }

            if (opportunity.npe01__OppPayment__r.isEmpty()) {
                hasNonWrittenOffPayments = false;
                return;
            }

            for (npe01__OppPayment__c oppPayment : opportunity.npe01__OppPayment__r) {
                if (hasNonWrittenOffPayments == null
                        && oppPayment.npe01__Written_Off__c == false) {
                    hasNonWrittenOffPayments = true;
                }

                if (isAvailableForUpdate(oppPayment)) {
                    unpaidPayments.add(oppPayment);
                } else {
                    continue;
                }
            }

            //If hasNonWrittenOffPayments is null after looping all of the Payments,
            //then all of the Opp's Payments are written-off, and hasNonWrittenOffPayments can
            //be set to false, as this Opp should be treated in the BGE Donation Selector UI
            //as if it has 0 Payments.
            if (hasNonWrittenOffPayments == null) {
                hasNonWrittenOffPayments = false;
            }
        }

        private Boolean isAvailableForUpdate(npe01__OppPayment__c oppPayment) {
            if (oppPayment.npe01__Paid__c || oppPayment.npe01__Written_Off__c) {
                return false;
            } else {
                return true;
            }
        }
    }

    @TestVisible
    private static RenderWrapper getRenderWrapperById(Id templateId) {
        // Get the base template
        GE_Template.Template queriedTemplate = retrieveFormTemplateById(templateId);

        // Create the wrapper which will hold the template and field mapping set.
        RenderWrapper renderWrapper = wrapTemplate(queriedTemplate);

        return renderWrapper;
    }

    /**
     * This method creates a wrapper which contains the default SGE template and a field mapping set.
     *
     * @return  A RenderWrapper containing the default template JSON.
     */
    @TestVisible
    private static RenderWrapper getDefaultSGERenderWrapper() {
        GE_Template.Template defaultTemplate = retrieveDefaultSGEFormTemplate();

        RenderWrapper renderWrapper = wrapTemplate(defaultTemplate);

        return renderWrapper;
    }

    /**
     * This method builds the wrapper given the template and the field mapping set.
     *
     * @return  A RenderWrapper containing the default template JSON.
     */
    private static RenderWrapper wrapTemplate(GE_Template.Template template) {
        if (template != null) {
            Boolean includeUnmappedFields = true;
            // Get the mapping service which will retrieve all the mappings
            BDI_MappingServiceAdvanced mappingService = BDI_MappingServiceAdvanced.getInstance(includeUnmappedFields);

            updateTemplateWithRequired(template, mappingService.fieldMappingSet);

            // Create the wrapper which will hold the template and field mapping set.
            RenderWrapper renderWrapper = new RenderWrapper(template, mappingService.fieldMappingSet);

            return renderWrapper;
        } else {
            return null;
        }
    }

    /**
     * Get Allocations settings. Used to determine the default GAU, and if the default GAU is enabled.
     * This result cannot be cached as there is the potential for an upsert operation when no allocation settings exist.
     * @return An Allocation_Settings__c custom setting record
     */
    @AuraEnabled
    public static Allocations_Settings__c getAllocationsSettings() {
        return UTIL_CustomSettingsFacade.getAllocationsSettings();
    }

    /*******************************************************************************************************
    * @description Takes the template and field mappings and updates the template so that the required fields are set
    * as required.
    * @param template - The deserailized template that is stored.
    * @param fieldMappingSet The field mapping set which determines what DI field is mapped to what target field.
    */
    private static void updateTemplateWithRequired(GE_Template.Template template, BDI_FieldMappingSet fieldMappingSet) {
        List<GE_Template.Section> sectionList = template.layout.sections;

        for (GE_Template.Section section : sectionList) {

            // Go through all the elements
            for (GE_Template.Element element : section.elements) {
                if (element.dataImportFieldMappingDevNames != null
                        && !element.dataImportFieldMappingDevNames.isEmpty()) {

                    if (fieldMappingSet.fieldMappingByDevName.containsKey(element.dataImportFieldMappingDevNames[0])) {
                        BDI_FieldMapping fieldMapping = fieldMappingSet.fieldMappingByDevName.get(element.dataImportFieldMappingDevNames[0]);

                        // Update the element's required by doing an OR between the element's required, DI source field, target field
                        // Update the element's required to make sure we are respecting the source/target/template builder's required
                        // with the most up to date information.
                        element.required = element.required ||
                                (fieldMapping.Source_Field_Required == true &&
                                        fieldMapping.Source_Field_Data_Type != BOOLEAN_DATA_TYPE);
                    }
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description Work in Progress to deliver widget behaviors
    * @return Widget data
    */
    @TestVisible
    private static String convertWidgetDataToObjectJSON(String widgetData) {

        if (String.isBlank(widgetData)) {
            return null;
        }

        BDI_MappingServiceAdvanced mappingService = BDI_MappingServiceAdvanced.getInstance();
        Map<String, BDI_DynamicSource> dynamicSourceByObjMappingDevName = new Map<String, BDI_DynamicSource>();
        BDI_DynamicSourceGroup dynSourceGroup = new BDI_DynamicSourceGroup();

        dynSourceGroup.name = DataImport__c.Additional_Object_JSON__c.getDescribe().getName();
        dynSourceGroup.dynamicSourceByObjMappingDevName = dynamicSourceByObjMappingDevName;

        Map<String, Object> objMappingDevNameToObjList;

        try {
            objMappingDevNameToObjList = (Map<String, Object>) JSON.deserializeUntyped(widgetData);
        } catch (Exception e) {
            String JSONExceptionData = ERR_ExceptionData.createExceptionWrapperJSONString(e);
            throw UTIL_AuraEnabledCommon.buildAuraException(JSONExceptionData);
        }

        // Create a map of sobject type to sobject list for processing
        for (String objMappingDevName : objMappingDevNameToObjList.keySet()) {
            BDI_ObjectMapping objMapping = mappingService.objectMappingByDevName.get(objMappingDevName);

            BDI_FieldMapping[] fieldMappings = mappingService.fieldMappingsByObjMappingDevName.get(objMappingDevName);

            List<String> serializedSObjects = new List<String>();

            //Reserializing the object strings to resolve platform issue with deserializing SObjects
            for (Object obj : (List<Object>) objMappingDevNameToObjList.get(objMappingDevName)) {
                serializedSObjects.add(JSON.serialize(obj));
            }

            if (serializedSObjects != null && serializedSObjects.size() > 0) {

                Integer i = 0;
                //Loop through the sObjects and construct DI records to hold the data in the expected fields
                for (String objString : serializedSObjects) {

                    SObject sObj = (SObject) JSON.deserialize(objString, Sobject.class);

                    i++;
                    DataImport__c tempDI = new DataImport__c();

                    //Reverse mapping the fields back onto a tempDI Record that respresents the source obj.
                    for (BDI_FieldMapping fieldMapping : fieldMappings) {
                        Object value = sObj.get(fieldMapping.Target_Field_API_Name);
                        tempDI.put(fieldMapping.Source_Field_API_Name, value);
                    }

                    BDI_DynamicSource dynSource = new BDI_DynamicSource();
                    dynSource.objectMappingDevName = objMapping.DeveloperName + 'temp' + i;
                    dynSource.objectMappingTemplateDevName = objMapping.DeveloperName;
                    dynSource.fieldMappingSetDevName = mappingService.fieldMappingSetName;
                    dynSource.sourceObj = tempDI;

                    dynamicSourceByObjMappingDevName.put(dynSource.objectMappingDevName, dynSource);
                }
            }
        }

        if (dynSourceGroup.dynamicSourceByObjMappingDevName.size() > 0) {
            String dynSourceGroupString = JSON.serialize(dynSourceGroup);
            return dynSourceGroupString;
        }
        return null;
    }

    /**
     * @description Returns a render wrapper containing the Advanced Mapping field and
     * object mappings and a Gift Entry form template, which is either the default
     * or the one whose Id is passed in as templateId.
     *
     * @param templateId Id of the target Form_Template__c.
     *
     * @return The render wrapper containing the target template or the default
     * template if templateId is null.
     */
    @AuraEnabled(cacheable=true)
    public static RenderWrapper getFormRenderWrapper(Id templateId) {
        try {
            if (templateId != null) {
                return getRenderWrapperById(templateId);
            } else {
                return getDefaultSGERenderWrapper();
            }
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.initCause(e);
            throw ex;
        }
    }

    /**
     * @description Retrieves the default SGE render wrapper for gift entry.
     * @return      A render wrapper containing a template and information about the object/field mappings.
     */
    @AuraEnabled
    public static RenderWrapper retrieveDefaultSGERenderWrapper() {
        return getDefaultSGERenderWrapper();
    }

    /**
     * @description Retrieves field mappings when a template is not needed, no render wrapper.
     * @return {BDI_FieldMappingSet}
     */
    @AuraEnabled
    public static BDI_FieldMappingSet getFieldMappings() {
        return BDI_MappingServiceAdvanced.getInstance().fieldMappingSet;
    }

    public class RenderWrapper {

        @AuraEnabled public GE_Template.Template formTemplate;
        @AuraEnabled public BDI_FieldMappingSet fieldMappingSetWrapper;

        public RenderWrapper(GE_Template.Template formTemplate, BDI_FieldMappingSet fieldMappingSetWrapper) {
            this.formTemplate = formTemplate;
            this.fieldMappingSetWrapper = fieldMappingSetWrapper;
        }
    }

    private static final String TEMPLATES = 'Templates';
    private static final String BATCHES = 'Batches';

    /*******************************************************************************************************
    * @description Retrieves Matching string values from BDI_DataImport_API
    * @return Map of object and field name keys to their values.
    */
    @AuraEnabled
    public static Map<String, String> getDonationMatchingValues() {
        Map<String, String> matchingValues = new Map<String, String> {
                'DoNotMatch' => BDI_DataImport_API.DoNotMatch,
                'RequireNoMatch' => BDI_DataImport_API.RequireNoMatch,
                'RequireExactMatch' => BDI_DataImport_API.RequireExactMatch,
                'ExactMatchOrCreate' => BDI_DataImport_API.ExactMatchOrCreate,
                'RequireBestMatch' => BDI_DataImport_API.RequireBestMatch,
                'BestMatchOrCreate' => BDI_DataImport_API.BestMatchOrCreate
        };
        return matchingValues;
    }

    /*******************************************************************************************************
    * @description Method retrieves records based on a query string.
    */
    @AuraEnabled
    public static SObject[] retrieveRecords(String[] selectFields,
            String sObjectApiName, String[] whereClauses, String orderByClause, Integer limitClause) {

        String queryString = new UTIL_Query()
                .withSelectFields(selectFields)
                .withFrom(sObjectApiName)
                .withWhere(whereClauses)
                .withSecurityEnforced()
                .withOrderBy(orderByClause)
                .withLimit(limitClause)
                .build();
        return Database.query(queryString);
    }

    /*******************************************************************************************************
    * @description Method retrieves custom Column Header Data (Custom Setting records & Permission Data)
    * for tables in the Gift
    * Entry landing page.
    * @param listName
    * @return {ColumnHeaderData}
    */
    @AuraEnabled
    public static ColumnHeaderData retrieveCustomColumnHeaders(String listName) {
        String[] selectFields = new String[] {
                SObjectType.Custom_Column_Header__c.fields.Id.name,
                SObjectType.Custom_Column_Header__c.fields.Name.name,
                SObjectType.Custom_Column_Header__c.fields.Field_Api_Name__c.name,
                SObjectType.Custom_Column_Header__c.fields.Index__c.name,
                SObjectType.Custom_Column_Header__c.fields.List_Name__c.name
        };
        String sObjectApiName = SObjectType.Custom_Column_Header__c.name;
        String whereVal = '\'' + String.escapeSingleQuotes(listName) + '\'';
        String whereClauses = SObjectType.Custom_Column_Header__c.fields.List_Name__c.name + ' = ' + whereVal;
        String orderByClause = SObjectType.Custom_Column_Header__c.fields.Index__c.name + ' ASC';

        String queryString = new UTIL_Query()
                .withSelectFields(selectFields)
                .withFrom(sObjectApiName)
                .withWhere(whereClauses)
                .withSecurityEnforced()
                .withOrderBy(orderByClause)
                .build();
        return getColumnHeaderDataWithPermissions(Database.query(queryString), listName);
    }

    /*******************************************************************************************************
    * @description Method retrieves records based on a query string.
    */
    @AuraEnabled
    public static ColumnHeaderData upsertCustomColumnHeaders(String columnHeadersString,
            String listName) {

        Custom_Column_Header__c[] columnHeaders =
                (Custom_Column_Header__c[])JSON.deserialize(columnHeadersString, Custom_Column_Header__c[].class);
        upsert columnHeaders;

        Id[] headerIdsToKeep = new Id[]{};
        for (Custom_Column_Header__c columnHeader : columnHeaders) {
            headerIdsToKeep.add(columnHeader.Id);
        }

        Custom_Column_Header__c[] headersToDelete = [
                SELECT Id
                FROM Custom_Column_Header__c
                WHERE Id NOT IN :headerIdsToKeep
                AND List_Name__c = :listName
                WITH SECURITY_ENFORCED
        ];
        delete headersToDelete;

        return getColumnHeaderDataWithPermissions(columnHeaders, listName);
    }

    /*******************************************************************************************************
    * @description Method for retrieving all existing form templates.
    */
    @AuraEnabled
    public static GE_Template.Template[] getAllFormTemplates() {
        GE_Template.Template[] formTemplates = new GE_Template.Template[]{};
        Form_Template__c[] allTemplates = [
                SELECT Id,
                        Name,
                        Template_JSON__c,
                        Description__c,
                        Format_Version__c
                FROM Form_Template__c
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
        ];

        for (Form_Template__c formTemplate : allTemplates) {
            GE_Template.Template deserializedFormTemplate = deserializeFormTemplateFromObj
                    (formTemplate);
            if (formTemplate.id != null) {
                deserializedFormTemplate.id = formTemplate.id;
            }

            formTemplates.add(deserializedFormTemplate);
        }

        return formTemplates;
    }

    /*******************************************************************************************************
    * @description Method deletes a Form_Template__c record by id.
    *
    * @param id: Form_Template__c record id
    *
    * @return FormTemplateWrapper: Wrapper object of the list of deleted template names and the result
    * of the DML action
    */
    @AuraEnabled
    public static String [] deleteFormTemplates(String[] ids) {
        String[] formTemplateNames = new String[] {};
        Form_Template__c[] templates = [
                SELECT Id, Name
                FROM Form_Template__c
                WHERE Id IN :ids
                WITH SECURITY_ENFORCED
        ];
        try {
            delete templates;
            for (Form_Template__c template : templates) {
                formTemplateNames.add(template.Name);
            }
        } catch (DmlException ex) {
            throw new AuraHandledException(ex.getDmlMessage(0));
        }
        return formTemplateNames;
    }

    /*******************************************************************************************************
    * @description Method for retrieving an existing template that you already have the Id for.
    * @param templateId - the Id of an existing form template record for retrieval.
    */
    @AuraEnabled
    public static GE_Template.Template retrieveFormTemplateById(Id templateId) {
        GE_Template.Template template;

        Form_Template__c templateObj = [
                SELECT Id, Name, Format_Version__c, Template_JSON__c
                FROM Form_Template__c
                WHERE Id =: templateId
                WITH SECURITY_ENFORCED
                LIMIT 1
        ];

        template = deserializeFormTemplateFromObj(templateObj);

        template = checkPermissions(template,
                new Set<GE_Template.AccessLevel>{
                        GE_Template.AccessLevel.VALIDATE_READ,
                        GE_Template.AccessLevel.VALIDATE_CREATE,
                        GE_Template.AccessLevel.VALIDATE_UPDATE});

        return template;
    }

    /*******************************************************************************************************
    * @description Method for retrieving the current default template.
    */
    @TestVisible
    private static GE_Template.Template retrieveDefaultSGEFormTemplate() {
        Gift_Entry_Settings__c giftEntrySettings = getGiftEntrySettings();
        GE_Template.Template template;
        List<Form_Template__c> templateObjList = [
                SELECT Id, Name, Format_Version__c, Template_JSON__c
                FROM Form_Template__c
                WHERE Id =: giftEntrySettings.Default_Gift_Entry_Template__c
                WITH SECURITY_ENFORCED
        ];

        if (!templateObjList.isEmpty()) {
            template = deserializeFormTemplateFromObj(templateObjList[0]);

            template = checkPermissions(template,
                    new Set<GE_Template.AccessLevel>{
                            GE_Template.AccessLevel.VALIDATE_READ,
                            GE_Template.AccessLevel.VALIDATE_CREATE,
                            GE_Template.AccessLevel.VALIDATE_UPDATE});
        }
        return template;
    }

    /*******************************************************************************************************
    * @description Method for validating CRUD/FLS permissions for a template
    * @param template - the template to use for CRUD/FLS validation
    * @param accessLevels - a collection of CRUD/FLS validations to perform on the template (i.e. CREATE/UPDATE/READ)
    */
    private static GE_Template.Template checkPermissions(GE_Template.Template template,
    Set<GE_Template.AccessLevel> accessLevels){

        GE_Template.PermissionValidator validator = new GE_Template.PermissionValidator(template, accessLevels);

        return (GE_Template.Template) validator.validateTemplate();
    }

    /*******************************************************************************************************
    * @description Stores the template JSON.
    * @param id - the Id of an existing form template record if this is an update of an existing template
    * @param name - The name that should be applied to template storage record.
    * @param description - the description of the template.
    * @param formatVersion - the version id/number of the template format
    * @param templateJSON - The JSON for the FormTemplate class that is being stored.
    */
    @AuraEnabled
    public static String storeFormTemplate(String id,
            String name,
            String description,
            String formatVersion,
            String templateJSON) {
        if (templateJSON != null) {
            Form_Template__c templateObj = new Form_Template__c(Id = id,
                    Name = name,
                    Description__c = description,
                    Template_JSON__c = templateJSON,
                    Format_Version__c = formatVersion);
            upsert templateObj;
            return templateObj.Id;
        }

        return null;
    }

    /*******************************************************************************************************
    * @description Method checks if the provided name is in use by another existing Form Template.
    *
    * @param String name: Name of a Form_Template__c record.
    * @param String id: Id of a Form_Template__c record.
    */
    @AuraEnabled
    public static Boolean checkNameUniqueness(String name, String id) {
        Form_Template__c[] formTemplates = [
                SELECT Id
                FROM Form_Template__c
                WHERE Name = :name
                WITH SECURITY_ENFORCED
        ];
        Boolean isNameValid = formTemplates.size() > 0 ? false : true;

        if (id != null) {
            for (Form_Template__c formTemplate : formTemplates) {
                if (formTemplate.Id == id) {
                    isNameValid = true;
                    break;
                }
            }
        }

        return isNameValid;
    }

    /*******************************************************************************************************
    * @description Private helper method for deserializing the JSON stored in a form template record.
    * @param templateObj - The Form_Template__c object with the Template JSON.
    */
    private static GE_Template.Template deserializeFormTemplateFromObj(Form_Template__c templateObj) {
        GE_Template.Template template;
        if (templateObj != null && templateObj.Template_JSON__c != null) {
            template = (GE_Template.Template)JSON.deserialize(templateObj.Template_JSON__c, GE_Template.Template.class);
        }
        return template;
    }

    /******************************************************************************************************
     * @description Private method for checking FLS & CRUD permissions for custom column headers for the
     * the GE List View headers
     * @param columnHeaders Custom Column Headers
     * @param listName List View Name
     * @return Instance of the ColumnHeaderData object
    */
    private static ColumnHeaderData getColumnHeaderDataWithPermissions(Custom_Column_Header__c[] columnHeaders,
            String listName) {
        String listNameDevName = listName == TEMPLATES ?
                Schema.SObjectType.Form_Template__c.getName() :
                Schema.SObjectType.DataImportBatch__c.getName();

        ColumnHeaderData headerData;

        if (columnHeaders.isEmpty()) {
            //populate column headers with default headers
            columnHeaders = populateDefaultColumnHeaders(listName);
        }

        GE_Template.PermissionValidator validator = new GE_Template.PermissionValidator(
                new Set<GE_Template.AccessLevel>{GE_Template.AccessLevel.VALIDATE_READ});

        if (validator.hasObjectPermissions(listNameDevName)) {
            headerData = new ColumnHeaderData(columnHeaders, '');
            List<String> flsErrors = new List<String>();
            for (Custom_Column_Header__c header : columnHeaders) {
                if (!validator.hasFieldPermissions(listNameDevName, header.Field_Api_Name__c)) {
                    List<String> errors = new List<String>{header.Field_Api_Name__c};
                    flsErrors.add(listNameDevName + ': (' + String.join(errors, ', ') + ')');
                }
            }
            headerData.permissionErrorData += String.join(flsErrors, ' ,');
        }
        return headerData;
    }

    /**
     * @description Method to populate default column headers for the Gift Entry list view tables
     * @param listName
     * @return {Custom_Column_Header__c}
    */
    private static Custom_Column_Header__c[] populateDefaultColumnHeaders(String listName) {
        Custom_Column_Header__c[] columnHeaders = new Custom_Column_Header__c[]{};
        Integer index = 0;
        for (String field : buildListViewDefaultFields(listName)) {
            index++;
            Custom_Column_Header__c columnHeader = new Custom_Column_Header__c();
            columnHeader.Field_Api_Name__c = field;
            columnHeader.Index__c = index;
            columnHeader.Name = UTIL_String.getGUID();
            columnHeader.List_Name__c = listName;
            columnHeaders.add(columnHeader);
        }
        return columnHeaders;
    }

    /**
     * @description Builds default fields for the Gift Entry list view column headers
     * @param listName List view tab name
     * @return {List} defaultFields
    */
    private static List<String> buildListViewDefaultFields (String listName) {
        List<String> defaultFields;
        if (listName == TEMPLATES) {
            defaultFields = new List<String> {
                    'Name',
                    UTIL_Namespace.StrTokenNSPrefix('Description__c'),
                    'CreatedById',
                    'LastModifiedDate'
            };
        } else if (listName == BATCHES) {
            defaultFields = new List<String> {
                    'Name',
                    UTIL_Namespace.StrTokenNSPrefix('Batch_Description__c'),
                    UTIL_Namespace.StrTokenNSPrefix('Form_Template__c'),
                    UTIL_Namespace.StrTokenNSPrefix('Expected_Count_of_Gifts__c'),
                    UTIL_Namespace.StrTokenNSPrefix('Expected_Total_Batch_Amount__c'),
                    'CreatedById',
                    'LastModifiedDate'
            };
        }
        return defaultFields;
    }

    /**
     * Inner class representation of the Custom Column Headers with permission data
    */
    public with sharing class ColumnHeaderData {
        @AuraEnabled
        public Custom_Column_Header__c[] columnHeaders;
        @AuraEnabled
        public String permissionErrorData;

        public ColumnHeaderData (Custom_Column_Header__c[] columnHeaders,
                String permissionErrorData) {
            this.columnHeaders = columnHeaders;
            this.permissionErrorData = permissionErrorData;
        }
    }

    /**
     * @description This method will create a default template
     * if it is necessary and then return the Gift_Entry_Settings__c
     * custom setting  for use.
     *
     * @return Returns whether or not there is an existing default template.
     */
    @AuraEnabled
    public static Gift_Entry_Settings__c getGiftEntrySettings() {
        try {
            GE_Template.createDefaultTemplateIfNecessary();
            Gift_Entry_Settings__c giftEntryCustomSetting = UTIL_CustomSettingsFacade.getGiftEntrySettings();

            return giftEntryCustomSetting;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable= true)
    public static String retrieveBatchCurrencyIsoCode (Id batchId) {
        String query = new UTIL_Query()
            .withSelectFields(new Set<String>{UTIL_Currency.CURRENCY_ISO_CODE_FIELD})
            .withFrom(DataImportBatch__c.SObjectType)
            .withWhere('Id =: batchId')
            .build();
        List<DataImportBatch__c> batches = Database.query(query);
        return (String)batches[0].get(UTIL_Currency.CURRENCY_ISO_CODE_FIELD);
    }

    private class CurrencyMismatchException extends Exception {}

    private class BDIException extends Exception {}
}
