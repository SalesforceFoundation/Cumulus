({
    /**
     *  @description: resets values and visibility for objects based on the object details
     * this is run when the page is first loaded or when a cancel event resets the page
     */
    setObjectAndFieldDependencies: function (cmp) {
        //TODO: need to reset fields to populate the selected objects -- refactor to see if necessary
        //fields can be lazy loaded if user is creating a new rollup
        if (cmp.get("v.mode") !== 'create') {
            this.fieldSetup(cmp);
        } else {
            //set active default as true
            cmp.set("v.activeRollup.isActive", true);
            // check for a summary object filter to see if summary fields need to be set
            var summaryObject = cmp.get("v.activeRollup.summaryObject");
            var summaryObjects = cmp.get("v.summaryObjects");
            var label = this.retrieveFieldLabel(summaryObject, summaryObjects);

            //sets summary object if it's being passed from the container
            if (summaryObject) {
                this.onChangeSummaryObject(cmp, summaryObject, label);
            }
            this.hideAllFields(cmp);
            this.setIntegerYearList(cmp);
        }

        //update filter group list to contain null as a first option
        //note: unshift can't be used here due to an issue with bound values
        var filterGroups = cmp.get("v.filterGroups");
        var tempList = [{ "name": "", "label": cmp.get("v.labels.noFilterGroupSelect") }];
        tempList = tempList.concat(filterGroups);
        cmp.set("v.filterGroups", tempList);
    },

    /**
     * @description: changes field visibility and save button access based on the mode
     * this is bound to a change handler to the mode attribute
     */
    changeMode: function (cmp) {
        var mode = cmp.get("v.mode");
        //we check to see if mode is null since the change handler is called when mode is cleared in the container
        if (mode) {
            //View is the only readOnly mode. Clone removes the activeRollupId for save.
            //Create hides all fields and sets isIncomplete to disable the save button.
            if (mode === "view") {
                cmp.set("v.isReadOnly", true);
            } else if (mode === "clone") {
                cmp.set("v.activeRollupId", null);
                cmp.set("v.activeRollup.recordId", null);
                cmp.set("v.activeRollup.recordName", null);
                cmp.set("v.isReadOnly", false);
                //reset summary fields, clear current summary field, and rerender rollup name
                this.resetFields(cmp, cmp.get("v.activeRollup.summaryObject"), "summary");
                cmp.set("v.activeRollup.summaryField", null);
                this.updateRollupName(cmp);
                cmp.set("v.isIncomplete", true);
            } else if (mode === "edit") {
                cmp.set("v.isReadOnly", false);
                cmp.set("v.isIncomplete", false);
            } else if (mode === "create") {
                cmp.set("v.isIncomplete", true);
                cmp.set("v.isReadOnly", false);
                this.hideAllFields(cmp);
            } else if (mode === "delete") {
                this.toggleModal(cmp);
            }
        }
    },

    /**
     * @description: applies the correct labels for all underlying API values and resets allowed values
     * this is run when the page is first loaded or when a cancel event resets the page
     */
    fieldSetup: function (cmp) {
        this.resetAllFields(cmp);
        this.updateAllowedOperations(cmp);
        this.onChangeOperation(cmp, cmp.get("v.activeRollup.operation"));
        this.setIntegerYearList(cmp);
        this.onChangeTimeBoundOperationsOptions(cmp, false);
        this.onChangeInteger(cmp, cmp.get("v.activeRollup.intValue"));
        this.updateRollupName(cmp);
    },

    /**
     * @description: filters a picklist of fields by their type
     * @param typeList: list of types to match
     * @param allFields: list of mapped fields to their type to filter
     * @return: the filtered list of values
     */
    filterFieldsByType: function (cmp, typeList, allFields, summaryFieldReferenceTo) {
        //if type is null, no detail field is selected
        var newFields = [];

        if (typeList && allFields) {
            typeList.forEach(function (type) {
                if (!(type === undefined || type === null)) {
                    allFields.forEach(function (field) {
                        if (field !== undefined) {
                            //field.type is the detail field
                            //type is the target field
                            if (type === 'REFERENCE') { //rolling up into a lookup field
                                if (field.type === 'REFERENCE' || field.type === 'ID') { // possible detail fields are IDs and other lookup fields because they store IDs
                                    if (summaryFieldReferenceTo && (field.referenceTo === summaryFieldReferenceTo)) { // make sure the referenced objects match
                                        newFields.push(field);
                                    }
                                }
                            } else if (field.type === type) {
                                newFields.push(field);
                            } else if (((type === 'PICKLIST' || type === 'MULTIPICKLIST') && field.type === 'STRING') ||
                                (type === 'STRING' && (field.type === 'PICKLIST' || field.type === 'MULTIPICKLIST')) ||
                                ((type === 'PICKLIST' || type === 'MULTIPICKLIST') && (field.type === 'PICKLIST' || field.type === 'MULTIPICKLIST'))) {
                                // matching picklists and multipicklists as strings because strings and picklists are interchangeable for rolling up
                                newFields.push(field);
                            }
                        }
                    });
                }
            });
        }

        if (typeList.length > 1) {
            //sort here as well if multiple types are converging into one list
            newFields = this.sortFields(newFields);
        }

        return newFields;
    },

    /**
     * @description: filters possible detail fields by summary type and updates the detailFields attribute
     * @param potentialDetailObjects: list of potential detail objects for this rollup type
     * @param isOnChange: flag to note if this is on change. Only set from onChangeRollupType.
     */
    filterDetailFieldsBySummaryField: function (cmp, potentialDetailObjects, isOnChange) {

        //current version filters strictly; update will include type conversion fields
        var summaryField = cmp.get("v.activeRollup.summaryField");

        //need to get all detail fields, or we filter on a subset of all options
        var allFields = [];
        for (var i = 0; i < potentialDetailObjects.length; i++) {
            var objectFields = cmp.get("v.objectDetails")[potentialDetailObjects[i]];
            allFields = allFields.concat(objectFields);
        }
        var newFields = [];

        //loop over all summary fields to get the type of selected field
        var summaryFields = cmp.get("v.summaryFields");
        var field = this.retrieveFieldTypeAndReferenceTo(cmp, summaryField, summaryFields);
        var type;
        var summaryFieldReferenceTo;
        if (field) {
            type = field.type;
            summaryFieldReferenceTo = field.referenceTo;
        }

        //TODO: maybe check if type is the same to see if need to filter?
        //if type is undefined, return all fields
        if (type === undefined || allFields === undefined) {
            newFields = allFields;
            //allow rolling up of text area fields to string fields and vice versa
        } else if (type === 'TEXTAREA' || type === 'STRING') {
            newFields = this.filterFieldsByType(cmp, ['TEXTAREA', 'STRING'], allFields, summaryFieldReferenceTo);
        } else {
            newFields = this.filterFieldsByType(cmp, [type], allFields, summaryFieldReferenceTo);
        }

        //clear detail field on change
        if (isOnChange) {
            cmp.set("v.activeRollup.detailField", null);
        }

        cmp.set("v.detailFields", newFields);
    },

    /**
     * @description: gets list of potential detail objects based on the amount object.
     * accommodates for soft credits having multiple potential detail objects.
     * @return: list of potential detail objects
     */
    getPotentialDetailObjects: function (cmp, amountObject) {
        var labels = cmp.get("v.labels");
        var potentialDetailObjects = [];

        potentialDetailObjects.push(amountObject);

        if (amountObject === labels.objectPartialSoftCredit
            || amountObject === labels.objectAllocation
            || amountObject === labels.objectAccountSoftCredit
        ) {
            potentialDetailObjects.push(labels.objectOpportunity);
        }

        return potentialDetailObjects;
    },

    /**
     * @description: hides all fields but the summary view with the renderMap var to walk user through a create rollup flow
     */
    hideAllFields: function (cmp) {
        var renderMap = cmp.get("v.renderMap");
        for (var key in renderMap) {
            renderMap[key] = false;
        }
        cmp.set("v.renderMap", renderMap);
    },

    /**
     * @description: resets the detail object, description, all picklist fields, and rollup types when summary object is changed
     * @param summaryObject: summaryObject API name
     * @param label: summaryObject API label
     */
    onChangeSummaryObject: function (cmp, summaryObject, label) {
        this.resetFields(cmp, summaryObject, 'summary');
        cmp.set("v.activeRollup.summaryField", null);
        cmp.set("v.activeRollup.summaryObjectLabel", label);
        cmp.set("v.activeRollup.description", null);
        cmp.set("v.activeRollup.detailObject", null);
        cmp.set("v.activeRollup.detailField", null);
        cmp.set("v.activeRollup.amountField", null);
        cmp.set("v.activeRollup.dateField", null);

        this.resetRollupTypes(cmp);

        //sets rollup type automatically if there is only 1
        var rollupTypes = cmp.get("v.rollupTypes");
        if (rollupTypes.length === 1 && label) {
            cmp.set("v.activeRollup.rollupTypeObject", rollupTypes[0].name);
            cmp.set("v.selectedRollupType", { label: rollupTypes[0].label, name: rollupTypes[0].name });
            this.onChangeRollupType(cmp, rollupTypes[0].name, rollupTypes[0].label);
        } else {
            cmp.set("v.selectedRollupType", { name: '', label: '' });
            cmp.set("v.activeRollup.rollupTypeObject", '');
            this.onChangeRollupType(cmp, '', '');
        }

        this.onChangeSummaryField(cmp, '', '');
    },
    /**
     * @description: Updates date SObject and field
     * @param dateObjectAndField: String containing date SObject and field name
     * @param fieldLabel: New date field label
     */
    onChangeDateField: function (cmp, dateObjectAndField, fieldLabel) {
        var objectName = dateObjectAndField.split(' ')[0];

        //date object is in the *detail* objects list
        var objectLabel = this.retrieveFieldLabel(objectName, cmp.get("v.detailObjects"));

        cmp.set("v.activeRollup.dateFieldLabel", fieldLabel);
        cmp.set("v.activeRollup.dateObject", objectName);
        cmp.set("v.activeRollup.dateObjectLabel", objectLabel);
    },

    /**
     * @description: sets the detail field label and determines if save button may illuminate since detail field is required if visible
     * @param detailObjectAndField: selected detail object and field API names, concatenated with a space
     * @param fieldLabel: selected detail field label
     */
    onChangeDetailField: function (cmp, detailObjectAndField, fieldLabel) {
        var stringList = detailObjectAndField.split(' ');
        var objectName = stringList[0];

        var objectLabel = this.retrieveFieldLabel(objectName, cmp.get("v.detailObjects"));
        cmp.set("v.activeRollup.detailFieldLabel", fieldLabel);
        cmp.set("v.activeRollup.detailObject", objectName);
        cmp.set("v.activeRollup.detailObjectLabel", objectLabel);
        this.verifyRollupSaveActive(cmp, detailObjectAndField);
    },

    /**
     * @description: sets the filter group master label when the filter group is changed
     * @param label: filter group label
     */
    onChangeFilterGroup: function (cmp, label) {
        cmp.set("v.activeRollup.filterGroupLabel", label);
    },

    /**
     * @description: stores the selected years back integer value for years to be used when the page is in view mode
     * @param value: integer value
     */
    onChangeInteger: function (cmp, value) {
        var renderMap = cmp.get("v.renderMap");
        if (renderMap["integerYears"]) {
            var integerList = cmp.get("v.integerList");
            //need to convert value to an integer due to strict comparison in retrieveFieldLabel
            var label = this.retrieveFieldLabel(parseInt(value), integerList);
            cmp.set("v.selectedIntegerLabel", label);
        } else {
            cmp.set("v.selectedIntegerLabel", "");
        }
    },

    /**
     * @description: conditionally renders the time bound operation, use fiscal year, amount, date and detail fields
     * @param operation: operation API name
     */
    onChangeOperation: function (cmp, operation) {
        var renderMap = cmp.get("v.renderMap");
        var rollupTypeLabel = cmp.get("v.selectedRollupType").label;

        //TIME BOUND OPERATION DEFAULT AND RENDERING
        if (!cmp.get("v.activeRollup.timeBoundOperationType")) {
            cmp.set("v.activeRollup.timeBoundOperationType", 'All_Time');
            var timeBoundLabel = this.retrieveFieldLabel('All_Time', cmp.get("v.timeBoundOperations"));
            cmp.set("v.selectedTimeBoundOperationLabel", timeBoundLabel);
        }
        if (operation) {
            if (operation !== 'Donor_Streak' && operation !== 'Years_Donated'
                && operation !== 'Best_Year' && operation !== 'Best_Year_Total') {
                renderMap["timeBoundOperationType"] = true;
            } else {
                renderMap["timeBoundOperationType"] = false;
                renderMap["integerDays"] = false;
                renderMap["integerYears"] = false;
            }
            renderMap["rollupType"] = true;
            this.renderAndResetFilterGroup(cmp, rollupTypeLabel);
        } else {
            if (cmp.get("v.mode") === 'create') {
                renderMap["timeBoundOperationType"] = false;
                cmp.set("v.activeRollup.timeBoundOperationType", '');
                this.onChangeTimeBoundOperationsOptions(cmp, true, '');
                renderMap["rollupType"] = false;
                this.renderAndResetFilterGroup(cmp, '');
            }
        }

        //AMOUNT, DATE & DETAIL FIELD RENDERING
        //require rollup label to render advanced fields
        renderMap = this.renderAmountField(cmp, operation, rollupTypeLabel, renderMap);
        renderMap = this.renderDateField(cmp, rollupTypeLabel, renderMap);
        renderMap = this.renderDetailField(cmp, operation, rollupTypeLabel, renderMap);
        renderMap = this.renderFiscalYear(cmp, renderMap);

        cmp.set("v.renderMap", renderMap);

        //set selected operation label to be available in view mode
        var operations = cmp.get("v.operations");
        var label = operations[operation];
        cmp.set("v.selectedOperationLabel", label);

        var amountObject = cmp.get("v.activeRollup.amountObject");
        if (amountObject) {
            //reset allowed amount fields because percents and num/curr are tricky based on operation
            this.resetFields(cmp, amountObject, 'amount');
            //clear the amount field if it's no longer available based on new operation
            var amountFieldLabel = this.retrieveFieldLabel(cmp.get("v.activeRollup.amountField"), cmp.get("v.amountFields"));
            if (!amountFieldLabel) {
                cmp.set("v.activeRollup.amountField", null);
                cmp.set("v.activeRollup.amountFieldLabel", '');
                //set intelligent default if previously selected amount is unavailable
                this.setDefaultAmount(cmp, cmp.get("v.labels"), amountObject);
            }
        }

        //check that detail field and rollup type have been populated before saving
        this.verifyRollupSaveActive(cmp, cmp.get("v.activeRollup.detailField"));

    },

    /**
     * @description: renders filter group and operation, resets fields for the amount, detail and date fields based on the detail object
     * @param rollupTypeObject: rollup type object
     * @param rollupTypeLabel: rollup type label
     */
    onChangeRollupType: function (cmp, rollupTypeObject, rollupTypeLabel) {
        var renderMap = cmp.get("v.renderMap");
        var labels = cmp.get("v.labels");
        var activeRollup = cmp.get("v.activeRollup");

        var amountObjectName = rollupTypeObject;
        var potentialDetailObjects = this.getPotentialDetailObjects(cmp, amountObjectName);
        this.filterDetailFieldsBySummaryField(cmp, potentialDetailObjects, true);

        cmp.set("v.selectedRollupType", { label: rollupTypeLabel, name: rollupTypeObject });
        this.renderAndResetFilterGroup(cmp, rollupTypeLabel);

        //reset amount fields
        this.resetFields(cmp, amountObjectName, 'amount');
        cmp.set("v.activeRollup.amountObject", amountObjectName);
        this.setDefaultAmount(cmp, labels, amountObjectName);

        var detailObjects = cmp.get("v.detailObjects");
        cmp.set("v.activeRollup.amountObjectLabel", this.retrieveFieldLabel(amountObjectName, detailObjects));

        this.resetDateFields(cmp, rollupTypeObject);

        //set date object label and api name based on the selected detail object then reset fields + selected value
        var dateFieldName;
        if (rollupTypeObject === labels.objectPayment) {
            cmp.set("v.activeRollup.dateObjectLabel", labels.labelPayment);
            cmp.set("v.activeRollup.dateObject", labels.objectPayment);
            dateFieldName = labels.objectPayment + ' npe01__Payment_Date__c';
        } else {
            cmp.set("v.activeRollup.dateObjectLabel", labels.labelOpportunity);
            cmp.set("v.activeRollup.dateObject", labels.objectOpportunity);
            dateFieldName = labels.objectOpportunity + ' CloseDate';
        }

        var dateFields = cmp.get("v.dateFields");
        var dateFieldLabel = this.retrieveFieldLabel(dateFieldName, dateFields);
        cmp.set("v.activeRollup.dateFieldLabel", dateFieldLabel);
        cmp.set("v.activeRollup.dateField", dateFieldName);

        //AMOUNT, DATE & DETAIL FIELD RENDERING
        //require rollup label to render advanced fields
        renderMap = this.renderAmountField(cmp, activeRollup.operation, rollupTypeLabel, renderMap);
        renderMap = this.renderDateField(cmp, rollupTypeLabel, renderMap);
        renderMap = this.renderDetailField(cmp, activeRollup.operation, rollupTypeLabel, renderMap);

        cmp.set("v.renderMap", renderMap);

        //check if save button can be activated
        this.verifyRollupSaveActive(cmp, activeRollup.detailField);

    },

    /**
     * @description: renders rollupType field, filters allowed operations by field type when summary field changes
     * @param label: summary field label
     */
    onChangeSummaryField: function (cmp, value, label) {
        //toggle rendering for create flow
        if (cmp.get("v.mode") === 'create' || cmp.get("v.mode") === 'clone') {
            var renderMap = cmp.get("v.renderMap");
            if (value) {
                renderMap["description"] = true;
                renderMap["operation"] = true;
            } else {
                renderMap["description"] = false;
                renderMap["operation"] = false;
            }
            cmp.set("v.renderMap", renderMap);
            cmp.set("v.activeRollup.operation", '');
            this.onChangeOperation(cmp, '');
        }

        //reset operation if selected operation isn't in the list
        this.updateAllowedOperations(cmp);
        var operationLabel = this.retrieveFieldLabel(cmp.get("v.activeRollup.operation"), cmp.get("v.allowedOperations"));
        if (!operationLabel) {
            cmp.set("v.activeRollup.operation", '');
            this.onChangeOperation(cmp, '');
        }

        var amountObject = cmp.get("v.activeRollup.amountObject");
        if (amountObject) {
            var potentialDetailObjects = this.getPotentialDetailObjects(cmp, amountObject);
            this.filterDetailFieldsBySummaryField(cmp, potentialDetailObjects);

            //reset detail and amount fields if not in the new lists
            var detailFieldLabel = this.retrieveFieldLabel(cmp.get("v.activeRollup.detailField"), cmp.get("v.detailFields"));
            if (!detailFieldLabel) {
                cmp.set("v.activeRollup.detailField", null);
                cmp.set("v.activeRollup.detailFieldLabel", '');
            }

            //reset amount fields for change between double/currency and percent, then reset amount field if not in the new list
            this.resetFields(cmp, amountObject, 'amount');
            var amountFieldLabel = this.retrieveFieldLabel(cmp.get("v.activeRollup.amountField"), cmp.get("v.amountFields"));
            if (!amountFieldLabel) {
                cmp.set("v.activeRollup.amountField", null);
                cmp.set("v.activeRollup.amountFieldLabel", '');
                //set intelligent default if previously selected amount is unavailable
                this.setDefaultAmount(cmp, cmp.get("v.labels"), amountObject);
            }
        }

        this.updateRollupName(cmp);
        cmp.set("v.activeRollup.summaryFieldLabel", label);
    },

    /**
     * @description: fires when time bound operations options is changed or when set up
     * @param isOnChange: determines if this is fired during a change (true) or during setup (false)
     * @param label: time bound operations label
     */
    onChangeTimeBoundOperationsOptions: function (cmp, isOnChange, label) {
        var operation = cmp.get("v.activeRollup.timeBoundOperationType");
        var renderMap = cmp.get("v.renderMap");
        if (operation === 'All_Time') {
            //disable fiscal year, disable integer, and reset values
            renderMap["integerDays"] = false;
            renderMap["integerYears"] = false;
            if (isOnChange) {
                cmp.set("v.activeRollup.useFiscalYear", cmp.get("v.cachedRollup.useFiscalYear"));
                cmp.set("v.activeRollup.intValue", cmp.get("v.cachedRollup.intValue"));
                this.onChangeInteger(cmp, 0);
            }
        } else if (operation === 'Years_Ago') {
            //enable fiscal year and integerYears
            renderMap["integerDays"] = false;
            renderMap["integerYears"] = true;
            //set a default integer of 0
            if (isOnChange) {
                cmp.set("v.activeRollup.intValue", 0);
                this.onChangeInteger(cmp, 0);
            }
        } else if (operation === 'Days_Back') {
            //disable fiscal year and enable integerDays
            renderMap["integerDays"] = true;
            renderMap["integerYears"] = false;
            //set a default integer of 0 and the default fiscal year
            if (isOnChange) {
                cmp.set("v.activeRollup.useFiscalYear", cmp.get("v.cachedRollup.useFiscalYear"));
                cmp.set("v.activeRollup.intValue", 0);
                this.onChangeInteger(cmp, 0);
            }
        } else {
            //default to not showing these fields and reset values
            renderMap["integerDays"] = false;
            renderMap["integerYears"] = false;
            if (isOnChange) {
                cmp.set("v.activeRollup.useFiscalYear", cmp.get("v.cachedRollup.useFiscalYear"));
                cmp.set("v.activeRollup.intValue", cmp.get("v.cachedRollup.intValue"));
                this.onChangeInteger(cmp, 0);
            }
        }
        renderMap = this.renderFiscalYear(cmp, renderMap);
        //check to display or clear the dateField for Years_Ago or Days_Back
        var rollupLabel = cmp.get("v.selectedRollupType").label;
        renderMap = this.renderDateField(cmp, rollupLabel, renderMap);

        cmp.set("v.renderMap", renderMap);

        //set selected operation to be available in view mode
        var timeBoundOperations = cmp.get("v.timeBoundOperations");
        if (label === undefined) {
            label = this.retrieveFieldLabel(operation, timeBoundOperations);
        }
        cmp.set("v.selectedTimeBoundOperationLabel", label);
    },

    /**
     * @description: conditionally render filter group. During create, visibility of filter group is toggled
     * @param rollupTypeLabel: label of the set rollup type
     */
    renderAndResetFilterGroup: function (cmp, rollupTypeLabel) {
        var renderMap = cmp.get("v.renderMap");
        if (cmp.get("v.mode") === "create") {
            if (rollupTypeLabel) {
                renderMap["filterGroup"] = true;
            } else {
                renderMap["filterGroup"] = false;
            }
            cmp.set("v.activeRollup.filterGroup", '');
            this.onChangeFilterGroup(cmp, cmp.get("v.labels.noFilterGroupSelect"));
            cmp.set("v.renderMap", renderMap);
        }
    },

    /**
     * @description: conditionally render amount field based on the selected operation
     * @param operation: operation API name
     * @param rollupLabel: label of the selected rollup type passed to ensure a rollup type is not null
     * @param renderMap: current map of fields to render
     * @return: updated render map
     */
    renderAmountField: function (cmp, operation, rollupLabel, renderMap) {
        if ((operation === 'Largest'
            || operation === 'Smallest'
            || operation === 'Best_Year'
            || operation === 'Best_Year_Total'
            || operation === 'Sum'
            || operation === 'Average')
            && rollupLabel) {

            //enable amount field
            renderMap["amountField"] = true;

            //show warning if no fields available and amount field displayed
            var amountFields = cmp.get("v.amountFields");
            if (amountFields.length === 0) {
                var labels = cmp.get("v.labels");
                cmp.set("v.isIncomplete", true);
                this.showToast(cmp, 'warning', labels.noFields, '');
            }

        } else {
            //disable amount field
            renderMap["amountField"] = false;
        }
        return renderMap;
    },

    /**
     * @description: conditionally render date field based on the selected operation and rollup selection
     * @param operation: operation API name
     * @param renderMap: current map of fields to render
     * @return: updated render map
     */
    renderDateField: function (cmp, rollupLabel, renderMap) {
        var operation = cmp.get("v.activeRollup.operation");
        var timeBoundOperation = cmp.get("v.activeRollup.timeBoundOperationType");
        if (timeBoundOperation !== null &&
            (operation === 'First'
                || operation === 'Last'
                || operation === 'Best_Year'
                || operation === 'Best_Year_Total'
                || operation === 'Donor_Streak'
                || operation === 'Years_Donated'
                || timeBoundOperation === 'Years_Ago'
                || timeBoundOperation === 'Days_Back')
            && rollupLabel) {
            //enable date field
            renderMap["dateField"] = true;
        } else {
            //disable date field
            renderMap["dateField"] = false;
        }

        return renderMap;
    },

    /**
     * @description: conditionally render detail field based on the selected operation, specifically Single Result Operations
     * Note: this should only be called after filterDetailFieldsBySummaryField so detailFields is correctly filtered
     * @param operation: operation API name
     * @param renderMap: current map of fields to render
     * @return: updated render map
     */
    renderDetailField: function (cmp, operation, rollupLabel, renderMap) {
        if ((operation === 'First'
            || operation === 'Last'
            || operation === 'Smallest'
            || operation === 'Largest')
            && rollupLabel
        ) {
            //enable detail field
            renderMap["detailField"] = true;

            //show warning if no fields available and detail field displayed
            var detailFields = cmp.get("v.detailFields");
            if (detailFields.length === 0) {
                var labels = cmp.get("v.labels");
                cmp.set("v.isIncomplete", true);
                this.showToast(cmp, 'warning', labels.noFields, labels.noDetailFieldsMessage);
            }
        } else {
            //disable detail field
            renderMap["detailField"] = false;
        }

        return renderMap;

    },

    /**
     * @description: conditionally render fiscal year checkbox based on the selected operation and time bound operation
     * note that both operations are retrieved instead of passed since only 1 would be available
     * @param renderMap: current map of fields to render
     * @return: updated render map
     */
    renderFiscalYear: function (cmp, renderMap) {
        var operation = cmp.get("v.activeRollup.operation");
        var timeBoundOperation = cmp.get("v.activeRollup.timeBoundOperationType");

        if ((operation === 'Donor_Streak'
            || operation === 'Years_Donated'
            || operation === 'Best_Year'
            || operation === 'Best_Year_Total'
            || timeBoundOperation === 'Years_Ago')
        ) {
            //enable fiscal year
            renderMap["fiscalYear"] = true;
        } else {
            //disable detail field and and clear values
            renderMap["fiscalYear"] = false;
            cmp.set("v.activeRollup.useFiscalYear", cmp.get("v.cachedRollup.useFiscalYear"));
        }

        return renderMap;

    },

    /**
     * @description: Repopulates date fields based on the rollup type object
     * @param rollupTypeObject: Rollup type object
     */
    resetDateFields: function (cmp, rollupTypeObject) {
        var labels = cmp.get("v.labels");
        var dateObjects = [];

        if (rollupTypeObject === labels.objectPayment) {
            dateObjects.push(labels.objectPayment);

        } else if (rollupTypeObject === labels.objectAccountSoftCredit) {
            dateObjects.push(labels.objectAccountSoftCredit);
            dateObjects.push(labels.objectOpportunity);

        } else {
            dateObjects.push(labels.objectOpportunity);
        }

        var dateFields = [];
        for (var i = 0; i < dateObjects.length; i++) {
            var fields = cmp.get("v.objectDetails")[dateObjects[i]];
            dateFields = dateFields.concat(fields);
        }

        dateFields = this.filterFieldsByType(cmp, ["DATE", "DATETIME"], dateFields);
        cmp.set("v.dateFields", dateFields);
    },

    /**
     * @description: resets fields based on the selected object and context
     * @param object: corresponding object to the fields
     * @param context: which fields to reset. values are: detail, summary, date, and amount
     */
    resetFields: function (cmp, object, context) {
        var newFields = cmp.get("v.objectDetails")[object];

        if (newFields === undefined || newFields.length === 0) {
            cmp.set("v.isIncomplete", true);
        } else {
            newFields = this.sortFields(newFields);
        }

        if (context === 'detail') {
            this.filterDetailFieldsBySummaryField(cmp, object);
        } else if (context === 'summary') {
            newFields = this.uniqueSummaryFieldCheck(cmp, newFields);
            cmp.set("v.summaryFields", newFields);
        } else if (context === 'date') {
            newFields = this.filterFieldsByType(cmp, ["DATE", "DATETIME"], newFields);
            cmp.set("v.dateFields", newFields);
        } else if (context === 'amount') {
            var activeRollup = cmp.get("v.activeRollup");
            var summaryFieldType = this.retrieveFieldType(cmp, activeRollup.summaryField, cmp.get("v.summaryFields"));
            var operation = Boolean(activeRollup.operation) ? activeRollup.operation : null;
            if (operation && operation === 'Average' || operation === 'Sum' || operation === 'Best_Year_Total' || operation === 'Best_Year') {
                // these operations must be type-matched to the amount field more precisely
                // note that only average applies to percent
                if (summaryFieldType && summaryFieldType === 'PERCENT') {
                    newFields = this.filterFieldsByType(cmp, ["PERCENT"], newFields);
                } else {
                    newFields = this.filterFieldsByType(cmp, ["DOUBLE", "CURRENCY"], newFields);
                }
            } else {
                // operation here is by definition smallest/largest, which can be percent/double/currency
                // (first/last/count don't have amount context)
                newFields = this.filterFieldsByType(cmp, ["PERCENT", "DOUBLE", "CURRENCY"], newFields);
            }

            cmp.set("v.amountFields", newFields);
        }
    },

    /**
     * @description: resets all object fields and rollup types
     */
    resetAllFields: function (cmp) {
        var activeRollup = cmp.get("v.activeRollup");

        this.resetFields(cmp, activeRollup.summaryObject, 'summary');
        this.resetFields(cmp, activeRollup.amountObject, 'amount');

        var amountObject = cmp.get("v.activeRollup.amountObject");
        var potentialDetailObjects = this.getPotentialDetailObjects(cmp, amountObject);
        this.resetFields(cmp, potentialDetailObjects, 'detail');

        this.resetDateFields(cmp, amountObject);

        this.resetRollupTypes(cmp);
        this.setRollupType(cmp);
    },

    /**
     * @description: resets the list of rollup types based on the selected summary object
     */
    resetRollupTypes: function (cmp) {
        var activeRollup = cmp.get("v.activeRollup");
        var summaryObject = activeRollup.summaryObject;
        var labels = cmp.get("v.labels");
        var templateList = [];
        // in templateList, the `name` attribute is the api name of the detail object
        if (summaryObject === labels.objectAccount) {
            templateList.push(
                {
                    label: labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.hardCredit + ')',
                    summaryObject: labels.objectAccount,
                    name: labels.objectOpportunity
                },
                {
                    label: labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.labelAccount + ' ' + labels.softCredit + ')',
                    summaryObject: labels.objectAccount,
                    name: labels.objectAccountSoftCredit
                },
                {
                    label: labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.labelContact + ' ' + labels.softCredit + ')',
                    summaryObject: labels.objectAccount,
                    name: labels.objectPartialSoftCredit
                },
                {
                    label: labels.labelPayment + ' -> ' + labels.labelAccount + ' (' + labels.hardCredit + ')',
                    summaryObject: labels.objectAccount,
                    name: labels.objectPayment
                }
            );
        } else if (summaryObject === labels.objectContact) {
            templateList.push(
                {
                    label: labels.labelOpportunity + ' -> ' + labels.labelContact + ' (' + labels.hardCredit + ')',
                    summaryObject: labels.objectContact,
                    name: labels.objectOpportunity
                },
                {
                    label: labels.labelOpportunity + ' -> ' + labels.labelContact + ' (' + labels.softCredit + ')',
                    summaryObject: labels.objectContact,
                    name: labels.objectPartialSoftCredit
                },
                {
                    label: labels.labelPayment + ' -> ' + labels.labelContact + ' (' + labels.hardCredit + ')',
                    summaryObject: labels.objectContact,
                    name: labels.objectPayment
                }
            );
        } else if (summaryObject === labels.objectGAU) {
            //check for the detail object to ensure correct value is selected on edit mode
            var detailName;
            if (activeRollup.detailObject === labels.objectOpportunity) {
                detailName = labels.objectOpportunity;
            } else {
                detailName = labels.objectAllocation;
            }
            templateList.push(
                {
                    label: labels.labelAllocation + ' -> ' + labels.labelGAU,
                    summaryObject: labels.objectGAU,
                    name: detailName
                }
            );
        } else if (summaryObject === labels.objectRD) {
            templateList.push(
                {
                    label: labels.labelOpportunity + ' -> ' + labels.labelRD,
                    summaryObject: labels.objectRD,
                    name: labels.objectOpportunity
                }
            );
        }

        cmp.set("v.rollupTypes", templateList);
    },

    /**
     * @description: restructures returned Apex response to preserve separate variables
     * @return: the parsed and stringified JSON
     */
    restructureResponse: function (resp) {
        return JSON.parse(JSON.stringify(resp));
    },

    /**
     * @description: gets the type of a field
     * @param field: name of the field
     * @param fieldList: list of fields with name, type and label keys
     * @return: the type of the field
     */
    retrieveFieldType: function (cmp, field, fieldList) {
        for (var i = 0; i < fieldList.length; i++) {
            if (fieldList[i].name === field) {
                var type = fieldList[i].type;
                return type;
            }
        }
    },

    /**
     * @description: gets the type of a field
     * @param field: name of the field
     * @param fieldList: list of fields with name, type and label keys
     * @return: the map of the field
     */
    retrieveFieldTypeAndReferenceTo: function (cmp, field, fieldList) {
        for (var i = 0; i < fieldList.length; i++) {
            if (fieldList[i].name === field) {
                return fieldList[i];
            }
        }
    },

    /**
     * @description: retrieves the label of an entity (field, operation, etc) based on the api name from a LIST of objects with name and label entries
     * @param apiName: the name of the field. ex: 'General_Account_Unit__c'
     * @param entityList: list of fields to search
     * @return label: field label that matches the apiName
     */
    retrieveFieldLabel: function (apiName, entityList) {
        var label;
        if (!(entityList === undefined || entityList === null)) {
            for (var i = 0; i < entityList.length; i++) {
                if (entityList[i].name === apiName) {
                    label = entityList[i].label;
                    break;
                }
            }
        }
        return label;
    },

    /**
     * @description: saves the active rollup and sets the mode to view OR punts back to grid in the case of a soft "delete"
     * @param activeRollup:
     */
    saveRollup: function (cmp, activeRollup) {
        var currentMode = cmp.get("v.mode");
        if (currentMode === 'delete') {
            cmp.set("v.activeRollup.isDeleted", true);
            cmp.set("v.activeRollup.isActive", false);
        } else {
            cmp.set("v.mode", 'view');
        }

        this.toggleSpinner(cmp, true);

        var rollupCMT = this.restructureResponse(cmp.get("v.activeRollup"));

        // strip back out detail/amount/date objects from fields
        if (cmp.get("v.activeRollup.detailField")) {
            var detailObjectAndField = cmp.get("v.activeRollup.detailField");
            var detailList = detailObjectAndField.split(' ');
            // check for null string because we had to concatenate potentially null values
            // and server requires actual null, not string of null
            rollupCMT.detailField = (detailList[1] === 'null' ? null : detailList[1]);
        }
        if (cmp.get("v.activeRollup.amountField")) {
            var amountObjectAndField = cmp.get("v.activeRollup.amountField");
            var amountList = amountObjectAndField.split(' ');
            rollupCMT.amountField = (amountList[1] === 'null' ? null : amountList[1]);
        }
        if (cmp.get("v.activeRollup.dateField")) {
            var dateObjectAndField = cmp.get("v.activeRollup.dateField");
            var dateList = dateObjectAndField.split(' ');
            rollupCMT.dateField = (dateList[1] === 'null' ? null : dateList[1]);
        }

        var action = cmp.get("c.saveRollup");
        action.setParams({ jsonRollup: JSON.stringify(rollupCMT) });
        action.setCallback(this, function (response) {
            var state = response.getState();

            if (state === "SUCCESS") {
                // Response value will be in the format of "JobId-RecordDeveloperName"
                var responseText = response.getReturnValue();
                var jobId = responseText.split("-")[0];
                var recordName = responseText.split("-")[1];

                cmp.set("v.activeRollup.recordName", recordName);
                if (cmp.get("v.cachedRollup") && cmp.get("v.cachedRollup.recordName")) {
                    cmp.set("v.cachedRollup.recordName", recordName);
                }

                this.pollForDeploymentStatus(cmp, jobId, recordName, 0);

            } else if (state === "ERROR") {

                var errors = response.getError();
                var msg = "Unknown error";
                if (errors && errors[0] && errors[0].message) {
                    msg = errors[0].message;
                }
                this.toggleSpinner(cmp, false);

                if (currentMode === 'delete') {
                    this.showToast(cmp, 'error', cmp.get("v.labels.rollupDeleteFail"), msg);
                } else {
                    this.showToast(cmp, 'error', cmp.get("v.labels.rollupSaveFail"), msg);
                    cmp.set("v.mode", "edit");
                    this.changeMode(cmp);
                }
            }
        });
        if (currentMode === 'delete') {
            this.showToast(cmp, 'info', cmp.get("v.labels.rollupDeleteProgress"), cmp.get("v.labels.pleaseWait"));
        } else {
            this.showToast(cmp, 'info', cmp.get("v.labels.rollupSaveProgress"), cmp.get("v.labels.pleaseWait"));
        }
        $A.enqueueAction(action);
    },

    /**
     * @description: Set the default amount field and detail object based on the selected rollup type for all target fields but percentages
     */
    setDefaultAmount: function (cmp, labels, amountObjectName) {
        var summaryFieldType = this.retrieveFieldType(cmp, cmp.get("v.activeRollup.summaryField"), cmp.get("v.summaryFields"));

        var amountFieldName;
        var amountFields = cmp.get("v.amountFields");

        if (amountObjectName === labels.objectPayment) {
            amountFieldName = labels.objectPayment + ' npe01__Payment_Amount__c';
            cmp.set("v.activeRollup.detailObject", labels.objectPayment);
        } else if (amountObjectName === labels.objectAllocation) {
            amountFieldName = labels.objectAllocation + ' ' + labels.namespacePrefix + 'Amount__c';
            cmp.set("v.activeRollup.detailObject", labels.objectAllocation);
        } else if (amountObjectName === labels.objectPartialSoftCredit) {
            amountFieldName = labels.objectPartialSoftCredit + ' ' + labels.namespacePrefix + 'Amount__c';
            cmp.set("v.activeRollup.detailObject", labels.objectPartialSoftCredit);
        } else if (amountObjectName === labels.objectAccountSoftCredit) {
            amountFieldName = labels.objectAccountSoftCredit + ' ' + labels.namespacePrefix + 'Amount__c';
            cmp.set("v.activeRollup.detailObject", labels.objectAccountSoftCredit);
        } else {
            amountFieldName = labels.objectOpportunity + ' Amount';
            cmp.set("v.activeRollup.detailObject", labels.objectOpportunity);
        }

        // only assume the amount field if the summary field is a number or currency.
        // if the summary field is a percent, the admin has to explicitly select an amount field
        if (summaryFieldType !== 'PERCENT') {
            cmp.set("v.activeRollup.amountField", amountFieldName);
            cmp.set("v.activeRollup.amountFieldLabel", this.retrieveFieldLabel(amountFieldName, amountFields));
        }

    },

    /**
     * @description: sets the selected rollup type based on detail and summary objects when a record is loaded
     */
    setRollupType: function (cmp) {
        var summaryObject = cmp.get("v.activeRollup.summaryObject");
        var detailObject = cmp.get("v.activeRollup.detailObject");
        var amountObject = cmp.get("v.activeRollup.amountObject");
        var labels = cmp.get("v.labels");
        var rollupType = {};

        if (detailObject === labels.objectOpportunity && summaryObject === labels.objectAccount) {
            if (amountObject === labels.objectPartialSoftCredit) {
                rollupType.name = labels.objectOpportunity;
                rollupType.summaryObject = labels.objectAccount;
                rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.labelContact + ' ' + labels.softCredit + ')';
                cmp.set("v.activeRollup.rollupTypeObject", labels.objectPartialSoftCredit);
            } else if (amountObject === labels.objectAccountSoftCredit) {
                rollupType.name = labels.objectOpportunity;
                rollupType.summaryObject = labels.objectAccount;
                rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.softCredit + ')';
                cmp.set("v.activeRollup.rollupTypeObject", labels.objectAccountSoftCredit);
            } else {
                rollupType.name = labels.objectOpportunity;
                rollupType.summaryObject = labels.objectAccount;
                rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.hardCredit + ')';
                cmp.set("v.activeRollup.rollupTypeObject", labels.objectOpportunity);
            }

        } else if (detailObject === labels.objectPayment && summaryObject === labels.objectAccount) {
            rollupType.name = labels.objectPayment;
            rollupType.summaryObject = labels.objectAccount;
            rollupType.label = labels.labelPayment + ' -> ' + labels.labelAccount + ' (' + labels.hardCredit + ')';
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectPayment);

        } else if (detailObject === labels.objectPartialSoftCredit && summaryObject === labels.objectAccount) {
            rollupType.name = labels.objectPartialSoftCredit;
            rollupType.summaryObject = labels.objectAccount;
            rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.labelContact + ' ' + labels.softCredit + ')';
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectPartialSoftCredit);

        } else if (detailObject === labels.objectAccountSoftCredit && summaryObject === labels.objectAccount) {
            rollupType.name = labels.objectAccountSoftCredit;
            rollupType.summaryObject = labels.objectAccount;
            rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelAccount + ' (' + labels.labelAccount + ' ' + labels.softCredit + ')';
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectAccountSoftCredit);

        } else if (detailObject === labels.objectOpportunity && summaryObject === labels.objectContact) {
            if (amountObject === labels.objectPartialSoftCredit) {
                rollupType.name = labels.objectOpportunity;
                rollupType.summaryObject = labels.objectContact;
                rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelContact + ' (' + labels.softCredit + ')';
                cmp.set("v.activeRollup.rollupTypeObject", labels.objectPartialSoftCredit);
            } else {
                rollupType.name = labels.objectOpportunity;
                rollupType.summaryObject = labels.objectContact;
                rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelContact + ' (' + labels.hardCredit + ')';
                cmp.set("v.activeRollup.rollupTypeObject", labels.objectOpportunity);
            }
        } else if (detailObject === labels.objectPartialSoftCredit && summaryObject === labels.objectContact) {
            rollupType.name = labels.objectPartialSoftCredit;
            rollupType.summaryObject = labels.objectContact;
            rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelContact + ' (' + labels.softCredit + ')';
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectPartialSoftCredit);

        } else if (detailObject === labels.objectPayment && summaryObject === labels.objectContact) {
            rollupType.name = labels.objectPayment;
            rollupType.summaryObject = labels.objectContact;
            rollupType.label = labels.labelPayment + ' -> ' + labels.labelContact + ' (' + labels.hardCredit + ')';
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectPayment);

        } else if (detailObject === labels.objectAllocation && summaryObject === labels.objectGAU) {
            rollupType.name = labels.objectAllocation;
            rollupType.summaryObject = labels.objectGAU;
            rollupType.label = labels.labelAllocation + ' -> ' + labels.labelGAU;
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectAllocation);

        } else if (detailObject === labels.objectOpportunity && summaryObject === labels.objectGAU) {
            rollupType.name = labels.objectOpportunity;
            rollupType.summaryObject = labels.labelGAU;
            rollupType.label = labels.labelAllocation + ' -> ' + labels.labelGAU;
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectOpportunity);

        } else if (detailObject === labels.objectOpportunity && summaryObject === labels.objectRD) {
            rollupType.name = labels.objectOpportunity;
            rollupType.summaryObject = labels.objectRD;
            rollupType.label = labels.labelOpportunity + ' -> ' + labels.labelRD;
            cmp.set("v.activeRollup.rollupTypeObject", labels.objectOpportunity);
        }

        cmp.set("v.selectedRollupType", rollupType);
    },

    /**
     * @description: creates the integer picklist for years, and is only called during setup
     */
    setIntegerYearList: function (cmp) {
        var integerList = [];
        var labels = cmp.get("v.labels");

        integerList.push({ name: 0, label: labels.picklistLabelThisYear });
        integerList.push({ name: 1, label: labels.picklistLabelLastYear });
        for (var i = 2; i < 21; i++) {
            var yearsAgoKey = labels['picklistLabelYearsAgo' + i];
            integerList.push({ name: i, label: yearsAgoKey });
        }

        cmp.set("v.integerList", integerList);
    },

    /**
     * @description: toggles a modal popup and backdrop
     */
    toggleModal: function (cmp) {
        var backdrop = cmp.find('backdrop');
        $A.util.toggleClass(backdrop, 'slds-backdrop_open');
        var modal = cmp.find('modaldialog');
        $A.util.toggleClass(modal, 'slds-fade-in-open');
    },

    /**
     *  @description: checks the mode to see if record's summary field needs to be added to or removed from summary field list
     *  @param newFields: list of all fields in name and label key value pairs
     *  @return: updated list of newFields
     */
    uniqueSummaryFieldCheck: function (cmp, newFields) {
        var mode = cmp.get("v.mode");
        var summaryField = cmp.get("v.activeRollup.summaryField");
        if (mode === 'clone') {
            //remove if it's in the list
            for (var i = 0; i < newFields.length; i++) {
                if (newFields[i].name === summaryField) {
                    newFields.splice(i, 1);
                }
            }
        }

        //show warning if no fields available
        if (newFields === undefined || newFields.length === 0) {
            var labels = cmp.get("v.labels");
            cmp.set("v.isIncomplete", true);
            this.showToast(cmp, 'warning', labels.noFields, labels.noTargetFieldsMessage);
        }

        return newFields
    },

    /**
     * @description: resets allowed operations based on the summary field type
     */
    updateAllowedOperations: function (cmp) {

        //start with all operations
        var ops = cmp.get("v.operations");

        var field = cmp.get("v.activeRollup.summaryField");
        var summaryFields = cmp.get("v.summaryFields");

        var type;
        for (var i = 0; i < summaryFields.length; i++) {
            if (summaryFields[i].name === field) {
                type = summaryFields[i].type;
                break;
            }
        }

        //create lists of allowed operations
        var allowedOps = [];
        allowedOps.push({ name: 'Smallest', label: ops['Smallest'] });
        allowedOps.push({ name: 'Largest', label: ops['Largest'] });
        allowedOps.push({ name: 'First', label: ops['First'] });
        allowedOps.push({ name: 'Last', label: ops['Last'] });

        if (type === 'DOUBLE' || type === 'INTEGER' || type === 'LONG') {
            allowedOps.push({ name: 'Count', label: ops['Count'] });
            allowedOps.push({ name: 'Sum', label: ops['Sum'] });
            allowedOps.push({ name: 'Average', label: ops['Average'] });
            allowedOps.push({ name: 'Best_Year', label: ops['Best_Year'] });
            allowedOps.push({ name: 'Best_Year_Total', label: ops['Best_Year_Total'] });
            allowedOps.push({ name: 'Donor_Streak', label: ops['Donor_Streak'] });
        } else if (type === 'CURRENCY') {
            allowedOps.push({ name: 'Sum', label: ops['Sum'] });
            allowedOps.push({ name: 'Average', label: ops['Average'] });
            allowedOps.push({ name: 'Best_Year_Total', label: ops['Best_Year_Total'] });
        } else if (type === 'STRING' || type === 'TEXTAREA' || type === 'PICKLIST' || type === 'MULTIPICKLIST') {
            allowedOps.push({ name: 'Best_Year', label: ops['Best_Year'] });
            allowedOps.push({ name: 'Years_Donated', label: ops['Years_Donated'] });
        } else if (type === 'PERCENT') {
            allowedOps.push({ name: 'Average', label: ops['Average'] });
        }

        cmp.set("v.allowedOperations", allowedOps);

    },

    /** 
    * @description: sets the rollup name with a simple concatenation of the summary object and summary field
    * also sends the updated name to the parent component to display as the page title
    */
    updateRollupName: function (cmp) {
        var summaryObjectAPI = cmp.get("v.activeRollup.summaryObject");
        var summaryObjects = cmp.get("v.summaryObjects");
        var summaryObjectName = this.retrieveFieldLabel(summaryObjectAPI, summaryObjects);

        var summaryFieldAPI = cmp.get("v.activeRollup.summaryField");
        var summaryFields = cmp.get("v.summaryFields");
        var summaryFieldName = this.retrieveFieldLabel(summaryFieldAPI, summaryFields);

        var label = summaryObjectName + ': ' + summaryFieldName;

        // The label is limited to 40 characters, so use these two shortened names for space
        label = label.replace(cmp.get("v.labels.labelGAU"), 'GAU').replace(cmp.get("v.labels.labelRD"), 'RD');

        var masterLabel = '';
        var mode = cmp.get("v.mode");

        if ((mode === 'create' || mode === 'clone') && (!summaryObjectName || !summaryFieldName || !summaryFieldAPI)) {
            masterLabel = cmp.get("v.labels.rollupNew");
            cmp.set("v.activeRollup.label", masterLabel);
        } else if (mode === 'create' || mode === 'clone') {
            masterLabel = label;
            cmp.set("v.activeRollup.label", masterLabel);
        } else if (summaryObjectName && summaryFieldName) {
            // Only reset the name once summary object and field are selected for edit mode
            masterLabel = label;
            cmp.set("v.activeRollup.label", masterLabel);
        }

        //sends the message to the parent cmp RollupsContainer
        if (masterLabel) {
            this.sendMessage(cmp, 'nameChange', masterLabel);
        }

    },

    /**
     * @description Inserting or updating a CMT record is an asynchronous deployment process. This method uses the
     * unique jobId and the Rollup__mdt.DeveloperName value to recursively call an apex controller method to determine
     * when the deployment has completed (by looking in a custom settings object). If it completes, the final recordId
     * is returned. Otherwise an error message to render is returned. If the return is null, then it calls this method
     * again to wait another second an try again.
     * @param jobId The returns CMT deployment job id to query status for
     * @param recordName Unique record name value (that was just inserted/updated) to query for.
     */
    pollForDeploymentStatus: function (cmp, jobId, recordName, counter) {
        var helper = this;
        var pollingInterval = 2000; // 2 seconds.
        var maxPollingCount = 45; // 1min 30, because the polling interval is 2 seconds (45 * 2 seconds).
        var mode = cmp.get("v.mode");
        var poller = window.setTimeout(
            $A.getCallback(function () {
                counter++;
                var action = cmp.get("c.getDeploymentStatus");
                action.setParams({ jobId: jobId, recordName: recordName, objectType: 'Rollup', mode: mode });
                action.setCallback(this, function (response) {
                    var state = response.getState();
                    if (state === "SUCCESS") {
                        // Response will be a serialized deployResult wrapper class
                        var deployResult = JSON.parse(response.getReturnValue());

                        // if there is a record id response
                        var mode = cmp.get("v.mode");
                        if (deployResult && deployResult.completed === true && (deployResult.rollupItem || mode === 'delete')) {
                            window.clearTimeout(poller);
                            helper.toggleSpinner(cmp, false);

                            if (mode === "delete") {
                                // Send a message with the deleted Rollup to the RollupContainer Component
                                helper.sendMessage(cmp, 'rollupDeleted', recordName);

                            } else {

                                helper.showToast(cmp, 'success', cmp.get("v.labels.rollupSaveProgress"), cmp.get("v.labels.rollupSaveSuccess"));

                                // Save the inserted/updated record id and update cached rollup
                                cmp.set("v.activeRollupId", deployResult.rollupItem.recordId);
                                cmp.set("v.activeRollup.id", deployResult.rollupItem.recordId);
                                cmp.set("v.cachedRollup", helper.restructureResponse(cmp.get("v.activeRollup")));

                                // Send a message with the changed or new Rollup to the RollupContainer Component
                                helper.sendMessage(cmp, 'rollupRecordChange', deployResult.rollupItem);
                            }

                        } else {
                            // No record id, so run call this method again to check in another 1 second
                            if (counter < maxPollingCount) {
                                helper.pollForDeploymentStatus(cmp, jobId, recordName, counter);
                            } else {
                                // When the counter hits the max, need to tell the user what happened and keep page in edit mode
                                helper.showToast(cmp, 'info', cmp.get("v.labels.rollupSaveProgress"), cmp.get("v.labels.rollupSaveTimeout"));
                                helper.toggleSpinner(cmp, false);
                                cmp.set("v.mode", "edit");
                                helper.changeMode(cmp);
                            }
                        }
                    } else {
                        // If an error is returned, parse the message, display and remove the spinner
                        var errors = response.getError();
                        var msg = "Unknown error";
                        if (errors && errors[0] && errors[0].message) {
                            msg = errors[0].message;
                        }
                        helper.showToast(cmp, 'error', cmp.get("v.labels.rollupSaveFail"), msg);
                        window.clearTimeout(poller);
                        helper.toggleSpinner(cmp, false);
                        cmp.set("v.mode", "edit");
                        helper.changeMode(cmp);
                    }
                });
                $A.enqueueAction(action);
            }), pollingInterval
        );
    },

    /**
     * @description Sends a lightning message to all listening components
     * @param channel - intended channel to hear the message
     * @param message - body of the message
     */
    sendMessage: function (cmp, channel, message) {
        var sendMessage = $A.get('e.ltng:sendMessage');
        sendMessage.setParams({
            'channel': channel,
            'message': message
        });
        sendMessage.fire();
    },

    /**
     * @description Sort provided fields by the field labels
     * @param fields - list of fields to sort
     */
    sortFields: function (fields) {
        fields.sort(function (a, b) {
            if (a.label.toUpperCase() < b.label.toUpperCase()) {
                return -1;
            }
            if (a.label.toUpperCase() > b.label.toUpperCase()) {
                return 1;
            }
            return 0;
        });
        return fields;
    },

    /**
     * @description Show a message on the screenin the parent cmp
     * @param type - error, success, info
     * @param title - message title
     * @param message - message to display
     */
    showToast: function (cmp, type, title, message) {
        var channel = 'showToast';
        var message = { type: type, title: title, message: message };
        this.sendMessage(cmp, channel, message);
    },

    /**
     * @description Show or Hide the page spinner in the parent cmp
     */
    toggleSpinner: function (cmp, showSpinner) {
        this.sendMessage(cmp, 'toggleSpinner', { showSpinner: showSpinner });
    },

    /**
    * @description: verifies all required fields have been populated before saving the component
    * @return canSave: boolean value indicating if rollup can be saved
    */
    validateFields: function (cmp) {
        //create required field list
        var renderMap = cmp.get("v.renderMap");
        var requiredSelectFields = ["summaryObject", "summaryField", "operation"];
        if (renderMap["detailField"]) {
            requiredSelectFields.push("detailField");
            requiredSelectFields.push("detailObject");
        }
        if (renderMap["timeBoundOperationType"]) {
            requiredSelectFields.push("timeBoundOperationType");
        }
        if (renderMap["amountField"]) {
            requiredSelectFields.push("amountField");
        }
        var activeRollup = cmp.get("v.activeRollup");

        //check for values of required fields
        var canSave = requiredSelectFields.reduce(function (validSoFar, field) {
            return validSoFar && Boolean(activeRollup[field]);
        }, true);

        //check for rollup type specifically since different name conventions are used
        if (renderMap["rollupType"]) {
            if (!activeRollup.rollupTypeObject) {
                canSave = false;
            }
        }

        //show help message in each child component SelectField
        if (!canSave) {
            this.sendMessage(cmp, 'validateCmp', cmp.get("v.labels.labelMissingRequired"));
        }

        //description and intValue set separately since we have direct access to these
        if (!activeRollup.description) {
            cmp.find("descriptionInput").focus();

            var channel = 'showToast';
            var formattedLabel = cmp.get("v.labels.labelMissingRequired").replace("{0}", cmp.get("v.labels.description"));
            var message = { type: 'warning', title: formattedLabel };

            var sendMessage = $A.get('e.ltng:sendMessage');
            sendMessage.setParams({
                'channel': channel,
                'message': message
            });
            sendMessage.fire();

            canSave = false;
        }

        /* TODO: a bug prevents this from working, so using explicit regex. replace when it's fixed.
        * validity is preferable since it checks for all validity, not just a regex
        var integerInput = cmp.find("integerInput");
        if (renderMap["integerDays"] && !integerInput.get("v.validity").valid) {
            integerInput.showHelpMessageIfInvalid();
            canSave = false;
        }*/
        var intValue = activeRollup.intValue;
        var isValidInteger;
        if (intValue !== undefined || intValue !== null) {
            var regex = new RegExp(/(^\d{1,4}$)/);
            isValidInteger = regex.test(intValue);
        }
        if (renderMap["integerDays"] && !isValidInteger) {
            canSave = false;
        }
        return canSave;
    },

    /**
    * @description: disables save button if a detail field is required for a single result operation and detail field or rollup type isn't visible
    * @param detailField: selected detail field API name
    */
    verifyRollupSaveActive: function (cmp, detailField) {
        if (cmp.get("v.mode") !== 'view') {
            var renderMap = cmp.get("v.renderMap");
            var selectedRollup = cmp.get("v.selectedRollupType");

            if (renderMap["rollupType"]) {
                if (!renderMap["detailField"]) {
                    //if detail field isn't required, save button enables
                    cmp.set("v.isIncomplete", false);
                } else {
                    //extra splitting is due to the detailFieldAndObject notation used for detailField
                    if (detailField && detailField.split(' ')[1] !== 'null') {
                        //if detail field is required, save button enables only if detail field is selected
                        cmp.set("v.isIncomplete", false);
                    } else {
                        cmp.set("v.isIncomplete", true);
                    }
                }
            } else {
                cmp.set("v.isIncomplete", true);
            }
        }
    }
})