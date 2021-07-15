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
* @group Rollups
* @group-content ../../ApexDocContent/Rollups2.htm
* @description Abstract base class Non-Skew Mode batch rollup operations
*/
public abstract class CRLP_Batch_Base_NonSkew extends CRLP_Batch_Base {

    /*******************************************************************************************************
    * @description When Chunking mode is used for an LDV org, this is the last Id retrieved
    * in the previous batch. When the job is chained, it'll query records with Ids greater than this Id.
    */
    @TestVisible
    private Id lastIdProcessed;

    @TestVisible
    private CRLP_ApiService apiService {
        get {
            if (apiService == null) {
                apiService = new CRLP_ApiService();
            }
            return apiService;
        }
        set;
    }


    protected CRLP_Batch_Base_NonSkew() { }

    /**
     * @description These fields are used to check for Contacts or Accounts (Summary Object) that may have
     * non-zero values in these fields even though they have no attached opportunities. In that case,
     * the summary records are included in the queries/processing to ensure the values are reset accordingly.
     * The assumption is that these fields are inclusive of the types of values that might have been incremented
     * at some point when an Opportunity was inserted/updated, but maybe that Opportunity was deleted or the
     * reference changed.
     * The objective of this method is to identify one or more fields on the Summary object that help identify
     * if the rerord "ever" had rollups to it, even if there are no detail records currently to roll up. This
     * allows the rollup process to clear the rollups in the summary record if the last remaining detail record
     * is no longer eligible for rolling up (such as it was deleted).
    */
    @TestVisible
    private List<String> fieldsToCheckForNonZero {
        get {
            if (fieldsToCheckForNonZero == null) {
                List<String> fieldsToCheck = new List<String>();
                switch on (jobType) {
                    when AccountHardCredit, ContactHardCredit {
                        fieldsToCheck.add('npo02__NumberOfClosedOpps__c');
                        fieldsToCheck.add('npo02__NumberOfMembershipOpps__c');
                    }
                    when ContactSoftCredit {
                        fieldsToCheck.add(
                                SObjectType.Contact.fields.Number_of_Soft_Credits__c.getName());
                    }
                    when GAU {
                        fieldsToCheck.add(
                                SObjectType.General_Accounting_Unit__c.fields.Total_Number_of_Allocations__c.getName());
                    }
                    when AccountContactSoftCredit, AccountSoftCredit {
                        String fieldToCheck = getFirstTargetRollupField(jobType);
                        if (fieldToCheck != null) {
                            fieldsToCheck.add(fieldToCheck);
                        }
                    }
                }
                fieldsToCheckForNonZero = fieldsToCheck;
            }
            return fieldsToCheckForNonZero;
        }
        private set;
    }

    /**
     * @description For AccountContactSoftCredit and AccountSoftCredit rollups, since there are no packaged rollups
     * for these two types, this method will find the first target rollup field that is of a numeric type to use
     * in the fieldsToCheckForNonZero logic. This allows the batch rollup jobs to also retrieve accounts that have
     * a value in this field even if there is no data to rollup for the record.
     * @param jobType
     * @return Field api name
     */
    private String getFirstTargetRollupField(CRLP_RollupProcessingOptions.RollupType jobType) {
        String detailObjectName;
        String fieldToCheck;
        SObjectType targetObject;

        if (jobType == CRLP_RollupProcessingOptions.RollupType.AccountContactSoftCredit) {
            targetObject = Account.SObjectType;
            detailObjectName = UTIL_Describe.getObjectDescribe(UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')).getName();
        } else if (jobType == CRLP_RollupProcessingOptions.RollupType.AccountSoftCredit) {
            targetObject = Account.SObjectType;
            detailObjectName = UTIL_Describe.getObjectDescribe(UTIL_Namespace.StrAllNSPrefix('Account_Soft_Credit__c')).getName();
        } else {
            return null;
        }

        for (Rollup__mdt r : CRLP_Rollup_SEL.getRollupsBySummaryType().get(targetObject)) {
            if (r.Active__c == false) {
                continue;
            }
            Schema.DisplayType fieldType = UTIL_Describe.getFieldDisplaytype(
                String.valueOf(targetObject), r.Summary_Field__r.QualifiedApiName
            );
            if (fieldType != DisplayType.DOUBLE && fieldType != DisplayType.CURRENCY) {
                continue;
            }
            if (r.Amount_Object__r.QualifiedApiName == detailObjectName) {
                fieldToCheck = r.Summary_Field__r.QualifiedApiName;
                break;
            }

        }
        return fieldToCheck;
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup all records that meet the "Non Skew" criteria
     * @param jobType Defines the type of rollup job
     * @param jobFilter Allows for filtering the rollups on N-Day, Memberships, etc.
     */
    public CRLP_Batch_Base_NonSkew(CRLP_RollupProcessingOptions.RollupType jobType, CRLP_RollupProcessingOptions.RollupTypeFilter jobFilter) {
        super(jobType, jobFilter);
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup is for a specific set of Summary Object Id's
     * @param jobType Defines the type of rollup job
     * @param recordIds Specific set of parent record id's to roll up to
     */
    public CRLP_Batch_Base_NonSkew(CRLP_RollupProcessingOptions.RollupType jobType, Id lastIdProcessed) {
        super(jobType);
        this.lastIdProcessed = lastIdProcessed;
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup is for a specific set of Summary Object Id's
     * @param jobType Defines the type of rollup job
     */
    public CRLP_Batch_Base_NonSkew(CRLP_RollupProcessingOptions.RollupType jobType) {
        super(jobType);
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup is for a specific set of Summary Object Id's
     * @param jobType Defines the type of rollup job
     * @param recordIds Specific set of parent record id's to roll up to
     */
    public CRLP_Batch_Base_NonSkew(CRLP_RollupProcessingOptions.RollupType jobType, List<Id> recordIds) {
        super(jobType, recordIds);
    }

    /*******************************************************************************************************
    * @description Query all Summary records for the current type of Rollups based on the defined 'jobType'. Called by
    * the start() method of the individual batch jobs that extend this class.
    * @return database.Querylocator
    */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        try {
            // TODO Refactor to use the new CRLP_QueryBuilder class
            String query = getBatchStartQuery(
                    lastIdProcessed,
                    batchSizeChunkLimit,
                    fieldsToCheckForNonZero
            );

            UTIL_Debug.debug(LoggingLevel.WARN, '>> Batch Query =' + query);
            return Database.getQueryLocator(query);

        } catch (Exception ex) {
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP + '.' + this.jobType.name());
            return Database.getQueryLocator([SELECT Id FROM Account LIMIT 0]);
        }
    }

    /*******************************************************************************************************
    * @description Handle each group of Summary records to roll-up.
    * @param summaryRecords List of Summary records
    */
    public void execute(Database.BatchableContext bc, List<SObject> summaryRecords) {
         try {
            if (isChunkModeEnabled) {
                // Since execution contexts might not run in order (ex., chunk size 10k,
                // batch size 2k has 5 batches but they won't run in a guaranteed order)
                // we first need to check if the last Id is greater than the value in lastIdProcessed
                Id lastProcessedId = summaryRecords[summaryRecords.size() - 1].Id;
                if (lastIdProcessed == null || lastProcessedId > lastIdProcessed) {
                    lastIdProcessed = lastProcessedId;
                }
            }

            CRLP_RollupQueryBuilder queryBuilder = new CRLP_RollupQueryBuilder()
                    .withRollupType(jobType)
                    .withSummaryRecords(summaryRecords)
                    .withSummaryRecordIdsVar('summaryRecords')
                    .withBatchJobMode(CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode)
                    .withOrderBy(CRLP_Rollup_SVC.getParentFieldNameForQuery(jobType));

            if (CRLP_Rollup_SVC.hasActiveRollups(jobType)) {
                queryBuilder.includePaymentRecords();
            }

            String query = queryBuilder.buildDetailsQuery();

            List<SObject> detailRecords = Database.query(query);

            if (jobType == CRLP_RollupProcessingOptions.RollupType.ContactSoftCredit ||
                    jobType == CRLP_RollupProcessingOptions.RollupType.AccountContactSoftCredit) {
                detailRecords = convertContactRolesToPartialSoftCredits(detailRecords);
            }

            summaryRecords = excludeSummaryWithMissingDetailRecords(summaryRecords, detailRecords);

            // Are there any summary records left to process?
            if (summaryRecords.size() > 0) {
                Map<Id, List<SObject>> paymentsByOpp = getRelatedPayments(detailRecords);

                // Need to pass in the Rollup Type, Rollup Defnitions if they're available along
                // with the Summary Record(s), Detail Record(s) and any Related Records.
                CRLP_RollupProcessor processor = new CRLP_RollupProcessor()
                        .withRollupType(jobType)
                        .withSummaryRecords(summaryRecords)
                        .withDetailRecords(detailRecords)
                        .withRelatedRecords(paymentsByOpp);

                List<SObject> updatedRecords = processor.startRollupProcessing();
                this.totalRecordsProcessed += detailRecords.size();

                // Handle dml on the records to be updated
                if (updatedRecords != null && !updatedRecords.isEmpty()) {
                    CRLP_RollupProcessor_SVC.updateChangedRecordsWithLogging(updatedRecords, this.jobType);
                    this.totalRecordsModified += updatedRecords.size();
                    this.totalCommits++;
                }
            }

        } catch (Exception ex) {
            ex.setMessage(ex.getMessage() + '\n\nRollups State:\n' + CRLP_Debug_UTIL.getCurrentRollupState());
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP + '.' + this.jobType.name());
        }

        this.totalApexDmlRows += Limits.getDmlRows();
    }

    /**
     * @description Batch finish method. Logs the result if debugging is enabled. If chunking mode is enabled for
     * LDV orgs, chains the batch
     * @param bc
     */
    public void finish(Database.BatchableContext bc) {
        // In debug mode, write a summary of the job to the error log
        if (CRLP_Debug_UTIL.isDebuggingEnabled) {
            logDebugInfo((isChunkModeEnabled ? 'LastIdProcessed: ' + lastIdProcessed : ''));
        }

        // If chunk mode is enabled and there are more records to process,
        // submit the next batch job
        if (isChunkModeEnabled && hasAdditionalRecordsToProcess(lastIdProcessed)) {
            submitBatchableJobForNextChunk();
        }

        logJobResults(bc.getJobId());
    }

    /**
     * @description Loop through the Summary records and remove any that do not have Detail Objects to be rolled up
     * @param summaryRecords
     * @param detailRecords
     * @return a cleaned list of summary records
     */
    @TestVisible
    private List<SObject> excludeSummaryWithMissingDetailRecords(List<SObject> summaryRecords, List<SObject> detailRecords) {
        Set<Id> includeParentIds = buildParentIdsToIncludeFromDetails(detailRecords);

        Map<Id,List<CRLP_Rollup>> externalRollupStates = apiService.getBaseRollupStateForRecords(
            new Map<Id,SObject>(summaryRecords).keySet(),
            jobType
        );

        List<SObject> includeSummaryRecords = new List<SObject>();
        for (Integer n = 0, listSize = summaryRecords.size(); n < listSize; n++) {
            if (includeParentIds.contains(summaryRecords[n].Id) || hasRollupState(externalRollupStates, summaryRecords[n])) {
                includeSummaryRecords.add(summaryRecords[n]);

            } else if (this.summaryObjectType == Contact.SObjectType || this.summaryObjectType == Account.SObjectType) {
                // If the Account and Contact is the Summary record, and there are no detail records, but the object
                // has a value in any of these key rollup fields, then we need to include it so the values can be
                // updated (reset) as necessary
                for (String f : fieldsToCheckForNonZero) {
                    Object val = summaryRecords[n].get(f);

                    if (val != null && val != 0) {
                        includeSummaryRecords.add(summaryRecords[n]);
                        break;
                    }
                }
            }

        }

        return includeSummaryRecords;
    }

    /**
     * @description Builds a set of parent Ids to include based on detail records
     * @param detailRecords
     * @return Set<Id>
     */
    private Set<Id> buildParentIdsToIncludeFromDetails(List<SObject> detailRecords) {
        String relationshipName;
        String parentKeyField = CRLP_Rollup_SVC.getParentFieldNameForProcessing(jobType);

        // If keyField field has dot-notation (ex: Contact__r.AccountId), need to parse out the two components
        if (parentKeyField.contains('.')) {
            relationshipName = parentKeyField.split('\\.')[0];
            parentKeyField = parentKeyField.split('\\.')[1];
        }

        Set<Id> includeParentIds = new Set<Id>();
        for (Integer n = 0, listSize = detailRecords.size(); n<listSize; n++) {
            SObject detailRecord = detailRecords[n];
            if (String.isNotBlank(relationshipName)) {
                detailRecord = detailRecords[n].getSObject(relationshipName);
            }

            includeParentIds.add((String) detailRecord.get(parentKeyField));
        }

        return includeParentIds;
    }

    /**
     * @description Determines if summary record has external rollup state
     * @param externalRollupStates
     * @param summaryRecord
     * @return Boolean
     */
    private Boolean hasRollupState(Map<Id,List<CRLP_Rollup>> externalRollupStates, SObject summaryRecord) {
        return externalRollupStates.get(summaryRecord.Id) != null
            && !externalRollupStates.get(summaryRecord.Id).isEmpty();
    }

    /**
     * @description Retrieve a map of related Payments for each Detail record, but only if Payment Rollups are active
     * for the given rollup type
     * @param detailRecords
     * @return Map<Id, List<SObject>>
     */
    private Map<Id, List<SObject>> getRelatedPayments(List<SObject> detailRecords) {
        Map<Id, List<SObject>> paymentsByOpp = new Map<Id, List<SObject>>();
        if (hasActivePaymentRollupsForThisJob()
                && this.detailObjectType != Account_Soft_Credit__c.SObjectType
                && (this.summaryObjectType == Account.SObjectType || this.summaryObjectType == Contact.SObjectType)
        ) {
            paymentsByOpp = CRLP_RollupProcessor_SVC.splitChildRecordsInMapByParentId(detailRecords, 'npe01__OppPayment__r');
        }
        return paymentsByOpp;
    }

    /**
     * @description Submits another Rollup Job of the same type, passing in the starting Id as a
     * param to the batch job constructor.  Used to support chunk mode.  This enables the Batchable
     * class to fully encapsulate the responsibility of running itself in Chunk mode.
     */
    private void submitBatchableJobForNextChunk(){
        switch on (jobType) {
            when AccountHardCredit {
                Database.executeBatch(new CRLP_Account_BATCH(lastIdProcessed));
            }
            when ContactHardCredit {
                Database.executeBatch(new CRLP_Contact_BATCH(lastIdProcessed));
            }
            when ContactSoftCredit {
                Database.executeBatch(new CRLP_Contact_SoftCredit_BATCH(lastIdProcessed));
            }
        }
    }
}