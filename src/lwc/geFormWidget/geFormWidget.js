import { LightningElement, api, track } from 'lwc';
import {apiNameFor, getSubsetObject, isEmptyObject, isUndefined} from 'c/utilCommon';

import DATA_IMPORT_ADDITIONAL_OBJECT_JSON_FIELD from '@salesforce/schema/DataImport__c.Additional_Object_JSON__c';
import DATA_IMPORT_DONATION_AMOUNT_FIELD from '@salesforce/schema/DataImport__c.Donation_Amount__c';
import DATA_IMPORT_PAYMENT_METHOD from '@salesforce/schema/DataImport__c.Payment_Method__c';
import DATA_IMPORT_CONTACT_FIRSTNAME from '@salesforce/schema/DataImport__c.Contact1_Firstname__c';
import DATA_IMPORT_CONTACT_LASTNAME from '@salesforce/schema/DataImport__c.Contact1_Lastname__c';
import DATA_IMPORT_DONATION_DONOR from '@salesforce/schema/DataImport__c.Donation_Donor__c';
import DATA_IMPORT_ACCOUNT_NAME from '@salesforce/schema/DataImport__c.Account1_Name__c';
import DATA_IMPORT_PAYMENT_STATUS from '@salesforce/schema/DataImport__c.Payment_Status__c';
import DATA_IMPORT_PARENT_BATCH_LOOKUP from '@salesforce/schema/DataImport__c.NPSP_Data_Import_Batch__c';
import DATA_IMPORT_ID from '@salesforce/schema/DataImport__c.Id';

const ALLOCATION_WIDGET = 'geFormWidgetAllocation';
const SOFT_CREDIT_WIDGET = 'geFormWidgetSoftCredit';
const TOKENIZE_CARD_WIDGET = 'geFormWidgetTokenizeCard';
const WIDGET_LIST = [ALLOCATION_WIDGET, SOFT_CREDIT_WIDGET, TOKENIZE_CARD_WIDGET];

export default class GeFormWidget extends LightningElement {
    @api element;
    @api gift;
    @api widgetConfig;

    @track widgetDataFromState = {};

    _formState = {};

    _allocationFields = [
        apiNameFor(DATA_IMPORT_DONATION_AMOUNT_FIELD),
        apiNameFor(DATA_IMPORT_ADDITIONAL_OBJECT_JSON_FIELD)
    ];

    _softCreditFields = [];

    _elevateFields = [
        apiNameFor(DATA_IMPORT_PARENT_BATCH_LOOKUP),
        apiNameFor(DATA_IMPORT_PAYMENT_METHOD),
        apiNameFor(DATA_IMPORT_CONTACT_FIRSTNAME),
        apiNameFor(DATA_IMPORT_CONTACT_LASTNAME),
        apiNameFor(DATA_IMPORT_DONATION_DONOR),
        apiNameFor(DATA_IMPORT_ACCOUNT_NAME),
        apiNameFor(DATA_IMPORT_PAYMENT_STATUS),
        apiNameFor(DATA_IMPORT_ID)
    ];

    get hasPaymentMethodFieldInForm() {
        return this.widgetConfig?.hasPaymentMethodFieldInForm;
    }

    get paymentTransactionStatusValues() {
        return this.widgetConfig && this.isElevateTokenizeCard ? this.widgetConfig.paymentTransactionStatusValues : {};
    }

    @api
    get formState() {
        return this._formState;
    }

    set formState(formState) {
        if (isEmptyObject(formState)) {
            return;
        }

        const shouldUpdateAllocationWidgetState = this.isAllocation && this.hasAllocationValuesChanged(formState);
        if (shouldUpdateAllocationWidgetState) {
            this.sliceWidgetDataFromFormState(formState, this._allocationFields);
        }

        const shouldUpdateElevateWidgetState = this.isElevateTokenizeCard && this.hasElevateValuesChanged(formState);
        if (shouldUpdateElevateWidgetState) {
            this.sliceWidgetDataFromFormState(formState, this._elevateFields);
        }

        this._formState = Object.assign({}, formState);
    }

    sliceWidgetDataFromFormState(formState, fields) {
        this.widgetDataFromState = getSubsetObject(formState, fields);
    }

    handleFormWidgetChange(event) {
        this.dispatchEvent(new CustomEvent('formwidgetchange', {detail: event.detail}))
    }

    hasElevateValuesChanged(formState) {
        const paymentMethodApiName = apiNameFor(DATA_IMPORT_PAYMENT_METHOD);
        if (!paymentMethodApiName) return false;
        const hasChanged = this._elevateFields.find(field => {
            return formState[field] !== this.formState[field];
        })
        return !!hasChanged ;
    }

    hasAllocationValuesChanged(formState) {
        const donationFieldApiName = apiNameFor(DATA_IMPORT_DONATION_AMOUNT_FIELD);
        const additionalObjectFieldApiName = apiNameFor(DATA_IMPORT_ADDITIONAL_OBJECT_JSON_FIELD)

        return formState[donationFieldApiName] !==
            this.formState[donationFieldApiName]
            ||
            formState[additionalObjectFieldApiName] !==
            this.formState[additionalObjectFieldApiName]
    }

    get isValid() {
        const thisWidget = this.widgetComponent;
        let isValid = false;
        if(thisWidget !== null && typeof thisWidget !== 'undefined'
            && typeof thisWidget.isValid === 'function') {
                isValid = thisWidget.isValid();
        } else if(isUndefined(thisWidget.isValid)) {
            // if no validation function defined, assume widget is valid
            return true;
        }
        return isValid;
    }

    get widgetComponent() {
        return this.template.querySelector('[data-id="widgetComponent"]');
    }

    get isSoftCredit() {
        return this.element.componentName === SOFT_CREDIT_WIDGET;
    }

    @api
    get isElevateTokenizeCard() {
        return this.element.componentName === TOKENIZE_CARD_WIDGET;
    }    

    get isAllocation() {
        return this.element.componentName === ALLOCATION_WIDGET;
    }

    get widgetNotFound(){
        return WIDGET_LIST.indexOf(this.element.componentName) < 0
    }

    @api
    get paymentToken() {
        const thisWidget = this.widgetComponent;
        if (this.isValid) {
            return thisWidget.paymentToken;
        }
    }

}