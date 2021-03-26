import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { isNull, isUndefined } from 'c/utilCommon';

import getRecurringSettings from '@salesforce/apex/RD2_entryFormController.getRecurringSettings';
import getRecurringData from '@salesforce/apex/RD2_entryFormController.getRecurringData';

import picklistLabelAdvanced from '@salesforce/label/c.RD2_EntryFormPeriodAdvanced';
import customPeriodHelpText from '@salesforce/label/c.RD2_EntryFormPeriodHelpText';
import fieldLabelPeriod from '@salesforce/label/c.RD2_EntryFormPeriodLabel';
import periodPluralDays from '@salesforce/label/c.RD2_EntryFormPeriodPluralDaily';
import periodPluralMonths from '@salesforce/label/c.RD2_EntryFormPeriodPluralMonthly';
import periodPluralWeeks from '@salesforce/label/c.RD2_EntryFormPeriodPluralWeekly';
import periodPluralYears from '@salesforce/label/c.RD2_EntryFormPeriodPluralYearly';
import fieldLabelEvery from '@salesforce/label/c.RD2_EntryFormScheduleEveryLabel';

import RECURRING_DONATION_OBJECT from '@salesforce/schema/npe03__Recurring_Donation__c';
import FIELD_RECURRING_TYPE from '@salesforce/schema/npe03__Recurring_Donation__c.RecurringType__c';
import FIELD_PLANNED_INSTALLMENTS from '@salesforce/schema/npe03__Recurring_Donation__c.npe03__Installments__c';
import FIELD_INSTALLMENT_PERIOD from '@salesforce/schema/npe03__Recurring_Donation__c.npe03__Installment_Period__c';
import FIELD_INSTALLMENT_FREQUENCY from '@salesforce/schema/npe03__Recurring_Donation__c.InstallmentFrequency__c';
import FIELD_DAY_OF_MONTH from '@salesforce/schema/npe03__Recurring_Donation__c.Day_of_Month__c';
import FIELD_START_DATE from '@salesforce/schema/npe03__Recurring_Donation__c.StartDate__c';

const RECURRING_PERIOD_ADVANCED = 'Advanced';

// Constants from RD2_Constants class
const RECURRING_TYPE_FIXED = 'Fixed';
const LAST_DAY_OF_MONTH = 'Last_Day';
const PERIOD_MONTHLY = 'Monthly';
const PERIOD_YEARLY = 'Yearly';
const PERIOD_WEEKLY = 'Weekly';
const PERIOD_DAILY = 'Daily';
const PERIOD_FIRST_AND_FIFTEENTH = '1st and 15th';

export default class rd2EntryFormScheduleSection extends LightningElement {

    customLabels = Object.freeze({
        picklistLabelAdvanced,
        fieldLabelEvery,
        fieldLabelPeriod,
        customPeriodHelpText,
        periodPluralDays,
        periodPluralMonths,
        periodPluralWeeks,
        periodPluralYears
    });

    isNew = false;
    hasError = false;

    @api recordId;
    @track isLoading = true;
    @track isAdvancedMode = false;

    @track showDayOfMonth = true;
    @track showNumPlannedInstallments = false;
    @track customPeriod = PERIOD_MONTHLY; // default
    @track customPeriodAdvancedMode;

    @track fieldInstallmentPeriod = this.customLabels.periodPluralMonths;

    @track fields = {};

    @track inputFieldInstallmentFrequency = 1;

    rdObjectInfo;
    defaultDayOfMonthValue;
    defaultInstallmentPeriodValue;

    @track disablePeriodPicklistField;
    @track disableInstallmentFrequencyField;
    @track hidePeriodPicklistField;
    @track hideInstallmentFrequencyField;

    @track advancedPeriodPicklistValues;

    @track recurringTypeColumnSize = 6;
    @track scheduleRowColumnSize = 6;

    /***
    * @description Init function
    */
    connectedCallback() {
        this.init();
    }

    /***
   * @description Get settings required to enable or disable fields and populate their values
   */
    init() {
        if (isNull(this.recordId)) {
            this.isNew = true;
            this.updateScheduleFieldVisibility(PERIOD_MONTHLY, PERIOD_MONTHLY);
            this.updatePlannedInstallmentsVisibility();

        } else {
            /**
             * @description Retrieve the RD Schedule related fields from apex to configure the custom picklist values
             * and field visibility rules accordingly.
             */
            getRecurringData({ recordId: this.recordId })
                .then(response => {
                    this.customPeriod = response.Period;
                    this.inputFieldInstallmentFrequency = response.Frequency;
                    if (response.Period !== PERIOD_MONTHLY
                        || (response.Period === PERIOD_MONTHLY && this.inputFieldInstallmentFrequency > 1)
                    ) {
                        this.customPeriod = RECURRING_PERIOD_ADVANCED;
                    }
                    this.updateScheduleFieldVisibility(this.customPeriod, response.Period);
                    this.updatePlannedInstallmentsVisibility(response.RecurringType);
                })
                .catch((error) => {
                    this.hasError = true;
                    this.dispatchEvent(new CustomEvent('errorevent', { detail: { value: error } }));
                });
        }

        /**
         * @description Retrieve special RD settings and permissions from Apex that cannot be retrieved effecively here.
         */
        getRecurringSettings({ parentId: null, recordId: null })
            .then(response => {
                this.disablePeriodPicklistField = this.shouldDisableField(response.InstallmentPeriodPermissions);
                this.hidePeriodPicklistField = this.shouldHideField(response.InstallmentPeriodPermissions);

                this.disableInstallmentFrequencyField = this.shouldDisableField(response.InstallmentFrequencyPermissions);
                this.hideInstallmentFrequencyField = this.shouldHideField(response.InstallmentFrequencyPermissions);
            })
            .catch((error) => {
                // handleError(error);
            })
            .finally(() => {
                this.checkLoading();
            });
    }

    /**
    * @description Retrieve Recurring Donation SObject info
    */
    @wire(getObjectInfo, { objectApiName: RECURRING_DONATION_OBJECT.objectApiName })
    wiredRecurringDonationObjectInfo(response) {
        if (response.data) {
            this.rdObjectInfo = response.data;
            this.setFields(this.rdObjectInfo.fields);
            this.buildFieldDescribes(
                this.rdObjectInfo.fields,
                this.rdObjectInfo.apiName
            );

            this.checkLoading();

        } else if (response.error) {
            this.hasError = true;
            this.dispatchEvent(new CustomEvent('errorevent', { detail: { value: response.error } }));
        }
    }

    /**
     * @description Set isLoading to false only after all wired actions have fully completed
     */
    checkLoading() {
        this.isLoading = !(
            this.installmentPeriodPicklistValues
            && this.dayOfMonthPicklistValues
            && !isUndefined(this.fields.recurringType)
            && this.rdObjectInfo
            && !this.hasError
        );
    }

    /**
     * @description Broadcasts the schedule form field values that 
     * might impact the parent component display
     */
    dispatchTypeChange() {
        this.dispatchEvent(new CustomEvent(
            'typechange',
            {
                detail: {
                    recurringType: this.getRecurringType()
                }
            }
        ));
    }

    /**
    * @description Method converts field describe info into objects that the
    * getRecord method can accept into its 'fields' parameter.
    */
    buildFieldDescribes(fields, objectApiName) {
        return Object.keys(fields).map((fieldApiName) => {
            return {
                fieldApiName: fieldApiName,
                objectApiName: objectApiName
            }
        });
    }

    /**
     * @description Construct field describe info from the Recurring Donation SObject info
     */
    setFields(fieldInfos) {
        this.fields.recurringType = this.extractFieldInfo(fieldInfos, FIELD_RECURRING_TYPE.fieldApiName);
        this.fields.period = this.extractFieldInfo(fieldInfos, FIELD_INSTALLMENT_PERIOD.fieldApiName);
        this.fields.installmentFrequency = this.extractFieldInfo(fieldInfos, FIELD_INSTALLMENT_FREQUENCY.fieldApiName);
        this.fields.dayOfMonth = this.extractFieldInfo(fieldInfos, FIELD_DAY_OF_MONTH.fieldApiName);
        this.fields.startDate = this.extractFieldInfo(fieldInfos, FIELD_START_DATE.fieldApiName);
        this.fields.plannedInstallments = this.extractFieldInfo(fieldInfos, FIELD_PLANNED_INSTALLMENTS.fieldApiName);
    }

    /**
     * @description Converts field describe info into a object that is easily accessible from the front end
     * Ignore errors to allow the UI to simply not render the layout-item if the field info doesn't exist
     * (i.e, the field isn't accessible).
     */
    extractFieldInfo(fieldInfos, fldApiName) {
        try {
            const field = fieldInfos[fldApiName];
            return {
                apiName: field.apiName,
                label: field.label,
                inlineHelpText: field.inlineHelpText,
                dataType: field.dataType
            };
        } catch (error) { }
    }

    /***
     * @description Set today's day as default Day of Month value for a new Recurring Donation record, unless
     * the picklist itself has a default value.
     */
    get defaultDayOfMonth() {
        return (this.isNew && this.dayOfMonthPicklistValues)
            ? (this.defaultDayOfMonthValue ? this.defaultDayOfMonthValue : this.getCurrentDayOfMonth())
            : undefined;
    }

    /**
     * @description If the default Installment Period is not monthly (the hard-coded default in this UI), then update
     * the custom picklist field default values accordingly as well as the visibility rules for the fields.
     */
    setDefaultInstallmentPeriod() {
        if (!this.isNew || !this.defaultInstallmentPeriodValue) {
            return;
        }
        if (this.defaultInstallmentPeriodValue !== PERIOD_MONTHLY) {
            this.updateScheduleFieldVisibility(RECURRING_PERIOD_ADVANCED, this.defaultInstallmentPeriodValue);
        }
    }

    /**
     * @description Returns a boolean to disable entry into a field based on the FLS
     * @returns True to disable entry into the field
     */
    shouldDisableField(fieldPerms) {
        return (this.isNew ? !fieldPerms.Createable : !fieldPerms.Updateable);
    }

    /**
     * @description Returns a boolean to hide a field based on the FLS
     * @returns True to hide the field entirely in the UI
     */
    shouldHideField(fieldPerms) {
        return !fieldPerms.Visible;
    }

    /***
    * @description Retrieve Recurring Donation Day of Month picklist values
    */
    @wire(getPicklistValues, { fieldApiName: FIELD_DAY_OF_MONTH, recordTypeId: '$rdObjectInfo.defaultRecordTypeId' })
    wiredDayOfMonthPicklistValues({ error, data }) {
        if (data) {
            this.dayOfMonthPicklistValues = data.values;
            if (data.defaultValue && data.defaultValue.value) {
                this.defaultDayOfMonthValue = data.defaultValue.value;
            }
            this.checkLoading();
        }

        if (error) {
            // Day of Month field likely not visible
            this.dayOfMonthPicklistValues = {};
            this.checkLoading();
        }
    }

    /***
    * @description Retrieve Recurring Donation Installment Period picklist values
    */
    @wire(getPicklistValues, { fieldApiName: FIELD_INSTALLMENT_PERIOD, recordTypeId: '$rdObjectInfo.defaultRecordTypeId' })
    wiredInstallmentPeriodPicklistValues({ error, data }) {
        if (data) {
            this.installmentPeriodPicklistValues = data.values;
            if (data.defaultValue && data.defaultValue.value) {
                this.defaultInstallmentPeriodValue = data.defaultValue.value;
                this.setDefaultInstallmentPeriod();
            }
            this.checkLoading();
        }

        if (error) {
            // Installment Period field likely not visible
            this.installmentPeriodPicklistValues = {};
            this.checkLoading();
        }
    }

    /***
    * @description Sets Day of Month to current day for a new Recurring Donation record.
    * When no match is found, ie today is day 31 in a month, return 'Last_Day' API value.
    * @return String Current day
    */
    getCurrentDayOfMonth() {
        let currentDay = new Date().getDate().toString();

        let matchingPicklistValue = this.dayOfMonthPicklistValues.find(value => {
            return value.value == currentDay;
        });

        return (matchingPicklistValue)
            ? matchingPicklistValue.value
            : LAST_DAY_OF_MONTH;
    }

    /**
     * @description Automatically Show/Hide the NumberOfPlannedInstallments field based on the Recurring Type value
     * @param event
     */
    onHandleRecurringTypeChange(event) {
        let recurringType = event.target.value;
        this.updatePlannedInstallmentsVisibility(recurringType);

        // Notify the main entry form about the Recurring Type value change
        this.dispatchTypeChange();
    }

    /**
     * @description When the custom Recurring Period picklist is updated change what other fields are visible on the
     * page: Monthly - just day of month; Advanced: Show the full period picklist and other fields.
     * @param event
     */
    onHandleRecurringPeriodChange(event) {
        let recurringPeriod = event.target.value;
        this.updateScheduleFieldVisibility(recurringPeriod, this.customPeriodAdvancedMode);
    }

    /**
     * @description When the Recurring Period picklist is Advanced, this picklist is visible and allows the User to select
     * any of the supported (and active) installment periods. If Monthly is selected, enable the DayOfMonth field visibility.
     * @param event
     */
    onHandleAdvancedPeriodChange(event) {
        let advancedPeriod = event.target.value;
        this.updateScheduleFieldVisibility(this.customPeriod, advancedPeriod);
    }

    /**
     * @description Set the various properties to control field visibility, how many fields appear in each row
     * and other rules based on the selected InstallmentPeriod value.
     * @param customPeriod Monthly or Advanced
     * @param advancedPeriod Monthly, Weekly, Daily, Yearly or 1st and 15th
     */
    updateScheduleFieldVisibility(customPeriod, advancedPeriod) {
        this.customPeriod = customPeriod;
        this.customPeriodAdvancedMode = advancedPeriod;

        if (customPeriod === PERIOD_MONTHLY) {
            this.isAdvancedMode = false;
            this.showDayOfMonth = true;
            this.scheduleRowColumnSize = 6;

        } else if (customPeriod === RECURRING_PERIOD_ADVANCED) {
            this.isAdvancedMode = true;
            this.showDayOfMonth = (this.customPeriodAdvancedMode === PERIOD_MONTHLY);
            this.scheduleRowColumnSize = (this.showDayOfMonth ? 3 : 4);

            if (advancedPeriod === PERIOD_MONTHLY) {
                this.showDayOfMonth = true;
                this.scheduleRowColumnSize = 3;
            } else {
                this.showDayOfMonth = false;
                this.scheduleRowColumnSize = 4;
            }
        }
    }

    /**
     * @description Update the visibility of the Planned Installments field based on the Recurring Type
     * @param recurringType
     */
    updatePlannedInstallmentsVisibility(recurringType) {
        if (recurringType === RECURRING_TYPE_FIXED) {
            this.showNumPlannedInstallments = true;
            this.recurringTypeColumnSize = 4;
        } else {
            this.showNumPlannedInstallments = false;
            this.recurringTypeColumnSize = 6;
        }
    }

    /**
     * @description Custom Period picklist options - Advanced and Monthly (using the correct labels)
     */
    get customPeriodOptions() {
        let monthlyLabel = PERIOD_MONTHLY;

        // Get the translated labels for Monthly if there is one
        this.installmentPeriodPicklistValues
            .forEach(pl => {
                if (pl.value === PERIOD_MONTHLY) {
                    monthlyLabel = pl.label;
                }
            });

        return [
            { label: monthlyLabel, value: PERIOD_MONTHLY },
            { label: this.customLabels.picklistLabelAdvanced, value: RECURRING_PERIOD_ADVANCED },
        ];
    }

    /**
     * @description Build the picklist values to use for the Period picklist in the Advanced view. These replace
     * the standard Monthly, Weekly, Yearly labels with Months, Weeks, Years - but only for labels visible in
     * this Picklist on this UI.
     */
    get advancedPeriodOptions() {
        let advancedPeriodPicklistValues = [];
        this.installmentPeriodPicklistValues
            .forEach(pl => {
                switch (pl.value) {
                    case PERIOD_DAILY:
                        advancedPeriodPicklistValues.push(
                            { label: this.customLabels.periodPluralDays, value: pl.value }
                        );
                        break;
                    case PERIOD_WEEKLY:
                        advancedPeriodPicklistValues.push(
                            { label: this.customLabels.periodPluralWeeks, value: pl.value }
                        );
                        break;
                    case PERIOD_MONTHLY:
                        advancedPeriodPicklistValues.push(
                            { label: this.customLabels.periodPluralMonths, value: pl.value }
                        );
                        break;
                    case PERIOD_YEARLY:
                        advancedPeriodPicklistValues.push(
                            { label: this.customLabels.periodPluralYears, value: pl.value }
                        );
                        break;
                    case PERIOD_FIRST_AND_FIFTEENTH:
                        advancedPeriodPicklistValues.push(
                            { label: pl.label, value: pl.value }
                        );
                        break;
                }

            });
        return advancedPeriodPicklistValues;
    }

    /**
     * Resets the Schedule fields as they were upon the initial load
     */
    @api
    reset() {
        this.template.querySelectorAll('lightning-input-field')
            .forEach(field => {
                field.reset();
            });
    }

    /**
     * Populates the Schedule form fields based on provided data
     */
    @api
    load(data) {
        //TODO, what is the format of "data"?
    }

    /**
     * @description Checks if values specified on fields are valid
     * @return Boolean
     */
    @api
    isValid() {
        let isValid = true;

        this.template.querySelectorAll('lightning-input-field')
            .forEach(field => {
                if (!field.reportValidity()) {
                    isValid = false;
                }
            });

        this.template.querySelectorAll('.advanced-mode-fields')
            .forEach(field => {
                if (!field.reportValidity()) {
                    isValid = false;
                }
            });

        return isValid;
    }

    /***
     * @description Returns value of the Recurring Type field
     */
    @api
    getRecurringType() {
        const recurringType = this.template.querySelector('lightning-input-field[data-id="recurringType"]');

        return recurringType ? recurringType.value : null;
    }

    /**
     * @description Returns fields displayed on the Recurring Donation Schedule section
     * @return Object containing field API names and their values
     */
    @api
    returnValues() {
        let data = {};

        // Standard Input Fields
        this.template.querySelectorAll('lightning-input-field')
            .forEach(field => {
                data[field.fieldName] = field.value;
            });

        // Overridden inputs using lighting-input or lightning-combobox
        this.template.querySelectorAll('.advanced-mode-fields')
            .forEach(input => {
                switch (input.name) {
                    case 'installmentFrequency':
                        data[this.fields.installmentFrequency.apiName] = input.value;
                        break;
                    case 'CustomPeriodSelect':
                        if (!this.isAdvancedMode) {
                            data[this.fields.period.apiName] = input.value;
                        }
                        break;
                    case 'advancedPeriodSelect':
                        if (this.isAdvancedMode) {
                            data[this.fields.period.apiName] = input.value;
                        }
                        break;
                }
            });

        return data;
    }

    /**
    * @description run init function 
    */
    @api
    forceRefresh() {
        this.init();
    }

    /**
    * @description reset all lighning-input-field value 
    */
    @api
    resetValues() {
        this.template.querySelectorAll('lightning-input-field')
            .forEach(field => {
                if (field.value) {
                    field.reset();
                }
            });
        this.isLoading = true;
    }

}