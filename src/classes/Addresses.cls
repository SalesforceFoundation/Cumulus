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
* @description Domain class for Addresses in NPSP.
*/
public inherited sharing class Addresses extends fflib_SObjects {

    private Map<Id, Address__c> oldMap;

    @TestVisible
    private TDTM_Runnable.DmlWrapper dmlWrapperLocal {
        get {
            if (dmlWrapperLocal == null) {
                dmlWrapperLocal = new TDTM_Runnable.DmlWrapper();
            }
            return dmlWrapperLocal;
        }
        set;
    }

    @TestVisible
    private ContactSelector contactSelector {
        get {
            if (contactSelector == null) {
                contactSelector = new ContactSelector();
            }
            return contactSelector;
        }
        set;
    }

    public Addresses(List<Address__c> addresses) {
        super(addresses, Address__c.SObjectType);
    }

    public Addresses(List<Address__c> addresses, List<Address__c> oldList) {
        super(addresses, Address__c.SObjectType);
        this.oldMap = oldList == NULL ?
                new Map<Id, Address__c>() :
                new Map<Id, Address__c>(oldList);
    }

    public void onBeforeInsert() {
        setLatestDatesOnDefaults();
        verifyAddrHHAccOnly();
        verifyAddrSeasonalNoOverlap();
    }

    public void onAfterInsert() {
        refreshCurrentHHAddress(addressesByAccountId(), dmlWrapperLocal, false);

        // we must process dmlWrapperLocal ourselves, so we can extract out the appropriate
        // errors
        // that might occur updating contacts and accounts, and associating those errors with
        // the correct addresses.
        ERR_Handler.Errors errors = TDTM_TriggerHandler.processDMLAllOrNothing
                (dmlWrapperLocal, false);
        if (errors.errorsExist) {
            putErrorsOnAddresses(errors, addressesByAccountId(), new Map<Id, Address__c>());
        }

        // hack to detect empty addresses and delete them after we've propagated the change to all contacts and account
        deleteEmptyAddresses();
    }

    public void onBeforeUpdate() {
        updateLatestDatesForDefaultChanges();
        verifyAddrHHAccOnly();
        verifyAddrSeasonalNoOverlap();
    }

    public void onAfterUpdate() {
        if (addressChangesToSync().size() > 0) {
            refreshCurrentHHAddress(addressChangesToSync(), dmlWrapperLocal, false);
        }

        if (nonDefaultsWithChanges().size() > 0) {
            updateAddrOverrides(nonDefaultsWithChanges(), dmlWrapperLocal);
        }

        // we must process dmlWrapper ourselves, so we can extract out the appropriate errors
        // that might occur updating contacts and accounts, and associating those errors with
        // the correct addresses.
        ERR_Handler.Errors errors =
                TDTM_TriggerHandler.processDMLAllOrNothing(
                        dmlWrapperLocal, false);
        if (errors.errorsExist) {
            putErrorsOnAddresses(errors, addressChangesToSync(), nonDefaultsWithChanges());
        }
    }

    public void onAfterDelete() {
        Map<Id, Address__c> addressesByAccountId = addressesByAccountId();
        if (!addressesByAccountId.isEmpty()) {
            clearAddressesForEachAccount(addressesByAccountId);
            refreshCurrentHHAddress(addressesByAccountId, dmlWrapperLocal,
                    false);
        }

        // we must process dmlWrapperLocal ourselves, so we can extract out the appropriate errors
        // that might occur updating contacts and accounts, and associating those errors with
        // the correct addresses.
        ERR_Handler.Errors errors = TDTM_TriggerHandler.processDMLAllOrNothing(dmlWrapperLocal,
                false);
        if (errors.errorsExist) {
            putErrorsOnAddresses(errors, addressesByAccountId(), new Map<Id, Address__c>());
        }
    }

    private void clearAddressesForEachAccount(Map<Id, Address__c> addressesByAccountId) {
        for (Id accountId : addressesByAccountId.keySet()) {
            addressesByAccountId.put(accountId, null);
        }
    }

    /********************************************************************************************************
    * @description Retreive the defined default address type picklist value to use when creating a new
    * Address record.
    */
    public static String defaultAddressType {
        get {
            if (defaultAddressType == null) {
                for (Schema.PicklistEntry pv: Address__c.Address_Type__c.getDescribe().getPicklistValues()) {
                    if (pv.isDefaultValue()) {
                        defaultAddressType = pv.getValue();
                        break;
                    }
                }
            }
            return defaultAddressType;
        } private set;
    }


    /*******************************************************************************************************
    * @description The main routine for finding the appropriate address to currently use for the
    * household and its contacts.  Prioritizes the Optional mapped Address as the Default
    * address, as well as checking to see if there is a seasonal address that should be used instead.
    * @param mapAccIdAddr a map of Account Id to the Account's default Address.
    * @param dmlWrapper to hold the objects that get updated
    * @param isCalcHHInfoOnly if set, then this routine will return the map of HHId to HHInfo,
    * and not do any changes to dmlWrapper.
    * @return map<Id, HHInfo> a map of Account Id to the HHInfo object for the account
    ********************************************************************************************************/
    public static Map<Id, HHInfo> refreshCurrentHHAddress(Map<Id, Address__c> mapAccIdAddr,
            TDTM_Runnable.DmlWrapper dmlWrapper, Boolean isCalcHHInfoOnly) {

        // assumptions:
        // called after all modifications saved to db
        // so either from a scheduled job,
        // or in the Address AfterUpdate trigger, AFTER any related objects updated
        //
        // strategy:
        // for each hh, get all its addresses (query)
        // for each hh, find all its contacts (query)
        // for each hh, find its current seasonal or default address (loop calculation)
        // for each hh, update its billing fields with seasonal current/default
        // for each hh addr, clear its Default field if it isn't default
        // for each hh contact, if no override, update mailing fields with seasonal current/default
        //

        // get all Addresses by HH, that might need updating
        List<Id> listAccId = new List<Id>(mapAccIdAddr.keySet());
        Map<Id, List<Address__c>> mapAccIdListAddrHH = getMapAccIdListAddrHH(listAccId);

        // for each hh, find the current address to use (seasonal vs default)
        Map<Id, HHInfo> mapAccIdHHInfo = new Map<Id, HHInfo>();
        for (Id accId : listAccId) {
            // create a HHInfo for each household
            HHInfo hhinfo = new HHInfo();
            hhinfo.accId = accId;
            mapAccIdHHInfo.put(accId, hhinfo);

            // if there is a provided Default address, use it over all other defaults.
            Address__c addr = mapAccIdAddr.get(accId);
            if (addr != null && addr.Default_Address__c) {
                hhinfo.addrDefault = addr;
            }

            // go through the hh addresses storing the default and any seasonal
            if (mapAccIdListAddrHH.get(accId) != null) {
                for (Address__c addrHH : mapAccIdListAddrHH.get(accId)) {
                    NPSP_Address npspAddressHH = new NPSP_Address(addrHH);

                    if (hhinfo.addrDefault == null && addrHH.Default_Address__c) {
                        hhinfo.addrDefault = addrHH;
                    }
                    if (npspAddressHH.isSeasonalAddr()) {
                        Date dtStart = dtStartOrEndOfAddrSeasonal(addrHH, true);
                        Date dtEnd = dtStartOrEndOfAddrSeasonal(addrHH, false);
                        Date dtToday = System.today();
                        if (dtToday >= dtStart && dtToday < dtEnd) {
                            hhinfo.addrSeasonal = addrHH;
                        }
                    }
                }
            }

            // finally, if no default found, create an empty default
            if (hhinfo.addrDefault == null) {
                Address__c addrEmpty = new Address__c();
                addrEmpty.Household_Account__c = accId;
                hhinfo.addrDefault = addrEmpty;
            }
        }

        // some callers just need the HHInfo for each HH Account.
        if (isCalcHHInfoOnly) {
            return mapAccIdHHInfo;
        }

        // get all Contacts by HH, that might need updating
        // note that if we have an organizational account, our query will not pick up any contacts (by design!)
        Map<Id, List<Contact>> mapAccIdListCon = new Map<Id, List<Contact>>();
        Map<Id, Account> accountsById = getAccountsByIds(mapAccIdAddr.keySet());
        Set<Id> setHHId =  mapAccIdAddr.keySet();

        for (Contact con : contactSelector.getContactAddressFieldsForContactsIn(setHHId)) {
            List<Contact> listConHH = mapAccIdListCon.get(con.AccountId);
            if (listConHH == null) {
                listConHH = new List<Contact>();
                mapAccIdListCon.put(con.AccountId, listConHH);
            }
            listConHH.add(con);
        }

        // lists of objects to update
        List<Account> listAccUpdate = new List<Account>();
        List<Address__c> listAddrUpdate = new List<Address__c>();
        List<Contact> listConUpdate = new List<Contact>();

        // now go through each HH, and do all the work!
        for (Id accId : listAccId) {

            // pick the address to use
            HHInfo hhinfo = mapAccIdHHInfo.get(accId);
            Address__c addrDefault = hhinfo.addrDefault;
            Address__c addr = hhinfo.addrSeasonal;
            if (addr == null) {
                addr = addrDefault;
            }

            // update HH Account's Billing address fields
            NPSP_Address npspAddress = new NPSP_Address(addr);

            NPSP_HouseholdAccount npspHouseholdAccount = new NPSP_HouseholdAccount(accountsById.get(accId));

            if (npspHouseholdAccount.billingAddressIsDifferentFrom(npspAddress) ||
                npspHouseholdAccount.undeliverableAddressStatus() != npspAddress.isUndeliverable()) {

                npspHouseholdAccount.billingAddress(npspAddress);
                npspHouseholdAccount.setBillingAddressUndeliverableStatus(npspAddress.isUndeliverable());

                listAccUpdate.add(npspHouseholdAccount.getRecord());
            }

            // check other addresses on this household that are no longer the default
            if (mapAccIdListAddrHH != null && mapAccIdListAddrHH.size() > 0 && mapAccIdListAddrHH.get(accId) != null) {
                for (Address__c addrHH : mapAccIdListAddrHH.get(accId)) {
                    if (addrHH.Id == addrDefault.Id) {
                        continue;
                    }
                    if (addrHH.Default_Address__c) {
                        addrHH.Default_Address__c = false;
                        addrHH.Latest_End_Date__c = System.today();
                        listAddrUpdate.add(addrHH);
                    }
                }
            }

            // check the Contacts on this household
            if (mapAccIdListCon != null && mapAccIdListCon.containsKey(accId)) {
                for (Contact con : mapAccIdListCon.get(accId)) {
                    NPSP_Contact npspContact = new NPSP_Contact(con);
                    // detect that the contact's current address was deleted.
                    // and if so clear any override flag so it will get the default address.
                    if (npspContact.currentAddress() == null) {
                        npspContact.getRecord().is_Address_Override__c = false;
                    }
                    if (npspContact.hasAddressOverride() == false) {
                        npspContact.getRecord().Undeliverable_Address__c =
                                npspHouseholdAccount.getRecord().Undeliverable_Address__c;
                    }
                    if (npspContact.hasAddressOverride() == false ||
                            npspContact.currentAddress() == addr.Id) {
                        if (npspContact.mailingAddressIsDifferentFrom(npspAddress)) {
                            npspContact.currentAddress(npspAddress);
                        }
                    }
                    listConUpdate.add(con);
                }
            }
        }

        if (listAccUpdate.size() > 0) {
            dmlWrapper.objectsToUpdate.addAll((List<SObject>)listAccUpdate);
        }
        if (listAddrUpdate.size() > 0) {
            dmlWrapper.objectsToUpdate.addAll((List<SObject>)listAddrUpdate);
        }
        if (listConUpdate.size() > 0) {
            dmlWrapper.objectsToUpdate.addAll((List<SObject>)listConUpdate);
        }

        return mapAccIdHHInfo;
    }

    /*******************************************************************************************************
    * @description helper class to keep track of the default and seasonal address for a household
    */
    public class HHInfo {
        public Id accId;
        public Address__c addrDefault;
        public Address__c addrSeasonal;
    }

    /*******************************************************************************************************
    * @description utility to create a map of HH Account Id to a list of Addresses in that HH, given a list of HH Account Id.
    * @param acctIds the list of Account Id's
    * @return map<Id, list<Address__c>> map that contains the Addresses for each HH Account Id
    */
    public static Map<Id, List<Address__c>> getMapAccIdListAddrHH(List<Id> acctIds) {
        Map<Id, List<Address__c>> mapAccIdListAddrHH = new Map<Id, List<Address__c>>();
        List<Address__c> listAddrOther = [
                SELECT Id, Default_Address__c, Household_Account__c, Address_Type__c,
                        MailingStreet__c, MailingStreet2__c, MailingCity__c, MailingState__c,
                        MailingPostalCode__c, MailingCountry__c,
                        Seasonal_Start_Month__c, Seasonal_Start_Day__c, Seasonal_End_Month__c,
                        Seasonal_End_Day__c, Geolocation__Latitude__s, Geolocation__Longitude__s, Undeliverable__c
                FROM Address__c
                WHERE Household_Account__c IN :acctIds
                ORDER BY Default_Address__c DESC, LastModifiedDate ASC
        ]; // ordering needed by cleanupAccountAddresses().
        for (Address__c addr : listAddrOther) {
            List<Address__c> listAddrHH = mapAccIdListAddrHH.get(addr.Household_Account__c);
            if (listAddrHH == null) {
                listAddrHH = new List<Address__c>();
                mapAccIdListAddrHH.put(addr.Household_Account__c, listAddrHH);
            }
            listAddrHH.add(addr);
        }
        return mapAccIdListAddrHH;
    }

    /*******************************************************************************************************
    * @description verify that the account for each Address is a HH account or an Organizational account if enabled.
    * Adds an Error to each Address object that has an illegal account.
    */
    public void verifyAddrHHAccOnly() {
        Set<Id> setAccId = new Set<Id>();
        for (Address__c addr : (List<Address__c>) getRecords()) {
            if (addr.Household_Account__c != null) {
                setAccId.add(addr.Household_Account__c);
            }
        }
        Map<Id, Account> mapAccIdAcc = new Map<Id, Account>([
                select Id, npe01__SYSTEM_AccountType__c, npe01__SYSTEMIsIndividual__c
                from Account
                where Id in :setAccId
        ]);
        for (Address__c addr : (List<Address__c>) getRecords()) {
            if (addr.Household_Account__c == null) {
                // with TDTM, have to use addError, not throw an exception, or the error will just get logged but not passed to Salesforce to stop its DML.
                addr.addError(Label.addrHHAccountOnly);
            } else {
                Account acc = mapAccIdAcc.get(addr.Household_Account__c);
                if ((acc.npe01__SYSTEM_AccountType__c != CAO_Constants.HH_ACCOUNT_TYPE) &&
                        (acc.npe01__SYSTEMIsIndividual__c || !UTIL_CustomSettingsFacade.getContactsSettings().Organizational_Account_Addresses_Enabled__c)) {
                    // with TDTM, have to use addError, not throw an exception, or the error will just get logged but not passed to Salesforce to stop its DML.
                    addr.addError(Label.addrHHAccountOnly);
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description verify that any seasonal addresses don't overlap
    * Adds an Error to each Address object that has an illegal seasonal fields
    */
    public void verifyAddrSeasonalNoOverlap() {

        // first get just the seasonal addresses
        List<NPSP_Address> seasonalAddresses = seasonalAddresses();

        addErrorsToPartialSeasonalAddresses();

        // if none are seasonal, we can bail out
        if (seasonalAddresses.size() == 0) {
            return;
        }

        // protect against overlaps within the set being inserted or updated
        checkForOverlaps(seasonalAddresses);

        // now check for overlaps within each household's saved addresses
        checkForOverlapsAgainstHouseholdAddresses(seasonalAddresses);
    }

    private void addErrorsToPartialSeasonalAddresses() {
        for (Address__c addr : (List<Address__c>) getRecords()) {
            NPSP_Address npspAddress = new NPSP_Address(addr);
            npspAddress.checkForPartialSeasonalErrors();
        }
    }

    private void checkForOverlaps(List<NPSP_Address> seasonalAddresses) {
        for (NPSP_Address addr : seasonalAddresses) {
            for (NPSP_Address addr2 : seasonalAddresses) {
                if (addr.getRecord() == addr2.getRecord()) {
                    continue;
                }
                if (addr.householdId() != addr2.householdId()) {
                    continue;
                }
                if (addr.overlapsWith(addr2)) {
                    addr.getRecord().addError(Label.addrSeasonalOverlap);
                }
            }
        }
    }

    private void checkForOverlapsAgainstHouseholdAddresses(List<NPSP_Address> seasonalAddresses) {
        List<Id> listAccId = new List<Id>();
        for (NPSP_Address addr : seasonalAddresses) {
            listAccId.add(addr.householdId());
        }
        Map<Id, List<Address__c>> mapAccIdListAddrHH = Addresses.getMapAccIdListAddrHH
                (listAccId);

        for (NPSP_Address addr : seasonalAddresses) {
            List<Address__c> existingHouseholdAddresses = mapAccIdListAddrHH.get(addr.householdId());
            if (existingHouseholdAddresses == null || existingHouseholdAddresses.isEmpty()) {
                continue;
            }
            for (Address__c addr2 : existingHouseholdAddresses) {
                NPSP_Address npspAddress2 = new NPSP_Address(addr2);
                if (addr.getRecord().Id == addr2.Id) {
                    continue;
                }
                if (addr.overlapsWith(npspAddress2)) {
                    addr.getRecord().addError(Label.addrSeasonalOverlap);
                    break;
                }
            }
        }
    }

    private List<NPSP_Address> seasonalAddresses() {
        List<NPSP_Address> listAddrS = new List<NPSP_Address>();
        for (Address__c addr : (List<Address__c>) getRecords()) {
            NPSP_Address npspAddress = new NPSP_Address(addr);
            if (npspAddress.isSeasonal()) {
                listAddrS.add(npspAddress);
            }
        }
        return listAddrS;
    }

    public Map<Id, Address__c> addressChangesToSync() {
        Map<Id, Address__c> defaultAndSeasonalWithChanges = new Map<Id, Address__c>();
        Integer i = 0;
        for (Address__c addr : (List<Address__c>) getRecords()) {
            NPSP_Address npspAddress = new NPSP_Address(addr);
            Address__c addrOld = oldVersionOf(addr);
            NPSP_Address npspAddressOld = new NPSP_Address(addrOld);
            // an address that is marked default needs to propagate to the household
            if (isNewDefault(addr, addrOld) ||
                isSeasonalChanged(addr, addrOld) ||
                (isUndeliverableStatusChanged(addr, addrOld)) && isDefault(addr)) {

                defaultAndSeasonalWithChanges.put(householdAccountIdFor(addr), addr);
            } else if (!npspAddress.isEqualToIncludingAddressType(npspAddressOld, TRUE)) {
                if (isDefault(addr)) {
                    defaultAndSeasonalWithChanges.put(householdAccountIdFor(addr), addr);
                }
            }
            i++;
        }
        return defaultAndSeasonalWithChanges;
    }

    private Boolean isUndeliverableStatusChanged(Address__c addr, Address__c addrOld) {
        return addr.Undeliverable__c != addrOld.Undeliverable__c;
    }

    public Map<Id, Address__c> nonDefaultsWithChanges() {
        Map<Id, Address__c> nonDefaultsWithChanges = new Map<Id, Address__c>();
        Integer i = 0;
        for (Address__c addr : (List<Address__c>) getRecords()) {
            NPSP_Address npspAddress = new NPSP_Address(addr);
            Address__c addrOld = oldVersionOf(addr);
            NPSP_Address npspAddressOld = new NPSP_Address(addrOld);
            if ((!npspAddress.isEqualToIncludingAddressType(npspAddressOld, TRUE) ||
                isUndeliverableStatusChanged(addr, addrOld))) {

                nonDefaultsWithChanges.put(idOf(addr), addr);
            }
            i++;
        }
        return nonDefaultsWithChanges;
    }

    public Map<Id, Address__c> addressesByAccountId() {
        Map<Id, Address__c> mapAddressesByAcctId = new Map<Id, Address__c>(); // map of HH Accounts, and their default Address
        for (Address__c address : (List<Address__c>) getRecords()) {
            if (hasHouseholdAccount(address)) {
                mapAddressesByAcctId.put(householdAccountIdFor(address), address);
            }
        }
        return mapAddressesByAcctId;
    }

    public Map<Id, Address__c> defaultAndSeasonalAddressesByHouseholdAccountId() {
        Map<Id, Address__c> defaultAndSeasonalAddressesByAcctId = new Map<Id, Address__c>();
        for (Address__c addr : (List<Address__c>) getRecords()) {
            NPSP_Address npspAddress = new NPSP_Address(addr);
            if (isDefault(addr) || npspAddress.isSeasonalAddr()) {
                defaultAndSeasonalAddressesByAcctId.put(householdAccountIdFor(addr), addr);
            }
        }
        return defaultAndSeasonalAddressesByAcctId;
    }

    public void deleteEmptyAddresses() {
        List<Address__c> listAddr = new List<Address__c>();
        for (Address__c addr : (List<Address__c>) getRecords()) {
            if (isAddressEmpty(addr)) {
                listAddr.add(new Address__c(Id = addr.Id));
            }
        }
        if (listAddr.size() > 0) {
            delete listAddr;
        }
    }

    /*******************************************************************************************************
    * @description For the list of Addresses, sees if there is already an existing Address in the Account that
    * matches. Creates only unique addresses from their respective household, and mark any existing matches
    * as Default if the caller specifies it on the new address.
    * @param listAddr a list of Addresses to update
    * @param dmlWrapper the Addresses to update
    * @param includeAddressType whether to include comparing the AddressType field
    */
    public static void createNonDuplicateAddresses(List<Address__c> listAddr,
            TDTM_Runnable.DmlWrapper dmlWrapper, Boolean includeAddressType) {

        Map<Address__c, Address__c> mapAddrDupAddr= findDuplicateAddresses(listAddr);
        for (Address__c addrNew : listAddr) {
            NPSP_Address npspAddressNew = new NPSP_Address(addrNew);
            Address__c addrDup = mapAddrDupAddr.get(addrNew);
            NPSP_Address npspAddressDup = new NPSP_Address(addrDup);
            if (addrDup != null) {
                // if it is a fuzzy match, not exact, then we want to update the existing address.
                if (!npspAddressNew.isEqualToIncludingAddressType(npspAddressDup, includeAddressType)) {
                    npspAddressDup.copyFrom(npspAddressNew);
                    if (npspAddressNew.isDefault()) {
                        npspAddressDup.setAsDefault();
                    }
                    dmlWrapper.objectsToUpdate.add(npspAddressDup.getRecord());
                } else if (npspAddressNew.isDefault() && !npspAddressDup.isDefault()) {
                    npspAddressDup.setAsDefault();
                    dmlWrapper.objectsToUpdate.add(npspAddressDup.getRecord());
                }
            } else {
                dmlWrapper.objectsToInsert.add(npspAddressNew.getRecord());
            }
        }
    }

    /*******************************************************************************************************
    * @description for the given addresses, find if they have a match, and return a map that
    * has null for no match, and the matching address if there is a match.
    * @param listAddr a list of Addresses to update
    * @return map<Address__c, Address__c>
    */
    public static Map<Address__c, Address__c> findDuplicateAddresses(List<Address__c> listAddr) {
        // for each address, create a map of HHId to lists of Addresses
        List<Id> listAccId = new List<Id>();
        for (Address__c addr : listAddr) {
            listAccId.add(addr.Household_Account__c);
        }
        Map<Id, List<Address__c>> mapAccIdListAddrHH = Addresses.getMapAccIdListAddrHH
                (listAccId);
        Boolean tryFuzzy = UTIL_CustomSettingsFacade.getContactsSettings().Simple_Address_Change_Treated_as_Update__c;

        // create our map for returning information in
        Map<Address__c, Address__c> mapAddrDupAddr = new Map<Address__c, Address__c>();

        // now compare our Addresses to the existing Addresses
        for (Address__c addr : listAddr) {
            NPSP_Address npspAddress = new NPSP_Address(addr);
            List<Address__c> listAddrHH = mapAccIdListAddrHH.get(addr.Household_Account__c);
            Boolean hasMatch = false;
            if (listAddrHH != null) {
                Address__c addrMatch = null;
                for (Address__c addrHH : listAddrHH) {
                    NPSP_Address npspAddressHH = new NPSP_Address(addrHH);
                    // only include address type in the test if the new one isn't empty.
                    if (isMatch(npspAddress, npspAddressHH)) {
                        // found exact match, record it and bail out
                        addrMatch = addrHH;
                        break;
                    }
                    if (tryFuzzy && npspAddress.isAddressMatchFuzzyWith(npspAddressHH)) {
                        // found fuzzy match, remember it and continue searching
                        addrMatch = addrHH;
                        continue;
                    }
                }
                if (addrMatch != null) {
                    hasMatch = true;
                    mapAddrDupAddr.put(addr, addrMatch);
                }
            }
            if (!hasMatch) {
                mapAddrDupAddr.put(addr, null);
            }
        }

        return mapAddrDupAddr;
    }

    private static Boolean isMatch(NPSP_Address npspAddress, NPSP_Address npspAddressHH) {
        return npspAddress.isEqualToIncludingAddressType(npspAddressHH, false);
    }

    /*******************************************************************************************************
    * @description Cleanup the Addresses for the specified Accounts by removing any duplicate Addresses,
    * making sure only one is marked Default, and that the Default is propagated to the appropriate
    * Account and Contacts.
    *
    * @param listAccId a list of Account Id's to process
    */
    public static void cleanupAccountAddresses(List<Id> listAccId) {

        // use dmlWrapper to handle all of our database operations
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();

        // for each Account, track its correct Default Address
        Map<Id, Address__c> mapAccIdAddr = new Map<Id, Address__c>();

        // for each Account, get its list of Addresses in oldest to newest order (of LastModifiedDate)
        Map<Id, List<Address__c>> mapAccIdListAddrHH = Addresses.getMapAccIdListAddrHH(listAccId);

        // Construct Contact repository for Accounts having Addresses
        HouseholdAccounts householdAccounts = new HouseholdAccounts(mapAccIdListAddrHH.keySet());

        for (Id accId : mapAccIdListAddrHH.keySet()) {
            if (mapAccIdListAddrHH.get(accId) != null) {
                Map<String, List<Address__c>> mapAddrKeyToAddresses = new Map<String, List<Address__c>>();
                Address__c addrDefault;

                for (Address__c addr : mapAccIdListAddrHH.get(accId)) {

                    // remember the oldest modified Default address
                    // this is the one from the winning account, since the losing account addresses get updated.
                    if (addr.Default_Address__c && addrDefault == null) {
                        addrDefault = addr;
                        mapAccIdAddr.put(accId, addrDefault);
                    }

                    // create our map of Address Keys to a list of one or more Addresses
                    NPSP_Address npspAddr = new NPSP_Address(addr);
                    String addrKey = npspAddr.getAddrKey();
                    List<Address__c> listAddr = mapAddrKeyToAddresses.get(addrKey);
                    if (listAddr == null) {
                        listAddr = new List<Address__c>();
                        mapAddrKeyToAddresses.put(addrKey, listAddr);
                    }
                    listAddr.add(addr);
                }

                // now we have the Default Address to use and lists of potential duplicate addresses
                // remove the duplicates, updating any contacts that are using the duplicates
                // we delay getting the contacts until we know we have a duplicate.
                for (String addrKey : mapAddrKeyToAddresses.keySet()) {
                    List<Address__c> listAddr = mapAddrKeyToAddresses.get(addrKey);

                    for (Integer i = 1, size = listAddr.size(); i < size; i++) {
                        Address__c addrDupe = listAddr[i];

                        replaceAddress(addrDupe, listAddr[0], householdAccounts.membersOf(accId), dmlWrapper);
                        dmlWrapper.objectsToDelete.add(addrDupe);
                    }
                }

            }
        }

        // perform our updates & deletes for dealing with the duplicate addresses
        TDTM_TriggerHandler.processDML(dmlWrapper);

        // now make sure all contacts are using the correct default address
        dmlWrapper = new TDTM_Runnable.DmlWrapper();
        refreshCurrentHHAddress(mapAccIdAddr, dmlWrapper, false);
        TDTM_TriggerHandler.processDML(dmlWrapper);
    }

    /*******************************************************************************************************
    * @description routine the scheduled batch job calls to update households with Seasonal addresses
    * @param listAcc a list of Accounts to see if their address needs to be updated
    */
    public static void batchSeasonalUpdate(List<Account> listAcc) {
        if (listAcc == null || listAcc.size() == 0) {
            return;
        }

        Map<Id, Address__c> mapAccIdAddr = new Map<Id, Address__c>();
        for (Account acc : listAcc) {
            mapAccIdAddr.put(acc.Id, null);
        }

        // get the default and seasonal address for each HH
        Map<Id, Addresses.HHInfo> mapAccIdHHInfo =
                refreshCurrentHHAddress(mapAccIdAddr, null, true);

        // now see which accounts actually had their address change, so we only update them.
        for (Account acc : listAcc) {
            Addresses.HHInfo hhinfo = mapAccIdHHInfo.get(acc.Id);
            if (hhinfo != null) {
                Address__c addr = hhinfo.addrSeasonal;
                if (addr == null) {
                    addr = hhinfo.addrDefault;
                }
                if (addr != null) {
                    NPSP_Address npspAddr = new NPSP_Address(addr);
                    NPSP_Address npspAddressCurrent = new NPSP_Address(new Address__c());
                    npspAddressCurrent.copyFromSObject(acc, 'Billing', null);
                    // now see if the address has changed, and if not, we don't need to process it anymore
                    if (npspAddr.isEqualToIncludingAddressType(npspAddressCurrent, false)) {
                        mapAccIdAddr.remove(acc.Id);
                    }

                }
            }
        }

        // now mapAccIdAddr only contains those Accounts (and Contacts) who need updating.
        // we'll go thru refreshCurrentHHAddress() again, this time allowing it to do the updates

        // must manually set our semaphore, so when we update contacts and households, they don't try to create additional addresses
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunTrigger, true);

        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();
        refreshCurrentHHAddress(mapAccIdAddr, dmlWrapper, false);
        TDTM_TriggerHandler.processDML(dmlWrapper);
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunTrigger, false);
    }

    /*******************************************************************************************************
    * @description Updates the Latest date fields on any address overrides
    * @param mapAddrIdIsOverride map of Address Id's to an isOverride boolean
    * @param dmlWrapper to hold the Addresses that need updating
    ********************************************************************************************************/
    public static void updateAddrIsOverride(Map<Id, Boolean> mapAddrIdIsOverride) {
        if (!mapAddrIdIsOverride.isEmpty()) {
            TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();
            for (Id id : mapAddrIdIsOverride.keySet()) {
                Address__c addr = new Address__c();
                addr.Id = id;
                if (mapAddrIdIsOverride.get(id) == true) {
                    addr.Latest_Start_Date__c = System.today();
                    addr.Latest_End_Date__c = null;
                } else {
                    addr.Latest_End_Date__c = System.today();
                }
                dmlWrapper.objectsToUpdate.add(addr);
            }
            TDTM_TriggerHandler.processDML(dmlWrapper);
        }
    }

    /*******************************************************************************************************
    * @description utility to see if the address has only a subset of its seasonal fields set
    * @param addr the Address to look at
    */
    public static void handleMultilineStreet(Address__c addr) {

        if (addr.MailingStreet__c == null) {
            return;
        }

        // handle CR NL
        Integer ich = addr.MailingStreet__c.indexOf('\r\n');
        if (ich > -1) {
            addr.MailingStreet2__c = addr.MailingStreet__c.substring(ich+2);
            addr.MailingStreet__c = addr.MailingStreet__c.left(ich);
            return;
        }

        // handle just NL
        ich = addr.MailingStreet__c.indexOf('\n');
        if (ich > -1) {
            addr.MailingStreet2__c = addr.MailingStreet__c.substring(ich+1);
            addr.MailingStreet__c = addr.MailingStreet__c.left(ich);
            return;
        }
    }

    private Boolean hasHouseholdAccount(Address__c address) {
        return householdAccountIdFor(address) != null;
    }

    private Id householdAccountIdFor(Address__c address) {
        return address.Household_Account__c;
    }

    private Boolean isNewDefault(Address__c addr, Address__c addrOld) {
        return addr.Default_Address__c && (addr.Default_Address__c != addrOld.Default_Address__c);
    }

    /*******************************************************************************************************
    * @description utility to compare two address objects seasonal fields
    * @param addrNew the new version of the Address
    * @param addrOld the old version of the Address
    * @return boolean. true if any of the seasonal fields have changed on the Address
    */
    private Boolean isSeasonalChanged(Address__c addrNew, Address__c addrOld) {
        if (addrNew == null || addrOld == null) {
            return false;
        }
        return (
                addrNew.Seasonal_Start_Month__c != addrOld.Seasonal_Start_Month__c ||
                        addrNew.Seasonal_Start_Day__c != addrOld.Seasonal_Start_Day__c ||
                        addrNew.Seasonal_End_Month__c != addrOld.Seasonal_End_Month__c ||
                        addrNew.Seasonal_End_Day__c != addrOld.Seasonal_End_Day__c);
    }

    private Id idOf(Address__c addr) {
        return addr.Id;
    }

    private void setLatestDatesOnDefaults() {
        for (Address__c addr : (List<Address__c>) defaultAddresses().getRecords()) {
            resetLatestStartDateFor(addr);
            resetLatestEndDateFor(addr);
        }
    }

    private void resetLatestEndDateFor(Address__c address) {
        address.Latest_End_Date__c = NULL;
    }

    private void resetLatestStartDateFor(Address__c address) {
        address.Latest_Start_Date__c = System.today();
    }

    private Addresses defaultAddresses() {
        fflib_SObjects defaultAddresses = selectByFieldValue(
                Address__c.Default_Address__c, TRUE);
        return new Addresses(defaultAddresses.getRecords());
    }

    private void updateLatestDatesForDefaultChanges() {
        for (Address__c addr :
                (List<Address__c>) addressesWithDefaultChanges().getRecords()) {
            // when an address changes Default, we update its latest date fields
            if (isDefault(addr)) {
                resetLatestStartDateFor(addr);
                resetLatestEndDateFor(addr);
            } else {
                setEndDateFor(addr);
            }
        }
    }

    private Addresses addressesWithDefaultChanges() {
        List<Address__c> addressesWithDefaultChanges = new List<Address__c>();
        for (Address__c addr : (List<Address__c>) getRecords()) {
            if (isDefaultChanged(addr)) {
                addressesWithDefaultChanges.add(addr);
            }
        }
        return new Addresses(addressesWithDefaultChanges);
    }

    private void setEndDateFor(Address__c addr) {
        addr.Latest_End_Date__c = System.today();
    }

    private Boolean isDefaultChanged(Address__c addr) {
        return isDefault(addr) != isDefault(oldVersionOf(addr));
    }

    private Boolean isDefault(Address__c addr) {
        return addr.Default_Address__c;
    }

    private Address__c oldVersionOf(Address__c addr) {
        return oldMap.get(addr.Id);
    }

    private static Map<Id, Account> getAccountsByIds(Set<Id> acctIds) {
        return new Map<Id, Account>([
                SELECT Id, BillingStreet, BillingCity, BillingState,
                        BillingPostalCode, BillingCountry, BillingLatitude, BillingLongitude, Undeliverable_Address__c
                FROM Account
                WHERE Id IN :acctIds
        ]);
    }

    /*******************************************************************************************************
    * @description utility to return the current StartDate or EndDate of a Seasonal Address
    * @param addr the Address to look at
    * @param fStart whether to return the StartDate or EndDate
    * @return Date
    */
    private static Date dtStartOrEndOfAddrSeasonal(Address__c addr, Boolean fStart) {
        Integer startMonth = Integer.valueOf(addr.Seasonal_Start_Month__c);
        Integer startDay = Integer.valueOf(addr.Seasonal_Start_Day__c);
        Integer endMonth = Integer.valueOf(addr.Seasonal_End_Month__c);
        Integer endDay = Integer.valueOf(addr.Seasonal_End_Day__c);
        Date dtStart;
        Date dtEnd;
        Date dtToday = System.today();
        //seasonal address is contained within a single year
        if (startMonth <= endMonth) {
            dtStart = Date.newInstance(dtToday.year(), startMonth, startDay);
            dtEnd = Date.newInstance(dtToday.year(), endMonth, endDay);
            //seasonal address overlaps the year, and this month is past the start month
        } else if (startMonth <= dtToday.month()){
            dtStart = Date.newInstance(dtToday.year(), startMonth, startDay);
            dtEnd = Date.newInstance(dtToday.year()+1, endMonth, endDay);
            //seasonal address overlaps the year, and this month is before the start month
        } else {
            dtStart = Date.newInstance(dtToday.year()-1, startMonth, startDay);
            dtEnd = Date.newInstance(dtToday.year(), endMonth, endDay);
        }
        return (fStart ? dtStart : dtEnd);
    }

    /*******************************************************************************************************
    * @description returns whether the Address's mailing fields are null
    * @param addr the Address
    * @return boolean. true if all of the Mailing fields are empty
    */
    private static Boolean isAddressEmpty(Address__c addr) {
        if (addr == null) {
            return false;
        }
        return (
                addr.MailingStreet__c == Null &&
                        addr.MailingStreet2__c == Null &&
                        addr.MailingCity__c == Null &&
                        addr.MailingState__c == Null &&
                        addr.MailingPostalCode__c == Null &&
                        addr.MailingCountry__c == Null);
    }

    /*******************************************************************************************************
    * @description replaces the losing address with the winning address in any contacts referring to the
    * loser.  Note that it just updates the contact's Address lookup, and doesn't copy any Address data.
    * Any Contacts that are modified are put on dmlWrapper for later updating.
    * @param addrLoser the Address to look for
    * @param addrWinner the Address to replace with
    * @param listCon the list of Contacts to evaluate
    * @param dmlWrapper to hold any Contacts that need updating
    */
    private static void replaceAddress(Address__c addrLoser, Address__c addrWinner, List<Contact> listCon, TDTM_Runnable.DmlWrapper dmlWrapper) {
        for (Contact con : listCon) {
            if (con.Current_Address__c == addrLoser.Id) {
                con.Current_Address__c = addrWinner.Id;
                dmlWrapper.objectsToUpdate.add(con);
            }
        }
    }

    /*******************************************************************************************************
    * @description for the map of addresses, update any contact's mailing fields that are using the address as an override.
    * @param mapAddrIdAddr a map of Address Id's to Addresses
    * @param dmlWrapper to hold the Contacts to update
    */
    private void updateAddrOverrides(Map<Id, Address__c> mapAddrIdAddr,
            TDTM_Runnable.DmlWrapper dmlWrapper) {
        List<Contact> listCon = [select Id, is_Address_Override__c, Current_Address__c from Contact where is_Address_Override__c = true and Current_Address__c in :mapAddrIdAddr.keySet()];
        for (Contact con : listCon) {
            NPSP_Contact npspContact = new NPSP_Contact(con);
            NPSP_Address npspAddress = new NPSP_Address(mapAddrIdAddr.get(npspContact.currentAddress()));

            npspContact.mailingAddress(npspAddress);
            npspContact.undeliverableAddress(npspAddress.isUndeliverable());

            dmlWrapper.objectsToUpdate.add(npspContact.getRecord());
        }
    }

    private void putErrorsOnAddresses(ERR_Handler.Errors errors, Map<Id, Address__c> mapAddressesByAcctId, Map<Id, Address__c> mapAddressesById) {
        for (Error__c error : errors.errorRecords) {
            Id objId = ERR_Handler.getErrorObjectId(error);
            UTIL_Debug.debug(LoggingLevel.WARN, '**** Address TDTM error on object: ' + objId);
            if (UTIL_Describe.isObjectIdThisType(objId, 'Account')) {
                Address__c addr = mapAddressesByAcctId.get(objId);
                addr.addError(error.Full_Message__c);
                UTIL_Debug.debug(LoggingLevel.WARN, '**** Address: ' + addr + ' message: ' + error.Full_Message__c);
            } else if (UTIL_Describe.isObjectIdThisType(objId, UTIL_Namespace.StrTokenNSPrefix('Address__c'))) {
                Address__c addr = mapAddressesById.get(objId);
                addr.addError(error.Full_Message__c);
                UTIL_Debug.debug(LoggingLevel.WARN, '**** Address: ' + addr + ' message: ' + error.Full_Message__c);
            }
        }
    }

}