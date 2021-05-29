/*
 * Copyright (c) 2020, Salesforce.org
 *     All rights reserved.
 *
 *     Redistribution and use in source and binary forms, with or without
 *     modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Salesforce.org nor the names of
 *       its contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 *
 *     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *     COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *     POSSIBILITY OF SUCH DAMAGE.
 */
@isTest
public with sharing class ElevateBatchServiceValidRequest extends ElevateBatchService {

    public override Gift addToElevateBatch(Gift tokenizedGift, String elevateBatchId) {
        ElevateAuthorizedGiftResponse giftResponse = addElevateBatchSuccessMessage();

        return new Gift(tokenizedGift, giftResponse);
    }

    public override ElevateBatch createElevateBatch() {
        ElevateBatchResponse elevateBatchResponse = createElevateBatchSuccessMessage();
        return new ElevateBatch(elevateBatchResponse);
    }

    public ElevateBatchResponse createElevateBatchSuccessMessage() {
        return (ElevateBatchResponse)JSON.deserialize('{\n' +
                '  "id": "test-id",\n' +
                '  "status": "Open"\n' +
                '}', ElevateBatchResponse.class);
    }

    public ElevateAuthorizedGiftResponse addElevateBatchSuccessMessage() {
        return (ElevateAuthorizedGiftResponse)JSON.deserialize(
                '{\n' +
                    '"id": "test-valid-id",\n' +
                    '"timestamp": "2021-03-03T17:43:28.589Z",\n' +
                    '"createdAt": "2021-03-03T17:43:28.589Z",\n' +
                    '"submittedAt": "2021-03-03T17:43:29.313Z",\n' +
                    '"authorizedAt": "2021-03-03T17:43:29.313Z",\n' +
                    '"authExpiresAt": "2021-03-06T17:43:29.313Z",\n' +
                    '"status": "AUTHORIZED",\n' +
                    '"merchantId": "f4338833-20f1-44b5-9270-6087659e0b9f",\n' +
                    '"merchantName": "TestPortal",\n' +
                    '"gatewayId": "106beaae-6d28-48b2-8c67-3cac2b636ee4",\n' +
                    '"gatewayTransactionId": "ch_1IQyjMLjHqxVjuiLnrG8C6Zx",\n' +
                    '"currencyCode": "USD",\n' +
                    '"amount": 500,\n' +
                    '"lastName": "Bond",\n' +
                    '"firstName": "James",\n' +
                    '"type": "PAYMENT",\n' +
                    '"paymentType": "CARD",\n' +
                    '"cardData": {\n' +
                    '    "last4": "1111",\n' +
                    '    "brand": "visa",\n' +
                    '    "expirationYear": "2025",\n' +
                    '    "expirationMonth": "05",\n' +
                    '    "firstName": "James",\n' +
                    '    "lastName": "Bond",\n' +
                    '    "fingerprint": "wU5VS1C0QNoMND4z"\n' +
                    '},\n' +
                    '"originalTransactionId": "c260c3eb-a8ae-47de-8f19-15e66c22098b",\n' +
                    '"batchId": "b0eec3f4-ab08-4207-857b-f2c6afc36d24",\n' +
                    '"receiptTimezone": "America/Los_Angeles",\n' +
                    '"amountRefunded": 0,\n' +
                    '"achData": {},\n' +
                    '"version": 2\n' +
                '}', ElevateAuthorizedGiftResponse.class);
    }

}