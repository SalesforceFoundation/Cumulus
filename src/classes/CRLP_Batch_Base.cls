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
* @description Abstract base class for all Customizable Rollup batch jobs
*/
public abstract class CRLP_Batch_Base {

    /** @description The job type for this batch job -- AccountHardCredit, AccountSoftCredit, etc. */
    protected CRLP_RollupProcessingOptions.RollupType jobType;

    /** @description The default batch job mode - SkewMode (i.e., where the main batch job query is on the Detail object)
    * or NonSkew (where the main batch job query is on the Summary object) */
    protected CRLP_RollupProcessingOptions.BatchJobMode jobMode = CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode;

    /** @description The default filter to apply to Rollups type records for the processing */
    protected CRLP_RollupProcessingOptions.RollupTypeFilter jobFilter = CRLP_RollupProcessingOptions.RollupTypeFilter.All;

    /** @description This is built one time at the start of the batch process and then re-used throughout
     * the rest of the batch processing logic. This data is passed in the
     * ProcessingOptions collection to the processor. It's also used to pre-generate the SOQL used to retrieve
     * summary or detail records rather than build that in every single batch iteration. Basically this collection
     * is injected into the CRLP_Rollup_SEL cache to significantly simplify and narrow the number of records
     * retrieved and cached throughout the job.
     */
    protected List<Rollup__mdt> statefulCacheOfRollupsToBeProcessed = new List<Rollup__mdt>();

    /**
     * @description Map of Opportunity Id's already processed by Account to avoid duplicating a donation amount
     * to the Account when rolling up soft credits by the Contact.AccountId
     */
    protected Map<Id,Set<Id>> statefulMapOfOppIdsByParentId = new Map<Id, Set<Id>>();

    /** @description Simple counters used to track state */
    protected Integer batchIteration = 0;

    /** @description Simple counters used to track state */
    protected Integer totalRecordsProcessed = 0;
    protected Integer totalApexDmlRows = 0;

    /** @description Simple counters used to track state */
    protected Integer totalRecordsModified = 0;

    /** @description Simple counters used to track state */
    protected Integer totalCommits=0;

    /** @description Specified list of Summary (Account, Contact or GAU) Id's to roll up */
    protected List<Id> recordIds;

    /** @description The Summary Object Type this batch job will process */
    protected SObjectType summaryObjectType;

    /** @description The Detail Object Type this batch job will process */
    protected SObjectType detailObjectType;

    /** @description The Detail Object field that will be used in the inner join */
    protected String keyField;

    /** @description Whether this class was constructed from within a scheduled job */
    @TestVisible
    protected Boolean isScheduledJob {
        get {
            return isScheduledJob;
        }
        private set;
    }

    /** @description The customizable rollup custom settings */
    protected Customizable_Rollup_Settings__c customizableRollupSettings;

    public CRLP_Batch_Base(){}

    /*******************************************************************************************************
     * @description Constructs the class - rollup is for a specific RollupType and RollupTypeFilter
     */
    public CRLP_Batch_Base(CRLP_RollupProcessingOptions.RollupType jobType, CRLP_RollupProcessingOptions.RollupTypeFilter jobFilter) {
        initializeJobData(jobType, jobFilter, null);
    }


    /*******************************************************************************************************
     * @description Constructs the class - Rollup is a specific RollupType and a specific set of Summary Object Id's
     */
    public CRLP_Batch_Base(CRLP_RollupProcessingOptions.RollupType jobType, List<Id> recordIds) {
        initializeJobData(jobType, null, recordIds);
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup is for a specific RollupType
     */
    public CRLP_Batch_Base(CRLP_RollupProcessingOptions.RollupType jobType) {
        initializeJobData(jobType, null, null);
    }

    /**
     * @description Called during the start() method for the actual batch job to initialize the summary object, detail
     * object, key field, and if there are payment rollups that need to be included for the given summary object
     */
    @TestVisible
    protected void initializeJobData(
            CRLP_RollupProcessingOptions.RollupType jobType,
            CRLP_RollupProcessingOptions.RollupTypeFilter jobFilter,
            List<Id> recordIds) {

        this.jobType = jobType;
        if (jobFilter != null) {
            this.jobFilter = jobFilter;
        }
        this.recordIds = recordIds;

        this.summaryObjectType = CRLP_Rollup_SVC.getSummaryObjectType(this.jobType);

        this.statefulCacheOfRollupsToBeProcessed = CRLP_Rollup_SEL.getRollupDefinitionsToUse(this.jobType, this.jobFilter);
        this.isScheduledJob = System.isScheduled();
        this.customizableRollupSettings = UTIL_CustomSettingsFacade.getCustomizableRollupSettings();

        this.detailObjectType = CRLP_Rollup_SVC.getDetailObjectType(jobType);
        this.keyField = CRLP_Rollup_SVC.getParentFieldNameForQuery(jobType);
    }


    /**
     * @description For a given set of records, returns a Set<Id> of parent records using the passed field name as the parent
     * @param detailRecords List<SObject>
     * @param parentKeyField API Name of the parent field to use for the Id
     * @return List<Id>
     */
    protected List<Id> getParentIdsFromDetailRecords(List<SObject> detailRecords, String parentKeyField) {
        Set<Id> parentIdSet = new Set<Id>();
        List<Id> parentIds = new List<Id>();
        // If the parentKeyField is something like Contact.AccountId, then have to retrieve the parent SObject
        // first and then get the field value.
        String parentObjectField;
        if (parentKeyField.contains('.')) {
            parentObjectField = parentKeyField.split('\\.')[0];
            parentKeyField = parentKeyField.split('\\.')[1];
        }
        for (SObject dtl : detailRecords) {
            SObject dtlRecord = dtl;
            if (parentObjectField != null) {
                dtlRecord = dtl.getSObject(parentObjectField);
            }
            if (dtlRecord.get(parentKeyField) != null) {
                Id parentId = (Id)dtlRecord.get(parentKeyField);
                // Use a set to ensure that the parentId is only in the collection one time since there is no
                // contains() yet, but use a List to keep the parentId records in the exact same sequence
                // that they are in the details collection
                if (!parentIdSet.contains(parentId)) {
                    parentIds.add(parentId);
                    parentIdSet.add(parentId);
                }
            }
        }
        return parentIds;
    }

    /** @description Are there Payment rollups to execute? */
    private Boolean hasPaymentRollups = null;
    public Boolean hasActivePaymentRollupsForThisJob() {
        if (hasPaymentRollups == null) {
            this.hasPaymentRollups = CRLP_Rollup_SVC.hasActivePaymentRollupsForSObject(this.summaryObjectType);
        }
        return hasPaymentRollups;
    }

    /********************************************************************************************************
     * @description Soft Credit roll-ups work by querying the OCR object as the main object, but sending
     * PartialSoftCredit records as the detail records for the rollups. This is because PSC has a custom field
     * for Amount and generally the rule is that every Donation has an OCR record, but may or may not have a PSC
     * record. This method creates non-committed PartialSoftCredit records where one doesn't already exist to
     * use for the rollups process.
     * @param ocrs List<OpportunityContactRole>
     * @return List<Partial_Soft_Credit__c>
     */
    protected List<Partial_Soft_Credit__c> convertContactRolesToPartialSoftCredits(List<OpportunityContactRole> ocrs) {
        // These are both referenced in the SOQL created by buildDetailObjectQueryForRollup().
        List<Id> oppIds = getParentIdsFromDetailRecords(ocrs, 'OpportunityId');
        List<Id> contactIds = getParentIdsFromDetailRecords(ocrs, 'ContactId');

        String oppQuery = CRLP_Query_SEL.buildDetailObjectQueryForRollup(
                Opportunity.SObjectType,
                new List<SObjectType>{ OpportunityContactRole.SObjectType, Partial_Soft_Credit__c.SObjectType }
            );
        oppQuery += ' WHERE Id IN :oppIds';

        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>((List<Opportunity>)Database.query(oppQuery));

        List<Partial_Soft_Credit__c> partialSoftCredits = new List<Partial_Soft_Credit__c>();
        for (OpportunityContactRole ocr : ocrs) {
            Opportunity opp = oppById.get(ocr.OpportunityId);

            Partial_Soft_Credit__c matchedPSC = matchOrBuildPartialSoftCredit(opp, ocr);

            partialSoftCredits.add(matchedPSC);
        }

        return partialSoftCredits;
    }

    /**
     * @description For the given Opportunity and OpportunityContactRole, either match the OCR to an existing
     * partialSoftCredit record or instantiate a new 'dummy' one that can be used for the Soft Credit Rollup job.
     * @param opp Opportunity
     * @param ocr OpportunityContactRole
     * @return Partial_Soft_Credit__c
     */
    private Partial_Soft_Credit__c matchOrBuildPartialSoftCredit(Opportunity opp, OpportunityContactRole ocr) {
        // Find the matching PartialSoftCredit record for the OCR record; if there is one
        Partial_Soft_Credit__c matchedPSC;
        for (Partial_Soft_Credit__c psc : opp.Partial_Soft_Credits__r) {
            if (psc.Contact__c == ocr.ContactId) {
                matchedPSC = psc.clone(true, true, true, true);
                matchedPSC.Opportunity__r = opp;
                break;
            }
        }
        if (matchedPSC == null) {
            // If there is no matched PartialSoftCredit record for this OCR, create a new one (not committed)
            // and set the Amount to the full Amount value from the Opportunity record.
            matchedPSC = new Partial_Soft_Credit__c(
                    Opportunity__c = opp.Id,
                    Opportunity__r = opp,
                    Contact__r = ocr.Contact,
                    Contact__c = ocr.ContactId,
                    Contact_Role_ID__c = ocr.Id,
                    Role_Name__c = ocr.Role,
                    Amount__c = opp.Amount
            );
            if (UserInfo.isMultiCurrencyOrganization()) {
                matchedPSC.put('CurrencyIsoCode', opp.get('CurrencyIsoCode'));
            }
        }

        return matchedPSC;
    }

    /******************************** Helper Methods *****************************/

    /**
     * @description Builds and returns batch job start query string.  The BatchQueryBuilder instance
     * needs to be constructed here in the top-level CRLP_Batch_Base class so that a reference to it
     * can be passed in to the BatchQueryBuilder constructor, making the top-level class variables
     * accessible to the inner class. Used in the start method of the CRLP_Batch_Base_NonSkew class.
     * @param lastIdProcessed The last processed Id from the previous chunk.
     * @param chunkSize The size of each chunk - used in the LIMIT statement in the query.
     * @param fieldsToCheckForNonZero A list of fields that were checked for non-zero values,
     * used in the query.
     * @return The query string to be used by the batch start method.
     */
    @TestVisible
    protected String getBatchStartQuery(Id lastIdProcessed, Integer chunkSize, List<String> fieldsToCheckForNonZero) {

        BatchQueryBuilder builder = new BatchQueryBuilder(
                this,
                lastIdProcessed,
                chunkSize,
                fieldsToCheckForNonZero
        );

        return builder.buildQuery();
    }

    /** TODO Merge this with the new CRLP_QueryBuilder class
     * @description Inner Class used to build the start method query.
     */
    public class BatchQueryBuilder {
        /**
         * @description the CRLP_Batch_Base instance that created this class instance.  Enables this
         * instance to access the member variables in the initializing class.
         */
        CRLP_Batch_Base base;
        Integer chunkSize;
        Id lastIdProcessed;
        List<String> additionalFieldsToQuery;

        @TestVisible
        BatchQueryBuilder(
                CRLP_Batch_Base base,
                Id lastIdProcessed,
                Integer chunkSize,
                List<String> additionalFieldsToQuery
        ) {
            this.base = base;
            this.lastIdProcessed = lastIdProcessed;
            this.chunkSize = chunkSize;
            this.additionalFieldsToQuery = additionalFieldsToQuery;
        }

        /**
         * @description Uses the local and base class variables to construct the batch class
         * start query.
         * @return The query string.
         */
        @TestVisible
        String buildQuery() {
            switch on (base.jobMode) {
                when NonSkewMode {
                    return buildQueryForNonSkewJob();
                }
                when else {
                    return null;
                }
            }
        }

        /**
         * @description Uses the local and base class variables to construct the batch class
         * start query for Non Skew jobs.
         * @return The query string.
         */
        String buildQueryForNonSkewJob(){
            // Build a query string of the target Summary object.
            String query = CRLP_Query_SEL.buildObjectQueryForRollup(base.summaryObjectType);

            // Fields in the fieldsToCheckForNonZero[] list must always be in the Contact query
            if (additionalFieldsToQuery != null) {
                for (String f : additionalFieldsToQuery) {
                    if (!query.containsIgnoreCase(f)) {
                        query = query.split(' FROM ')[0] + ', ' + f + ' FROM ' + query.split(' FROM ')[1];
                    }
                }
            }

            List<String> whereClauses = new List<String>();

            // Add additional query filters as needed
            if (base.recordIds != null && base.recordIds.size() > 0) {
                whereClauses.add('Id IN :recordIds');
            } else {
                // Exclude Accounts or Contacts that will be rolled up in the SkewMode batch job
                String skewClause = CRLP_RollupBatch_SVC.getSkewWhereClause(base.jobType, CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode);
                if (!String.isEmpty(skewClause)) {
                    whereClauses.add(skewClause);
                }

                if (lastIdProcessed != null) {
                    whereClauses.add('Id > \'' + lastIdProcessed + '\'');
                }

                String innerJoinWhereClause = getMainQueryInnerJoinFilter();
                if (innerJoinWhereClause != null) {
                    whereClauses.add(innerJoinWhereClause);
                }
            }

            if (!whereClauses.isEmpty()) {
                query += ' WHERE ' + String.join(whereClauses, ' AND ');
            }

            // If there are no active rollups for the object type, then force the query to return zero records.
            if (CRLP_Rollup_SVC.hasActiveRollups(base.jobType) == false) {
                // This is needed because can't return null as a valid iterator.
                query += ' LIMIT 0';
            } else if (base.recordIds == null) {
                if (base.isChunkModeEnabled) {
                    query += ' ORDER BY Id LIMIT ' + chunkSize;
                }
            }
            return query;
        }

        /**
         * @description Produces the where clause that should be used for the inner join
         * @return The WHERE clause, as a string, that should be used to filter the detail records
         */
        @TestVisible
        String getMainQueryInnerJoinFilter() {
            String whereClause = null;
            Boolean hasMaxValuesForIncrementalMode = (maxDaysAgo != null || maxYearsAgo != null);

            if (getIsIncrementalModeEnabled() && hasMaxValuesForIncrementalMode) {
                whereClause = buildIncrementalModeWhereClause();
            } else {
                if (base.customizableRollupSettings.Disable_Related_Records_Filter__c == false) {
                    whereClause = buildNonIncrementalModeWhereClause();
                }
            }
            return whereClause;
        }

        /**
         * @description Produces the where clause that should be used for the inner join when NOT in incremental mode
         * @return The WHERE clause, as a string, that should be used to filter the detail records
         */
        String buildNonIncrementalModeWhereClause() {
            String whereClause = null; //will return null if this method is called from an unsupported rollup type

            switch on (base.jobType) {
                when AccountHardCredit, ContactHardCredit {
                    whereClause = 'Id IN (' +
                            'SELECT ' + base.keyField + ' ' +
                            'FROM ' + base.detailObjectType + ')';
                }
                when ContactSoftCredit {
                    whereClause = 'Id IN (SELECT ContactId FROM OpportunityContactRole)';
                }
                when AccountContactSoftCredit, AccountSoftCredit {
                    // It's not possible to do an inner query on this due to the following Salesforce error:
                    // "The inner select field 'Contact.AccountId' cannot have more than one level of relationships"
                }
                when RecurringDonations {
                    // There is little value to restricting the query locator with an inner select based upon Opportunities, since almost all RDs will
                    // be associated with an Opportunity.  A previous version of this code used an inner select that caused issues with timeouts in one large org.
                    // Cost vs benefit analysis suggests that the value of the additional restriction is not worth the cost.
                }
            }
            return whereClause;
        }

        /**
         * @description Produces the where clause that should be used for the inner join when in incremental mode
         * @return The WHERE clause, as a string, that should be used to filter the detail records
         */
        String buildIncrementalModeWhereClause() {
            String whereClause = 'Id IN (' +
                    'SELECT ' + base.keyField + ' ' +
                    'FROM ' + base.detailObjectType + ' ' +
                    'WHERE ';

            if (hasIncrementalFieldOverrides) {
                whereClause += overrideForLastNDaysField + ' >= LAST_N_DAYS:' + overrideForLastNDaysValue;
            } else {
                // Set to CloseDate for testing, SystemModstamp for prod.
                String whereClauseDateField = Test.isRunningTest() ? 'CloseDate' : 'SystemModstamp';
                whereClause += whereClauseDateField + ' ';

                if (maxDaysAgo != null && maxYearsAgo != null) {
                    if ((maxDaysAgo / 365) > maxYearsAgo) {
                        whereClause += '>= LAST_N_DAYS:' + maxDaysAgo;
                    } else {
                        whereClause += '>= LAST_N_YEARS:' + maxYearsAgo;
                    }
                } else if (maxDaysAgo != null) {
                    whereClause += '>= LAST_N_DAYS:' + maxDaysAgo;
                } else if (maxYearsAgo != null) {
                    whereClause += '>= LAST_N_YEARS:' + maxYearsAgo;
                }
            }
            return whereClause += ')';
        }

        /**
         * @description Determines whether the rollup should be run in incremental mode
         * @return true if the rollup should be run in incremental mode, otherwise false
         */
        Boolean getIsIncrementalModeEnabled() {
            if (base.isScheduledJob == null || base.isScheduledJob == false) {
                return false;
            }

            switch on (base.jobMode) {
                when NonSkewMode {
                    switch on (base.jobType) {
                        when AccountHardCredit {
                            return base.customizableRollupSettings.AccountHardCreditNonSkew_Incremental__c;
                        }
                        when ContactHardCredit {
                            return base.customizableRollupSettings.ContactHardCreditNonSkew_Incremental__c;
                        }
                        when else {
                            return false;
                        }
                    }
                }
                when else {
                    return false;
                }
            }
        }

        /**
         * @description The max Integer for all active time-bound Days_Back rollups,
         * or null if there are no active time-bound Days_Back rollups for this summary object
         */
        Integer maxDaysAgo {
            get {
                if (maxDaysAgo == null) {
                    maxDaysAgo = getMaxIntegerValueFromRollupsForType(CRLP_Operation.TimeBoundOperationType.Days_Back);
                }
                return maxDaysAgo;
            }
            private set;
        }

        /**
         * @description The max Integer for all active time-bound Years_Ago rollups,
         * or null if there are no active time-bound Years_Ago rollups for this summary object
         */
        private Integer maxYearsAgo {
            get {
                if (maxYearsAgo == null) {
                    maxYearsAgo = getMaxIntegerValueFromRollupsForType(CRLP_Operation.TimeBoundOperationType.Years_Ago);
                }
                return maxYearsAgo;
            }
            private set;
        }

        /**
         * @description Returns the maximum integer for time-bound rollups by time-bound type
         * @param timeBoundType Time-bound type for which the max integer should be calculated
         * @return max integer for the specified time bound type
         */
        Integer getMaxIntegerValueFromRollupsForType(CRLP_Operation.TimeBoundOperationType timeBoundType) {
            Integer maxInteger = null;
            for (Rollup__mdt rollup : base.statefulCacheOfRollupsToBeProcessed) {
                if (rollup.Active__c == true
                        && String.isNotBlank(rollup.Time_Bound_Operation_Type__c)
                        && rollup.Time_Bound_Operation_Type__c == timeBoundType.name()
                        && rollup.Integer__c != null) {
                    if (maxInteger == null || rollup.Integer__c > maxInteger) {
                        maxInteger = (Integer) rollup.Integer__c;
                    }
                }
            }
            return maxInteger;
        }

        /**
         * @description Returns true if the org has configured a
         * user-defined inner join for incremental rollups
         */
        Boolean hasIncrementalFieldOverrides {
            get {
                return overrideForLastNDaysField != null && overrideForLastNDaysValue != null;
            }
        }

        /**
         * @description Value to use with LAST_N_DAYS: in the inner join query
         * when the org has the user-defined inner join for incremental rollups
         */
        Integer overrideForLastNDaysValue {
            get {
                if (overrideForLastNDaysValue == null) {
                    if (base.customizableRollupSettings.Rollups_IncrementalLastNDays_ValOverride__c != null) {
                        overrideForLastNDaysValue = (Integer) base.customizableRollupSettings.Rollups_IncrementalLastNDays_ValOverride__c;
                    }
                }
                return overrideForLastNDaysValue;
            }
            set;
        }

        /**
         * @description API name of the date field to use as in the inner join query
         * when the org has the user-defined inner join for incremental rollups
         */
        String overrideForLastNDaysField {
            get {
                if (overrideForLastNDaysField == null) {
                    if (String.isNotBlank(base.customizableRollupSettings.Rollups_IncrementalLastNDays_FldOverride__c)) {
                        overrideForLastNDaysField = base.customizableRollupSettings.Rollups_IncrementalLastNDays_FldOverride__c;
                    }
                }
                return overrideForLastNDaysField;
            }
            set;
        }
    }

    /**
    * @description Checks whether chunk mode is enabled for this job.  In an LDV Org, there may be
    * too many records to query in the main query. Core support has recommended a chunking approach
    * where the main query is limited to under 1M records and the finish() method kicks off the job
    * again starting with the last Id that was queried.
    * @return True if chunk mode is enabled, false otherwise.
    */
    protected Boolean isChunkModeEnabled {
        get {
            return batchSizeChunkLimit != null && batchSizeChunkLimit > 0;
        }
    }

    /**
     * @description The chunk size used to limit the number of records returned in the main query.
     * Used in chunk mode.
     * @return Limit value to use or null if chunking is not enabled.
     */
    @TestVisible
    protected Integer batchSizeChunkLimit {
        get {
            if (batchSizeChunkLimit == null) {
                Decimal rtnValue;
                switch on (jobType) {
                    when AccountHardCredit {
                        rtnValue = customizableRollupSettings.ChunkSize_Account_HardCredit__c;
                    }
                    when ContactHardCredit {
                        rtnValue = customizableRollupSettings.ChunkSize_Contact_HardCredit__c;
                    }
                    when ContactSoftCredit {
                        rtnValue = customizableRollupSettings.ChunkSize_Contact_SoftCredit__c;
                    }
                }
                batchSizeChunkLimit = (rtnValue > 0 ? rtnValue.intValue() : null);
            }
            return batchSizeChunkLimit;
        }
        set;
    }

    /**
     * @description Checks whether there are additional records to be processed when in chunk mode.
     * @param lastIdProcessed The last processed Id.
     * @return True if there are any records that still need to be processed.
     */
    @TestVisible
    protected Boolean hasAdditionalRecordsToProcess(Id lastIdProcessed) {
        Integer queryLimitForAdditionalRecordsCheck = 1;
        BatchQueryBuilder builder = new BatchQueryBuilder(
                this,
                lastIdProcessed,
                queryLimitForAdditionalRecordsCheck,
                null
        );
        String query = builder.buildQuery();
        return Database.query(query).size() == 1;
    }

    /*******************************************************************************************************
     * @description CRLP Batch Job custom exception
     */
    public class CRLPBatchException extends Exception {}

    /*******************************************************************************************************
     * @description Shared method to log an Error record when a CRLP Batch is skipped because
     * the previous job hadn't yet completed
     * @param className The name of the skipped batch class to be used in the error message
     */
    protected void logDuplicateBatchError(String className) {

        CRLPBatchException ex = new CRLPBatchException();
        ex.setMessage(String.format(Label.CRLP_BatchSkipped, new List<String>{className}));
        ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP);

    }

    /**
     * @description Only called by the Finish() method if debug logging is enabled to log state
     * @param String addlLogData
     */
    protected void logDebugInfo(String addlLogData) {
        Error__c logEntry = new Error__c(
            Context_Type__c = ERR_Handler_API.Context.CRLP.name() + ': ' + this.jobType.name() + ' ' + this.jobMode.name(),
            Error_Type__c = 'DEBUG LOG',
            Full_Message__c = (
                'Total Batch Iterations: ' + this.batchIteration +
                '\nTotal DML Operations: ' + this.totalCommits +
                '\nTotal Records Updates: ' + this.totalRecordsModified +
                addlLogData + '\n' +
                '\nRollups State:\n' + CRLP_Debug_UTIL.getCurrentRollupState()
            ).left(32768)
        );
        insert logEntry;
    }

    protected void updateLogData() {
        this.totalRecordsProcessed += Limits.getQueryRows();
        this.totalApexDmlRows += Limits.getDmlRows();
    }

    protected void logJobResults(Id batchjobId) {
        this.totalApexDmlRows += Limits.getDmlRows();

        String jobName = ERR_Handler_API.Context.CRLP.name() + ': ' + this.jobType.name() + ' ' + this.jobMode.name();
        UTIL_BatchJobService.logJobResult(batchjobId, jobName, this.totalRecordsProcessed,
            this.totalRecordsModified, this.totalCommits, this.totalApexDmlRows);
    }
}