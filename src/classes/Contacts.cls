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
* @description Domain class for Contacts in NPSP.
*/
public inherited sharing class Contacts extends fflib_SObjects {

    private Map<Id, Contact> oldMap;
    private Boolean isUpdate = false;

    @TestVisible
    private ContactService contactService {
        get {
            if (contactService == null) {
                contactService = new ContactService();
            }
            return contactService;
        }
        set;
    }

    public Contacts(List<Contact> records) {
        this(records, null);
    }

    public Contacts(List<Contact> records, List<Contact> oldList) {
        super(records, Contact.SObjectType);
        this.oldMap = oldList != null ?
                new Map<Id, Contact>(oldList) : new Map<Id, Contact>();
    }

    public void onBeforeInsert() {
        syncNamingExclusionsBeforeInsert();
    }

    /**
     * @description ADDR_Contact_TDTM was refactored and its logic was moved down into this
     * class and supporting entity classes like NPSP_Contact and NPSP_Address.  However, there
     * is already a Trigger Handler (HH_Households_TDTM) running in the
     * before insert context for Contacts, and that handler calls the onBeforeInsert method.
     * Secondary Trigger Handlers running in
     * the same context will have to use specific trigger context entry point methods, like
     * this one (or call other public methods directly) until NPSP is able to merge down
     * Trigger Handlers so that there is only one per Trigger Context for each object.  At
     * that point the logic in this method will be moved into the onBeforeInsert method and
     * this method will be removed.
     */
    public void onBeforeInsert_FromAddrContactTDTM() {
        normalizeLineBreaks();

        List<Contact> consThatHaveARelatedAddress = consThatHaveARelatedAddress();
        if (consThatHaveARelatedAddress.size() > 0) {
            // to avoid pushing these address changes to the HH.
            setRecursionFlags();
            // set the mailing address for contacts who specify an address lookup or override
            setContactAddressFromCurrentAddress(consThatHaveARelatedAddress);
        }

        Contacts contactsNeedingHouseholdAddressApplied = contactsNeedingHouseholdAddressApplied();
        if (contactsNeedingHouseholdAddressApplied.getRecords().size() > 0) {
            // to avoid pushing these address changes to the HH.
            setRecursionFlags();
            // reset the mailing address for contacts who no longer have an address override
            contactsNeedingHouseholdAddressApplied.resetAddressUsingHouseholdAddress();
        }

        // create any new Default Address objects
        createAddressFromContact(
                new List<Contact>(contactsWithAddressChanges()));

        // update the Latest date fields on any address overrides
        Addresses.updateAddrIsOverride(getIsOverrideByAddressIdBeforeInsert());

        if (consThatHaveARelatedAddress.size() > 0 ||
                contactsNeedingHouseholdAddressApplied.getRecords().size() > 0) {
            deactivateAddrRecursionFlag();
        }
    }

    public void onBeforeUpdate() {
        syncNamingExclusionsBeforeUpdate();
    }

    /**
     * @description ADDR_Contact_TDTM was refactored and its logic was moved down into this
     * class and supporting entity classes like NPSP_Contact and NPSP_Address.  However, there
     * is already a Trigger Handler (HH_Households_TDTM) running in the
     * before update context for Contacts, and that handler calls the onBeforeUpdate method.
     * Secondary Trigger Handlers running in
     * the same context will have to use specific trigger context entry point methods, like
     * this one (or call other public methods directly) until NPSP is able to merge down
     * Trigger Handlers so that there is only one per Trigger Context for each object.  At
     * that point the logic in this method will be moved into the onBeforeUpdate method and
     * this method will be removed.
     */
    public void onBeforeUpdate_FromAddrContactTDTM() {
        normalizeLineBreaksForContactsWithChangedAddresses();
        Map<Id, Boolean> isOverrideByAddressId = getIsOverrideByAddressId();
        isOverrideByAddressId.putAll(getIsOverrideByAddressIdFromAddressOverrideChanges());

        // set the mailing address for contacts who specify an address lookup or override
        List<Contact> consNeedingAddressFieldsPopulated = consWhoseAddressChanged();
        if (consNeedingAddressFieldsPopulated.size() > 0) {
            // to avoid pushing these address changes to the HH.
            setRecursionFlags();
            setContactAddressFromCurrentAddress(consNeedingAddressFieldsPopulated);
            deactivateAddrRecursionFlag();
        }

        // reset the mailing address for contacts who no longer have an address override
        List<Contact> addressRefreshQueue =
                consWhoseAccountChangedAndDontHaveAddressOverrides();
        addressRefreshQueue.addAll(consHavingAddressOverridesRemoved());
        if (addressRefreshQueue.size() > 0) {
            // to avoid pushing these address changes to the HH.
            setRecursionFlags();
            Contacts contactsForAddressRefresh = new Contacts(addressRefreshQueue);
            contactsForAddressRefresh.resetAddressUsingHouseholdAddress();
            deactivateAddrRecursionFlag();
        }

        // create any new Default Address objects
        Set<Contact> addressCreationQueue = getAddressCreationQueueBeforeUpdate();
        createAddressFromContact(new List<Contact>(addressCreationQueue));

        // update the Latest date fields on any address overrides
        Addresses.updateAddrIsOverride(isOverrideByAddressId);
    }

    public void onAfterUpdate() {
        isUpdate = true;
        createAddressesForContacts();
    }

    public void onAfterInsert() {
        createAddressesForContacts();
    }

    public void onAfterDelete() {
        fireRollupsForMergedContacts();
        if (!contactsInHouseholds().isEmpty()) {
            ContactsInLegacyHouseholds contactsInLegacyHouseholds =
                    new ContactsInLegacyHouseholds(contactsInHouseholds().getRecords());
            contactsInLegacyHouseholds.onAfterDelete();
        }
    }

    public List<Contact> forHouseholdName() {
        List<Contact> contactsForHouseholdNameGeneration = new List<Contact>();
        for (Contact con : (List<Contact>) getRecords()) {
            if (isIncludedInHouseholdName(con)) {
                contactsForHouseholdNameGeneration.add(con);
            }
        }
        return contactsForHouseholdNameGeneration;
    }

    public List<Contact> forFormalGreeting() {
        List<Contact> contactsForFormalName = new List<Contact>();
        for (Contact con : (List<Contact>) getRecords()) {
            if (isIncludedInFormalGreeting(con)) {
                contactsForFormalName.add(con);
            }
        }
        return contactsForFormalName;
    }

    public List<Contact> forInformalGreeting() {
        List<Contact> listCon = new List<Contact>();
        for (Contact con : (List<Contact>) getRecords()) {
            if (isIncludedInInformalGreeting(con)) {
                listCon.add(con);
            }
        }
        return listCon;
    }

    /**
     * @description NPSP Contacts have two forms of tracking which Household Name / Greetings
     * they should be excluded from.  Checkboxes are a newer implementation and have priority.
     * This method aligns the concatenated String with the Checkboxes to keep them in sync.
     */
    public void synchronizeNamingExclusions() {
        for (Contact con : (List<Contact>) getRecords()) {
            INamingExclusionsString exclusionsAsString =
                    new HouseholdNamingExclusionsString(con);
            INamingExclusions exclusionsAsBooleans =
                    new HouseholdNamingExclusionsCheckboxes(con);
            if (!exclusionsAsString.equals(exclusionsAsBooleans)) {
                mergeExclusions(exclusionsAsBooleans, exclusionsAsString);
                setExclusionsStringFor(con, exclusionsAsString.value());
                setExclusionsCheckboxes(con, exclusionsAsBooleans);
            }
        }
    }

    public Boolean accountHasAddresses(Contact con) {
        return (accountsByIds().containsKey(con.AccountId)
                && accountsByIds().get(con.AccountId).Addresses__r.size() > 0);
    }

    public void normalizeLineBreaksForContactsWithChangedAddresses() {
        for (Integer i = 0; i < getRecords().size(); i++) {
            Contact newRecord = (Contact) getRecords()[i];

            if (contactService.isContactAddressChanged(newRecord, oldVersionOf(newRecord))) {
                UTIL_Address.normalizeLineBreak(newRecord);
            }
        }
    }

    public void normalizeLineBreaks() {
        for (Integer i = 0; i < getRecords().size(); i++) {
            Contact newRecord = (Contact) getRecords()[i];
            UTIL_Address.normalizeLineBreak(newRecord);
        }
    }

    /*******************************************************************************************************
    * @description for each contact, refresh its mailing address from its Address lookup
    * @param listCon the list of Contacts to update
    ********************************************************************************************************/
    public void setContactAddressFromCurrentAddress(List<Contact> listCon) {
        List<Contact> listConCreateAddr = new List<Contact>();
        Set<Id> setAddrId = new Set<Id>();
        for (Contact con : listCon) {
            if (con.Current_Address__c != null) {
                setAddrId.add(con.Current_Address__c);
            }
        }

        Map<Id, Address__c> mapAddrIdAddr = new Map<Id, Address__c>([SELECT Id, Address_Type__c,
                Household_Account__c, MailingStreet__c, MailingStreet2__c, MailingCity__c,
                MailingState__c, Geolocation__Latitude__s, Geolocation__Longitude__s,
                MailingPostalCode__c, MailingCountry__c
        FROM Address__c
        WHERE Id IN :setAddrId]
        );

        for (Contact con : listCon) {
            Address__c addr = mapAddrIdAddr.get(con.Current_Address__c);
            NPSP_Address npspAddress = new NPSP_Address(addr);
            NPSP_Contact npspContact = new NPSP_Contact(con);
            if (npspContact.mailingAddressIsDifferentFrom(npspAddress)) {
                npspContact.mailingAddress(npspAddress);
                // deal with any address coming from a different account,
                // which we need to treat as a creation instead.
                if (npspAddress.householdId() != npspContact.accountId()) {
                    listConCreateAddr.add(npspContact.getRecord());
                }
            }
        }

        createAddressFromContact(listConCreateAddr);
    }

    /*******************************************************************************************************
    * @description Creates a new address or matches an existing one, for each Contact.
    * This routine is called both by BeforeInsert/Update and AfterInsert/Update.
    * when pushing a new default address, we need to do it in the AfterInsert/Update.
    * otherwise we want to do it in the BeforeInsert/Update so we can update the contacts' info now.
    * @param listConAll the list of Contacts
    ********************************************************************************************************/
    public void createAddressFromContact(List<Contact> listConAll) {
        if (!listConAll.isEmpty()) {
            // Strategy:
            // create a new (unsaved) address for each contact.
            // see if there is an existing address that matches each new address.
            //
            // for existing addresses we match
            //     process during BeforeInsert/Update
            //     update appropriate fields on contact
            //
            // for new addresses that won't be a default (ie, the contact has override set)
            //     process during BeforeInsert/Update
            //     create the address now
            //     update appropriate fields on contact
            //
            // for new addresses that will be a default address
            //     process during AfterInsert/Update
            //     mark the new address as default
            //     put it on dmlWrapper
            //

            Map<Contact, Address__c> mapConAddr = new Map<Contact, Address__c>();
            List<Contact> listCon = new List<Contact>();

            for (Contact con : listConAll) {
                listCon.add(con);
                NPSP_Address npspAddressFromContact = new NPSP_Address(con);
                mapConAddr.put(con, npspAddressFromContact.getRecord());
            }

            // look for duplicates for our proposed new addresses
            Map<Address__c, Address__c> mapAddrDupAddr = Addresses.findDuplicateAddresses(mapConAddr
                    .values());

            // maps & lists to keep track of the addresses we must insert or update
            Map<Contact, Address__c> mapConAddrInsertNow = new Map<Contact, Address__c>();

            for (Contact con : listCon) {
                Address__c addrNew = mapConAddr.get(con);
                Address__c addrDup = mapAddrDupAddr.get(addrNew);

                // if found a match
                if (addrDup != null) {
                    // record the match in the contact
                    con.Current_Address__c = addrDup.Id;

                    //reset the Primary Address Type only; resetting other fields on Contact will create a new Address
                    con.npe01__Primary_Address_Type__c = con.npe01__Primary_Address_Type__c == null
                            ? addrDup.Address_Type__c
                            : con.npe01__Primary_Address_Type__c;

                    // Prevent an address that was just inserted by the BeforeInsert trigger from being udpated
                    // a second time by the AfterInsert trigger.
                }

                // no match found, and its an override just for this contact
                else if (con.is_Address_Override__c) {
                    // put it on the list of addresss to create now
                    mapConAddrInsertNow.put(con, addrNew);
                }
            }

            if (mapConAddrInsertNow.size() > 0) {
                UTIL_DMLService.insertRecords(mapConAddrInsertNow.values());
                // Since we're inserting new Addresses in a Before Insert/Update scenario, set the flag to
                // prevent the After Insert/Update Contact logic from executing when it's eventually called.
                TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunContactOnBefore, true);
                for (Contact con : mapConAddrInsertNow.keySet()) {
                    Address__c addr = mapConAddrInsertNow.get(con);
                    con.Current_Address__c = addr.Id;
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description Creates a new address or matches an existing one, for each Contact.
    * This routine is called both by BeforeInsert/Update and AfterInsert/Update.
    * when pushing a new default address, we need to do it in the AfterInsert/Update.
    * otherwise we want to do it in the BeforeInsert/Update so we can update the contacts' info now.
    * @param listConAll the list of Contacts
    * @param dmlWrapper to hold the Addresses that need inserting/updating
    ********************************************************************************************************/
    public void createAddrFromConAfterInsertUpdate(List<Contact> listConAll,
            TDTM_Runnable.DmlWrapper dmlWrapper) {

        // Strategy:
        // create a new (unsaved) address for each contact.
        // see if there is an existing address that matches each new address.
        //
        // for existing addresses we match
        //     process during BeforeInsert/Update
        //     update appropriate fields on contact
        //
        // for new addresses that won't be a default (ie, the contact has override set)
        //     process during BeforeInsert/Update
        //     create the address now
        //     update appropriate fields on contact
        //
        // for new addresses that will be a default address
        //     process during AfterInsert/Update
        //     mark the new address as default
        //     put it on dmlWrapper
        //

        Map<Contact, Address__c> mapConAddr = new Map<Contact, Address__c>();
        List<Contact> listCon = new List<Contact>();

        for (Contact con : listConAll) {
            listCon.add(con);
            NPSP_Address npspAddressFromContact = new NPSP_Address(con);
            mapConAddr.put(con, npspAddressFromContact.getRecord());
        }

        // look for duplicates for our proposed new addresses
        Map<Address__c, Address__c> mapAddrDupAddr = Addresses.findDuplicateAddresses(mapConAddr
                .values());

        // maps & lists to keep track of the addresses we must insert or update
        List<Address__c> listAddrUpdateDefault = new List<Address__c>();
        List<Address__c> listAddrInsertDefault = new List<Address__c>();

        for (Contact con : listCon) {
            Address__c addrNew = mapConAddr.get(con);
            Address__c addrDup = mapAddrDupAddr.get(addrNew);

            // if found a match
            if (addrDup != null) {
                // record the match in the contact
                // if it is a fuzzy match, not exact, then we want to update the existing address.
                NPSP_Address npspAddress = new NPSP_Address(addrNew);
                NPSP_Address npspAddressDup = new NPSP_Address(addrDup);

                if (!npspAddress.isEqualToIncludingAddressType(npspAddressDup, true)) {
                    npspAddressDup.copyFrom(npspAddress);
                    if (!con.is_Address_Override__c && !addrDup.Default_Address__c) {
                        addrDup.Default_Address__c = true;
                    }
                    listAddrUpdateDefault.add(addrDup);
                }
                // exact match. we aren't specifying override, so the address should become the new hh default address
                else if (!con.is_Address_Override__c && !addrDup.Default_Address__c) {
                    addrDup.Default_Address__c = true;
                    listAddrUpdateDefault.add(addrDup);
                }
            } else {
                // no match, not an override, make it a new default hh address
                addrNew.Default_Address__c = true;
                listAddrInsertDefault.add(addrNew);
            }
        }

        if (listAddrUpdateDefault.size() > 0) {
            for (Address__c addr : listAddrUpdateDefault) {
                dmlWrapper.objectsToUpdate.add(addr);
            }
        }

        if (listAddrInsertDefault.size() > 0) {
            dmlWrapper.objectsToInsert.addAll((List<SObject>) listAddrInsertDefault);
        }
    }

    public void resetAddressUsingHouseholdAddress() {
        Map<Id, Address__c> mapAccIdAddr = new Map<Id, Address__c>();
        for (Contact con : (List<Contact>) getRecords()) {
            mapAccIdAddr.put(con.AccountId, null);
        }

        // get the default and seasonal address for each HH
        Map<Id, Addresses.HHInfo> mapAccIdHHInfo =
                Addresses.refreshCurrentHHAddress(mapAccIdAddr, null, true);

        // reset the Contact's address fields with the appropriate address
        for (Contact con : (List<Contact>) getRecords()) {
            Addresses.HHInfo hhinfo = mapAccIdHHInfo.get(con.AccountId);
            if (hhinfo != null) {
                Address__c addr = hhinfo.addrSeasonal;
                if (addr == null) {
                    addr = hhinfo.addrDefault;
                }
                if (addr != null) {
                    NPSP_Address npspAddress = new NPSP_Address(addr);
                    NPSP_Contact npspContact = new NPSP_Contact(con);
                    npspContact.currentAddress(npspAddress);
                }
            }
        }
    }

    public Contacts contactsInHouseholdAccounts() {
        List<Contact> contactsInHouseholdAccounts = new List<Contact>();
        for (SObject so : getRecords()) {
            NPSP_Contact npspContact = new NPSP_Contact((Contact) so);
            if (isAnAccountOfTypeHousehold(accountFor(npspContact))) {
                contactsInHouseholdAccounts.add(npspContact.getRecord());
            }
        }
        return new Contacts(contactsInHouseholdAccounts);
    }

    private List<NPSP_Contact> npspContactsInHouseholdAccounts() {
        List<NPSP_Contact> contactsInHouseholdAccounts = new List<NPSP_Contact>();
        for (SObject so : getRecords()) {
            NPSP_Contact npspContact = new NPSP_Contact((Contact) so, oldVersionOf(
                    (Contact) so));
            if (isAnAccountOfTypeHousehold(accountFor(npspContact))) {
                contactsInHouseholdAccounts.add(npspContact);
            }
        }
        return contactsInHouseholdAccounts;
    }

    private List<NPSP_Contact> householdAccountContacts;
    public List<NPSP_Contact> householdAccountContacts() {
        if (householdAccountContacts == null) {
            householdAccountContacts = new List<NPSP_Contact>();
            for (Contact con : (List<Contact>) getRecords()) {
                NPSP_Contact npspContact = new NPSP_Contact(con, oldVersionOf(con));
                if (!npspContact.hasAccount()) {
                    continue;
                }
                householdAccountContacts.add(npspContact);
            }
        }
        return householdAccountContacts;
    }

    public Set<Id> accountIds() {
        Set<Id> setAccountId = new Set<Id>();
        for (Integer i = 0; i < getRecords().size(); i++) {
            Contact newRecord = (Contact) getRecords()[i];

            // need to query account fields we need to look at
            if (newRecord.AccountId != null) {
                setAccountId.add(newRecord.AccountId);
            }
        }
        return setAccountId;
    }

    private Map<Id, Account> accountsById;
    public Map<Id, Account> accountsByIds() {
        if (accountsById == null) {
            accountsById = new Map<Id, Account>([
                    SELECT Id, npe01__SYSTEM_AccountType__c, (SELECT Id FROM Addresses__r)
                    FROM Account
                    WHERE Id IN :accountIds()
            ]);
        }
        return accountsById;
    }

    private void deactivateAddrRecursionFlag() {
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunTrigger, false);
    }

    private Set<Contact> getAddressCreationQueueBeforeUpdate() {
        if (isRecursive()) {
            UTIL_Debug.debug('**** RECURSION: Stop Addr Trigger recursion in ADDR_Contact_TDTM');
            return new Set<Contact>();
        } else {
            return consWithAddressChanges();
        }
    }

    private void setRecursionFlags() {
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunTrigger, true);
        // set this flag to true to prevent the AfterUpdate trigger on the Contact from processing changes
        // to the Contact's address that are being made by this BeforeUpdate trigger.
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunContactOnBefore, true);
    }

    private Set<Contact> contactsWithAddressChanges() {
        Set<Contact> addressCreationQueue = new Set<Contact>();
        if (isRecursive()) {
            UTIL_Debug.debug('**** RECURSION: Stop Addr Trigger recursion in ADDR_Contact_TDTM');
            addressCreationQueue = new Set<Contact>();
        } else {
            addressCreationQueue = consWithAddressChanges();
        }
        return addressCreationQueue;
    }

    private Contacts contactsNeedingHouseholdAddressApplied() {
        List<Contact> addressRefreshQueue = new List<Contact>();
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {
            if (shouldUseAccountAddress(npspContact)) {
                // if the contact has no address specified and the household has a default address, pick up the hh default.
                addressRefreshQueue.add(npspContact.getRecord());
            }
        }
        return new Contacts(addressRefreshQueue);
    }

    private Map<Id, Boolean> getIsOverrideByAddressIdBeforeInsert() {
        Map<Id, Boolean> isOverrideByAddressId = new Map<Id, Boolean>();
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {
            if (hasCurrentAddress(npspContact) && npspContact.hasAddressOverride()) {
                // track which address's need their dates updated
                isOverrideByAddressId.put(npspContact.currentAddress(), true);
            }
        }
        return isOverrideByAddressId;
    }

    private List<Contact> consThatHaveARelatedAddress() {
        List<Contact> useCurrentAddressQueue = new List<Contact>();
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {
            if (hasCurrentAddress(npspContact)) {
                // remember which contacts will need their address set
                useCurrentAddressQueue.add(npspContact.getRecord());
            }
        }
        return useCurrentAddressQueue;
    }

    private Boolean shouldUseAccountAddress(NPSP_Contact npspContact) {
        return npspContact.isAddressEmpty() && accountHasAddresses(npspContact.getRecord());
    }

    private Boolean hasCurrentAddress(NPSP_Contact npspContact) {
        return npspContact.currentAddress() != null;
    }

    private Boolean isIncludedInHouseholdName(Contact con) {
        HouseholdNamingExclusionsString exclusionsAsString = new
                HouseholdNamingExclusionsString(con);
        return !exclusionsAsString.isExcludedFromName();
    }

    private Boolean isIncludedInFormalGreeting(Contact con) {
        HouseholdNamingExclusionsString exclusionsAsString = new
                HouseholdNamingExclusionsString(con);
        return !exclusionsAsString.isExcludedFromFormalGreeting();
    }

    private Boolean isIncludedInInformalGreeting(Contact con) {
        HouseholdNamingExclusionsString exclusionsAsString = new
                HouseholdNamingExclusionsString(con);
        return !exclusionsAsString.isExcludedFromInformalGreeting();
    }

    private Contacts contactsInHouseholds() {
        List<Contact> consInHouseholds = new List<Contact>();
        for (Contact con : (List<Contact>) getRecords()) {
            if (householdIdFor(con) != null) {
                consInHouseholds.add(con);
            }
        }
        return new Contacts(consInHouseholds);
    }

    private void syncNamingExclusionsBeforeInsert() {
        for (Contact con : (List<Contact>) getRecords()) {
            HouseholdNamingExclusionsString namingExclusionsString =
                    new HouseholdNamingExclusionsString(con);

            HouseholdNamingExclusionsCheckboxes exclusionsAsCheckboxes =
                    new HouseholdNamingExclusionsCheckboxes(con);

            if (namingExclusionsString.hasNamingExclusions()) {
                exclusionsAsCheckboxes.updateFrom(namingExclusionsString);
                setExclusionsCheckboxes(con, exclusionsAsCheckboxes);
            }

            if (exclusionsAsCheckboxes.hasNamingExclusions()) {
                namingExclusionsString.synchronizeFrom(exclusionsAsCheckboxes);
                setExclusionsStringFor(con, namingExclusionsString.value());
            }
        }
    }

    private void syncNamingExclusionsBeforeUpdate() {
        for (Contact con : (List<Contact>) getRecords()) {
            HouseholdNamingExclusionsCheckboxes exclusionsAsCheckboxes =
                    new HouseholdNamingExclusionsCheckboxes(con);
            HouseholdNamingExclusionsCheckboxes oldExclusionsAsCheckboxes =
                    new HouseholdNamingExclusionsCheckboxes(oldVersionOf(con));
            HouseholdNamingExclusionsString householdNamingExclusionsString =
                    new HouseholdNamingExclusionsString(con);
            HouseholdNamingExclusionsString oldHouseholdNamingExclusionsString =
                    new HouseholdNamingExclusionsString(oldVersionOf(con));

            if (!exclusionsAsCheckboxes.equals(oldExclusionsAsCheckboxes)) {
                householdNamingExclusionsString.synchronizeFrom(exclusionsAsCheckboxes);
                setExclusionsStringFor(con, householdNamingExclusionsString.value());
            } else if (!householdNamingExclusionsString.equals
                    (oldHouseholdNamingExclusionsString)) {
                exclusionsAsCheckboxes.updateFrom(householdNamingExclusionsString);
                setExclusionsCheckboxes(con, exclusionsAsCheckboxes);
            }
        }
    }

    private void setExclusionsStringFor(Contact contact, String val) {
        contact.npo02__Naming_Exclusions__c = val;
    }

    /**
     * @param exclusionsAsBooleans Checkbox implemenation of Household Naming Exclusions
     * @param exclusionsAsString Concatenated string implementation of Household Naming
     * Exclusions
     * @description Checks any exclusions checkboxes to true that are included in the
     * concatenated string, and then updates the string to include exclusions (field names)
     * for any Exclusion checkboxes that are marked TRUE for the Contact.
     */
    private void mergeExclusions(INamingExclusions exclusionsAsBooleans,
            INamingExclusions exclusionsAsString) {
        // Prioritize booleans by syncing from picklists first
        exclusionsAsBooleans.synchronizeFrom(exclusionsAsString);
        exclusionsAsString.synchronizeFrom(exclusionsAsBooleans);
    }

    private void setExclusionsCheckboxes(Contact con, INamingExclusions exclusions) {
        con.Exclude_from_Household_Name__c = exclusions.isExcludedFromName();
        con.Exclude_from_Household_Formal_Greeting__c = exclusions.isExcludedFromFormalGreeting();
        con.Exclude_from_Household_Informal_Greeting__c = exclusions.isExcludedFromInformalGreeting();
    }

    private void fireRollupsForMergedContacts() {
        Set<Id> mergedWinningContact = getMergedWinningContactIds();
        if (mergedWinningContact.size() > 0) {
            // this fires off opp rollups, which we aren't going to move to dmlWrapper!
            rollupContactsAndHouseholdsAfterMerge(mergedWinningContact);
        }
    }

    private Set<Id> getMergedWinningContactIds() {
        Set<Id> mergedWinningContactIds = new Set<Id>();
        for (Contact con : (List<Contact>) getRecords()) {
            if (isLosingRecordInMergeOperation(con)) {
                mergedWinningContactIds.add(con.MasterRecordId);
            }
        }
        return mergedWinningContactIds;
    }

    private Id householdIdFor(Contact con) {
        return con.npo02__Household__c;
    }

    private Boolean isLosingRecordInMergeOperation(Contact con) {
        return con.MasterRecordId != null;
    }

    private Contact oldVersionOf(Contact con) {
        return oldMap.get(con.Id);
    }

    /*******************************************************************************************************
     * @description kicks off Opportunity Rollups after contacts have been merged, but only if NOT using
     * the Household Account model
     * @param winningContacts Set of Contact Id's
     ********************************************************************************************************/
    @TestVisible
    private static void rollupContactsAndHouseholdsAfterMerge(Set<Id> winningContacts) {

        ContactAndOrgSettings contactAndOrgSettings = new ContactAndOrgSettings();
        if (contactAndOrgSettings.isHouseholdAccountModel()) {
            return;
        }

        Set<Id> oppIds = getOppIdsForWinningContacts(winningContacts);
        if (!oppIds.isEmpty()) {
            if (System.isFuture() || System.isBatch()) {
                RLLP_OppRollup.rollupContactsandHouseholdsForTrigger(oppIds);
            } else {
                RLLP_OppRollup.rollupContactsandHouseholdsForTriggerFuture(oppIds);
            }
        }
    }

    private static Set<Id> getOppIdsForWinningContacts(Set<Id> winningContacts) {
        Set<Id> oppIds = new Set<Id>();
        for (OpportunityContactRole ocr : [
                SELECT OpportunityId
                FROM OpportunityContactRole
                WHERE ContactId IN :winningContacts AND IsPrimary = TRUE
        ]
        ) {
            oppIds.add(ocr.OpportunityId);
        }
        return oppIds;
    }

    private Account accountFor(NPSP_Contact npspContact) {
        return accountsByIds().get(npspContact.accountId());
    }


    private Boolean isAnAccountOfTypeHousehold(Account a) {
        if (a == null) {
            return false;
        }
        return a.npe01__SYSTEM_AccountType__c == CAO_Constants.HH_ACCOUNT_TYPE;
    }

    private Set<Contact> getAddressCreationQueue() {
        Set<Contact> addressCreationQueue = new Set<Contact>();
        if (isRecursive() || isRecursiveFromContact()) {
            if (isRecursive()) {
                UTIL_Debug.debug('**** RECURSION: Stop Addr Trigger recursion in ADDR_Contact_TDTM');
            }
            // If the Before Insert/Update trigger on the Contact has already executed and taken action
            // and this is an After Insert/Update trigger, simply reset the flag and exit out.
            if (isRecursiveFromContact()) {
                UTIL_Debug.debug('**** RECURSION: Stop BeforeContact Trigger recursion in ADDR_Contact_TDTM');
            }
            addressCreationQueue = new Set<Contact>();
        } else {
            addressCreationQueue = getAddressCreationQueueInAfterContext();
        }
        return addressCreationQueue;
    }

    private Set<Contact> consWithAddressChanges() {
        Set<Contact> consWithAddressChanges = getConsWithAddressChanges();
        Set<Contact> consMovingToANewHousehold = getConsMovingToANewHousehold();
        consWithAddressChanges.addAll(consMovingToANewHousehold);
        return consWithAddressChanges;
    }

    private Set<Contact> getConsMovingToANewHousehold() {
        Set<Contact> consMovingToANewHousehold = new Set<Contact>();
        for (NPSP_Contact npspContact : householdAccountContacts()) {

            Account a = accountsByIds().get(npspContact.accountId());
            if (a.npe01__SYSTEM_AccountType__c != CAO_Constants.HH_ACCOUNT_TYPE) {
                continue;
            }
            // BEFORE UPDATE & AFTER UPDATE & BEFORE INSERT && AFTER INSERT
            // our functionality for dealing with contact address changes requires some trickery!
            // if the contact doesn't have an address override, we create (or match) a default address,
            // which requires us to do the work in the AfterUpdate (or else we can't propagate the default address).
            // but if the contact has an address override, we are supposed to create (or match) a non default address override.
            // in order to update the contact with the new address override's Id, we have to do it in the BeforeUpdate.
            // note that we detect whether the address change is coming from the address trigger,
            // in which case we don't want to create a new address.

            // if the contacts address changed or if the contact with an address moves to a new household remember the contact
            if (npspContact.isMovingToANewHousehold()) {
                consMovingToANewHousehold.add(npspContact.getRecord());
            }
        }
        return consMovingToANewHousehold;
    }

    private Set<Contact> getConsWithAddressChanges() {
        Set<Contact> consWithAddressChanges = new Set<Contact>();
        // we only support address management with HH Accounts being used
        for (NPSP_Contact npspContact : householdAccountContacts()) {

            Account a = accountsByIds().get(npspContact.accountId());
            if (a.npe01__SYSTEM_AccountType__c != CAO_Constants.HH_ACCOUNT_TYPE) {
                continue;
            }
            // BEFORE UPDATE & AFTER UPDATE & BEFORE INSERT && AFTER INSERT
            // our functionality for dealing with contact address changes requires some trickery!
            // if the contact doesn't have an address override, we create (or match) a default address,
            // which requires us to do the work in the AfterUpdate (or else we can't propagate the default address).
            // but if the contact has an address override, we are supposed to create (or match) a non default address override.
            // in order to update the contact with the new address override's Id, we have to do it in the BeforeUpdate.
            // note that we detect whether the address change is coming from the address trigger,
            // in which case we don't want to create a new address.

            // if the contacts address changed or if the contact with an address moves to a new household remember the contact
            if (npspContact.isAddressChanged()) {
                consWithAddressChanges.add(npspContact.getRecord());
            }
        }
        return consWithAddressChanges;
    }

    private Set<Contact> getAddressCreationQueueInAfterContext() {
        Set<Contact> addressCreationQueue = new Set<Contact>();
        for (NPSP_Contact npspContact : householdAccountContacts()) {

            if (npspContact.householdAndAccountDiffer()) {
                continue;
            }

            if (npspContact.isAddressChanged() || npspContact.isMovingToANewHousehold()) {
                addressCreationQueue.add(npspContact.getRecord());
            }
        }
        return addressCreationQueue;
    }

    private Boolean isRecursiveFromContact() {
        return TDTM_ProcessControl.isRecursive(TDTM_ProcessControl.flag.ADDR_hasRunContactOnBefore);
    }

    private Boolean isRecursive() {
        return TDTM_ProcessControl.isRecursive(TDTM_ProcessControl.flag.ADDR_hasRunTrigger);
    }

    private Map<Id, Boolean> getIsOverrideByAddressIdFromAddressOverrideChanges() {
        Map<Id, Boolean> isOverrideByAddressId = new Map<Id, Boolean>();
        // we only support address management with HH Accounts being used
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {

            // new highest priority! if Account changes...
            if (!npspContact.accountChanged()) {
                // second priority.  if they are clearing isAddressOverride, and no address fields change, refill from the Default Address
                if (npspContact.isClearingAddressOverride() &&
                        npspContact.noAddressFieldsChanged()) {
                    // track which address's need their dates updated
                    isOverrideByAddressId.put(npspContact.oldVersion().currentAddress(), false);
                }

                // third priority.  if MailingAddress fields changed, update the existing address object or create a new one.
                // this is handled in the next block, since we do it for both new contacts and updated contacts.
            }
        }
        return isOverrideByAddressId;
    }

    private List<Contact> consHavingAddressOverridesRemoved() {
        List<Contact> addressRefreshQueue = new List<Contact>();
        // we only support address management with HH Accounts being used
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {

            // new highest priority! if Account changes...
            if (!npspContact.accountChanged()) {
                // second priority.  if they are clearing isAddressOverride, and no address fields change, refill from the Default Address
                if (npspContact.isClearingAddressOverride() &&
                        !npspContact.isAddressChanged()) {
                    addressRefreshQueue.add(npspContact.getRecord());
                }

                // third priority.  if MailingAddress fields changed, update the existing address object or create a new one.
                // this is handled in the next block, since we do it for both new contacts and updated contacts.
            }
        }
        return addressRefreshQueue;
    }

    private List<Contact> consWhoseAddressChanged() {
        List<Contact> useCurrentAddressQueue = new List<Contact>();
        // we only support address management with HH Accounts being used
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {

            // new highest priority! if Account changes...
            if (!npspContact.accountChanged()) {
                // highest priority. if they are changing to a new Current Address, refill from it.
                if (npspContact.isCurrentAddressChanged()) {
                    useCurrentAddressQueue.add(npspContact.getRecord());
                }
            }
        }
        return useCurrentAddressQueue;
    }

    private Map<Id, Boolean> getIsOverrideByAddressId() {
        Map<Id, Boolean> isOverrideByAddressId = new Map<Id, Boolean>();
        // we only support address management with HH Accounts being used
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {

            // new highest priority! if Account changes...
            if (!npspContact.accountChanged()) {
                // highest priority. if they are changing to a new Current Address, refill from it.
                if (npspContact.isChangingToANewCurrentAddress()) {
                    // track which address's need their dates updated
                    isOverrideByAddressId.put(npspContact.currentAddress(), true);
                }
            }
        }
        return isOverrideByAddressId;
    }

    private List<Contact> consWhoseAccountChangedAndDontHaveAddressOverrides() {
        List<Contact> addressRefreshQueue = new List<Contact>();
        // we only support address management with HH Accounts being used
        for (NPSP_Contact npspContact : npspContactsInHouseholdAccounts()) {

            // new highest priority! if Account changes...
            if (npspContact.accountChanged()) {
                // if no override, refill from the Default Address
                if (isEligibleForRefresh(npspContact)) {
                    if (accountHasAddresses(npspContact.getRecord())) { //
                        // refresh address if the contact does not have one and account does
                        addressRefreshQueue.add(npspContact.getRecord());
                    }
                }
            }
        }
        return addressRefreshQueue;
    }

    private Boolean isEligibleForRefresh(NPSP_Contact npspContact) {
        return !npspContact.hasAddressOverride() && !npspContact.isAddressChanged();
    }

    private void createAddressesForContacts() {
        TDTM_Runnable.DmlWrapper dmlWrapper = new TDTM_Runnable.DmlWrapper();
        Set<Contact> addressCreationQueue = getAddressCreationQueue();
        // create any new Default Address objects
        if (addressCreationQueue.size() > 0) {
            createAddrFromConAfterInsertUpdate(new List<Contact>(addressCreationQueue), dmlWrapper);
        }
        TDTM_TriggerHandler.processDML(dmlWrapper);
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.ADDR_hasRunContactOnBefore, false);
    }

}