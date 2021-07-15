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
* @group Batch Job
* @description Batch job service
*/
public without sharing class UTIL_BatchJobService {
    /***
    * @description A batch job custom exception
    */
    public class BatchException extends Exception {}

    /***
    * @description An error message thrown when batch job is undefined.
    */
    @TestVisible
    private static final String BATCH_JOB_REQUIRED = 'Batch job is required';
    /***
    * @description Value used to query Apex batch jobs
    */
    private static final String JOB_TYPE_BATCH = 'BatchApex';

    /***
    * @description Contains max number of batch completed days to report.
    * The actual number of days passes is not relevant for any display after this point.
    */
    @TestVisible
    private static final Integer MAX_DAYS_EXCEEDED = 365;

    /***
    * @description AsyncApexJob possible status values
    */
    public enum ApexJobStatus {
        HOLDING, QUEUED, PREPARING, PROCESSING, COMPLETED, FAILED, ABORTED
    }

    /***
    * @description AsyncApexJob possible status values indicating the batch job is in progress
    */
    public static final Set<String> IN_PROGRESS_STATUSES = new Set<String>{
        ApexJobStatus.HOLDING.name(),
        ApexJobStatus.QUEUED.name(),
        ApexJobStatus.PREPARING.name(),
        ApexJobStatus.PROCESSING.name()
    };

    /***
    * @description Determines if the batch job is in progress
    * @param batchId Batch Id
    * @return Boolean
    */
    public Boolean isInProgress(Id batchId) {
        if (batchId == null) {
            return false;
        }

        return (Database.countQuery('SELECT Count() FROM AsyncApexJob WHERE Id = :batchId AND Status IN :IN_PROGRESS_STATUSES') > 0);
    }

    /***
    * @description Determines if the batch job is in progress
    * @param status Batch job status
    * @return Boolean
    */
    public Boolean isInProgress(String status) {
        return IN_PROGRESS_STATUSES.contains(status.toUpperCase());
    }

    /***
    * @description Determines if we have at least one *other* batch job running.
    * The method is called from a batch job, so in this context, we exclude the batch itself.
    * @param className Batch class name
    * @return Boolean
    */
    public Boolean isConcurrentBatch(String className) {
        return getAsyncApexJobInProgress(className).size() > 1;
    }

    /***
    * @description Determines if any batch job with the same class name is running
    * @param className Batch class name
    * @return Boolean
    */
    public Boolean isBatchInProgress(String className) {
        return getAsyncApexJobInProgress(className).size() > 0;
    }

    /***
    * @description Logs an error when another same batch is running
    * @param className Apex batch class name
    * @param context Error context
    * @return void
    */
    public void logConcurrentBatchError(String className, ERR_Handler_API.Context context) {
        BatchException ex = new BatchException();
        ex.setMessage(getConcurrentBatchMessage(className));

        ERR_Handler.processError(ex, context);
    }

    /***
    * @description Builds concurrent batch error message
    * @param className Apex batch class name
    * @return String
    */
    public String getConcurrentBatchMessage(String className) {
        return String.format(
            System.Label.commonConcurrentBatchError,
            new List<String>{ className }
        );
    }

    /***
    * @description Determines number of days passed since the batch job has completed
    * @param className Batch job class name
    * @return Integer
    */
    public Integer getCompletedDaysBetween(String className) {
        AsyncApexJob batchJob = getAsyncApexJob(className);

        if (batchJob == null) {
            return 0;
        }

        return getCompletedDaysBetween(batchJob.CompletedDate, batchJob.Status);
    }

    /***
    * @description Determines number of days passed since the batch job has completed
    * @param completedDate Batch completed date and time
    * @param status Batch status
    * @return Integer
    */
    public Integer getCompletedDaysBetween(Datetime completedDate, String status) {
        if (completedDate == null || isInProgress(status)) {
            return 0;
        }

        Long milliseconds = Datetime.now().getTime() - completedDate.getTime();
        Long days = milliseconds /1000 /60 /60 /24;

        return days > MAX_DAYS_EXCEEDED ? MAX_DAYS_EXCEEDED : Integer.valueOf(days);
    }

    /***
    * @description Returns the list of batches that are in progress at this moment.
    * @param className Apex class name
    * @return List<AsuncApexJob>
    */
    public List<AsyncApexJob> getAsyncApexJobInProgress(String className) {
        String namespacePrefix = UTIL_Namespace.getNamespace();

        //Remove the namespace from the class name
        className = UTIL_Namespace.removeClassNamespace(className);

        List<AsyncApexJob> apexJobs = [
            SELECT
                Status, ApexClass.Name,
                ExtendedStatus, NumberOfErrors,
                TotalJobItems, JobItemsProcessed,
                CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE JobType = :JOB_TYPE_BATCH
                AND ApexClass.Name = :className
                AND ApexClass.NamespacePrefix = :namespacePrefix
                AND Status IN :IN_PROGRESS_STATUSES
            ORDER BY CreatedDate DESC
        ];

        return apexJobs;
    }

    /***
    * @description Returns the latest batch job for the specified job Id
    * @param jobId Batch job Id
    * @return AsyncApexJob
    */
    public AsyncApexJob getAsyncApexJob(Id jobId) {
        List<AsyncApexJob> apexJobs = [
            SELECT
                Status, ApexClass.Name,
                ExtendedStatus, NumberOfErrors,
                TotalJobItems, JobItemsProcessed,
                CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        return apexJobs.isEmpty() ? null : apexJobs[0];
    }

    /***
    * @description Returns the latest batch job for the specified batch class name
    * @param className Batch class name
    * @return AsyncApexJob
    */
    public AsyncApexJob getAsyncApexJob(String className) {
        String namespacePrefix = UTIL_Namespace.getNamespace();

        //Remove the namespace from the class name
        className = UTIL_Namespace.removeClassNamespace(className);

        List<AsyncApexJob> apexJobs = [
            SELECT
                Status, ApexClass.Name,
                ExtendedStatus, NumberOfErrors,
                TotalJobItems, JobItemsProcessed,
                CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE JobType = :JOB_TYPE_BATCH
                AND ApexClass.Name = :className
                AND ApexClass.NamespacePrefix = :namespacePrefix
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return apexJobs.isEmpty() ? null : apexJobs[0];
    }

    /***
    * @description Loads the latest batch job for the specified batch class name
    * @param className Batch class name
    * @return BatchJob
    */
    public BatchJob getBatchJob(String className) {
        AsyncApexJob batchJob = getAsyncApexJob(className);

        return batchJob == null ? null : new BatchJob(batchJob);
    }

    /***
    * @description Batch job descriptor
    */
    public class BatchJob {

        public Id batchId;
        public String status;
        public String extendedStatus;
        public Integer jobItemsProcessed;
        public Integer totalJobItems;
        public Integer numberOfErrors;

        public DateTime createdDate;
        public DateTime completedDate;

        public String timeElapsed;
        public Long percentComplete = 0;
        public Integer completedDaysBetween = 0;
        public Boolean isInProgress = false;
        public JobSummary summary;

        /***
        * @description Constructor
        * @param job AsyncApexJob record
        */
        public BatchJob(AsyncApexJob job) {
            if (job == null) {
                throw new BatchException(BATCH_JOB_REQUIRED);
            }

            batchId = job.Id;
            status = job.Status;
            extendedStatus = job.ExtendedStatus;
            jobItemsProcessed = job.JobItemsProcessed;
            totalJobItems = job.TotalJobItems;
            numberOfErrors = job.NumberOfErrors;

            createdDate = job.CreatedDate;
            completedDate = job.CompletedDate;

            isInProgress = isInProgress(status);
            summary = getSummary(batchId, job.ApexClass.Name);

            timeElapsed = calcTimeElapsed(createdDate, completedDate);
            percentComplete = calcPercentComplete(jobItemsProcessed, totalJobItems, status);
            completedDaysBetween = getCompletedDaysBetween();
        }

        /***
        * @description Loads the batch job summary
        * @param batchId Batch job Id
        * @param className Batch job class name
        * @return JobSummary
        */
        @TestVisible
        private JobSummary getSummary(Id batchId, String className) {
            if (isInProgress) {
                return null; //the summary is available for the completed batch only
            }

            JobSummary summary;
            switch on className {
                when 'RD2_DataMigration_BATCH', 'RD2_DataMigrationDryRun_BATCH' {
                    summary = new RD2_DataMigrationEnablement.BatchJob().getSummary(batchId, className);
                }
            }
            if (summary != null && numberOfErrors == 0 && summary.failed > 0) {
                numberOfErrors = summary.failed;
            }

            return summary;
        }

        /***
        * @description Calculates time elapsed since the batch job has started.
        *
        * @param startDate Batch Start Date
        * @param endDate When completed, the endDate is completion date;
        * otherwise, the endDate is the current datetime.
        * @return String Time elapsed
        */
        @TestVisible
        private String calcTimeElapsed(DateTime startDate, DateTime endDate) {
            endDate = endDate == null ? Datetime.now() : endDate;

            Long milliseconds = endDate.getTime() - startDate.getTime();
            Long days = milliseconds / 1000 /60 /60 /24;

            DateTime diffDate = DateTime.newInstance(milliseconds);

            return (days > 0 ? String.valueOf(days) + ' ' + System.Label.BatchProgressTimeElapsedDays + ' ' : '') +
                String.format(
                    '{0}:{1}:{2}',
                    new String[] { formatTime(diffDate.hourGmt()), formatTime(diffDate.minuteGmt()), formatTime(diffDate.secondGmt()) }
                );
        }

        /***
        * @description Formats hours, minutes and seconds of the time
        * @param value Time
        * @return String Formatted time
        */
        private String formatTime(Long value) {
            return String.valueOf(value).leftPad(2, '0').right(2);
        }

        /***
        * @description Calculates the percentage of the batch job completion
        * @param jobItemsProcessed Processed batch iterations
        * @param totalJobItems Total batch iterations
        * @param status Batch job status
        * @return Long Percentage completed
        */
        @TestVisible
        private Long calcPercentComplete(Integer jobItemsProcessed, Integer totalJobItems, String status) {
            final Integer defaultPercentComplete = 5;

            Long percentComplete = defaultPercentComplete;

            if (ApexJobStatus.COMPLETED.name() == status) {
                percentComplete = 100;

            } else if (ApexJobStatus.QUEUED.name() == status || ApexJobStatus.HOLDING.name() == status) {
                percentComplete = defaultPercentComplete;

            } else if (ApexJobStatus.PREPARING.name() == status) {
                percentComplete = 10;

            } else if (ApexJobStatus.FAILED.name() == status) {
                percentComplete = 0;

            } else if (0 == totalJobItems) {
                percentComplete = defaultPercentComplete;

            } else {
                percentComplete = Math.max(
                    Math.roundToLong(100 * jobItemsProcessed / totalJobItems),
                    defaultPercentComplete
                );
            }

            return percentComplete;
        }

        /***
        * @description Determines number of days passed since the batch job has completed
        * @return Integer
        */
        private Integer getCompletedDaysBetween() {
            return new UTIL_BatchJobService().getCompletedDaysBetween(completedDate, status);
        }

        /***
        * @description Determines if the batch job is in progress
        * @param status Batch job status
        * @return Boolean
        */
        @TestVisible
        private Boolean isInProgress(String status) {
            return IN_PROGRESS_STATUSES.contains(status.toUpperCase());
        }
    }

    /***
    * @description Represents batch job summary
    */
    public class JobSummary {
        public Id batchId;
        public Integer total = 0;
        public Integer processed = 0;
        public Integer failed = 0;

        /**
        * @description Contructor
        * @param batchId Batch job Id
        */
        public JobSummary(Id batchId) {
            this.batchId = batchId;
        }

        /**
        * @description Sets number of records selected
        * @param total Number of records selected
        * @return JobSummary
        */
        public JobSummary withTotalRecords(Integer total) {
            this.total = total;
            return this;
        }

        /**
        * @description Sets number of records processed
        * @param processed Number of records processed
        * @return JobSummary
        */
        public JobSummary withTotalRecordsProcessed(Integer processed) {
            this.processed = processed;
            return this;
        }

        /**
        * @description Sets number of records failed
        * @param failed Number of records failed
        * @return JobSummary
        */
        public JobSummary withTotalRecordsFailed(Integer failed) {
            this.failed = failed;
            return this;
        }
    }

    /**
     * @description Log Batch Job Results - FOR PERFORMANCE TESTING
     */
    public static void logJobResult(Id jobId, String batchName, Integer processedCount, Integer modifiedCount, Integer dmlCount, Integer apexDmlRows) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('BatchResultLog__c')) {
            return;
        }

        UTIL_BatchJobService jobService = new UTIL_BatchJobService();
        UTIL_BatchJobService.BatchJob job = new UTIL_BatchJobService.BatchJob(jobService.getAsyncApexJob(jobId));

        SObject log = globalDescribe.get('BatchResultLog__c').newSObject();
        log.put('Name', batchName);
        log.put('BatchJobId__c', jobId);
        log.put('StartDate__c', job.createdDate);
        log.put('EndDate__c', job.completedDate);
        log.put('Duration__c', job.timeElapsed);
        log.put('RecordsProcessedCount__c', processedCount);
        log.put('RecordsModifiedCount__c', modifiedCount);
        log.put('DMLOperationCount__c', dmlCount);
        log.put('DMLRows__c', apexDmlRows);
        log.put('ChildBatchCount__c', job.jobItemsProcessed);
        insert log;
    }
}