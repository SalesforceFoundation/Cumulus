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
* @description Household entity class in NPSP.
*/
public inherited sharing class NPSP_HouseholdAccount {

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

    private Account householdAccount;
    private Account oldVersion;

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

    public NPSP_HouseholdAccount(Account account) {
        this.householdAccount = account;
    }

    public NPSP_HouseholdAccount(Account account, Account oldVersion) {
        this.householdAccount = account;
        this.oldVersion = oldVersion;
    }

    public Id getId() {
        return householdAccount.Id;
    }

    public Account getRecord() {
        return householdAccount;
    }

    public void billingAddress(IAddress anAddress) {
        addressService.copyOntoSObject(
                anAddress, householdAccount, 'Billing',
                null);
    }

    public void setBillingAddressUndeliverableStatus(Boolean isUndeliverable) {
        householdAccount.Undeliverable_Address__c = isUndeliverable;
    }

    public Boolean undeliverableAddressStatus() {
        return householdAccount.Undeliverable_Address__c;
    }

    /*******************************************************************************************************
    * @description utility to compare two Accounts' (billing) addresses
    * @return boolean. true if there are any changes between the two accounts.
    ********************************************************************************************************/
    public Boolean isAccountAddressChanged() {
        if (householdAccount == null || oldVersion == null) {
            return false;
        }

        //Todo: convert to use isEqualTo
        Boolean isChanged =
                !addressService.equalsCaseSensitive(householdAccount.BillingStreet, oldVersion
                        .BillingStreet) ||
                        !addressService.equalsCaseSensitive(householdAccount.BillingCity,
                                oldVersion
                                .BillingCity) ||
                        !addressService.equalsCaseSensitive(householdAccount.BillingState,
                                oldVersion
                                .BillingState) ||
                        !addressService.equalsCaseSensitive(householdAccount
                                .BillingPostalCode, oldVersion
                                .BillingPostalCode) ||
                        !addressService.equalsCaseSensitive(householdAccount
                                .BillingCountry, oldVersion
                                .BillingCountry);

        if (!isChanged && orgConfig.isStateCountryPicklistsEnabled()) {
            isChanged =
                    !addressService.equalsCaseSensitive(String.valueOf(householdAccount.get
                            ('BillingStateCode')
                    ), String.valueOf(oldVersion.get('BillingStateCode'))) ||
                            !addressService.equalsCaseSensitive(String.valueOf
                                    (householdAccount.get
                                    ('BillingCountryCode')), String.valueOf(oldVersion.get
                                    ('BillingCountryCode')));
        }
        return isChanged;

    }

    //Todo: replace usages with isEqualTo
    public Boolean billingAddressIsDifferentFrom(IAddress anAddress) {
        return addressService.isSObjectAddressDifferent(householdAccount, anAddress);
    }

}