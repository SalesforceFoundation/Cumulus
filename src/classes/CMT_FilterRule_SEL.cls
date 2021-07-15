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
* @group CMT Filter Rules
* @description Selector class for FilterGroups and FilterRule Custom Metadata Type objects
*/
public without sharing class CMT_FilterRule_SEL {

    /** @description Platform Cache instance, if available */
    private static UTIL_PlatformCache platformCache = UTIL_PlatformCache.getInstance();

    /**
     * @description Private static vars to cache the Custom Metadata Type records.
     * In terms of limits, these DO use up Query Rows, but NOT Queries.
     * These are testVisible to allow unit tests to mock the contents of these static vars
     */
    @TestVisible
    private static List<Filter_Group__mdt> cachedFilterGroups {
        get {
            if (cachedFilterGroups == null) {
                if (platformCache.isOrgCacheAvailable) {
                    cachedFilterGroups = (List<Filter_Group__mdt>)platformCache.orgCache.get(
                        CRLP_PlatformCache.FilterGroupDefinitionsCache.class, UTIL_PlatformCache.CacheBuilderStubParameter
                    );
                } else {
                    cachedFilterGroups = queryFilterGroupRecords();
                }
            }
            return cachedFilterGroups;
        } private set;
    }

    @TestVisible
    private static List<Filter_Rule__mdt> cachedFilterRules {
        get {
            if (cachedFilterRules == null) {
                if (platformCache.isOrgCacheAvailable) {
                    cachedFilterRules = (List<Filter_Rule__mdt>)platformCache.orgCache.get(
                        CRLP_PlatformCache.FilterGroupDefinitionsCache.class, UTIL_PlatformCache.CacheBuilderStubParameter
                    );
                } else {
                    cachedFilterRules = queryFilterRuleRecords();
                }
            }
            return cachedFilterRules;
        }
        private set;
    }

    /**
     * @description Perform the actual query of FilterGroup CMDT records. Normally this should not be called
     * directly by any method, but is exposed for the CRLP_PlatformCache class.
     */
    public static List<Filter_Group__mdt> queryFilterGroupRecords() {
        return [SELECT Id, MasterLabel, DeveloperName, Description__c, Is_Deleted__c,
                    (SELECT Id, Is_Deleted__c FROM Filter_Rules__r WHERE Is_Deleted__c = false)
                FROM Filter_Group__mdt
                WHERE Is_Deleted__c = false
                ORDER BY MasterLabel
            ];
    }

    /**
     * @description Perform the actual query of FilterGroup CMDT records. Normally this should not be called
     * directly by any method, but is exposed for the CRLP_PlatformCache class.
     */
    public static List<Filter_Rule__mdt> queryFilterRuleRecords() {
        return [SELECT Id, MasterLabel, DeveloperName, Filter_Group__r.DeveloperName,
                    Filter_Group__c, Field__r.QualifiedApiName, Field__r.MasterLabel, Is_Deleted__c,
                    Object__r.QualifiedApiName, Object__r.MasterLabel, Operator__c, Constant__c
                FROM Filter_Rule__mdt
                WHERE Is_Deleted__c = false
                ORDER BY Filter_Group__c
            ];
    }

    /**
     * @description Returns a map of List<FilterRule> by FilterGroupId
     * @return Map<Id, List<Filter_Rule__mdt>>
     */
    public static Map<Id, List<Filter_Rule__mdt>> getFilterRulesByGroup() {
        Map<Id, List<Filter_Rule__mdt>> rulesByGroupId = new Map<Id, List<Filter_Rule__mdt>>();
        for (Filter_Group__mdt fg : cachedFilterGroups) {
            List<Filter_Rule__mdt> rules = new List<Filter_Rule__mdt>();
            for (Filter_Rule__mdt fr : cachedFilterRules) {
                if (fr.Filter_Group__c == fg.Id) {
                    rules.add(fr);
                }
            }
            rulesByGroupId.put(fg.Id, rules);
        }
        return rulesByGroupId;
    }

    /**
     * @description Returns a Map of Filter Group records by FilterGroupId
     * @return Map<Id, Filter_Group__mdt>
     */
    public static Map<Id, Filter_Group__mdt> getFilterGroupsById() {
        Map<Id, Filter_Group__mdt> filterGroupsById = new Map<Id, Filter_Group__mdt>();
        for (Filter_Group__mdt fg : cachedFilterGroups) {
            filterGroupsById.put(fg.Id, fg);
        }
        return filterGroupsById;
    }

    /**
     * @description Queries a single Rollup Definition using the specified DeveloperName
     * @return Record Id or null
     */
    public static Id getFilterGroupIdByDeveloperName(String developerName) {

        for (Filter_Group__mdt fg : cachedFilterGroups) {
            if (developerName == fg.DeveloperName) {
                return fg.Id;
            }
        }
        return null;

    }

    /**
     * @description Creates a list of all fields for a given object that are referenced in any way on an
     *  existing FilterRule. This list can be used when building a query of the needed fields to retrieve
     *  for an object.
     * @param objType The type of object to retrieve referenced fields for
     * @return List<DescribeFieldResult>
     */
    public static List<Schema.DescribeFieldResult> getReferencedFieldsByObject(SObjectType objType) {
        String objName = UTIL_Describe.getObjectDescribe(objType).getName();

        // Get all field describes from the cache
        Map<String, Schema.DescribeFieldResult> allFields = UTIL_Describe.getAllFieldsDescribe(objName);
        Map<String, Schema.DescribeFieldResult> referencedFields = new Map<String, Schema.DescribeFieldResult>();

        // For all filter rules (regardless of the filter group)
        for (Filter_Rule__mdt fr : cachedFilterRules) {
            // Does the object match the requested object?
            if (fr.Object__r.QualifiedApiName == objName) {
                // Get the target field name and add to the map of fields
                String fldName = fr.Field__r.QualifiedApiName.toLowerCase();
                if (allFields.containsKey(fldName)) {
                    referencedFields.put(fr.Field__c, allFields.get(fldName));
                } else {
                    throw new CRLP_Rollup_SVC.CRLP_Exception('Field ' + fldName + ' not found in allFields collection for ' + objName);
                }
            }
        }
        // Always include the CurrencyIsoCode field if it's available for the object
        if (UserInfo.isMultiCurrencyOrganization() && allFields.containsKey('currencyisocode')) {
            referencedFields.put('CurrencyIsoCode', allFields.get('currencyisocode'));
        }
        CRLP_Rollup_SEL.validateReferencedFields(referencedFields, objName);
        return referencedFields.values();
    }

    /**
     * @description Returns a simple comma separated string list of field names to add to a SOQL Query
     * @param objType The type of object to retrieve referenced fields for
     * @return String list of fields to append to a SOQL query
     */
    public static String getReferencedFieldsByObjectAsString(SObjectType objType) {
        String soql = '';
        for (DescribeFieldResult dfr : getReferencedFieldsByObject(objType)) {
            soql += dfr.getName() + ',';
        }
        return soql.removeEnd(',');
    }

    /**
    * @description Return a simple list of all Filter Group definition CMT records
    */
    public static List<Filter_Group__mdt> getFilterGroups() {
        return cachedFilterGroups;
    }

    /**
    * @description Return a simple list of all Filter Rule definition CMT records
    */
    public static List<Filter_Rule__mdt> getFilterRules() {
        return cachedFilterRules;
    }
}