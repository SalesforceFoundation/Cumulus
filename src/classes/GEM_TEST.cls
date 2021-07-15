@IsTest
private class GEM_TEST {
    @IsTest
    static void isolatedTestNewAndUpdateContactWithHHNaming() {

        HH_Households_TEST.setupHouseholdSettings();
        HH_Households_TEST.setOrgContactSettingsToOneToOne();
        HH_Households_TEST.setupHouseholdNamingSettings();

        Contact con = TEST_ContactBuilder.dummyContact();
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