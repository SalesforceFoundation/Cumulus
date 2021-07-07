@IsTest
private class GiftBatchView_TEST {

    @IsTest
    static void sample_gift_batch_view() {
        Gifts gifts = dummyGifts();
        GiftBatch giftBatch = new GiftBatch(gifts);
        GiftBatchView giftBatchView =
                new GiftBatchView(new GiftBatchDTO(giftBatch));
        System.debug(LoggingLevel.ERROR, '*** variable value: ' +
                JSON.serializePretty(giftBatchView));
        System.debug(LoggingLevel.ERROR, '^^^^^^ giftBatchView ^^^^^^');
    }

    @IsTest
    static void total_amount_correct_for_gift_batch_with_total_of_200() {
        GiftBatchOf2WithTotalOf200 giftBatch200 = new GiftBatchOf2WithTotalOf200();
        IGiftBatch giftBatchMock =
                (IGiftBatch) Test.createStub(IGiftBatch.class, giftBatch200);

        System.debug(LoggingLevel.ERROR, '*** variable value: ' +
                JSON.serializePretty(giftBatch200));
        System.debug(LoggingLevel.ERROR, '^^^^^^ JSON.serializePretty(giftBatch) ^^^^^^');
        GiftBatchView giftBatchView =
                new GiftBatchView(new GiftBatchDTO(giftBatchMock));
        System.debug(LoggingLevel.ERROR, '*** variable value: ' +
                JSON.serializePretty(giftBatchView));
        System.debug(LoggingLevel.ERROR, '^^^^^^ giftBatchView ^^^^^^');
        System.assertEquals(200, giftBatchView.total.amount());
    }

    @IsTest
    static void total_count_correct_for_gift_batch_with_total_count_of_2() {
        GiftBatchOf2WithTotalOf200 giftBatch200 = new GiftBatchOf2WithTotalOf200();
        IGiftBatch giftBatchMock =
                (IGiftBatch) Test.createStub(IGiftBatch.class, giftBatch200);

        System.debug(LoggingLevel.ERROR, '*** variable value: ' +
                JSON.serializePretty(giftBatch200));
        System.debug(LoggingLevel.ERROR, '^^^^^^ JSON.serializePretty(giftBatch) ^^^^^^');
        GiftBatchView giftBatchView =
                new GiftBatchView(new GiftBatchDTO(giftBatchMock));
        System.debug(LoggingLevel.ERROR, '*** variable value: ' +
                JSON.serializePretty(giftBatchView));
        System.debug(LoggingLevel.ERROR, '^^^^^^ giftBatchView ^^^^^^');
        System.assertEquals(2, giftBatchView.totalCount);
    }

    private static Gifts dummyGifts() {
        return new Gifts(
                new List<DataImport__c>{
                        new DataImport__c(
                                Donation_Amount__c = 100,
                                Donation_Date__c = Date.today()
                        ),
                        new DataImport__c(
                                Donation_Amount__c = 100,
                                Donation_Date__c = Date.today()
                        )
                }
        );
    }

    public class GiftBatchOf2WithTotalOf200 implements StubProvider {
        public Object handleMethodCall(Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs) {
            switch on (stubbedMethodName) {
                when 'total' {
                    return new Money(200, 'US');
                }
                when 'totalCount' {
                    return 2;
                }
            }
            return null;
        }
    }
}