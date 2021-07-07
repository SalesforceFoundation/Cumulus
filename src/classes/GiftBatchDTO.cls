public inherited sharing class GiftBatchDTO {

    private IGiftBatch giftBatch;

    public GiftBatchDTO(IGiftBatch giftBatch) {
       this.giftBatch = giftBatch;
    }

    public Money total() {
        return giftBatch.total();
    }

    public Integer totalCount() {
        return giftBatch.totalCount();
    }
}