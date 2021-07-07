public inherited sharing class GiftBatchView {

    @AuraEnabled public Money total;
    @AuraEnabled public Integer totalCount;

    public GiftBatchView(GiftBatchDTO giftBatchDTO) {
        total = giftBatchDTO.total();
        totalCount = giftBatchDTO.totalCount();
    }
}