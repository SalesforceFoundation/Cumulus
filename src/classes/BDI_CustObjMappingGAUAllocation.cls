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
* @description Overrides the standard object mapping logic class for GAU allocation field mapping since only one of
* the Opportunity__c and Payment__c fields should be populated.
*/

public with sharing class BDI_CustObjMappingGAUAllocation extends BDI_ObjectMappingLogic {

    public override BDI_ObjectWrapper[] populateObjects(BDI_ObjectWrapper[] objWraps) {

        String PAYMENT_FIELDNAME = SObjectType.Allocation__c.fields.Payment__c.Name;
        String OPPORTUNITY_FIELDNAME = SObjectType.Allocation__c.fields.Opportunity__c.Name;
        String RECURRING_DONATION_FIELDNAME = SObjectType.Allocation__c.fields.Recurring_Donation__c.Name;

        String sourceObjName = SObjectType.DataImport__c.getName();

        for (BDI_ObjectWrapper objWrap : objWraps) {

            objWrap.sObj = UTIL_Describe.getPrototypeObject(objWrap.objMapping.Object_API_Name);

            if (objWrap.existingSObjectId != null) {
                objWrap.sObj.put('Id', objWrap.existingSObjectId);
            }

            Object opportunityIdValue;
            Object recurringDonationIdValue;

            for (BDI_FieldMapping fieldMapping : objWrap.fieldMappings) {
                String sourceFieldName = fieldMapping.Source_Field_API_Name;
                String targetFieldName = fieldMapping.Target_Field_API_Name;

                Object value = objWrap.getSourceFieldValue(sourceFieldName);

                Schema.DescribeFieldResult sourceFieldDescribe = UTIL_Describe.getFieldDescribe(sourceObjName, sourceFieldName);
                Schema.DescribeFieldResult targetFieldDescribe = UTIL_Describe.getFieldDescribe(objWrap.objMapping.Object_API_Name, targetFieldName);

                //Confirm that it is real field, and that it is accessible to the running user.
                if (targetFieldDescribe != null && targetFieldDescribe.isAccessible()) {
                    //Confirm that either the sObj Id is null (ie new record) or that the field is updatable if it is not new.
                    if (objWrap.sObj.Id == null || targetFieldDescribe.isUpdateable()) {
                        // If the target field mapping is one of the key parent objects, then extract the values for later logic
                        if (fieldMapping.Target_Field_API_Name == PAYMENT_FIELDNAME) {
                            // Skip payment lookup since we will not directly link a GAU Allocation to Payment
                            continue;
                        } else if (fieldMapping.Target_Field_API_Name == OPPORTUNITY_FIELDNAME) {
                            opportunityIdValue = value;
                        } else if (fieldMapping.Target_Field_API_Name == RECURRING_DONATION_FIELDNAME) {
                            recurringDonationIdValue = value;
                        } else {
                            castAndCopyField(objWrap, sourceFieldName, sourceFieldDescribe, targetFieldName, targetFieldDescribe);
                        }
                    }
                }
            }

            // If the payment is specified and payment allocations are enabled, always use that first.
            if ( recurringDonationIdValue != null
                    && objWrap.dataImport.RecurringDonationImportStatus__c == Label.bdiCreated ) {
                objWrap.sObj.put(RECURRING_DONATION_FIELDNAME,recurringDonationIdValue);
            } else if ( opportunityIdValue != null ) {
                objWrap.sObj.put(OPPORTUNITY_FIELDNAME,opportunityIdValue);
            }

        }
        return objWraps;
    }
}
