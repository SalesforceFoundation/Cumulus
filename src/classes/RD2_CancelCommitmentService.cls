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
* @group Recurring Donations
* @description Services related to the cancellation of Elevate commitments
*/
public without sharing class RD2_CancelCommitmentService {

    /***
     * @description Max length of a string to be stored in a picklist field
     */
    private static final Integer MAX_PICKLIST_FIELD_LEN = 255;

    /***
     * @description Maximum number of retry attempts to cancel Elevate commitment
     */
    @TestVisible
    private static Integer maxCancelRetries {
        get {
            if (maxCancelRetries == null) {
                maxCancelRetries = 3;
            }
            return maxCancelRetries;
        }
        set;
    }

    /**
    * @description Sends requests and constructs the response
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
    * @description Sends cancel commitment requests for closed Recurring Donations.
    * Sets RD closed reason back to user specified reason and insert any error.
    * @return void
    */
    public void cancelCommitments(List<RecordWrapper> closedRecords) {
        List<npe03__Recurring_Donation__c> rdsToUpdate = new List<npe03__Recurring_Donation__c>();
        List<RecordWrapper> queuedRecords = new List<RecordWrapper>();
        ERR_LogService.Logger logger = new ERR_LogService.Logger(
            ERR_Handler_API.Context.Elevate,
            npe03__Recurring_Donation__c.SObjectType
        );

        for (RecordWrapper record : closedRecords) {
            Integer calloutsRemaining = Limits.getLimitCallouts();

            if (calloutsRemaining > 0) {
                //Cancel the commitment or GET the commitment to verify if already cancelled
                UTIL_Http.Response response = sendRequest(record);

                //Set Recurring Donation Status Reason and its wrapper data to reflect response.
                handleResponse(record, response, logger);

                //Add the Recurring Donation to update list if it cannot be retried,
                //it is already cancelled or the cancel succeeded
                if (record.isDone) {
                    rdsToUpdate.add(record.getRecurringDonation());
                    continue;
                }
            }

            queuedRecords.add(record);
        }

        //Update Recurring Donations that succeeded or the max retry limit is reached
        List<Database.SaveResult> dmlResults = Database.update(rdsToUpdate, false);
        logger.addErrors(dmlResults, rdsToUpdate);

        //Log errors
        logger.processErrors();

        //Chain another queueable with Recurring Donations that should be retried or data GET
        if (!queuedRecords.isEmpty()) {
            System.enqueueJob(new RD2_QueueableService.CancelCommitmentService(queuedRecords));
        }
    }

    /**
    * @description Sends request for closed Recurring Donations.
    * @param closedRecord RecordWrapper
    * @return UTIL_Http.Response
    */
    private UTIL_Http.Response sendRequest(RecordWrapper closedRecord) {
        UTIL_Http.Response response;

        try {
            HttpRequest request;

            if (getRequestType(closedRecord) == PS_Request.ElevateEndpoint.COMMITMENT_CANCEL) {
                request = buildCancelRequest(closedRecord.rd.CommitmentId__c);
            }
            else if (getRequestType(closedRecord) == PS_Request.ElevateEndpoint.COMMITMENT) {
                request = PS_CommitmentRequest.buildGetRequest(closedRecord.rd.CommitmentId__c);
            }
            response = requestService.sendRequest(request);

        }
        catch (Exception ex) {
            response = requestService.buildErrorResponse(ex);
        }

        return response;
    }

    /**
    * Builds a cancel commitment request for the provided commitment Id
    * @param commitmentId Elevate recurring commitment Id
    * @return HttpRequest
    */
    private HttpRequest buildCancelRequest(String commitmentId) {
        return new PS_Request.Builder()
            .withCommitmentId(commitmentId)
            .withEndpoint(PS_Request.ElevateEndpoint.COMMITMENT_CANCEL)
            .withMethod(UTIL_Http.Method.POST)
            .build();
    }

    /**
    * @description Returns request type to send to Payment API endpoint.
    * @param closedRecord RecordWrapper
    * @return PS_Request.ElevateEndpoint
    */
    private PS_Request.ElevateEndpoint getRequestType(RecordWrapper closedRecord) {
        PS_Request.ElevateEndpoint requestType = PS_Request.ElevateEndpoint.COMMITMENT_CANCEL;

        if (hasPreviousTimeoutOrConflict(closedRecord)) {
            requestType = PS_Request.ElevateEndpoint.COMMITMENT;
        }

        return requestType;
    }

    /**
    * @description Returns true if a previous cancel attempt result was timeout or conflict.
    * @param closedRecord RecordWrapper
    * @return Boolean
    */
    private Boolean hasPreviousTimeoutOrConflict(RecordWrapper closedRecord) {
        return closedRecord.isConfirmationRequired;
    }

    /**
    * @description Handles response from the Payments API
    * @param closedRecord RecordWrapper
    * @param response UTIL_Http.Response
    * @param logger Logger to create error logs
    */
    @TestVisible
    private void handleResponse(
        RecordWrapper closedRecord,
        UTIL_Http.Response response,
        ERR_LogService.Logger logger
    ) {
        // Successful cancellation
        if (isCancelled(closedRecord, response)) {
            closedRecord.isDone = true;
            return;
        }

        // Set firstErrorMessage if blank
        if (String.isBlank(closedRecord.firstErrorMessage)) {
            closedRecord.firstErrorMessage = response.getErrorMessages();
            handleCancelConfirmation(closedRecord, response);
        }

        resetElevateConfirmationRequired(closedRecord, response);

        // If not success, decrement retries
        if (!closedRecord.isDone) {
            closedRecord.retriesRemaining--;
        }

        if (isErrorResponse(response) && !isQualifiedForRetry(closedRecord, response)) {
            closedRecord.isDone = true;
            logger.addError(
                closedRecord.rd.Id,
                closedRecord.firstErrorMessage,
                RD2_ElevateIntegrationService.LOG_TYPE_COMMITMENT_CANCEL
            );
            closedRecord.rd.ClosedReason__c = closedRecord.firstErrorMessage.abbreviate(MAX_PICKLIST_FIELD_LEN);
        }
    }

    /**
    * @description Checks if the commitment has been successfully cancelled in Elevate
    * @param closedRecord RecordWrapper, including previous response code
    * @param response Elevate API response
    * @return Boolean
    */
    private Boolean isCancelled(RecordWrapper closedRecord, UTIL_Http.Response response) {
        return
            response != null
            && response.statusCode == UTIL_Http.STATUS_CODE_OK
            && (!closedRecord.isConfirmationRequired || isElevateCommitmentCancelled(response));
    }

    /**
    * @description Returns true if response represents an error.
    * @param response UTIL_Http.Response
    * @return Boolean
    */
    private Boolean isErrorResponse(UTIL_Http.Response response) {
        return response.statusCode != UTIL_Http.STATUS_CODE_OK;
    }

    /**
    * @description Returns true if Elevate cancel callout should be retried.
    * @param closedRecord RecordWrapper
    * @param response UTIL_Http.Response
    * @return Boolean
    */
    private Boolean isQualifiedForRetry(RecordWrapper closedRecord, UTIL_Http.Response response) {
        return hasRetriesRemaining(closedRecord) && response.statusCode != UTIL_Http.STATUS_CODE_NOT_FOUND;
    }

    /**
    * @description Returns true if closedRecord has retries remaining.
    * @param closedRecord RecordWrapper
    * @return Boolean
    */
    private Boolean hasRetriesRemaining(RecordWrapper closedRecord) {
        return closedRecord.retriesRemaining > 0;
    }

    /**
    * @description Sets closedRecord field to indicate confirmation is needed that Elevate RD has been cancelled.
    * @param closedRecord RecordWrapper
    * @param response UTIL_Http.Response
    */
    private void handleCancelConfirmation(RecordWrapper closedRecord, UTIL_Http.Response response) {
        closedRecord.isConfirmationRequired = isConfirmationNeeded(response);
    }

    /**
    * @description Returns true if response indicates that Elevate status confirmation is needed.
    * @param response UTIL_Http.Response
    * @return Boolean
    */
    private Boolean isConfirmationNeeded(UTIL_Http.Response response) {
        return response.statusCode == UTIL_Http.STATUS_CODE_REQUEST_TIMEOUT
            || response.statusCode == UTIL_Http.STATUS_CODE_GATEWAY_TIMEOUT
            || response.statusCode == UTIL_Http.STATUS_CODE_INTERNAL_SERVER_ERROR
            || response.statusCode == UTIL_Http.STATUS_CODE_SERVICE_UNAVAILABLE
            || response.statusCode == UTIL_Http.STATUS_CODE_CONFLICT;
    }

    private void resetElevateConfirmationRequired(RecordWrapper closedRecord, UTIL_Http.Response response) {
        if (closedRecord.isConfirmationRequired
            && response.statusCode == UTIL_Http.STATUS_CODE_OK
            && !isElevateCommitmentCancelled(response)
        ) {
            closedRecord.isConfirmationRequired = false;
        }
    }

    /**
    * @description Validates Elevate commitment cancellation
    * @param response UTIL_Http.Response
    * @return Boolean
    */
    private Boolean isElevateCommitmentCancelled(UTIL_Http.Response response) {
        return getCommitmentStatus(response) == 'INACTIVE';
    }

    /**
    * @description Extracts Elevate commitment status from response
    * @param response UTIL_Http.Response
    * @return String
    */
    private String getCommitmentStatus(UTIL_Http.Response response) {
        String status;

        try {
            Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(response.body);
            Map<String, Object> commitment = (Map<String, Object>) bodyMap.get('commitment');
            status = (String) commitment.get('status');
        }
        catch (Exception e) {
            // Response body is null or empty. Treat as cancellation unconfirmed.
        }

        return status;
    }

    /**
    * @description Wraps Recurring Donation, retriesRemaining, isConfirmationRequired and isDone.
    * These values need to be accessed together during the Elevate cancellation process.
    */
    public class RecordWrapper {
        public npe03__Recurring_Donation__c rd;
        public Integer retriesRemaining;
        public Boolean isConfirmationRequired;
        public String firstErrorMessage;
        public Boolean isDone;

        public RecordWrapper(npe03__Recurring_Donation__c rd) {
            this.rd = rd;
            this.retriesRemaining = maxCancelRetries;
            this.isConfirmationRequired = false;
            this.isDone = false;
        }

        public npe03__Recurring_Donation__c getRecurringDonation() {
            return rd;
        }
    }
}
