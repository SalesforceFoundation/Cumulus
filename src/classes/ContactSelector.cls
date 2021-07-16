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
* @description Selector class for Contacts in NPSP.
*/
public inherited sharing class ContactSelector {

    @TestVisible
    private static OrgConfig orgConfig {
        get {
            if (orgConfig == null) {
                orgConfig = new OrgConfig();
            }
            return orgConfig;
        }
        set;
    }

    /*******************************************************************************************************
    * @description Returns Contacts for specified Accounts or Households.
    * Private Contacts or records not belonging to the specified Accounts/Households are not selected.
    * @param householdOrAccountIds The list of Household Id's (either Household__c or Account Id's)
    * @return List<Contact>
    */
    public List<Contact> householdMembersFor(List<Id> householdOrAccountIds) {
        Set<Id> queryHHIds = householdOrAccountIds == null ? new Set<Id>() : new Set<Id>(householdOrAccountIds);
        queryHHIds.remove(null);

        if (queryHHIds.isEmpty()) {
            return new List<Contact>();
        }

        return Database.Query(householdMembersQueryFor(queryHHIds));
    }

    private String householdMembersQueryFor(Set<Id> queryHHIds) {
        //get all of the contacts and their associated households
        //return them in the order of household and then household naming order
        //we use dynamic soql so we can include all contact fields, since custom naming may refer to any field.
        String strSoql = getQueryForContactNamingFields();
        String strHHId = UTIL_Namespace.StrTokenNSPrefix('HHId__c');
        strSoql += ' WHERE AccountId IN :queryHHIds OR npo02__Household__c IN :queryHHIds ' +
                ' ORDER BY ' + strHHId + ', npo02__Household_Naming_Order__c ASC NULLS LAST, Primary_Contact__c DESC, CreatedDate ';
        return strSoql;
    }

    /*******************************************************************************************************
    * @description the soql select String to use which includes any fields we use or are referred to in
    * any of the naming specifications.
    */
    private String queryForContactNamingFields;
    @TestVisible
    private String getQueryForContactNamingFields() {
        if (queryForContactNamingFields == null) {
            //we use dynamic soql so we can include all contact fields, since custom naming may refer to any field.
            String[] selectFields = new String[]{
                    'Id', 'HHId__c', 'npo02__Naming_Exclusions__c'
            };
            selectFields.addAll(
                    new HouseholdNamingService()
                            .getHouseholdNamingContactFields());

            queryForContactNamingFields = new UTIL_Query()
                    .withSelectFields(selectFields)
                    .withToLabelSalutation()
                    .withFrom('Contact')
                    .build();
        }
        return queryForContactNamingFields;
    }

    public static List<Contact> getContactAddressFieldsForContactsIn(Set<Id> householdAccountIds) {
        return Database.query(contactAddressFieldsSOQL(householdAccountIds));
    }

    private static String householdAccountType = CAO_Constants.HH_ACCOUNT_TYPE;
    private static String contactAddressFieldsSOQL(Set<Id> householdAccountIds) {
        List<String> selectFields = contactAddressFields();

        return new UTIL_Query()
                .withSelectFields(selectFields)
                .withFrom(String.valueOf(Contact.SObjectType))
                .withWhere('Account.npe01__SYSTEM_AccountType__c = :householdAccountType')
                .withWhere('AccountId != Null')
                .withWhere('AccountId IN :householdAccountIds')
                .build();
    }

    private static List<String> contactAddressFields() {
        List<String> selectFields = new List<String>{
                'Id', 'is_Address_Override__c',
                'Current_Address__c', 'AccountId',
                'MailingStreet', 'MailingCity', 'MailingState',
                'MailingPostalCode', 'MailingCountry', 'MailingLatitude',
                'MailingLongitude',
                'npe01__Primary_Address_Type__c',
                'Undeliverable_Address__c',
                'LastName'
        };

        if (orgConfig.isStateCountryPicklistsEnabled()) {
            selectFields.add('MailingCountryCode');
            selectFields.add('MailingStateCode');
            selectFields.add('OtherCountryCode');
            selectFields.add('OtherStateCode');
        }
        return selectFields;
    }

}