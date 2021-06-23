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
* @group Batch Data Import
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Methods to handle converting data import help text mappings to custom metadata records
*/
public without sharing class BDI_MigrationMappingUtility {
    /*******************************************************************************************************
    * @description Metadata queued up for deployment
    */
    public List<Metadata.CustomMetadata> queuedMetadataTypesForDeploy =
        new List<Metadata.CustomMetadata>();

    /*******************************************************************************************************
    * @description Current context namespace
    */
    public static final String NAMESPACE = UTIL_Namespace.getNamespace();

    /*******************************************************************************************************
    * @description Name of default packaged Object Mapping Set
    */
    public static final String DEFAULT_OBJECT_MAPPING_SET_RECORD_NAME = 'Default_Object_Mapping_Set';

    /*******************************************************************************************************
    * @description Name of default packaged Field Mapping Set
    * Set as static because it's used in the static method updateCustomSettings
    */
    public static final String DEFAULT_FIELD_MAPPING_SET_RECORD_NAME = 'Default_Field_Mapping_Set';

    /*******************************************************************************************************
    * @description Name of custom Object Mapping Set
    * Set as static because it's used in the static method updateCustomSettings
    */
    public static final String MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME =
        'Migrated_Custom_Object_Mapping_Set';

    /*******************************************************************************************************
    * @description Name of custom Field Mapping Set
    * Set as static because it's used in the static method updateCustomSettings
    */
    public static final String MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME =
        'Migrated_Custom_Field_Mapping_Set';

    /*******************************************************************************************************
    * @description Value for Data Import custom settings Field Mapping Method
    * Set as static because it's used in the static method updateCustomSettings
    */
    public static final String DATA_IMPORT_FIELD_MAPPING = 'Data Import Field Mapping';

    /*******************************************************************************************************
    * @description Value for Data Import Custom Setting's Field Mapping Method.
    * Set as static because it's used in the static method updateCustomSettings
    */
    public static final String HELP_TEXT = 'Help Text';

    /*******************************************************************************************************
    * @description These are known standard Help Text mappings that could be picked up by the migration
    * utility as bad help text mappings and need to be skipped
    */
    private final Set<String> HELP_TEXT_EXCEPTIONS = new Set<String>{
        'The role that the Opportunity Contact Role should be created with.  For example enter \'Soft Credit\' '+
            'to create a soft credit opportunity contact role.',
            'Indicates the type of transaction.'
    };

    /*******************************************************************************************************
    * @description Helper class that supports BDI_MigrationMappingUtility and enables mocking of test data.
    */
    private BDI_MigrationMappingHelper helper;

    /*******************************************************************************************************
    * @description Custom Setting record where we set cmt api deployment status, cmt deployment id,
    * field mapping method, and default data import field mapping set.
    */
    private Data_Import_Settings__c dataImportSettings;

    /*******************************************************************************************************
    * @description Map of migrated Data Import Object Mapping developer names by legacy data import object
    * names
    */
    private Map<String, String> legacyDataImportObjectNameByDeveloperName;

    /*******************************************************************************************************
    * @description List of bad/malformed help text mappings
    */
    public List<HelpTextFieldMapping > badHelpTextMappings {
        get {
            if (badHelpTextMappings == null) {
                badHelpTextMappings = new List<HelpTextFieldMapping>();
            }
            return badHelpTextMappings;
        }
        set;
    }

    /*******************************************************************************************************
    * @description List of BDI_MappingServiceHelpText.DataImportFieldMappings built from good help text mappings
    */
    public List<DataImportFieldMapping> dataImportFieldMappings = new List<DataImportFieldMapping>();

    /*******************************************************************************************************
    * @description Map of valid Object Fields by Object Name
    */
    public static Map<String, Set<String>> validFieldsByObjectName;

    /*******************************************************************************************************
    * @description Name of the Data Import Field Mapping Set to use
    */
    public String fieldMappingSetName {
        get {
            if (fieldMappingSetName == null) {
                List<Data_Import_Field_mapping_Set__mdt> fieldMappingSet =
                    helper.getFieldMappingSet(MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);

                if (fieldMappingSet != null && fieldMappingSet.size() > 0) {
                    return MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME;
                }
                return DEFAULT_FIELD_MAPPING_SET_RECORD_NAME;
            }
            return fieldMappingSetName;
        }
        set;
    }

    /*******************************************************************************************************
    * @description Constructor for Migration Mapping Utility class
    * @param helper Instance of BDI_MigrationMappingHelper
    */
    public BDI_MigrationMappingUtility(BDI_MigrationMappingHelper helper) {
        this.helper = helper;
        this.dataImportSettings = Data_Import_Settings__c.getInstance();
    }

    /*******************************************************************************************************
    * @description Updates Data Import custom settings.
    * Static because it's used in static inner class DeploymentCallback and in
    * STG_PanelDataImportAdvancedMapping_CTRL
    *
    * @param fieldMappingMethod: String that determines what data import field mapping method
    * to use (i.e. help text, custom metadata)
    * @param status: Deployment status
    * @return Data_Import_Settings__c
    */
    public static Data_Import_Settings__c updateCustomSettings(String fieldMappingMethod, String status) {

        Data_Import_Settings__c dataImportSettings = UTIL_CustomSettingsFacade.getDataImportSettings();
        dataImportSettings.Field_Mapping_Method__c = fieldMappingMethod;
        BDI_MigrationMappingHelper helper = new BDI_MigrationMappingHelper();
        List<Data_Import_Field_mapping_Set__mdt> fieldMappingSet =
            helper.getFieldMappingSet(MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);

        if (fieldMappingSet.size() > 0) {
            dataImportSettings.Default_Data_Import_Field_Mapping_Set__c =
                MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME;
        } else {
            dataImportSettings.Default_Data_Import_Field_Mapping_Set__c =
                DEFAULT_FIELD_MAPPING_SET_RECORD_NAME;
        }

        Map<String, String> statusMap;

        if (fieldMappingMethod == DATA_IMPORT_FIELD_MAPPING) {
            statusMap = new Map<String, String>{
                'Deployment Date' => String.valueOf(Datetime.now()),
                'Status' => String.valueOf(status),
                'Field Mapping Method' => fieldMappingMethod};
        } else {
            statusMap = new Map<String, String>();
        }

        dataImportSettings.CMT_API_Status__c = JSON.serializePretty(statusMap).left(255);

        try {
            upsert dataImportSettings;
            return dataImportSettings;
        } catch (Exception e) {
            throw new DeploymentException(Label.bdiErrorDataImportCustomSettings + ' ' + e.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Clone the reference Data Import Object Mapping records
    */
    public void cloneObjectMappings() {

        queuedMetadataTypesForDeploy.clear();
        legacyDataImportObjectNameByDeveloperName = new Map<String, String>();

        Data_Import_Object_Mapping_Set__mdt[] migratedObjectMappingSets =
            helper.getObjectMappingSet(MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME);

        if (migratedObjectMappingSets.isEmpty()) {
            createAndEnqueueMigratedCustomObjectMappingSet();
        }

        Map<String, Data_Import_Object_Mapping__mdt> existingMigratedObjectMappings =
            helper.getObjectMappingsBySetDeveloperName(MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME);

        DataImportObjectMapping[] objectMappings = new List<DataImportObjectMapping>();
        Map<String, String> developerNamesByPredecessor = new Map<String, String>();

        Map<String, Data_Import_Object_Mapping__mdt> referenceObjectMappingsByDeveloperName =
            helper.getObjectMappingsBySetDeveloperName(DEFAULT_OBJECT_MAPPING_SET_RECORD_NAME);
        for (String name : referenceObjectMappingsByDeveloperName.keySet()) {

            String legacyDataImportObjectName;
            String developerName;
            Data_Import_Object_Mapping__mdt referenceObjectMapping =
                referenceObjectMappingsByDeveloperName.get(name);
            Data_Import_Object_Mapping__mdt existingMigratedObjectMapping =
                existingMigratedObjectMappings.get(name);
            DataImportObjectMapping objectMappingWrapper;

            if (existingMigratedObjectMapping == null) {
                objectMappingWrapper = new DataImportObjectMapping(referenceObjectMapping, true);
                legacyDataImportObjectName =
                    referenceObjectMapping.Legacy_Data_Import_Object_Name__c;
                developerName = objectMappingWrapper.uniqueRecordName;
            } else {
                objectMappingWrapper = new DataImportObjectMapping(existingMigratedObjectMapping, false);
                legacyDataImportObjectName =
                    existingMigratedObjectMapping.Legacy_Data_Import_Object_Name__c;
                developerName = existingMigratedObjectMapping.DeveloperName;
                objectMappingWrapper.uniqueRecordName = existingMigratedObjectMapping.DeveloperName;
            }

            objectMappings.add(objectMappingWrapper);
            legacyDataImportObjectNameByDeveloperName.put(legacyDataImportObjectName, developerName);
            developerNamesByPredecessor.put(legacyDataImportObjectName, developerName);
        }

        for (DataImportObjectMapping objectMappingWrapper : objectMappings) {

            if (objectMappingWrapper.objectMapping.Predecessor__c != null &&
                developerNamesByPredecessor.get(objectMappingWrapper.predecessor) != null) {

                objectMappingWrapper.objectMapping.Predecessor__c =
                    developerNamesByPredecessor.get(objectMappingWrapper.predecessor);
            }

            queuedMetadataTypesForDeploy.add(objectMappingWrapper.getMetadataRecord());
        }
    }

    /*******************************************************************************************************
    * @description Starts the migration from help text to custom metadata records and adds created custom
    * metadata records to list queuedMetadataTypesForDeploy.
    */
    public void migrateHelpTextToCustomMetadata() {

        cloneObjectMappings();

        if (!Test.isRunningTest()) {
            populateListsFromHelpTextMappings();
        }

        Map<String, Data_Import_Field_Mapping__mdt> referenceFieldMappingsByFieldMappingKey =
            helper.getFieldMappingsByFieldMappingSetDeveloperName(DEFAULT_FIELD_MAPPING_SET_RECORD_NAME);
        Map<String, Data_Import_Field_Mapping__mdt> migratedFieldMappingsByFieldMappingKey =
            helper.getFieldMappingsByFieldMappingSetDeveloperName(MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);

        for (DataImportFieldMapping fieldMapping : dataImportFieldMappings) {

            String fieldMappingKey = fieldMapping.getKey();

            String existingObjectMappingDeveloperName =
                legacyDataImportObjectNameByDeveloperName.get(fieldMapping.dataImportObjectName);
            Data_Import_Field_Mapping__mdt referenceFieldMapping =
                referenceFieldMappingsByFieldMappingKey.get(fieldMappingKey);
            Data_Import_Field_Mapping__mdt migratedFieldMapping =
                migratedFieldMappingsByFieldMappingKey.get(fieldMappingKey);

            if (referenceFieldMapping == null && migratedFieldMapping == null) {
                fieldMapping.setRecordName(null, false);
            } else {
                if (migratedFieldMapping != null) {
                    fieldMapping.recordName = migratedFieldMapping.DeveloperName;
                } else {
                    fieldMapping.setRecordName(referenceFieldMapping.DeveloperName, true);
                }
            }

            fieldMapping.setFieldMappingSet(MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);
            fieldMapping.setObjectMapping(
                existingObjectMappingDeveloperName,
                fieldMapping.dataImportObjectName);

            queuedMetadataTypesForDeploy.add(fieldMapping.getMetadataRecord());

            referenceFieldMappingsByFieldMappingKey.remove(fieldMappingKey);
        }

        createAndEnqueueNonHelpTextMappings(
            referenceFieldMappingsByFieldMappingKey,
            migratedFieldMappingsByFieldMappingKey);
        createAndEnqueueMigratedCustomFieldMappingSet();
    }

    /*******************************************************************************************************
    * @description Go through all fields in Data Import object and populate relevant lists from help text
    * mappings, lists for potentially bad help text mappings and list of data import field mappings generated
    * from help text mappings.
    */
    @TestVisible
    private void populateListsFromHelpTextMappings() {

        badHelpTextMappings.clear();
        dataImportFieldMappings.clear();

        List<HelpTextFieldMapping> helpTextFieldMappings = helper.getAllHelpTextFieldMappings();

        for (HelpTextFieldMapping helpTextFieldMapping : helpTextFieldMappings) {

            String unnamespacedDIFieldName =
                UTIL_Namespace.alignSchemaNSWithEnvironment(helpTextFieldMapping.dataImportFieldAPIName.toLowerCase());

            Boolean isException = false;
            if (helpTextFieldMapping.helpText != null) {
                isException = HELP_TEXT_EXCEPTIONS.contains(helpTextFieldMapping.helpText);
            }

            if (isException) {
                continue;
            }

            if (helpTextFieldMapping.isUsable()) {
                DataImportFieldMapping newDataImportFieldMapping =
                    new DataImportFieldMapping(helpTextFieldMapping);

                dataImportFieldMappings.add(newDataImportFieldMapping);

            } else if (helpTextFieldMapping.isPotentialMapping()) {
                badHelpTextMappings.add(helpTextFieldMapping);
            }
        }
    }

    /*******************************************************************************************************
    * @description Creates the corresponding Migrated Custom Field Mapping records
    * @param defaultFieldMappingDeveloperNames - list of Default Field Mapping records to reference
    */
    public void migrateNewDefaultToCustomMetadata(List<String> defaultFieldMappingDeveloperNames) {

        // clean deployment queueue 
        queuedMetadataTypesForDeploy.clear();        
        
        // aux var to store field mappings that needs migration 
        Map<String, Data_Import_Field_Mapping__mdt> referenceFieldMappingsByStrings =
                                            new Map<String, Data_Import_Field_Mapping__mdt>();

        // Collect current Default Field Mapping and Migrated Custom Field Mapping records
        Map<String, Data_Import_Field_Mapping__mdt> referenceFieldMappingsByFieldMappingKey =
                helper.getFieldMappingStringsBySetDeveloperName(DEFAULT_FIELD_MAPPING_SET_RECORD_NAME);
        Map<String, Data_Import_Field_Mapping__mdt> migratedFieldMappingsByFieldMappingKey =
                helper.getFieldMappingStringsBySetDeveloperName(MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);

        // Collect Default Field Mapping records of interest based on values passed in
        List<String> referenceFieldMappingKeys = helper.getFieldMappingKeysByDeveloperName(
                defaultFieldMappingDeveloperNames, DEFAULT_FIELD_MAPPING_SET_RECORD_NAME);

        for (String key : referenceFieldMappingKeys) {
            // If there is a match with the Migrated Field Mapping, do nothing
            if (migratedFieldMappingsByFieldMappingKey.containsKey(key)) {
                continue;
                // If no match is found, prepare to create the Migrated Field Mapping records
            } else {
                referenceFieldMappingsByStrings.put(key, referenceFieldMappingsByFieldMappingKey.get(key));
            }
        }

        // Create and enqueue Migrated Field Mapping records
        if (referenceFieldMappingsByStrings.size()>0) {

            // Collect Migrated Custom Object Mapping developer names
            Map<String, String> dataImportObjectDeveloperNameByLabel = 
                helper.getDataImportObjectDeveloperNamesByLabel();

            // get all default object mappings 
            Map<String, Data_Import_Object_Mapping__mdt> defaultObjectMappings =
                helper.getObjectMappingsBySetDeveloperName(DEFAULT_OBJECT_MAPPING_SET_RECORD_NAME);

            // create migrated fields
            for (Data_Import_Field_Mapping__mdt referenceFieldMapping : referenceFieldMappingsByStrings.values()) {

                // clone reference field
                Data_Import_Field_Mapping__mdt clone = referenceFieldMapping.clone();
                // get instance
                DataImportFieldMapping fieldMapping = new DataImportFieldMapping(
                        clone, MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);

                // set object mapping
                if (dataImportObjectDeveloperNameByLabel.size()>0) {

                    // if target object mapping does not exist - we need to create it                     
                    if (!dataImportObjectDeveloperNameByLabel.containsKey(fieldMapping.targetObjectMappingLabel)) {
                        // create missing mapping object && update dataImportObjectDeveloperNameByLabel variable                        
                        createAndEnqueueMigratedCustomObject(
                            fieldMapping.targetObjectMappingLabel, 
                            fieldMapping.targetObjectMappingRecordName, 
                            dataImportObjectDeveloperNameByLabel, 
                            defaultObjectMappings
                        );
                    }

                    // if target object mapping exists then do field migration
                    // Test.isRunningTest => is needed to support namespaced orgs and 
                    //                      STG_InstallScript_TEST given that has hardcoded list
                    if (dataImportObjectDeveloperNameByLabel.containsKey(fieldMapping.targetObjectMappingLabel) ||
                            Test.isRunningTest()) {

                        // get target object name
                        String existingObjectMappingDeveloperName =
                            dataImportObjectDeveloperNameByLabel.get(fieldMapping.targetObjectMappingLabel);
                        // set target object name
                        fieldMapping.setObjectMapping(
                            existingObjectMappingDeveloperName, 
                            fieldMapping.targetObjectMappingLabel
                        );                
                        // Set unique record name
                        fieldMapping.setRecordName(null, true);
                        
                        // Set all other values and add to queue
                        queuedMetadataTypesForDeploy.add(fieldMapping.getMetadataRecord());

                    }                                            

                }
            }
        }

        // Deploy new metadata record types
        if (queuedMetadataTypesForDeploy.size()>0) {
 	       CMT_MetadataAPI.deployMetadata(
                   queuedMetadataTypesForDeploy, new BDI_MigrationMappingUtility.DeploymentCallback());
        }
    }

    /*******************************************************************************************************
    * @description Creates and enqueues mising Migrated Custom Object Mapping records
    * @param targetObjectMappingLabel - label of target object mapping
    * @param targetObjectMappingRecordName - record-name of target object mapping
    * @param dataImportObjectDeveloperNameByLabel - existent migrated object mappings
    * @param defaultObjectMappings - existent default object mappings
    */
    private void createAndEnqueueMigratedCustomObject(String targetObjectMappingLabel, String targetObjectMappingRecordName, 
                                                        Map<String, String> dataImportObjectDeveloperNameByLabel,
                                                        Map<String, Data_Import_Object_Mapping__mdt> defaultObjectMappings) {     
        
        // get existent object mapping to use as reference (if exists)
        Data_Import_Object_Mapping__mdt rdObjectMapping = defaultObjectMappings!=null ? 
            defaultObjectMappings.get(targetObjectMappingRecordName):null;

        // if reference object mapping exists 
        if (rdObjectMapping!=null && !Test.isRunningTest()) { 

            // create instance of object mapping
            BDI_MigrationMappingUtility.DataImportObjectMapping diom = 
                new BDI_MigrationMappingUtility.DataImportObjectMapping(rdObjectMapping, true);                

            // get metadata object to be enqueued
            Metadata.CustomMetadata objectMetadata = diom.getMetadataRecord();
            // get unique migrated name using full name
            String uniqueName = objectMetadata.fullName;
            // split by '.' and get the last array node
            uniqueName =  uniqueName.split('\\.')[uniqueName.split('\\.').size()-1] ;

            // add new custom object mapping so we can process fields for the same object
            dataImportObjectDeveloperNameByLabel.put(targetObjectMappingLabel,uniqueName);

            // enqueue object to deploy
            queuedMetadataTypesForDeploy.add(objectMetadata);

        }        
    }

    /*******************************************************************************************************
    * @description Creates the Migrated Custom Field Mapping Set and adds to queuedMetadataTypesForDeploy
    */
    private void createAndEnqueueMigratedCustomFieldMappingSet() {
        if (fieldMappingSetName == DEFAULT_FIELD_MAPPING_SET_RECORD_NAME) {

            DataImportFieldMappingSet fieldMappingSet =
                new DataImportFieldMappingSet(
                    MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME,
                    MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME);

            queuedMetadataTypesForDeploy.add(fieldMappingSet.getMetadataRecord());
        }
    }

    /*******************************************************************************************************
    * @description Creates the Migrated Custom Object Mapping Set and adds to queuedMetadataTypesForDeploy
    */
    private void createAndEnqueueMigratedCustomObjectMappingSet() {
        Metadata.CustomMetadata objectMappingSetMDT = new Metadata.CustomMetadata();
        String mdTypeName = Data_Import_Object_Mapping_Set__mdt.SObjectType.getDescribe().getName();

        objectMappingSetMDT.label = MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME.replace('_', ' ');
        objectMappingSetMDT.fullName = mdTypeName + '.' + MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME;
        objectMappingSetMDT.protected_x = false;

        queuedMetadataTypesForDeploy.add(objectMappingSetMDT);
    }

    /*******************************************************************************************************
    * @description Method for converting non help text mapped standard field mappings to Custom Metadata
    * records and adds to queuedMetadataTypesForDeploy
    *
    * @param fieldMappingSetName String Name of the parent Data Import Field Mapping Set
    */
    private void createAndEnqueueNonHelpTextMappings(
        Map<String, Data_Import_Field_Mapping__mdt> referenceFieldMappings,
        Map<String, Data_Import_Field_Mapping__mdt> migratedFieldMappings) {

        for (String key : referenceFieldMappings.keySet()) {
            Data_Import_Field_Mapping__mdt referenceFieldMapping = referenceFieldMappings.get(key);
            Data_Import_Field_Mapping__mdt migratedFieldMapping = migratedFieldMappings.get(key);

            if (referenceFieldMapping != null) {
                Data_Import_Field_Mapping__mdt clone = referenceFieldMapping.clone();
                String existingObjectMappingDeveloperName =
                    legacyDataImportObjectNameByDeveloperName.get(
                        referenceFieldMapping.Target_Object_Mapping__r.DeveloperName);

                DataImportFieldMapping fieldMapping =
                    new DataImportFieldMapping(clone, MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);

                fieldMapping.setFieldMappingSet(MIGRATED_CUSTOM_FIELD_MAPPING_SET_RECORD_NAME);
                fieldMapping.setObjectMapping(
                    existingObjectMappingDeveloperName,
                    fieldMapping.dataImportObjectName);

                if (migratedFieldMapping != null) {
                    fieldMapping.setRecordName(migratedFieldMapping.DeveloperName, false);
                } else {
                    fieldMapping.setRecordName(null, false);
                }

                queuedMetadataTypesForDeploy.add(fieldMapping.getMetadataRecord());
            }
        }
    }

    /*******************************************************************************************************
    * @description Inserting or Updating CMT's through the Apex Metadata API is an asynchronous process. This callback
    * class is used to handle the async response from the call to Metadata.Operations.enqueueDeployment().
    * An instance of this class gets passed into the deployment call from
    * STG_PanelDataImportAdvancedMapping_CTRL.enableDataImportFieldMapping()
    */
    public class DeploymentCallback implements Metadata.DeployCallback {

        /*******************************************************************************************************
        * @description Method called by salesforce with the result of the Metadata deployment operation status.
        * This will write the status of the deployment to Data Import custom settings
        */
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {

            if (result != null && result.status == Metadata.DeployStatus.SUCCEEDED) {
                // Deployment was successful
                BDI_MigrationMappingUtility.updateCustomSettings(DATA_IMPORT_FIELD_MAPPING,
                    String.valueOf(result.status));

            } else if (result != null && result.status != Metadata.DeployStatus.SUCCEEDED) {
                // Deployment was not successful
                String errMsg = '';
                for (Integer n=0; n < result.details.componentFailures.size(); n++) {
                    errMsg += (n > 0 ? '\n' : '') + '* ' + result.details.componentFailures[n].fullName +
                            '> ' + result.details.componentFailures[n].problem;
                }

                BDI_MigrationMappingUtility.updateCustomSettings(HELP_TEXT, errMsg);
                if (!Test.isRunningTest()) {
                    throw new DeploymentException(Label.bdiErrorDeploymentFailed);
                }

            } else {
                // Deployment was not successful and result is null
                BDI_MigrationMappingUtility.updateCustomSettings(HELP_TEXT, 'Unknown error');
                if (!Test.isRunningTest()) {
                    throw new DeploymentException(Label.bdiErrorDeploymentFailed);
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description Wrapper class for Data_Import_Field_Mapping_Set__mdt used to create
    * the custom CMT data as well as for use in the Custom UI.
    */
    public class DataImportFieldMappingSet {
        public String recordName;
        public String label;
        public String dataImportObjectMappingSetRecordName;

        public DataImportFieldMappingSet(String label, String dataImportObjectMappingSetRecordName) {
            this.label = label.trim();
            this.dataImportObjectMappingSetRecordName = dataImportObjectMappingSetRecordName;
        }

        public Metadata.CustomMetadata getMetadataRecord() {
            String mdTypeName = Data_Import_Field_Mapping_Set__mdt.SObjectType.getDescribe().getName();

            // Setup custom metadata to be created or updated in the subscriber org.
            Metadata.CustomMetadata customMd = new Metadata.CustomMetadata();
            customMd.label = this.label.left(40);
            this.recordName = this.label;
            customMd.fullName = mdTypeName + '.' + this.recordName.left(40).removeEnd('_');
            customMd.protected_x = false;

            Map<String, Object> fieldValues = new Map<String, Object>{
                'Data_Import_Object_Mapping_Set__c' => this.dataImportObjectMappingSetRecordName
            };
            customMd = CMT_MetadataAPI.addFieldsToMetadataObject(customMd, fieldValues);

            return customMd;
        }
    }

    /*******************************************************************************************************
    * @description Class for to store properties of the Object Mapping 
    */
    public class DataImportObjectMapping {
        Data_Import_Object_Mapping__mdt objectMapping;
        String uniqueRecordName;
        String predecessor;
        Boolean isReference;

        public DataImportObjectMapping() {}

        public DataImportObjectMapping(Data_Import_Object_Mapping__mdt objectMapping, Boolean isReference) {
            this.isReference = isReference;
            this.objectMapping = objectMapping;
            this.predecessor = objectMapping.Predecessor__c;
            if (objectMapping.Predecessor__c == null &&
                objectMapping.Relationship_To_Predecessor__c == null) {
                objectMapping.Relationship_To_Predecessor__c = null;
            }
            this.uniqueRecordName = generateUniqueRecordName(objectMapping.DeveloperName);
        }

        public Metadata.CustomMetadata getMetadataRecord() {
            String mdTypeName = Data_Import_Object_Mapping__mdt.SObjectType.getDescribe().getName();

            Data_Import_Object_Mapping__mdt clone = objectMapping.clone();

            Map<String, Object> fieldValues =
                (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(clone));

            fieldValues.remove(UTIL_Namespace.StrAllNSPrefix('attributes'));
            fieldValues.remove(UTIL_Namespace.StrAllNSPrefix('DeveloperName'));
            fieldValues.remove(UTIL_Namespace.StrAllNSPrefix('Label'));

            fieldValues.put(
                UTIL_Namespace.StrAllNSPrefix('Data_Import_Object_Mapping_Set__c'),
                MIGRATED_CUSTOM_OBJECT_MAPPING_SET_RECORD_NAME);

            fieldValues.put(
                UTIL_Namespace.StrAllNSPrefix('Legacy_Data_Import_Object_Name__c'),
                (isReference ? clone.DeveloperName : clone.Legacy_Data_Import_Object_Name__c)
            );

            Metadata.CustomMetadata customMd = new Metadata.CustomMetadata();
            customMd.label = clone.label.left(40);
            customMd.fullName = mdTypeName + '.' + uniqueRecordName.left(40);
            customMd.protected_x = false;

            customMd = CMT_MetadataAPI.addFieldsToMetadataObject(customMd, fieldValues);

            return customMd;
        }

        /****************************************************************************************************
        * @description Utility to convert a name into a valid 'DeveloperName' quality value (or unique GUID)
        * for the CMT record
        *
        * @param name String
        * @param makeUnique Boolean
        * @return DeveloperName format string
        */
        private String generateUniqueRecordName(String recordName) {

            recordName = recordName.replace(' ', '_');

            if (recordName.length() > 30) {
                String firstFifteen = recordName.substring(0, 15);
                String lastFifteen = recordName.substring(recordName.length() - 15, recordName.length());
                recordName = firstFifteen + lastFifteen;
            }

            // Create a GUID format unique string
            Blob b = Crypto.GenerateAESKey(128);
            String h = EncodingUtil.ConvertTohex(b);
            // force everything to have a 9-char random string at the end
            recordName = recordName.left(30).removeEnd('_') + '_' + h.left(9);

            recordName = recordName.replaceAll('[^\\w]+', '_').replaceAll('_{2,}', '_');
            return recordName;
        }
    }

    /*******************************************************************************************************
    * @description Wrapper class for Data_Import_Field_Mapping__mdt used to create
    * the default CMT data as well as for use in the Custom UI.
    */
    public class DataImportFieldMapping {
        public String recordName;
        public String label {get; set;}
        public String dataImportObjectName {get; set;}
        public String dataImportFieldMappingSetRecordName;
        public String dataImportFieldMappingSetLabel;
        public String sourceFieldAPIName;
        public String targetFieldAPIName {get; set;}
        public String targetObjectMappingRecordName;
        public String targetObjectMappingLabel;
        public String targetObjectAPIName;
        public String isRequired;
        public Boolean isDeleted;
        public String importedRecordField;
        public String importedRecordStatusField;

        public DataImportFieldMapping() {}

        public DataImportFieldMapping(HelpTextFieldMapping helpTextMapping) {
            this.label = helpTextMapping.dataImportFieldName.trim();
            this.sourceFieldAPIName = helpTextMapping.dataImportFieldAPIName;
            this.dataImportObjectName = helpTextMapping.dataImportObjectName;
            this.targetFieldAPIName = helpTextMapping.targetFieldAPIName;
            this.targetObjectAPIName = helpTextMapping.targetObjectAPIName;
            this.isRequired = helpTextMapping.isRequired;
        }

        public DataImportFieldMapping(
            Data_Import_Field_Mapping__mdt sourceFieldMapping, String fieldMappingSet) {

            this.dataImportFieldMappingSetRecordName = fieldMappingSet;
            this.label = sourceFieldMapping.MasterLabel;
            this.sourceFieldAPIName = sourceFieldMapping.Source_Field_API_Name__c;
            this.targetFieldAPIName = sourceFieldMapping.Target_Field_API_Name__c;
            this.targetObjectMappingRecordName = sourceFieldMapping.Target_Object_Mapping__r.DeveloperName;
            this.targetObjectMappingLabel = sourceFieldMapping.Target_Object_Mapping__r.MasterLabel;
            this.dataImportObjectName =
                sourceFieldMapping.Target_Object_Mapping__r.Legacy_Data_Import_Object_Name__c;
            this.targetObjectAPIName = sourceFieldMapping.Target_Object_Mapping__r.Object_API_Name__c;
            this.recordName = sourceFieldMapping.DeveloperName;
            this.isRequired = sourceFieldMapping.Required__c;
            this.isDeleted = false;
        }

        public String getKey() {
            return this.targetObjectAPIName + '.' +
                this.dataImportObjectName + '.' +
                this.sourceFieldAPIName;
        }

        public void setFieldMappingSet(String fieldMappingSetName) {
            this.dataImportFieldMappingSetRecordName = fieldMappingSetName;
        }

        public void setObjectMapping(String objectMappingDeveloperName, String objectMappingLabel) {
            this.targetObjectMappingLabel = objectMappingLabel;
            this.targetObjectMappingRecordName = objectMappingDeveloperName;
        }

        public void setTargetField(String targetFieldAPIName) {
            this.targetFieldAPIName = targetFieldAPIName;
        }

        public void setRecordName(String recordName, Boolean isUnique) {
            if (isUnique) {
                this.recordName = generateRecordName(
                    this.label,
                    true,
                    this.targetObjectMappingLabel,
                    this.dataImportObjectName);
            } else {
                this.recordName = recordName;
            }
        }

        public Boolean hasBadDefaultValues(Data_Import_Field_Mapping__mdt existingFieldMapping) {
            Boolean badSourceFieldAPIName =
                (existingFieldMapping.Source_Field_API_Name__c != this.sourceFieldAPIName);
            Boolean badTargetFieldAPIName =
                (existingFieldMapping.Target_Field_API_Name__c != this.targetFieldAPIName);
            Boolean badTargetObjectMapping =
                (existingFieldMapping.Target_Object_Mapping__r.DeveloperName !=
                    this.targetObjectMappingRecordName);

            return badSourceFieldAPIName || badTargetFieldAPIName || badTargetObjectMapping;
        }

        public Metadata.CustomMetadata getMetadataRecord() {
            String mdTypeName = Data_Import_Field_Mapping__mdt.SObjectType.getDescribe().getName();

            // Setup custom metadata to be created or updated in the subscriber org.
            Metadata.CustomMetadata customMd = new Metadata.CustomMetadata();

            if (this.targetObjectMappingLabel != null && this.dataImportObjectName != null) {
                customMd.label = this.label.replace(
                    this.dataImportObjectName,
                    this.targetObjectMappingLabel).left(40);
            }

            if (this.recordName == null) {
                this.recordName = generateRecordName(
                    this.label,
                    true,
                    this.targetObjectMappingLabel,
                    this.dataImportObjectName);
            }

            customMd.fullName = mdTypeName + '.' + this.recordName.left(40).removeEnd('_');
            customMd.protected_x = false;

            // Convert an empty string ('') value into null for the entity reference to save properly.
            if (String.isEmpty(this.dataImportFieldMappingSetRecordName)) {
                this.dataImportFieldMappingSetRecordName = null;
            }

            // Convert an empty string ('') value into null for the entity reference to save properly.
            if (String.isEmpty(this.targetObjectMappingRecordName)) {
                this.targetObjectMappingRecordName = null;
            }

            Map<String, Object> fieldValues;
            if (this.isDeleted != true) {

                if (UTIL_Namespace.shouldAlignNamespace) {
                    this.targetFieldAPIName =
                        UTIL_Namespace.alignSchemaNSWithEnvironment(this.targetFieldAPIName);
                }

                fieldValues = new Map<String, Object>{
                    'Data_Import_Field_Mapping_Set__c' => dataImportFieldMappingSetRecordName == null ? 'Default_Field_Mapping_Set' : dataImportFieldMappingSetRecordName,
                    'Required__c' => isRequired,
                    'Source_Field_API_Name__c' => sourceFieldAPIName,
                    'Target_Field_API_Name__c' => targetFieldAPIName,
                    'Target_Object_Mapping__c' => targetObjectMappingRecordName,
                    'Is_Deleted__c' => isDeleted
                };
            } else {
                fieldValues = new Map<String, Object>{ 'Is_Deleted__c' => isDeleted };
            }
            customMd = CMT_MetadataAPI.addFieldsToMetadataObject(customMd, fieldValues);

            return customMd;
        }

        /****************************************************************************************************
        * @description Utility to convert a name into a valid 'DeveloperName' quality value (or unique GUID)
        * for the CMT record
        *
        * @param name String
        * @param makeUnique Boolean
        * @return DeveloperName format string
        */
        private String generateRecordName(String name, Boolean makeUnique, String objectLabel, String objectAPIName) {

            if (String.isNotBlank(objectLabel)) {
                objectLabel = objectLabel.replace(' ', '_');
                name = name.replace(objectAPIName, objectLabel);
            }

            if (name.length() > 30) {
                String firstFifteen = name.substring(0, 15);
                String lastFifteen = name.substring(name.length() - 15, name.length());
                name = firstFifteen + lastFifteen;
            }

            if (makeUnique == true) {
                // Create a GUID format unique string
                Blob b = Crypto.GenerateAESKey(128);
                String h = EncodingUtil.ConvertTohex(b);
                // force everything to have a 9-char random string at the end
                name = name.left(30).removeEnd('_') + '_' + h.left(9);
            } else {
                name = name.left(40);
            }

            name = name.replaceAll('[^\\w]+', '_').replaceAll('_{2,}', '_');
            return name;
        }
    }

    /*******************************************************************************************************
    * @description Wrapper class for help text field
    */
    public class HelpTextFieldMapping {
        public Boolean isUsable = false;
        public Boolean isPotentialMapping = false;
        private Boolean isFieldNameUsable = false;
        private Boolean isObjectNameUsable = false;
        private Boolean isObjectAPINameUsable = false;
        private String isRequired = '';
        public String dataImportObjectName;
        public String targetObjectAPIName;
        public String targetFieldAPIName;
        public String dataImportFieldName { get;set; }
        public String dataImportFieldAPIName { get;set; }
        public String helpText { get;set; }
        private final UTIL_Describe describeService = UTIL_Describe.getInstance();
        private final Set<String> LEGACY_DATA_IMPORT_OBJECT_NAMES = new Set<String> {
            'account1', 'account2', 'address', 'contact1', 'contact2',
                'household','opportunity','donation','payment','gau','role'};

        public HelpTextFieldMapping() {}

        public HelpTextFieldMapping(Schema.DescribeFieldResult dfr) {
            this.dataImportFieldName = dfr.Label;
            this.dataImportFieldAPIName = dfr.Name;
            this.helpText = describeService.getHelpText(dfr.getSobjectField());
            this.isRequired = dfr.isNillable() ? 'No' : 'Yes';

            if (this.helpText != null) {

                List<String> mappingValuesFromHelpText = retrieveObjectAndFieldApiNames(this.helpText);
                if (mappingValuesFromHelpText != null) {
                    this.dataImportObjectName = mappingValuesFromHelpText[0];
                    this.targetFieldAPIName =
                        UTIL_Namespace.shouldAlignNamespace ?
                            UTIL_Namespace.alignSchemaNSWithEnvironment(mappingValuesFromHelpText[1]) :
                            mappingValuesFromHelpText[1];

                    checkRequiredFields();
                }
            }
        }

        /*******************************************************************************************************
        * @description Retrieves an object and field api name from a DataImport__c field help text mapping.
        *
        * @param helpText Help text value of a DataImport__c field
        * @return A list of strings containing an object api name and a field api name OR null if help text
        * value doesn't contain a valid help text mapping.
        */
        private List<String> retrieveObjectAndFieldApiNames(String helpText) {
            if (helpText.contains('.')) {
                List<String> parts = helpText.trim().split('\\.', 2);

                if (parts.size() == 2) {
                    String possibleObjectApiName = parts[0];
                    String possibleFieldApiName = parts[1];
                    Boolean isLegacyObjectApiName =
                        LEGACY_DATA_IMPORT_OBJECT_NAMES.contains(possibleObjectApiName.toLowerCase());
                    Boolean isPossibleFieldApiName = !possibleFieldApiName.contains(' ');

                    if (isLegacyObjectApiName && isPossibleFieldApiName) {
                        return parts;
                    }
                }
            }

            return null;
        }

        private void checkRequiredFields() {
            this.isObjectNameUsable = String.isNotBlank(this.dataImportObjectName);
            if (String.isNotBlank(this.dataImportObjectName)) {
                this.targetObjectAPIName = DI_OBJECT_MAP.get(this.dataImportObjectName);
            }
            this.isObjectAPINameUsable = String.isNotBlank(this.targetObjectAPIName);
            if (this.isObjectAPINameUsable && String.isNotBlank(this.targetFieldAPIName)) {
                Set<String> validFields = getValidFieldsByObjectName(this.targetObjectAPIName);
                this.isFieldNameUsable = validFields.contains(this.targetFieldAPIName.toLowerCase());
            }
        }

        public Boolean isUsable() {
            if (Test.isRunningTest()) {
                checkRequiredFields();
            }
            return this.isFieldNameUsable && this.isObjectNameUsable && this.isObjectAPINameUsable;
        }

        private Boolean isPotentialMapping() {
            if (Test.isRunningTest()) {
                checkRequiredFields();
            }
            return this.isObjectNameUsable && String.isNotBlank(this.targetFieldAPIName);
        }

        public Set<String> getValidFieldsByObjectName(String objectName) {
            if (validFieldsByObjectName == null) {
                validFieldsByObjectName = new Map<String, Set<String>>();
            }

            if (validFieldsByObjectName.get(objectName) == null) {
                SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
                Set<String> validFields = objectType.getDescribe().fields.getMap().keySet();
                validFieldsByObjectName.put(objectName, validFields);

                return validFields;
            } else {
                return validFieldsByObjectName.get(objectName);
            }
        }

        /****************************************************************************************************
        * @description Map of legacy help text field data import object names to object api names
        */
        private final Map<String, String> DI_OBJECT_MAP = new Map<String, String>{
            'Account1' => 'Account',
            'Account2' => 'Account',
            'Address' => UTIL_Namespace.StrTokenNSPrefix('Address__c'),
            'Contact1' => 'Contact',
            'Contact2' => 'Contact',
            'Household' => 'Account',
            'Opportunity' => 'Opportunity',
            'Donation' => 'Opportunity',
            'Payment' => 'npe01__OppPayment__c'
        };
    }

    /*******************************************************************************************************
    * @description an exception object wrapper for migration utility
    */
    private class DeploymentException extends Exception {}

} // BDI_MigrationMappingUtility
