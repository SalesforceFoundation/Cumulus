import { LightningElement, api, track, wire } from 'lwc';

import sendPurchaseRequest from '@salesforce/apex/GE_GiftEntryController.sendPurchaseRequest';
import upsertDataImport from '@salesforce/apex/GE_GiftEntryController.upsertDataImport';
import submitDataImportToBDI from '@salesforce/apex/GE_GiftEntryController.submitDataImportToBDI';
import validateAuthorizedGiftEdit from '@salesforce/apex/GE_GiftEntryController.validateAuthorizedGiftEdit';
import getPaymentTransactionStatusValues from '@salesforce/apex/GE_PaymentServices.getPaymentTransactionStatusValues';
import { getCurrencyLowestCommonDenominator } from 'c/utilNumberFormatter';
import PAYMENT_AUTHORIZE_TOKEN from '@salesforce/schema/DataImport__c.Payment_Authorization_Token__c';
import PAYMENT_ELEVATE_ID from '@salesforce/schema/DataImport__c.Payment_Elevate_ID__c';
import PAYMENT_ELEVATE_ELEVATE_BATCH_ID from '@salesforce/schema/DataImport__c.Payment_Elevate_Batch_Id__c';
import PAYMENT_CARD_NETWORK from '@salesforce/schema/DataImport__c.Payment_Card_Network__c';
import PAYMENT_EXPIRATION_YEAR from '@salesforce/schema/DataImport__c.Payment_Card_Expiration_Year__c';
import PAYMENT_EXPIRATION_MONTH from '@salesforce/schema/DataImport__c.Payment_Card_Expiration_Month__c';
import PAYMENT_GATEWAY_ID from '@salesforce/schema/DataImport__c.Payment_Gateway_ID__c';
import PAYMENT_GATEWAY_TRANSACTION_ID from '@salesforce/schema/DataImport__c.Payment_Gateway_Payment_ID__c';
import PAYMENT_AUTHORIZED_AT from '@salesforce/schema/DataImport__c.Payment_Authorized_UTC_Timestamp__c';
import PAYMENT_CREATED_AT from '@salesforce/schema/DataImport__c.Payment_Elevate_Created_UTC_Timestamp__c';
import PAYMENT_LAST_4 from '@salesforce/schema/DataImport__c.Payment_Card_Last_4__c';
import PAYMENT_STATUS from '@salesforce/schema/DataImport__c.Payment_Status__c';
import PAYMENT_DECLINED_REASON from '@salesforce/schema/DataImport__c.Payment_Declined_Reason__c';
import DONATION_CAMPAIGN_NAME from '@salesforce/schema/DataImport__c.Donation_Campaign_Name__c';
import PAYMENT_ACH_CODE from '@salesforce/schema/DataImport__c.Payment_ACH_Code__c';
import PAYMENT_ACH_LAST_4 from '@salesforce/schema/DataImport__c.Payment_ACH_Last_4__c';
import PAYMENT_METHOD from '@salesforce/schema/DataImport__c.Payment_Method__c';
import PAYMENT_ELEVATE_ORIGINAL_PAYMENT_ID
    from '@salesforce/schema/DataImport__c.Payment_Elevate_Original_Payment_ID__c';
import PAYMENT_TYPE from '@salesforce/schema/DataImport__c.Payment_Type__c';
import PAYMENT_ACH_CONSENT from '@salesforce/schema/DataImport__c.ACH_Consent__c';

import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { convertBDIToWidgetJson } from './geFormRendererHelper';
import GeFormElementHelper from './geFormElementHelper'
import GeFormService from 'c/geFormService';
import GeLabelService from 'c/geLabelService';
import messageLoading from '@salesforce/label/c.labelMessageLoading';
import { getNumberAsLocalizedCurrency } from 'c/utilNumberFormatter';
import {
    buildErrorMessage,
    DONATION_DONOR_FIELDS,
    DONATION_DONOR,
    handleError,
    getRecordFieldNames,
    setRecordValuesOnTemplate,
    checkPermissionErrors,
    isTrueFalsePicklist,
    trueFalsePicklistOptions,
    CHECKBOX_TRUE,
    CHECKBOX_FALSE,
    PICKLIST_TRUE,
    PICKLIST_FALSE, CONTACT_FIRST_NAME_INFO, CONTACT_LAST_NAME_INFO
} from 'c/utilTemplateBuilder';
import { registerListener, fireEvent } from 'c/pubsubNoPageRef';
import {
    getQueryParameters,
    isEmpty,
    isObject,
    isNotEmpty,
    format,
    isUndefined,
    hasNestedProperty,
    deepClone,
    getNamespace,
    validateJSONString,
    relatedRecordFieldNameFor,
    apiNameFor,
    isString,
    showToast
} from 'c/utilCommon';
import ExceptionDataError from './exceptionDataError';
import ElevateBatch from './elevateBatch';
import ElevateTokenizeableGift from './elevateTokenizeableGift';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FORM_TEMPLATE_FIELD from '@salesforce/schema/DataImportBatch__c.Form_Template__c';
import BATCH_DEFAULTS_FIELD from '@salesforce/schema/DataImportBatch__c.Batch_Defaults__c';
import STATUS_FIELD from '@salesforce/schema/DataImport__c.Status__c';
import NPSP_DATA_IMPORT_BATCH_FIELD from '@salesforce/schema/DataImport__c.NPSP_Data_Import_Batch__c';

import DATA_IMPORT_ADDITIONAL_OBJECT_FIELD from '@salesforce/schema/DataImport__c.Additional_Object_JSON__c'
import DATA_IMPORT_ACCOUNT1_IMPORTED_FIELD from '@salesforce/schema/DataImport__c.Account1Imported__c';
import DATA_IMPORT_CONTACT1_IMPORTED_FIELD from '@salesforce/schema/DataImport__c.Contact1Imported__c';
import DATA_IMPORT_CONTACT1_FIRSTNAME_FIELD from '@salesforce/schema/DataImport__c.Contact1_Firstname__c';
import DATA_IMPORT_CONTACT1_LASTNAME_FIELD from '@salesforce/schema/DataImport__c.Contact1_Lastname__c';
import DATA_IMPORT_DONATION_IMPORTED_FIELD from '@salesforce/schema/DataImport__c.DonationImported__c';
import DATA_IMPORT_PAYMENT_IMPORTED_FIELD from '@salesforce/schema/DataImport__c.PaymentImported__c';
import DATA_IMPORT_DONATION_IMPORT_STATUS_FIELD from '@salesforce/schema/DataImport__c.DonationImportStatus__c';
import DATA_IMPORT_PAYMENT_IMPORT_STATUS_FIELD from '@salesforce/schema/DataImport__c.PaymentImportStatus__c';
import DATA_IMPORT_DONATION_DONOR_FIELD
    from '@salesforce/schema/DataImport__c.Donation_Donor__c';
import DONATION_AMOUNT from '@salesforce/schema/DataImport__c.Donation_Amount__c';
import DONATION_DATE from '@salesforce/schema/DataImport__c.Donation_Date__c';
import DONATION_RECORD_TYPE_NAME
    from '@salesforce/schema/DataImport__c.Donation_Record_Type_Name__c';
import OPP_PAYMENT_AMOUNT
    from '@salesforce/schema/npe01__OppPayment__c.npe01__Payment_Amount__c';
import SCHEDULED_DATE from '@salesforce/schema/npe01__OppPayment__c.npe01__Scheduled_Date__c';
import {
    DISABLE_TOKENIZE_WIDGET_EVENT_NAME,
    LABEL_NEW_LINE,
    ACCOUNT_HOLDER_BANK_TYPES,
    ACCOUNT_HOLDER_TYPES,
    PAYMENT_METHODS, ACH_CODE,
    PAYMENT_METHOD_CREDIT_CARD,
    PAYMENT_UNKNOWN_ERROR_STATUS,
    FAILED
} from 'c/geConstants';


import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import CONTACT_NAME_FIELD from '@salesforce/schema/Contact.Name';
import OPP_PAYMENT_OBJECT from '@salesforce/schema/npe01__OppPayment__c';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import PARENT_OPPORTUNITY_FIELD
    from '@salesforce/schema/npe01__OppPayment__c.npe01__Opportunity__c';
import ELEVATE_PAYMENT_STATUS_FIELD
    from '@salesforce/schema/npe01__OppPayment__c.Elevate_Payment_API_Status__c';
import DATA_IMPORT_OBJECT from '@salesforce/schema/DataImport__c';
import DATA_IMPORT_ACCOUNT1_NAME
    from '@salesforce/schema/DataImport__c.Account1_Name__c';

// Labels are used in BDI_MatchDonations class
import userSelectedMatch from '@salesforce/label/c.bdiMatchedByUser';
import userSelectedNewOpp from '@salesforce/label/c.bdiMatchedByUserNewOpp';
import applyNewPayment from '@salesforce/label/c.bdiMatchedApplyNewPayment';
import CURRENCY from '@salesforce/i18n/currency';

const mode = {
    CREATE: 'create',
    UPDATE: 'update'
};
const DONATION_DONOR_TYPE_ENUM = Object.freeze({
    ACCOUNT1: 'Account1',
    CONTACT1: 'Contact1'
});

const ACH_CONSENT_MESSAGE = 'true';
const EXPANDABLE_SECTION_CONTAINER = 'expandableSectionContainer';

export default class GeFormRenderer extends LightningElement{
    // these three fields are used to query the donor record
    // when opened from an Account or Contact
    @api donorRecordId;
    @api donorRecord;
    @api loadingText;

    fieldNames = [ ACCOUNT_NAME_FIELD, CONTACT_NAME_FIELD ];
    PAYMENT_TRANSACTION_STATUS_ENUM;
    @api sections = [];
    @api showSpinner = false;
    @api batchId;
    @api gift;
    @api submissions = [];
    @api hasPageLevelError = false;
    @api pageLevelErrorMessageList = [];
    @api batchCurrencyIsoCode;

    @track isPermissionError = false;
    @track permissionErrorTitle;
    @track permissionErrorMessage;
    @track formTemplate;
    @track fieldMappings;
    @track ready = false;
    @track name = '';
    @track description = '';
    @track mappingSet = '';
    @track version = '';
    @track formTemplateId;
    _batchDefaults;
    _isElevateWidgetInDisabledState = false;
    _hasPaymentWidget = false;
    latestElevateBatchId = null;
    cardholderNamesNotInTemplate = {};
    _openedGiftId;

    erroredFields = [];
    CUSTOM_LABELS = {...GeLabelService.CUSTOM_LABELS, messageLoading};

    @track widgetConfig = {
        hasPaymentMethodFieldInForm: undefined,
        paymentTransactionStatusValues: undefined
    }
    @track isAccessible = true;

    _isFormCollapsed = false;
    _shouldInformParent = true;

    set selectedDonationOrPaymentRecord(record) {
        if (record.new === true) {
            this.setCreateNewOpportunityInFormState();
        } else if (this.isAPaymentId(record.Id)) {
            this.setSelectedPaymentInFormState(record);
            this.loadPaymentAndParentDonationFieldValues(record);
        } else if (this.isAnOpportunityId(record.Id)) {
            this.setSelectedDonationInFormState(record, record.applyPayment);
            this.loadSelectedDonationFieldValues(record);
        } else {
            throw 'Unsupported selected donation type!';
        }
    }

    setSelectedPaymentInFormState(record) {
        const updatedData = {
            [apiNameFor(DATA_IMPORT_PAYMENT_IMPORTED_FIELD)]: record.Id,
            [apiNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD)]:
                record[apiNameFor(PARENT_OPPORTUNITY_FIELD)],
            [apiNameFor(DATA_IMPORT_PAYMENT_IMPORT_STATUS_FIELD)]: userSelectedMatch,
            [apiNameFor(DATA_IMPORT_DONATION_IMPORT_STATUS_FIELD)]: userSelectedMatch,
            [apiNameFor(PAYMENT_STATUS)]:
                record[apiNameFor(ELEVATE_PAYMENT_STATUS_FIELD)],
        };
        this.updateFormState(updatedData);
    }

    loadPaymentAndParentDonationFieldValues(record) {
        this.loadSelectedRecordFieldValues(
            apiNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD),
            record[apiNameFor(PARENT_OPPORTUNITY_FIELD)]);

        this.loadSelectedRecordFieldValues(
            apiNameFor(DATA_IMPORT_PAYMENT_IMPORTED_FIELD), record.Id);
    }

    setSelectedDonationInFormState(record, isApplyNewPayment = false) {
        this.resetDonationAndPaymentImportedFields();

        this.updateFormState({
            [apiNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD)]: record.Id,
            [apiNameFor(DATA_IMPORT_DONATION_IMPORT_STATUS_FIELD)]:
                isApplyNewPayment ? applyNewPayment : userSelectedMatch
        });
    }

    loadSelectedDonationFieldValues(record) {
        this.loadSelectedRecordFieldValues(
            apiNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD), record.Id);
    }

    @track hasPurchaseCallTimedout = false;

    /*******************************************************************************
     * @description Object used to hold current values for all fields on the form.
     */
    @track
    _formState = {}

    /** Determines when we show payment related text above the cancel and save buttons */
    get showPaymentSaveNotice() {
        return this._hasPaymentWidget && this._isElevateWidgetInDisabledState === false;
    }

    get title() {
        return hasNestedProperty(this.donorRecord, 'fields', 'Name', 'value') ?
            GeLabelService.format(
                this.CUSTOM_LABELS.geHeaderMatchingGiftBy,
                [this.donorRecord.fields.Name.value]) :
            this.CUSTOM_LABELS.commonNewGift;
    }

    get isSingleGiftEntry() {
        return !this.batchId;
    }

    get cancelButtonText() {
        return this.isSingleGiftEntry ?
            this.CUSTOM_LABELS.commonCancel :
            this.CUSTOM_LABELS.geButtonCancelAndClear;
    }

    @wire(getRecord, {recordId: '$donorRecordId', optionalFields: '$fieldNames'})
    wiredGetRecordMethod({error, data}) {
        if (data) {
            this.donorRecord = data;
            this.initializeForm(this.formTemplate, this.fieldMappings);
        } else if (error) {
            console.error(JSON.stringify(error));
        }
    }

    connectedCallback() {
        getPaymentTransactionStatusValues()
            .then(response => {
                this.PAYMENT_TRANSACTION_STATUS_ENUM = Object.freeze(JSON.parse(response));
            });
        registerListener('paymentError', this.handleAsyncWidgetError, this);
        registerListener('doNotChargeState', this.handleDisableElevateWidgetState, this);
        registerListener('geModalCloseEvent', this.handleChangeSelectedDonation, this);
        registerListener('nullPaymentFieldsInFormState', this.handleNullPaymentFieldsInFormState, this);
        registerListener('formRendererReset', this.reset, this);
        registerListener('widgetStateChange', this.handleWidgetStateChange, this);

        GeFormService.getFormTemplate().then(response => {
            if (this.batchId) {
                // When the form is being used for Batch Gift Entry, the Form Template JSON
                // uses the @wire service below to retrieve the Template using the Template Id
                // stored on the Batch.
                return;
            }

            // check if there is a record id in the url
            this.donorRecordId = getQueryParameters().c__donorRecordId;
            const donorApiName = getQueryParameters().c__apiName;
            if (donorApiName) {
                this.initializeDonationDonorTypeInFormState(donorApiName);
            }

            // read the template header info
            if (response !== null && typeof response !== 'undefined') {
                this.formTemplate = response.formTemplate;
                this.fieldMappings = response.fieldMappingSetWrapper.fieldMappingByDevName;

                let errorObject = checkPermissionErrors(this.formTemplate);
                if (errorObject) {
                    this.setPermissionsError(errorObject);

                    return;
                }

                // get the target field names to be used by getRecord
                let fieldNamesFromTemplate =
                    getRecordFieldNames(this.formTemplate, this.fieldMappings, donorApiName);
                this.fieldNames = [...this.fieldNames, ...fieldNamesFromTemplate];
                if (isEmpty(this.donorRecordId)) {
                    // if we don't have a donor record, it's ok to initialize the form now
                    // otherwise the form will be initialized after wiredGetRecordMethod completes
                    this.initializeForm(this.formTemplate);
                }
            }
        });
    }

    handleWidgetStateChange(changeEvent) {
        if (changeEvent.state === 'readOnly') {
            this._isElevateWidgetInDisabledState = true;
        }
    }

    handleNullPaymentFieldsInFormState() {
        if (this.shouldNullPaymentRelatedFields()) {
            this.nullPaymentFieldsInFormState([
                apiNameFor(PAYMENT_AUTHORIZE_TOKEN),
                apiNameFor(PAYMENT_DECLINED_REASON),
                apiNameFor(PAYMENT_STATUS),
                apiNameFor(PAYMENT_ELEVATE_ELEVATE_BATCH_ID),
                apiNameFor(PAYMENT_ELEVATE_ID),
                apiNameFor(PAYMENT_ELEVATE_ORIGINAL_PAYMENT_ID),
                apiNameFor(PAYMENT_LAST_4),
                apiNameFor(PAYMENT_CARD_NETWORK),
                apiNameFor(PAYMENT_EXPIRATION_MONTH),
                apiNameFor(PAYMENT_EXPIRATION_YEAR),
                apiNameFor(PAYMENT_AUTHORIZED_AT),
                apiNameFor(PAYMENT_GATEWAY_ID),
                apiNameFor(PAYMENT_GATEWAY_TRANSACTION_ID),
            ]);
        }
    }

    initializeDonationDonorTypeInFormState(donorApiName) {
        const updates = new Map();
        updates.set(DATA_IMPORT_DONATION_DONOR_FIELD, donorApiName);
        this.updateFormState(updates);
    }

    getDonationDonorTypeFor(donorApiName) {
        switch (donorApiName) {
            case 'Account':
                return DONATION_DONOR_TYPE_ENUM.ACCOUNT1;
            case 'Contact':
                return DONATION_DONOR_TYPE_ENUM.CONTACT1;
            default:
                throw `Unsupported donorApiName of: ${donorApiName}`;
        }
    }

    initializeForm(formTemplate, fieldMappings) {
        // read the template header info
        this.ready = true;
        this.name = formTemplate.name;
        this.description = formTemplate.description;
        this.version = formTemplate.layout.version;

        if (typeof formTemplate.layout !== 'undefined'
            && Array.isArray(formTemplate.layout.sections)) {
            // add record data to the template fields

            if (isNotEmpty(fieldMappings) && isNotEmpty(this.donorRecord)) {
                this.sections = setRecordValuesOnTemplate(formTemplate.layout.sections,
                    fieldMappings, this.donorRecord);
            } else {
                this.sections = formTemplate.layout.sections;
            }

            if (!this.isSingleGiftEntry) {
                this.sections = this.prepareFormForBatchMode(formTemplate.layout.sections);
                this.dispatchEvent(new CustomEvent('sectionsretrieved'));
            }
        }

        this.sections = this.appendRecordTypeLocationInfoToPicklistElements();
        this.initializeFormState();
        this.initializeWidgetConfig();
    }

    initializeWidgetConfig() {
        this.widgetConfig.hasPaymentMethodFieldInForm = this.sourceFieldsUsedInTemplate().includes(apiNameFor(PAYMENT_METHOD));
        this.widgetConfig.paymentTransactionStatusValues = this.PAYMENT_TRANSACTION_STATUS_ENUM;
    }

    appendRecordTypeLocationInfoToPicklistElements() {

        this.sections
            .forEach(section => {
                section.elements
                    .forEach(element => {
                        this.enrichElement(element);
                    });
            });

        return [...this.sections];
    }

    appendRecordTypeLocationInfo(element) {
        const fieldMappingDevName =
            element.dataImportFieldMappingDevNames &&
            element.dataImportFieldMappingDevNames[0];

        if (fieldMappingDevName) {
            element.siblingRecordTypeField =
                this.siblingRecordTypeFieldFor(fieldMappingDevName);
            element.parentRecordField =
                this.parentRecordFieldFor(fieldMappingDevName);
        }
    }

    enrichElement(element) {
        this.appendRecordTypeLocationInfo(element);
        this.appendElementHelperData(element);
    }

    appendElementHelperData(element) {
        const helper = new GeFormElementHelper(element);
        element.isRenderable = helper.isRenderable();
        if (helper.isTrueFalsePicklist()) {
            element.picklistOptionsOverride = trueFalsePicklistOptions();
        }
    }

    setPermissionsError(errorObject) {
        if (errorObject) {
            this.isPermissionError = true;
            this.permissionErrorTitle = errorObject.errorTitle;
            this.permissionErrorMessage = errorObject.errorMessage;
        }
    }

    @wire(getRecord, {
        recordId: '$batchId',
        fields: [FORM_TEMPLATE_FIELD, BATCH_DEFAULTS_FIELD]
    })
    wiredBatch({data, error}) {
        if (data) {
            this.formTemplateId = data.fields[apiNameFor(FORM_TEMPLATE_FIELD)].value;
            this._batchDefaults = data.fields[apiNameFor(BATCH_DEFAULTS_FIELD)].value;
            GeFormService.getFormTemplateById(this.formTemplateId)
                .then(formTemplate => {
                    this.formTemplate = formTemplate;

                    let errorObject = checkPermissionErrors(formTemplate);
                    if (errorObject) {
                        this.dispatchEvent(new CustomEvent('permissionerror'));
                        this.setPermissionsError(errorObject)
                    }
                    this.initializeForm(formTemplate, GeFormService.fieldMappings);
                })
                .catch(err => {
                    handleError(err);
                });
        } else if (error) {
            handleError(error);
        }
    }

    handleCancel() {
        this.reset();
        this.initializeFormState();

        if (this.isSingleGiftEntry) {
            const originatedFromRecordDetailPage = getQueryParameters().c__donorRecordId;
            if (originatedFromRecordDetailPage) {
                this.goToRecordDetailPage(originatedFromRecordDetailPage);
            } else {
                this.goToLandingPage();
            }
        }
    }

    goToRecordDetailPage(recordId) {
        if (!recordId) return;
        const navigateEvent = new CustomEvent('navigate', {
            detail: {
                to: 'recordPage',
                recordId: recordId
            }
        });
        this.dispatchEvent(navigateEvent);
    }

    goToLandingPage() {
        const navigateEvent = new CustomEvent('navigate', {
            detail: {
                to: 'landingPage'
            }
        });
        this.dispatchEvent(navigateEvent);
    }

    /*******************************************************************************
    * @description Dispatches an event to the geFormWidgetTokenizeCard component
    * to disable itself and display the provided message.
    *
    * @param {string} message: Message to display in the UI
    */
    dispatchDisablePaymentServicesWidgetEvent(message) {
        fireEvent(this, DISABLE_TOKENIZE_WIDGET_EVENT_NAME,
            { detail: { message: message } });
    }

    /*******************************************************************************
    * @description Dispatches an event and notifies the parent component to display
    * an aura overlay library modal with a lightning web component in its body.
    *
    * @param {string} modalBodyComponentName: Name of the LWC to render in the
    * overlay library modal's body.
    */
    toggleModalByComponentName(modalBodyComponentName, componentProperties) {
        const detail = {
            modalProperties: {
                componentName: modalBodyComponentName,
                showCloseButton: false
            }, 
            componentProperties
        };
        this.dispatchEvent(new CustomEvent('togglemodal', { detail }));
    }

    continueBatchGiftEntrySave(dataImportRecord, formControls, isCreditCardAuth) {
        // reset function for callback
        const reset = () => this.reset();
        // handle error on callback from promise
        const handleCatchError = (err) => this.handleCatchOnSave(err);

        this.dispatchEvent(new CustomEvent('submit', {
            detail: {
                dataImportRecord,
                success: () => {
                    formControls.enableSaveButton();
                    formControls.toggleSpinner();
                    reset();
                    
                    if (isCreditCardAuth) {
                        showToast(
                            this.CUSTOM_LABELS.PageMessagesConfirm,
                            this.CUSTOM_LABELS.geAuthorizedCreditCardSuccess, 
                            'success', 
                            'dismissible', 
                            null
                        );
                    }
                },
                error: (error) => {
                    formControls.enableSaveButton();
                    formControls.toggleSpinner();
                    handleCatchError(error);
                }
            }
        }));
    }

    handleCatchOnSave( error ) {
        // var inits
        const sectionsList = this.template.querySelectorAll('c-ge-form-section');
        const exceptionWrapper = new ExceptionDataError(error);
        const allDisplayedFields = this.getDisplayedFieldsMappedByAPIName(sectionsList);
        this.hasPageLevelError = true;

        if (isNotEmpty(exceptionWrapper.exceptionType)) {

            // Check to see if there are any field level errors
            if (Object.entries(exceptionWrapper.DMLErrorFieldNameMapping).length === undefined ||
                Object.entries(exceptionWrapper.DMLErrorFieldNameMapping).length === 0) {

                // validation rules on Target Objects shows up here
                // unfortunately currently it doesnt bring field info yet
                if (isNotEmpty(exceptionWrapper.errorMessage)) {
                    let errorMessage = exceptionWrapper.errorMessage;

                    const errorMessageObject = validateJSONString(exceptionWrapper.errorMessage);
                    if (errorMessageObject) {
                        errorMessage = errorMessageObject.errorMessage;
                    }

                    this.addPageLevelErrorMessage({ errorMessage, index: this.pageLevelErrorMessageList.length });
                }

                // If there are no specific fields the error has to go to,
                // put it on the page level error message.
                for (const dmlIndex in exceptionWrapper.DMLErrorMessageMapping) {
                    const errorMessage = exceptionWrapper.DMLErrorMessageMapping[dmlIndex];
                    const index = dmlIndex + 1;
                    this.addPageLevelErrorMessage({ errorMessage, index });
                }

            } else {
                // If there is a specific field that each error is supposed to go to,
                // show it on the field on the page.
                // If it is not on the page to show, display it on the page level.
                for (const key in exceptionWrapper.DMLErrorFieldNameMapping) {

                    // List of fields with this error
                    let fieldList = exceptionWrapper.DMLErrorFieldNameMapping[key];
                    // Error message for the field.
                    let errorMessage = exceptionWrapper.DMLErrorMessageMapping[key];
                    // Errored fields that are not displayed
                    let hiddenFieldList = [];

                    fieldList.forEach(fieldWithError => {

                        // Go to the field and set the error message using setCustomValidity
                        if (fieldWithError in allDisplayedFields) {
                            let fieldInput = allDisplayedFields[fieldWithError];
                            this.erroredFields.push(fieldInput);
                            fieldInput.setCustomValidity(errorMessage);
                        } else {
                            // Keep track of errored fields that are not displayed.
                            hiddenFieldList.push(fieldWithError);
                        }

                    });

                    // If there are hidden fields, display the error message at the page level.
                    // With the fields noted.
                    if (hiddenFieldList.length > 0) {
                        let combinedFields = hiddenFieldList.join(', ');
                        this.addPageLevelErrorMessage({
                            errorMessage: `${errorMessage} [${combinedFields}]`,
                            index: key
                        });
                    }
                }
            }
        } else {
            this.addPageLevelErrorMessage({ errorMessage: exceptionWrapper.errorMessage, index: 0 });
        }

        // focus either the page level or field level error message somehow
        window.scrollTo(0, 0);
    }

    /*******************************************************************************
     * @description Add an error message to the overall page level error messages
     * array.
     *
     * @param errorObject
     */
    addPageLevelErrorMessage(errorObject) {
        errorObject.index = errorObject.index ? errorObject.index : 0;
        this.pageLevelErrorMessageList = [
            ...this.pageLevelErrorMessageList,
            { ...errorObject }
        ];
        this.hasPageLevelError = true;
    }

    /*******************************************************************************
    * @description Handles the form save action. Builds a data import record and
    * calls handlers for Batch Gift and Single Gift depending on the form's mode.
    *
    * @param {object} event: Onclick event from the form save button
    */
    async handleSave(event) {
        const sectionsList = this.template.querySelectorAll('c-ge-form-section');
        const isFormReadyToSave = this.prepareFormForSave(sectionsList);

        if (isFormReadyToSave) {
            // Disable save button
            this.loadingText = '';
            event.target.disable = true;
            const formControls = this.getFormControls(event);
            formControls.toggleSpinner();

            let tokenizedGift = null;
            try {
                if (this.shouldTokenizeCard()) {
                    tokenizedGift = new ElevateTokenizeableGift(
                        this.cardholderNames,
                        getCurrencyLowestCommonDenominator(
                            this.getFieldValueFromFormState(DONATION_AMOUNT)
                        )
                    );

                    this.updateFormState(await tokenizedGift.tokenize(sectionsList));
                }
            } catch(ex) {
                // exceptions that we expect here are all async widget-related
                this.handleAsyncWidgetError(ex);
                return;
            }

            if (this.batchId) {
                await this.submitBatch(formControls, tokenizedGift);
            } else {
                await this.submitSingleGift();
            }
        }
    }

    async submitBatch(formControls, tokenizedGift) {
        this.handleNullPaymentFieldsInFormState();

        if (this.isGiftAuthorized() && !tokenizedGift && this._openedGiftId) {
            const canUpdate = await this.canAuthorizedGiftBeUpdated(
                this.saveableFormState(), formControls);
            if (!canUpdate) { return; }
        }

        const hasSaved = await this.saveDataImport(this.saveableFormState());
        if (!hasSaved) {
            this.disabled = false;
            this.toggleSpinner();
            return;
        }

        await this.prepareForBatchGiftSave(this.saveableFormState(), formControls, tokenizedGift);
    }

    shouldNullPaymentRelatedFields() {
        return (this.isGiftAuthorized() || this.isGiftExpired())
            && this.selectedPaymentMethod() !== PAYMENT_METHOD_CREDIT_CARD;
    }

    async prepareForBatchGiftSave(dataImportFromFormState, formControls, tokenizedGift) {
        if (tokenizedGift) {
            try {
                this.loadingText = this.CUSTOM_LABELS.geAuthorizingCreditCard;
    
                const currentElevateBatch = new ElevateBatch(this.latestElevateBatchId);
                const authorizedGift = await currentElevateBatch.add(tokenizedGift);
                const isAuthorized = authorizedGift.status === this.PAYMENT_TRANSACTION_STATUS_ENUM.AUTHORIZED
                    || authorizedGift.status === this.PAYMENT_TRANSACTION_STATUS_ENUM.PENDING;

                if (isAuthorized) {
                    this.updateFormState({
                        [apiNameFor(PAYMENT_ELEVATE_ELEVATE_BATCH_ID)]: currentElevateBatch.elevateBatchId,
                        [apiNameFor(PAYMENT_ELEVATE_ID)]: authorizedGift.paymentId,
                        [apiNameFor(PAYMENT_STATUS)]: this.PAYMENT_TRANSACTION_STATUS_ENUM.AUTHORIZED,
                        [apiNameFor(PAYMENT_ELEVATE_ORIGINAL_PAYMENT_ID)]: authorizedGift.originalTransactionId,
                        [apiNameFor(PAYMENT_DECLINED_REASON)]: authorizedGift.declineReason,
                        [apiNameFor(PAYMENT_LAST_4)]: authorizedGift.cardLast4,
                        [apiNameFor(PAYMENT_CARD_NETWORK)]: authorizedGift.cardNetwork,
                        [apiNameFor(PAYMENT_EXPIRATION_MONTH)]: authorizedGift.cardExpirationMonth,
                        [apiNameFor(PAYMENT_EXPIRATION_YEAR)]: authorizedGift.cardExpirationYear,
                        [apiNameFor(PAYMENT_AUTHORIZED_AT)]: authorizedGift.authorizedAt,
                        [apiNameFor(PAYMENT_GATEWAY_ID)]: authorizedGift.gatewayId,
                        [apiNameFor(PAYMENT_GATEWAY_TRANSACTION_ID)]: authorizedGift.gatewayTransactionId,
                        [apiNameFor(PAYMENT_DECLINED_REASON)]: null,
                        [apiNameFor(STATUS_FIELD)]: null
                    });

                    this.deleteFieldFromFormState(apiNameFor(PAYMENT_AUTHORIZE_TOKEN));
                    dataImportFromFormState = this.saveableFormState();
                } else {
                    await this.handleAuthorizationFailure(authorizedGift.declineReason);
                    return;
                }
            } catch (ex) {
                await this.handleAuthorizationFailure(buildErrorMessage(ex));
                return;
            }
        }

        this.continueBatchGiftEntrySave(dataImportFromFormState, formControls, !!tokenizedGift);
    }

    async handleAuthorizationFailure(declineReason) {
        this.updateFormState({
            [apiNameFor(PAYMENT_DECLINED_REASON)]: declineReason,
            [apiNameFor(PAYMENT_STATUS)]: this.PAYMENT_TRANSACTION_STATUS_ENUM.DECLINED,
            [apiNameFor(STATUS_FIELD)]: FAILED
        });
        await this.saveDataImport(this.saveableFormState());

        const errors = [{ message: declineReason }];
        this.handleElevateAPIErrors(errors);

        fireEvent(this, 'refreshtable', {});
    }

    /*******************************************************************************
    * @description On an authorized data import record where re-tokenization is not
    * required, validate that certain payment-related fields have not been modified
    *
    * @param {object} dataImportFromFormState: Representing data import record
    * @param {object} formControls: Used to drive UI elements like spinner and button
    * visibility
    *
    * @return {boolean}: True if the gift can be saved in its current state
    */
    async canAuthorizedGiftBeUpdated(dataImportFromFormState, formControls) {
        try {
            await validateAuthorizedGiftEdit({dataImport: dataImportFromFormState});
        } catch (ex) {
            this.handleCatchOnSave(ex.body.message);
            formControls.enableSaveButton();
            formControls.toggleSpinner();
            return false;
        }

        return true;
    }

    isGiftAuthorized() {
        return this.formState[apiNameFor(PAYMENT_STATUS)] === this.PAYMENT_TRANSACTION_STATUS_ENUM.AUTHORIZED;
    }

    isGiftExpired() {
        return this.formState[apiNameFor(PAYMENT_STATUS)] === this.PAYMENT_TRANSACTION_STATUS_ENUM.EXPIRED;
    }
    
    shouldNotNullPaymentFields() {
        return (this.isGiftAuthorized() || this.isGiftExpired());
    }

    shouldTokenizeCard() {
        return !!(this.showPaymentSaveNotice) && this.hasChargeableTransactionStatus();
    }

    /*******************************************************************************
    * @description Clears existing errors from the form and re-validates all form
    * sections.
    *
    * @param {list} sectionsList: List of all the form sections
    *
    * @return {boolean}: True if the form is ready for a save attempt.
    */
    prepareFormForSave(sectionsList) {
        // clean errors present on form
        this.clearErrors();
        // apply custom and standard field validation
        return this.isFormValid(sectionsList);

    }

    /*******************************************************************************
    * @description Collects form controls for toggling the spinner and enabling
    * the form save button in one object.
    *
    * @param {object} event: Onclick event from the form save button
    *
    * @return {object}: An object with methods that toggle the form lightning
    * spinner and enables the form save button.
    */
    getFormControls(event) {
        const toggleSpinner = () => this.toggleSpinner();
        const enableSaveButton = function () {
            this.disabled = false;
        }.bind(event.target);

        return { toggleSpinner, enableSaveButton };
    }

    isFormValid(sectionsList) {

        // custom donor type validation
        if (this.isDonorTypeInvalid(sectionsList)) {
            return false;
        }

        // field validations
        let invalidFields = [];
        sectionsList.forEach(section => {
            const fields = section.getInvalidFields();
            invalidFields.push(...fields);
        });

        if (invalidFields.length > 0) {
            let fieldListAsString = invalidFields.join(', ');
            this.hasPageLevelError = true;
            this.pageLevelErrorMessageList = [ {
                index: 0,
                errorMessage: `The following fields are required: ${fieldListAsString}`
            } ];
        }

        return invalidFields.length === 0;
    }

    /**
     * validates donation donor type on sectionsList
     * @param sectionsList, list of sections
     * @returns {boolean|*} - true if form invalid, false otherwise
     */
    isDonorTypeInvalid(sectionsList) {

        const DONATION_VALUES = [
            DONATION_DONOR_FIELDS.donationDonorField,
            DONATION_DONOR_FIELDS.account1ImportedField, DONATION_DONOR_FIELDS.account1NameField,
            DONATION_DONOR_FIELDS.contact1ImportedField, DONATION_DONOR_FIELDS.contact1LastNameField
        ];
        // get label and value using apiName as key from fields for each section
        let miniFieldWrapper = {};
        sectionsList.forEach(section => {
            miniFieldWrapper = { ...miniFieldWrapper, ...(section.getFieldValueAndLabel(DONATION_VALUES))};
        });

        // if no donation donor selection, nothing to validate here yet
        if ( isEmpty(miniFieldWrapper[DONATION_DONOR_FIELDS.donationDonorField].value) ) {
            return false;
        }

        // returns true when error message was generated
        return this.getDonorTypeValidationError( miniFieldWrapper, sectionsList );
    }

    /**
     * helper class for isDonorTypeInvalid, contains majority of logic
     * @param fieldWrapper - Array, field ui-label and value using field-api-name as key
     * @param sectionsList - Array, all sections
     * @returns {boolean} - true if error message was generated, false if otherwise
     */
    getDonorTypeValidationError(fieldWrapper, sectionsList) {

        // get data import record helper
        const di_record = this.getDataImportHelper(fieldWrapper);

        // donation donor validation depending on selection and field presence
        let isError = (di_record.donationDonorValue === DONATION_DONOR.isAccount1) ?
            di_record.isAccount1ImportedEmpty && di_record.isAccount1NameEmpty :
            di_record.donationDonorValue === DONATION_DONOR.isContact1 &&
            di_record.isContact1ImportedEmpty && di_record.isContact1LastNameEmpty;

        // process error notification when error
        if (isError) {
            // highlight validation fields
            this.highlightValidationErrorFields(di_record, sectionsList, ' ');
            // set page error
            this.hasPageLevelError = true;
            this.pageLevelErrorMessageList = [ {
                index: 0,
                errorMessage: this.getDonationDonorErrorLabel(di_record, fieldWrapper)
            } ];
        }

        return isError;
    }

    /**
     * Set donation donor error message using custom label depending on field presence
     * @param diRecord, Object - helper obj
     * @param fieldWrapper, Array of fields with Values and Labels
     * @returns {String}, formatted error message for donation donor validation
     */
    getDonationDonorErrorLabel(diRecord, fieldWrapper) {

        // init array replacement for custom label
        let validationErrorLabelReplacements = [diRecord.donationDonorValue, diRecord.donationDonorLabel];

        if (diRecord.donationDonorValue === DONATION_DONOR.isAccount1) {
            if (diRecord.isAccount1ImportedPresent)
                validationErrorLabelReplacements.push(fieldWrapper[DONATION_DONOR_FIELDS.account1ImportedField].label);
            if (diRecord.isAccount1NamePresent)
                validationErrorLabelReplacements.push(fieldWrapper[DONATION_DONOR_FIELDS.account1NameField].label);
        } else {
            if (diRecord.isContact1ImportedPresent)
                validationErrorLabelReplacements.push(fieldWrapper[DONATION_DONOR_FIELDS.contact1ImportedField].label);
            if (diRecord.isContact1LastNamePresent)
                validationErrorLabelReplacements.push(fieldWrapper[DONATION_DONOR_FIELDS.contact1LastNameField].label);
        }

        // set label depending fields present on template
        let label;
        switch (validationErrorLabelReplacements.length) {
            case 2:
                label = this.CUSTOM_LABELS.geErrorDonorTypeInvalid;
                break;
            case 3:
                label = this.CUSTOM_LABELS.geErrorDonorTypeValidationSingle;
                break;
            case 4:
                label = this.CUSTOM_LABELS.geErrorDonorTypeValidation;
                break;
            default:
                label = this.CUSTOM_LABELS.geErrorDonorTypeInvalid;
        }

        // set message using replacement array
        return format(label, validationErrorLabelReplacements);
    }

    /**
     * highlight geForm fields on lSections using sError as message
     * @param diRecord, Object - helper obj
     * @param lSections, Array of geFormSection
     * @param sError, String to set on setCustomValidity
     */
    highlightValidationErrorFields(diRecord, lSections, sError) {

        // prepare array to highlight fields that require attention depending on Donation_Donor
        const highlightFields = [DONATION_DONOR_FIELDS.donationDonorField,
            diRecord.donationDonorValue === DONATION_DONOR.isAccount1 ? DONATION_DONOR_FIELDS.account1ImportedField :
                DONATION_DONOR_FIELDS.contact1ImportedField,
            diRecord.donationDonorValue === DONATION_DONOR.isAccount1 ? DONATION_DONOR_FIELDS.account1NameField :
                DONATION_DONOR_FIELDS.contact1LastNameField
        ];
        lSections.forEach(section => {
            section.setCustomValidityOnFields(highlightFields, sError);
        });

    }

    /**
     * helper object to minimize length of if statements and improve code legibility
     * @param fieldWrapper, Array of fields with Values and Labels
     * @returns Object, helper object to minimize length of if statements and improve code legibility
     */
    getDataImportHelper(fieldWrapper) {
        return {
            // donation donor
            donationDonorValue: fieldWrapper[DONATION_DONOR_FIELDS.donationDonorField].value,
            donationDonorLabel: fieldWrapper[DONATION_DONOR_FIELDS.donationDonorField].label,
            // empty val checks
            isAccount1ImportedEmpty: isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.account1ImportedField]) ||
                isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.account1ImportedField].value),
            isContact1ImportedEmpty: isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.contact1ImportedField]) ||
                isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.contact1ImportedField].value),
            isContact1LastNameEmpty: isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.contact1LastNameField]) ||
                isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.contact1LastNameField].value),
            isAccount1NameEmpty: isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.account1NameField]) ||
                isEmpty(fieldWrapper[DONATION_DONOR_FIELDS.account1NameField].value),
            // field presence
            isAccount1ImportedPresent: isNotEmpty(fieldWrapper[DONATION_DONOR_FIELDS.account1ImportedField]),
            isAccount1NamePresent: isNotEmpty(fieldWrapper[DONATION_DONOR_FIELDS.account1NameField]),
            isContact1ImportedPresent: isNotEmpty(fieldWrapper[DONATION_DONOR_FIELDS.contact1ImportedField]),
            isContact1LastNamePresent: isNotEmpty(fieldWrapper[DONATION_DONOR_FIELDS.contact1LastNameField])
        };
    }

    // change showSpinner to the opposite of its current value
    toggleSpinner() {
        this.showSpinner = !this.showSpinner;
    }

    getDisplayedFieldsMappedByAPIName(sectionsList) {
        let allFields = {};
        sectionsList.forEach(section => {
            const fields = section.getAllFieldsByAPIName();

            allFields = Object.assign(allFields, fields);
        });

        return allFields;
    }

    clearErrors() {

        // Clear the page level error
        this.hasPageLevelError = false;
        this.pageLevelErrorMessageList = [];

        // Clear the field level errors
        if (this.erroredFields.length > 0) {
            this.erroredFields.forEach(fieldToReset => {
                fieldToReset.setCustomValidity('');
            });
        }

        this.erroredFields = [];
    }

    @api
    loadDataImportRecord(dataImport) {
        const isAlreadyOpen = dataImport.Id === this._openedGiftId;
        if (isAlreadyOpen) {
            return;
        }

        this.expandForm();
        const dataImportWithNullValuesAppended =
            this.appendNullValuesForMissingFields(dataImport);

        dataImportWithNullValuesAppended[apiNameFor(DATA_IMPORT_ADDITIONAL_OBJECT_FIELD)] =
            convertBDIToWidgetJson(dataImportWithNullValuesAppended[apiNameFor(DATA_IMPORT_ADDITIONAL_OBJECT_FIELD)]);
        this.reset();
        this.updateFormState(dataImportWithNullValuesAppended);
        this._openedGiftId = dataImport.Id;
    }

    reset() {
        this.clearErrors();
        this.resetFormState();
        this._openedGiftId = null;
    }

    resetFormState() {
        fireEvent(this, 'resetReviewDonationsEvent', {});
        this.initializeFormState();
        this.resetElevateWidget();
        this._isElevateWidgetInDisabledState = false;
    }

    resetFieldsForObjMappingApplyDefaults(objectMappingDeveloperName) {
        this.setFormStateToInitialFieldValuesForObjMapping(objectMappingDeveloperName);
    }

    fieldMappingDevNamesFor(objectMappingDeveloperName) {
        return Object.values(GeFormService.fieldMappings)
            .filter(
                ({Target_Object_Mapping_Dev_Name}) =>
                    Target_Object_Mapping_Dev_Name === objectMappingDeveloperName)
            .map(({DeveloperName}) => DeveloperName);
    }

    get mode() {
        return this.getFieldValueFromFormState('Id') ?
            mode.UPDATE :
            mode.CREATE;
    }

    get saveActionLabel() {
        return this.isSingleGiftEntry ?
            this.CUSTOM_LABELS.commonSave :
            this.mode === mode.UPDATE ?
                this.CUSTOM_LABELS.commonUpdate :
                this.CUSTOM_LABELS.geButtonSaveNewGift;
    }

    get isUpdateActionDisabled() {
        return this.getFieldValueFromFormState(STATUS_FIELD) === 'Imported';
    }

    get cardholderNames() {
        const names = this.donorNames;
        const firstName = isNotEmpty(names.firstName) ? names.firstName : '';
        const lastName = isNotEmpty(names.lastName) ? names.lastName : '';
        const accountName = isNotEmpty(names.accountName) ? names.accountName : '';
        if (this.donorType === DONATION_DONOR_TYPE_ENUM.ACCOUNT1) {
            return {
                firstName: accountName,
                lastName: accountName
            }
        } else {
            return { firstName, lastName };
        }
    }

    get donorNames() {
        let donorNames = {};

        const nameFields = {
            firstName: DATA_IMPORT_CONTACT1_FIRSTNAME_FIELD,
            lastName: DATA_IMPORT_CONTACT1_LASTNAME_FIELD,
            accountName: DATA_IMPORT_ACCOUNT1_NAME
        };

        Object.entries(nameFields).forEach(([k, v]) => {
            const formStateValue = this.getFieldValueFromFormState(v);
            const notInTemplateValue = this.getFieldValueFromCardholderState(v);
            donorNames[k] = formStateValue || notInTemplateValue;
        });

        return donorNames;
    }

    /**
     * Handle payment errors at the form level
     * @param event The paymentError event object
     */
    handleAsyncWidgetError(event) {
        let errorMessage = this.CUSTOM_LABELS.commonUnknownError;
        let errorResponse;

        if (event.error && event.error.message) {
            errorMessage = event.error.message[0];

            if (event.error.message.length > 1) {
                errorResponse = event.error.message[1];
            }
        }

        let errorObjects = [];
        if (event.error && event.error.isObject) {
            // Represents the error response returned from payment services
            let errorObject = JSON.parse(errorResponse);
            errorObject.forEach((message, index) => {
                errorObjects.push({
                    message: message,
                    index: index
                });
            });

        } else if (errorResponse) {
            let errorObject = errorResponse.message
                ? errorResponse
                : {
                    message: errorResponse,
                    index: 0
                };
            errorObjects.push(errorObject);
        }

        this.pageLevelErrorMessageList = [{
            index: 0,
            errorMessage: errorMessage,
            multilineMessages: errorObjects
        }];
        this.showSpinner = false;
        this.hasPageLevelError = true;
    }

    /**
     * @description Set variable that informs the form renderer when the widget is in a disabled state
     * @param event
     */
    handleDisableElevateWidgetState (event) {
        this._isElevateWidgetInDisabledState = event.isElevateWidgetDisabled;
        if (this._isElevateWidgetInDisabledState) {
            this.nullPaymentFieldsInFormState([
                apiNameFor(PAYMENT_AUTHORIZE_TOKEN),
                apiNameFor(PAYMENT_DECLINED_REASON),
                apiNameFor(PAYMENT_STATUS)
            ]);
        }
    }

    handleFormWidgetChange = (event) => {
        this.updateFormState(event.detail);
    }

    /*******************************************************************************
     * @description Pass through method that receives an event from geReviewDonations
     * to notify the parent component to construct a modal for reviewing donations.
     *
     * @param {object} event: Event object containing a payload for the modal.
     */
    toggleModal(event) {
        this.dispatchEvent(new CustomEvent('togglemodal', { detail: event.detail }));
    }

    getSiblingFieldsForSourceField(sourceFieldApiName) {
        const objectMapping = Object.values(GeFormService.objectMappings)
            .find(({Imported_Record_Field_Name}) =>
                Imported_Record_Field_Name === sourceFieldApiName);
        return this.getSiblingFields(objectMapping.DeveloperName);
    }

    getSiblingFields(objectMappingDeveloperName) {
        // For a given field, get the full list of fields related to its object mapping

        // 1. Get this field's object mapping
        // 2. Get the other field mappings that have the same Target_Object_Mapping_Dev_Name
        // 3. Return the list of fields from those mappings

        const objectMapping =
            GeFormService.getObjectMapping(objectMappingDeveloperName);

        const relevantFieldMappings =
            Object.values(GeFormService.fieldMappings)
                .filter(({Target_Object_Mapping_Dev_Name}) =>
                    Target_Object_Mapping_Dev_Name === objectMapping.DeveloperName);

        // Return the sibling fields used by Advanced Mapping
        const relevantFields = relevantFieldMappings.map(
            ({Target_Field_API_Name}) =>
                `${objectMapping.Object_API_Name}.${Target_Field_API_Name}`);

        if (this.isPaymentImportedField(objectMapping.Imported_Record_Field_Name)) {
            const pmtAmountField =
                `${objectMapping.Object_API_Name}.${apiNameFor(OPP_PAYMENT_AMOUNT)}`;
            const pmtScheduledDate =
                `${objectMapping.Object_API_Name}.${apiNameFor(SCHEDULED_DATE)}`;
            relevantFields.push(pmtAmountField, pmtScheduledDate);
        }
        return relevantFields;
    }

    objectMappingDeveloperNameFor(fieldApiName) {
        const objectMapping = this.getObjectMapping(fieldApiName);
        return objectMapping && objectMapping.DeveloperName;
    }

    @track selectedDonationCopyForReviewDonationsModal;
    handleChangeSelectedDonation(event) {
        this.selectedDonationCopyForReviewDonationsModal =
            event.detail.payment || event.detail.opportunity;

        this.selectedDonationOrPaymentRecord =
            this.selectedDonationCopyForReviewDonationsModal;
        if (!this.isSingleGiftEntry) {
            this.expandForm();
        }

        this.resetElevateWidget();
    }

    resetElevateWidget() {
        fireEvent(this, 'resetElevateWidget', {});
    }

    hasSelectedDonationOrPayment() {
        return !!this.selectedDonationOrPaymentRecordId();
    }

    setCreateNewOpportunityInFormState() {
        this.resetDonationAndPaymentImportedFields();
        this.updateFormState({
            [apiNameFor(DATA_IMPORT_DONATION_IMPORT_STATUS_FIELD)]: userSelectedNewOpp
        });
    }


    resetDonationAndPaymentImportedFields() {
        this.resetSelectedPaymentFieldsInFormState();
        this.resetSelectedDonationFieldsInFormState();
    }

    /**
     * @description Function that prepares (sets batch defaults, remove credit card widget)
     * the gift entry form in Batch Mode
     * @param templateSections
     * @returns {sections}
     */
    prepareFormForBatchMode (templateSections) {
        let sections = deepClone(templateSections);
        if (isNotEmpty(this._batchDefaults)) {
            let batchDefaultsObject;
            try {
                batchDefaultsObject = JSON.parse(this._batchDefaults);
                sections.forEach(section => {
                    section.elements.forEach(element => {
                        for (let key in batchDefaultsObject) {
                            if (batchDefaultsObject.hasOwnProperty(key)) {
                                const batchDefault = batchDefaultsObject[key];
                                if (batchDefault.objectApiName === element.objectApiName &&
                                    batchDefault.fieldApiName === element.fieldApiName) {
                                    if (!isUndefined(batchDefault.value)) {
                                        element.defaultValue = batchDefault.value;
                                    }
                                }
                            }
                        }
                    });
                });
            } catch (err) {
                handleError(err);
            }
        }
        return sections;
    }

    /**
     * @description Retrieves a records mapped target field values and
     *              loads them into the appropriate source fields in use
     *              on the Gift Entry form.
     * @param lookupFieldApiName Api name of the lookup field.
     * @param selectedRecordId Id of the selected record.
     */
    loadSelectedRecordFieldValues(lookupFieldApiName, selectedRecordId) {
        let selectedRecordFields =
            this.getSiblingFieldsForSourceField(lookupFieldApiName);

        this.storeSelectedRecordIdByObjectMappingName(
            this.getObjectMapping(lookupFieldApiName).DeveloperName,
            selectedRecordId
        );

        this.lookupFieldApiNameBySelectedRecordId[selectedRecordId] = lookupFieldApiName;
        this.queueSelectedRecordForRetrieval(selectedRecordId, selectedRecordFields);
    }

    lookupFieldApiNameBySelectedRecordId = {};

    getQualifiedFieldName(objectInfo, fieldInfo) {
        return `${objectInfo.objectApiName}.${fieldInfo.fieldApiName}`;
    }

    get oppPaymentKeyPrefix() {
        return this.oppPaymentObjectInfo.data.keyPrefix;
    }

    isAnOpportunityId(id) {
        if (!id || typeof id !== 'string') {
            return false;
        }
        return id.startsWith(this.opportunityKeyPrefix);
    }

    isAPaymentId(id) {
        if (!id || typeof id !== 'string') {
            return false;
        }
        return id.startsWith(this.oppPaymentKeyPrefix);
    }

    get opportunityKeyPrefix() {
        return this.opportunityObjectInfo.data.keyPrefix;
    }

    get accountKeyPrefix() {
        return this.accountObjectInfo.data.keyPrefix;
    }

    get contactKeyPrefix() {
        return this.contactObjectInfo.data.keyPrefix;
    }

    getObjectMapping(fieldApiName) {
        return Object.values(GeFormService.objectMappings)
            .find(({Imported_Record_Field_Name}) =>
                Imported_Record_Field_Name === fieldApiName);
    }

    // Properties used to manage retrieval of fields for selected records
    selectedRecordIdByObjectMappingDevName = {};
    selectedRecordId;
    selectedRecordFields;
    getSelectedRecordStatus = 'ready';
    selectedRecordsQueue = [];

    @wire(getRecord, {recordId: '$selectedRecordId', optionalFields: '$selectedRecordFields'})
    getSelectedRecord({error, data}) {
        if (error) {
            handleError(error);
        } else if (data) {
            const updates = this.getFormStateUpdatesFromSelectedRecord(data);
            this.updateFormState(updates);
        }
        this.loadNextSelectedRecordFromQueue();
    }

    loadParentOpportunityForSelectedPayment(oppId) {
        this.loadSelectedRecordFieldValues(apiNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD), oppId);
    }

    loadNextSelectedRecordFromQueue() {
        if (this.selectedRecordsQueue.length > 0) {
            const nextSelectedRecord = this.selectedRecordsQueue.pop();
            this.selectedRecordId = nextSelectedRecord.selectedRecordId;
            this.selectedRecordFields = nextSelectedRecord.selectedRecordFields;
        } else {
            // If there are no records in the queue, set status back to 'ready'
            this.getSelectedRecordStatus = 'ready';
        }
    }

    parentOpportunityIdFor(oppPaymentRecord) {
        return getFieldValue(oppPaymentRecord, PARENT_OPPORTUNITY_FIELD);
    }

    @wire(getObjectInfo, { objectApiName: OPP_PAYMENT_OBJECT })
    oppPaymentObjectInfo;

    @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT })
    opportunityObjectInfo;

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountObjectInfo;

    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT })
    contactObjectInfo;

    @wire(getObjectInfo, { objectApiName: DATA_IMPORT_OBJECT })
    dataImportObjectInfo;

    mapRecordValuesToDataImportFields(record) {
        //reverse map to create an object with relevant source field api names to values
        let dataImport = {};
        let objectMappingDevNames = this.getObjectMappingDevNamesForSelectedRecord(record);

        objectMappingDevNames.forEach(objectMappingName => {
            this.fieldMappingsFor(objectMappingName).forEach(fieldMapping => {
                const valueObjectFromRecord =
                    record.fields[fieldMapping.Target_Field_API_Name];
                const sourceField = fieldMapping.Source_Field_API_Name;

                if (this.isFieldMappingUsedInTemplate(fieldMapping)) {
                    dataImport[sourceField] =
                        this.getFieldValueForFormState(
                            valueObjectFromRecord, fieldMapping);
                } else if(this.isFieldUsedForCardholderName(fieldMapping)) {
                    this.updateCardholderState(valueObjectFromRecord, fieldMapping);
                }
            });

            const objectMapping = GeFormService.getObjectMapping(objectMappingName);
            if (this.isPaymentImportedObjectMapping(objectMapping)) {
                dataImport =
                    this.overwriteDonationAmountAndDateWithPaymentInfo(dataImport, record);
            }

        });

        return dataImport;
    }

    isFieldMappingUsedInTemplate(fieldMapping) {
        return this.fieldMappingDevNamesUsedInTemplate().includes(fieldMapping.DeveloperName);
    }

    getFieldValueForFormState(valueObject, fieldMapping) {
        const { value } = valueObject;

        if (value === null) {
            return this.defaultValueFor(fieldMapping.DeveloperName);
        } else if (isTrueFalsePicklist(fieldMapping)) {
            return this.transformForTrueFalsePicklist(value);
        }

        return value;
    }

    isPaymentImportedObjectMapping(objectMapping) {
        return objectMapping &&
            objectMapping.Imported_Record_Field_Name ===
            apiNameFor(DATA_IMPORT_PAYMENT_IMPORTED_FIELD);
    }

    overwriteDonationAmountAndDateWithPaymentInfo(dataImport, record) {
        dataImport[apiNameFor(DONATION_AMOUNT)] =
            record.fields[apiNameFor(OPP_PAYMENT_AMOUNT)].value;
        dataImport[apiNameFor(DONATION_DATE)] =
            record.fields[apiNameFor(SCHEDULED_DATE)].value;
        return dataImport;
    }

    getObjectMappingDevNamesForSelectedRecord(record) {
        let objectMappingDevNames = [];
        for (let [key, value] of Object.entries(
            this.selectedRecordIdByObjectMappingDevName)) {
            if (value === record.id) {
                objectMappingDevNames.push(key);
            }
        }
        return objectMappingDevNames;
    }

    storeSelectedRecordIdByObjectMappingName(objectMappingName, recordId) {
        this.selectedRecordIdByObjectMappingDevName[objectMappingName] = recordId;
    }

    set donorId(id) {
        this.updateFormStateFromMap(new Map([
            [this.lookupFieldForDonorId(id), id]
        ]));
    }

    lookupFieldForDonorId(id) {
        return this.isAnAccountId(id) ?
            DATA_IMPORT_ACCOUNT1_IMPORTED_FIELD :
            this.isAContactId(id) ?
                DATA_IMPORT_CONTACT1_IMPORTED_FIELD :
                null;
    }

    get donorId() {
        switch (this.donorType) {
            case DONATION_DONOR_TYPE_ENUM.ACCOUNT1:
                return this.getFieldValueFromFormState(DATA_IMPORT_ACCOUNT1_IMPORTED_FIELD);
            case DONATION_DONOR_TYPE_ENUM.CONTACT1:
                return this.getFieldValueFromFormState(DATA_IMPORT_CONTACT1_IMPORTED_FIELD);
            default:
                return null;
        }
    }

    handleDonationDonorChange() {
        if (this.hasSelectedDonationOrPayment()) {
            this.resetDonationAndPaymentImportedFields();
            fireEvent(this, 'resetReviewDonationsEvent', {});
        }
    }

    getObjectMappingsForSourceField(fieldApiName) {
        return Object.values(GeFormService.fieldMappings)
            .filter(({Source_Field_API_Name}) => Source_Field_API_Name === fieldApiName)
            .map(({Target_Object_Mapping_Dev_Name}) => Target_Object_Mapping_Dev_Name);
    }

    /**
     * @description Queues selected record Ids (and fields) when getRecord is
     *              in the progress of retrieving another record's related fields.
     *              Prevents one lookup from overwriting the reactive selectedRecordId
     *              and selectedRecordFields properties before getRecord has returned
     *              with data.
     * @param selectedRecordId Id of record to be retrieved.
     * @param selectedRecordFields Fields list to be retrieved.
     */
    queueSelectedRecordForRetrieval(selectedRecordId, selectedRecordFields) {
        if (this.getSelectedRecordStatus === 'ready') {
            this.getSelectedRecordStatus = 'pending';
            this.selectedRecordId = selectedRecordId;
            this.selectedRecordFields = selectedRecordFields;
        } else {
            this.selectedRecordsQueue.push({selectedRecordId, selectedRecordFields});
        }
    }

    handleRegisterPaymentWidget() {
       this._hasPaymentWidget = true;
    }

    /*******************************************************************************
     * @description Method formats custom labels for the purchase call timeout error
     * scenario.
     */
    formatTimeoutErrorMessage() {
        const donorName = this.getDonorName();
        const donationAmountFormField = this.getFormFieldBySourceName(apiNameFor(DONATION_AMOUNT));
        const formattedDonationAmount = getNumberAsLocalizedCurrency(donationAmountFormField.value);

        this.CUSTOM_LABELS.geErrorUncertainCardChargePart1 = GeLabelService.format(
            this.CUSTOM_LABELS.geErrorUncertainCardChargePart1,
            [formattedDonationAmount, donorName, this.CUSTOM_LABELS.commonPaymentServices]);

        this.CUSTOM_LABELS.geErrorUncertainCardChargePart3 = GeLabelService.format(
            this.CUSTOM_LABELS.geErrorUncertainCardChargePart3,
            [this.CUSTOM_LABELS.commonPaymentServices]);

        this.CUSTOM_LABELS.geErrorUncertainCardChargePart4 = GeLabelService.format(
            this.CUSTOM_LABELS.geErrorUncertainCardChargePart4,
            [this.CUSTOM_LABELS.commonPaymentServices]);
    }

    getDonorName() {
        const names = this.donorNames;
        if (names.firstName && names.lastName) {
            return `${names.firstName} ${names.lastName}`;
        } else {
            return names.accountName;
        }
    }

    /*******************************************************************************
    * @description Get a form field's value and label properties by the source
    * field api name.
    *
    * @param {string} sourceFieldApiName: A field api name from the DataImport__c
    * custom object.
    */
    getFormFieldBySourceName(sourceFieldApiName) {
        const sectionsList = this.template.querySelectorAll('c-ge-form-section');
        for (let i = 0; i < sectionsList.length; i++) {
            const matchingFormField = sectionsList[i].getFieldValueAndLabel([sourceFieldApiName]);
            if (isObject(matchingFormField) && matchingFormField.hasOwnProperty(sourceFieldApiName)) {
                return matchingFormField[sourceFieldApiName];
            }
        }
    }

    get namespace() {
        return getNamespace(apiNameFor(FORM_TEMPLATE_FIELD));
    }

    // ================================================================================
    // AUTOMATION LOCATOR GETTERS
    // ================================================================================

    get qaLocatorCancelButton() {
        return `button ${this.cancelButtonText}`;
    }

    get qaLocatorSaveButton() {
        return `button ${this.saveActionLabel}`;
    }

    get formState() {
        return this._formState;
    }

    set formState(formState) {
        this._formState = formState;
    }

    lookupFieldApiNameFor(recordId) {
        const valueForKeyByStartsWith =
            this.getValueForKeyByStartsWith(recordId,
                this.lookupFieldApiNameBySelectedRecordId);

        return this.lookupFieldApiNameBySelectedRecordId[recordId] || valueForKeyByStartsWith;
    }

    /*******************************************************************************
     * @description Updates the formState object that holds the current value
     * of all fields on the form.
     * @param fields An object with key-value pairs.
     */
    updateFormState(fields) {
        Object.assign(this.formState, fields);
        if (fields.hasOwnProperty(apiNameFor(DONATION_RECORD_TYPE_NAME))) {
            this.updateFormStateForDonationRecordType(fields);
        }

        if (this.hasImportedRecordFieldsBeingSetToNull(fields)) {
            this.deleteRelationshipFieldsFromStateFor(fields);
        }

        // Shallow-copy to a new object to prompt reactivity
        this.formState = Object.assign({}, this.formState);
    }

    updateFormStateFromMap(fieldReferenceToValueMap) {
        let updates = {};
        for (const [key, value] of fieldReferenceToValueMap.entries()) {
            if (typeof key === 'string' || key instanceof String) {
                updates[key] = value;
            } else {
                updates[apiNameFor(key)] = value;
            }
        }
        this.updateFormState(updates);
    }

    updateFormStateForDonationRecordType(fields) {
        const opportunityRecordTypeValue = fields[apiNameFor(DONATION_RECORD_TYPE_NAME)];

        if (opportunityRecordTypeValue) {
            const isId = opportunityRecordTypeValue.startsWith('012');
            const val = isId ?
                opportunityRecordTypeValue :
                this.opportunityRecordTypeIdFor(opportunityRecordTypeValue);

            this.formState[apiNameFor(DONATION_RECORD_TYPE_NAME)] =
                this.opportunityRecordTypeNameFor(val);

            this.setDonationRecordTypeIdInFormState(val);
        }
    }

    opportunityRecordTypeNameFor(id) {
        const found = this.opportunityRecordTypeInfos &&
            this.opportunityRecordTypeInfos
                .find(recordTypeInfo => recordTypeInfo.recordTypeId === id);

        return found && found.name;
    }

    hasImportedRecordFieldsBeingSetToNull(fields) {
        return Object.keys(fields)
            .filter(field =>
                GeFormService.importedRecordFieldNames.includes(field) &&
                fields[field] === null
            ).length > 0;
    }

    deleteRelationshipFieldsFromStateFor(fields) {
        const needsRelationshipFieldDeleted = (field) =>
            this.hasRelatedRecordFieldInFormState(field) &&
            fields[field] === null;

        Object.keys(fields)
            .filter(needsRelationshipFieldDeleted)
            .forEach(field => {
                this.deleteFieldFromFormState(relatedRecordFieldNameFor(field));
            });
    }

    deleteFieldFromFormState(field) {
        delete this.formState[field];
    }

    hasRelatedRecordFieldInFormState(field) {
        return this.formState.hasOwnProperty(relatedRecordFieldNameFor(field));
    }

    handleFormFieldChange(event) {
        const value = event.detail.value,
            label = event.detail.label,
            sourceField = this.sourceFieldFor(event.detail.fieldMappingDevName),
            isDonationRecordTypeName = this.isDonationRecordTypeName(sourceField),
            isDonationDonor = this.isDonationDonor(sourceField),
            isImportedRecordField = this.isImportedRecordField(sourceField);

        this.updateFormState({
            [sourceField]: isDonationRecordTypeName ? label : value
        });

        if (isDonationRecordTypeName) {
            this.setDonationRecordTypeIdInFormState(value);
        }

        if (isDonationDonor) {
            this.handleDonationDonorChange(value)
        }

        if (isImportedRecordField) {
            this.handleImportedRecordFieldChange(sourceField, value);
        }
    }

    isDonationDonor(fieldApiName) {
        return fieldApiName === apiNameFor(DATA_IMPORT_DONATION_DONOR_FIELD);
    }

    isDonationRecordTypeName(fieldApiName) {
        return fieldApiName === apiNameFor(DONATION_RECORD_TYPE_NAME);
    }

    handleImportedRecordFieldChange(sourceField, value) {
        this.populateRelatedFieldsForSelectedLookupRecord(sourceField, value);
    }

    populateRelatedFieldsForSelectedLookupRecord(sourceField, value) {
        if (value) {
            this.loadSelectedRecordFieldValues(sourceField, value);
        } else {
            this.resetFieldsForObjMappingApplyDefaults(
                this.objectMappingDeveloperNameFor(sourceField));
        }
    }

    sourceFieldFor(fieldMappingDevName) {
        return GeFormService.getFieldMappingWrapper(fieldMappingDevName).Source_Field_API_Name;
    }

    isTrueFalsePicklist(fieldMappingDevName) {
        const fieldMapping = GeFormService.getFieldMappingWrapper(fieldMappingDevName);
        return isTrueFalsePicklist(fieldMapping);
    }

    /*******************************************************************************
     * @description Analyzes the sections property to get initial values and set them
     * in the formState property.
     */
    initializeFormState() {
        this.formState = {};
        if (this.sections) {
            this.sections
                .forEach(section => {
                    if (section.elements) {
                        section.elements
                            .forEach(element => {
                                this.setInitialValueInFormStateForElement(element);
                            });
                    }
                });
        }

        if (this.batchId) {
            this.updateFormState({
                [apiNameFor(NPSP_DATA_IMPORT_BATCH_FIELD)]: this.batchId
            });
        }

        this.setFormStateForURLQueryParameters();
    }

    setFormStateForURLQueryParameters() {
        const donorApiName = getQueryParameters().c__apiName;
        const donorId = getQueryParameters().c__donorRecordId;

        if (donorApiName) {
            this.initializeDonationDonorTypeInFormState(donorApiName);
        }
        if (donorId) {
            this.donorId = donorId;
        }
    }

    setInitialValueInFormStateForElement(element) {
        const sourceField = this.getSourceFieldApiNameFor(element);
        const value = this.getValueFrom(element);
        const isLookupWithDefaultValue = value &&
            GeFormService.importedRecordFieldNames.includes(sourceField);

        this.updateFormState({[sourceField]: value});

        if (isLookupWithDefaultValue) {
            this.loadSelectedRecordFieldValues(sourceField, value);
        }
    }

    setInitialValueInFormStateForFieldMappings(fieldMappingDevNames) {
        this.resetFieldsToNullInFormStateIfPresent(fieldMappingDevNames);

        this.elementsFor(fieldMappingDevNames)
            .forEach(el => this.setInitialValueInFormStateForElement(el));
    }

    resetFieldsToNullInFormStateIfPresent(fieldMappingDevNames) {
        const updates = {};
        fieldMappingDevNames.forEach(fieldMappingDevName => {
            const sourceField = this.sourceFieldFor(fieldMappingDevName);
            if (this.formState.hasOwnProperty(sourceField)) {
                updates[sourceField] = null;
            }
        });
        this.updateFormState(updates);
    }

    elementsFor(fieldMappingDevNames) {
        const foundInFieldMappingDevNames =
            (fieldMappingDevName) => fieldMappingDevNames
                .includes(fieldMappingDevName);

        return this.sections
            .map(s => s.elements)
            .flat()
            .filter(element =>
                element.dataImportFieldMappingDevNames
                    .some(foundInFieldMappingDevNames));
    }

    setFormStateToInitialFieldValuesForObjMapping(objectMappingDeveloperName) {
        this.setInitialValueInFormStateForFieldMappings(
            this.fieldMappingsFor(objectMappingDeveloperName)
                .map(({DeveloperName}) => DeveloperName));
    }

    fieldMappingsFor(objectMappingDeveloperName) {
        return GeFormService.fieldMappingsForObjectMappingDevName(objectMappingDeveloperName);
    }

    getSourceFieldApiNameFor(element) {
        return this.fieldMappingWrapperFor(element) &&
            this.fieldMappingWrapperFor(element).Source_Field_API_Name;
    }

    fieldMappingWrapperFor(element) {
        return element.dataImportFieldMappingDevNames &&
            GeFormService.getFieldMappingWrapper(element.dataImportFieldMappingDevNames[0]);
    }

    getValueFrom(element) {
        return element && element.recordValue !== undefined ?
            element.recordValue :
            element.defaultValue;
    }

    opportunityRecordTypeIdFor(opportunityRecordTypeName) {
        const recordTypeInfo = Object.values(this.opportunityRecordTypeInfos)
            .find(recordTypeInfo =>
                recordTypeInfo.name === opportunityRecordTypeName);

        if (!recordTypeInfo) return null;
        return recordTypeInfo.recordTypeId;
    }

    get opportunityRecordTypeInfos() {
        return this.opportunityObjectInfo &&
            Object.values(this.opportunityObjectInfo.data.recordTypeInfos);
    }

    transformForTrueFalsePicklist(value) {
        if (value === true || value === CHECKBOX_TRUE) {
            return PICKLIST_TRUE;
        } else if (value === false || value === CHECKBOX_FALSE) {
            return PICKLIST_FALSE;
        }
        return ''; // blank values are valid for picklist/checkbox mappings
    }

    setDonationRecordTypeIdInFormState(opportunityRecordTypeId) {
        const donationImportedRelatedRecordField =
            relatedRecordFieldNameFor(apiNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD));
        const relatedRecord =
            this.getFieldValueFromFormState(donationImportedRelatedRecordField);

        let updatedRecord;
        if (relatedRecord) {
            updatedRecord = Object.assign(
                relatedRecord,
                {recordTypeId: opportunityRecordTypeId});
        } else {
            updatedRecord = {recordTypeId: opportunityRecordTypeId};
        }

        this.updateFormState({
            [donationImportedRelatedRecordField]: updatedRecord
        })
    }

    siblingRecordTypeFieldFor(fieldMappingDevName) {
        const fieldMappingToRecordTypeId =
            Object.values(GeFormService.fieldMappings)
                .filter(f =>
                    f.Target_Object_Mapping_Dev_Name ===
                    this.objectMappingDevNameFor(fieldMappingDevName))
                .find(f => f.Target_Field_API_Name === 'RecordTypeId')

        return fieldMappingToRecordTypeId &&
            fieldMappingToRecordTypeId.Source_Field_API_Name;
    }

    objectMappingDevNameFor(fieldMappingDevName) {
        const fieldMapping = GeFormService.getFieldMappingWrapper(fieldMappingDevName);
        return fieldMapping && fieldMapping.Target_Object_Mapping_Dev_Name;
    }

    parentRecordFieldFor(fieldMappingDevName) {
        const objMapping =
            GeFormService.getObjectMapping(
                this.objectMappingDevNameFor(fieldMappingDevName));

        return objMapping && objMapping.Imported_Record_Field_Name;
    }

    get donorType() {
        return this.getFieldValueFromFormState(
            apiNameFor(DATA_IMPORT_DONATION_DONOR_FIELD));
    }

    /**
     * @description Pass in a DataImport field's api to get that field's current
     * value from the formState object.
     * @param fieldApiNameOrFieldReference: field name or an imported field reference object
     * @returns {*} Current value stored in formState for the passed-in field.
     */
    getFieldValueFromFormState(fieldApiNameOrFieldReference) {
        const fieldApiName =
            typeof fieldApiNameOrFieldReference === 'string' ?
                fieldApiNameOrFieldReference :
                apiNameFor(fieldApiNameOrFieldReference);

        return this.formState[fieldApiName];
    }

    defaultValueFor(fieldMappingDevName) {
        const element = this.formElements()
            .find(element =>
                element.dataImportFieldMappingDevNames[0] === fieldMappingDevName);

        return element && element.defaultValue;
    }

    appendNullValuesForMissingFields(dataImport) {
        this.applyNullValuesForMissingFields(this.sourceFieldsUsedInTemplate(), dataImport);
        return dataImport;
    }

    applyNullValuesForMissingFields(sourceFieldsOnForm, dataImport) {
        sourceFieldsOnForm.forEach(sourceFieldOnForm => {
            if (!dataImport.hasOwnProperty(sourceFieldOnForm)) {
                dataImport[sourceFieldOnForm] = null;
            }
        });
    }

    sourceFieldsUsedInTemplate() {
        return Object.values(GeFormService.fieldMappings)
            .filter(fieldMapping =>
                this.fieldMappingDevNamesUsedInTemplate()
                    .includes(fieldMapping.DeveloperName))
            .map(fieldMapping => fieldMapping.Source_Field_API_Name);
    }

    fieldMappingDevNamesUsedInTemplate() {
        return this.formElements()
            .filter(element => element.elementType === 'field')
            .map(element => element.dataImportFieldMappingDevNames[0]);
    }

    formElements() {
        return this.sections.flat()
            .map(({elements}) => elements)
            .flat();
    }

    isImportedRecordField(fieldApiName) {
        return GeFormService.importedRecordFieldNames.includes(fieldApiName);
    }

    isDonorLookupField(fieldApiName) {
        return this.isDonorAccountField(fieldApiName) ||
            this.isDonorContactField(fieldApiName);
    }

    isDonorAccountField(fieldApiName) {
        return fieldApiName === apiNameFor(DATA_IMPORT_ACCOUNT1_IMPORTED_FIELD);
    }

    isDonorContactField(fieldApiName) {
        return fieldApiName === apiNameFor(DATA_IMPORT_CONTACT1_IMPORTED_FIELD);
    }

    selectedDonorId() {
        if (this.isDonorTypeContact()) {
            return this.donorContactId();
        } else if (this.isDonorTypeAccount()) {
            return this.donorAccountId();
        } else {
            return null;
        }
    }

    isDonorTypeContact() {
        return this.donorType === DONATION_DONOR_TYPE_ENUM.CONTACT1;
    }

    isDonorTypeAccount() {
        return this.donorType === DONATION_DONOR_TYPE_ENUM.ACCOUNT1;
    }

    donorContactId() {
        return this.getFieldValueFromFormState(
            apiNameFor(DATA_IMPORT_CONTACT1_IMPORTED_FIELD)
        );
    }

    donorAccountId() {
        return this.getFieldValueFromFormState(
            apiNameFor(DATA_IMPORT_ACCOUNT1_IMPORTED_FIELD)
        );
    }

    selectedDonationOrPaymentRecordId() {
        return this.getFieldValueFromFormState(DATA_IMPORT_PAYMENT_IMPORTED_FIELD) ||
            this.getFieldValueFromFormState(DATA_IMPORT_DONATION_IMPORTED_FIELD);
    }

    resetSelectedPaymentFieldsInFormState() {
        this.updateFormState({
            [apiNameFor(DATA_IMPORT_PAYMENT_IMPORTED_FIELD)]: null,
            [apiNameFor(DATA_IMPORT_PAYMENT_IMPORT_STATUS_FIELD)]: null,
            [relatedRecordFieldNameFor(apiNameFor(DATA_IMPORT_PAYMENT_IMPORTED_FIELD))]: null
        });

        this.resetFieldsForObjMappingApplyDefaults(
            this.objectMappingDeveloperNameForFieldReference(
                DATA_IMPORT_PAYMENT_IMPORTED_FIELD
            )
        );
    }

    resetSelectedDonationFieldsInFormState() {
        const updates = new Map();
        updates.set(DATA_IMPORT_DONATION_IMPORTED_FIELD, null);
        updates.set(DATA_IMPORT_DONATION_IMPORT_STATUS_FIELD, null);
        updates.set(relatedRecordFieldNameFor(DATA_IMPORT_DONATION_IMPORTED_FIELD), null);
        this.updateFormStateFromMap(updates);

        this.resetFieldsForObjMappingApplyDefaults(
            this.objectMappingDeveloperNameForFieldReference(
                DATA_IMPORT_DONATION_IMPORTED_FIELD
            )
        );
    }

    objectMappingDeveloperNameForFieldReference(fieldReference) {
        const objectMapping =
            this.getObjectMapping(apiNameFor(fieldReference));
        return objectMapping && objectMapping.DeveloperName;
    }

    saveableFormState() {
        let dataImportRecord = { ...this.formState };
        dataImportRecord = this.removeFieldsNotInObjectInfo(dataImportRecord);

        return dataImportRecord;
    }

    removeFieldsNotInObjectInfo(dataImportRecord) {
        const diFields = Object.keys(this.dataImportObjectInfo.data.fields);
        for (const key of Object.keys(dataImportRecord)) {
            if (!diFields.includes(key)) {
                delete dataImportRecord[key];
            }
        }
        return dataImportRecord;
    }

    get hasDataImportId() {
        return !!this.getFieldValueFromFormState('id');
    }

    hasProcessableDataImport() {
        return !this.hasFailedPurchaseRequest ||
            this._isElevateWidgetInDisabledState;
    }

    hasAuthorizationToken() {
        return !!this.getFieldValueFromFormState(
            apiNameFor(PAYMENT_AUTHORIZE_TOKEN));
    }

    shouldMakePurchaseRequest() {
        return this.hasAuthorizationToken() &&
            this.hasChargeableTransactionStatus() &&
            !this._isElevateWidgetInDisabledState;
    }

    hasChargeableTransactionStatus = () => {
        const nonChargeableForSingleGift = this.selectedPaymentMethod() !== PAYMENT_METHODS.ACH
            && this.selectedPaymentMethod() !== PAYMENT_METHOD_CREDIT_CARD;
        if (this.isSingleGiftEntry && nonChargeableForSingleGift) {
            return false;
        }

        const nonChargeableForBatchGift = this.selectedPaymentMethod() !== PAYMENT_METHOD_CREDIT_CARD;
        if (!this.isSingleGiftEntry && nonChargeableForBatchGift) {
            return false;
        }

        const paymentStatus = this.convertPaymentStatusToUpperCase(
            this.getFieldValueFromFormState(PAYMENT_STATUS));

        switch (paymentStatus) {
            case '':
            case undefined:
            case null:
            case this.PAYMENT_TRANSACTION_STATUS_ENUM.PENDING:
            case this.PAYMENT_TRANSACTION_STATUS_ENUM.AUTHORIZED:
            case this.PAYMENT_TRANSACTION_STATUS_ENUM.DECLINED:
            case this.PAYMENT_TRANSACTION_STATUS_ENUM.RETRYABLEERROR:
            case this.PAYMENT_TRANSACTION_STATUS_ENUM.EXPIRED:
            case PAYMENT_UNKNOWN_ERROR_STATUS:
                return true;

            default:
                return false;
        }
    }

    convertPaymentStatusToUpperCase(paymentStatus) {
        if (isString(paymentStatus)) {
            return paymentStatus.toUpperCase();
        }
        return paymentStatus;
    }

    /*******************************************************************************
     * @description Saves a Data Import record, makes an elevate payment if needed,
     * and processes the Data Import through BDI.
     *
     * @param dataImportFromFormState
     */
    submitSingleGift = async () => {
        const gift = this.saveableFormState();
        try {
            await this.saveDataImport(gift);

            if (this.shouldMakePurchaseRequest()) {
                await this.makePurchaseRequest();
            }

            if (this.hasProcessableDataImport()) {
                await this.processDataImport();
            }
        } catch (error) {
            this.disabled = false;
            this.toggleSpinner();
            handleError(error);
        }
    }

    saveDataImport = async (dataImportFromFormState) => {
        this.loadingText = this.hasDataImportId
            ? this.CUSTOM_LABELS.geTextUpdating
            : this.CUSTOM_LABELS.geTextSaving;

        try {
            delete dataImportFromFormState[apiNameFor(PAYMENT_AUTHORIZE_TOKEN)];
            const upsertResponse = await upsertDataImport({
                dataImport: dataImportFromFormState
            });
            this.updateFormState(upsertResponse);
            return true;
        } catch (err) {
            this.handleCatchOnSave(err);
            return false;
        }
    };

    makePurchaseRequest = async () => {
        this.loadingText = this.CUSTOM_LABELS.geTextChargingCard;
        const responseBodyString = await sendPurchaseRequest({
            requestBodyParameters: this.buildPurchaseRequestBodyParameters(),
            dataImportRecordId: this.getFieldValueFromFormState('id'),
        });

        const responseBody = JSON.parse(responseBodyString);
        await this.processPurchaseResponse(responseBody);
    }

    buildPurchaseRequestBodyParameters() {
        if (this.selectedPaymentMethod() === PAYMENT_METHODS.ACH) {
            return this.buildACHPurchaseRequestBodyParameters();
        } else {
            return this.buildCreditCardPurchaseRequestBodyParameters();
        }
    }

    buildACHPurchaseRequestBodyParameters() {
        const metadata = {
            campaignCode: this.getFieldValueFromFormState(DONATION_CAMPAIGN_NAME)
        };
        const achData = {
            achCode: ACH_CODE,
            consent: ACH_CONSENT_MESSAGE,
            type: this.accountHolderType(),
            bankType: ACCOUNT_HOLDER_BANK_TYPES.CHECKING,
        }
        const amount = getCurrencyLowestCommonDenominator(
            this.getFieldValueFromFormState(DONATION_AMOUNT));
        const paymentMethodToken =
            this.getFieldValueFromFormState(PAYMENT_AUTHORIZE_TOKEN);

        return JSON.stringify({
            ...this.buildACHPurchaseBodyNameParameter(),
            paymentMethodType : PAYMENT_METHODS.ACH,
            amount: amount,
            paymentMethodToken: paymentMethodToken,
            achData : achData,
            metadata: metadata
        });

    }

    buildACHPurchaseBodyNameParameter() {
        let names;
        if (this.isDonorTypeContact()) {
            names = {
                firstName: this.donorNames.firstName,
                lastName: this.donorNames.lastName
            };
        } else {
            names = {
                accountName: this.donorNames.accountName
            }
        }
        return names;
    }

    buildCreditCardPurchaseRequestBodyParameters() {
        const {firstName, lastName} = this.cardholderNames;
        const metadata = {
            campaignCode: this.getFieldValueFromFormState(
                apiNameFor(DONATION_CAMPAIGN_NAME)),
        };
        return JSON.stringify({
            firstName: firstName,
            lastName: lastName,
            metadata: metadata,
            amount: getCurrencyLowestCommonDenominator(
                this.getFieldValueFromFormState(apiNameFor(DONATION_AMOUNT)),
            ),
            paymentMethodToken:
                this.getFieldValueFromFormState(
                    apiNameFor(PAYMENT_AUTHORIZE_TOKEN)),
            paymentMethodType: PAYMENT_METHODS.CREDIT_CARD,
        });
    }

    accountHolderType() {
        return this.isDonorTypeContact()
            ? ACCOUNT_HOLDER_TYPES.INDIVIDUAL
            : ACCOUNT_HOLDER_TYPES.BUSINESS;
    }

    selectedPaymentMethod () {
        return this.getFieldValueFromFormState(PAYMENT_METHOD);
    }

    processPurchaseResponse = async (responseBody) => {
        if (responseBody.errors) {
            this.updateFormStateWithFailedPurchaseCall(responseBody.errors);
            this.handleElevateAPIErrors(responseBody.errors);
            this.hasFailedPurchaseRequest = true;
        }

        if (this.hasPurchaseTimedOut(responseBody)) {
            this.updateFormStateWithTimedoutPurchaseCall(responseBody);
            this.hasFailedPurchaseRequest = true;
            this.hasPurchaseCallTimedout = true;
            this.formatTimeoutErrorMessage();
        }

        if (this.isPurchaseCreated(responseBody)) {
            this.updateFormStateWithSuccessfulPurchaseCall(responseBody);
            this.hasFailedPurchaseRequest = false;
        }

        await this.saveDataImport(this.saveableFormState());
    }

    isPurchaseCreated(responseBody) {
        return responseBody.id
            && this.isCreditCardTransactionSuccessResponse(responseBody)
            || this.isACHTransactionSuccessResponse(responseBody);
    }

    isCreditCardTransactionSuccessResponse(responseBody) {
        return responseBody.status ===
            this.PAYMENT_TRANSACTION_STATUS_ENUM.CAPTURED;
    }

    isACHTransactionSuccessResponse(responseBody) {
        return responseBody.status ===
            this.PAYMENT_TRANSACTION_STATUS_ENUM.SUBMITTED;
    }

    hasPurchaseTimedOut (responseBody) {
        return !responseBody.id && responseBody.message && responseBody.status;
    }


    updateFormStateWithFailedPurchaseCall(errors) {
        if (errors && errors[0]) {
            const primaryError = errors[0];
            const paymentStatus =
                hasNestedProperty(primaryError, 'errorDetail', 'code', 'name') ?
                primaryError.errorDetail.code.name :
                this.CUSTOM_LABELS.commonUnknownError;

            this.updateFormState({
                [apiNameFor(PAYMENT_DECLINED_REASON)]: primaryError.message,
                [apiNameFor(PAYMENT_STATUS)]: paymentStatus,
            });
        }
    }

    handleElevateAPIErrors(errors) {
        const errorMessage = JSON.stringify(
            errors.map(error => error.message))
            || this.CUSTOM_LABELS.commonUnknownError;
        let labelReplacements = [
            this.CUSTOM_LABELS.commonPaymentServices, errorMessage];
        let formattedErrorResponse = format(
            this.CUSTOM_LABELS.gePaymentProcessError, labelReplacements);

        const error = {
            message: formattedErrorResponse.split(LABEL_NEW_LINE),
            isObject: true
        };
        this.handleAsyncWidgetError({ error });
    }

    updateFormStateWithTimedoutPurchaseCall(responseBody) {
        this.updateFormState({
            [apiNameFor(PAYMENT_DECLINED_REASON)]: responseBody.message,
            [apiNameFor(PAYMENT_STATUS)]: responseBody.status,
        });
    }

    updateFormStateWithSuccessfulPurchaseCall(responseBody) {
        const baseDataImportPaymentFields = {
            [apiNameFor(PAYMENT_ELEVATE_ID)]: responseBody.id,
            [apiNameFor(PAYMENT_STATUS)]: responseBody.status,
            [apiNameFor(PAYMENT_DECLINED_REASON)]: '',
            [apiNameFor(PAYMENT_GATEWAY_ID)]: responseBody.gatewayId,
            [apiNameFor(PAYMENT_GATEWAY_TRANSACTION_ID)]: responseBody.gatewayTransactionId,
            [apiNameFor(PAYMENT_AUTHORIZED_AT)]: responseBody.authorizedAt,
            [apiNameFor(PAYMENT_CREATED_AT)]: responseBody.createdAt
        };

        if (this.isCreditCardTransaction()) {
            this.updateFormStateWithCreditCardTransactionResponse(
                baseDataImportPaymentFields, responseBody);
        } else {
            this.updateFormStateWithACHTransactionResponse(
                baseDataImportPaymentFields, responseBody);
        }
    }

    updateFormStateWithCreditCardTransactionResponse(
        baseDataImportPaymentFields, responseBody) {
        this.updateFormState({
            ...baseDataImportPaymentFields,
            [apiNameFor(PAYMENT_CARD_NETWORK)]: responseBody.cardData.brand,
            [apiNameFor(PAYMENT_LAST_4)]: responseBody.cardData.last4,
            [apiNameFor(
                PAYMENT_EXPIRATION_MONTH)]: responseBody.cardData.expirationMonth,
            [apiNameFor(
                PAYMENT_EXPIRATION_YEAR)]: responseBody.cardData.expirationYear
        });
    }

    updateFormStateWithACHTransactionResponse(
        baseDataImportPaymentFields, responseBody) {
        this.updateFormState({
            ...baseDataImportPaymentFields,
            [apiNameFor(PAYMENT_ACH_LAST_4)]: responseBody.achData.last4,
            [apiNameFor(PAYMENT_ACH_CODE)]: responseBody.achData.achCode,
            [apiNameFor(PAYMENT_METHOD)]: responseBody.paymentType,
            [apiNameFor(
                PAYMENT_ACH_CONSENT)]: responseBody.achData.consentMessage,
            [apiNameFor(PAYMENT_TYPE)]: responseBody.paymentType,
            [apiNameFor(
                PAYMENT_ELEVATE_ORIGINAL_PAYMENT_ID)]: responseBody.originalTransactionId,
        });
    }

    isCreditCardTransaction() {
        return this.selectedPaymentMethod() === PAYMENT_METHOD_CREDIT_CARD;
    }

    processDataImport = async () => {
        this.loadingText = this.CUSTOM_LABELS.geTextProcessing;
        this.deleteFieldFromFormState(apiNameFor(PAYMENT_AUTHORIZE_TOKEN));
        const dataImportRecord = this.saveableFormState();

        submitDataImportToBDI({
            dataImport: dataImportRecord,
            updateGift: this.hasSelectedDonationOrPayment()
        })
            .then(opportunityId => {
                this.loadingText = this.CUSTOM_LABELS.geTextNavigateToOpportunity;
                this.goToRecordDetailPage(opportunityId);
            })
            .catch(error => {
                this.handleBdiProcessingError(error);
            });
    }

    handleBdiProcessingError(error) {
        if (this.isProcessableElevateTransaction) {
            const exceptionDataError = new ExceptionDataError(error);
            this.handleElevateTransactionBDIError(exceptionDataError);
        } else {
            this.handleCatchOnSave(error);
            this.toggleSpinner();
        }
    }

    get isProcessableElevateTransaction() {
        const paymentStatus = this.getFieldValueFromFormState(PAYMENT_STATUS);
        return paymentStatus
            && (paymentStatus === this.PAYMENT_TRANSACTION_STATUS_ENUM.CAPTURED
                || paymentStatus === this.PAYMENT_TRANSACTION_STATUS_ENUM.SUBMITTED);

    }

    get elevateTransactionWarning() {
        return format(this.CUSTOM_LABELS.gePaymentProcessedWarning, [this.CUSTOM_LABELS.commonPaymentServices]);
    }

    get showElevateTransactionWarning() {
        const paymentStatus = this.getFieldValueFromFormState(PAYMENT_STATUS);
        return paymentStatus &&
            (paymentStatus === this.PAYMENT_TRANSACTION_STATUS_ENUM.CAPTURED
                || paymentStatus === this.PAYMENT_TRANSACTION_STATUS_ENUM.SUBMITTED
                || paymentStatus === this.PAYMENT_TRANSACTION_STATUS_ENUM.SETTLED
            );
    }

    handleElevateTransactionBDIError(exceptionDataError) {
        this.dispatchDisablePaymentServicesWidgetEvent(this.CUSTOM_LABELS.geErrorCardChargedBDIFailed);
        this.toggleModalByComponentName('geModalPrompt',
            {
                'variant': 'error',
                'title': this.CUSTOM_LABELS.commonCriticalError,
                'message': this.CUSTOM_LABELS.geErrorCardChargedBDIFailed,
                'buttons': 
                    [{
                        label: this.CUSTOM_LABELS.commonReviewForm,
                        action: () => { fireEvent(this.pageRef, 'geModalCloseEvent', {}) }
                    }]
            });

        const pageLevelError = this.buildElevateTransactionBDIError(exceptionDataError);
        this.addPageLevelErrorMessage(pageLevelError);

        this.disabled = false;
        this.toggleSpinner();
    }

    buildElevateTransactionBDIError(exceptionDataError) {
        return {
            index: 0,
            errorMessage: this.CUSTOM_LABELS.geErrorCardChargedBDIFailed,
            multilineMessages: [
                {
                    message: exceptionDataError.errorMessage ||
                        this.CUSTOM_LABELS.commonUnknownError,
                    index: 0
                }]
        };
    }

    isAnAccountId(id) {
        return id && typeof id === 'string' &&
            id.startsWith(this.accountKeyPrefix);
    }

    isAContactId(id) {
        return id && typeof id === 'string' &&
            id.startsWith(this.contactKeyPrefix);
    }

    getValueForKeyByStartsWith(longKey, keyValueMap) {
        for (const [key, value] of Object.entries(keyValueMap)) {
            if (longKey.startsWith(key)) {
                return value;
            }
        }
    }

    isPaymentImportedField(sourceField) {
        return sourceField === apiNameFor(DATA_IMPORT_PAYMENT_IMPORTED_FIELD);
    }

    nullPaymentFieldsInFormState(paymentFields) {
        paymentFields.forEach(field => {
            this.updateFormState({ [field]: null });
        });
    }

    getFormStateUpdatesFromSelectedRecord(record) {
        const formStateUpdates = this.mapRecordValuesToDataImportFields(record);
        const relatedRecordFieldName =
            relatedRecordFieldNameFor(this.lookupFieldApiNameFor(record.id));
        formStateUpdates[relatedRecordFieldName] = record;
        return formStateUpdates;
    }

    get isFormCollapsed() {
        return this._isFormCollapsed;
    }

    get altTextLabel() {
        return 'Toggle '
            + this.CUSTOM_LABELS.geHeaderFormFieldsDefaultSectionName;
    }

    expandForm() {
        if (this.isFormCollapsed) {
            this._isFormCollapsed = false;
        }
    }

    @api
    collapse() {
        this._isFormCollapsed = true;
    }

    get expandableContainerId() {
        return EXPANDABLE_SECTION_CONTAINER;
    }

    handleCollapse(event) {
        this._isFormCollapsed = event.detail.isCollapsed;
    }

    get showMismatchedCurrencyWarning() {
        if (isEmpty(this.batchCurrencyIsoCode)) {
            return false;
        }
        return this.batchCurrencyIsoCode !== CURRENCY;
    }

    get mismatchedCurrencyWarning() {
        if (this.showMismatchedCurrencyWarning) {
            return GeLabelService.format(
                this.CUSTOM_LABELS.geWarningBatchGiftEntryCurrencyMismatch,
                [this.batchCurrencyIsoCode]);
        }
    }

    isFieldUsedForCardholderName(fieldMapping) {
        const cardholderNameFields = [CONTACT_LAST_NAME_INFO, CONTACT_FIRST_NAME_INFO, ACCOUNT_NAME_FIELD];
        return cardholderNameFields.find( f => apiNameFor(f) === fieldMapping.Target_Field_API_Name);
    }

    updateCardholderState(valueObjectFromRecord, fieldMapping) {
        const value = this.getFieldValueForFormState(valueObjectFromRecord, fieldMapping);
        this.cardholderNamesNotInTemplate[fieldMapping.Source_Field_API_Name] = value;
    }

    getFieldValueFromCardholderState(fieldApiNameOrFieldReference) {
        const fieldApiName =
            typeof fieldApiNameOrFieldReference === 'string' ?
                fieldApiNameOrFieldReference :
                apiNameFor(fieldApiNameOrFieldReference);

        return this.cardholderNamesNotInTemplate[fieldApiName];
    }
}
