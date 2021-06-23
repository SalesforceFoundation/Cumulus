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
* @description Wrapper class used to contain information about a particular object mapping and data import record combination.
*/

public with sharing class BDI_ObjectWrapper {

    public BDI_ObjectMapping objMapping;
    public BDI_ObjectMapping predecessorObjMapping;
    public BDI_FieldMapping[] fieldMappings;
    public DataImport__c dataImport;
    public SObject sobj;
    public BDI_DynamicSource dynamicSource;

    public Id existingSObjectId;

    /*******************************************************************************************************
    * @description Constructor
    *
    * @param dataImport Instance of DataImport__c 
    * @param objMapping  CMT record for object from config
    * @param fieldMappings CMT records for field mappings from config
    * @param predecessorObjMapping CMT record of predecessor
    * @param dynamicSource if dynamic source objects are being used, this object contains the sourceSObj.
    */
    public BDI_ObjectWrapper(DataImport__c dataImport, 
                            BDI_ObjectMapping objMapping, 
                            BDI_FieldMapping[] fieldMappings, 
                            BDI_ObjectMapping predecessorObjMapping,
                            BDI_DynamicSource dynamicSource) {
        this.objMapping = objMapping;
        this.predecessorObjMapping = predecessorObjMapping;
        this.fieldMappings = fieldMappings;
        this.dataImport = dataImport;
        this.dynamicSource = dynamicSource;
    }

    /*******************************************************************************************************
    * @description Set the status for the DataImport__c
    */
    public void setDataImportStatus(String status) {
        dataImport.Status__c = status;
    }

    /*******************************************************************************************************
    * @description Set object mapping level import status.
    */
    public void setImportedRecordStatus(String newStatus) {
        if (newStatus != null){
            newStatus = newStatus.abbreviate(255);
        }

        if (dynamicSource == null) {
            if (objMapping.Imported_Record_Status_Field_Name != null) {
                dataImport.put(objMapping.Imported_Record_Status_Field_Name, newStatus);
            }
        } else {
            dynamicSource.importedRecordStatus = newStatus;
        }
    }

    /*******************************************************************************************************
    * @description Set failure information on the DataImport__c
    * @param failureInformation the new combined failure information value
    */
    public void setFailureInformation(String failureInformation) {
        dataImport.FailureInformation__c = failureInformation;
    }

    /*******************************************************************************************************
    * @description Get the imported record Id (if any)
    */
    public Id getImportedRecordId() {
        Id importedRecordId;

        if (dynamicSource == null) {
            if (dataImport.get(objMapping.Imported_Record_Field_Name) != null) {
                importedRecordId = (Id)dataImport.get(objMapping.Imported_Record_Field_Name);
            }
        } else {
            importedRecordId = dynamicSource.importedRecordId;
        }
        
        return importedRecordId;
    }

    /*******************************************************************************************************
    * @description Set Imported Record Id
    * @param importedRecordId the Id of the record that was just created.
    */
    public void setImportedRecordId(Id importedRecordId) {

        if (importedRecordId != null) {
            if (dynamicSource == null) {
                dataImport.put(objMapping.Imported_Record_Field_Name,
                    importedRecordId);
            } else {
                dynamicSource.importedRecordId = importedRecordId;
            }
        }
    }

    /*******************************************************************************************************
    * @description Get the source field value when given an API name
    * @param sourceFieldAPIName The api name of the source field to extract from the wrapper.
    */
    public Object getSourceFieldValue(String sourceFieldAPIName) {
        Object value;
        if (dynamicSource == null) {
            value = dataImport.get(sourceFieldAPIName);
        } else {
            //If the values are being drawn from a dynamic source then return the value from the DI
            //for imported fields, otherwise return it from the dynamic source object.
            BDI_MappingServiceAdvanced bdiMSAdv = BDI_MappingServiceAdvanced.getInstance();
            if (bdiMSAdv.importedRecordFieldNames.contains(sourceFieldAPIName.toLowerCase())) {
                value = dataImport.get(sourceFieldAPIName);
            } else {
                value = dynamicSource.sourceObj.get(sourceFieldAPIName);
            }
        }
        return value;
    }

    /*******************************************************************************************************
    * @description Builds the appropriate error message with the status field label name to append to the 
    * Failure Information field based on whether a dynamic source is being used.
    * @param errorMessage The error message that needs to have the correct field label/objMapping prefixed 
    */
    public String getFailureInformationErrorMessage(String errorMessage) {

        String errorMessageToAppend;
        String errorPrefix;

        if (dynamicSource == null && objMapping.Imported_Record_Status_Field_Name != null) {

            String importedRecordStatusField = objMapping.Imported_Record_Status_Field_Name;

            errorPrefix = UTIL_Describe.getFieldDescribe(
                    DataImport__c.SObjectType.getDescribe().getName(),
                    importedRecordStatusField).getLabel();


        } else if (dynamicSource != null && objMapping.dynamicSourceField != null) {
            
            String dynFieldLabel = UTIL_Describe.getFieldDescribe(
                    DataImport__c.SObjectType.getDescribe().getName(),
                    objMapping.dynamicSourceField).getLabel();

            errorPrefix = dynFieldLabel + ' - ' + dynamicSource.objectMappingDevName;
        }

        if (errorPrefix != null) {
            errorMessageToAppend = String.join(
                    new List<String>{
                            errorPrefix, errorMessage
                    }, ':\n');
        } else {
            errorMessageToAppend = errorMessage;
        }

        return errorMessageToAppend;
    }
}
