public with sharing class UTIL_pkBanding {

    public String querySelect = getQuery();
    public String queryWhere;
    public pkBandingService.dispatcherResponse resp = new pkBandingService.dispatcherResponse();

    // should be interface
    public String getQuery() {
        return new UTIL_Query()
                .withFrom(npe03__Recurring_Donation__c.SObjectType)
                .withSelectFields(
                    new Set<String>{ 'Id' }
                )
                .build();
    }

    // should be interface
    public sObject[] getNextBatch(){
        SObject[] records = new List<SObject>();
        resp.completed = false;

        while (records.isEmpty() && !resp.completed){
            records = queryNextBatch();
            if (records.isEmpty()){
                getStartOfNextCluster();
            }
        }
        return records;
    }

    public SObject[] queryNextBatch(){
        if (resp.cursor.offset == null){
            resp.cursor.offset = getStartOfNextCluster();
            resp.cursor.offset = idAdd(resp.cursor.offset, -1);
        }
        if (getBand(resp.cursor.offset, resp.cursor.partitionBits) != resp.cursor.band){
            resp.cursor.offset = getStartOfNextChunkInBand(
                    resp.cursor.offset,
                    resp.cursor.band,
                    resp.cursor.partitionBits);
            resp.cursor.offset = idAdd(resp.cursor.offset, -1);
        }
        String startOffset = resp.cursor.offset;
        String endOfChunk = getNearestEndOfChunkInBand(
                resp.cursor.offset,
                resp.cursor.band,
                resp.cursor.partitionBits);
        Integer batchSize = resp.cursor.batchSize;

        String nextBatchQuery = querySelect +
                (String.isblank(queryWhere)?' ':' ' + queryWhere) +
                (String.isblank(queryWhere)?' WHERE ':' AND ') +
                ' Id > \'' + startOffset + '\' AND '+
                ' Id <= \'' + endOfChunk + '\'' +
                ' ORDER BY Id ASC LIMIT '+batchSize;

        System.debug('nextBatchQuery: ' + nextBatchQuery);

        SObject[] sObjectList = Database.query(nextBatchQuery);

        if (sObjectList.isEmpty()) {
            resp.cursor.sparse = true;
        }
        if (sObjectList.size()<batchSize) {
            resp.cursor.offset = endOfChunk;

        } else { //sObjectList.size()==batchSize
            resp.cursor.offset = sObjectList[sObjectList.size()-1].Id.to15();
        }
        return sObjectList;
    }


    public String getStartOfNextCluster(){
        String offset = resp.cursor.offset;
        String nextIdQuery = querySelect +
                (String.isblank(queryWhere)?' ':' ' + queryWhere) +
                (String.isblank(queryWhere)&&offset!=null?' WHERE ':'') +
                (!String.isblank(queryWhere)&&offset!=null?' AND ':'') +
                (offset!=null?' Id > :offset ':' ')  +
                ' ORDER BY Id ASC LIMIT 1';
        //System.assert(false, nextIdQuery);
        sObject[] firstIdList = Database.query(nextIdQuery);
        String minId;
        If (!firstIdList.isEmpty()) {
            minId = firstIdList[0].Id.to15();
            resp.cursor.offset = minId;
            resp.cursor.sparse = false;
        } else {
            resp.completed = true;
        }
        return minId;
    }


    public String getStartOfNextChunkInBand(String b62, Integer band, Integer bandBits) {
        //TO DO: What if band is not 3 bits?
        System.assert(bandBits == 3, 'Only 3-bit bands are currently suported');
        System.assert(b62.length()==15,'b62 number must be exactly 15 chars long');
        String IdPrefix = b62.left(6);
        String chunkPrefix = b62.mid(6,6);
        //TO DO: figure out if I need to add offset 1 or not based on actual band in key
        Integer nextBandOffset = getBand(b62, bandBits)>=band?1:0;
        //System.assert(false,'chunkprefix: '+chunkPrefix + 'nextBandOffset: '+ nextBandOffset);
        chunkPrefix = longToB62(b62toLong(chunkPrefix)+nextBandOffset,6);
        String bandStr = longToB62(band<<3,1);
        b62 = IdPrefix + chunkPrefix + bandStr + '00';
        return b62;
    }


    public String getNearestEndOfChunkInBand(String b62, Integer band, Integer bandBits) {
        //TO DO: What if band is not 3 bits?
        System.assert(bandBits == 3, 'Only 3-bit bands are currently suported');
        System.assert(b62.length()==15,'b62 number must be exactly 15 chars long');
        //b62 = getStartOfNextChunkInBand(b62, band, bandBits);
        String IdPrefix = b62.left(6);
        String chunkPrefix = b62.mid(6,6);
        Integer nextBandOffset = getBand(b62, bandBits)>band?1:0;
        chunkPrefix = longToB62(b62toLong(chunkPrefix)+nextBandOffset,6);
        //TO DO: Cannot add 7 to band 111b or it will overflow!!! Subtract 10b?
        Integer last3bits = band==7?5:7;
        String bandStr = longToB62((band<<3)+last3bits,1);
        b62 = IdPrefix + chunkPrefix + bandStr + 'zz';
        return b62;
    }


    public Integer getBand(String b62, Integer bandBits){
        System.assert(bandBits == 3, 'Only 3-bit bands are currently suported');
        System.assert(b62.length()==15,'b62 number must be exactly 15 chars long');
        Integer band;
        band = (Integer)b62toLong(b62.mid(12,1));
        band >>>=3;
        return band;
    }


    public String idAdd(String b62, Long addend){
        System.assert(b62.length()==15,'b62 number must be exactly 15 chars long');
        String IdPrefix = b62.left(6);
        String sequenceB62 = b62.mid(6,9);
        Long sequenceDec = b62toLong(sequenceB62);
        sequenceDec += addend;
        System.assert(sequenceDec>=0,'Negative Ids are not valid');
        sequenceB62 = longToB62(sequenceDec, 9);
        b62 = IdPrefix + sequenceB62;
        return b62;
    }


    public Long b62toLong(String b62){
        System.assert(b62.length()<=10,'b62 string is too long');
        String chars ='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'; //[0-9A-Za-z]
        Long sum=0;
        for (String i: b62.split('')){
            sum = sum*62;
            sum += chars.indexOf(i);
        }
        return sum;
    }


    public String longToB62(Long lng, Integer length) {
        System.assert(lng >= 0, 'Cannot convert negative number to base62');
        System.assert(length <= 10, 'Largest supported base62 length is 10');
        String chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'; //[0-9A-Za-z]
        String b62 = '';
        while (lng > 0) {
            Integer lchar = (Integer) Math.mod(lng, 62);
            b62 = chars.mid(lchar, 1) + b62;
            lng = lng / 62;
        }
        b62 = b62.leftPad(length, '0');
        System.assert(b62.length() <= length, 'b62 conversion OVERFLOW: ' + b62);
        return b62;
    }

}