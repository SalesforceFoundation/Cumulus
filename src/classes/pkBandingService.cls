@RestResource(urlMapping='/pkbanding')
global with sharing class pkBandingService {

    // consts
    public static final String ERR_CLASS_NAME = 'pkBandingService:';
    public static final Integer HTTP_SUCCESS = 200;
    public static final Integer HTTP_FORBIDDEN = 403;

    @HttpPost
    global static void pkbanding() {

        // set default response
        RestResponse response = RestContext.response;
        response.statusCode = HTTP_SUCCESS;

        // aux vars
        Cursor request;
        dispatcherResponse dResponse = new dispatcherResponse();
        SObject[] events;

        // class vars        
        Integer failedCount = 0;
        Map<Id,String> failedIdsMap = new Map<Id,String>();
        Set<Id> failedIds = new Set<Id>();
        
        // aux vars
        Integer band;                
        Integer eventLimit;
        String lastOffset;   
        
        // rd2 evaluation service instance
        RD2_OpportunityEvaluationService evalService;

        try {

            // deserialize payload
            request = (Cursor) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                Cursor.class
            );   
                                    
            // cursor logic
            if (request!=null && request.isCursor) {
                
                // init aux vars                
                band = request.band;
                eventLimit = request.batchSize;
                lastOffset = request.offset;

                // init response
                dResponse.init(request);

                // init pk banding service
                UTIL_pkBanding pkb = new UTIL_pkBanding();
                // set resp obj
                pkb.resp = dResponse;
                // get next batch
                events = pkb.getNextBatch();
                // get resp obj from service
                dResponse = pkb.resp;
                dResponse.numberProcessed = events.size();

                // process RDs if result == true
                if (dResponse.numberProcessed>0 && dResponse.result) {
                
                    // disable rollups
                    TDTM_Config_API.disableAllRollupTriggers();
                    // execute RD service
                    evalService = new RD2_OpportunityEvaluationService().withBatchContext()
                                                                        .withRds(UTIL_SObject.extractIds(events))
                                                                        .withCurrentDate(Date.Today())
                                                                        .evaluateOpportunities();

                    // capture after execution results
                    failedCount = evalService.getRecordsFailed();
                    failedIds = evalService.getRecordsFailedId();
                    failedIdsMap = evalService.getRecordsFailedMap();

                } 

            // re-try logic 
            } else if (request!=null && !request.isCursor && request.recordIds!=null && request.recordIds.size()>0 ) {

                // aux var
                Set<Id> auxIds = new Set<Id>();
                Set<Id> rdIds = new Set<Id>();
                                
                // init response
                dResponse.init(request);
                dResponse.cursor.isCursor = false;
                dResponse.result = true;
                dResponse.completed = request.batchSize >= request.recordIds.size();

                // if not completed, build set(recordIds) for next execution
                if (!dResponse.completed) {

                    // get array values to proccess in next batch
                    List<Id> listIds = new List<Id> (request.recordIds);
                    for (Integer i=request.batchSize; i<request.recordIds.size(); i++) {
                        auxIds.add(listIds[i]);
                    }
                    // remove them from the records to be processed in this execution
                    request.recordIds.removeAll(auxIds);
                    // HAD-TO use aux SET<ID> because of bug after using removeAll()
                    rdIds = request.recordIds;
                    // add to cursor to process later
                    dResponse.cursor.recordIds = auxIds;

                } else {
                    // HAD-TO use aux SET<ID> because of bug after using removeAll()
                    rdIds = request.recordIds;
                }
                // set num processed
                dResponse.numberProcessed = rdIds.size();

                // disable rollups
                TDTM_Config_API.disableAllRollupTriggers();
                // execute RD service
                evalService = new RD2_OpportunityEvaluationService().withBatchContext()
                                                                    .withRds(rdIds)
                                                                    .withCurrentDate(Date.Today())
                                                                    .evaluateOpportunities();
                // capture after execution results
                failedCount = evalService.getRecordsFailed();
                failedIds = evalService.getRecordsFailedId();
                failedIdsMap = evalService.getRecordsFailedMap();

            }


        } catch (Exception e) {
            System.debug('EXCEPTION: ' + e.getMessage());
            // update response object with error details
            dResponse.cursor.offset = lastOffset;
            dResponse.numberProcessed = 0;
            dResponse.numberErrors = failedCount;
            dResponse.failedRecords = failedIdsMap;
            dResponse.failedRecordsIds = failedIds;
            dResponse.result = false;
            dResponse.error =  ERR_CLASS_NAME + e.getMessage();
            response.responseBody = Blob.valueOf(JSON.serialize(dResponse));
            return;
        }

        // service response
        dResponse.numberErrors = failedCount;
        dResponse.failedRecords = failedIdsMap;
        dResponse.failedRecordsIds = failedIds;
        response.responseBody = Blob.valueOf(JSON.serialize(dResponse));
    }

    public class dispatcherResponse {
        public Boolean result;
        public String error;
        public Integer numberProcessed;
        public Integer numberErrors;
        public Map<Id,String> failedRecords;
        public Set<Id> failedRecordsIds;
        public Boolean completed; // consumed all records in band
        public Cursor cursor = new Cursor();       

        public void init(Cursor request) {
            cursor = request;
            result = true;
            completed = false;
            numberProcessed = 0;
            error = '';
            failedRecords = new Map<Id,String>();
            failedRecordsIds = new Set<Id>();
        }
    }

    public class Cursor {
        public Integer band; // same as shard/subshard in TL
        public Integer partitionBits; // Not yet used (currently 3 bits - 8 bands)
        public Integer chunkBits; // Not yet used (currently ~14.90839 bits - 30752 recs/chunk)
        public Integer batchSize; // Max number of records to pull
        public Boolean sparse; // Will be true if last chunk in band was empty
        public String offset; // Last Id queried (not necessarily processed)
        public String url;
        public String session;
        public Set<Id> recordIds;
        public Boolean isCursor;
    }

}