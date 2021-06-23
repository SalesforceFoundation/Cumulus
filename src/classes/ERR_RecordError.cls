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
* @description Helps manage the process of inserting and updating Record centered Errors.
* @group ErrorHandling
* @group-content ../../ApexDocContent/ErrorHandling.htm
*/
public class ERR_RecordError {

   public class RecordErrorHandlerException extends Exception { }

    private Map<String, Error__c> existingErrorsByRecordID = new Map<String, Error__c>();

    private String context;

    public Map<ID, Error__c> insRecordErrors = new Map<Id, Error__c>();
    public Map<ID, Error__c> updRecordErrors = new Map<Id, Error__c>();

    /*******************************************************************************************************
    * @description Constructor for the ERR_RecordError class.  It should include a context that represents
    *              the process these Record Errors should be associated with.
    * @param context The process or batch to be associated with any errors processed via this instance
    *                of RecordErrors.  It is stored in the Error Records Context Type field
    */
    public ERR_RecordError (String context) {
        if (String.isNotBlank(context)) {
            this.context = context;
        } else {
            // Consumer of this service is attempting to instantiate it without a Context Type, which is required for
            // Record Errors
            throw new RecordErrorHandlerException(System.Label.errErrorNoContext);
        }

    }

    /*******************************************************************************************************
    * @description Allows a ERR_RecordError instance to reference "existing" errors previously set for this
    *              process.
    * @param existingErrors A List of Existing Error records
    * @return A reference to the ERR_RecordError Object so it can be part of an construct and configure
    *         statement
    */
    public ERR_RecordError withExistingErrors(List<Error__c> existingErrors) {
        this.existingErrorsByRecordID = new Map<String, Error__c>();

        for (Error__c err : existingErrors) {
            if (err.Id != null && err.Related_Record_ID__c != null) { // Only add if Error__c record is already inserted, and has a Related_Record_ID__c value
                this.existingErrorsByRecordID.put(err.Related_Record_ID__c, err);
            }
        }

        return this;
    }

    /*******************************************************************************************************
    * @description Queries the Errors object using the Context Type configured for this RecordErrors
    *              instance, and the list of sObjects passed in to populate a map of existing errors by
    *              "Related Record ID", which are kept in an internal map and used when other errors are
    *              added to determine if it is an update or an insert operation.
    * @param records the list of sObjects to determine if errors are present for
    */
    public void retrieveExistingErrorsFor (List<SObject> records) {
        Set<String> ids = new Set<String>();

        for (SObject so : records) {
            ids.add((String)so.Id);
        }

        List<Error__c> errors = [SELECT     Id,
                                            Context_Type__c,
                                            Datetime__c,
                                            Error_Type__c,
                                            Full_Message__c,
                                            Object_Type__c,
                                            Related_Record_ID__c,
                                            Record_URL__c,
                                            Retry_Pending__c,
                                            Email_Sent__c,
                                            Posted_In_Chatter__c
                                FROM Error__c
                                WHERE      Related_Record_ID__c IN :ids AND
                                            Context_Type__c = :context
                                ];

        for (Error__c error : errors) {
            this.existingErrorsByRecordID.put(error.Related_Record_ID__c, error);
        }
    }

    /*******************************************************************************************************
    * @description Indicates whether any new are errors are present to be committed to the Database
    * @return Boolean true if there are new errors present to be inserted/updated.
    */
    public Boolean isNewErrorsPresent() {
        return (!this.insRecordErrors.isEmpty() || !this.updRecordErrors.isEmpty());
    }

    /*******************************************************************************************************
    * @description Returns a list of Errors for records to be inserted that did not previously have Errors
    * for that Record and Context Type.
    * @return List of Errors to be inserted
    */
    @testVisible private List<Error__c> getErrorsForInsert() {
        return this.insRecordErrors.values();
    }


    /*******************************************************************************************************
    * @description Returns a list of Errors for records to be updated because they was a previous Error
    *              record
    * present for that Record ID and Context Type
    * @return List of Errors to be updated
    */
    @testVisible private List<Error__c> getErrorsForUpdate() {
        return this.updRecordErrors.values();
    }

    /*******************************************************************************************************
    * @description Checks the maps in a hierarchy to find the Error record that should be used when adding
    *              a new error.  This is to allow Errors (sometimes multiple errors for a single record)
    *              to be added without requiring the process to manage all the nuances required.
    *              Basically, if the record is in our updated records map, we will use that first.  If
    *              not, we will check the existing Errors next.  Finally we will check for newly inserted
    *              error records.  Once an Error has been added or updated, it will ignore the record in
    *              the existing errors map.
    * @param recordId Id of the Salesforce Record to get from the maps hierarchy
    * @return Error__c record, if found in any of the maps
    */
    @testVisible private Error__c get(Id recordId) {
        if (updRecordErrors.containsKey(recordId)) {
            return updRecordErrors.get(recordId);
        } else if (existingErrorsByRecordID.containsKey(recordId)) {
            return existingErrorsByRecordID.get(recordId);
        } else if (insRecordErrors.containsKey(recordId)) {
            return insRecordErrors.get(recordId);
        } else {
            return null;
        }
    }

    /*******************************************************************************************************
    * @description Adds/or replaces an error in either the insert or update error map.  If the Error
    *              record has a Salesforce ID, it will put it in the update map.  Otherwise, it will put
    *              it in the insert map.
    * @param recordId The Record ID of the Salesforce record associated with the Error
    * @param Error__c The error record
    */
    @testVisible private void put(String recordId, Error__c error) {
        if (error.Id != null) {
            updRecordErrors.put (recordId, error);
        } else {
            insRecordErrors.put (recordId, error);
        }
    }

    /*******************************************************************************************************
    * @description Adds a single Error by Record ID to the appropriate insert or update map, if an error
    *              occurred (isSuccess() of the dmlResult != true).
    * @param recordId The Record ID of the Salesforce record associated with the Error
    * @param dmlResult The result of the DML Operation
    * @param sObj The record the error is associated with
    */
    public void addError(Id recordId, Object dmlResult, SObject sObj) {
        if (isDmlResultSuccess(dmlResult)) {
            return;
        }

        // Checks to see if this in already in the Record Errors List
        Error__c err = this.get(recordId);

        if (err == null) {
            // Create Error record
            err = createRecordError(
                dmlResult,
                (sObj != null) ? UTIL_Describe.getObjectDescribe(sObj.getSObjectType()).getName() : null,
                recordId,
                context
            );
        } else {
            // Existing Error associated with record exists, update.
            err = updateRecordError(
                err,
                dmlResult
            );
        }

        // Put into inserts or updates list, depending on requirements
        this.put(recordId, err);
    }

    /*******************************************************************************************************
    * @description Adds errors by Record IDs to the appropriate insert or update map, if an error
    *              occurred (isSuccess() of the dmlResult != true).  The three lists are ordinal, and
    *              should be the same length.  The information provided in each parameter will be
    *              associated together by it's position in the list.
    * @param dmlResults The list of result of the DML Operation
    * @param errorIdForSObject The List of Record IDs that match each dmlResult, in terms of errors
    * @param sObjects The list of records any errors are associated with
    */
    public void addErrors(List<Object> dmlResults, List<Id> errorIdForSObject, List<SObject> sObjects) {
        if (dmlResults == null || dmlResults.isEmpty()) {
            return;
        }

        for(Integer i=0; i < dmlResults.size(); i++) {
            addError(errorIdForSObject[i], dmlResults[i], sObjects[i]);
        }
    }

    /*******************************************************************************************************
    * @description Adds a single Error by Record ID to the appropriate insert or update map.
    * @param recordId The Record ID of the Salesforce record associated with the Error
    * @param errorMessage The erorr to add
    * @param sObj The record the error is associated with
    */
    public void addError(Id recordId, String errorMessage, SObject sObj) {
        // Checks to see if this in already in the Record Errors List
        Error__c err = this.get(recordId);

        if (err == null) {
            // Create Error record
            err = createRecordError(
                errorMessage,
                System.Label.errErrorTypeOther,
                (sObj != null) ? UTIL_Describe.getObjectDescribe(sObj.getSObjectType()).getName() : null,
                recordId,
                context
            );
        } else {
            // Existing Error associated with record exists, update.
            err = updateRecordError(
                err,
                errorMessage,
                System.Label.errErrorTypeOther
            );
        }

        // Put into inserts or updates list, depending on requirements
        this.put(recordId, err);
    }

    /*******************************************************************************************************
    * @description Adds errors by Record IDs to the appropriate insert or update map.  The two parameters
    *              are keyed by the Record ID associated with the error
    * @param errorMessagesByRecordID Error Messages to add, keyed by Record ID
    * @param sObjects Map of SObjects associated with the errors, keyed by Record ID associated with the
    *        Error
    */
    public void addErrors(Map<Id, String> errorMessagesByRecordID, Map<Id, SObject> sObjects) {
        if (errorMessagesByRecordID == null || errorMessagesByRecordID.isEmpty()) {
            return;
        }

        for(String soId :errorMessagesByRecordID.keySet()) {
            addError(soId, errorMessagesByRecordID.get(soId), sObjects.get(soId));
        }

    }

    /*******************************************************************************************************
    * @description Clears errors, if they exist in the Map
    * @param recordId The Record ID of the Salesforce record associated with the Error
    * @param message The message to add
    */
    public void clearError(String recordId, String message) {
        // Checks to see if this in already in the Record Errors List
        Error__c err = this.get(recordId);

        // Only clear error if Error is found and Retry Pending is true
        if (err != null && err.Retry_Pending__c) {
            err = clearRecordError(
                err,
                message
            );
            // Put into list
            this.put(recordId, err);
        }
    }

    /*******************************************************************************************************
    * @description Resets the Retry Pending flag and adds a message for a Set of Record IDs.  It only does
    * this if the recordID is present in map of Errors by Record ID
    * @param Set<String> recordIds
    * @param String message
    */
    public void clearErrors(Set<String> recordIds, String message) {
        for (String recordId :recordIds) {
            clearError(recordId, message);
        }
    }

    /*******************************************************************************************************
    * @description Resets the Retry Pending flag and adds a message for a Set of Record IDs.  It only does
    *              this for record IDs that are present in the map of Errors by Record ID
    * @param Set<String> recordIds
    * @param String message
    */
    public void clearErrors(Set<Id> recordIds, String message) {
        for (String recordId :recordIds) {
            clearError((String) recordId, message);
        }
    }

    /*******************************************************************************************************
    * @description Executes DML for any pending inserts and updates.  Then, it updates the Existing Errors
    *              Map using the inserted and updated data
    * @param errorMessagesByRecordID Error Messages to add, keyed by Record ID
    * @param sObjects Map of SObjects associated with the errors, keyed by Record ID associated with the
    *        Error
    */
    public void processErrors() {
        List<Error__c> errsForIns = getErrorsForInsert();
        if (errsForIns != null && !errsForIns.isEmpty()) {
            // Insert new record errors
            Database.insert(errsForIns, false);

            // Refresh existing Errors Map
            refreshExistingErrorsMap(errsForIns);

            insRecordErrors.clear();
        }

        List<Error__c> errsForUpd = getErrorsForUpdate();
        if (errsForUpd != null && !errsForUpd.isEmpty()) {
            // Update record errors that already existed in the system
            Database.update(errsForUpd, false);

            // Refresh existing Errors Map
            refreshExistingErrorsMap(errsForUpd);

            updRecordErrors.clear();
        }

        //ERR_Notifier takes care of checking the settings itself.
        ERR_Notifier.sendErrorNotifications(context);
    }

    /*******************************************************************************************************
    * @description Takes a list of Errors, and updates the existing Errors map using the errors Related
    *              Record ID as a key
    * @param errs List of Errors to be processed into the Existing Errors Map
    */
    @testVisible private void refreshExistingErrorsMap(List<Error__c> errs) {
        for (Error__c err : errs) {
            this.existingErrorsByRecordID.put (err.Related_Record_ID__c, err);
        }
    }

    // **************************** HELPER METHODS ****************************

    /*******************************************************************************************************
    * @description Checks if a given DML operation has succeeded depending on the type of DML result.
    *              Use the isSuccess() method of the result.
    * @param Boolean true if isSuccess() was true
    */
    @testVisible private static boolean isDmlResultSuccess(Object dmlResult) {
        if (dmlResult instanceof Database.SaveResult) {
            return ((Database.SaveResult)dmlResult).isSuccess();
        } else if (dmlResult instanceof Database.DeleteResult) {
            return ((Database.DeleteResult)dmlResult).isSuccess();
        } else if (dmlResult instanceof Database.UndeleteResult) {
            return ((Database.UndeleteResult)dmlResult).isSuccess();
        }
        // Will only occur if a user of this class tries to use an unsupported DML Type
        throw new RecordErrorHandlerException(System.Label.errErrorUnsupportedDMLType);
    }

    /*******************************************************************************************************
    * @description Gets the first error from the error list if the list is not null and has at least one
    *              error present
    * @param errs The list of Errors
    * @return Database.Error the first error (if errors are present) or null
    */
    @testVisible private static Database.Error getFirstDmlError(List<Database.Error> errs) {
        return (errs != null && errs.size() > 0) ? errs[0] : null;
    }

    /*******************************************************************************************************
    * @description Creates a error record associated with a specific context and record with the message
    *              passed to the method.
    * @param message The full message of all the errors for a given job and compiled IDs.
    * @param statusCode The code associated with the error
    * @param objectType The name of the type of object that caused the error.
    * @param objId The id of the record that caused the error.
    * @param context The context the exception was raised on.
    * @return The error record.
    */
    @testVisible private static Error__c createRecordError(String message, String statusCode, String objectType, Id objId, String context) {
        Datetime now = System.now();

        return new Error__c(
            Datetime__c = now,
            Object_Type__c = objectType,
            Context_Type__c = context,
            Retry_Pending__c = true,
            Related_Record_ID__c = objId,
            Record_URL__c = ERR_Handler.getRecordURL(objId),
            Error_Type__c = statusCode,
            Full_Message__c = updateFullMessage(now, '', message)
        );
    }

    /*******************************************************************************************************
    * @description Creates a error record associated with a specific context and record from the result
    *              of a DML operation performed through the Database class.
    * @param result The result of the Database DML operation. It cannot be more specific than Object,
    *        because the result of the different DML operations that the Database class can perform don't
    *        have a common parent.
    * @param objectType The name of the type of object that caused the error.
    * @param objId The id of the record that caused the error.
    * @param context The context the exception was raised on.
    * @return The error record.
    */
    @testVisible private static Error__c createRecordError(Object result, String objectType, Id objId, String context) {
        Database.Error dmlError;

        if (result instanceof Database.SaveResult) {
            Database.SaveResult saveResult = (Database.SaveResult) result;
            dmlError = getFirstDmlError(saveResult.getErrors());
        } else if (result instanceof Database.DeleteResult) {
            Database.DeleteResult deleteResult = (Database.DeleteResult) result;
            dmlError = getFirstDmlError(deleteResult.getErrors());
        } else if (result instanceof Database.UndeleteResult) {
            Database.UndeleteResult undeleteResult = (Database.UndeleteResult) result;
            dmlError = getFirstDmlError(undeleteResult.getErrors());
        }

        // Use non DML variant of createRecordError after determining statusCode and error message
        return createRecordError(getDmlMessage(dmlError), getStatusCode(dmlError), objectType, objId, context);
    }

    /*******************************************************************************************************
    * @description Updates an existing error record associated with a specific context and record from the
    *              result of a DML operation performed through the Database class.  Full_Message__c will
    *              be prepended with the latest message and timestamp, and truncated to 5K.  The Error
    *              Type will be updated based on the StatusCode of the Result.  The Datetime field will be
    *              updated to the current timestamp.  Retry_Pending__c will be set to true, indicated it
    *              should try the record again, if possible.
    * @param error The error record to be updated.
    * @param message The full message of all the errors for a given job and compiled IDs.
    * @param statusCode The code associated with the error
    * @return The error record.
    */
    @testVisible private static Error__c updateRecordError(Error__c error, String message, String statusCode) {
        Datetime now = System.now();

        error.Datetime__c = now;
        error.Retry_Pending__c = true;
        // Set to false so it will repost to chatter on update
        error.Posted_in_Chatter__c = false;
        // Set to false so it will resend email on update
        error.Email_Sent__c = false;
        error.Error_Type__c = statusCode;
        error.Full_Message__c = updateFullMessage(now, error.Full_Message__c, message);

        return error;
    }

    /*******************************************************************************************************
    * @description Updates an existing error record associated with a specific context and record from the
    *              result of a DML operation performed through the Database class.  Full_Message__c will
    *              be prepended with the latest message and timestamp, and truncated to 5K.  The Error
    *              Type will be updated based on the StatusCode of the Result.  The Datetime field will be
    *              updated to the current timestamp.  Retry_Pending__c will be set to true, indicated it
    *              should try the record again, if possible.
    * @param error The error record to be updated.
    * @param result The result of the Database DML operation. It cannot be more specific than Object,
    *               because the result of the different DML operations that the Database class can
    *               perform don't have a common parent.
    * @return The error record.
    */
    @testVisible private static Error__c updateRecordError(Error__c error, Object result) {

        Database.Error dmlError;

        if (result instanceof Database.SaveResult) {
            Database.SaveResult saveResult = (Database.SaveResult) result;
            dmlError = getFirstDmlError(saveResult.getErrors());
        } else if (result instanceof Database.DeleteResult) {
            Database.DeleteResult deleteResult = (Database.DeleteResult) result;
            dmlError = getFirstDmlError(deleteResult.getErrors());
        } else if (result instanceof Database.UndeleteResult) {
            Database.UndeleteResult undeleteResult = (Database.UndeleteResult) result;
            dmlError = getFirstDmlError(undeleteResult.getErrors());
        }

        // Use non DML variant of updateRecordError after determining statusCode and error message
        return updateRecordError(error, getDmlMessage(dmlError), getStatusCode(dmlError));
    }

    /*******************************************************************************************************
    * @description Updates an existing error record, clearing the retry pending flag.  Full_Message__c
    *              will be prepended with the latest message and timestamp, and truncated to 5K.  The
    *              Datetime field will be updated to the current timestamp.  Retry_Pending__c will be set
    *              to false, indicating it should NOT try the record again.
    * @param error The error record to be updated.
    * @param message The full message to add when clearing the Retry Pending? status.
    * @return The error record.
    */
    @testVisible private static Error__c clearRecordError (Error__c error, String message) {
        error.Datetime__c = System.now();
        error.Retry_Pending__c = false;
        // Setting so it does not send email
        error.Email_Sent__c = true;
        // Setting so it does post to chatter
        error.Posted_in_Chatter__c = false;
        error.Full_Message__c = updateFullMessage(error.Datetime__c, error.Full_Message__c, message);

        return error;
    }

    /*******************************************************************************************************
    * @description For existing error records, it will concatenate the new message, and any existing text
    *              with a separator in between.
    * @param ts The timestamp the associated
    * @param context The context the exception was raised on.
    * @param objectType The type of all records in the job, only to be passed in if they all match.
    * @return The error record.
    */
    @testVisible private static String updateFullMessage(Datetime ts, String existingMessage, String message) {

        String updatedMessage = ts.format() + ':\r\n' + message;

        if (String.isNotBlank(existingMessage)) {
            updatedMessage += '\r\n' + '========================================\r\n' + existingMessage;
            // Limit to 5K worth of Message History
            updatedMessage = updatedMessage.abbreviate(5120);
        }

        return updatedMessage;
    }

    /*******************************************************************************************************
    * @description Returns the status of the error that happened as a result of a DML operation performed
    *              through the Database class as a string.  If null, will return null
    * @param dmlError The DML error that occurred
    * @return The error message as a String
    */
    private static String getDmlMessage(Database.Error dmlError) {
        return (dmlError != null) ? dmlError.getMessage() : null;
    }

    /*******************************************************************************************************
    * @description Returns the status of the error that happened as a result of a DML operation performed
    *              through the Database class as a string.  If null, will return null
    * @param dmlError The DML error that occurred
    * @return The error status as a string.
    */
    private static String getStatusCode(Database.Error dmlError) {
        return (dmlError != null) ? ERR_Handler.getStatusCode(dmlError.getStatusCode()) : '(Error not available.)';
    }

    /*******************************************************************************************************
    * @description Returns the status of the error that happened as a result of a DML operation performed
    *              through the Database class as a string.
    * @param status The status code.
    * @return The error status as a string.
    */
    private static String getStatusCode(System.StatusCode status) {
        if (status == System.Statuscode.REQUIRED_FIELD_MISSING) {
            return System.Label.errErrorTypeRequiredFieldMissing;
        } else if (status == System.Statuscode.FIELD_CUSTOM_VALIDATION_EXCEPTION) {
            return System.Label.errErrorTypeValidationFailed;
        } else {
            return System.Label.errErrorTypeOther;
        }
    }
}