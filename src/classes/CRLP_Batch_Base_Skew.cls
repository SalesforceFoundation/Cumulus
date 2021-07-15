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
* @description Abstract base class Skew Mode batch rollup operations
*/
public abstract class CRLP_Batch_Base_Skew extends CRLP_Batch_Base {
    protected CRLP_Batch_Base_Skew() { }

    /**
     * @description Because Salesforce may call the execute method with sorted blocks of data out of sequence
     * it's necessary to store the working rollup data in a stateful map. Rather than write the current state to
     * the parent record multiple times, the code will keep uncommitted rollup data in the stateful var for up to
     * this number of batch iterations. After that number, the record will be committed to the database.
     * Salesforce can easily put data significantly out of sequence -- hundreds or even thousands of batch iterations.
     */
    private Integer MAX_BATCHES_TO_HOLD_BEFORE_COMMIT = 1500;

    /** @description The last Id of a set of records passed to this method. Passed back to the SkewDispatcher batch job */
    private Id lastIdProcessedForChunking;

    /**
     * @description Rather than commit the parent record every time the lastParentIdProcessed is changed,
     * which can cause a single parent to be committed multiple times, this is used to track which parent records
     * have not yet been committed. This is useful when Salesforce calls the execute() method with blocks of data
     * out of sequence.
     */
    protected Map<Id, Integer> parentIdsNotCommittedWithBatch = new Map<Id, Integer>();

    /**
    * @description Stateful collection of Rollups used to hold Rollups for Contacts and Accounts that
    * span beyond a single batch iteration
    */
    protected Map<Id, List<CRLP_Rollup>> statefulRollupsById = new Map<Id, List<CRLP_Rollup>>();

    /*******************************************************************************************************
     * @description Constructs the class - Rollup all Accounts that meet the "Non Skew" criteria
     * @param jobType Defines the type of rollup job
     * @param jobFilter Allows for filtering the rollups on N-Day, Memberships, etc.
     */
    public CRLP_Batch_Base_Skew(CRLP_RollupProcessingOptions.RollupType jobType, CRLP_RollupProcessingOptions.RollupTypeFilter jobFilter) {
        super(jobType, jobFilter);
        this.jobMode = CRLP_RollupProcessingOptions.BatchJobMode.SkewMode;
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup is for a specific set of Account Id's
     * @param jobType Defines the type of rollup job
     * @param jobFilter Allows for filtering the rollups on N-Day, Memberships, etc.
     */
    public CRLP_Batch_Base_Skew(CRLP_RollupProcessingOptions.RollupType jobType, List<Id> recordIds) {
        super(jobType, recordIds);
        this.jobMode = CRLP_RollupProcessingOptions.BatchJobMode.SkewMode;
    }

    /*******************************************************************************************************
     * @description Constructs the class - Rollup is for a specific set of Account Id's
     * @param jobType Defines the type of rollup job
     * @param jobFilter Allows for filtering the rollups on N-Day, Memberships, etc.
     * @param lastIdProcessedForChunking If this job is called by the SkewDispatcher job, this is the last Id queried
     * by that job; and is passed back into SkewDispatcher job constructor for the next group of records.
     */
    public CRLP_Batch_Base_Skew(CRLP_RollupProcessingOptions.RollupType jobType, List<Id> recordIds, Id lastIdProcessedForChunking) {
        super(jobType, recordIds);
        this.jobMode = CRLP_RollupProcessingOptions.BatchJobMode.SkewMode;
        this.lastIdProcessedForChunking = lastIdProcessedForChunking;
    }

    /*******************************************************************************************************
    * @description Build a query of Detail records based on the specified Summary Object Type and Job Type. Called by
    * the start() method of the individual batch jobs that extend this class.
    * @return database.Querylocator
    */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query;
        try {

            query = buildQueryLocatorAsSOQL();

            UTIL_Debug.debug(LoggingLevel.WARN, '>> Batch Query =' + query);

            return Database.getQueryLocator(query);
        } catch (Exception ex) {
            ex.setMessage(ex.getMessage() + '\n\n' + query);
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP + '.' + this.jobType.name());
            return Database.getQueryLocator([SELECT Id FROM Account LIMIT 0]);
        }
    }

    /*******************************************************************************************************
    * @description Handle each group of Detail records to roll-up (i.e., LDV mode). A Stateful collection of
    * CRLP_Rollup instances is used to accumulate the rolled up values by Parent Id across multiple calls to this
    * exection() method with more and more detailsRecords for the same parent.
    * @param detailRecords List of Detail (Allocation, Opportunity, or OpportunityContactRole) records
    */
    public void execute(Database.BatchableContext bc, List<SObject> detailRecords) {

        this.batchIteration++;
        this.totalRecordsProcessed += detailRecords.size();

        try {
            // Retrieve and store the cached list of Rollup__mdt records into the Rollups Processor
            // so that the list never changes throughout the life of the batch job
            if (this.statefulCacheOfRollupsToBeProcessed != null) {
                CRLP_Rollup_SEL.addRollupsToCache(this.jobType, this.jobFilter,
                    this.statefulCacheOfRollupsToBeProcessed);
            }

            String parentKeyField = CRLP_Rollup_SVC.getParentFieldNameForQuery(jobType);
            String parentObjectField;

            // The parentKeyField field may be have dot-notation (ex: Contact__r.Account__c)
            // If this is the case, need to parse out the two components to use
            if (parentKeyField.contains('.')) {
                parentObjectField = parentKeyField.split('\\.')[0];
                parentKeyField = parentKeyField.split('\\.')[1];
            }

            Id firstParentId, lastParentId;
            if (parentObjectField == null) {
                firstParentId = (Id)detailRecords[0].get(parentKeyField);
                lastParentId = (Id)detailRecords[detailRecords.size()-1].get(parentKeyField);
            } else {
                SObject dtlRecord = detailRecords[0].getSObject(parentObjectField);
                firstParentId = (Id)dtlRecord.get(parentKeyField);
                dtlRecord = detailRecords[detailRecords.size()-1].getSObject(parentObjectField);
                lastParentId = (Id)dtlRecord.get(parentKeyField);
            }

            // Get all parent records to be processed by this batch iteration
            List<Id> parentIds = getUniqueParentIds(this.summaryObjectType, detailRecords,
                (parentObjectField != null ? parentObjectField + '.' : '') + parentKeyField);

            // If there is any post-query filtering that needs to be applied, do it here
            detailRecords = applyPostQueryLocatorFilters(detailRecords);

            // Map of Payment Child details by parent Opportunity (this job only handles Opportunity or Allocation
            // as the primary queryLocator).
            Map<Id, List<npe01__OppPayment__c>> paymentsByOpp = getRelatedPayments(detailRecords);

            // Get the Summary (target) records for the current set of Detail Records
            String soql = CRLP_Query_SEL.buildObjectQueryForRollup(summaryObjectType) + ' WHERE Id IN :parentIds ORDER BY Id';

            // Resequence the Parent (Summary) records to be in the exact order of the detail records
            // using the defined parent Id
            List<SObject> summaryRecords = queryAndSequenceSummaryRecords(parentIds, soql);

            // Contact-level Account Soft Credit rollups require changing the detail object type to PartialSoftCredit
            if (CRLP_Rollup_SVC.isOppContactRoleSoftCreditRollup(this.jobType)) {
                detailRecords = convertContactRolesToPartialSoftCredits(detailRecords);
            }

            CRLP_RollupProcessingOptions.ProcessingOptions options = new CRLP_RollupProcessingOptions.ProcessingOptions();
            options.useRollupDefsByParentIdMap = true;

            // Need to pass in the Rollup Type, Rollup Defnitions if they're available along
            // with the Summary Record(s), Detail Record(s) and any Related Records.
            CRLP_RollupProcessor processor = new CRLP_RollupProcessor()
                .withRollupType(jobType)
                .withBatchJobMode(jobMode)
                .withSummaryRecords(summaryRecords)
                .withDetailRecords(detailRecords)
                .withRelatedRecords(paymentsByOpp)
                .withPreviouslyProcessedOppIdsMap(this.statefulMapOfOppIdsByParentId)
                .withRollupDefinitions(this.statefulRollupsById)
                .withJobOptions(options);

            List<SObject> updatedRecords = processor.startRollupProcessing();

            saveFirstAndLastParentIdData(processor, firstParentId, lastParentId);

            // Handle dml on the records to be updated
            if (updatedRecords != null && !updatedRecords.isEmpty()) {
                CRLP_RollupProcessor_SVC.updateChangedRecordsWithLogging(updatedRecords, this.jobType);
                this.totalRecordsModified += updatedRecords.size();
                this.totalCommits++;

                // If the record was committed and the Id is in the parentIdsNotCommittedWithBatch collection
                // that tracks the last batch iteration by Id, remove it from that collection now that it's committed.
                for (SObject s : updatedRecords) {
                    if (this.parentIdsNotCommittedWithBatch.containsKey(s.Id)) {
                        this.parentIdsNotCommittedWithBatch.remove(s.Id);
                    }
                }
            }

        } catch (Exception ex) {
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP + '.' + this.jobType.name());
        }

        this.totalApexDmlRows += Limits.getDmlRows();
    }

    /********************************************************************************************************
     * @description Called when all processing is complete for the batch job. Since this job is working from the
     * Detail object, there will be one parent record to finish the update for.
     * Log any captured DML errors.
     */
    public void finish(Database.BatchableContext bc) {

        try {
            // Handle the final parent record in the LDV job
            if (parentIdsNotCommittedWithBatch != null && !parentIdsNotCommittedWithBatch.isEmpty()) {
                completeRollupsForBatchIteration();
            }
        } catch (Exception ex) {
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP);
        }

        // Finally, pass control back to the chunking job that will re-call this job with the next set of parent Id's
        if (this.lastIdProcessedForChunking != null) {
            Database.executeBatch(new CRLP_SkewDispatcher_BATCH(this.jobType, this.jobFilter, this.lastIdProcessedForChunking),
                    CRLP_SkewDispatcher_BATCH.BATCH_SIZE);
        }

        // In debug mode, write a summary of the job to the error log
        if (CRLP_Debug_UTIL.isDebuggingEnabled) {
            String additionalInfo = 'Parent Ids Committed in Finish: ' +
                (this.parentIdsNotCommittedWithBatch !=  null
                    ? '(' + this.parentIdsNotCommittedWithBatch.size() + ')\n' + JSON.serializePretty(this.parentIdsNotCommittedWithBatch)
                    : 'none'
                );
            logDebugInfo(additionalInfo);
        }

        logJobResults(bc.getJobId());
    }

    /**
     * @description Build the Skew Mode Query string for the current job
     * @return SOQL
     */
    private String buildQueryLocatorAsSOQL() {
        // TODO Refactor this to use the CRLP_QueryBuilder class
        // Not including OppPayment as the child object because including the sub-query in an LDV org
        // may cause a cpu time out issue.
        String query = CRLP_Query_SEL.buildDetailObjectQueryForRollup(detailObjectType, new List<SObjectType>());

        npo02__Households_Settings__c householdSettings = UTIL_CustomSettingsFacade.getHouseholdsSettings();

        if (!CRLP_Rollup_SVC.hasActiveRollups(jobType)) {
            // If there are no active rollups for the object type, then force the query to return zero records.
            // This is needed because can't return null as a valid iterator.
            query += ' LIMIT 0';
            return query;
        }

        List<String> whereClauses = new List<String>();

        String keyFieldOverrideForQuery = CRLP_Rollup_SVC.getParentFieldNameForQuery(jobType);

        // Add necessary filters to limit the LDV batch job to only the records that should be processed as LDV
        if (this.recordIds != null && this.recordIds.size() > 0) {
            whereClauses.add(keyFieldOverrideForQuery + ' IN :recordIds');

        } else {
            // When querying detail rows and trying to filer on a field in the parent, need to get the
            // relationship name to use for that parent query.
            String parentRelationshipPrefix = CRLP_Rollup_SVC.getParentFieldNameForQuery(jobType).replace('__c', '__r') + '.';

            String skewClause = CRLP_RollupBatch_SVC.getSkewWhereClause(this.jobType,
                    CRLP_RollupProcessingOptions.BatchJobMode.SkewMode, parentRelationshipPrefix);

            if (!String.isEmpty(skewClause)) {
                whereClauses.add(skewClause);
            }
        }

        // Exclude Organization Donations (where Opp.Account.SYSTEM_IsIndividual=false) from Contact Hard Credit rollups
        // Depending on the npo02__Always_Rollup_to_Primary_Contact__c custom setting
        if (householdSettings.npo02__Always_Rollup_to_Primary_Contact__c == false
                && this.jobType == CRLP_RollupProcessingOptions.RollupType.ContactHardCredit) {
            whereClauses.add('Account.npe01__SYSTEMIsIndividual__c = True');

        } else if (householdSettings.npo02__Always_Rollup_to_Primary_Contact__c == false
                && CRLP_Rollup_SVC.isOppContactRoleSoftCreditRollup(this.jobType)
        ) {
            whereClauses.add('(IsPrimary = False OR Opportunity.Account.npe01__SYSTEMIsIndividual__c = False)');

        } else if (householdSettings.npo02__Always_Rollup_to_Primary_Contact__c == true
                && CRLP_Rollup_SVC.isOppContactRoleSoftCreditRollup(this.jobType)
        ) {
            whereClauses.add('IsPrimary = False');
        }

        // Identify a common filter that can be applied to the main query to reduce the number of records queried
        String addlFilter;
        if (detailObjectType == Opportunity.SObjectType) {
            addlFilter = CRLP_Query_SEL.buildCommonQueryFilterOnOpportunity(this.summaryObjectType, detailObjectType,
                    this.statefulCacheOfRollupsToBeProcessed);

        } else if (this.jobType == CRLP_RollupProcessingOptions.RollupType.ContactSoftCredit) {
            addlFilter = CRLP_Query_SEL.buildCommonQueryFilterOnOpportunity(Contact.SObjectType, Partial_Soft_Credit__c.SObjectType);

        } else if (this.jobType == CRLP_RollupProcessingOptions.RollupType.AccountContactSoftCredit) {
            addlFilter = CRLP_Query_SEL.buildCommonQueryFilterOnOpportunity(Account.SObjectType, Partial_Soft_Credit__c.SObjectType);

        } else if (this.jobType == CRLP_RollupProcessingOptions.RollupType.AccountSoftCredit) {
            addlFilter = CRLP_Query_SEL.buildCommonQueryFilterOnOpportunity(this.summaryObjectType, this.detailObjectType);
        }
        if (!String.isEmpty(addlFilter)) {
            whereClauses.add(addlFilter);
        }

        if (!whereClauses.isEmpty()) {
            query += ' WHERE ' + String.join(whereClauses, ' AND ');
        }

        query += ' ORDER BY ' + keyFieldOverrideForQuery + ', CreatedDate ASC';

        return query;
    }

    /**
     * @description There are cases where the main queryLocator did not filter out certain records to avoid
     * non-selectivity issues that would affect the query performance. In these cases, this method is hard-coded
     * to strip out any detail records from the queried data that will not be rolled up. Initially this only applies
     * to removing records with a null value in Opportunity__c from the Allocation__c object.
     * @param scope List<SObject> from query locator
     * @return updated List<SObject> with the same or less rows as 'scope'
     */
    private List<SObject> applyPostQueryLocatorFilters(List<SObject> scope) {

        if (this.jobType == CRLP_RollupProcessingOptions.RollupType.GAU) {
            // For the GAU object, strip out any detail records where the key field is NULL. This is better
            // handled here in the Execute() method than in the query to ensure proper SOQL selectivity.
            List<SObject> updatedDetailRecords = new List<SObject>();
            for (Integer n = 0, listSize = scope.size(); n < listSize; n++) {
                Allocation__c alloc = (Allocation__c) scope[n];
                if (alloc.Opportunity__c != null) {
                    updatedDetailRecords.add(alloc);
                }
            }
            return updatedDetailRecords;
        } else {
            return scope;
        }
    }

    /**
     * @description Retrieve a list of unique parent Id records from a set of detail records, taking into account
     * parent id records from previous batches that may be in the stateful collection of id's not yet committed.
     * @param objType
     * @param detailRecords
     * @param keyField
     * @return List of Unique Parent (Summary) record Id's
     */
    private List<Id> getUniqueParentIds(SObjectType objType, List<SObject> detailRecords, String keyField) {
        // Get all parent records to be processed by this batch iteration
        List<Id> parentIds = getParentIdsFromDetailRecords(detailRecords, keyField);
        if (!this.parentIdsNotCommittedWithBatch.isEmpty()) {
            Set<Id> uniqueParentIds = new Set<Id>(parentIds);
            // Don't add the last parent Id to the list UNLESS at least four batches have gone by. This is way of
            // handling Salesforce's out of sequence baches while avoiding too many commits for a single record
            for (Id lastId : this.parentIdsNotCommittedWithBatch.keySet()) {
                if (lastId.getSobjectType() == objType) {
                    if (this.batchIteration - this.parentIdsNotCommittedWithBatch.get(lastId) > MAX_BATCHES_TO_HOLD_BEFORE_COMMIT) {
                        if (!uniqueParentIds.contains(lastId)) {
                            parentIds.add(lastId);
                            uniqueParentIds.add(lastId);
                            this.parentIdsNotCommittedWithBatch.remove(lastId);
                        }
                    }
                }
            }
        }
        return parentIds;
    }

    /**
     * @description Retrieve a map of related Payments for each Detail record, but only if Payment Rollups are active
     * for the given rollup type
     * @param detailRecords
     * @return Map<Id, List<SObject>>
     */
    private Map<Id, List<SObject>> getRelatedPayments(List<SObject> detailRecords) {
        Map<Id, List<SObject>> paymentsByOpp = new Map<Id, List<SObject>>();

        // If the detail object is Opportunity AND there are payment rollups for the parent object
        // these need to be queried outside of the main batch job query due to a current known issue with
        // sub-queries on large objects.
        if (hasActivePaymentRollupsForThisJob() && !detailRecords.isEmpty() && detailObjectType == Opportunity.SObjectType) {

            // build a list of all the detail record Id's to use for retrieving the child payment records
            // for each Opportunity (detail).
            Set<Id> detailIds = new Map<Id,SObject>(detailRecords).keySet();

            String paymentsQuery = CRLP_Query_SEL.buildObjectQueryForRollup(npe01__OppPayment__c.SObjectType) +
                    ' WHERE npe01__Opportunity__c IN :detailIds ORDER BY npe01__Opportunity__c, CreatedDate ASC';

            for (npe01__OppPayment__c pmt : Database.query(paymentsQuery)) {
                if (!paymentsByOpp.containsKey(pmt.npe01__Opportunity__c)) {
                    paymentsByOpp.put(pmt.npe01__Opportunity__c, new List<npe01__OppPayment__c>());
                }
                paymentsByOpp.get(pmt.npe01__Opportunity__c).add(pmt);
            }
        }

        return paymentsByOpp;
    }

    /**
     * @description Resequence the Parent (Summary) records to be in the exact order of the detail records
     * using the defined parent Id
     * @param parentIds
     * @param summaryRecords
     * @return a list of Parent (Summary) SObject records in the proper order
     */
    private List<SObject> queryAndSequenceSummaryRecords(List<Id> parentIds, String soql) {
        // Resequence the Parent (Summary) records to be in the exact order of the detail records
        // using the defined parent Id
        List<SObject> reorderedSummaryRecords = new List<SObject>();
        Map<Id, SObject> mapOfSummaryRecords = new Map<Id, SObject>(Database.query(soql));
        for (Id parentId : parentIds) {
            reorderedSummaryRecords.add(mapOfSummaryRecords.get(parentId));
        }
        return reorderedSummaryRecords;
    }

    /**
     * @description Save Rollups collection and the last parent record id processed in stateful vars
     * @param processor
     * @param firstParentId
     * @param lastParentId
     */
    private void saveFirstAndLastParentIdData(CRLP_RollupProcessor processor, Id firstParentId, Id lastParentId) {
        Id lastParentIdProcessed = processor.getLastParentIdProcessed();

        if (processor.getRollupDefsForParent(firstParentId) != null) {
            updateStatefulCollections(processor, firstParentId);
        }
        if (lastParentId != firstParentId && processor.getRollupDefsForParent(lastParentId) != null) {
            updateStatefulCollections(processor, lastParentId);
        }
        if (lastParentIdProcessed != lastParentId && lastParentIdProcessed != null && processor.getRollupDefsForParent(lastParentIdProcessed) != null) {
            updateStatefulCollections(processor, lastParentIdProcessed);
        }

        // Remember which batch iteration this parent was last NOT updated
        if (processor.hasLastParentIdCompleted()) {
            this.parentIdsNotCommittedWithBatch.put(lastParentIdProcessed, this.batchIteration);
        }
    }

    /**
     * @description Update the stateful collection for statefulRollupsById and statefulMapOfOppIdsByParentId for the
     * specified record Ids.
     * @param processor
     * @param recordId
     */
    private void updateStatefulCollections(CRLP_RollupProcessor processor, Id recordId) {
        this.statefulRollupsById.put(recordId, processor.getRollupDefsForParent(recordId));

        if (CRLP_Rollup_SVC.isOppContactRoleSoftCreditRollup(this.jobType)) {
            this.statefulMapOfOppIdsByParentId.put(recordId, processor.getPreviouslyProcessedOppIds(recordId));
        }
    }

    /**
     * @description In skew mode, the lack of properly sequenced batches when ORDER BY is used requires the batch
     * job to hold the first and last summary record id data stateful until the end in case there are additional
     * detail records to be rolled up. This method is called in the finish() process to complete any pending rollups
     * for those parent records held stateful throughout the life of the batch job.
     */
    private void completeRollupsForBatchIteration() {
        // Get the Summary (target) records for the final record to be processed
        List<Id> parentIds = new List<Id>(parentIdsNotCommittedWithBatch.keySet());
        String query = CRLP_Query_SEL.buildObjectQueryForRollup(summaryObjectType) + ' WHERE Id IN :parentIds';
        List<SObject> parents = Database.query(query);

        CRLP_RollupProcessingOptions.ProcessingOptions options = new CRLP_RollupProcessingOptions.ProcessingOptions();
        options.useRollupDefsByParentIdMap = true;

        CRLP_RollupProcessor processor = new CRLP_RollupProcessor()
                .withRollupType(jobType)
                .withBatchJobMode(jobMode)
                .withDetailRecords(new List<SObject>())
                .withRelatedRecords(new Map<Id, List<SObject>>())
                .withPreviouslyProcessedOppIdsMap(statefulMapOfOppIdsByParentId)
                .withRollupDefinitions(statefulRollupsById)
                .withJobOptions(options);

        // Call the method to do the actual rollup on this last remaining record, which is basically
        // just to return the updated record
        List<SObject> updatedRecords = new List<SObject>();
        for (SObject parent : parents) {

            SObject updatedRecord = processor.withSummaryRecord(parent).completeRollupForSingleSummaryRecord(parent);
            if (updatedRecord != null) {
                updatedRecords.add(updatedRecord);
            }
        }

        // Handle dml on the records to be updated
        if (!updatedRecords.isEmpty()) {
            CRLP_RollupProcessor_SVC.updateChangedRecordsWithLogging(updatedRecords, jobType);
            totalRecordsModified += updatedRecords.size();
            totalCommits++;
        }
    }
}