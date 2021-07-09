/*
    Copyright (c) 2021 Salesforce.org
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
* @description Tests for the synchronization of Household Naming Exclusions on Contacts.
*/
@IsTest
private class HouseholdNamingExclusions_TEST {

    @IsTest
    static void checkboxesShouldSyncToStringBeforeInsert() {
        Contact c = new Contact(
                LastName = 'test',
                Exclude_from_Household_Name__c = true,
                Exclude_from_Household_Formal_Greeting__c = true
        );

        Contacts contacts = new Contacts(new List<Contact>{
                c
        });
        contacts.onBeforeInsert();

        HouseholdNamingExclusionsString householdNamingExclusionsString =
                new HouseholdNamingExclusionsString(c);
        System.assertEquals(true, householdNamingExclusionsString.isExcludedFromName(),
                'The Household Naming Exclusions string should be synced with the ' +
                        'Naming Exclusion checkboxes on Contact insert.');
    }

    @IsTest
    static void multipleCheckboxesShouldSyncToStringBeforeInsert() {
        String assertMsg = 'The Household Naming Exclusions string should be synced with the ' +
                'Naming Exclusion checkboxes on Contact insert.';

        Contact c = new Contact(
                LastName = 'test',
                Exclude_from_Household_Name__c = true,
                Exclude_from_Household_Formal_Greeting__c = true
        );

        Contacts contacts = new Contacts(new List<Contact>{
                c
        });
        contacts.onBeforeInsert();

        HouseholdNamingExclusionsString householdNamingExclusionsString =
                new HouseholdNamingExclusionsString(c);
        System.assertEquals(true, householdNamingExclusionsString.isExcludedFromName(),
                assertMsg);
        System.assertEquals(true, householdNamingExclusionsString.isExcludedFromFormalGreeting(),
                assertMsg);
    }

    @IsTest
    static void checkboxesShouldSyncToStringBeforeUpdate() {
        Id id = UTIL_UnitTestData_TEST.mockId(Contact.SObjectType);
        Contact c = new Contact(
                Id = id,
                LastName = 'test',
                Exclude_from_Household_Name__c = true
        );

        Contact oldContact = new Contact(
                Id = id,
                LastName = 'test'
        );
        Contacts contacts = new Contacts(new List<Contact>{
                c
        }, new List<Contact>{
                oldContact
        });
        contacts.onBeforeUpdate();

        HouseholdNamingExclusionsString householdNamingExclusionsString =
                new HouseholdNamingExclusionsString(c);
        System.assertEquals(true, householdNamingExclusionsString.isExcludedFromName(),
                'The Household Naming Exclusions string should be synced with the ' +
                        'Naming Exclusion checkboxes on Contact update.');
    }

    @IsTest
    static void stringShouldSyncToCheckboxesBeforeInsert() {
        Contact c = new Contact(
                LastName = 'test',
                npo02__Naming_Exclusions__c = 'Household__c.Name'
        );

        Contacts contacts = new Contacts(new List<Contact>{
                c
        });
        contacts.onBeforeInsert();

        HouseholdNamingExclusionsCheckboxes exclusionsCheckboxes =
                new HouseholdNamingExclusionsCheckboxes(c);
        System.assertEquals(true, exclusionsCheckboxes.isExcludedFromName(),
                'The Household Naming Exclusions checkboxes should be synced with the' +
                        'Naming Exclusions string on Contact insert.');
    }

    @IsTest
    static void checkboxChangesOverwriteStringBeforeUpdate() {
        Id id = UTIL_UnitTestData_TEST.mockId(Contact.SObjectType);
        Contact c = new Contact(
                Id = id,
                LastName = 'test',
                Exclude_from_Household_Formal_Greeting__c = true
        );

        Contact oldContact = new Contact(
                Id = id,
                LastName = 'test',
                npo02__Naming_Exclusions__c = 'Household__c.Name'
        );

        Contacts contacts = new Contacts(new List<Contact>{
                c
        }, new List<Contact>{
                oldContact
        });
        contacts.onBeforeUpdate();

        HouseholdNamingExclusionsCheckboxes exclusionsCheckboxes =
                new HouseholdNamingExclusionsCheckboxes(c);
        System.assertEquals(true, exclusionsCheckboxes.isExcludedFromFormalGreeting());
        System.assertEquals(false, exclusionsCheckboxes.isExcludedFromName());

        HouseholdNamingExclusionsString exclusionsString =
                new HouseholdNamingExclusionsString(c);
        System.assertEquals(true, exclusionsString.isExcludedFromFormalGreeting(),
                'The Household Naming Exclusions string should be updated to match the' +
                        'Naming Exclusions checkboxes when they change on Contact update.');
        System.assertEquals(false, exclusionsString.isExcludedFromName(),
                'The Household Naming Exclusions string should be updated to match the' +
                        'Naming Exclusions checkboxes when they change on Contact update.');
    }

    @IsTest
    static void stringChangesOverwriteCheckboxesBeforeUpdate() {
        Id id = UTIL_UnitTestData_TEST.mockId(Contact.SObjectType);
        Contact c = new Contact(
                Id = id,
                LastName = 'test',
                npo02__Naming_Exclusions__c = 'Household__c.Name',
                Exclude_from_Household_Formal_Greeting__c = true
        );

        Contact oldContact = new Contact(
                Id = id,
                LastName = 'test',
                Exclude_from_Household_Formal_Greeting__c = true
        );
        Contacts contacts = new Contacts(new List<Contact>{
                c
        }, new List<Contact>{
                oldContact
        });
        contacts.onBeforeUpdate();

        HouseholdNamingExclusionsCheckboxes exclusionsCheckboxes =
                new HouseholdNamingExclusionsCheckboxes(c);
        System.assertEquals(true, exclusionsCheckboxes.isExcludedFromName(),
                'The Household Naming Exclusions checkboxes should be updated to match the' +
                        'Naming Exclusions string when it changes on Contact update.');
        System.assertEquals(false, exclusionsCheckboxes.isExcludedFromFormalGreeting(),
                'The Household Naming Exclusions checkboxes should be updated to match the' +
                        'Naming Exclusions string when it changes on Contact update.');
    }

    @IsTest
    static void prefersCheckboxesWhenBothStringAndCheckboxAreUpdated() {
        String assertMsg = 'The Household Naming Exclusions checkboxes should be ' +
                'honored when both the string and the checkboxes change.';

        Id id = UTIL_UnitTestData_TEST.mockId(Contact.SObjectType);
        Contact c = new Contact(
                Id = id,
                LastName = 'test',
                npo02__Naming_Exclusions__c = 'Household__c.Name',
                Exclude_from_Household_Informal_Greeting__c = true
        );

        Contact oldContact = new Contact(
                Id = id,
                LastName = 'test'
        );
        Contacts contacts = new Contacts(new List<Contact>{
                c
        }, new List<Contact>{
                oldContact
        });
        contacts.onBeforeUpdate();

        HouseholdNamingExclusionsCheckboxes exclusionsCheckboxes =
                new HouseholdNamingExclusionsCheckboxes(c);
        System.assertEquals(false, exclusionsCheckboxes.isExcludedFromName(),
                assertMsg);
        System.assertEquals(true, exclusionsCheckboxes.isExcludedFromInformalGreeting(),
                assertMsg);

        HouseholdNamingExclusionsString exclusionsString = new
                HouseholdNamingExclusionsString(c);
        System.assertEquals(false, exclusionsString.isExcludedFromName(),
                assertMsg);
        System.assertEquals(true, exclusionsString.isExcludedFromInformalGreeting(),
                assertMsg);
    }

    @IsTest
    static void prefersStringWhenBothStringAndCheckboxesAreInserted() {
        String assertMsg = 'The Household Naming Exclusions string should be ' +
                'honored when both the string and the checkboxes are populated on insert.';

        Contact c = new Contact(
                LastName = 'test',
                npo02__Naming_Exclusions__c =
                        'Household__c.Name;Household__c.Informal_Greeting__c',
                Exclude_from_Household_Formal_Greeting__c = true
        );

        Contacts contacts = new Contacts(new List<Contact>{
                c
        });
        contacts.onBeforeInsert();

        HouseholdNamingExclusionsCheckboxes exclusionsCheckboxes =
                new HouseholdNamingExclusionsCheckboxes(c);
        System.assertEquals(true, exclusionsCheckboxes.isExcludedFromName(),
                assertMsg);
        System.assertEquals(true, exclusionsCheckboxes.isExcludedFromInformalGreeting(),
                assertMsg);
        System.assertEquals(false, exclusionsCheckboxes.isExcludedFromFormalGreeting(),
                assertMsg);

        HouseholdNamingExclusionsString exclusionsString = new
                HouseholdNamingExclusionsString(c);
        System.assertEquals(true, exclusionsString.isExcludedFromName(),
                assertMsg);
        System.assertEquals(true, exclusionsString.isExcludedFromInformalGreeting(),
                assertMsg);
        System.assertEquals(false, exclusionsString.isExcludedFromFormalGreeting(),
                assertMsg);
    }
}