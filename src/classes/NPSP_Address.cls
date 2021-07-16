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
* @description Address entity class in NPSP.
*/
public inherited sharing class NPSP_Address implements IAddress {

    private Address__c addr;

    @TestVisible
    private OrgConfig orgConfig {
        get {
            if (orgConfig == null) {
                orgConfig = new OrgConfig();
            }
            return orgConfig;
        }
        set;
    }

    @TestVisible
    private AddressService addressService {
        get {
            if (addressService == null) {
                addressService = new AddressService();
            }
            return addressService;
        }
        set;
    }

    public NPSP_Address(Address__c address) {
        this.addr = address;
    }

    public NPSP_Address(Contact con) {
        this.addr = new Address__c();
        try {
            addr.Household_Account__c = con.AccountId;
        } catch (NullPointerException npe) {
            UTIL_Debug.debug('*** ##### npe on NPSP_Address doing nothing. ######');
        }
        if (con.getPopulatedFieldsAsMap().keySet().contains(
                String.valueOf(Contact.is_Address_Override__c)
        )) {
            addr.Default_Address__c = !con.is_Address_Override__c;
        }
        addr.Latest_Start_Date__c = System.today();
        addr.Latest_End_Date__c = null;
        if (con.getPopulatedFieldsAsMap().keySet().contains(
                String.valueOf(Contact.npe01__Primary_Address_Type__c)
        )) {
            copyFromSObject(con, 'Mailing', con.npe01__Primary_Address_Type__c);
        } else {
            copyFromSObject(con, 'Mailing', 'Mailing');
        }
    }

    public NPSP_Address(Account acc) {
        this.addr = new Address__c();
        addr.Household_Account__c = acc.Id;
        addr.Default_Address__c = true;
        addr.Latest_Start_Date__c = System.today();
        addr.Latest_End_Date__c = null;
        copyFromSObject(acc, 'Billing', null);
    }

    public NPSP_Address(npo02__Household__c household) {
        this.addr = new Address__c();
        addr.MailingStreet__c = household.npo02__MailingStreet__c;
        addr.MailingCity__c = household.npo02__MailingCity__c;
        addr.MailingState__c = household.npo02__MailingState__c;
        addr.MailingPostalCode__c = household.npo02__MailingPostalCode__c;
        addr.MailingCountry__c = household.npo02__MailingCountry__c;
    }

    public Boolean isSeasonal() {
        return (this.addr.Seasonal_Start_Month__c != null && this.addr.Seasonal_Start_Day__c != null &&
                this.addr.Seasonal_End_Month__c != null && this.addr.Seasonal_End_Day__c != null);
    }

    public Address__c getRecord() {
        return this.addr;
    }

    public String householdId() {
        return this.addr.Household_Account__c;
    }

    public Boolean isAddressMatchFuzzyWith(NPSP_Address other) {
        Address__c otherAddress = other.getRecord();

        if (addr == null || otherAddress == null) {
            return false;
        }

        Integer cChange = 0;
        if (strCleanup(addr.MailingStreet__c) != strCleanup(otherAddress.MailingStreet__c)
                && otherAddress.MailingStreet__c != null) {
            cChange++;
        }
        if (strCleanup(addr.MailingStreet2__c) != strCleanup(otherAddress.MailingStreet2__c)
                && otherAddress.MailingStreet2__c != null) {
            cChange++;
        }
        if (strCleanup(addr.MailingCity__c) != strCleanup(otherAddress.MailingCity__c)
                && otherAddress.MailingCity__c != null) {
            cChange++;
        }
        if (strCleanup(addr.MailingState__c) != strCleanup(otherAddress.MailingState__c)
                && otherAddress.MailingState__c != null) {
            cChange++;
        }
        if (strCleanup(addr.MailingPostalCode__c) != strCleanup(otherAddress.MailingPostalCode__c)
                && otherAddress.MailingPostalCode__c != null) {
            cChange++;
        }
        if (strCleanup(addr.MailingCountry__c) != strCleanup(otherAddress.MailingCountry__c)
                && otherAddress.MailingCountry__c != null) {
            cChange++;
        }
        if (addr.Address_Type__c != null
                && strCleanup(addr.Address_Type__c) != strCleanup(otherAddress.Address_Type__c)
                && otherAddress.Address_Type__c != null) {
            cChange++;
        }
        return cChange <= 1;
    }

    public String getAddrKey() {
        String strKey =
                strCleanup(addr.MailingStreet__c) +
                        strCleanup(addr.MailingStreet2__c) +
                        strCleanup(addr.MailingCity__c) +
                        strCleanup(addr.MailingState__c) +
                        strCleanup(addr.MailingPostalCode__c) +
                        strCleanup(addr.MailingCountry__c) +
                        strCleanup(addr.Address_Type__c) +
                        (addr.Seasonal_Start_Day__c != null ? addr.Seasonal_Start_Day__c : '') +
                        (addr.Seasonal_Start_Month__c != null ? addr.Seasonal_Start_Month__c : '') +
                        (addr.Seasonal_End_Day__c != null ? addr.Seasonal_End_Day__c : '') +
                        (addr.Seasonal_End_Month__c != null ? addr.Seasonal_End_Month__c : '');
        return strKey;
    }

    /*******************************************************************************************************
    * @description utility to remove all whitespace and to lowercase the string
    * @param str the string to clean up
    * @return string
    */
    private static String strCleanup(String str) {
        if (str != null) {
            str = str.replace(' ', '');
            str = str.toLowerCase();
        } else {
            str = '';
        }
        return str;
    }

    public Boolean overlapsWith(NPSP_Address other) {
        if (other == null) {
            return false;
        }
        if (!isSeasonal() || !other.isSeasonal()) {
            return false;
        }

        // we don't need to know what year or month we are currently in, but
        // we need to take into account days (since we could be in the same month).
        // to make this easy to compare, we convert month & day to be a decimal of month.day.
        // eg., 3.01 for Feb 1st and 3.28 for Feb 28th.
        Decimal start1 = decimalOfMonthDay(startMonth(), startDay());
        Decimal end1 = decimalOfMonthDay(endMonth(), endDay());
        Decimal start2 = decimalOfMonthDay(other.startMonth(), other.startDay());
        Decimal end2 = decimalOfMonthDay(other.endMonth(), other.endDay());

        // now we see if the ranges are increasing (Jan '14 - March '14), or decreasing (Nov 14' - Feb '15),
        Boolean range1Increases = start1 < end1;
        Boolean range2Increases = start2 < end2;

        // we can now tell if there is overlap simply by looking at three scenarios:
        // 1. both ranges increase, make sure start1 not in range2, and start2 not in range1.
        if (range1Increases && range2Increases) {
            return (start1 >= start2 && start1 <= end2) || (start2 >= start1 && start2 <= end1);
        }
        // 2. one range increases, one range decreases, make sure end1 not in range2, and end2 not in range1.
        else if (range1Increases != range2Increases) {
            return (end1 >= start2 && end1 <= end2) || (end2 >= start1 && end2 <= end1);
        }
        // 3. both ranges decrease, always implies an overlap of the new year!
        else {
            return true;
        }

    }

    public String endDay() {
        return addr.Seasonal_End_Day__c;
    }

    public String endMonth() {
        return addr.Seasonal_End_Month__c;
    }

    public String startDay() {
        return addr.Seasonal_Start_Day__c;
    }

    public String startMonth() {
        return addr.Seasonal_Start_Month__c;
    }

    public Boolean isEqualToIncludingAddressType(IAddress other, Boolean includeAddressType) {
        if (addr == null || other == null) {
            return false;
        }
        if (includeAddressType) {
            if (!addressService.equalsCaseSensitive(getType(), other.getType())) {
                return false;
            }
        }
        return isEqualTo(other);
    }

    private Boolean isEqualTo(IAddress other) {
        return (addressService.equalsCaseSensitive(street(), other.street()) &&
                addressService.equalsCaseSensitive(street2(), other.street2()) &&
                addressService.equalsCaseSensitive(city(), other.city()) &&
                addressService.equalsCaseSensitive(state(), other.state()) &&
                addressService.equalsCaseSensitive(postalCode(), other.postalCode()) &&
                addressService.equalsCaseSensitive(country(), other.country())
        );
    }

    public Boolean isDifferentIncludingLatLong(IAddress other) {
        Boolean isDifferent = (
                        !isEqualToIncludingAddressType(other, false) ||
                        latitude() != other.latitude() ||
                        longitude() != other.longitude()
        );
        return isDifferent;
    }

    /*******************************************************************************************************
    * @description Utility to copy Address fields between two Address objects.
    * @param addrSrc the source Address
    * @param addrDst the destination Address
    * @return void
    */
    public void copyFrom(IAddress other) {
        addr.MailingStreet__c = other.street();
        addr.MailingStreet2__c = other.street2();
        addr.MailingCity__c = other.city();
        addr.MailingState__c = other.state();
        addr.MailingPostalCode__c = other.postalCode();
        addr.MailingCountry__c = other.country();
        addr.Geolocation__Latitude__s = other.latitude();
        addr.Geolocation__Longitude__s = other.longitude();
        if (other.getType() != null) {
            addr.Address_Type__c = other.getType();
        }
    }

    public Boolean isDefault() {
        return addr.Default_Address__c;
    }

    public void setAsDefault() {
        addr.Default_Address__c = true;
    }

    public String getType() {
        return addr.Address_Type__c;
    }

    /*******************************************************************************************************
    * @description utility to copy Address fields from a Contact or Account to an Address object.
    * Handles instances where State and Country picklists are enabled, and multiline street addresses.
    * @param sobjSrc the source Contact or Account
    * @param fieldPrefixSrc the address fields to copy from, ie., Mailing, Other, Shipping, Billing
    * @param addr the Address object to copy to
    * @param addrType if not null, copy to address.Address_Type__c
    * @return void
    */
    public void copyFromSObject(SObject sobjSrc, String fieldPrefixSrc, String addrType) {
        addr.MailingStreet__c = (String) getSObjectField(sobjSrc, fieldPrefixSrc, 'Street');
        Addresses.handleMultilineStreet(addr);
        addr.MailingCity__c = (String) getSObjectField(sobjSrc, fieldPrefixSrc, 'City');
        addr.MailingPostalCode__c = (String) getSObjectField(sobjSrc, fieldPrefixSrc, 'PostalCode');
        addr.MailingState__c = (String) getSObjectField(sobjSrc, fieldPrefixSrc, 'State');
        addr.MailingCountry__c = (String) getSObjectField(sobjSrc, fieldPrefixSrc, 'Country');
        addr.Geolocation__Latitude__s = (Decimal) getSObjectField(sobjSrc, fieldPrefixSrc, 'Latitude');
        addr.Geolocation__Longitude__s = (Decimal) getSObjectField(sobjSrc, fieldPrefixSrc, 'Longitude');

        if (orgConfig.isStateCountryPicklistsEnabled()) {
            populateAddressCountryFromCountryCode(sobjSrc, fieldPrefixSrc);
            populateAddressStateFromStateCode(sobjSrc, fieldPrefixSrc);
        }

        // if specified, also include Address Type
        if (addrType != null) {
            addr.Address_Type__c = addrType;
        } else {
            // A null value will force a newly created Address record to use its defined default value for
            // the picklist, which if not reflected here could cause isAddressChanged() to return true
            // in cases when it should not.
            addr.Address_Type__c = Addresses.defaultAddressType;
        }
    }

    private Object getSObjectField(SObject sobjSrc, String fieldPrefixSrc, String field) {
        Object val;
        try {
            val = sobjSrc.get(fieldPrefixSrc + field);
        } catch (Exception e) {
            val = null;
        }
        return val;
    }

    public void checkForPartialSeasonalErrors() {
        if (isPartialSeasonalAddr()) {
            this.addr.addError(Label.addrSeasonalPartial);
        }
    }

    /*******************************************************************************************************
    * @description utility to see if the address has only a subset of its seasonal fields set
    * @param addr the Address to look at
    * @return boolean
    */
    private Boolean isPartialSeasonalAddr() {
        Integer cParts = 0;
        if (addr.Seasonal_Start_Month__c != null) cParts++;
        if (addr.Seasonal_Start_Day__c != null) cParts++;
        if (addr.Seasonal_End_Month__c != null) cParts++;
        if (addr.Seasonal_End_Day__c != null) cParts++;
        return (cParts > 0 && cParts < 4);
    }

    /*******************************************************************************************************
    * @description utility to create the month and day strings to a decimal we can use in comparisons.
    * @param m the month ordinal as a string
    * @param d the day ordinal as a string
    * @return decimal
    */
    private static Decimal decimalOfMonthDay(String m, String d) {
        if (Integer.valueOf(d) < 10)
            return Decimal.valueOf(m + '.0' + d); else
                return Decimal.valueOf(m + '.' + d);
    }

    /*******************************************************************************************************
    * @description Updates the Address record's MailingCountry field when it is empty
    *              with the Account's BillingCountryCode or Contact's MailingCountryCode value.
    * @param sobjSrc the source Account or Contact
    * @param fieldPrefixSrc the address field to copy from, ie., Mailing, Other, Billing, Shipping
    * @param addr the Address object to update accordingly
    * @return void
    */
    @TestVisible
    private void populateAddressCountryFromCountryCode(SObject sobjSrc, String fieldPrefixSrc) {
        String countryCode = (String) sobjSrc.get(fieldPrefixSrc + 'CountryCode');
        if (String.isBlank(countryCode)) {
            return;
        }

        if (String.isEmpty(addr.MailingCountry__c)) {
            addr.MailingCountry__c = orgConfig.validCountriesByCode().get(countryCode
                    .toUpperCase());
        }
    }

    /*******************************************************************************************************
    * @description Updates the Address record's MailingState field when it is empty
    *              or does not match the Account's BillingStateCode or Contact's MailingStateCode value.
    * @param sobjSrc the source Account or Contact
    * @param fieldPrefixSrc the address field to copy from, ie., Mailing, Other, Billing, Shipping
    * @return void
    */
    @TestVisible
    private void populateAddressStateFromStateCode(SObject sobjSrc, String fieldPrefixSrc) {
        String stateCode = (String) sobjSrc.get(fieldPrefixSrc + 'StateCode');
        if (String.isBlank(stateCode)) {
            return;
        }

        if (String.isEmpty(addr.MailingState__c) || !isMatchingStateCode(stateCode)) {

            // Assume it's a valid statecode
            addr.MailingState__c = stateCode;
        }
    }

    /*******************************************************************************************************
    * @description Determines if the Account's BillingStateCode or Contact's MailingStateCode matches the
    *              Address record's Mailing State.
    * @param stateCode the BillingStateCode or MailingStateCode
    * @return void
    */
    @TestVisible
    private Boolean isMatchingStateCode(String stateCode) {
        if (String.isBlank(addr.MailingState__c)) {
            return false;
        }

        String mappedMailingState = (orgConfig.validStatesByLabel() == null)
                ? ''
                : orgConfig.validStatesByLabel().get(addr.MailingState__c.toUpperCase());

        return stateCode.equalsIgnoreCase(mappedMailingState);
    }

    /*******************************************************************************************************
    * @description utility to see if the address has seasonal fields set
    * @param addr the Address to look at
    * @return boolean
    */
    public Boolean isSeasonalAddr() {
        return (addr.Seasonal_Start_Month__c != null && addr.Seasonal_Start_Day__c != null &&
                addr.Seasonal_End_Month__c != null && addr.Seasonal_End_Day__c != null);
    }

    public void state(String state) {
        addr.MailingState__c = state;
    }

    public String street() {
        return addr.MailingStreet__c;
    }

    public String street2() {
        return addr.MailingStreet2__c;
    }

    public String city() {
        return addr.MailingCity__c;
    }

    public String state() {
        return addr.MailingState__c;
    }

    public String postalCode() {
        return addr.MailingPostalCode__c;
    }

    public String country() {
        return addr.MailingCountry__c;
    }

    public Decimal longitude() {
        return addr.Geolocation__Longitude__s;
    }

    public Decimal latitude() {
        return addr.Geolocation__Latitude__s;
    }

    public Boolean isUndeliverable() {
        return addr.Undeliverable__c;
    }

    /*******************************************************************************************************
    * @description utility to combine mailing street fields into a single string with embedded CR LF
    * @param addr the Address to look at
    * @return boolean
    */
    public String multilineStreet() {
        Boolean isOneLineStreetAddress = String.isBlank(addr.MailingStreet2__c);
        if (isOneLineStreetAddress) {
            return addr.MailingStreet__c;
        }
        return addr.MailingStreet__c + '\r\n' + addr.MailingStreet2__c;
    }

}