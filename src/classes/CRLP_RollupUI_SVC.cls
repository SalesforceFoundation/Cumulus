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
* @description Lightning Component Server Controller for the Rollups UI page CRLP_Setup.
*/

public with sharing class CRLP_RollupUI_SVC {

    private static final String SUCCESS_RESPONSE = 'SUCCESS';

    @TestVisible
    private static final Set<String> fieldsToExclude = new Set<String> {
        'topinsightid',
        'topinsight',
        'activitymetricid',
        'activitymetric',
        'opportunityscoreid',
        'opportunityscore',
        'activitymetricrollupid',
        'activitymetricrollup',
        'npo02__system_custom_naming__c',
        'npe01__system_accounttype__c',
        'npe01__systemisindividual__c',
        'npe01__systemaccountprocessor__c',
        'npo02__systemhouseholdprocessor__c',
        'npo02__systemhouseholdcontactroleprocessor__c'
    };

    /*******************************************************************************************************
    * @description a class to hold only the required information from the rollup__mdt records for the rollup UI.
    */
    public class RollupTableItem {
        @AuraEnabled public String active;
        @AuraEnabled public String activeIcon;
        @AuraEnabled public String creditType;
        @AuraEnabled public String description;
        @AuraEnabled public String detailField;
        @AuraEnabled public String detailObject;
        @AuraEnabled public String displayName;
        @AuraEnabled public String filterGroupName;
        @AuraEnabled public String operation;
        @AuraEnabled public String rollupName;
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String summaryField;
        @AuraEnabled public String summaryObject;
        @AuraEnabled public String summaryObjectApiName;

    }

    /*******************************************************************************************************
    * @description a class to hold only the required information from the filter_group__mdt records for the filter group UI.
    */
    public class FilterGroupTableItem {
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public Integer countFilterRules;
        @AuraEnabled public Integer countRollups;
        @AuraEnabled public String name;
        @AuraEnabled public String recordId;
        @AuraEnabled public Boolean isDeleted;
    }

    /*******************************************************************************************************
    * @description Creates a model to collect both the RollupTableItems and the labels used on the page to minimize server trips.
    * Retrieving labels in Apex instead of lightning components avoids namespace complications.
    */
    public class RollupGridModel {
        @AuraEnabled public List<RollupTableItem> items;
        @AuraEnabled public Map<String, String> labels;
        @AuraEnabled public List<FilterGroupTableItem> filterGroups;
        @AuraEnabled public Boolean isCRLPEnabled;
        @AuraEnabled public Boolean isSystemAdminUser;

    }

    /*******************************************************************************************************
    * @description Creates a model to collect both the RollupTableItems and the labels used on the page to minimize server trips.
    * Retrieving labels in Apex instead of lightning components avoids namespace complications.
    */
    public class RollupDetailModel {
        @AuraEnabled public CRLP_RollupCMT.Rollup rollup;
        @AuraEnabled public Map<String, List<Map<String, String>>> fieldsByDataType;
        @AuraEnabled public Map<String, String> timeBoundOperations;
        @AuraEnabled public Map<String, String> operations;

    }

    /*******************************************************************************************************
    * @description Creates a model to collect both the Filter Group and Filter Rules used on the page to minimize server trips.
    * Filter rules need to be flattened for use within the lightning:datatable.
    */
    public class FilterGroupModel {
        @AuraEnabled public CRLP_RollupCMT.FilterGroup filterGroup;
        @AuraEnabled public List<CRLP_RollupCMT.FilterRule> filterRuleList;
        @AuraEnabled public Map<String,String> operators;
        @AuraEnabled public Map<String,List<Map<String,String>>> filterFieldsByDataType;

    }

    /*******************************************************************************************************
    * @description Response model returned by the getDeploymentResult() method
    */
    public class DeploymentResult {
        @AuraEnabled public Boolean completed = false;
        @AuraEnabled public RollupTableItem rollupItem;
        @AuraEnabled public FilterGroupModel filterGroupItem;
    }

    /*******************************************************************************************************
    * @description Retrieves rollup definitions and creates the rollup model.
    * @return rollup grid model
    */
    @AuraEnabled
    public static String setupRollupGrid() {
        RollupGridModel model = new RollupGridModel();

        model.labels = getAppLabels();
        model.isCRLPEnabled = Customizable_Rollup_Settings__c.getOrgDefaults().Customizable_Rollups_Enabled__c;
        model.isSystemAdminUser = STG_Panel.runningUserIsAdmin();

        //return early with just labels and CRLP enabled flag if CRLP is disabled
        if (!model.isCRLPEnabled) {
            return JSON.serialize(model);
        }

        model.items = getRollupDefinitions();
        model.filterGroups = getFilterGroupDefinitions();

        //serialize to avoid passing inner classes, which is technically unsupported
        String modelString = JSON.serialize(model);
        return modelString;
    }

    /*******************************************************************************************************
    * @description Retrieves rollup definitions and creates the rollup model. Used by the CRLP_Rollup component
    * during the init() function to retrieve and set up the LEX page for view/edit
    * @param rollupId Id of selected rollup
    * @param targetObjectNames list of target objects used in rollups
    * @param detailObjectNames list of detail objects used in rollups
    * @return String model with optional rollup and fields with data types
    */
    @AuraEnabled
    public static String setupRollupDetail(String rollupId, List<String> targetObjectNames, List<String> detailObjectNames) {
        RollupDetailModel model = new RollupDetailModel();
        String summaryField = '';

        if(!String.isEmpty(rollupId)){
            Rollup__mdt rlp = CRLP_Rollup_SEL.getRollupById(Id.valueOf(rollupId));
            model.rollup = new CRLP_RollupCMT.Rollup(rlp);
            summaryField = model.rollup.summaryField;
        }
        model.fieldsByDataType = getFieldsByDataType(summaryField, targetObjectNames, detailObjectNames);
        model.timeBoundOperations = getTimeBoundOperations();
        model.operations = getRollupOperations();

        //serialize to avoid passing inner classes, which is technically unsupported
        String modelString = JSON.serialize(model);
        return modelString;
    }

    /*******************************************************************************************************
    * @description Queries from the rollup selector to fetch all rollup__mdt records. Parses so that only the relevant
    * information is returned, and a custom RollupTableItem class is created with this information.
    * @return a list of all rollup definitions
    */
    @AuraEnabled
    public static List<RollupTableItem> getRollupDefinitions() {
        List<RollupTableItem> mdtTableList = new List<RollupTableItem>();

        List<Rollup__mdt> rollups = CRLP_Rollup_SEL.getRollupDefinitions();
        for(Rollup__mdt rlp : rollups){
            if(!rlp.Is_Deleted__c) {
                mdtTableList.add(createRollupItem(rlp));
            }
        }

        return mdtTableList;
    }

    /*******************************************************************************************************
     * @description Build a RollupTableItem wrapper for a given Rollup__mdt record
     * @param rlpm Rollup__mdt
     * @return RollupTableItem
     */
    private static RollupTableItem createRollupItem(Rollup__mdt rlp) {
        RollupTableItem item = new RollupTableItem();

        if(rlp.Summary_Object__r.QualifiedAPIName == 'Account'
                && rlp.Detail_Object__r.QualifiedAPIName == 'Opportunity') {
            if(rlp.Amount_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')
                    || rlp.Amount_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Account_Soft_Credit__c')) {
                item.creditType = Label.CRLP_SoftCredit;
            } else {
                item.creditType = Label.CRLP_HardCredit;
            }
        } else if(rlp.Summary_Object__r.QualifiedAPIName == 'Account'
                && rlp.Detail_Object__r.QualifiedAPIName == 'npe01__OppPayment__c') {
            item.creditType = Label.CRLP_HardCredit;
        } else if(rlp.Summary_Object__r.QualifiedAPIName == 'Account'
                && (rlp.Detail_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')
                    || rlp.Detail_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Account_Soft_Credit__c'))) {
            item.creditType = Label.CRLP_SoftCredit;
        } else if(rlp.Summary_Object__r.QualifiedAPIName == 'Contact'
                && rlp.Detail_Object__r.QualifiedAPIName == 'Opportunity') {
            if(rlp.Amount_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')) {
                item.creditType = Label.CRLP_SoftCredit;
            } else {
                item.creditType = Label.CRLP_HardCredit;
            }
        } else if(rlp.Summary_Object__r.QualifiedAPIName == 'Contact'
                && rlp.Detail_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')) {
            item.creditType = Label.CRLP_SoftCredit;
        } else {
            item.creditType = Label.stgNotApplicable;
        }
        item.detailObject = rlp.Detail_Object__r.QualifiedAPIName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c') ? Schema.SObjectType.Opportunity.getLabel() : rlp.Detail_Object__r.Label;
        item.summaryObject = rlp.Summary_Object__r.Label;
        item.summaryObjectApiName = rlp.Summary_Object__r.QualifiedApiName;
        item.summaryField = rlp.Summary_Field__r.Label;
        item.recordName = rlp.DeveloperName;
        item.rollupName = rlp.MasterLabel;
        item.detailField = rlp.Detail_Field__r.Label;
        item.description = rlp.Description__c;
        item.filterGroupName = rlp.Filter_Group__c == null ? System.Label.CRLP_NoFilterGroupSelected : rlp.Filter_Group__r.MasterLabel;
        item.operation = rlp.Operation__c.replace('_', ' ');
        if(rlp.Active__c){
            item.activeIcon = 'utility:check';
        } else {
            item.activeIcon = 'utility:close';
        }
        item.recordId = rlp.Id;

        if (item.summaryObjectApiName == Schema.SObjectType.General_Accounting_Unit__c.getName()) {
            item.displayName = 'GAU' + ': ' + item.summaryField;
        } else if (item.summaryObjectApiName == Schema.SObjectType.npe03__Recurring_Donation__c.getName()) {
            item.displayName = 'RD' + ': ' + item.summaryField;
        } else {
            item.displayName = item.summaryObject + ': ' + item.summaryField;
        }

        return item;
    }

    /*******************************************************************************************************
    * @description Queries from the Filter Rule selector to fetch all Filter_Group__mdt records. Parses so that only the relevant
    * information is returned, and a custom FilterGroupTableItem class is created with this information.
    * @return a list of all filter group definitions
    */
    @AuraEnabled
    public static List<FilterGroupTableItem> getFilterGroupDefinitions() {

        List<FilterGroupTableItem> mdtTableList = new List<FilterGroupTableItem>();
        List<Filter_Group__mdt> mdtList = CMT_FilterRule_SEL.getFilterGroups();
        Map<Id, List<Rollup__mdt>> rollupsByFilterGroup = CRLP_Rollup_SEL.getRollupsByFilterGroup();

        for(Integer i=0; i<mdtList.size(); i++) {
            FilterGroupTableItem item = new FilterGroupTableItem();

            item.label = mdtList[i].MasterLabel;
            item.name = mdtList[i].DeveloperName;
            item.description = mdtList[i].Description__c;
            item.countFilterRules = mdtList[i].Filter_Rules__r.size();
            item.countRollups = (rollupsByFilterGroup.containsKey(mdtList[i].Id) ? rollupsByFilterGroup.get(mdtList[i].Id).size() : 0);
            item.recordId = mdtList[i].Id;
            item.isDeleted = false;

            mdtTableList.add(item);
        }

        return mdtTableList;

    }

    /*******************************************************************************************************
    * @description Queries from the Filter Rule metadata to fetch all operation values.
    * @return a map of picklist options api values to labels
    */
    @AuraEnabled
    public static Map<String,String> getFilterRuleOperations() {

        Map<String,String> filterRuleOperations = new Map<String,String>();

        Schema.DescribeFieldResult field = Filter_Rule__mdt.Operator__c.getDescribe();

        for (Schema.PicklistEntry f : field.getPicklistValues()) {
            filterRuleOperations.put(f.getValue(), f.getLabel());
        }
        return filterRuleOperations;
    }

    /*******************************************************************************************************
    * @description Fetches a single FilterGroup__mdt record by Id and associated FilterRule__mdt records.
    * @param id the filter group ID
    * @return A serialized instance of the FilterGroupModel inner class
    */
    @AuraEnabled
    public static String setupFilterGroupDetail(String filterGroupId, List<String> objectNames) {

        Map<String,List<Map<String,String>>> objNameToFieldTypeMap = new Map<String,List<Map<String,String>>>();
        Set<String> excludedTypes = new Set<String>{'TIME', 'TEXTAREA'};

        for(String obj : objectNames){
            if (obj == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')) {
                List<String> pscFieldsToReturn = new List<String>{
                        UTIL_Namespace.StrAllNSPrefix('Role_Name__c'),
                        UTIL_Namespace.StrAllNSPrefix('Amount__c')
                };
                List<Map<String, String>> pscList = getSpecificFieldsWithType(obj, pscFieldsToReturn, false);
                objNameToFieldTypeMap.put(obj, pscList);

            } else {
                List<Map<String, String>> detailNameToFieldTypeObj = getFilterRuleFieldsExcludingTypes(obj, excludedTypes);
                objNameToFieldTypeMap.put(obj, detailNameToFieldTypeObj);
            }
        }

        FilterGroupModel model = createFilterGroupModel(filterGroupId);
        model.operators = getfilterRuleOperations();
        model.filterFieldsByDataType = objNameToFieldTypeMap;

        //serialize to avoid passing inner classes, which is technically unsupported
        String modelString = JSON.serialize(model);
        return modelString;
    }

    /*******************************************************************************************************
     * @description Build a FilterGroupModel wrapper for a given FilterGroup Id
     * @param filterGroupId
     * @return FilterGroupModel with just the FilterGroup and FilterRuleList properties populated
     */
    private static FilterGroupModel createFilterGroupModel(String filterGroupId) {
        FilterGroupModel model = new FilterGroupModel();
        model.filterRuleList = new List<CRLP_RollupCMT.FilterRule>();
        if (!String.isEmpty(filterGroupId)) {
            Filter_Group__mdt filterGroup = CMT_FilterRule_SEL.getFilterGroupsById().get(filterGroupId);
            model.filterGroup = new CRLP_RollupCMT.FilterGroup(filterGroup);

            Map<String,String> operatorMap = getfilterRuleOperations();
            for (Filter_Rule__mdt fr: CMT_FilterRule_SEL.getFilterRulesByGroup().get(filterGroup.Id)) {
                CRLP_RollupCMT.FilterRule ruleItem = new CRLP_RollupCMT.FilterRule(fr);
                ruleItem.setValueLabel();
                ruleItem.operationLabel = operatorMap.get(ruleItem.operationName);
                model.filterRuleList.add(ruleItem);
            }
        }

        return model;
    }

    /*******************************************************************************************************
    * @description Queries from the Rollup operations to fetch all rollup operation values.
    * @return a map of picklist options api values to labels
    */
    @AuraEnabled
    public static Map<String,String> getRollupOperations() {

        try {
            Map<String,String> rollupOperations = new Map<String,String>();

            Schema.DescribeFieldResult field = Rollup__mdt.Operation__c.getDescribe();

            for (Schema.PicklistEntry f : field.getPicklistValues()) {
                rollupOperations.put(f.getValue(), f.getLabel());
            }
            return rollupOperations;
        } catch (Exception ex) {
            // error retrieving the rollup operations
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Queries from the Rollup yearly operation types to fetch all yearly operation values.
    * @return a map of picklist yearly operations api values to labels
    */
    @AuraEnabled
    public static Map<String,String> getTimeBoundOperations() {
        try {
            Map<String, String> timeBoundOperations = new Map<String, String>();
            Schema.DescribeFieldResult field = Rollup__mdt.Time_Bound_Operation_Type__c.getDescribe();

            for (Schema.PicklistEntry f : field.getPicklistValues()) {
                timeBoundOperations.put(f.getValue(), f.getLabel());
            }
            return timeBoundOperations;
        } catch (Exception ex) {
            // error retrieving the timeBoundOperations
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    @description Fetches all field labels, mapped to their data types, for a list of objects.
    * @param summaryField a summary field already being used to include in the type list
    * @param targetObjectNames list of target or summary objects to query
    * @param detailObjectNames list of detail or objects to rollup to query
    * @return a map of strings to string-string maps. Map<String,Map<String,String>>
    */

    @AuraEnabled
    public static Map<String,List<Map<String,String>>> getFieldsByDataType(String summaryField, List<String> targetObjectNames, List<String> detailObjectNames) {

        try {

            Map<String, List<Map<String, String>>> objNameToFieldTypeMap = new Map<String, List<Map<String, String>>>();

            for (String detailObj : detailObjectNames) {
                if (detailObj == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')) {
                    List<String> pscFieldsToReturn = new List<String>{
                            UTIL_Namespace.StrAllNSPrefix('Role_Name__c'),
                            UTIL_Namespace.StrAllNSPrefix('Amount__c'),
                            UTIL_Namespace.StrAllNSPrefix('Id')
                    };
                    List<Map<String, String>> pscList = getSpecificFieldsWithType(detailObj, pscFieldsToReturn, true);
                    objNameToFieldTypeMap.put(detailObj, pscList);

                } else {
                    List<Map<String, String>> detailNameToFieldTypeObj = getDetailFieldsWithType(detailObj);
                    objNameToFieldTypeMap.put(detailObj, detailNameToFieldTypeObj);
                }
            }
            for (String targetObj : targetObjectNames) {
                List<Map<String, String>> summaryNameToFieldTypeObj = getTargetFieldsWithType(targetObj, summaryField);
                objNameToFieldTypeMap.put(targetObj, summaryNameToFieldTypeObj);
            }

            return objNameToFieldTypeMap;
        } catch (Exception ex) {
            // error retrieving the fields by data type
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Returns a map of field names to data types, excluding system fields; meant for detail objects
    * @param objectName the name of the object to look up
    * @return List<Map<String, String>> an object with field api names, labels and data type.
    */
    @TestVisible
    private static List<Map<String, String>> getDetailFieldsWithType(String objectName) {

        List<Map<String, String>> fieldObjectList = new List<Map<String, String>>();

        Map<String, Schema.DescribeFieldResult> objectFields = UTIL_Describe.getAllFieldsDescribe(objectName);

        String objectLabel = UTIL_Describe.getObjectLabel(objectName);

        for (Schema.DescribeFieldResult dfr : objectFields.values()) {
            if (excludeField(dfr)) {
                continue;
            }
            Map<String, String> fieldObject = new Map<String, String>();
            fieldObject.put('name', objectName+' '+dfr.name);
            fieldObject.put('label', objectLabel+': '+dfr.label);
            String fieldType = UTIL_Describe.getFieldType(objectName, dfr.name.toLowerCase());
            fieldObject.put('type', fieldType);

            if (fieldType == 'REFERENCE') {
                fieldObject.put('referenceTo', dfr.referenceTo[0].getDescribe().name);
            } else if (fieldType == 'ID') {
                fieldObject.put('referenceTo', objectName);
            }
            fieldObjectList.add(fieldObject);
        }

        return fieldObjectList;
    }

    /*******************************************************************************************************
    * @description Returns a map of field names to data types, excluding system fields
    * @param objectName the name of the object to look up
    * @param fields list of field api names to get
    * @return List<Map<String, String>> an object with field api names, labels and data type.
    */
    private static List<Map<String, String>> getSpecificFieldsWithType(String objectName, List<String> fields, Boolean concatenate) {

        //get object label and clean "Partial Soft Credit" to "Soft Credit" in a translatable way
        String pscLabel = Schema.SObjectType.Partial_Soft_Credit__c.getLabel();
        String scLabel = Label.CRLP_SoftCredit;
        String objectLabel = UTIL_Describe.getObjectLabel(objectName).replace(pscLabel,scLabel);

        List<Map<String, String>> fieldObjectList = new List<Map<String, String>>();

        for (String field : fields) {
            Map<String, String> fieldObject = new Map<String, String>();
            //this method is reused for rollups, where obj concatenation is needed, and filter groups, where it is not
            fieldObject.put('name', (concatenate ? objectName+' ' : '') + field);
            fieldObject.put('label', (concatenate ? objectLabel +': ' : '') + UTIL_Describe.getFieldLabel(objectName, field.toLowerCase()));
            String fieldType;
            //treat PSC Role as a Picklist because we actually use the OCR Role picklist values in the UI
            if (objectName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')
                    && field == UTIL_Namespace.StrAllNSPrefix('Role_Name__c')) {
                fieldType = 'picklist';
            } else {
                fieldType = UTIL_Describe.getFieldType(objectName, field.toLowerCase());
            }
            fieldObject.put('type', fieldType);

            if (fieldType == 'ID') {
                fieldObject.put('referenceTo', objectName);
            }

            fieldObjectList.add(fieldObject);
        }

        return fieldObjectList;

    }

    /*******************************************************************************************************
    * @description Fetches a list of labels for the rollups UI to avoid namespace issues within lightning components.
    * If any additional labels are required, they should be added here.
    * @return a list of all labels used in the rollups UI.
    */
    public static Map<String, String> getAppLabels() {

        PageReference settingsPage = Page.STG_SettingsManager;

            Map<String, String> labels = new Map<String,String>
            {
                'action' => Label.stgLabelActionColumn,
                'active' => Schema.Rollup__mdt.Active__c.getDescribe().getLabel(),
                'add' => Label.stgAdd,
                'advancedCustomizationHeader' => Label.CRLP_AdvancedCustomizationHeader,
                'advancedCustomizationText' => Label.CRLP_AdvancedCustomizationText,
                'amountField' => Schema.Rollup__mdt.Amount_Field__c.getDescribe().getLabel(),
                'amountObject' => Schema.Rollup__mdt.Amount_Object__c.getDescribe().getLabel(),
                'availableRollupTypes' => Label.CRLP_AvailableRollupType,
                'cancel' => Label.stgBtnCancel,
                'checkboxTrue' => Label.stgCheckboxTrue,
                'checkboxFalse' => Label.stgCheckboxFalse,
                'clone' => Label.stgBtnClone,
                'constant' => Schema.Filter_Rule__mdt.Constant__c.getDescribe().getLabel(),
                'countOf' => Label.stgCountOf,
                'createIntroHelp' => Label.CRLP_CreateRollupIntroHelpText,
                'createTargetObjectHelp' => Label.CRLP_CreateRollupTargetObjectHelpText,
                'createTargetFieldHelp' => Label.CRLP_CreateRollupTargetFieldHelpText,
                'createActiveHelp' => Label.CRLP_CreateRollupActiveHelpText,
                'createDescriptionHelp' => Label.CRLP_CreateRollupDescriptionHelpText,
                'createRollupTypeHelp' => Label.CRLP_CreateRollupTypeHelpText,
                'createFilterGroupHelp' => Label.CRLP_CreateRollupFilterGroupHelpText,
                'createOperationHelp' => Label.CRLP_CreateRollupOperationHelpText,
                'createFiscalYearHelp' => Label.CRLP_CreateRollupFiscalYearHelpText,
                'createTimeBoundHelp' => Label.CRLP_CreateRollupTimeBoundOperationHelpText,
                'createYearsHelp' => Label.CRLP_CreateRollupYearsAgoHelpText,
                'createDaysHelp' => Label.CRLP_CreateRollupDaysBackHelpText,
                'createDetailFieldHelp' => Label.CRLP_CreateRollupDetailFieldHelpText,
                'createDateFieldHelp' => Label.CRLP_CreateRollupDateFieldHelpText,
                'createAmountFieldHelp' => Label.CRLP_CreateRollupAmountFieldHelpText,
                'creditType' => Label.CRLP_CreditType,
                'crlpNotEnabledTitle' => Label.CRLP_DisabledTitle,
                'crlpNotEnabledMessage' => Label.CRLP_DisabledMessage,
                'crlpNoAccessPerms' => Label.stgEditPermissionError,
                'dateField' => Schema.Rollup__mdt.Date_Field__c.getDescribe().getLabel(),
                'dateObject' => Schema.Rollup__mdt.Date_Object__c.getDescribe().getLabel(),
                'daysBackError' => Label.CRLP_DaysBack,
                'delete' => Label.alloDeleteRow,
                'detailField' => Schema.Rollup__mdt.Detail_Field__c.getDescribe().getLabel(),
                'detailObject' => Schema.Rollup__mdt.Detail_Object__c.getDescribe().getLabel(),
                'description' => Schema.Rollup__mdt.Description__c.getDescribe().getLabel(),
                'edit' => Label.stgBtnEdit,
                'error' => Label.PageMessagesError,
                'field' => Schema.Filter_Rule__mdt.Field__c.getDescribe().getLabel(),
                'filterGroupActiveRollupsHelp' => Label.CMT_FilterGroupActiveRollupsHelpText,
                'filterGroupDeleteConfirm' => String.format(Label.CMT_DeleteConfirm, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filterGroupDeleteWarning' => Label.CMT_FilterGroupDeleteError,
                'filterGroupDescription' => Schema.Filter_Group__mdt.Description__c.getDescribe().getLabel(),
                'filterGroupDescriptionHelp' => Label.CMT_FilterGroupDescriptionHelpText,
                'filterGroupLabel' => Schema.SObjectType.Filter_Group__mdt.getLabel(),
                'filterGroupLabelPlural' => Schema.SObjectType.Filter_Group__mdt.getLabelPlural(),
                'filterGroupNew' => Label.CMT_FilterNew,
                'filterGroupNameHelp' => Label.CMT_FilterGroupNameHelpText,
                'filterGroupNameLimitError' => Label.CMT_FilterGroupNameLimitError,
                'filterRuleDeleteWarning' => Label.CMT_FilterRuleDeleteWarning,
                'filterRuleDeleteConfirm' => String.format(Label.CMT_DeleteConfirm, new List<String>{Schema.SObjectType.Filter_Rule__mdt.getLabel()}),
                'filterRuleDuplicate' => Label.CMT_FilterRuleDuplicateError,
                'filterRuleFieldMissing' => Label.CMT_FilterRuleFieldsMissing,
                'filterRuleHelpText' => Label.CMT_FilterRulesHelpText,
                'filterRuleLabel' => Schema.SObjectType.Filter_Rule__mdt.getLabel(),
                'filterRuleLabelPlural' => Schema.SObjectType.Filter_Rule__mdt.getLabelPlural(),
                'filterRuleValueHelp' => Label.CMT_FilterRulesValueHelpText,
                'filtersDeleteProgress' => String.format(System.Label.CRLP_DeleteProgress, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersDeleteSuccess' => String.format(System.Label.CRLP_DeleteSuccess, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersDeleteFail' => String.format(System.Label.CRLP_DeleteError, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersDeleteTimeout' => String.format(System.Label.CRLP_DeleteTimeout, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersDisplayError' => String.format(System.Label.CRLP_DisplayError, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersSaveProgress' => String.format(System.Label.CRLP_SaveProgress, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersSaveSuccess' => String.format(System.Label.CRLP_SaveSuccess, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersSaveFail' => String.format(System.Label.CRLP_SaveError, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'filtersSaveTimeout' => String.format(System.Label.CRLP_SaveTimeout, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'hardCredit' => Label.CRLP_HardCredit,
                'info' => Label.PageMessagesInfo,
                'integer' => Schema.Rollup__mdt.Integer__c.getDescribe().getLabel(),
                'labelAccount' => Schema.SObjectType.Account.getLabel(),
                'labelAccountSoftCredit' => Schema.SObjectType.Account_Soft_Credit__c.getLabel(),
                'labelAllocation' => Schema.SObjectType.Allocation__c.getLabel(),
                'labelContact' => Schema.SObjectType.Contact.getLabel(),
                'labelContactSoftCredit' => Schema.SObjectType.Contact.getLabel()+' '+Label.CRLP_SoftCredit,
                'labelGAU' => Schema.SObjectType.General_Accounting_Unit__c.getLabel(),
                'labelPayment' => Schema.SObjectType.npe01__OppPayment__c.getLabel(),
                'labelOpportunity' => Schema.SObjectType.Opportunity.getLabel(),
                'labelPartialSoftCredit' => Schema.SObjectType.Partial_Soft_Credit__c.getLabel(),
                'labelRD' => Schema.SObjectType.npe03__Recurring_Donation__c.getLabel(),
                'labelBooleanTrue' => System.Label.labelBooleanTrue,
                'labelBooleanFalse' => System.Label.labelBooleanFalse,
                'labelMissingRequired' => System.Label.commonMissingRequiredFields,
                'name' => Label.stgLabelName,
                'namespacePrefix' => UTIL_Namespace.StrTokenNSPrefix(''),
                'na' => Label.stgNotApplicable,
                'next' => Label.labelListViewNext,
                'noFields' => Label.stgLabelPaymentMapNoValidFields,
                'noDetailFieldsMessage' => Label.CRLP_NoAvailableDetailFieldsMessage,
                'noTargetFieldsMessage' => Label.CRLP_NoAvailableTargetFieldsMessage,
                'noObjects' => String.format(Label.stgNoObjectsFound, new List<String>{Schema.Filter_Rule__mdt.Object__c.getDescribe().getLabel().toLowerCase()}),
                'noFilterGroups' => String.format(Label.stgNoObjectsFound, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabelPlural()}),
                'noFilterGroupSelect' => Label.CRLP_NoFilterGroupSelected,
                'noFilterRules' => String.format(Label.stgNoObjectsFound, new List<String>{Schema.SObjectType.Filter_Rule__mdt.getLabelPlural()}),
                'noRollups' => String.format(Label.stgNoObjectsFound, new List<String>{Schema.SObjectType.Rollup__mdt.getLabelPlural()}),
                'object' => Schema.Filter_Rule__mdt.Object__c.getDescribe().getLabel(),
                'objectAccount' => Schema.SObjectType.Account.getName(),
                'objectAccountSoftCredit' => Schema.SObjectType.Account_Soft_Credit__c.getName(),
                'objectAllocation' => Schema.SObjectType.Allocation__c.getName(),
                'objectContact' => Schema.SObjectType.Contact.getName(),
                'objectGAU' => Schema.SObjectType.General_Accounting_Unit__c.getName(),
                'objectPayment' => Schema.SObjectType.npe01__OppPayment__c.getName(),
                'objectOpportunity' => Schema.SObjectType.Opportunity.getName(),
                'objectPartialSoftCredit' => Schema.SObjectType.Partial_Soft_Credit__c.getName(),
                'objectRD' => Schema.SObjectType.npe03__Recurring_Donation__c.getName(),
                'ok' => Label.stgLabelOK,
                'operation' => Schema.Rollup__mdt.Operation__c.getDescribe().getLabel(),
                'operator' => Schema.Filter_Rule__mdt.Operator__c.getDescribe().getLabel(),
                'picklistLabelLastYear' => Label.stgLabelYearPicklistLastYear,
                'picklistLabelThisYear' => Label.stgLabelYearPicklistThisYear,
                'pleaseWait' => Label.CRLP_PleaseWait,
                'returnNPSP' => String.format(Label.CRLP_Return, new List<String>{Label.lblNPSPSettings}),
                'returnFilterGroup' => String.format(Label.CRLP_Return, new List<String>{Schema.SObjectType.Filter_Group__mdt.getLabel()}),
                'rollupLabel' => Schema.SObjectType.Rollup__mdt.getLabel(),
                'rollupLabelPlural' => Schema.SObjectType.Rollup__mdt.getLabelPlural(),
                'rollupNew' => Label.CRLP_RollupNew,
                'rollupsByFilterGroup' => Label.CRLP_RollupsByFilterGroup,
                'rollupSummaryTitle' => Label.CRLP_RollupSummary,
                'rollupType' => Label.CRLP_RollupType,
                'rollupDeleteConfirm' => String.format(Label.CMT_DeleteConfirm, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupDeleteProgress' => String.format(System.Label.CRLP_DeleteProgress, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupDeleteSuccess' => String.format(System.Label.CRLP_DeleteSuccess, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupDeleteFail' => String.format(System.Label.CRLP_DeleteError, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupDeleteTimeout' => String.format(System.Label.CRLP_DeleteTimeout, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupDisplayError' => String.format(System.Label.CRLP_DisplayError, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupSaveProgress' => String.format(System.Label.CRLP_SaveProgress, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupSaveSuccess' => String.format(System.Label.CRLP_SaveSuccess, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupSaveFail' => String.format(System.Label.CRLP_SaveError, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'rollupSaveTimeout' => String.format(System.Label.CRLP_SaveTimeout, new List<String>{Schema.SObjectType.Rollup__mdt.getLabel()}),
                'save' => Label.stgBtnSave,
                'saveAndNew' => Label.lvlBtnSaveAndNew,
                'selectOne' => Label.stgSelectOne,
                'selectAll' => Label.conMergeSelectAll,
                'softCredit' => Label.CRLP_SoftCredit,
                'success' => Label.PageMessagesConfirm,
                'summaryField' => Schema.Rollup__mdt.Summary_Field__c.getDescribe().getLabel(),
                'summaryObject' => Schema.Rollup__mdt.Summary_Object__c.getDescribe().getLabel(),
                'timeBoundOperationType' => Schema.Rollup__mdt.Time_Bound_Operation_Type__c.getDescribe().getLabel(),
                'useFiscalYear' => Schema.Rollup__mdt.Use_Fiscal_Year__c.getDescribe().getLabel(),
                'urlNamespacePrefix' => settingsPage.getUrl(),
                'unknownError' => Label.stgUnknownError,
                'view' => Label.stgLabelView,
                'warning' => Label.PageMessagesWarning
            };

        for (Integer i = 2; i < 21; i++) {
            String key = 'picklistLabelYearsAgo' + i;
            String value = String.format(Label.stgLabelYearPicklistYearsAgo, new List<String>{String.valueOf(i)});
            labels.put(key, value);
        }

        return labels;
    }

    /*******************************************************************************************************
     * @description Handle the save (insert/update/delete) of a Rollup__mdt record
     * @param jsonRollup Stringified structure of a CRLP_RollupCMT.Rollup wrapper class
     * @return {JobId}-{DeveloperName} - ASync Job Id - Developer name of the newly inserted or updated
     * record; or an error message. The {DeveloperName} value can be used by the JS to retrieve the record after
     * the insert (deployment) completes.
     */
    @AuraEnabled
    public static String saveRollup(String jsonRollup) {
        try {
            // For new records, the RecordName property will be null by default. The process of deploying the
            // CMT data will generate a unique RecordName to use for the new record.
            CRLP_RollupCMT.Rollup cmtRollup = (CRLP_RollupCMT.Rollup) JSON.deserialize(jsonRollup, CRLP_RollupCMT.Rollup.class);

            if (cmtRollup.isDuplicate()) {
                throw new RollupException(Label.CRLP_DuplicateTargetField);
            }

            List<CRLP_RollupCMT.Rollup> rollups = new List<CRLP_RollupCMT.Rollup>{cmtRollup};
            CRLP_EnablementService.RollupMetadataHandler changeHandler = new CRLP_ApiService()
                .sendChangeEvent(rollups)
                .getCallbackHandler();

            CRLP_ConfigBuilder_SVC.queueRollupConfigForDeploy(rollups);
            String jobId = CRLP_ConfigBuilder_SVC.deployedQueuedMetadataTypes(changeHandler, changeHandler.params);

            // Return the unique record DeveloperName value of the Rollup__mdt record
            return jobId + '-' + cmtRollup.recordName;

        } catch (Exception ex) {
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP);
            throw new AuraHandledException('ERROR: ' + ex.getMessage());
        }
    }

    /*******************************************************************************************************
     * @description Handle the save (insert/update) of a Rollup__mdt record
     * @param jsonFilterGroup Stringified structure of a CRLP_RollupCMT.FilterGroup wrapper class
     * @return {JobId}-{DeveloperName} - ASync Job Id - Developer name of the newly inserted or updated
     * record; or an error message. The {DeveloperName} value can be used by the JS to retrieve the record after
     * the insert (deployment) completes.
     */
    @AuraEnabled
    public static String saveFilterGroupAndRules(String jsonFilterGroup) {
        try {
            // For new records, the RecordName property will be null by default. The process of deploying the
            // CMT data will generate a unique RecordName to use for the new record.
            CRLP_RollupCMT.FilterGroup cmtFilterGroup = (CRLP_RollupCMT.FilterGroup) JSON.deserialize(jsonFilterGroup, CRLP_RollupCMT.FilterGroup.class);

            if (cmtFilterGroup.isDeleted == true) {
                Map<Id, List<Rollup__mdt>> rollupsByFilterGroup = CRLP_Rollup_SEL.getRollupsByFilterGroup();
                Integer countRollups = rollupsByFilterGroup.containsKey(cmtFilterGroup.recordId) ? rollupsByFilterGroup.get(cmtFilterGroup.recordId).size() : 0;

                if (countRollups > 0) {
                    throw new RollupException(Label.CMT_FilterGroupDeleteError);
                }
            }

            // Queue up the deployment
            List<CRLP_RollupCMT.FilterGroup> filterGroups = new List<CRLP_RollupCMT.FilterGroup>{cmtFilterGroup};
            CRLP_EnablementService.RollupMetadataHandler changeHandler = new CRLP_ApiService()
                .sendChangeEvent(filterGroups)
                .getCallbackHandler();

            CRLP_ConfigBuilder_SVC.queueRollupConfigForDeploy(filterGroups);
            String jobId = CRLP_ConfigBuilder_SVC.deployedQueuedMetadataTypes(changeHandler, changeHandler.params);

            // Return the unique record DeveloperName value of the FilterGroup__mdt record
            return jobId + '-' + cmtFilterGroup.recordName;
        } catch (Exception ex) {
            ERR_Handler.processError(ex, ERR_Handler_API.Context.CRLP);
            throw new AuraHandledException('ERROR: ' + ex.getMessage());
        }
    }

    /*******************************************************************************************************
     * @description When a new Rollup record is inserted, the page will only have a unique DeveloperName value to match
     * the record. However, to re-load the record and allow for editing we need to have the actual record Id.
     * This method queries for the DeveloperName and returns the record Id (if there is a match) or null
     * @param jobId CMT Deployment Job Id to check the status for
     * @param recordName Rollup__mdt.DeveloperName to query for if the job has completed
     * @param objectType 'Rollup' or 'Filter'
     * @return DeploymentResult
     */
    @AuraEnabled
    public static String getDeploymentStatus(String jobId, String recordName, String objectType, String mode) {
        try {
            Customizable_Rollup_Settings__c crs = UTIL_CustomSettingsFacade.getCustomizableRollupSettings();
            if (crs.CMT_API_Status__c != null) {
                Map<String, String> deploymentStatus = (Map<String, String>) JSON.deserialize(crs.CMT_API_Status__c, Map<String, String>.class);
                if (deploymentStatus.containsKey(jobId)) {
                    String result = deploymentStatus.get(jobId);
                    if (result == Metadata.DeployStatus.Succeeded.name()) {
                        DeploymentResult response = new DeploymentResult();
                        if (objectType == 'Rollup') {
                            Id rollupId = CRLP_Rollup_SEL.getRollupIdByDeveloperName(recordName);
                            response.completed = true;
                            if (mode != 'delete') {
                                response.rollupItem = createRollupItem(CRLP_Rollup_SEL.getRollupById(rollupId));
                            }
                        } else if (objectType == 'Filter') {
                            Id groupId = CMT_FilterRule_SEL.getFilterGroupIdByDeveloperName(recordName);
                            response.completed = true;
                            if (mode != 'delete') {
                                response.filterGroupItem = createFilterGroupModel(groupId);
                            }
                        }
                        return JSON.serialize(response);

                    } else {

                        // If there is an error, parse the message to remove the metadata recordname leaving just the error message itself
                        List<String> errors = result.split('\n');
                        String errMsg = '';
                        for (String er : errors) {
                            if (er.contains('>')) {
                                er = er.split('>')[1];
                                errMsg += er + '\n';
                            }
                        }
                        throw new RollupException(!String.isEmpty(errMsg) ? errMsg : result);
                    }
                }
            }
        } catch (Exception ex) {
            // error retrieving the metadata record
            throw new AuraHandledException(ex.getMessage());
        }
        return null;
    }

    /*******************************************************************************************************
    * @description Finds picklist values or record types for the constant field.
    * @param objectName the name of the object to look up
    * @param selectedField the name of the selected summary field.
    * @return List<Map<String, String>> a list of mapped name to label options.
    */
    @AuraEnabled
    public static List<Map<String, String>> getFilterRuleConstantPicklistOptions(String objectName, String selectedField) {

        try {
            List<Map<String, String>> optionsList = new List<Map<String, String>>();
            List<SelectOption> picklistValues = new List<SelectOption>();

            if (objectName == UTIL_Namespace.StrAllNSPrefix('Partial_Soft_Credit__c')
                    && selectedField == UTIL_Namespace.StrAllNSPrefix('Role_Name__c')) {
                optionsList = UTIL_Describe.getLightningSelectOptions('OpportunityContactRole', 'Role');
            } else if (selectedField != 'RecordTypeId') {
                optionsList = UTIL_Describe.getLightningSelectOptions(objectName, selectedField);
            } else {
                Schema.SObjectType sObjectType = UTIL_Describe.getSObjectType(objectName);
                optionsList = UTIL_RecordTypes.getRecordTypeDevNamesForLightningSelectList(sObjectType);
            }
            return optionsList;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Returns a map of field names to data types, excluding system, deleted and other non-value fields
    * @param objectName the name of the object to look up
    * @param excludedTypes set of types not included in the returned list
    * @return List<Map<String, String>> an object with field api names, labels and data type.
    */
    public static List<Map<String, String>> getFilterRuleFieldsExcludingTypes(String objectName, Set<String> excludedTypes) {

        List<Map<String, String>> fieldObjectList = new List<Map<String, String>>();

        Map<String, Schema.DescribeFieldResult> objectFields = UTIL_Describe.getAllFieldsDescribe(objectName);
        Set<String> excludedFields = new Set<String>{'ConnectionReceivedId', 'ConnectionSentId', 'IsDeleted', 'IsSplit', 'Fiscal', 'FiscalQuarter', 'FiscalYear', 'ForecastCategoryName', 'SyncedQuoteID'};

        for (Schema.DescribeFieldResult dfr : objectFields.values()) {
            String type = dfr.getType().Name();
            if(!dfr.name.toLowerCase().contains('__system') && !excludedTypes.contains(type) && !excludedFields.contains(dfr.name)) {
                Map<String, String> fieldObject = new Map<String, String>();
                fieldObject.put('name', dfr.name);
                fieldObject.put('label', dfr.label);
                fieldObject.put('type', type);

                fieldObjectList.add(fieldObject);
            }
        }

        return fieldObjectList;
    }

    /*******************************************************************************************************
    * @description Finds writable, custom, unused target fields of specific types to provide field lists for Rollup definitions.
    *              Includes an exception for a set summary field on the rollup detail.
    * @param objectName the name of the object to look up
    * @param selectedField the name of a summary field already in use
    * @return List<Map<String, String>> an object with field api names, labels and data type.
    */
    private static List<Map<String, String>> getTargetFieldsWithType(String objectName, String selectedField) {

        List<Map<String, String>> fieldObjectList = new List<Map<String, String>>();

        Map<String, Schema.DescribeFieldResult> objectFields = UTIL_Describe.getAllFieldsDescribe(objectName);
        Schema.SObjectType sobjType = UTIL_Describe.getSObjectType(objectName);
        List<Schema.DescribeFieldResult> referencedFields = CRLP_Rollup_SEL.getReferencedFieldsByObject(sobjType);
        Set<Schema.DescribeFieldResult> referencedFieldSet = new Set<Schema.DescribeFieldResult>(referencedFields);
        Set<String> validTypeSet = new Set<String>{'CURRENCY', 'DATE', 'DATETIME', 'DOUBLE', 'INTEGER', 'MULTIPICKLIST', 'PERCENT', 'PICKLIST', 'REFERENCE', 'STRING', 'TEXTAREA'};

        for (Schema.DescribeFieldResult dfr : objectFields.values()) {
            //valid types are taken from the DisplayType Enum and only include values that make sense to roll up
            String fieldType = UTIL_Describe.getFieldType(objectName, dfr.name.toLowerCase());
            Boolean isValidType = validTypeSet.contains(fieldType);

            //check that target field isn't being used on another rollup
            Boolean isRolledUp = referencedFieldSet.contains(dfr);

            if (( isValidType
                    && !isRolledUp
                     && isTargetFieldAllowed(objectName,dfr))
                    || selectedField.equals(dfr.name)) {
                Map<String, String> fieldObject = new Map<String, String>();
                fieldObject.put('name', dfr.name);
                fieldObject.put('label', dfr.label);
                fieldObject.put('type', fieldType);

                if (fieldType == 'REFERENCE') {
                    fieldObject.put('referenceTo', dfr.referenceTo[0].getDescribe().name);
                }


                fieldObjectList.add(fieldObject);
            }
        }

        return fieldObjectList;
    }

    /******************************************************************************************************************
    * @description Checks that a given field is allowed as a target field
    * @param objectName the name of the object
    * @param dfr the DescribeFieldResult of the field
    * @return Boolean
    /*****************************************************************************************************************/
    public static Boolean isTargetFieldAllowed(String objectName, Schema.DescribeFieldResult dfr) {

        if(!dfr.isUpdateable()
                || !dfr.isCustom()
                || dfr.name.toLowerCase().contains('__system')
                || dfr.name.contains('Latitude__s')
                || dfr.name.contains('Longitude__s')) {
            return false;
        }

        Map<String,Set<String>> bannedFieldsByObject = new Map<String,Set<String>>();

        // BAN ALL NPSP FIELDS ON RD EXCEPT THE FOUR CORE ROLLUP FIELDS
        bannedFieldsByObject.put('npe03__Recurring_Donation__c',new Set<String>{'npe03__Amount__c'
                ,'npe03__Recurring_Donation_Campaign__c'
                ,'npe03__Contact__c'
                ,'npe03__Date_Established__c'
                ,'npe03__Donor_Name__c'
                ,'npe03__Installment_Amount__c'
                ,'npe03__Installment_Period__c'
                ,'npe03__Installments__c'
                ,'npe03__Open_Ended_Status__c'
                ,'npe03__Organization__c'
                ,'npe03__Schedule_Type__c'
                ,'npe03__Total__c'
                ,UTIL_Namespace.StrAllNSPrefix('Always_Use_Last_Day_Of_Month__c')});

        // add more objects here as needed with their banned fields

        if (bannedFieldsByObject.containsKey(objectName) && bannedFieldsByObject.get(objectName).contains(dfr.name)) {
            return false;
        }

        return true;

    }

    /***
    * @description Checks if the given field name is not system and einstein insights fields
    * @param dfr the DescribeFieldResult of the field
    * @return Boolean
    */
    private static Boolean excludeField(Schema.DescribeFieldResult dfr) {
        return fieldsToExclude.contains(dfr.name.toLowerCase());
    }

    public class RollupException extends Exception {}

}