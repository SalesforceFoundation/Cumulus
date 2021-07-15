/*******************************************************************************
* @description Server / Platform  Imports
*/
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { NavigationMixin } from 'lightning/navigation';
import { registerListener, unregisterListener } from 'c/pubsubNoPageRef';
import { validateJSONString, format, getNamespace, showToast } from 'c/utilCommon';
import { handleError } from "c/utilTemplateBuilder";
import GeLabelService from 'c/geLabelService';
import geBatchGiftsHeader from '@salesforce/label/c.geBatchGiftsHeader';
import geBatchGiftsExpectedTotalsMessage
    from '@salesforce/label/c.geBatchGiftsExpectedTotalsMessage';
import geBatchGiftsExpectedCountOrTotalMessage
    from '@salesforce/label/c.geBatchGiftsExpectedCountOrTotalMessage';
import checkForElevateCustomer 
    from '@salesforce/apex/GE_GiftEntryController.isElevateCustomer';
import processBatch from '@salesforce/apex/GE_GiftEntryController.processGiftsFor';

/*******************************************************************************
* @description Schema imports
*/
import DATA_IMPORT_BATCH_OBJECT from '@salesforce/schema/DataImportBatch__c';
import BATCH_NAME
    from '@salesforce/schema/DataImportBatch__c.Name';
import EXPECTED_COUNT_OF_GIFTS
    from '@salesforce/schema/DataImportBatch__c.Expected_Count_of_Gifts__c';
import EXPECTED_TOTAL_BATCH_AMOUNT
    from '@salesforce/schema/DataImportBatch__c.Expected_Total_Batch_Amount__c';
import BATCH_ID_FIELD from '@salesforce/schema/DataImportBatch__c.Id';
import BATCH_TABLE_COLUMNS_FIELD from '@salesforce/schema/DataImportBatch__c.Batch_Table_Columns__c';
import REQUIRE_TOTAL_MATCH from '@salesforce/schema/DataImportBatch__c.RequireTotalMatch__c';

import BatchTotals from './helpers/batchTotals';
import Gift from './helpers/gift';

/*******************************************************************************
* @description Constants
*/
const GIFT_ENTRY_TAB_NAME = 'GE_Gift_Entry';
const BATCH_CURRENCY_ISO_CODE = 'DataImportBatch__c.CurrencyIsoCode';

export default class GeGiftEntryFormApp extends NavigationMixin(LightningElement) {

    // Expose custom labels to template
    CUSTOM_LABELS = GeLabelService.CUSTOM_LABELS;

    @api recordId;
    @api sObjectName;

    @track isPermissionError;
    @track loadingText = this.CUSTOM_LABELS.geTextSaving;
    @track batchTotals = {}
    @track gift = new Gift();

    _hasDisplayedExpiredAuthorizationWarning = false;

    dataImportRecord = {};
    errorCallback;
    _isBatchProcessing = false;
    isElevateCustomer = false;

    namespace;
    count;
    total;
    batch = {};
    isLoading = true;

    get isBatchMode() {
        return this.sObjectName &&
            this.sObjectName === DATA_IMPORT_BATCH_OBJECT.objectApiName;
    }

    constructor() {
        super();
        this.namespace = getNamespace(DATA_IMPORT_BATCH_OBJECT.objectApiName);
    }

    async connectedCallback() {
        registerListener('geBatchGiftEntryTableChangeEvent', this.retrieveBatchTotals, this);
        await this.gift.init(); 
        this.isElevateCustomer = await checkForElevateCustomer();
    }

    disconnectedCallback() {
        unregisterListener('geBatchGiftEntryTableChangeEvent', this.retrieveBatchTotals, this);
    }

    async retrieveBatchTotals() {
        this.batchTotals = await BatchTotals(this.batchId);
        if (this.shouldDisplayExpiredAuthorizationWarning()) {
            this.displayExpiredAuthorizationWarningModalForPageLoad();
        }
        this._isBatchProcessing = this.batchTotals.isProcessingGifts;
        this.isLoading = false;
        if (!this._isBatchProcessing) return;
        await this.startPolling();
    }

    /*******************************************************************************
    * @description Receives a 'submit' event from geFormRenderer and proceeds down
    * the Batch or Single save paths depending on the current app mode.
    *
    * @param {object} event: Custom Event containing the Data Import record and
    * potentially other objects (booleans, callbacks, etc).
    */
    handleSubmit(event) {
        // Callback received from geFormRenderer. Provides functions that
        // toggle the form save button, toggle the lightning spinner, and displays aura exceptions.
        this.errorCallback = event.detail.errorCallback;

        try {
            if (this.isBatchMode) {
                this.batchGiftSubmit(event);
            } else {
                // TODO: potentially receive event here and navigate to record detail page
            }
        } catch (error) {
            this.errorCallback(error);
        }
    }

    /*******************************************************************************
    * @description Handles a batch gift entry submit. Saves a Data Import record,
    * runs dry run, and renders the Data Import in the Batch Gift Table.
    *
    * @param {object} event: Custom Event containing the Data Import record and a
    * callback for handling and displaying errors in the form.
    */
    batchGiftSubmit(event) {
        const table = this.template.querySelector('c-ge-batch-gift-entry-table');
        this.dataImportRecord = event.detail.dataImportRecord;
        table.handleSubmit(event);
    }

    handleSectionsRetrieved(event) {
        const formSections = event.target.sections;
        const table = this.template.querySelector('c-ge-batch-gift-entry-table');
        table.sections = formSections;
    }

    async handleBatchDryRun() {
        try {
            await this.refreshBatchTotals();
        } catch (error) {
            handleError(error);
        } finally {
            if (this.shouldDisplayExpiredAuthorizationWarning()) {
                this.displayExpiredAuthorizationWarningModalForProcessAndDryRun(
                    () => { 
                        this.callBatchDryRun(); 
                        this.dispatchEvent(new CustomEvent('closemodal')); 
                    } 
                );
            } else {
                this.callBatchDryRun();
            }
        }
    }
    
    callBatchDryRun() {
        //toggle the spinner on the form
        const form = this.template.querySelector('c-ge-form-renderer');
        const toggleSpinner = function () {
            form.showSpinner = !form.showSpinner
        };
        form.showSpinner = true;

        const table = this.template.querySelector('c-ge-batch-gift-entry-table');
        table.runBatchDryRun(toggleSpinner);
    }

    handleLoadData(event) {
        const form = this.template.querySelector('c-ge-form-renderer');
        form.loadDataImportRecord(event.detail);
    }

    handlePermissionErrors() {
        this.isPermissionError = true;
    }
    handleEditBatch() {
        this.dispatchEvent(new CustomEvent('editbatch'));
    }

    handleToggleModal(event) {
        this.dispatchEvent(new CustomEvent('togglemodal', { detail: event.detail }));
    }

    handleNavigateEvent(event) {
        if (event.detail.to === 'recordPage') {
            this.navigateToRecordPage(event.detail.recordId);
        }

        if (event.detail.to === 'landingPage') {
            this.navigateToLandingPage();
        }
    }

    navigateToRecordPage(recordId) {
        const pageReference = {
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        };
        this[NavigationMixin.Navigate](pageReference);
    }

    navigateToLandingPage() {
        const giftEntryTabName = this.namespace ?
            `${this.namespace}__${GIFT_ENTRY_TAB_NAME}` :
            GIFT_ENTRY_TAB_NAME;
        const url = `/lightning/n/${giftEntryTabName}`;

        const pageReference = {
            type: 'standard__webPage',
            attributes: { url: url }
        };
        this[NavigationMixin.Navigate](pageReference, true);
    }

    get batchCurrencyIsoCode() {
        return getFieldValue(this.batch.data, BATCH_CURRENCY_ISO_CODE);
    }

    get expectedCountOfGifts() {
        return getFieldValue(this.batch.data, EXPECTED_COUNT_OF_GIFTS);
    }

    get expectedTotalBatchAmount() {
        return getFieldValue(this.batch.data, EXPECTED_TOTAL_BATCH_AMOUNT);
    }

    get batchName() {
        return getFieldValue(this.batch.data, BATCH_NAME);
    }

    get userDefinedBatchTableColumnNames() {
        const batchTableColumns = validateJSONString(
            getFieldValue(this.batch.data, BATCH_TABLE_COLUMNS_FIELD)
        );
        if (batchTableColumns) return batchTableColumns;
        return [];
    }

    get giftsTableTitle() {
        return format(geBatchGiftsHeader, [this.batchName]);
    }

    shouldDisplayExpiredAuthorizationWarning() {
        return this.isElevateCustomer
            && this.batchTotals.hasPaymentsWithExpiredAuthorizations 
            && !this._hasDisplayedExpiredAuthorizationWarning;
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [
            BATCH_ID_FIELD,
            BATCH_NAME
        ],
        optionalFields: [
            BATCH_CURRENCY_ISO_CODE,
            EXPECTED_COUNT_OF_GIFTS,
            EXPECTED_TOTAL_BATCH_AMOUNT,
            REQUIRE_TOTAL_MATCH,
            BATCH_TABLE_COLUMNS_FIELD
        ]
    })
    wiredBatch({data, error}) {
        if (data) {
            this.batch.data = data;
            this.retrieveBatchTotals();
        } else if (error) {
            handleError(error);
        }
    }

    async handleProcessBatch() {
        if (this.isProcessable()) {
            try {
                await this.refreshBatchTotals();
            } catch (error) {
                handleError(error);
            } finally {
                await this.startBatchProcessing();
            }
            return;
        }
        this.handleBatchProcessingErrors();
    }

    async startBatchProcessing() {
        if (this.shouldDisplayExpiredAuthorizationWarning()) {
            this.displayExpiredAuthorizationWarningModalForProcessAndDryRun(
                this.processBatchAndCloseAuthorizationWarningModal()
            );
            return;
        }
        await this.processBatch();
    }

    processBatchAndCloseAuthorizationWarningModal() {
        return async () => {
            await this.processBatch();
            this.dispatchEvent(new CustomEvent('closemodal'));
        };
    }

    handleBatchProcessingErrors() {
        if (this.expectedCountOfGifts && this.expectedTotalBatchAmount) {
            handleError(geBatchGiftsExpectedTotalsMessage);
        } else {
            handleError(geBatchGiftsExpectedCountOrTotalMessage);
        }
    }

    get isBatchProcessing() {
        return this._isBatchProcessing;
    }

    async processBatch() {
        await processBatch({
            batchId: this.batchId
        }).then(() => {
            this._isBatchProcessing = true;
        }).catch(error => {
            handleError(error);
        }).finally(() => {
            this.startPolling();
        });
    }

    async startPolling() {
        const poll = setInterval(() => {
            Promise.resolve(true).then(() => {
                this.refreshBatchTotals();
            }).then(() => {
                if (!this._isBatchProcessing) {
                    this.handleProcessedBatch();
                    clearInterval(poll);
                }
                if (!this.isBatchGiftEntryInFocus()) {
                    clearInterval(poll);
                }
            })
        }, 5000);
    }

    isBatchGiftEntryInFocus() {
        return location.href.includes(this.batchId);
    }

    handleProcessedBatch() {
        this.collapseForm();
        showToast(
            this.CUSTOM_LABELS.PageMessagesConfirm,
            GeLabelService.format(
                this.CUSTOM_LABELS.geBatchProcessingSuccess,
                [this.batchName]),
            'success',
            'dismissible',
            null
        );
    }

    collapseForm() {
        const form = this.template.querySelector('c-ge-form-renderer');
        form.collapse();
    }

    async refreshBatchTotals() {
        this._hasDisplayedExpiredAuthorizationWarning = false;
        this.batchTotals = await BatchTotals(this.batchId);
        this._isBatchProcessing = this.batchTotals.isProcessingGifts;
    }

    requireTotalMatch() {
        return getFieldValue(this.batch.data, REQUIRE_TOTAL_MATCH);
    }

    totalsMatch() {
        if (this.expectedCountOfGifts && this.expectedTotalBatchAmount) {
            return this.countMatches && this.amountMatches;
        } else if (this.expectedCountOfGifts) {
            return this.countMatches;
        } else if (this.expectedTotalBatchAmount) {
            return this.amountMatches;
        }
    }

    get countMatches() {
        return this.count === this.expectedCountOfGifts;
    }

    get amountMatches() {
        return this.total === this.expectedTotalBatchAmount;
    }

    isProcessable() {
        if (this.totalsMatch()) {
            return true;
        }
        return !this.requireTotalMatch();
    }

    handleDelete(event) {
        this.count--;
        this.total = this.total - event.detail.amount;
    }

    handleCountChanged(event) {
        this.count = event.detail.value;
    }

    handleTotalChanged(event) {
        this.total = event.detail.value;
    }

    get batchId() {
        return getFieldValue(this.batch.data, BATCH_ID_FIELD);
    }

    handleReceiveEvent(event) {
        const closeModalCallback = function() {
            closeModal();
            unregisterModalListener();
        }
        const closeModal = () => this.dispatchEvent(new CustomEvent('closemodal'));
        const unregisterModalListener = () =>
            unregisterListener('privateselectcolumns', this.handleReceiveEvent, this);

        if (event.action === 'save') {
            let fields = {};
            fields[BATCH_ID_FIELD.fieldApiName] = this.batchId;
            fields[BATCH_TABLE_COLUMNS_FIELD.fieldApiName] =
                JSON.stringify(event.payload.values);

            const recordInput = { fields };
            const lastModifiedDate =
                this.batch.data.lastModifiedDate;
            const clientOptions = {'ifUnmodifiedSince': lastModifiedDate};
            updateRecord(recordInput, clientOptions)
                .then(closeModalCallback)
                .catch((error) =>
                    handleError(error)
                );
        } else {
            closeModalCallback();
        }
    }

    @wire(getObjectInfo, { objectApiName: DATA_IMPORT_BATCH_OBJECT})
    dataImportBatchObjectInfo;

    get userCanEditBatchTableColumns() {
        try {
            return this.dataImportBatchObjectInfo.data.fields[
                BATCH_TABLE_COLUMNS_FIELD.fieldApiName
                ].updateable;
        } catch (e) {
            return false;
        }
    }

    handleSelectColumns(event) {
        const modalContent =
            this.userCanEditBatchTableColumns ?
                this.buildModalConfigSelectColumns(
                    event.detail.options,
                    event.detail.values) :
                this.modalConfigNoAccess;

        registerListener('privateselectcolumns', this.handleReceiveEvent, this);

        this.dispatchEvent(new CustomEvent('togglemodal', {
            detail: modalContent
        }));
    }

    displayModalPrompt(componentProperties) {
        const detail = {
            modalProperties: {
                componentName: 'geModalPrompt',
                showCloseButton: true
            },
            componentProperties
        };
        this.dispatchEvent(new CustomEvent('togglemodal', { detail }));      
    }

    displayExpiredAuthorizationWarningModalForPageLoad() {
        this.displayModalPrompt ({
                'variant': 'warning',
                'title': this.CUSTOM_LABELS.gePaymentAuthExpiredHeader,
                'message': this.CUSTOM_LABELS.gePaymentAuthExpiredWarningText,
                'buttons': 
                    [{
                        label: this.CUSTOM_LABELS.commonOkay,
                        variant: 'neutral',
                        action: () => { this.dispatchEvent(new CustomEvent('closemodal')); }
                    }]
            });
        this._hasDisplayedExpiredAuthorizationWarning = true;
    }

    displayExpiredAuthorizationWarningModalForProcessAndDryRun(actionOnProceed) {
        this.displayModalPrompt ({
                'variant': 'warning',
                'title': this.CUSTOM_LABELS.gePaymentAuthExpiredHeader,
                'message': this.CUSTOM_LABELS.gePaymentAuthExpiredWarningText,
                'buttons': 
                    [{
                        label: this.CUSTOM_LABELS.geProcessAnyway,
                        variant: 'neutral',
                        action: actionOnProceed
                    },
                    {
                        label: this.CUSTOM_LABELS.commonCancel,
                        variant: 'brand',
                        action: () => { this.dispatchEvent(new CustomEvent('closemodal')); }
                    }]
            });
        this._hasDisplayedExpiredAuthorizationWarning = true;
    }    

    buildModalConfigSelectColumns(available, selected) {
        const modalConfig = {
            componentProperties: {
                name: 'selectcolumnsmodal',
                cssClass: 'slds-m-bottom_medium slds-p-horizontal_small',
                sourceLabel: this.CUSTOM_LABELS.geLabelCustomTableSourceFields,
                selectedLabel: this.CUSTOM_LABELS.geLabelCustomTableSelectedFields,
                dedicatedListenerEventName: 'privateselectcolumns',
                options: available,
                values: selected,
                showModalFooter: true,
                min: 1
            },
            modalProperties: {
                cssClass: 'slds-modal_large',
                header: this.CUSTOM_LABELS.geTabBatchTableColumns,
                componentName: 'utilDualListbox',
                showCloseButton: true
            }
        };
        return modalConfig;
    }

    get modalConfigNoAccess() {
        const errorFieldName =
            `${BATCH_TABLE_COLUMNS_FIELD.objectApiName}: (${BATCH_TABLE_COLUMNS_FIELD.fieldApiName})`;
        const errorFLSBody = GeLabelService.format(
            this.CUSTOM_LABELS.geErrorFLSBody, [errorFieldName]
        );
        const message = `${this.CUSTOM_LABELS.geErrorFLSBatchTableColumns}  ${errorFLSBody}`;
        return {
            componentProperties: {
                name: 'noaccessmodal',
                illustrationClass: 'slds-p-around_large',
                dedicatedListenerEventName: 'privateselectcolumns',
                showModalFooter: false,
                message: message,
                title: this.CUSTOM_LABELS.geErrorFLSHeader,
                variant: 'no-access'
            },
            modalProperties: {
                cssClass: 'slds-modal_large',
                header: this.CUSTOM_LABELS.geTabBatchTableColumns,
                componentName: 'utilIllustration',
                showCloseButton: true
            }
        };
    }

}
