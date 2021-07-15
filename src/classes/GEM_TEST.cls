/**
 * Created by bdvorachek on 7/15/21.
 */

@IsTest
private class GEM_TEST {
    @IsTest
    static void testNewAndUpdateContactWithHHNaming() {

        npo02__Households_Settings__c householdSettingsForTests = UTIL_CustomSettingsFacade.getHouseholdsSettingsForTests(new npo02__Households_Settings__c (npo02__Household_Rules__c = HH_Households.ALL_PROCESSOR, npo02__Advanced_Household_Naming__c = true));

        npe01__Contacts_and_Orgs_Settings__c contactSettingsForTests = UTIL_CustomSettingsFacade.getContactsSettingsForTests(new npe01__Contacts_and_Orgs_Settings__c (npe01__Account_Processor__c = CAO_Constants.ONE_TO_ONE_PROCESSOR));

        Household_Naming_Settings__c hhNamingSettingsForTests = UTIL_CustomSettingsFacade.getHouseholdNamingSettingsForTests(
                new Household_Naming_Settings__c(
                        Household_Name_Format__c = '{!LastName} Household',
                        Formal_Greeting_Format__c = '{!{!Title}} {!LastName}',
                        Informal_Greeting_Format__c = '{!{!FirstName}}',
                        Name_Connector__c = label.npo02.HouseholdNameConnector,
                        Name_Overrun__c = label.npo02.HouseholdNameOverrun,
                        Contact_Overrun_Count__c = 9,
                        Implementing_Class__c = 'HH_NameSpec'
                )
        );

        Contact con = new Contact(
                FirstName=CAO_Constants.CONTACT_FIRSTNAME_FOR_TESTS,
                LastName=CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,
                Title= 'Doctor',
                npe01__WorkEmail__c = CAO_Constants.CONTACT_EMAIL_FOR_TESTS,
                npe01__Preferred_Email__c = CAO_Constants.CONTACT_PREFERRED_EMAIL_FOR_TESTS,
                npe01__WorkPhone__c = CAO_Constants.CONTACT_PHONE_FOR_TESTS,
                npe01__PreferredPhone__c = CAO_Constants.CONTACT_PREFERRED_PHONE_FOR_TESTS
        );
        Test.startTest();
        insert con;
        Test.stopTest();

        Contact[] createdContacts = [select npo02__household__r.npo02__Formal_Greeting__c  from Contact where id=:con.id];
        system.assertEquals('Doctor '+CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,createdContacts[0].npo02__household__r.npo02__Formal_Greeting__c  );

        con.Title = 'Handy Man';
        update con;

        Contact[] updatedContacts = [select npo02__household__r.npo02__Formal_Greeting__c  from Contact where id=:con.id];
        system.assertEquals('Handy Man '+CAO_Constants.CONTACT_LASTNAME_FOR_TESTS,updatedContacts[0].npo02__household__r.npo02__Formal_Greeting__c  );
    }
}