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
/**
* @author Salesforce.org
* @date 2020
* @group Utilities
* @description Contains tests for the common HttpRequest and HttpResponse methods
*/
@IsTest(IsParallel=true)
public with sharing class UTIL_Http_TEST {
    public static final String BAD_REQUEST_MESSAGE = 'Unauthorized endpoint, please check Setup->Security->Remote site settings.';
    public static final String MESSAGE_DATA_CONFLICT = 'Conflict';
    public static final String MESSAGE_NOT_FOUND = '404 /external/objects';

    /**
    * @description Verifies response is correctly formatted based on HttpResponse
    */
    @isTest
    private static void shouldPopulateResponseWhenHttpResponseIsReturned() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://test.com');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');
        request.setMethod('POST');

        String body = '{"value" : "success"}';

        Test.startTest();
        mockSuccessCalloutResponse(body);

        UTIL_Http.RequestService service = new UTIL_Http.RequestService();
        UTIL_Http.Response response = service.sendRequest(request);
        Test.stopTest();

        System.assertEquals(UTIL_Http.STATUS_CODE_OK, response.statusCode,
            'The response status code should be populated');
        System.assertEquals(UTIL_Http.STATUS_OK, response.status,
            'The response status should be populated');
        System.assertEquals(body, response.body,
            'The response body should be populated');
    }


    /**
    * @description Verifies the timed out exception is correctly handled in the error response
    */
    @isTest
    private static void shouldConstructTimedOutResponseWhenTimedOutExceptionIsGenerated() {
        String errorMessage = 'test callout timed out';
        System.CalloutException ex = new System.CalloutException(errorMessage);

        Test.startTest();
        UTIL_Http.RequestService service = new UTIL_Http.RequestService();
        UTIL_Http.Response response = service.buildErrorResponse(ex);
        Test.stopTest();

        System.assertEquals(UTIL_Http.STATUS_CODE_REQUEST_TIMEOUT, response.statusCode,
            'The status code should be set to timed out status code');
        System.assertEquals(UTIL_Http.STATUS_TIMED_OUT, response.status,
            'The status should be set to timed out status');

        UTIL_Http.ErrorResponseBody body = (UTIL_Http.ErrorResponseBody) JSON.deserialize(
            response.body, UTIL_Http.ErrorResponseBody.class
        );
        System.assertEquals(1, body.errors.size(), 'There should be one error in the response body');
        System.assertEquals(errorMessage, body.errors[0].message, 'The error message should match');
    }

    /**
    * @description Verifies the exception is correctly handled in the error response
    */
    @isTest
    private static void shouldConstructErrorResponseWhenExceptionIsGenerated() {
        String errorMessage = 'HttpRequest failed';
        System.DMLException ex = new System.DMLException(errorMessage);

        Test.startTest();
        UTIL_Http.RequestService service = new UTIL_Http.RequestService();
        UTIL_Http.Response response = service.buildErrorResponse(ex);
        Test.stopTest();

        System.assertEquals(UTIL_Http.STATUS_CODE_BAD_REQUEST, response.statusCode,
            'The status code should be set to bad request status code');
        System.assertEquals(System.Label.commonUnknownError, response.status,
            'The status should be set to unknown error');

        UTIL_Http.ErrorResponseBody body = (UTIL_Http.ErrorResponseBody) JSON.deserialize(
            response.body, UTIL_Http.ErrorResponseBody.class
        );
        System.assertEquals(1, body.errors.size(), 'There should be one error in the response body');
        System.assertEquals(errorMessage, body.errors[0].message, 'The error message should match');
    }

    /**
    * @description Verifies the error messages are empty when response is success
    */
    @isTest
    private static void shouldNotReturnErrorsWhenResponseIsSuccess() {
        String body = '{"value" : "success"}';

        Test.startTest();
        mockSuccessCalloutResponse(body);

        UTIL_Http.RequestService service = new UTIL_Http.RequestService();
        UTIL_Http.Response response = service.sendRequest(new HttpRequest());
        Test.stopTest();

        System.assertEquals('', response.getErrorMessages(),
            'The response should not return any error message');
    }

    /**
    * @description Verifies the error messages are returned from the error response
    */
    @isTest
    private static void shouldReturnErrorsWhenResponseIsBadRequest() {
        Test.startTest();
        mockBadRequestCalloutResponse();

        UTIL_Http.RequestService service = new UTIL_Http.RequestService();
        UTIL_Http.Response response = service.sendRequest(new HttpRequest());
        Test.stopTest();

        System.assertEquals(BAD_REQUEST_MESSAGE, response.getErrorMessages(),
            'The response should return expected error message');
    }


    /**
    * @description Callout Mock
    */
    public class CalloutMock implements HttpCalloutMock {
        Integer statusCode;
        String status;
        String body;

        /**
        * @description Constructor
        */
        public CalloutMock() {
            //set defaults
            statusCode = UTIL_Http.STATUS_CODE_OK;
            status = UTIL_Http.STATUS_OK;
        }

        /**
        * @description Set the response status code
        * @param statusCode The status code of the returned mock response
        * @return CalloutMock
        */
        public CalloutMock withStatusCode(Integer statusCode) {
            this.statusCode = statusCode;
            return this;
        }

        /**
        * @description Set the response status code
        * @param status The status of the returned mock response
        * @return CalloutMock
        */
        public CalloutMock withStatus(String status) {
            this.status = status;
            return this;
        }

        /**
        * @description Set the response body
        * @param body The body JSON of the returned mock response
        * @return CalloutMock
        */
        public CalloutMock withBody(String body) {
            this.body = body;
            return this;
        }

        /**
        * @description HttpCalloutMock Interface method to return the response
        * @param request The request that is sent
        * @return HttpResponse
        */
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(statusCode);
            response.setStatus(status);

            if (body != null) {
                response.setBody(body);
            }

            return response;
        }
    }

    // Helpers
    /////////////////

    /**
     * @description Simulates a success callout response
     * @return void
     */
    public static void mockSuccessCalloutResponse(String responseBody) {
        CalloutMock callout = new CalloutMock()
            .withBody(responseBody);

        Test.setMock(HttpCalloutMock.class, callout);
    }

    /****
    * @description Simulates a successful record created callout response
    * @return String
    */
    public static void mockRecordCreatedCalloutResponse(String responseBody) {
        CalloutMock callout = new CalloutMock()
            .withStatusCode(UTIL_Http.STATUS_CODE_CREATED)
            .withStatus(UTIL_Http.STATUS_OK)
            .withBody(responseBody);

        Test.setMock(HttpCalloutMock.class, callout);
    }

    public static void mockRecordUpdateCalloutResponse(String responseBody) {
        CalloutMock callout = new CalloutMock()
            .withStatusCode(UTIL_Http.STATUS_CODE_OK)
            .withStatus(UTIL_Http.STATUS_OK)
            .withBody(responseBody);

        Test.setMock(HttpCalloutMock.class, callout);
    }

    /**
     * @description Stubs a "bad request" callout response
     * @return void
     */
    public static void mockBadRequestCalloutResponse() {
        String responseBody = '{"errors":[{'
            + '"message":"' + BAD_REQUEST_MESSAGE + '"'
            + '}]}';

        mockErrorCalloutResponse(UTIL_Http.STATUS_CODE_BAD_REQUEST, System.Label.commonUnknownError, responseBody);
    }

    /**
     * @description Stubs a "not found" callout response
     * @return void
     */
    public static void mockNotFoundCalloutResponse() {
        String responseBody = '{"errors":[{'
            + '"message":"' + MESSAGE_NOT_FOUND
            + '","localizedPaymentsMessage":"' + MESSAGE_NOT_FOUND
            + '"}]}';

        mockErrorCalloutResponse(UTIL_Http.STATUS_CODE_NOT_FOUND, UTIL_Http.STATUS_NOT_FOUND, responseBody);
    }

    /**
     * @description Stubs a "not found" callout response
     * @return void
     */
    public static void mockDataConflictCalloutResponse() {
        String responseBody = '{"errors":[{'
            + '"message":"' + MESSAGE_DATA_CONFLICT
            + '","localizedPaymentsMessage":"' + MESSAGE_DATA_CONFLICT
            + '","detailedMessage":"' + MESSAGE_DATA_CONFLICT
            + '"}]}';

        mockErrorCalloutResponse(UTIL_Http.STATUS_CODE_CONFLICT, UTIL_Http.STATUS_CONFLICT, responseBody);
    }

    /**
     * @description Simulates an error callout response
     * @return void
     */
    public static void mockErrorCalloutResponse(Integer statusCode, String status, String responseBody) {
        CalloutMock callout = new CalloutMock()
            .withStatusCode(statusCode)
            .withStatus(status)
            .withBody(responseBody);

        Test.setMock(HttpCalloutMock.class, callout);
    }

}
