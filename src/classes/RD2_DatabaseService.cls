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
* @group Recurring Donations
* @description Database DML service to insert/update/delete records and keep track of failed RD Ids.
*   RD creation is commonly used in Community/Flows to allow customers to create donations. However,
*   the Winter '21 enforced security policies update which locked down the Site/Community Gues User's permission.
*   Declaring without sharing context will allow Guest Site Users to continue create Enhanced Recurring Dondations.
*   The class is specifically used and will only be used by Enhanced Recurring Donation related DML operations.
*/
public without sharing class RD2_DatabaseService {
    private SObjectType rdSObjectType = npe03__Recurring_Donation__c.SObjectType;
    private SObjectType oppSObjectType = Opportunity.SObjectType;

    private ERR_Handler.Errors errorResult = new ERR_Handler.Errors();
    private Set<Id> failedRDIds = new Set<Id>();
    private Map<Id,String> failedRDIdsMap = new Map<Id,String>();

    /***
    * @description Creates specified records
    * @param records Records to create
    * @return Set<Id> Ids of created records
    */
    public Set<Id> insertRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new Set<Id>();
        }

        List<Database.SaveResult> saveResults = Database.insert(records, false);
        handleErrors(saveResults, records);

        return getSuccessIds(saveResults);
    }

    /***
    * @description Updates specified records
    * @param records Records to update
    * @return void
    */
    public void updateRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        List<Database.SaveResult> saveResults = Database.update(records, false);
        handleErrors(saveResults, records);
    }

    /***
    * @description Extracts Ids of records that were successfully created/update
    * @param saveResults Insert/update DML operation results
    * @return Set<Id> Ids of successfully created/updated records
    */
    private Set<Id> getSuccessIds(Database.SaveResult[] saveResults) {
        Set<Id> successIds = new Set<Id>();

        if (saveResults == null || saveResults.isEmpty()) {
            return successIds;
        }

        for (Database.SaveResult result : saveResults) {
            if (result.isSuccess()) {
                successIds.add(result.getId());
            }
        }
        return successIds;
    }

    /***
    * @description Deletes specified records
    * @param records Records to delete
    * @return void
    */
    public void deleteRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        List<Database.DeleteResult> deleteResults = Database.delete(records, false);
        handleErrors(deleteResults, records);
    }

    /***
    * @description Keeps track of errors
    * @param dmlResults Database DML results upon insert/update/delete operation
    * @param records SObject records in DML operation
    * @return void
    */
    private void handleErrors(List<Object> dmlResults, List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        //extract errors
        ERR_Handler.Errors dmlErrors = ERR_Handler.getErrorsOnly(dmlResults, records);
        if (dmlErrors.errorRecords.isEmpty()) {
            return;
        }

        errorResult.errorRecords.addAll(
            dmlErrors.errorRecords
        );

        //track failed Recurring Donation Ids
        SObjectType recordSObjectType = records[0].getSObjectType();
        if (recordSObjectType == oppSObjectType) {
            for (Integer i = 0; i < dmlResults.size(); i++) {
                Boolean isSuccess = dmlResults[i] instanceof Database.SaveResult
                    ? ((Database.SaveResult)dmlResults[i]).isSuccess()
                    : ((Database.DeleteResult)dmlResults[i]).isSuccess();

                if (!isSuccess) {

                    List<Database.Error> lErr = dmlResults[i] instanceof Database.SaveResult
                                                    ? ((Database.SaveResult)dmlResults[i]).getErrors()
                                                    : ((Database.DeleteResult)dmlResults[i]).getErrors();
                    String sErr;
                    // Operation failed, so get all errors                
                    for (Database.Error err : lErr) {                                  
                        sErr = String.isBlank(sErr) 
                                ? err.getMessage() 
                                : sErr + ', ' + err.getMessage();           
                    }

                    failedRDIds.add((Id) records[i].get('npe03__Recurring_Donation__c'));
                    if (records[i].get('npe03__Recurring_Donation__c')!=null) {
                        failedRDIdsMap.put((Id) records[i].get('npe03__Recurring_Donation__c'), sErr);
                    }
                }
            }

        } else if (recordSObjectType == rdSObjectType) {
            for (Error__c error : dmlErrors.errorRecords) {                
                failedRDIds.add(error.Related_Record_ID__c);
                if (error.Related_Record_ID__c!=null) {
                    failedRDIdsMap.put(error.Related_Record_ID__c, error.Full_Message__c);
                }                
            }
        }
    }

    /**
    * @description Creates Error__c record for each errorResult.errorRecords
    * @return void
    */
    public void processErrors() {
        errorResult.errorsExist = !errorResult.errorRecords.isEmpty();

        ERR_Handler.processErrorsOnly(errorResult, ERR_Handler_API.Context.RD.name());
    }

    /***
    * @description Returns number of failed Recurring Donations
    * @return Integer
    */
    public Integer getRecordsFailed() {
        failedRDIds.remove(null);

        return failedRDIds.size();
    }

    /***
    * @description Returns Ids of failed Recurring Donations
    * @return Set<Id>
    */
    public Set<Id> getRecordsFailedId() {
        failedRDIds.remove(null);
        return failedRDIds;
    }

    public Map<Id,String> getRecordsFailedMap() {
        return failedRDIdsMap;
    }

}
