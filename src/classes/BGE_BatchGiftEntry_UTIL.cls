/*
    Copyright (c) 2019, Salesforce.org
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
* @group BGE
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Utilities to support Batch Gift Entry.
*/
public with sharing class BGE_BatchGiftEntry_UTIL {

    @TestVisible
    private static GiftBatch giftBatch;

    /*******************************************************************************************************
    * @description Currently limit the set of allowed objects, and point to their BDI-defined 
    *  Object group name
    */
    public static Map<String, String> objectGroupNameByAllowedObjects = new Map<String,String> {
        'Opportunity' => 'Opportunity',
        'npe01__OppPayment__c' => 'Payment'
    };

    /*******************************************************************************************************
    * @description Provides field mapping configuration used by BGE
    */
    public static Map<SObjectField, BDI_TargetFields> targetFieldsBySourceField =
        BDI_DataImportService.getDefaultMappingService().getTargetFieldsBySourceField();

    /*******************************************************************************************************
    * @description returns a list of DataImport__c fields the Batch Gift Entry UI needs in SOQL
    * @param batchId the batch for which to get all fields for soql
    * @return List<String> list of DataImport__c field api names
    */
    public static List<String> getDataImportFields(Id batchId) {
        return getDataImportFields(batchId, true);
    }

    /*******************************************************************************************************
    * @description returns a list of DataImport__c fields the Batch Gift Entry UI needs in SOQL
    * @param batchId the batch for which to get all fields for soql
    * @param includeRelationshipFields whether to include relationship fields in the returned list
    * @return List<String> list of DataImport__c field api names
    */
    public static List<String> getDataImportFields(Id batchId, Boolean includeRelationshipFields) {
        Set<String> fieldApiNames = new Set<String>();
        List<String> dataImportCoreFields = getCoreDataImportFields(includeRelationshipFields);

        // Query the Batch to determine which set of fields will be needed.
        // Batches created using BGE_DataImportBatchEntry store fields used by its Data
        // Import records in Active_Fields__c, while Batches created in GE_GiftEntry
        // use fields included in the Form_Template__c record related to the Batch.
        DataImportBatch__c batch = getDataImportBatch(batchId);

        if (!isNewBatchGiftEntryVersion(batch)) {
            fieldApiNames.addAll(getActiveFieldNamesFromBatch(batchId));
            fieldApiNames.addAll(dataImportCoreFields);

            return new List<String>( fieldApiNames );
        }

        fieldApiNames.addAll(getDataImportElevateFields(batchId));
        fieldApiNames.add(getNewBatchGiftEntryVersionFields());

        for (String field : dataImportCoreFields) {
            fieldApiNames.add(field.toLowerCase());
        }

        // Must explicitly use BDI_MappingServiceAdvanced here (as opposed to
        // BDI_DataImportService.getDefaultMappingService()) because of the need
        // to reference the fieldMappingByDevName property.
        fieldApiNames.addAll(getTemplateFields(batch, new List<String> (fieldApiNames)));
        return new List<String>( fieldApiNames );
    }

    private static List<String> getTemplateFields(DataImportBatch__c batch, List<String> fieldApiNames) {
        List<String> templateFields = new List<String>();

        BDI_MappingServiceAdvanced mappingService =
                BDI_MappingServiceAdvanced.getInstance();

        Map<String, BDI_FieldMapping> fieldMappingByDevName =
                mappingService.fieldMappingByDevName;

        for (GE_Template.Section formSection : deserializeTemplate(batch).layout.sections) {
            for (GE_Template.Element formElement : formSection.elements) {
                if (formElement.dataImportFieldMappingDevNames == null) {
                    continue;
                }
                // Get the field mappings, used to reference the source fields
                for (String fieldMappingName :
                        formElement.dataImportFieldMappingDevNames) {

                    BDI_FieldMapping fieldMapping =
                            fieldMappingByDevName.get(fieldMappingName);

                    Boolean isObjectMappedLookup = mappingService
                            .importedRecordFieldNames.contains(
                            fieldMappingName.toLowerCase());

                    if (fieldMapping == null && !isObjectMappedLookup) {
                        continue;
                    }
                    String sourceFieldName = fieldMapping != null ?
                            fieldMapping.Source_Field_API_Name :
                            isObjectMappedLookup ?
                                    fieldMappingName : null;
                    SObjectField field = DataImport__c.SObjectType.getDescribe()
                            .fields.getMap().get(sourceFieldName);

                    // Add the source fields used in the Template but only if the source field name is valid
                    if (!fieldApiNames.contains(sourceFieldName.toLowerCase()) && field != null) {
                        templateFields.add(sourceFieldName.toLowerCase());
                    }

                    // Add the Name fields on the related object(s) for all Lookup fields,
                    // used as display value(s) for Lookup fields loaded in the Form UI
                    if ((fieldMapping != null &&
                            fieldMapping.Source_Field_Data_Type == 'REFERENCE')
                            || isObjectMappedLookup) {

                        if (field != null) {
                            String relatedObjNameField =
                                    UTIL_Describe.getReferenceObjectNameField(field);

                            if (relatedObjNameField != null &&
                                    !fieldApiNames.contains(
                                            relatedObjNameField.toLowerCase())) {
                                templateFields.add(relatedObjNameField.toLowerCase());
                            }
                        }
                    }
                }
            }
        }
        return templateFields;
    }

    private static GE_Template.Template deserializeTemplate(DataImportBatch__c batch) {
        GE_Template.Template template = (GE_Template.Template) JSON.deserialize(
                batch.Form_Template__r.Template_JSON__c,
                GE_Template.Template.class
        );
        return template;
    }

    private static String getNewBatchGiftEntryVersionFields() {
        return DataImport__c.Additional_Object_JSON__c.getDescribe().getName();
    }

    private static Boolean isNewBatchGiftEntryVersion(DataImportBatch__c batch) {
        return batch.Batch_Gift_Entry_Version__c >= 2.0;
    }

    private static DataImportBatch__c getDataImportBatch(Id batchId) {
        DataImportBatch__c batch = [
                SELECT Batch_Gift_Entry_Version__c,
                        Form_Template__r.Template_JSON__c
                FROM DataImportBatch__c
                WHERE Id = :batchId
        ];
        return batch;
    }

    @TestVisible
    private static List<String> getDataImportElevateFields(Id batchId) {
        List<String> elevateFieldApiNames = new List<String>();
        if (GE_PaymentServices.getInstance().isElevateCustomer()
            && hasElevateWidgetOnTemplate(batchId)) {

            elevateFieldApiNames = new List<String>{
                String.valueOf(DataImport__c.Payment_Declined_Reason__c),
                String.valueOf(DataImport__c.Elevate_Payment_Status__c)
            };
        }

        return elevateFieldApiNames;
    }

    private static Boolean hasElevateWidgetOnTemplate(Id batchId) {
        if (giftBatch == null) {
            giftBatch = new GiftBatch(batchId);
        }
        return giftBatch.hasElevateWidget();
    }

    /*******************************************************************************************************
    * @description Returns the subset of DataImport__c fields that are part of every batch
    * @param includeRelationshipFields whether to include relationship fields in the returned list
    * @return List<String>
    */
    private static List<String> getCoreDataImportFields(Boolean includeRelationshipFields) {
        List<String> fields = new List<String> {
            'Id',
            'Account1Imported__c',
            'Contact1Imported__c',
            'Donation_Donor__c',
            'DonationImported__c',
            'DonationImportStatus__c',
            'FailureInformation__c',
            'NPSP_Data_Import_Batch__c',
            'PaymentImported__c',
            'PaymentImportStatus__c',
            'Payment_Status__c',
            'Status__c'
        };

        if (includeRelationshipFields) {
            fields.addAll(new List<String> {
                'Account1Imported__r.Name',
                'Contact1Imported__r.Name',
                'DonationImported__r.Name',
                'PaymentImported__r.Name'
            });
        }

        // Maybe create new method in UTIL_Namespace for lists
        Set<String> namespacedFields = new Set<String>();
        for (String fieldName : fields) {
            namespacedFields.add(UTIL_Namespace.StrAllNSPrefix(fieldName));
        }

        return new List<String> (namespacedFields);
    }

     /*******************************************************************************************************
    * @description parses Active_Fields__c for the list of user-defined fields included in the batch config
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @return list of field api names
    */
    public static List<String> getActiveFieldNamesFromBatch(Id batchId) {
        DataImportBatch__c batch = [SELECT Active_Fields__c FROM DataImportBatch__c WHERE Id = :batchId];
        String activeFieldsJSON = batch.Active_Fields__c;
        List<String> activeFieldNames = new List<String>();

        if (activeFieldsJSON != null) {
            List<BGE_ConfigurationWizard_CTRL.BGEField> activeFields =
                (List<BGE_ConfigurationWizard_CTRL.BGEField>)JSON.deserialize(
                    activeFieldsJSON,
                    List<BGE_ConfigurationWizard_CTRL.BGEField>.class
                );
            for (BGE_ConfigurationWizard_CTRL.BGEField field : activeFields) {
                activeFieldNames.add(field.name);
                if (field.type == 'reference') {
                    DescribeFieldResult lookupDFR = UTIL_Describe.getFieldDescribe(
                        UTIL_Namespace.StrTokenNSPrefix('DataImport__c'),
                        field.name.toLowerCase()
                    );
                    String referencedObjectName = lookupDFR.getReferenceTo()[0].getDescribe().name;
                    activeFieldNames.add(field.name.substringBefore('__c') + '__r.' + UTIL_Describe.getNameField(referencedObjectName));
                }
            }
        }

        return activeFieldNames;
    }

    /*******************************************************************************************************
    * @description checks for read, create, and edit FLS for a given field
    * @param dfr DescribeFieldResult of the field to check
    * @return Boolean
    */
    public static Boolean canUpdateField(DescribeFieldResult dfr) {
        return dfr.isCreateable() && dfr.isUpdateable();
    }

    /*******************************************************************************************************
    * @description Returns the relevant Batch fields for soql
    * @return list of field API names
    */
    public static List<String> getBatchFieldNames() {
        return new List<String>{
            'Id',
            'Name',
            'Active_Fields__c',
            'Batch_Description__c',
            'Batch_Process_Size__c',
            'Contact_Matching_Rule__c',
            'Donation_Matching_Behavior__c',
            'Donation_Matching_Implementing_Class__c',
            'Donation_Matching_Rule__c',
            'Donation_Date_Range__c',
            'Expected_Count_of_Gifts__c',
            'Expected_Total_Batch_Amount__c',
            'Post_Process_Implementing_Class__c',
            'Process_Using_Scheduled_Job__c',
            'RequireTotalMatch__c',
            'Run_Opportunity_Rollups_while_Processing__c',
            'Batch_Status__c'
        };
    }

    /*******************************************************************************************************
    * @description Checks to see whether the running user has permission to edit a given list of fields
    * @param fieldsToCheck list of DescribeFieldResult records to check
    * @return void Throws an exception if user lacks edit permissions on any field
    */
    public static void checkFieldPermissions(List<DescribeFieldResult> fieldsToCheck) {
        Boolean hasPermission = true;
        List<String> fieldsWithoutPermission = new List<String>();

        for (DescribeFieldResult dfr : fieldsToCheck) {
            Boolean canReadCustomFormulaField =
                dfr.isCalculated() && UTIL_Permissions.canRead(dfr, false);
            if (canReadCustomFormulaField) {
                continue;
            }
            if (!UTIL_Permissions.canUpdate(dfr, false)) {
                hasPermission = false;
                fieldsWithoutPermission.add(dfr.getLabel());
            }
        }

        if (!hasPermission) {
            handleMissingPermissions(fieldsWithoutPermission);
        }

    }

    public static void checkFieldPermissions(String objectName, List<String> fieldNamesToCheck) {
        List<DescribeFieldResult> fieldResults = new List<DescribeFieldResult>();
        for (String fieldName : fieldNamesToCheck) {
            if (fieldName.contains('__r')) {
                fieldName = fieldName.substringBefore('__r') + '__c';
            }

            DescribeFieldResult fieldResult =
                UTIL_Describe.getFieldDescribe(UTIL_Namespace.StrAllNSPrefix(objectName), fieldName);

            if (fieldName != 'Id' && !fieldResults.contains(fieldResult)) {
                fieldResults.add(fieldResult);
            }
        }
        checkFieldPermissions(fieldResults);
    }

    /*******************************************************************************************************
    * @description Handles missing field permissions
    * @param missingPermissions list of DescribeFieldResult records for which permissions are lacking
    * @return void Throws an exception if user lacks permissions on any field
    */
    public static void handleMissingPermissions(List<DescribeFieldResult> missingPermissions) {
        List<String> fieldNames = new List<String>();
        for (DescribeFieldResult fieldResult : missingPermissions) {
            fieldNames.add(fieldResult.getLabel());
        }
        handleMissingPermissions(fieldNames);
    }

    /*******************************************************************************************************
    * @description Handles missing field permissions
    * @param missingPermissions list of Strings identifying the fields with missing permissions
    * @return void Throws an exception if user lacks permissions on any field
    */
    private static void handleMissingPermissions(List<String> missingPermissions) {

        if (!missingPermissions.isEmpty()) {
            String errorMsg = Label.bgeFLSError + ' [' + truncateList(missingPermissions, 3) + ']';
            AuraHandledException ex = new AuraHandledException(errorMsg);
            ex.setMessage(errorMsg);
            throw ex;
        }
    }

    /*******************************************************************************************************
    * @description Takes a list of strings and converts it to a string of a subset of the original list
    * @param items list of Strings
    * @param maxItems the maximum number of Strings from the list to retain
    * @return String the truncated list of strings, separated by a comma
    * @example truncateList(new List<String>{ 'apple', 'orange', 'banana', 'pear' }, 2); // returns 'apple, 
    *  orange ...'
    */
    @TestVisible
    private static String truncateList(List<String> items, Integer maxItems) {
        Integer totalItems = items.size();
        List<String> limitedItems = new List<String>();

        for (Integer i = 0; i < maxItems && i < items.size(); i++) {
            limitedItems.add(items[i]);
        }

        return String.join(limitedItems, ', ') + (totalItems > maxItems ? ' ...' : '');
    }

    /*******************************************************************************************************
    * @description Checks for field permissions needed to create a new Batch
    * User must have fields on DataImportBatch__c that appear in the config wizard
    * as well as Donation_Amount__c on DataImport__c because it is locked as a required field in config wizard
    * @return void; throws an AuraHandledException if any fields fail FLS check
    */
    public static void checkFieldPermissionsNeededForBatch() {

        List<DescribeFieldResult> fieldsToCheck = new List<DescribeFieldResult>();

        List<String> batchFieldNames = getBatchFieldNames();

        for (String field : batchFieldNames) {
            if (field != 'Id') {
                field = UTIL_Namespace.StrAllNSPrefix(field);
                fieldsToCheck.add(UTIL_Describe.getFieldDescribe(
                    UTIL_Namespace.StrTokenNSPrefix('DataImportBatch__c'), field));
            }
        }

        // Donation Amount and Donation Date are also required
        fieldsToCheck.add(UTIL_Describe.getFieldDescribe(UTIL_Namespace.StrTokenNSPrefix('DataImport__c'), 
            UTIL_Namespace.StrTokenNSPrefix('Donation_Amount__c')));
        fieldsToCheck.add(UTIL_Describe.getFieldDescribe(UTIL_Namespace.StrTokenNSPrefix('DataImport__c'), 
            UTIL_Namespace.StrTokenNSPrefix('Donation_Date__c')));

        // Lookup from Data Import row to Data Import Batch is also required
        fieldsToCheck.add(UTIL_Describe.getFieldDescribe(UTIL_Namespace.StrTokenNSPrefix('DataImport__c'), 
            UTIL_Namespace.StrTokenNSPrefix('NPSP_Data_Import_Batch__c')));

        checkFieldPermissions(fieldsToCheck);
    }



    /*******************************************************************************************************
    * @description Returns the source field's options formatted for lightning:select if the source field is a picklist
    * or the target field's options if the source field is a string and the target field is a picklist.
    * Returns an empty map if neither case applies.
    */
    public static List<Map<String, String>> getPicklistOptions(String dataImportField){
        List<Map<String, String>> options = new List<Map<String, String>>();

        String dataImportObject = UTIL_Namespace.StrTokenNSPrefix('DataImport__c');

        Schema.DisplayType rawSourceFieldType = UTIL_Describe.getFieldDisplaytype(
            dataImportObject, dataImportField.toLowerCase());

        Schema.DescribeFieldResult sourceFieldDFR = UTIL_Describe.getFieldDescribe(
            dataImportObject, dataImportField.toLowerCase());

        if (rawSourceFieldType == Schema.DisplayType.Picklist) {
            options = UTIL_Describe.getLightningSelectOptions(dataImportObject, dataImportField);

        } else if (rawSourceFieldType == Schema.DisplayType.String) {

            if (targetFieldsBySourceField.containsKey(sourceFieldDFR.getSObjectField())) {
                BDI_TargetFields targetFields = targetFieldsBySourceField.get(sourceFieldDFR.getSObjectField());
                Map<SObjectType, Set<SObjectField>> targetFieldsByTargetObject = 
                    targetFields.getTargetFieldsByTargetObject();

                String targetObject = '';
                String targetField = '';

                // One DI field can be mapped to multiple target fields although it will be rare and presents some 
                // issues with picklists; here we will return info for the first match
                for (Schema.SObjectType targetSObjType: targetFieldsByTargetObject.keySet()) {
                    String aTargetObjectName = targetSObjType.getDescribe().getName();
                    if (objectGroupNameByAllowedObjects.containsKey(aTargetObjectName)) {
                        targetObject = aTargetObjectName;
                        List<SObjectField> mappedTargetFields = 
                            new List<SObjectField> (targetFieldsByTargetObject.get(targetSObjType));
                        if(mappedTargetFields.size() > 0) {
                            targetField = mappedTargetFields[0].getDescribe().getName();
                        }
                    }
                }

                Schema.DisplayType targetFieldType = UTIL_Describe.getFieldDisplaytype(targetObject, targetField);

                if (targetFieldType == Schema.DisplayType.PICKLIST) {
                    options = UTIL_Describe.getLightningSelectOptions(targetObject, targetField);
                } else if (targetField == 'RecordTypeId') {
                    options = UTIL_RecordTypes.getStringRecordTypesForLightningSelect(
                        UTIL_Describe.getSObjectType(targetObject));
                }
            }
        }
        return options;
    }
}
