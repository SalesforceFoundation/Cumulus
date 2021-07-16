/*
    Copyright (c) 2011, Salesforce.org
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
* @date 2011 (1.x)
* @group Accounts
* @description Tests for ACCT_IndividualAccounts_TDTM
*/
@isTest
private class ACCT_IndividualAccounts_TEST {

    /*********************************************************************************************************
    * @description tests default contructor
    */
    private static testMethod void ACCT_IndividualAccounts_TEST() {
        ACCT_IndividualAccounts_TDTM testIndividualAccounts = new ACCT_IndividualAccounts_TDTM();
    }

    /*********************************************************************************************************
    * @description Test Method for inserting a Contact that should get no account
    */
    private static testMethod void insertPrivateOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertPrivateProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void insertPrivateBucket() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertPrivateProcessor(CAO_Constants.BUCKET_PROCESSOR);
    }
    private static testMethod void insertPrivateHHAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertPrivateProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void insertPrivateProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__Private__c=true,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        Test.startTest();
        insert con;
        Test.stopTest();

        Contact[] insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:con.id];

        //contact should have no AccountId
        System.assertEquals(null,insertedContacts[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Accounts created from the trigger should populate the currency code with the contact currency code
    */
    @IsTest
    private static void shouldPopulateNewAccountCurrencyWithContactCurrency() {
        //Skip the test if Advancement is installed
        if (ADV_PackageInfo_SVC.useAdv()) return;

        Boolean isMultiCurrencyEnabled = UserInfo.isMultiCurrencyOrganization();
        String defaultCurrency = UserInfo.getDefaultCurrency();

        Contact newContact = new Contact(
            LastName = 'CurrencyTest',
            FirstName = 'Test'
        );

        String currencyField = '';
        if (isMultiCurrencyEnabled) {

             // Set currency to be something different than the default one if possible
            UTIL_CurrencyCache.CurrencyData nonDefaultCurrency = UTIL_UnitTestData_TEST.nonDefaultCurrencyType;

            if (nonDefaultCurrency != null) {
                defaultCurrency = nonDefaultCurrency.IsoCode;
            }

            newContact.put('CurrencyIsoCode', defaultCurrency);
            currencyField = ', CurrencyIsoCode ';
        }

        Test.startTest();
        insert newContact;
        Test.stopTest();

        String qryString = 'SELECT Id, Name' + currencyField + ' FROM Account LIMIT 1';
        Account newAccount = Database.query(qryString);
        System.assertNotEquals(null, newAccount, 'New Account should be created');
        if (isMultiCurrencyEnabled) {
            System.assertEquals(defaultCurrency, (String) newAccount.get('CurrencyIsoCode'), 'Account Currency Code should be populated with Contact Currency Code');
        }

    }

    /*********************************************************************************************************
    * @description Test changing the account model from one-to-one account to household account.
    */
    private static testMethod void changeFromOneToOneToHouseholdAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	UTIL_CustomSettingsFacade.getHouseholdsSettingsForTests(
            new npo02__Households_Settings__c (npo02__Household_Rules__c = HH_Households.ALL_PROCESSOR));

    	//Set Individual (Bucket) settings
    	npe01__Contacts_And_Orgs_Settings__c contactsSettings = UTIL_CustomSettingsFacade.getContactsSettings();
    	contactsSettings.npe01__Account_Processor__c = CAO_Constants.BUCKET_PROCESSOR;


    	//Create a contact
    	Contact contact1 = new Contact(FirstName = 'Test', LastName = 'Testerson');
        insert contact1;

    	//Verify it's using Individual
    	contact1 = [select Account.Name from Contact Where ID = :contact1.ID];
    	System.assertEquals(CAO_Constants.BUCKET_PROCESSOR, contact1.Account.Name);

    	//Verify we are still using Individual (Bucket) settings
    	contactsSettings = UTIL_CustomSettingsFacade.getContactsSettings();
    	System.assertEquals(CAO_Constants.BUCKET_PROCESSOR, contactsSettings.npe01__Account_Processor__c);

    	//Change to Household Account
    	contactsSettings.npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR;

    	//Create a Contact
    	Contact contact2 = new Contact(FirstName = 'Test2', LastName = 'Testerson2');
        Test.startTest();
        insert contact2;
        Test.stopTest();

    	//Verify it's using Household Account - a new Account should have been created for it
    	Integer numOfAccs = [select count() from Account];
    	System.assertEquals(2, numOfAccs);
    }

    private static testMethod void insertHHAccountContactTitleForRename() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertContactTitleForRename(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void insertContactTitleForRename(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        Household_Naming_Settings__c hhNamingSettingsForTests = UTIL_CustomSettingsFacade.getHouseholdNamingSettingsForTests(
        	new Household_Naming_Settings__c(
                Household_Name_Format__c = '{!LastName} Household',
        		Formal_Greeting_Format__c = '{!{!Title} {!FirstName}} {!LastName}',
                Informal_Greeting_Format__c = '{!{!FirstName}}',
        		Name_Connector__c = label.npo02.HouseholdNameConnector,
       			Name_Overrun__c = label.npo02.HouseholdNameOverrun,
        		Contact_Overrun_Count__c = 9,
        		Implementing_Class__c = 'HH_NameSpec'
            )
        );

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName='Jack',
            LastName='Ruby',
            Title = 'Doctor',
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        Test.startTest();
        insert con;
        Test.stopTest();

        Contact[] insertedContacts = [Select Account.npo02__Formal_Greeting__c, FirstName, LastName, AccountId  from Contact where id=:con.id];
        System.assertEquals('Doctor Jack Ruby', insertedContacts[0].Account.npo02__Formal_Greeting__c);

        con.Title = 'Hard Worker';
        update con;

        Contact[] updatedContacts = [Select Account.npo02__Formal_Greeting__c, FirstName, LastName, AccountId  from Contact where id=:con.id];
        System.assertEquals('Hard Worker Jack Ruby', updatedContacts[0].Account.npo02__Formal_Greeting__c);
    }


    /*********************************************************************************************************
    * @description Create a contact, and change it to private, against all three account models.
    */
    private static testMethod void insertOneToOneChangeToPrivate() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	insertChangeToPrivateProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void insertBucketChangeToPrivate() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertChangeToPrivateProcessor(CAO_Constants.BUCKET_PROCESSOR);
    }
    private static testMethod void insertHHAccountChangeToPrivate() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertChangeToPrivateProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void insertChangeToPrivateProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        Test.startTest();
        insert con;
        Test.stopTest();

        Contact[] insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:con.id];
        ID accountId = insertedContacts[0].AccountId;

        insertedContacts[0].npe01__Private__c = true;
        update insertedContacts;
        insertedContacts = [Select FirstName, LastName, AccountId,npe01__Private__c  from Contact where id=:con.id];
        //contact should have no AccountId
        System.assertEquals(null,insertedContacts[0].AccountId);
        System.assert(insertedContacts[0].npe01__Private__c);

        // account should NOT get deleted
        Account[] acts = [Select Id from Account where Id = :accountId];
        System.assertEquals(1, acts.size());
    }

    /*********************************************************************************************************
    * @description Create a Contact with TDTM triggers off, for both 1:1 and Household account models.
    */
    private static testMethod void insertOneToOneTriggerOff() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	insertTriggerOffProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void insertHHAccountTriggerOff() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertTriggerOffProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void insertTriggerOffProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor,npe01__Disable_Account_Model_Trigger__c=true));

        // turn off all TDTM triggers for this component
        List<Trigger_Handler__c> handlers = new List<Trigger_Handler__c>();
        handlers.add(new Trigger_Handler__c(Active__c = false, Asynchronous__c = false,
              Class__c = 'ACCT_IndividualAccounts_TDTM', Load_Order__c = 1, Object__c = 'Contact',
              Trigger_Action__c = 'BeforeInsert'));
        handlers.add(new Trigger_Handler__c(Active__c = false, Asynchronous__c = false,
              Class__c = 'ACCT_IndividualAccounts_TDTM', Load_Order__c = 1, Object__c = 'Contact',
              Trigger_Action__c = 'BeforeUpdate'));
        handlers.add(new Trigger_Handler__c(Active__c = false, Asynchronous__c = false,
              Class__c = 'ACCT_IndividualAccounts_TDTM', Load_Order__c = 1, Object__c = 'Contact',
              Trigger_Action__c = 'AfterInsert'));
        handlers.add(new Trigger_Handler__c(Active__c = false, Asynchronous__c = false,
              Class__c = 'ACCT_IndividualAccounts_TDTM', Load_Order__c = 1, Object__c = 'Contact',
              Trigger_Action__c = 'AfterUpdate'));
        handlers.add(new Trigger_Handler__c(Active__c = false, Asynchronous__c = false,
              Class__c = 'ACCT_IndividualAccounts_TDTM', Load_Order__c = 1, Object__c = 'Contact',
              Trigger_Action__c = 'AfterDelete'));
        insert handlers;

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        Test.startTest();
        insert con;
        Test.stopTest();

        Contact[] insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:con.id];

        //contact should have no AccountId
        System.assertEquals(null,insertedContacts[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Test Method for inserting and updating a Contact in the One-to-One model
    */
    private static testMethod void insertUpdateOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	insertUpdateOneToOneProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }

    /*********************************************************************************************************
    * @description Test Method for inserting and updating a Contact in the Household Account model
    */
    private static testMethod void insertUpdateOneToOneHouseholds() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        insertUpdateOneToOneProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }

    private static void insertUpdateOneToOneProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        String newContactMailingStreet = '123 Elm St';

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            MailingStreet = newContactMailingStreet,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select FirstName, LastName, AccountId, Account.Name,Account.npe01__One2OneContact__c,MailingStreet,Account.BillingStreet,npe01__Organization_Type__c,Account.npe01__SYSTEMIsIndividual__c  from Contact where id=:con.id];
        UTIL_Debug.debug('****' +insertedContacts);
        UTIL_Debug.debug('****' +insertedcontacts[0].id);
        UTIL_Debug.debug('****' +insertedContacts);
        //one contact should have been created
        System.assertEquals(1,insertedContacts.size());
        //the account should have the right type
        if (strProcessor == CAO_Constants_API.ONE_TO_ONE_PROCESSOR)
            System.assertEquals(CAO_Constants_API.ONE_TO_ONE_ORGANIZATION_TYPE,insertedcontacts[0].npe01__Organization_Type__c);
        else if (strProcessor == CAO_Constants_API.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(CAO_Constants_API.HH_ACCOUNT_TYPE,insertedcontacts[0].npe01__Organization_Type__c);
        //the account should be flagged as an individual
        System.assertEquals(true,insertedcontacts[0].Account.npe01__SYSTEMIsIndividual__c );
        //the account should have been named correctly
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR)
            System.assertEquals(CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS + ' ' + CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,insertedcontacts[0].Account.Name);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(CAO_Constants.CONTACT_LASTNAME_FOR_TESTS + CAO_Constants.HH_NAME_SUFFIX,insertedcontacts[0].Account.Name);
        //relationship should be bi-directional
        System.assertEquals(insertedcontacts[0].id,insertedcontacts[0].Account.npe01__One2OneContact__c);
        //addresses should be sync'd
        System.assertEquals(newContactMailingStreet,insertedcontacts[0].Account.BillingStreet);
        System.assertEquals(insertedcontacts[0].MailingStreet,insertedcontacts[0].Account.BillingStreet);

        String updatedContactLastName = 'Contact_forTestsChange';
        String updatedOtherCity = 'Seattle';
        con.LastName=updatedContactLastName;
        con.OtherCity = updatedOtherCity;
        con.AccountId = insertedContacts[0].AccountId;
        Test.startTest();
        update con;
        Test.stopTest();

        Contact[] updatedContacts = [Select FirstName, LastName, AccountId, Account.Name,Account.npe01__One2OneContact__c,MailingStreet,OtherCity,Account.BillingStreet,Account.ShippingCity from Contact where id=:con.id];

        //the account should have been named correctly
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR)
            System.assertEquals(updatedContacts[0].firstName + ' ' + updatedContacts[0].LastName,updatedContacts[0].Account.Name);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(updatedContacts[0].LastName + CAO_Constants.HH_NAME_SUFFIX,updatedContacts[0].Account.Name);
        //relationship should be bi-directional
        System.assertEquals(updatedContacts[0].id,updatedContacts[0].Account.npe01__One2OneContact__c);
        //addresses should be sync'd
        System.assertEquals(newContactMailingStreet,updatedContacts[0].MailingStreet);
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR) {
	        System.assertEquals(updatedOtherCity,updatedContacts[0].Account.ShippingCity);
	        System.assertEquals(updatedContacts[0].MailingStreet,updatedContacts[0].Account.BillingStreet);
	        System.assertEquals(updatedContacts[0].OtherCity,updatedContacts[0].Account.ShippingCity);
        }
    }

    /*********************************************************************************************************
    * @description Test Method for separating a Contact from it's One-to-One account, in 1:1 and Household Account models.
    */
    private static testMethod void detachOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	detachProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void detachHHAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        detachProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void detachProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select AccountId from Contact where id=:con.id];

        Id originalAccountId = insertedContacts[0].AccountId;

        String updatedContactLastName = 'Contact_forTestsChange';

        con.AccountId = null;
        con.LastName = updatedContactLastName;
        Test.startTest();
        update con;
        Test.stopTest();

        Contact[] updatedContacts = [Select FirstName, LastName, AccountId,Account.Name,Account.npe01__One2OneContact__c from Contact where id=:con.id];

        //Original Account should still be there
        Account[] originalAccount = [Select id from Account where Id=:originalAccountId];

        System.assertEquals(1,originalAccount.size());

        //AccountId of updated contact should match the orignial Account
        System.assertEquals(originalAccountId,updatedContacts[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Test Method for editing a contact while it is being detached from it's One-to-One Account. This was a bug (#37)
    */
    private static testMethod void editContactDuringDetachOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	editContactDuringDetachProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void editContactDuringDetachHHAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        editContactDuringDetachProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void editContactDuringDetachProcessor(string strProcessor) {
        setAccountProcessorSetting(strProcessor);

        String newContactMailingStreet = '123 Elm St';

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            MailingStreet = newContactMailingStreet,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select AccountId from Contact where id=:con.id];

        Id originalAccountId = insertedContacts[0].AccountId;

        String updatedContactLastName = 'Contact_forTestsChange';
        String updateContactMailingStreet = '234 Oak St';

        con.AccountId = null;
        con.LastName = updatedContactLastName;
        con.MailingStreet = updateContactMailingStreet;
        Test.startTest();
        update con;
        Test.stopTest();

        Contact[] updatedContacts = [Select FirstName, LastName, AccountId,Account.Name,Account.npe01__One2OneContact__c,
                MailingStreet,npe01__Organization_Type__c,Account.BillingStreet from Contact where id=:con.id];

        //AccountId of updated contact should match the original Account
        System.assertEquals(originalAccountId,updatedContacts[0].AccountId);

        //org type should be set correctly
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR) {
            System.assertEquals(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, updatedContacts[0].npe01__Organization_Type__c);
        } else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR) {
            System.assertEquals(CAO_Constants.HH_ACCOUNT_TYPE, updatedContacts[0].npe01__Organization_Type__c);
        }

        //the account should have been named correctly
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR) {
            System.assertEquals(updatedContacts[0].FirstName + ' ' + updatedContacts[0].LastName, updatedContacts[0].Account.Name);
        } else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR) {
            System.assertEquals(updatedContacts[0].LastName + CAO_Constants.HH_NAME_SUFFIX, updatedContacts[0].Account.Name);
            System.assertEquals(2, [SELECT Count() FROM Address__c WHERE Household_Account__c = :originalAccountId],
                'There should two addresses attached to the Household');

            Integer attachedAddressCount = 0;
            for (Address__c address : [SELECT Id, MailingStreet__c FROM Address__c]) {
                if (address.MailingStreet__c == updateContactMailingStreet) {
                    attachedAddressCount++;
                }
            }
            System.assertEquals(1, attachedAddressCount,
                'There should one address with the new street attached to the Household');
        }

        //addresses should be sync'd
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR) {
            System.assertEquals(updateContactMailingStreet,updatedContacts[0].MailingStreet);
            System.assertEquals(updatedContacts[0].MailingStreet,updatedContacts[0].Account.BillingStreet);
        }
    }

    private static void setAccountProcessorSetting(String strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests =
                UTIL_CustomSettingsFacade.getContactsSettingsForTests(
                        new npe01__Contacts_and_Orgs_Settings__c (
                                npe01__Account_Processor__c = strProcessor));
    }

    /*********************************************************************************************************
    * @description Test Method for a new Contact in the Bucket Individual model
    */
    private static testMethod void attachToIndividualAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	attachToProcessor(CAO_Constants.BUCKET_PROCESSOR);
    }
    private static testMethod void attachToHHAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        attachToProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void attachToProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        Test.startTest();
        insert con;
        Test.stopTest();

        Contact[] insertedContacts = [Select Account.Name,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];
        //the contact should have the right type
        if (strProcessor == CAO_Constants_API.BUCKET_PROCESSOR)
            System.assertEquals(CAO_Constants_API.BUCKET_ORGANIZATION_TYPE,insertedcontacts[0].npe01__Organization_Type__c);
        else if (strProcessor == CAO_Constants_API.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(CAO_Constants_API.HH_ACCOUNT_TYPE,insertedcontacts[0].npe01__Organization_Type__c);
        //the account should have been named correctly
        if (strProcessor == CAO_Constants_API.BUCKET_PROCESSOR)
            System.assertEquals(CAO_Constants_API.BUCKET_ACCOUNT_NAME,insertedcontacts[0].Account.Name);
        else if (strProcessor == CAO_Constants_API.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(con.LastName + CAO_Constants.HH_NAME_SUFFIX,insertedcontacts[0].Account.Name);
    }

    /*********************************************************************************************************
    * @description Test Method for detaching a Contact from the bucket individual account
    */
    private static testMethod void detachIndividualAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        if (UTIL_UnitTestData_TEST.isAccountNameEncrypted()) return;

        detachAccountProcessor(CAO_Constants.BUCKET_PROCESSOR);
    }
    private static testMethod void detachHHAccount2() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        detachAccountProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void detachAccountProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select Account.Name,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        Id AccountId = insertedContacts[0].AccountId;

        con.AccountId = null;
        Test.startTest();
        update con;
        Test.stopTest();

        Contact[] updatedContacts = [Select Lastname,Account.Name,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        //the contact should have the right type
        if (strProcessor == CAO_Constants.BUCKET_PROCESSOR)
            System.assertEquals(CAO_Constants.BUCKET_ORGANIZATION_TYPE,updatedContacts[0].npe01__Organization_Type__c);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(CAO_Constants.HH_ACCOUNT_TYPE,updatedContacts[0].npe01__Organization_Type__c);
        //the account should have been named correctly
        if (strProcessor == CAO_Constants.BUCKET_PROCESSOR)
            System.assertEquals(CAO_Constants.BUCKET_ACCOUNT_NAME,updatedContacts[0].Account.Name);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(updatedContacts[0].Lastname + CAO_Constants.HH_NAME_SUFFIX,updatedContacts[0].Account.Name);
        //the account should have the correct AccountId
        System.assertEquals(AccountId,updatedContacts[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Test Method for detaching a Contact from a normal account. It should land in the bucket account.
    */
    private static testMethod void detachFromNormalAccountToBucket() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	detachFromNormalAccountToBucketProcessor(CAO_Constants.BUCKET_PROCESSOR);
    }

    /*********************************************************************************************************
    * @description Test Method for detaching a Contact from a normal account. It should land in the bucket account.
    */
    private static testMethod void detachFromNormalAccountToBucketAccountProcessor() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        detachFromNormalAccountToBucketProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }

    private static void detachFromNormalAccountToBucketProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = CAO_Constants.BUCKET_PROCESSOR));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Account acct = new Account(Name='Test Account 876');
        insert acct;

        Account[] insertedAccount = [select npe01__SystemIsIndividual__c from Account where id = :acct.id];

        //the account should not be an individual one
        System.assert(!insertedAccount[0].npe01__SystemIsIndividual__c);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            AccountId = acct.id,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select Account.Name,Account.npe01__SystemIsIndividual__c,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        //the contact should be connected to the account
        System.assertEquals(acct.id,insertedContacts[0].AccountId);
        //the account should not be an individual account
        System.assert(!insertedContacts[0].Account.npe01__SystemIsIndividual__c);

        con.AccountId = null;
        Test.startTest();
        update con;
        Test.stopTest();

        Contact[] updatedContacts = [Select Account.Name,AccountId,Account.npe01__SystemIsIndividual__c,npe01__Organization_Type__c from Contact where id=:con.id];

        //the account should be an individual account
        System.assert(updatedContacts[0].Account.npe01__SystemIsIndividual__c);
        //the account should not be the one we started with
        System.assertNotEquals(acct.id,updatedContacts[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Add a contact to an existing 1:1 or Household Account
    */
    private static testMethod void contactAddedToExistingOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	contactAddedToExistingProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void contactAddedToExistingHHAccount() {
        contactAddedToExistingProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void contactAddedToExistingProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select Account.Name,Account.npe01__SystemIsIndividual__c,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        Id accountId = insertedContacts[0].AccountId;

        Contact con2 = new Contact(FirstName='John', LastName='Smith',AccountId=accountId);

        Test.startTest();
        insert con2;
        Test.stopTest();

        Contact[] insertedContact = [Select Account.Name,AccountId,Account.npe01__SystemIsIndividual__c,npe01__Organization_Type__c from Contact where id=:con2.id];

        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR)
            System.assertNotEquals(accountId,insertedContact[0].AccountId);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(accountId,insertedContact[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Update a contact to an existing 1:1 or Household Account
    */

    private static testMethod void contactUpdatedToExistingOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	contactUpdatedToExistingOneToOneProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }

    private static testMethod void contactUpdatedToExistingOneToOneHH() {
        contactUpdatedToExistingOneToOneProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }

    private static void contactUpdatedToExistingOneToOneProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select Account.Name,Account.npe01__SystemIsIndividual__c,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        Id accountId = insertedContacts[0].AccountId;

        Contact con2 = new Contact(FirstName='John', LastName='Smith',AccountId=null);
        insert con2;

        // now update the contact to the existing account from contact 1
        con2.AccountId = accountId;
        Test.startTest();
        update con2;
        Test.stopTest();

        Contact[] insertedContact = [Select Account.Name,AccountId,Account.npe01__SystemIsIndividual__c,npe01__Organization_Type__c from Contact where id=:con2.id];

        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR)
            System.assertNotEquals(accountId,insertedContact[0].AccountId);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(accountId,insertedContact[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Update a contact's Lastname in the 1:1 and Household Account models
    */
    private static testMethod void contactInNormalOrgNameChangeOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	contactInNormalOrgNameChangeProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    private static testMethod void contactInNormalOrgNameChangeHHAccount() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        contactInNormalOrgNameChangeProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    private static void contactInNormalOrgNameChangeProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        String acctName = 'Test Account 876';
        Account acct = new Account(Name=acctName);
        insert acct;

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            AccountId = acct.id,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select Account.Name,Account.npe01__SystemIsIndividual__c,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        //the contact should be connected to the account
        System.assertEquals(acct.id,insertedContacts[0].AccountId);

        System.assertEquals(acctName,insertedContacts[0].Account.Name);


        Contact con2 = new Contact(id=con.id, LastName='Smith');
        Test.startTest();
        update con2;
        Test.stopTest();

        Contact[] updatedContacts = [Select Account.Name,AccountId,Account.npe01__SystemIsIndividual__c,npe01__Organization_Type__c from Contact where id=:con.id];

        System.assertEquals(acctName,updatedContacts[0].Account.Name);
    }

    /*********************************************************************************************************
    * @description Test Method for detaching a Contact from an org account. It should land in a one-to-one account.
    */
    private static testMethod void detachFromNormalAccountToOneToOne() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	detachFromNormalAccountToOneToOneProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }

    /*********************************************************************************************************
    * @description Test Method for detaching a Contact from an org account. It should land in Household account.
    */
    private static testMethod void detachFromNormalAccountToOneToOneHousehold() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        detachFromNormalAccountToOneToOneProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }

    private static void detachFromNormalAccountToOneToOneProcessor(string strProcessor) {
        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Account acct = new Account(Name='Test Account 876');
        insert acct;

        Account[] insertedAccount = [select npe01__SystemIsIndividual__c from Account where id = :acct.id];

        //the account should not be an individual one
        System.assert(!insertedAccount[0].npe01__SystemIsIndividual__c);

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            AccountId = acct.id,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select Account.Name,Account.npe01__SystemIsIndividual__c,AccountId,npe01__Organization_Type__c from Contact where id=:con.id];

        //the contact should be connected to the account
        System.assertEquals(acct.id,insertedContacts[0].AccountId);
        //the account should not be an individual account
        System.assert(!insertedContacts[0].Account.npe01__SystemIsIndividual__c);

        con.AccountId = null;
        Test.startTest();
        update con;
        Test.stopTest();

        Contact[] updatedContacts = [Select Account.Name,AccountId,Account.npe01__SystemIsIndividual__c,npe01__Organization_Type__c from Contact where id=:con.id];

        //the account should be an individual account
        System.assert(updatedContacts[0].Account.npe01__SystemIsIndividual__c);
        //the account should not be the one we started with
        System.assertNotEquals(acct.id,updatedContacts[0].AccountId);
    }

    /*********************************************************************************************************
    * @description Delete a Contact and verify its One-to-One or Household Account is not deleted.
    */
     public static testMethod void deleteContactNoOppOneToOne() {
     	deleteContactNoOppProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
     }
     public static testMethod void deleteContactNoOppHHAccount() {
        deleteContactNoOppProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
     }
     public static void deleteContactNoOppProcessor(string strProcessor) {

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        String newContactMailingStreet = '123 Elm St';

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            MailingStreet = newContactMailingStreet,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;
        Id contactId;
        contactId = con.id;

        Contact[] insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:contactId];
        Id createdAccountId = insertedContacts[0].AccountId;

        Test.startTest();
        delete con;
        Test.stopTest();

        insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:contactId];
        System.assertEquals(0,insertedContacts.size());

        Account[] missingAccount = [select id from Account where id=:createdAccountId];
        System.assertEquals(1,missingAccount.size());
    }

    /*********************************************************************************************************
    * @description Delete a Contact with Opps and verify its One-to-One or Household Account is not deleted.
    */
    public static testMethod void deleteContactWithOppOneToOne() {
    	deleteContactWithOppProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }
    public static testMethod void deleteContactWithOppHHAccount() {
        deleteContactWithOppProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }
    public static void deleteContactWithOppProcessor(string strProcessor) {

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        String newContactMailingStreet = '123 Elm St';

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            MailingStreet = newContactMailingStreet,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;
        Id contactId;
        contactId = con.id;
        Id accountId;
        Contact[] insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:contactId];

        Id createdAccountId = insertedContacts[0].AccountId;

       Opportunity opp = new Opportunity(
            Amount=500,
            AccountId=createdAccountId,
            Name='test',
            StageName='Closed/Won',
            CloseDate=System.today()
        );
        insert opp;

        Test.startTest();
        delete con;
        Test.stopTest();

        Account[] missingAccount = [select id from Account where id=:createdAccountId];
        System.assertEquals(1,missingAccount.size());
    }

    /*********************************************************************************************************
    * @description Delete a Contact from an Org Account and make sure the Account is not deleted.
    */
    public static testMethod void deleteContactNormalAccountOneToOne() {
    	deleteContactNormalAccountProcessor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }

    /*********************************************************************************************************
    * @description Delete a Contact from an Org Account and make sure the Account is not deleted.
    */
    public static testMethod void deleteContactNormalAccountHouseholdAcc() {
        deleteContactNormalAccountProcessor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }

    public static void deleteContactNormalAccountProcessor(string strProcessor) {

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        CAO_Constants.setIndividualAccountForTests(CAO_Constants.INDIVIDUAL_ACCOUNT_NAME_FOR_TESTS);

        Account orgAccount = new Account(
            Name='Fake account'
        );
        insert orgAccount;

        String newContactMailingStreet = '123 Elm St';

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            MailingStreet = newContactMailingStreet,
            AccountId=orgAccount.id,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact[] insertedContacts = [Select FirstName, LastName, AccountId  from Contact where id=:con.id];

        Id createdAccountId = insertedContacts[0].AccountId;

        Test.startTest();
        delete con;
        Test.stopTest();

        Account[] missingAccount = [select id from Account where id=:createdAccountId];
        System.assertEquals(1,missingAccount.size());
    }

    /*********************************************************************************************************
    * @description Rename a Contact's firstname to null and make sure the 1:1 Account's name gets updated
    */
    private static testMethod void ghIssue16a(){
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	ghIssue16Processor(CAO_Constants.ONE_TO_ONE_PROCESSOR);
    }

    /*********************************************************************************************************
    * @description Rename a Contact's firstname to null and make sure the Household Account's name gets updated
    */
    private static testMethod void ghIssue16b(){
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

    	ghIssue16Processor(CAO_Constants.HH_ACCOUNT_PROCESSOR);
    }

    private static void ghIssue16Processor(string strProcessor){
        /* Set value of Account name to blank when first name is blank, not null */

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = strProcessor));

        Contact con = new Contact(
            FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
            LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        con = [select AccountId from Contact where id = :con.Id];
        Account newAcc = [select id,Name from Account where id = :con.AccountId limit 1];
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR)
            System.assertEquals(newAcc.Name, CAO_Constants.Contact_FIRSTNAME_FOR_TESTS + ' ' + CAO_Constants.Contact_LASTNAME_FOR_TESTS);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(newAcc.Name, CAO_Constants.Contact_LASTNAME_FOR_TESTS + CAO_Constants.HH_NAME_SUFFIX);

        //set name to null
        con.FirstName = null;

        Test.startTest();
        update con;
        Test.stopTest();

        newAcc = [select id,Name from Account where id = :con.AccountId limit 1];
        if (strProcessor == CAO_Constants.ONE_TO_ONE_PROCESSOR)
            System.assertEquals(newAcc.Name, CAO_Constants.Contact_LASTNAME_FOR_TESTS);
        else if (strProcessor == CAO_Constants.HH_ACCOUNT_PROCESSOR)
            System.assertEquals(newAcc.Name, CAO_Constants.Contact_LASTNAME_FOR_TESTS + CAO_Constants.HH_NAME_SUFFIX);
    }

    /*********************************************************************************************************
    * @description Undelete a contact back to an existing Household Account
    */
    private static testMethod void undeleteContactToExistingHH() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR));

        Household_Naming_Settings__c hhNamingSettingsForTests = UTIL_CustomSettingsFacade.getHouseholdNamingSettingsForTests(
            new Household_Naming_Settings__c(
                Household_Name_Format__c = '{!LastName} Household',
                Formal_Greeting_Format__c = '{!{!Salutation} {!FirstName}} {!LastName}',
                Informal_Greeting_Format__c = '{!{!FirstName}}',
                Name_Connector__c = label.npo02.HouseholdNameConnector,
                Name_Overrun__c = label.npo02.HouseholdNameOverrun,
                Contact_Overrun_Count__c = 9,
                Implementing_Class__c = 'HH_NameSpec'
            )
        );

        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact insertedCon = [SELECT Account.Name, AccountId FROM Contact WHERE Id = :con.Id LIMIT 1];
        Id acctId = insertedCon.AccountId;

        Contact con2 = new Contact(FirstName = 'Johnny', LastName = 'Test', AccountId = null);
        con2.AccountId = acctId;
        insert con2;

        Contact insertedCon2 = [SELECT Account.Name, AccountId FROM Contact WHERE Id = :con2.Id LIMIT 1];

        System.assertNotEquals(null, acctId, 'The account should have been automatically created and assigned to the contact');
        System.assertEquals(acctId, insertedCon2.AccountId, 'The second contact should be assigned to the same account as the first');
        System.assert(insertedCon2.Account.Name.contains(con.LastName), 'The Account Name should contain the first contacts last name.');
        System.assert(insertedCon2.Account.Name.contains(con2.LastName), 'The Account Name should contain the second contacts last name.');

        delete insertedCon2;

        List<Contact> insertedContacts = [SELECT Account.Name FROM Contact WHERE AccountId = :acctId];
        System.assertEquals(1, insertedContacts.size(), 'The second contact should have been deleted, only one should remain.');
        System.assert(insertedContacts[0].Account.Name.contains(con.LastName), 'The Account Name should still contain the first contacts last name.');
        System.assert(!insertedContacts[0].Account.Name.contains(con2.LastName), 'The Account Name should no longer contain the first contacts last name after delete.');

        Test.startTest();
        undelete insertedCon2;
        Test.stopTest();

        insertedContacts = [SELECT Account.Name FROM Contact WHERE AccountId = :acctId];
        System.assertEquals(2, insertedContacts.size(), 'The second contact should have been undeleted, both contacts should be there.');
        System.assert(insertedContacts[0].Account.Name.contains(con.LastName), 'The Account Name should still contain the first contacts last name.');
        System.assert(insertedContacts[0].Account.Name.contains(con2.LastName), 'The Account Name should contain the first contacts last name after undelete.');
    }

    /*********************************************************************************************************
    * @description Delete a HH Contact without Opps and verify it can be undeleted.
    */
    public static testMethod void undeleteHHContactNoOpp() {

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR));

        Contact con = new Contact(
            FirstName = 'Johnny',
            LastName = 'Test',
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        delete con;

        Test.startTest();
        try {
            undelete con;
        } catch (Exception e) {
            System.assert(false, 'The contact is no longer in the recycle bin and cannot be undeleted.');
        }
        Test.stopTest();
    }

    /*********************************************************************************************************
    * @description Delete a HH Contact with opps and verify account name is updated after undelete.
    */
    public static testMethod void undeleteHHContactWithOpp() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR));

        Household_Naming_Settings__c hhNamingSettingsForTests = UTIL_CustomSettingsFacade.getHouseholdNamingSettingsForTests(
            new Household_Naming_Settings__c(
                Household_Name_Format__c = '{!LastName} Household',
                Formal_Greeting_Format__c = '{!{!Salutation} {!FirstName}} {!LastName}',
                Informal_Greeting_Format__c = '{!{!FirstName}}',
                Name_Connector__c = label.npo02.HouseholdNameConnector,
                Name_Overrun__c = label.npo02.HouseholdNameOverrun,
                Contact_Overrun_Count__c = 9,
                Implementing_Class__c = 'HH_NameSpec'
            )
        );

        Contact con = new Contact(
            FirstName = 'Johnny',
            LastName = 'Test',
            npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
            npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
            npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
            npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        insert con;

        Contact insertedCon = [SELECT AccountId, Account.Name FROM Contact WHERE Id = :con.Id LIMIT 1];
        Id acctId = insertedCon.AccountId;
        System.assert(insertedCon.Account.Name.contains(con.LastName), 'The Account Name should contain the contacts last name.');

        //add other contact to household and associate opportunity with that contact to avoid cascade deletion of opportunity
        Contact othercon = new Contact(accountId = acctId, LastName='other');
        insert othercon;

        Opportunity opp = new Opportunity(
            Amount = 500,
            AccountId = acctId,
            Name = 'test',
            StageName = UTIL_UnitTestData_TEST.getClosedWonStage(),
            CloseDate = System.today(),
            Primary_Contact__c = othercon.id
        );
        insert opp;

        delete con;

        List<Error__c> errors = [SELECT Id, Object_Type__c, Full_Message__c, Stack_Trace__c FROM Error__c];
        System.assertEquals(0, errors.size(), errors);

        Account anonymousAcct = [SELECT Id, Name, (SELECT Id FROM Contacts) FROM Account WHERE Id = :acctId LIMIT 1];
        System.assert(!anonymousAcct.Name.contains(con.LastName), 'The Account Name should no longer contain the contacts last name.');

        Test.startTest();
        undelete con;
        Test.stopTest();

        Contact undeletedCon = [SELECT AccountId, Account.Name FROM Contact WHERE Id = :con.Id LIMIT 1];
        System.assert(undeletedCon.Account.Name.contains(con.LastName), 'The Account Name should contain the contacts last name again.');
        System.assertEquals(acctId, undeletedCon.AccountId, 'The contact should be returned to the same account.');
    }

    /*********************************************************************************************************
    @description
        Update a Household Account's Record Type to another Record Type
    verify:
        The specific system fields should not be set.
    **********************************************************************************************************/
    public static testMethod void updateHHAccountRecType() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        Boolean isPersonAccountEnabled = UTIL_Describe.isValidField('Account', 'isPersonAccount');

        String soql = String.format(
            'SELECT Id{0} FROM RecordType WHERE SobjectType = \'\'Account\'\' AND IsActive = true',
            new String[] { isPersonAccountEnabled ? ', IsPersonType' : '' }
        );
        List<RecordType> rectypes = database.query(soql);

        if (rectypes == null || rectypes.size() < 2) {
            return;
        }

        UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (
                npe01__Account_Processor__c = CAO_Constants.HH_ACCOUNT_PROCESSOR,
                npe01__HH_Account_RecordTypeID__c = rectypes[0].id
            )
        );

        Contact con = new Contact(LastName = 'Test');
        insert con;
        con = [SELECT AccountId FROM Contact WHERE Id = :con.id];

        Account queryAccount = [SELECT Id, RecordTypeId, npe01__SYSTEMISINDIVIDUAL__c, npe01__SYSTEM_AccountType__c FROM Account WHERE Id = :con.AccountId];

        System.assertEquals(rectypes[0].id, queryAccount.RecordTypeId, 'Record Type should be set to hh account rectype defined in settings.');
        System.assertEquals(true, queryAccount.npe01__SYSTEMISINDIVIDUAL__c, 'IsIndividual system field should be set for household account.');
        System.assertEquals(CAO_Constants.HH_ACCOUNT_TYPE, queryAccount.npe01__SYSTEM_AccountType__c, 'Account Type system field should be set for household account.');

        Id newRecordTypeId = findAnotherRecordTypeId(rectypes[0].id, rectypes, isPersonAccountEnabled);
        if (newRecordTypeId == null) {
            //Cannot verify the rest of the test since
            //a Record Type of the same isPersonType (where applicable) does not exist
            return;
        }

        System.assertNotEquals(rectypes[0].id, newRecordTypeId);

        Test.startTest();
        //If the Account is a Person Account, no other field can be updated when changing the Record Type
        update new Account(Id = queryAccount.Id, RecordTypeId = newRecordTypeId);
        Test.stopTest();

        queryAccount = [SELECT Id, RecordTypeId, npe01__SYSTEMISINDIVIDUAL__c, npe01__SYSTEM_AccountType__c FROM Account WHERE Id = :con.AccountId];

        System.assertEquals(false, queryAccount.npe01__SYSTEMISINDIVIDUAL__c, 'Individual system field should not be set after the Record Type change.');
        System.assertNotEquals(CAO_Constants.HH_ACCOUNT_TYPE, queryAccount.npe01__SYSTEM_AccountType__c, 'Account Type system field should not be set after the Record Type change.');
    }

    /*********************************************************************************************************
    * @description Update a 1-1 contact's first name and ownerid, verify no "duplicate id in list" exception.
    */
    public static testMethod void regressionDuplicateIdInList() {
        //skip the test if Advancement is installed
        if(ADV_PackageInfo_SVC.useAdv()) return;

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(
            new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = CAO_Constants.ONE_TO_ONE_PROCESSOR)
        );

        Contact con = new Contact(
            LastName = 'Test'
        );
        insert con;

        Contact queryCon = [SELECT Id, AccountId, OwnerId FROM Contact WHERE Id = :con.id];
        Account queryAccount = [SELECT Id, RecordTypeId, npe01__SYSTEMISINDIVIDUAL__c, npe01__SYSTEM_AccountType__c FROM Account WHERE Id = :queryCon.AccountId];

        System.assertEquals(true, queryAccount.npe01__SYSTEMISINDIVIDUAL__c, 'IsIndividual system field should be set for household account.');
        System.assertEquals(CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE, queryAccount.npe01__SYSTEM_AccountType__c, 'Account Type system field should be set for household account.');

        List<User> secondUser = [SELECT Id FROM User WHERE Id != :queryCon.OwnerId AND IsActive = true AND UserType = 'Standard' LIMIT 1];
        //regression only possible with a second active user, exit if we don't have one
        if (secondUser.isEmpty()) {
            return;
        }

        Test.startTest();
        con.FirstName = 'foo';
        con.OwnerId = secondUser[0].id;
        try {
            update con;
        } catch (Exception ex) {
            System.assert(false, 'No exception should occur: ' + ex);
        }
        Test.stopTest();
    }

    /*********************************************************************************************************
    @description
        Test Contact insert and update when Household Naming Settings is invalid
        and the Automatic Household Naming is turned off
    verify:
        The Contact is created and updated successfully
    **********************************************************************************************************/
    private static testMethod void testContactDmlWhenHHNamingSettingsIsInvalidAndAutomaticHHNamingIsOff() {
        UTIL_UnitTestData_TEST.turnOffAutomaticHHNaming();
        UTIL_UnitTestData_TEST.setupInvalidHHNamingSettings();

        Contact contact = new Contact(LastName = 'Smith');
        try {
            insert contact;

        } catch (Exception e) {
            System.assert(false, 'Unexpected error on Contact insert: ' + e.getMessage());
        }

        try {
            contact.FirstName = 'John';
            update contact;

        } catch (Exception e) {
            System.assert(false, 'Unexpected error on Contact update: ' + e.getMessage());
        }

        System.assertEquals('John', [SELECT FirstName FROM Contact WHERE Id = :contact.Id][0].FirstName, 'Contact update should succeed');
    }

    /*********************************************************************************************************
    @description
        Test SOQL built by buildContactSoql()
    verify:
        The SOQL retrieves data for specified Contacts only.
        The SOQL contains no duplicate field.
        The SOQL contains Household Naming fields.
    **********************************************************************************************************/
    private static testMethod void testContactSoqlReturnsQueryForSpecifiedContacts() {
        UTIL_UnitTestData_TEST.turnOnAutomaticHHNaming();
        UTIL_UnitTestData_TEST.setupHHNamingSettings(
            'The {!lastname}, {!{!FIRSTname}} Family',
            '{!{!SALUTATION} {!FIRSTname}} {!LASTNAME}',
            '{!{!npe01__WorkEmail__c}}'
        );
        String soql = new ContactSelector().buildContactSoql(null);

        System.assert(soql.contains('npe01__WorkEmail__c'));// the only field added from Household Naming fields

        Contact[] contacts = new Contact[]{
            new Contact(LastName = 'testSoql1'),
            new Contact(LastName = 'testSoql2')
        };
        insert contacts;

        insert new Contact(LastName = 'testSoqlExclude');

        // Verify the SOQL is correct and there is no duplicate field error raised
        Contact[] actualContacts;
        try {
            actualContacts = Database.query(soql);
        } catch (Exception e) {
            System.assert(false, 'Unexpected error when SOQL (' + soql + ') has been run: ' + e.getMessage());
        }

        System.assert(actualContacts != null, 'Contacts should be returned when the SOQL is has been run');
        System.assertEquals(contacts.size(), actualContacts.size(), 'Expected Contacts: ' + contacts + '; Actual Contacts: ' + actualContacts);
        System.assert(
            new Map<Id, Contact>(contacts).keySet().containsAll(new Map<Id, Contact>(actualContacts).keySet()),
            'Expected Contacts: ' + contacts + '; Actual Contacts: ' + actualContacts
        );
    }

    /**
     * @description Validate that when inserting a new Account for a Contact, it uses the same OwnerId as the
     * Contact that was inserted (especially if the Contact.OwnerId is set to a value other than the current user).
     */
    private static testMethod void test_insertAsOtherUser() {

        // Create a single new User
        User tempUser = UTIL_UnitTestData_TEST.createUserWithoutInsert(UTIL_Profile.SYSTEM_ADMINISTRATOR);
        tempUser.IsActive = true;
        insert tempUser;

        Id currUserId = UserInfo.getUserId();
        Contact c = UTIL_UnitTestData_TEST.getContact();
        c.OwnerId = currUserId;
        System.runAs(tempUser) {
            insert c;
            c = [SELECT Id, OwnerId, Account.OwnerId FROM Contact WHERE Id = :c.Id LIMIT 1];
            System.assertEquals(c.OwnerId, currUserId, 'The Contact owner should be current system admin user');
            System.assertEquals(c.Account.OwnerId, currUserId, 'The Account owner should be the same as the Contact Owner');
        }
    }

    // Helpers
    ////////////

    /*********************************************************************************************************
    * @description Find another Record Type Id that is not recTypeId. If the org has Person Accounts enabled,
    * then other Record Type must be of the same isPersonType as the input recTypeId.
    * @param recTypeId A Record Type Id
    * @param recTypes List of all Record Types for the Account SObjectType
    * @param isPersonAccountEnabled Flag to indicate if the org has Person Accounts enabled
    * @return Id An Id of another Record Type
    **********************************************************************************************************/
    static Id findAnotherRecordTypeId(Id recTypeId, List<RecordType> recTypes, Boolean isPersonAccountEnabled) {
        Id newRecTypeId = null;

        Map<Id, RecordType> recTypesById = new Map<Id, RecordType>(recTypes);
        RecordType recType = recTypesById.remove(recTypeId);

        if (recTypesById.isEmpty() || recType == null) {
            return newRecTypeId;
        }

        if (isPersonAccountEnabled) {
            //Choose a Record Type that has the same IsPersonType value
            Boolean isPersonType = (Boolean) recType.get('IsPersonType');

            for (RecordType rt : recTypesById.values()) {
                if ((Boolean) rt.get('IsPersonType') == isPersonType) {
                    newRecTypeId = rt.Id;
                    break;
                }
            }
        } else {
            //Choose any Record Type that is not input recTypeId
            newRecTypeId = recTypesById.values()[0].Id;
        }

        return newRecTypeId;
    }
}