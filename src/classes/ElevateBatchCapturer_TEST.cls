/*
    Copyright (c) 2020, Salesforce.org
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

@IsTest
private class ElevateBatchCapturer_TEST {

    @IsTest static void shouldHaveGroupsToCaptureInElevateBatches() {
        ElevateBatchCapturer capturer = new ElevateBatchCapturer(
                UTIL_UnitTestData_TEST.mockId(DataImportBatch__c.getSObjectType()),
                buildElevateBatchIds(200));
        System.assert(capturer.queueableElevateBatches.hasGroupsToCapture());
        System.assertEquals(4, capturer.queueableElevateBatches.partitionSize());
        System.assertEquals(50, capturer.queueableElevateBatches.idsToCapture().size());
    }

    @IsTest static void shouldCaptureEnqueuedElevateBatches() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        ElevateBatchCapturer capturer = new ElevateBatchCapturer(
                UTIL_UnitTestData_TEST.mockId(DataImportBatch__c.getSObjectType()),
                buildElevateBatchIds(200));
        Test.startTest();
        String validResponse = '{"id": "test-valid-group-id","status": "Processing"}';
        UTIL_Http_TEST.mockSuccessCalloutResponse(validResponse);
        capturer.execute(null);
        Test.stopTest();
        System.assert(capturer.failReasonByElevateBatchId.isEmpty());
    }

    @IsTest static void shouldPopulateFailReasonMapForFailedCaptures() {
        PS_IntegrationService.setConfiguration(PS_IntegrationServiceConfig_TEST.testConfig);
        ElevateBatchCapturer capturer = new ElevateBatchCapturer(
                UTIL_UnitTestData_TEST.mockId(DataImportBatch__c.getSObjectType()),
                buildElevateBatchIds(50));
        GiftBatchServiceMock giftBatchServiceMock = new GiftBatchServiceMock();
        capturer.giftBatchService = stubFor(giftBatchServiceMock);

        Test.startTest();
        String invalidResponse = '{"errors":[{"message":"id: Must be a valid UUID","localizedPaymentsMessage":"Bad Request","detailedMessage":"id: Must be a valid UUID"}]}';
        UTIL_Http_TEST.mockSuccessCalloutResponse(invalidResponse);
        capturer.execute(null);
        Test.stopTest();

        System.assert(giftBatchServiceMock.giftsFailedCaptureForCalled);
        System.assertEquals(50, capturer.failReasonByElevateBatchId.size());
        System.assertEquals(capturer.failReasonByElevateBatchId.values()[0], 'id: Must be a valid UUID');
    }

    static Set<String> buildElevateBatchIds(Integer numOfElevateBatchIds) {
        Set<String> elevateBatchIds = new Set<String>();
        for (Integer i=0; i < numOfElevateBatchIds; i++) {
            elevateBatchIds.add('sjdj-12334-fhdh-0'+ i);
        }
        return elevateBatchIds;
    }

    public class GiftBatchServiceMock implements StubProvider {
        public Boolean giftsFailedCaptureForCalled = false;

        public Object handleMethodCall(Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs) {

            switch on (stubbedMethodName) {
                when 'giftsFailedCaptureFor' {
                    giftsFailedCaptureForCalled = true;
                }
            }

            return null;
        }
    }

    private static GiftBatchService stubFor(GiftBatchServiceMock giftBatchServiceMock) {
        return (GiftBatchService) Test.createStub(
            GiftBatchService.class,
            giftBatchServiceMock
        );
    }
}