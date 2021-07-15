/*
    Copyright (c) 2021, Salesforce.org
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
* @date 2021
* @description test class for Error Handling API
* @group ErrorHandling
*/
@IsTest(IsParallel=true)
private class ERR_Handler_API_TEST {

    private static final String ERR_CONTEXT = 'ERR_Handler_API_TEST';
    private static final TEST_SObjectGateway.ErrorGateway errorGateway = new TEST_SObjectGateway.ErrorGateway();

    @TestSetup
    static void setupInitialAccount() {
        Account account = UTIL_UnitTestData_TEST.createMultipleTestAccounts(1, null)[0];
        insert account;
    }

    /**
     * @description When a DML error occurs, verify an Error__c record is created and the error is displayed on a page
     */
    @IsTest
    private static void shouldCreateErrorFromDMLAndDisplayOnPage() {

        Test.setCurrentPage(Page.STG_SettingsManager);

        // set test account name to null to trigger update error (Required fields are missing: [Name])
        Account acct = [SELECT Id, Name FROM Account LIMIT 1];
        acct.Name = null;
        List<Account> accounts = new List<Account>{acct};

        Test.startTest();
        List<Database.SaveResult> saveResults = Database.update(accounts, false);
        ERR_Handler_API.processDMLErrors(saveResults, accounts, ERR_CONTEXT, true);
        Test.stopTest();

        // query Error__c record result for asserts
        List<Error__c> errors = errorGateway.getRecords();

        // assert error is created
        System.assertEquals(1, errors.size(), 'There should be only a single Error record created');
        // assert error fields match
        System.assertEquals(acct.Id, errors[0].Related_Record_ID__c);
        System.assertEquals(ERR_CONTEXT, errors[0].Context_Type__c);
        // assert page error is displayed
        UTIL_UnitTestData_TEST.assertPageHasError(errors[0].Full_Message__c);

    }

    /**
    * @description When a DML error occurs, verify DML error is created but do not displayed error on a page
    */
    @IsTest
    private static void shouldCreateErrorFromDMLButDoNotDisplayOnPage() {

        Test.setCurrentPage(Page.STG_SettingsManager);

        // set test account name to null to trigger update error (Required fields are missing: [Name])
        Account acct = [SELECT Id, Name FROM Account LIMIT 1];
        acct.Name = null;
        List<Account> accounts = new List<Account>{acct};

        Test.startTest();
        List<Database.SaveResult> saveResults = Database.update(accounts, false);
        ERR_Handler_API.processDMLErrors(saveResults, accounts, ERR_CONTEXT, false);
        Test.stopTest();

        // query Error__c record result for asserts
        List<Error__c> errors = errorGateway.getRecords();

        // assert error is created
        System.assertEquals(1, errors.size(), 'There should be only a single Error record created');
        // assert error is not displayed on page
        UTIL_UnitTestData_TEST.assertPageHasNoErrors();

    }

    /**
     * @description If a DML error does not take place, verify no Error__c records are not created
     */
    @IsTest
    private static void shouldNotCreateErrorFromDmlIfNoErrorsGenerated() {

        Test.setCurrentPage(Page.STG_SettingsManager);

        Account acct = [SELECT Id, Name FROM Account LIMIT 1];
        acct.Name = 'NewName';
        List<Account> accounts = new List<Account>{acct};

        Test.startTest();
        List<Database.SaveResult> saveResults = Database.update(accounts, false);
        ERR_Handler_API.processDMLErrors(saveResults, accounts, ERR_CONTEXT, true);
        Test.stopTest();

        // query Error__c record result for asserts
        List<Error__c> errors = errorGateway.getRecords();

        // assert no errors created
        System.assertEquals(0, errors.size(), 'There should not be any Error records created');
        // assert no page error
        UTIL_UnitTestData_TEST.assertPageHasNoErrors();

    }
}
