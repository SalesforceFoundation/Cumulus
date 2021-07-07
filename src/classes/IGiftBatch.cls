public interface IGiftBatch {

    /**
     * @return Sum of all Gifts in the GiftBatch.
     */
    Money total();

    /**
     * @return Count of all Gifts in the GiftBatch.
     */
    Integer totalCount();

}