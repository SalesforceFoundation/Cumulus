/*
    Copyright (c) 2018, Salesforce.org
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
* @date 2018
* @group Rollups
* @group-content ../../ApexDocContent/Rollups2.htm
* @description Selector class for Rollup definition custom metadata.
*/
public inherited sharing class CRLP_Rollup_SEL {

    /** @description Platform Cache instance, if available */
    private static UTIL_PlatformCache platformCache = UTIL_PlatformCache.getInstance();
    
    /**
     * @description Private static var to cache the Custom Metadata Type records.
     * In terms of limits, these DO use up Query Rows, but NOT Queries.
     * This are testVisible to allow unit tests to mock the contents of the static var
     */
    @TestVisible
    public static List<Rollup__mdt> cachedRollups {
        get {
            if (cachedRollups == null) {
                if (platformCache.isOrgCacheAvailable) {
                    cachedRollups = (List<Rollup__mdt>)platformCache.orgCache.get(
                        CRLP_PlatformCache.RollupDefinitionsCache.class, UTIL_PlatformCache.CacheBuilderStubParameter
                    );
                } else {
                    cachedRollups = queryRollupRecords();
                }
            }
            return cachedRollups;
        }
        private set;
    }

    /**
     * @description Perform the actual query of Rollup CMDT records. Normally this should not be called
     * directly by any method, but is exposed for the CRLP_PlatformCache class.
     */
    public static List<Rollup__mdt> queryRollupRecords() {
        return [
            SELECT
                Id,
                DeveloperName,
                MasterLabel,
                Active__c,
                Use_Fiscal_Year__c,
                Description__c,
                Operation__c,
                Time_Bound_Operation_Type__c,
                Integer__c,
                Is_Deleted__c,
                Filter_Group__c,
                Filter_Group__r.MasterLabel,
                Filter_Group__r.DeveloperName,
                Summary_Object__r.QualifiedApiName,
                Summary_Object__r.Label,
                Summary_Field__r.QualifiedApiName,
                Summary_Field__r.Label,
                Detail_Object__r.QualifiedApiName,
                Detail_Object__r.Label,
                Detail_Field__r.QualifiedApiName,
                Detail_Field__r.Label,
                Amount_Object__r.QualifiedApiName,
                Amount_Object__r.Label,
                Amount_Field__r.QualifiedApiName,
                Amount_Field__r.Label,
                Date_Object__r.QualifiedApiName,
                Date_Object__r.Label,
                Date_Field__r.QualifiedApiName,
                Date_Field__r.Label
            FROM Rollup__mdt
            WHERE Is_Deleted__c = false
            ORDER BY Summary_Object__c, MasterLabel
        ];
    }

    /**
     * @description Return a simple list of all Rollup definition CMT records
     */
    public static List<Rollup__mdt> getRollupDefinitions() {
        return cachedRollups;
    }

    /**
     * @description Return a map of Rollup Definitions with a key of the Summary object
     * and a list of all rollups for each Summary object
     */
    @TestVisible
    private static Map<Schema.SObjectType, List<Rollup__mdt>> rollupsBySummaryType;
    public static Map<Schema.SObjectType, List<Rollup__mdt>> getRollupsBySummaryType() {
        if (rollupsBySummaryType == null) {
            rollupsBySummaryType = new Map<Schema.SObjectType, List<Rollup__mdt>>();
            for (Rollup__mdt rollup : cachedRollups) {
                Schema.SObjectType objType = UTIL_Describe.getObjectDescribe(rollup.Summary_Object__r.QualifiedApiName).getSObjectType();
                if (!rollupsBySummaryType.containsKey(objType)) {
                    rollupsBySummaryType.put(objType, new List<Rollup__mdt>());
                }
                rollupsBySummaryType.get(objType).add(rollup);
            }
        }
        return rollupsBySummaryType;
    }

    /**
     * @description Return a map of Rollup Definitions with a key of the Detail object and a list of
     * all rollups for each Detail object
     */
    @TestVisible
    private static Map<Schema.SObjectType, List<Rollup__mdt>> rollupsByDetailType;
    public static Map<Schema.SObjectType, List<Rollup__mdt>> getRollupsByDetailType() {
        if (rollupsByDetailType == null) {
            rollupsByDetailType = new Map<Schema.SObjectType, List<Rollup__mdt>>();
            for (Rollup__mdt rollup : cachedRollups) {
                Schema.SObjectType objType = UTIL_Describe.getObjectDescribe(rollup.Detail_Object__r.QualifiedApiName).getSObjectType();
                if (!rollupsByDetailType.containsKey(objType)) {
                    rollupsByDetailType.put(objType, new List<Rollup__mdt>());
                }
                rollupsByDetailType.get(objType).add(rollup);
            }
        }
        return rollupsByDetailType;
    }

    /**
     * @description Return a map of Rollup Definitions with a key of the FilterGroup Id and a list of
     * all rollups for each FilterGroup
     */
    @TestVisible
    private static Map<Id, List<Rollup__mdt>> rollupsByFilterGroup;
    public static Map<Id, List<Rollup__mdt>> getRollupsByFilterGroup() {
        if (rollupsByFilterGroup == null) {
            rollupsByFilterGroup = new Map<Id, List<Rollup__mdt>>();
            for (Rollup__mdt rollup : cachedRollups) {
                if (!rollupsByFilterGroup.containsKey(rollup.Filter_Group__c)) {
                    rollupsByFilterGroup.put(rollup.Filter_Group__c, new List<Rollup__mdt>());
                }
                rollupsByFilterGroup.get(rollup.Filter_Group__c).add(rollup);
            }
        }
        return rollupsByFilterGroup;
    }

    /**
     * @description Queries a single Rollup Definition using the specified DeveloperName
     * @return Record Id or null
     */
    public static Id getRollupIdByDeveloperName(String developerName) {

        for (Rollup__mdt rlp : cachedRollups) {
            if (developerName == rlp.DeveloperName) {
                return rlp.Id;
            }
        }
        return null;
    }

    /**
     * @description Returns a Map of Rollup records by Rollup Id
     * @return requested rollup__mdt
     */
    public static Map<Id, Rollup__mdt> getRollupsById() {

        Map<Id, Rollup__mdt> rollupsById = new Map<Id, Rollup__mdt>();
        for (Rollup__mdt rollup : cachedRollups) {
            rollupsById.put(rollup.Id, rollup);
        }
        return rollupsById;

    }

    /**
     * @description Queries a single Rollup Definition based on the requested Id
     * @return requested rollup__mdt
     */
    public static Rollup__mdt getRollupById(Id id) {
        return getRollupsById().get(id);
    }

    /**
     * @description Defines which Operations do not use specific fields in their processing. For example, the Count
     * operation does not need the Amount_Field__c or Detail_Field__c fields to complete. As a result, the contents
     * of these fields can be ignored when building out the dynamic query against the detail object(s).
     */
    @TestVisible
    private static final Map<SObjectField, Set<String>> UNSUPPORTED_OPERATIONS_BY_ROLLUP_FIELD = new Map<SObjectField, Set<String>> {
        Schema.Rollup__mdt.Date_Field__c => new Set<String> {}, // All Operations Supported
        Schema.Rollup__mdt.Amount_Field__c => new Set<String> {
            CRLP_Operation.RollupType.Count.name(),
            CRLP_Operation.RollupType.First.name(),
            CRLP_Operation.RollupType.Last.name()
        },
        Schema.Rollup__mdt.Detail_Field__c => new Set<String> {
            CRLP_Operation.RollupType.Sum.name(),
            CRLP_Operation.RollupType.Count.name(),
            CRLP_Operation.RollupType.Average.name(),
            CRLP_Operation.RollupType.Years_Donated.name(),
            CRLP_Operation.RollupType.Donor_Streak.name(),
            CRLP_Operation.RollupType.Best_Year.name(),
            CRLP_Operation.RollupType.Best_Year_Total.name()
        }
    };

    /**
     * @description Determines if specific Rollup.Amount, Date, or Detail__c field should be included in a query
     * of the Detail object based on the specific Rollup operation type. In the event that the field refers to a
     * field that will never be used in the rollup logic, this prevents that field from being included in the Query.
     * @param  rollup Rollup__mdt
     * @param  rollupField SObjectField of Rollup__mdt Metadata Relationship (Amount, Detail or Date field)
     * @return Returns True if the field specified by the RollupField (Detail, Amount, Date) for the Rollup Operation
     * (Sum, Count, etc.)is needed when building a query
     */
    @TestVisible
    private static Boolean shouldQueryRollupField(Rollup__mdt rollup, Schema.SObjectField rollupField) {
        return
            rollup.Operation__c != null
            && rollup.get(rollupField) != null
            && !UNSUPPORTED_OPERATIONS_BY_ROLLUP_FIELD.get(rollupField).contains(rollup.Operation__c);
    }

    /**
     * @description Creates a list of all fields for a given object that are referenced in any way on an
     *  existing Rollup. This list can be used when building a query of the needed fields to retrieve
     *  for an object.
     * @param objType The type of object to retrieve referenced fields for
     * @return List<DescribeFieldResult>
     */
    public static List<Schema.DescribeFieldResult> getReferencedFieldsByObject(SObjectType objType) {
        // Collect SObjectFields in set in case there are duplicates
        final Set<SObjectField> fields = new Set<SObjectField>();

        // Always add the AccountId and Primary_Contact__c for the Opportunity object
        if (objType == Schema.Opportunity.SObjectType) {
            fields.add(Schema.Opportunity.AccountId);
            fields.add(Schema.Opportunity.Primary_Contact__c);
        }

        if (objType != null) {
            final DescribeSObjectResult sObjectDescribe = UTIL_Describe.getObjectDescribe(objType);
            final String sObjectName = sObjectDescribe.getName();

            // Note: DescribeSObjectResult.fields.getMap() is a case-insensitive map
            final Map<String, SObjectField> fieldsByName = sObjectDescribe.fields.getMap();

            // Always include the CurrencyIsoCode field if available for the object
            if (UserInfo.isMultiCurrencyOrganization()
                && fieldsByName.get('CurrencyIsoCode') != null
            ) {
                fields.add(fieldsByName.get('CurrencyIsoCode'));
            }

            // Summary, Date, Amount, Detail Fields from cachedRollups
            for (Rollup__mdt rollup : cachedRollups) {
                if (rollup.Active__c == true) {
                    // Summary Field
                    if (rollup.Summary_Object__c != null
                        && rollup.Summary_Object__r.QualifiedApiName == sObjectName
                    ) {
                        fields.add(fieldsByName.get(rollup.Summary_Field__r.QualifiedApiName));
                    }

                    // Date Field
                    if (rollup.Date_Object__r.QualifiedApiName == sObjectName
                        && shouldQueryRollupField(rollup, Schema.Rollup__mdt.Date_Field__c)
                    ) {
                        fields.add(fieldsByName.get(rollup.Date_Field__r.QualifiedApiName));
                    }

                    // Amount Field
                    if (rollup.Amount_Object__r.QualifiedApiName == sObjectName
                        && shouldQueryRollupField(rollup, Schema.Rollup__mdt.Amount_Field__c)
                    ) {
                        fields.add(fieldsByName.get(rollup.Amount_Field__r.QualifiedApiName));
                    }

                    // Detail Field
                    if (rollup.Detail_Object__r.QualifiedApiName == sObjectName
                        && shouldQueryRollupField(rollup, Schema.Rollup__mdt.Detail_Field__c)
                    ) {
                        fields.add(fieldsByName.get(rollup.Detail_Field__r.QualifiedApiName));
                    }
                }
            }
        }

        final List<Schema.DescribeFieldResult> referencedFields = new List<Schema.DescribeFieldResult>();

        // Add fields' Describes to referencedFields
        for (SObjectField field : fields) {
            referencedFields.add(field.getDescribe());
        }

        return referencedFields;
    }

    /**
     * @description If the field describe for a given field is null, assert a false to allow for debugging
     * @param referencedFields Map<String, DescribeFieldResult>
     * @param objName Object Name
     */
    public static void validateReferencedFields(Map<String, Schema.DescribeFieldResult> referencedFields, String objName) {
        for (String field : referencedFields.keySet()) {
            if (referencedFields.get(field) == null) {
                throw new CRLP_Rollup_SVC.CRLP_Exception('Field ' + field + ' not found in allFields collection for ' + objName);
            }
        }
    }

    /**
     * @description Returns a simple comma separated string list of field names to add to a SOQL Query
     * @param objType The type of object to retrieve referenced fields for
     * @return String list of fields to append to a SOQL query
     */
    public static String getReferencedFieldsByObjectAsString(SObjectType objType) {
        List<String> names = new List<String>();
        for (DescribeFieldResult describe : getReferencedFieldsByObject(objType)) {
            names.add(describe.getName());
        }
        return String.join(names, ',');
    }

    /** @description Static cache of filtered rollups by RollupType and Applied Filter */
    private static Map<String, List<Rollup__mdt>> cachedRollupsByTypeAndFilter = new Map<String, List<Rollup__mdt>>();

    /**
     * @description Used to populate the cache with the saved value from the Batch stateful property.
     * @param rollupType Enum of the job type (AccountHardCredit, ContactHardCredit, etc.)
     * @param typeFilter Enum of the rollup filter to apply (All, DaysAgoOnly, NonDaysAgoOnly, etc.)
     * @param rollups List of Rollup__mdt records to store
     */
    public static void addRollupsToCache(
        CRLP_RollupProcessingOptions.RollupType rollupType,
        CRLP_RollupProcessingOptions.RollupTypeFilter typeFilter,
        List<Rollup__mdt> rollups
    ) {
        cachedRollupsByTypeAndFilter.put(rollupType.name() + typeFilter.name(), rollups);
    }

    /**
     * @description Return a list of Rollup__mdt records based on the Rollup Job Type (Account Hard Credit, etc.)
     * and the Rollup Type Filter (if there is one defined). This is called by each of the Rollup Job Handler
     * classes as well as the initial batch class.
     * @param rollupType Enum of the job type (AccountHardCredit, ContactHardCredit, etc.)
     * @param typeFilter Enum of the rollup filter to apply (All, DaysAgoOnly, NonDaysAgoOnly, etc.)
     * @return List<Rollup__mdt>
     */
    public static List<Rollup__mdt> getRollupDefinitionsToUse(CRLP_RollupProcessingOptions.RollupType rollupType,
            CRLP_RollupProcessingOptions.RollupTypeFilter typeFilter) {

        // If the list exists in the cache, just return it
        if (cachedRollupsByTypeAndFilter != null && cachedRollupsByTypeAndFilter.containsKey(rollupType.name() + typeFilter.name())) {
            return cachedRollupsByTypeAndFilter.get(rollupType.name() + typeFilter.name());
        }

        List<Rollup__mdt> filteredRollupCmts = new List<Rollup__mdt>();

        // Determine the correct base summary object based on the Rollup Type
        SObjectType summaryObjectType = getSummarySObjectType(rollupType);

        // Retrieve all the Rollup Definitions for the summary object
        List<Rollup__mdt> allRollupCmts = CRLP_Rollup_SEL.getRollupsBySummaryType().get(summaryObjectType);
        if (allRollupCmts != null) {
            // Loop through each Rollup__mdt and determine whether the record should be included based on the
            // Rollup Type Job AND the Type Filter if there is one.
            for (Rollup__mdt rollup : allRollupCmts) {
                if (shouldRollupDefinitionBeIncluded(rollup, rollupType, typeFilter)) {
                    filteredRollupCmts.add(rollup);
                }
            }
        }

        // Save the list in the cache
        cachedRollupsByTypeAndFilter.put(rollupType.name() + typeFilter.name(), filteredRollupCmts);
        return filteredRollupCmts;
    }

    /**
     * @description Determine if the Summary SObjectType for a given type of rollup
     * @param rollupType Enum
     * @return SObjectType (Account, Contact, GAU, RecurringDonation)
     */
    private static SObjectType getSummarySObjectType(CRLP_RollupProcessingOptions.RollupType rollupType) {
        SObjectType objectType;
        switch on (rollupType) {
            when AccountHardCredit, AccountContactSoftCredit, AccountSoftCredit {
                objectType = Account.SObjectType;
            }
            when ContactHardCredit, ContactSoftCredit {
                objectType = Contact.SObjectType;
            }
            when GAU {
                objectType = General_Accounting_Unit__c.SObjectType;
            }
            when RecurringDonations {
                objectType = npe03__Recurring_Donation__c.SObjectType;
            }
        }
        return objectType;
    }

    /**
     * @description Determine if the Rollup__mdt record is valid for the specified RollupType
     * @param Rollup__mdt CMT Record
     * @param rollupType RollupType Enum
     * @param typeFilter RollupTypeFilter Enum
     * @return True or False
     */
    private static Boolean shouldRollupDefinitionBeIncluded(Rollup__mdt rollup,
            CRLP_RollupProcessingOptions.RollupType rollupType,
            CRLP_RollupProcessingOptions.RollupTypeFilter typeFilter
    ) {

        if (rollup.Is_Deleted__c == true || rollup.Active__c == false) {
            return false;
        }

        String oppObjectName = UTIL_Describe.getObjectDescribe('Opportunity').getName();
        String pmtObjectName = UTIL_Describe.getObjectDescribe('npe01__OppPayment__c').getName();
        String pscObjectName = UTIL_Describe.getObjectDescribe(UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')).getName();
        String accSCObjectName = UTIL_Describe.getObjectDescribe(UTIL_Namespace.StrAllNSPrefix('Account_Soft_Credit__c')).getName();

        Boolean include = false;

        switch on (rollupType) {
            when AccountHardCredit, ContactHardCredit {
                include = (
                    (rollup.Detail_Object__r.QualifiedApiName == oppObjectName || rollup.Detail_Object__r.QualifiedApiName == pmtObjectName)
                    && rollup.Amount_Object__r.QualifiedApiName != pscObjectName
                    && rollup.Amount_Object__r.QualifiedApiName != accSCObjectName);
            }
            when AccountSoftCredit {
                include = (rollup.Amount_Object__r.QualifiedApiName == accSCObjectName &&
                    (rollup.Detail_Object__r.QualifiedApiName == oppObjectName || rollup.Detail_Object__r.QualifiedApiName == accSCObjectName));
            }
            when AccountContactSoftCredit, ContactSoftCredit {
                include = (rollup.Amount_Object__r.QualifiedApiName == pscObjectName);
            }
            when GAU, RecurringDonations {
                include = true;
            }
        }

        if (include) {
            if (typeFilter == CRLP_RollupProcessingOptions.RollupTypeFilter.NonDaysAgo &&
                    rollup.Time_Bound_Operation_Type__c == CRLP_Operation.TimeBoundOperationType.DAYS_BACK.name()) {
                include = false;

            } else if (typeFilter == CRLP_RollupProcessingOptions.RollupTypeFilter.DaysAgoOnly &&
                    rollup.Time_Bound_Operation_Type__c != CRLP_Operation.TimeBoundOperationType.DAYS_BACK.name()) {
                include = false;

            } else if (typeFilter == CRLP_RollupProcessingOptions.RollupTypeFilter.MembershipsOnly &&
                    !rollup.Summary_Field__r.QualifiedApiName.containsIgnoreCase('Membership')) {
                include = false;
            }
        }

        return include;
    }

}