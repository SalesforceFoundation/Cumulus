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
* @description Implements the ability to import additional objects during batch data import.
*/

public with sharing class BDI_AdditionalObjectService {

    /*******************************************************************************************************
    * @description the data import service we are invoked from
    */
    private BDI_DataImportService dataImportService;
    private BDI_MappingServiceAdvanced mappingServiceAdvanced;

    private Map<Integer,Map<String,BDI_ObjectMapping>> objMappingsByTier = 
        new Map<Integer,Map<String,BDI_ObjectMapping>>();
    private Map<String,Map<String,BDI_ObjectMapping>> successorObjMappingsByPredecessorName = 
        new Map<String,Map<String,BDI_ObjectMapping>>();
    private Set<String> importedRecordFieldNames = new Set<String>();
    public Set<String> dynamicSourceFields = 
        new Set<String>{DataImport__c.Additional_Object_JSON__c.getDescribe().getName()};

    private Map<Id,Map<String,BDI_DynamicSourceGroup>> dynamicSourceGroupByNameByDataImportId = 
        new Map<Id,Map<String,BDI_DynamicSourceGroup>>();

    public Set<String> objMappingDevNames = new Set<String>();

    /*******************************************************************************************************
    * @description Constructor
    * @param dataImportService The data import service instance that invokes us
    */
    public BDI_AdditionalObjectService(BDI_DataImportService dataImportService) {
        this.dataImportService = dataImportService;
        this.mappingServiceAdvanced = BDI_MappingServiceAdvanced.getInstance();
    }


    /*******************************************************************************************************
    * @description Main method to call to begin the additional object import process.
    */
    public void importAdditionalObjects(){

        prepareDynamicSourceDataForAllDIs();
        generateTiersOfObjectMappings();

        //Iterate through the map of tiers, starting with the first tier that actually has a predecessor 
        //(ie 2nd tier), and validate and create each object as appropriate.
        for (Integer i = 1; i < objMappingsByTier.size(); i++) {

            Map<String,BDI_ObjectMapping> currentTier = objMappingsByTier.get(i);

            DataImport__c[] disWithoutFailure = new DataImport__c[]{};

            // Removing DIs that have already failed from the list since it is likely that it will fail due 
            // to predecessors not existing anyway.
            for (DataImport__c dataImport : dataImportService.listDI) {
                if(dataImport.Status__c != BDI_DataImport_API.bdiFailed){
                    disWithoutFailure.add(dataImport);
                }
            }

            //for the current tier of object mappings, validate and populate object wrappers for later processing.
            Map<String,BDI_ObjectWrapper[]> objAPINameToObjWraps = 
                prepareObjectWrappers(currentTier,disWithoutFailure);

            // if this is not a dry run then perform the insert/update of the object wrappers.
            if (!dataImportService.isDryRun) {
                importObjectWrappers(objAPINameToObjWraps);
            }
        }

        updateDIwithDynamicSourceGroups();
    }

    /*******************************************************************************************************
    * @description Prepares object wrappers for a given tier of object mappings and data import records.
    * @param currentTierOfObjMappings a list of object mappings that are all on the same level of the object 
    *    hierarchy
    * @param dataImportRecords the data import records that the preparation should be performed on.
    */

    private Map<String,BDI_ObjectWrapper[]> prepareObjectWrappers (
        Map<String,BDI_ObjectMapping> currentTierOfObjMappings, 
        DataImport__c[] dataImportRecords) {

        Map<String,BDI_ObjectWrapper[]> objAPINameToObjWraps = new Map<String,BDI_ObjectWrapper[]>();

        if (currentTierOfObjMappings != null) {
            for (BDI_ObjectMapping objMapping : currentTierOfObjMappings.values()) {

                BDI_ObjectMappingLogic objMappingLogic = getObjectMappingLogicClass(objMapping);

                BDI_ObjectMapping predecessor = 
                    mappingServiceAdvanced.objectMappingByDevName.get(objMapping.Predecessor);
                BDI_FieldMapping[] fieldMappings = 
                    mappingServiceAdvanced.fieldMappingsByObjMappingDevName.get(objMapping.DeveloperName);

                //Only proceed if at least one field mapping exists
                if (fieldMappings != null && fieldMappings.size() > 0) {

                    BDI_ObjectWrapper[] objWrapsForProcessing = new BDI_ObjectWrapper[]{};
                    for (DataImport__c dataImport : dataImportRecords) {

                        BDI_DynamicSourceGroup dsg;
                        BDI_DynamicSource ds;

                        if (objMapping.dynamicSourceField != null && objMapping.dynamicSourceField.length() > 0) {
                            dsg = retrieveDynamicSourceDataForDI(dataImport,objMapping.dynamicSourceField);
                            if (dsg.name != null) {
                               ds = dsg.dynamicSourceByObjMappingDevName.get(objMapping.DeveloperName);
                            }
                        }

                        BDI_ObjectWrapper objWrap = new BDI_ObjectWrapper(
                            dataImport,objMapping,fieldMappings,predecessor,ds);

                        //blank out any existing value in the status field for this object mapping
                        objWrap.setImportedRecordStatus('');

                        //If the imported record field for the object is not populated then create a new SObject, 
                        //otherwise update existing.
                        if (objWrap.getImportedRecordId() == null) {

                            //If there are no fields populated or required fields are not populated for this object 
                            //mapping then ignore this dataImport and continue.
                            if (!validateFields(objWrap)) {
                                continue;
                            }

                            //If the predecessor doesn't exist, then update the Data import object with an error 
                            //and continue with the next dataImport.
                            if (!predecessorExists(objWrap,predecessor)) {
                                continue;
                            }

                        } else { 

                            //If there is an existing record then we don't need to perform the normal validation 
                            // and can proceed to populating the record with any non-null values.
                            objWrap.existingSObjectId = objWrap.getImportedRecordId();

                        }

                        objWrapsForProcessing.add(objWrap);
                    }

                    if (!dataImportService.isDryRun && objWrapsForProcessing.size() > 0) {
                        objWrapsForProcessing = objMappingLogic.populateObjects(objWrapsForProcessing);

                        for (BDI_ObjectWrapper objWrap : objWrapsForProcessing) {

                            // If the SObject in the objWrap is not null then add it to the map of object wraps by 
                            // SObject type to upsert. They are grouped by object api name so that we only need to 
                            // do one upsert per object per tier.
                            if (objWrap.sObj != null) {
                                if (objAPINameToObjWraps.get(objMapping.Object_API_Name) != null) {
                                    objAPINameToObjWraps.get(objMapping.Object_API_Name).add(objWrap);
                                } else {
                                    objAPINameToObjWraps.put(objMapping.Object_API_Name,
                                        new BDI_ObjectWrapper[]{objWrap});
                                }
                            }
                        }
                    }
                }
            }
        }

        return objAPINameToObjWraps;
    }

    /*******************************************************************************************************
    * @description Takes a map of SObject api name to the object wrappers for that SObject and either updates 
    *  or inserts the data.
    * @param objAPINameToObjWraps map of SObject api name to object wrappers.
    */

    private void importObjectWrappers (Map<String,BDI_ObjectWrapper[]> objAPINameToObjWraps) {
        //If there are any records to create, then combine them into lists for update
        if (objAPINameToObjWraps.size() > 0) {

            BDI_ObjectWrapper[] objWrapsForChildPredecessorUpdate = new BDI_ObjectWrapper[]{};

            List<BDI_ObjectWrapper[]> objWrapsForUpdateList = new List<BDI_ObjectWrapper[]>();
            BDI_ObjectWrapper[] currentObjWrapsForUpdate = new BDI_ObjectWrapper[]{};

            List<BDI_ObjectWrapper[]> objWrapsForInsertList = new List<BDI_ObjectWrapper[]>();
            BDI_ObjectWrapper[] currentObjWrapsForInsert = new BDI_ObjectWrapper[]{};

            List<SObject[]> sObjsForUpdateLists = new List<SObject[]>();
            SObject[] currentSObjectForUpdateList = new SObject[]{};

            List<SObject[]> sObjsForInsertLists = new List<SObject[]>();
            SObject[] currentSObjectForInsertList = new SObject[]{};

            Integer objTypeCount = 1;
            for (String objApiName : objAPINameToObjWraps.keySet()) {

                BDI_ObjectWrapper[] objWraps = objAPINameToObjWraps.get(objApiName);

                for (BDI_ObjectWrapper objWrap : objWraps) {
                    if (objWrap.sObj.Id != null) {
                        currentSObjectForUpdateList.add(objWrap.sObj);
                        currentObjWrapsForUpdate.add(objWrap);
                    } else {
                        currentSObjectForInsertList.add(objWrap.sObj);
                        currentObjWrapsForInsert.add(objWrap);
                    }
                }

                //If the loop is on its 10th run then add the lists to the array 
                // and start a new list and reset the counter.
                if (objTypeCount == 10) {
                    sObjsForUpdateLists.add(currentSObjectForUpdateList);
                    currentSObjectForUpdateList = new SObject[]{};

                    objWrapsForUpdateList.add(currentObjWrapsForUpdate);
                    currentObjWrapsForUpdate = new BDI_ObjectWrapper[]{};

                    sObjsForInsertLists.add(currentSObjectForInsertList);
                    currentSObjectForInsertList = new SObject[]{};

                    objWrapsForInsertList.add(currentObjWrapsForInsert);
                    currentObjWrapsForInsert = new BDI_ObjectWrapper[]{};

                    objTypeCount = 1;
                } else {
                    objTypeCount++;
                }
            }

            sObjsForUpdateLists.add(currentSObjectForUpdateList);
            objWrapsForUpdateList.add(currentObjWrapsForUpdate);

            sObjsForInsertLists.add(currentSObjectForInsertList);
            objWrapsForInsertList.add(currentObjWrapsForInsert);

            for (Integer i = 0; i < sObjsForUpdateLists.size(); i++) {

                SObject[] sObjsForUpdate = sObjsForUpdateLists[i];
                BDI_ObjectWrapper[] objWrapsForUpdate = objWrapsForUpdateList[i];

                if (sObjsForUpdate.size() > 0) {
                    Database.SaveResult[] updateSaveResults = UTIL_DMLService.updateRecords(sObjsForUpdate,false);
                    
                    // Cycle through all the upsert results and update the data import records with status 
                    // appropriately.
                    for (Integer t = 0; t < updateSaveResults.size(); t++) {
                        Database.SaveResult result = updateSaveResults[t];

                        BDI_ObjectWrapper objWrap = objWrapsForUpdate[t];

                        if (result.isSuccess()) {
                            objWrap.setImportedRecordStatus(System.label.bdiUpdated);
                        } else {
                            logError(objWrap, result.getErrors()[0].getMessage());
                        }
                    }
                }        
            }


            for (Integer i = 0; i < sObjsForInsertLists.size(); i++) {

                SObject[] sObjsForInsert = sObjsForInsertLists[i];
                BDI_ObjectWrapper[] objWrapsForInsert = objWrapsForInsertList[i];

                if (sObjsForInsert.size() > 0) {
                    Database.SaveResult[] insertSaveResults = UTIL_DMLService.insertRecords(sObjsForInsert,false);

                    // Cycle through all the upsert results and update the data import records with status 
                    // appropriately.
                    for (Integer t = 0; t < insertSaveResults.size(); t++) {
                        Database.SaveResult result = insertSaveResults[t];

                        BDI_ObjectWrapper objWrap = objWrapsForInsert[t];

                        if (result.isSuccess()) {
                            objWrap.setImportedRecordStatus(System.Label.bdiCreated);
                            objWrap.setImportedRecordId(objWrap.sObj.Id);

                            // If the newly created sobject is a parent to its predecesssor, then
                            // add it to a list for updating child predcessors.
                            if (objWrap.objMapping.Relationship_To_Predecessor == 'Parent') { 
                                objWrapsForChildPredecessorUpdate.add(objWrap);
                            }
                        } else {
                            logError(objWrap, result.getErrors()[0].getMessage());
                        }
                    }
                }
            }

            if (objWrapsForChildPredecessorUpdate.size() > 0) {
                updateChildPredecessorRecords(objWrapsForChildPredecessorUpdate);
            }
        }
    }


    /*******************************************************************************************************
    * @description Iterates through the in context list of Data Import records and calls a method to extract
    * the Dynamic Source info for each Data Import record and dynamic source field combination.
    */
    private void prepareDynamicSourceDataForAllDIs() {

        for (DataImport__c dataImport : dataImportService.listDI) {
            for (String dynamicSourceField : dynamicSourceFields) {
                retrieveDynamicSourceDataForDI(dataImport, dynamicSourceField);
            }
        }
    }

    /*******************************************************************************************************
    * @description For a given data import record and dynamic source field, this method extracts the 
    * dynamic source group and calls a method to create temporary dynamic mappings as needed.
    * @param di The DataImport__c record to extract Dynamic sources from.
    * @param dynamicSourceField the field on the DI to look into for the JSON string.
    */
    private BDI_DynamicSourceGroup retrieveDynamicSourceDataForDI(DataImport__c di, String dynamicSourceField) {

        BDI_DynamicSourceGroup dsg;
        Map<String,BDI_DynamicSourceGroup> dynamicSourceGroupByName = new Map<String,BDI_DynamicSourceGroup>();

        //Retrieve and return an existing DynamicSourceGroup if already present in the map.
        if(dynamicSourceGroupByNameByDataImportId.get(di.Id) != null) {
            dynamicSourceGroupByName = dynamicSourceGroupByNameByDataImportId.get(di.Id);
            if (dynamicSourceGroupByName.get(dynamicSourceField) != null) {
                return dynamicSourceGroupByName.get(dynamicSourceField);
            }
        }

        //Attempt to deserialize the target field, and store in the map if there was data.
        dsg = new BDI_DynamicSourceGroup();
        dsg.deserialize(di, dynamicSourceField);

        if (dsg.name != null) {
            dynamicSourceGroupByName.put(dsg.name,dsg);
            dynamicSourceGroupByNameByDataImportId.put(di.Id,dynamicSourceGroupByName);
            createTemporaryDynamicMappings(dsg);
        }

        return dsg;
    }

    /*******************************************************************************************************
    * @description Inspects the dynamic sources included in the DynamicSourceGroup and creates temporary
    * copies of Object mappings for each based on the defined template object mapping and stores them in 
    * maps in the current instance of the BDI_MappingServiceAdvanced.
    * @param dsg The dynamic source group that should be examined to create temporary mappings for.
    */
    private void createTemporaryDynamicMappings(BDI_DynamicSourceGroup dsg) {
        //Create temporary object and field mappings for the dynamic additional objects based on the
        //template provided if not already created.
        for (String objMappingDevName : dsg.dynamicSourceByObjMappingDevName.keySet()) {

            if (mappingServiceAdvanced.objectMappingByDevName.get(objMappingDevName) == null) {
                BDI_DynamicSource ds = dsg.dynamicSourceByObjMappingDevName.get(objMappingDevName);

                BDI_ObjectMapping templateObjMapping = 
                    mappingServiceAdvanced.objectMappingByDevName.get(ds.objectMappingTemplateDevName);

                BDI_ObjectMapping newObjMapping = new BDI_ObjectMapping(templateObjMapping,objMappingDevName);
                newObjMapping.dynamicSourceField = dsg.name;

                BDI_FieldMapping[] fms = 
                    mappingServiceAdvanced.fieldMappingsByObjMappingDevName.get(ds.objectMappingTemplateDevName);

                mappingServiceAdvanced.objectMappingByDevName.put(objMappingDevName,newObjMapping);
                mappingServiceAdvanced.fieldMappingsByObjMappingDevName.put(objMappingDevName,fms);
            }
        }
    }

    /*******************************************************************************************************
    * @description updates the Dynamic source fields on the Data Import object with the updated DynamicSourceGroup
    * values.
    */
    private void updateDIwithDynamicSourceGroups(){

        for (DataImport__c dataImport : dataImportService.listDI) {

            if (dynamicSourceGroupByNameByDataImportId.get(dataImport.Id) != null) {
                Map<String,BDI_DynamicSourceGroup> dynamicSourceGroupByName = 
                    dynamicSourceGroupByNameByDataImportId.get(dataImport.Id);

                for (String dynamicSourceFieldName : dynamicSourceGroupByName.keySet()){
                    dataImport.put(dynamicSourceFieldName,
                        JSON.serialize(dynamicSourceGroupByName.get(dynamicSourceFieldName)));
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description Determines if there is a custom mapping logic class and constructs it if there is, 
    *   otherwise returns the default
    * mapping class.
    * @param objMapping The Data Import Object Mapping to look for a custom mapping logic class on.
    */
    private BDI_ObjectMappingLogic getObjectMappingLogicClass (BDI_ObjectMapping objMapping) {
        BDI_ObjectMappingLogic objMappingLogicClass;

        if (objMapping.Custom_Mapping_Logic_Class != null) {
            Type custLogicClassType = Type.forName(
                UTIL_Namespace.alignClassNSWithEnvironment(objMapping.Custom_Mapping_Logic_Class));
            objMappingLogicClass = (BDI_ObjectMappingLogic)custLogicClassType.newInstance();
        } else {
            objMappingLogicClass = new BDI_ObjectMappingLogic();
        }
        return objMappingLogicClass;
    }


    /*******************************************************************************************************
    * @description For newly created parent sobjects, this method updates the appropriate child predecessor
    * record's lookup field to the id of the newly created object.
    * @param objWrapsForChildPredecessorUpdate list of object wraps that were successfully created
    * and need to update their child predecessors.
    */
    private void updateChildPredecessorRecords(BDI_ObjectWrapper[] objWrapsForChildPredecessorUpdate){

        Map<String,Map<Id,SObject>> childSObjectMapByObjectAPIName = new Map<String,Map<Id,SObject>>();
        Map<Id,BDI_ObjectWrapper[]> successorObjWrapsByPredecessorId = new Map<Id,BDI_ObjectWrapper[]>();

        for (BDI_ObjectWrapper objWrap : objWrapsForChildPredecessorUpdate) {

            Id predecessorId = (Id)objWrap.dataImport.get(objWrap.predecessorObjMapping.Imported_Record_Field_Name);
            SObject sObjForUpdate;

            Map<Id,SObject> sObjectById = new Map<Id,SObject>();

            if (childSObjectMapByObjectAPIName.get(objWrap.predecessorObjMapping.Object_API_Name) != null) {
                sObjectById = childSObjectMapByObjectAPIName.get(objWrap.predecessorObjMapping.Object_API_Name);
            }

            // Attempt to find if the predecessor sobject if it is already in the map for update and update 
            // the existing SObject if possible.  Otherwise initialize a new SObject for update.
            if (sObjectById.size() > 0 && sObjectById.get(predecessorId) != null) {
                sObjForUpdate = sObjectById.get(predecessorId);
            } else {
                sObjForUpdate = UTIL_Describe.getPrototypeObject(objWrap.predecessorObjMapping.Object_API_Name);
            }

            // Set the id of the sobject to the predecessors record id
            sObjForUpdate.put('Id',predecessorId);

            // Place the Id of the newly created SObject into the appropriate relationship field on the child.
            sObjForUpdate.put(objWrap.objMapping.Relationship_Field,objWrap.sObj.Id);

            // Put the SObject back into the enclosing maps.
            sObjectById.put(predecessorId, sObjForUpdate);
            childSObjectMapByObjectAPIName.put(objWrap.predecessorObjMapping.Object_API_Name,sObjectById);

            // Store the successor object wraps by their predecessor id for later use in recording errors.
            if (successorObjWrapsByPredecessorId.get(predecessorId) != null) {
                successorObjWrapsByPredecessorId.get(predecessorId).add(objWrap);
            } else {
                successorObjWrapsByPredecessorId.put(predecessorId, new BDI_ObjectWrapper[]{objWrap});
            }
        }

        List<SObject[]> sObjForUpdateLists = new List<SObject[]>();

        SObject[] currentSObjectForUpdateList = new SObject[]{};

        // If the number of different sObject types being updated exceeds 10 then split into separate lists to avoid
        // the limit on the number of sObject types per dml operation.
        Integer n = 1;
        for (String objAPIName : childSObjectMapByObjectAPIName.keySet()) {

            currentSObjectForUpdateList.addAll(childSObjectMapByObjectAPIName.get(objAPIName).values());

            //If the loop is on its 10th run then add the list to the array and start a new one and reset the counter.
            if (n == 10) {
                sObjForUpdateLists.add(currentSObjectForUpdateList);
                currentSObjectForUpdateList = new SObject[]{};
                n = 1;
            } else {
                n++;
            }
        }

        if (currentSObjectForUpdateList.size() > 0) {
            sObjForUpdateLists.add(currentSObjectForUpdateList);
        }

        for (Integer t = 0; t < sObjForUpdateLists.size(); t++) {
            SObject[] sObjsForUpdate = sObjForUpdateLists[t];

            Database.SaveResult[] updateSaveResults = UTIL_DMLService.updateRecords(sObjsForUpdate,false);
            
            // Cycle through all the update results and update the data import records with status 
            // appropriately.
            for (Integer i = 0; i < updateSaveResults.size(); i++) {
                Database.SaveResult result = updateSaveResults[i];

                BDI_ObjectWrapper[] successorObjWraps = successorObjWrapsByPredecessorId.get(result.getId());

                // If the update of the child object fails then record an error in the status field
                // for all successor objects.
                if (!result.isSuccess()) {
                    for (BDI_ObjectWrapper objWrap : successorObjWraps) {

                        String errorMessage = System.label.bdiAdditionalObjChildNotUpdated +
                                result.getErrors()[0].getMessage();
                        logError(objWrap, errorMessage);
                    }
                }
            }
        }
    }


    /*******************************************************************************************************
    * @description 
    * @param predecessor The Data Import Object Mapping for which the imported field can be checked to see 
    *  if it exists.
    */
    private Boolean predecessorExists(BDI_ObjectWrapper objWrap, BDI_ObjectMapping predecessor){
        Boolean result = true;
        String errorObjectText;

        //There is a special case for mappings based on Allocation that can have either Donation or Recurring
        //Donation as predecessors.  In the future we should think about natively supporting multiple 
        //predecessors.
        if (objWrap.objMapping.Object_API_Name == SObjectType.Allocation__c.Name) {

            //If both Recurring Donation and Donation have not been inserted then return false.
            if (objWrap.dataImport.get(SObjectType.DataImport__c.fields.RecurringDonationImported__c.Name) == null
                && objWrap.dataImport.get(SObjectType.DataImport__c.fields.DonationImported__c.Name) == null){
                result = false;
                errorObjectText = SobjectType.Opportunity.getLabel() + ' / ' + SobjectType.npe03__Recurring_Donation__c.getLabel();
             }
             
        } else if (objWrap.dataImport.get(predecessor.Imported_Record_Field_Name) == null) {
            result = false;
            errorObjectText = predecessor.MasterLabel;
        }

        //Construct and log error message if predecessor does not exist.
        if (!result) {
            String error = String.format(
                System.Label.bdiAdditionalObjPredNotFound,
                new List<String>{errorObjectText});
            logError(objWrap, error);
        }

        return result;
    }


    /*******************************************************************************************************
    * @description Validates the field mappings to make sure that the required ones are not null and that 
    *  at least one non imported record
    * field is populated.
    * @param objWrap The BDI_ObjectWrapper that should have its field mappings validated.
    */
    private Boolean validateFields(BDI_ObjectWrapper objWrap){

        Boolean result = false;
        Boolean anyNonImportedRecordFieldsPopulated = false;
        Boolean allRequiredFieldsPopulated = true;

        String requiredFieldErrorMsg = System.label.bdiAdditionalObjRequiredFieldsNull;

        // First determine if there is at least one field populated that was not automatically populated by 
        // the import of another object. This is done to ensure that the user actually intended to attempt 
        // the creation of this object.
        for (BDI_FieldMapping fieldMapping : objWrap.fieldMappings) {

            if (objWrap.dynamicSource == null) {

                if (!mappingServiceAdvanced.importedRecordFieldNames.contains(
                        fieldMapping.Source_Field_API_Name.toLowerCase())
                    && objWrap.getSourceFieldValue(fieldMapping.Source_Field_API_Name) != null) {
                    
                    anyNonImportedRecordFieldsPopulated = true;
                }
            } else {
                anyNonImportedRecordFieldsPopulated = true;
            }
        }

        // If at least one field aside from imported record fields was populated then we should assume the 
        // user is trying to create the object and continue with record validation.
        if (anyNonImportedRecordFieldsPopulated) {

            for (BDI_FieldMapping fieldMapping : objWrap.fieldMappings) {

                if (objWrap.getSourceFieldValue(fieldMapping.Source_Field_API_Name) == null) {

                    if (fieldMapping.Required == 'Yes') {

                        allRequiredFieldsPopulated = false;
                        requiredFieldErrorMsg += fieldMapping.Source_Field_API_Name + '; ';
                    }
                }
            }

            // If at least one of the fields is populated and all required fields are populated then set result 
            // to true
            if (anyNonImportedRecordFieldsPopulated && allRequiredFieldsPopulated) {

                result = true;

            } else if (anyNonImportedRecordFieldsPopulated && !allRequiredFieldsPopulated) {
                requiredFieldErrorMsg = requiredFieldErrorMsg.removeEnd('; ').abbreviate(255);
                logError(objWrap, requiredFieldErrorMsg);
            }
        }

        return result;
    }


    /*******************************************************************************************************
    * @description Generates a map of tier number to list of Data Import Object Mappings so that they mappings 
    *   can be processed and imported in the correct
    * order.
    */
    public void generateTiersOfObjectMappings() {

        if (mappingServiceAdvanced.objectMappingByDevName != null 
            && mappingServiceAdvanced.objectMappingByDevName.size() > 0) {

            // Creates a map of predecessor dev name to successor and also identifies 
        // the base level objects with no predecessor defined.
            for (BDI_ObjectMapping objMapping : mappingServiceAdvanced.objectMappingByDevName.values()) {

                if (objMapping.Predecessor != null && objMapping.Relationship_Field != null 
            && objMapping.Relationship_To_Predecessor != null) {

                    objMappingDevNames.add(objMapping.DeveloperName);

                    if (successorObjMappingsByPredecessorName.get(objMapping.Predecessor) != null) {
                        successorObjMappingsByPredecessorName.get(objMapping.Predecessor).put(objMapping.DeveloperName,
                                                                                            objMapping);
                    } else {
                        successorObjMappingsByPredecessorName.put(objMapping.Predecessor,
                            new Map<String,BDI_ObjectMapping>{objMapping.DeveloperName => objMapping});
                    }
                } else {

                    if (objMappingsByTier.get(0) != null) {
                        objMappingsByTier.get(0).put(objMapping.DeveloperName,objMapping);
                    } else {
                        objMappingsByTier.put(0,new Map<String,BDI_ObjectMapping>{
                            objMapping.DeveloperName => objMapping
                        });
                    }
                }
            }

            //Iterates through the tier list and builds out each tier starting with the objects with no predecessor.
            for (Integer i = 0; i < objMappingsByTier.size(); i++) {

                Map<String,BDI_ObjectMapping> currentTier = 
                    new Map<String,BDI_ObjectMapping>();
                Map<String,BDI_ObjectMapping> nextTier = 
                    new Map<String,BDI_ObjectMapping>();

                if (objMappingsByTier.get(i) != null) {
                    currentTier = objMappingsByTier.get(i);

                    for (String objMappingDevName : currentTier.keyset()) {

                        if (successorObjMappingsByPredecessorName.get(objMappingDevName) != null) {
                            nextTier.putAll(successorObjMappingsByPredecessorName.get(objMappingDevName));
                        }
                    }

                    if (nextTier != null && nextTier.size() > 0) {
                        objMappingsByTier.put(i + 1,nextTier);
                    }
                }
            }
        }
    }

    private void logError(BDI_ObjectWrapper objectWrapper, String errorMessage) {

        objectWrapper.setDataImportStatus(BDI_DataImport_API.bdiFailed);

        objectWrapper.setImportedRecordStatus(errorMessage);

        logCombinedFailureInformation(objectWrapper, errorMessage);

        objectWrapper.setFailureInformation(
                failureInformationByDataImportId.get(objectWrapper.dataImport.Id)
        );
    }

    private Map<Id, String> failureInformationByDataImportId;

    private void logCombinedFailureInformation(
            BDI_ObjectWrapper objectWrapper,
            String errorMessage) {

        DataImport__c dataImport = objectWrapper.dataImport;
        String errorMessageToAppend = objectWrapper.getFailureInformationErrorMessage(errorMessage);

        if (failureInformationByDataImportId == null) {
            failureInformationByDataImportId = new Map<Id, String>();
        }

        String combinedErrorMessage =
                failureInformationByDataImportId.get(dataImport.Id);

        if (combinedErrorMessage == null) {
            failureInformationByDataImportId.put(dataImport.Id, errorMessageToAppend);
        } else {
            failureInformationByDataImportId.put(dataImport.Id,
                    String.join(
                            new List<String>{
                                    combinedErrorMessage, errorMessageToAppend
                            }, '\n\n'));
        }
    }
}