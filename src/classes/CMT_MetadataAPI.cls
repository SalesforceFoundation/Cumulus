/*
    Copyright (c) 2018, Salesforce.org
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
* @date 2018
* @group Utilities
* @description Utility methods to handle manipulating CustomMetadataType objects through the Apex MD Api
*
*/
public class CMT_MetadataAPI {

    public static final String DEPLOYMENT_SUCCESS_TEXT = 'Succeeded';

    /**
     * @description Static list of queued metadata updates to submit in a single process rather than
     * one update at a time.
     */
    public static List<Metadata.CustomMetadata> cmtUpsertQueue = new List<Metadata.CustomMetadata>();

    /**
     * @description Queue a Custom MetadataType upsert operation to be submitted later as an ASync operation.
     * @param mdObject MetadataObject name
     * @param recordName Unique record name of the record to insert/update. Required for both insert and update.
     * @param recordLabel Record label of the record to insert/update. Required for insert.
     * @param fldValues Map of field names/values to upsert for the specified record.
     */
    public static void upsertCustomMetadata(CRLP_RollupCMT.MetadataObject mdObject, String recordName, String recordLabel, Map<String,Object> fldValues) {

        String mdTypeName = UTIL_Namespace.StrTokenNSPrefix(mdObject.Name() + '__mdt');

        // Setup custom metadata to be created or updated in the subscriber org.
        Metadata.CustomMetadata customMd = new Metadata.CustomMetadata();
        customMd.fullName = mdTypeName + '.' + recordName;
        if (recordLabel != null) {
            customMd.protected_x = false;
            customMd.label = recordLabel;
        }

        addFieldsToMetadataObject(customMd, fldValues);
        cmtUpsertQueue.add(customMd);
    }

    /**
     * @description Set field values on the specified Custom Metadata Type record
     * @param md CustomMetadata instance
     * @param fldValues Key-Value pair map of fields/values
     * @return Updated CustomMetadata object instance with the fields added to the values collection
     */
    public static Metadata.CustomMetadata addFieldsToMetadataObject(Metadata.CustomMetadata md, Map<String,Object> fldValues) {
        Metadata.CustomMetadataValue customField;
        for (String k : fldValues.keySet()) {
            customField = new Metadata.CustomMetadataValue();
            customField.field = UTIL_Namespace.StrAllNSPrefix(k);
            customField.value = fldValues.get(k);
            md.values.add(customField);
        }
        return md;
    }

    /**
     * @description We can't actually delete CMT's through the Apex API yet, but we'll wrap deleting into
     * this method so it can easily be implemented at some future point in time. For now, just set the custom
     * 'IsDeleted' boolean value to true. The operation does not commit the changes, but only queues it for
     * a future asynchronous commit.
     * @param mdObject MetadataObject name
     * @param recordName Unique record name of the record to insert/update. Required for both insert and update.
     */
    public static void deleteCustomMetadataTypeRecord(CRLP_RollupCMT.MetadataObject mdObject, String recordName) {
        upsertCustomMetadata(mdObject, recordName, null, new Map<String,Object>{
                'IsDeleted__c' => True
        });
    }

    /******************************************************************************************************************
     * @description Initiate a deployment of custom metadata type records.
     * @param mtToDeploy List of CustomMetadata objects to deploy
     * @param callback a MetadataCallBack to handle the deployment result
     *****************************************************************************************************************/
    public static Id deployMetadata(List<Metadata.CustomMetadata> mtToDeploy, Metadata.DeployCallback callback) {

        // Add all queued up metadata updates to the deployment container
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        for (Metadata.CustomMetadata md: mtToDeploy) {
            mdContainer.addMetadata(md);
        }

        // Enqueue custom metadata deployment and return the Job Id
        if (!Test.isRunningTest()) {
            return Metadata.Operations.enqueueDeployment(mdContainer, callback);
        }

        return null;
    }

    /******************************************************************************************************************
     * @description Initiate a deployment of custom metadata type records.
     * @param jobId Unique string to act as a "jobId" when writing the final deployment status to the Custom Settings
     * @param mtToDeploy List of CustomMetadata objects to deploy
     *****************************************************************************************************************/
    public static void deployMetadata(String jobId, List<Metadata.CustomMetadata> mtToDeploy) {
        deployMetadata(mtToDeploy, new MetadataCallBack(jobId));
    }

    /******************************************************************************************************************
     * @description Check the status of metadata deployment
     * @return Metadata.DeployResult JSON
     */
    public static Metadata.DeployResult getDeploymentResult(Id deploymentId) {
        Http h = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(Url.getOrgDomainUrl().toExternalForm() +
            '/services/data/v44.0/metadata/deployRequest/' +
            deploymentId +
            '?includeDetails=true');
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        HttpResponse response = h.send(request);
        DeploymentResponse deploymentResponse =
            (DeploymentResponse)JSON.deserialize(response.getBody(), DeploymentResponse.class);

        return deploymentResponse.deployResult;
    }

    /******************************************************************************************************************
     * @description Wrapper used to deserialize the deployment request response
     */
    private class DeploymentResponse {
        Metadata.DeployResult deployResult;
    }

    /**
     * @return A 10 character unique 'jobId' to use for deploying metadata
     */
    public static String getUniqueJobId() {
        return UserInfo.getUserId().left(15).right(4).toUpperCase() +
                String.valueOf(Integer.valueOf(math.rint(math.random()*5000000))).right(6);
    }


    /******************************************************************************************************************
     * @description Interface for Metadata Callback Handler
     * Is used to allow metadata deployments to have customized on result handlers
     *****************************************************************************************************************/
    public interface MetadataCallbackHandler {
        void performSuccessHandler(Map<String, Object> params, String status);
        void performErrorHandler(Map<String, Object> params, String status);
    }

    /******************************************************************************************************************
     * @description Inserting or Updating CMT's through the Apex Metadata API is an asynchronous process. This callback
     * class is used to handle the async response from the call to Metadata.Operations.enqueueDeployment().
     * If the call is not successfull, the Customizable_Rollup_Settings__c  record is updated
     * with the result status.
     *****************************************************************************************************************/
    public class MetadataCallBack implements Metadata.DeployCallBack {

        private String jobId;

        /**
         * @description  Handler to allow for calling functions to have customized result handling with parameters
         */
        public MetadataCallbackHandler callbackHandler { get; set; }
        public Map<String, Object> callbackParams {get; set;}

        /**
         * @description Constructor for Callback Class
         * @param jobId Some unique string value to use when writing the deployment status to the Custom Settings object
         */
        public MetadataCallBack(String jobId) {
            this.jobId = jobId;
        }

        /**
         * @description Method called by salesforce with the result of the Metadata deployment operation status.
         * This will write the status of the deployment to a CustomSettings object
         */
        public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {

            Boolean isSuccess = (result != null ? result.status == Metadata.DeployStatus.Succeeded : false);
            Map<String, String> statusMap = new Map<String, String>{ this.jobId => (result != null ? result.status.name() : 'Unknown') };
            // If the status is not Success, collect all errors into a string that can be written as the status
            if (result != null && result.status != Metadata.DeployStatus.Succeeded) {
                String errMsg = '';
                for (Integer n=0; n < result.details.componentFailures.size(); n++) {
                    errMsg += (n > 0 ? '\n' : '') + '* ' + result.details.componentFailures[n].fullName +
                            '> ' + result.details.componentFailures[n].problem;
                }
                // The custom settings field is a max of 255 characters, but need space for the serialized json overhead
                statusMap.put(this.jobId, errMsg.left(220));
                isSuccess = false;
            }

            if (isSuccess) {
                if (!Test.isRunningTest()) {
                    UTIL_OrgTelemetry_SVC.asyncProcessCMTChange(buildChangedMetadata(result));
                }

                if (callbackHandler != null) {
                    callbackHandler.performSuccessHandler(callbackParams, JSON.serializePretty(statusMap).left(255));
                }
            } else {
                if (callbackHandler != null) {
                    callbackHandler.performErrorHandler(callbackParams, JSON.serializePretty(statusMap).left(255));
                }
            }

            UTIL_PlatformCache platformCache = UTIL_PlatformCache.getInstance();
            platformCache.fireInvalidatePlatformCacheEvent('Custom Metadata Changed');
        }

        /**
         * @description This method iterates through the successful deployments and grabs the
         * object name. It will then pass into the UTIL_OrgTelemetry_SVC class to determine
         * whether or not to run the telemetry code.
         * @param result - Deployment Result
         * @return Set<String>
         */
        private Set<String> buildChangedMetadata(Metadata.DeployResult result) {
            Set<String> metadataObjectTypeSet = new Set<String>();

            for (Integer i = 0; i < result.details.componentSuccesses.size(); i++) {

                // Metadata full name for a custom metadata is in this format:
                // metadataObject.recordName
                // Example:
                // Opportunity_Stage_To_State_Mapping__mdt.FINALIZED
                String metadataFullName = result.details.componentSuccesses[i].fullName.toLowerCase();

                metadataObjectTypeSet.add(metadataFullName);
            }

            return metadataObjectTypeSet;
        }
    }
}