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
* @date 2011
* @group Households
* @description Controls generation of household names for lists of households
* NOTE: This class handles both household naming for the Household__c object
* as well as for HH Account objects.
*/
public without sharing class HouseholdNamingService {

    private HouseholdSettings settings = new HouseholdSettings();

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

    @TestVisible
    private UnitOfWork unitOfWork {
        get {
            if (unitOfWork == null) {
                unitOfWork = new UnitOfWork();
            }
            return unitOfWork;
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

    /*******************************************************************************************************
    * @description turns off household naming in the current execution context.  provided for other
    * components, like Batch Data Import, to momentarily turn off the household naming logic.  there is no
    * direct way to do that by disabling TDTM trigger handlers, or using existing static flags.
    * @param disable True to disable, False to enable
    * @return void
    */
    private static Boolean isHouseholdNamingDisabled = false;
    public static void disableHouseholdNaming(Boolean disable) {
        isHouseholdNamingDisabled = disable;
    }

    public void updateHouseholdNameAndMemberCountAsync(List<Id> hhids) {
       updateHouseholdNameAndMemberCountAsynchronously(hhids);
    }

    /*******************************************************************************************************
    * @description future method to update the household names for the specified households
    * @param hhids the list of household Id's (either Household__c or Account Id's)
    * @return void
    */
    @future
    public static void updateHouseholdNameAndMemberCountAsynchronously(List<Id> hhids) {
        //set our process control to avoid recursive updating on household records
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.HH, true);
        HouseholdNamingService householdNamingService = new HouseholdNamingService();
        householdNamingService.updateHouseholdNameAndMemberCount(hhids);
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.HH, false);
    }

    /*******************************************************************************************************
    * @description Sets Number_Of_Household_Members__c, and
    * it will be responsible for only updating names if the advanced household naming is true.
    * So any code that used to check for advanced household naming should no longer do so,
    * (unless it is only for a naming scenario that would possibly change number of household members.)
    * @param householdOrAccountIds the list of household Id's (either Household__c or Account Id's)
    * @return void
    */
    public void updateHouseholdNameAndMemberCount(List<Id> householdOrAccountIds) {
        if (isHouseholdNamingDisabled) {
            return;
        }
        //we need this turned on to prevent recursive triggering on household creation
        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.HH, true);

        List<SObject> householdsOrAccounts = householdsOrAccountsFor(householdOrAccountIds);
        Map<Id, List<Contact>> membersByHouseholdId =
                getHouseholdMembersByHouseholdId(householdOrAccountIds);
        setHouseholdNameFieldValues(householdsOrAccounts, membersByHouseholdId);
        setNumberOfHouseholdMembers(householdsOrAccounts, membersByHouseholdId);
        unitOfWork.save();

        TDTM_ProcessControl.setRecursionFlag(TDTM_ProcessControl.flag.HH, false);
    }

    private void save(List<SObject> householdsOrAccounts) {
        if (!householdsOrAccounts.isEmpty()) {
            UTIL_DMLService.updateRecords(householdsOrAccounts);
        }
    }

    private void setNumberOfHouseholdMembers(List<SObject> householdsOrAccounts, Map<Id, List<Contact>> membersByHouseholdId) {
        for (SObject household : householdsOrAccounts) {
            List<Contact> members = membersByHouseholdId.get(idFor(household));
            if (numberOfHouseholdMembersIsIncorrect(household, members)) {
                refreshNumberOfHouseholdMembers(household, members);
                unitOfWork.registerDirty(new List<SObject>{household});
            }
        }
    }

    private void refreshNumberOfHouseholdMembers(SObject household, List<Contact> members) {
        household.put(UTIL_Namespace.StrTokenNSPrefix('Number_of_Household_Members__c'),
                members != null ? members.size() : 0);
    }

    private Boolean numberOfHouseholdMembersIsIncorrect(SObject household, List<Contact> householdMembers) {
        if (householdMembers != null) {
            return household.get('Number_of_Household_Members__c') != householdMembers.size();
        } else {
            return false;
        }
    }

    private void setHouseholdNameFieldValues(List<SObject> householdsOrAccounts,
            Map<Id, List<Contact>> membersByHouseholdId) {
        for (SObject household : householdsOrAccounts) {
            List<Contact> householdMembers =
                    membersByHouseholdId.get(idFor(household)) == null ?
                            new List<Contact>() :
                            membersByHouseholdId.get(idFor(household));
            if (settings.isAdvancedHouseholdNaming()) {
                setNameFieldValuesOnHousehold(
                        household,
                        new HouseholdName(
                                new Contacts(householdMembers),
                                householdNamingImpl));
            }
        }
    }

    private Map<Id, List<Contact>> getHouseholdMembersByHouseholdId(List<Id> householdOrAccountIds) {
        return householdMembersByHouseholdId(
                contactSelector.householdMembersFor(householdOrAccountIds));
    }

    private List<SObject> householdsOrAccountsFor(List<Id> householdOrAccountIds) {
        List<SObject> hhupdatelist = new List<SObject>();
        hhupdatelist.addAll(getHouseholdsFor(householdOrAccountIds));
        hhupdatelist.addAll(getAccountsFor(householdOrAccountIds));
        return hhupdatelist;
    }

    private List<SObject> getAccountsFor(List<Id> hhids) {
        return [
                SELECT Id, Name, npo02__SYSTEM_CUSTOM_NAMING__c, npo02__Formal_Greeting__c,
                        npo02__Informal_Greeting__c, Number_of_Household_Members__c
                FROM Account
                WHERE Id IN :hhids
        ];
    }

    private List<SObject> getHouseholdsFor(List<Id> hhids) {
        return [
                SELECT Id, Name, npo02__SYSTEM_CUSTOM_NAMING__c, npo02__Formal_Greeting__c,
                        npo02__Informal_Greeting__c, Number_of_Household_Members__c
                FROM Npo02__Household__c
                WHERE Id IN :hhids
        ];
    }

    private Id idFor(SObject household) {
        return String.valueOf(household.get('Id'));
    }

    private Map<Id, List<Contact>> householdMembersByHouseholdId(List<Contact> contacts) {
        Map<Id, List<Contact>> hhIDContactMap = new Map<Id, List<Contact>>();
        for (Contact con : contacts) {
            if (!hhIDContactMap.containskey(con.hhId__c)) {
                hhIDContactMap.put(con.hhId__c, new List<Contact>{
                        con
                });
            } else {
                List<Contact> clist = hhIDContactMap.get(con.hhId__c);
                clist.add(con);
            }
        }
        return hhIDContactMap;
    }


    /*******************************************************************************************************
    * @description Returns Contact fields specified in the Household Naming Settings format fields.
    * @return Set<String> If the Automatic Household Naming is enabled, return set of Contact field API names;
    * otherwise, an empty set
    */
    //Todo: move to Household Settings?
    public Set<String> getHouseholdNamingContactFields() {
        if (!settings.isAdvancedHouseholdNaming()
                || householdNamingImpl.setHouseholdNameFieldsOnContact() == null) {
            return new Set<String>();
        } else {
            return householdNamingImpl.setHouseholdNameFieldsOnContact();
        }
    }

    /*******************************************************************************************************
    * @description the class object that supports the HH_INaming interface
    */
    HH_INaming householdNamingImpl {
        get {
            if (householdNamingImpl == null) {
                String implementingClass = new HouseholdSettings().getImplementingClass();

                Type classType = Type.forName(implementingClass);
                if (classType != null) {
                    Object classInstance = classType.newInstance();
                    if (classInstance instanceof HH_INaming) {
                        householdNamingImpl = (HH_INaming) classInstance;
                    }
                }
            }
            return householdNamingImpl;
        }
        set;
    }

    /*******************************************************************************************************
    * @description executes the batch job to update all household names
    * @param isActivation whether this is being called when npo02__Advanced_Household_Naming__c is being turned on
    * @return void
    */
    public static void refreshAllHouseholdNaming(Boolean isActivation) {
        // the household batch expects a list of Contact's with just Id, LastName, HHId__c available.
        String strSoql = 'SELECT Id, LastName, ' + UTIL_Namespace.StrTokenNSPrefix('HHId__c') + ' FROM Contact WHERE ' +
                UTIL_Namespace.StrTokenNSPrefix('HHId__c') + ' != NULL ';
        HH_HouseholdNaming_BATCH batch = new HH_HouseholdNaming_BATCH(strSoql, isActivation);
        Id batchProcessId = database.executeBatch(batch, getBatchSize());
    }

    private static Integer getBatchSize() {
        return 200;
    }

    private Boolean needsNamingFieldsUpdated(SObject household, SObject oldRecord) {
        if (needsNameReplaced(household)) {
            return true;
        } else if (needsInformalGreetingReplaced(household)) {
            return true;
        } else if (needsFormalGreetingReplaced(household)) {
            return true;
        } else if (isSystemCustomNamingChanged(household, oldRecord)) {
            return true;
        } else if (oneToOneAccountChanged(household, oldRecord)) {
            return true;
        }
        return false;
    }

    private Boolean oneToOneAccountChanged(SObject household, SObject oldRecord) {
        return isAccount(household) && isOneToOneContactChanged(household, oldRecord);
    }

    private Boolean isAccount(SObject household) {
        return household.getSObjectType() == Account.sObjectType;
    }

    private Boolean needsFormalGreetingReplaced(SObject household) {
        return formalGreetingFor(household) == nameReplacementText();
    }

    private Boolean needsInformalGreetingReplaced(SObject household) {
        return informalGreetingFor(household) == nameReplacementText();
    }

    private Boolean needsNameReplaced(SObject household) {
        return nameFor(household) == nameReplacementText();
    }

    private Object formalGreetingFor(SObject household) {
        return household.get('npo02__Formal_Greeting__c');
    }

    private Object informalGreetingFor(SObject household) {
        return household.get('npo02__Informal_Greeting__c');
    }

    private Object nameFor(SObject household) {
        return household.get('Name');
    }

    private Boolean isOneToOneContactChanged(SObject household, SObject oldRecord) {
        return household.get('npe01__One2OneContact__c') != oldRecord.get('npe01__One2OneContact__c');
    }

    private Boolean isSystemCustomNamingChanged(SObject household, SObject oldRecord) {
        return household.get('npo02__SYSTEM_CUSTOM_NAMING__c') !=
                oldRecord.get('npo02__SYSTEM_CUSTOM_NAMING__c');
    }

    public List<Id> getHouseholdsNeedingNameUpdates(List<SObject> records,
            Map<Id, SObject> oldMap) {
        List<Id> hhList = new List<Id>();
        for (SObject household : records) {
            if (needsNamingFieldsUpdated(household, oldMap.get(household.Id))) {
                hhList.add(household.Id);
            }
        }
        return hhList;
    }

    public void setCustomNamingField(List<SObject> records, Map<Id, SObject> oldMap) {
        for (SObject household : records) {
            SObject oldRecord = oldMap.get(household.Id);
            setCustomNamingStringValue(household, oldRecord);
        }
    }

    public void setNameAndGreetingsToReplacementText(List<SObject> records) {
        for (SObject household : records) {
            setNameAndGreetingsToReplacementText(household);
        }
    }

    public void setNameFieldValuesOnHousehold(SObject household, HouseholdName householdName) {
        HouseholdNamingUserControlledFields namingOverrides =
                new HouseholdNamingUserControlledFields(namingOverridesFor(household));
        if (!namingOverrides.isNameControlledByUser() &&
                nameNeedsUpdate(household, householdName)) {
            setName(household, householdName);
            unitOfWork.registerDirty(new List<SObject>{
                    household
            });
        }

        if (!namingOverrides.isFormalGreetingControlledByUser() &&
                formalGreetingNeedsUpdate(household, householdName)) {
            setFormalGreeting(household, householdName);
            unitOfWork.registerDirty(new List<SObject>{
                    household
            });
        }
        if (!namingOverrides.isInformalGreetingControlledByUser() &&
                informalGreetingNeedsUpdate(household, householdName)) {
            setInformalGreeting(household, householdName);
            unitOfWork.registerDirty(new List<SObject>{
                    household
            });
        }
    }

    private Boolean informalGreetingNeedsUpdate(SObject household, HouseholdName householdName) {
        return !addressService.equalsCaseSensitive(
                (String) household.get('npo02__Informal_Greeting__c'),
                householdName.asInformalGreeting());
    }

    private Boolean formalGreetingNeedsUpdate(SObject household, HouseholdName householdName) {
        return !addressService.equalsCaseSensitive(
                (String) household.get('npo02__Formal_Greeting__c'),
                householdName.asFormalGreeting());
    }

    private Boolean nameNeedsUpdate(SObject household, HouseholdName householdName) {
        return !addressService.equalsCaseSensitive(
                (String) household.get('Name'),
                householdName.asName());
    }

    private void setInformalGreeting(SObject household, HouseholdName householdName) {
        household.put('npo02__Informal_Greeting__c', householdName.asInformalGreeting());
    }

    private void setFormalGreeting(SObject household, HouseholdName householdName) {
        household.put('npo02__Formal_Greeting__c', householdName.asFormalGreeting());
    }

    private void setName(SObject household, HouseholdName householdName) {
        household.put('Name', householdName.asName());
    }

    private void replaceHouseholdFormalGreeting(SObject household) {
        household.put('npo02__Formal_Greeting__c', nameReplacementText());
    }

    private void replaceHouseholdInformalGreeting(SObject household) {
        household.put('npo02__Informal_Greeting__c', nameReplacementText());
    }

    private void replaceHouseholdName(SObject household) {
        household.put('Name', nameReplacementText());
    }

    private void setNameAndGreetingsToReplacementText(SObject household) {
        if (isNameReplaceable(household)) {
            replaceHouseholdName(household);
        }

        if (isInformalGreetingReplaceable(household)) {
            replaceHouseholdInformalGreeting(household);
        }

        if (isFormalGreetingReplaceable(household)) {
            replaceHouseholdFormalGreeting(household);
        }
    }

    private Boolean isNameReplaceable(SObject household) {
        return isReplaceable(household, 'Name');
    }

    private Boolean isFormalGreetingReplaceable(SObject household) {
        return isReplaceable(household, 'npo02__Formal_Greeting__c');
    }

    private Boolean isInformalGreetingReplaceable(SObject household) {
        return isReplaceable(household, 'npo02__Informal_Greeting__c');
    }

    private Boolean isReplaceable(SObject household, String fieldApiName) {
        String fieldValue = (String) household.get(fieldApiName);
        return fieldValue == null || fieldValue == '' || fieldValue == nameReplacementText();
    }

    private void setCustomNamingStringValue(SObject household, SObject oldRecord) {
        HouseholdNamingUserControlledFields userControlledNamingFields =
                new HouseholdNamingUserControlledFields(household, oldRecord);
        household.put('npo02__SYSTEM_CUSTOM_NAMING__c',
                userControlledNamingFields.asConcatenatedString());
    }

    private String namingOverridesFor(SObject household) {
        return (String) household.get
                ('npo02__SYSTEM_CUSTOM_NAMING__c');
    }

    private String nameReplacementText() {
        return System.Label.npo02.NameReplacementText;
    }
}