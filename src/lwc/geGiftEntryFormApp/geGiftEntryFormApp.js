import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import saveAndDryRunDataImport from '@salesforce/apex/GE_GiftEntryController.saveAndDryRunDataImport';
import sendPurchaseRequest from '@salesforce/apex/GE_GiftEntryController.sendPurchaseRequest';
import upsertDataImport from '@salesforce/apex/GE_GiftEntryController.upsertDataImport';
import submitDataImportToBDI from '@salesforce/apex/GE_GiftEntryController.submitDataImportToBDI';

//import GeFormService from 'c/geFormService';
import { showToast } from 'c/utilTemplateBuilder';
import { registerListener, unregisterListener } from 'c/pubsubNoPageRef';
import GeLabelService from 'c/geLabelService';

import DATA_IMPORT_BATCH_OBJECT from '@salesforce/schema/DataImportBatch__c';
import DI_PAYMENT_AUTHORIZE_TOKEN_FIELD from '@salesforce/schema/DataImport__c.Payment_Authorization_Token__c';
import DI_PAYMENT_STATUS_FIELD from '@salesforce/schema/DataImport__c.Payment_Status__c';
import DI_PAYMENT_DECLINED_REASON_FIELD from '@salesforce/schema/DataImport__c.Payment_Declined_Reason__c';
import DI_PAYMENT_METHOD_FIELD from '@salesforce/schema/DataImport__c.Payment_Method__c';
import DI_DONATION_AMOUNT_FIELD from '@salesforce/schema/DataImport__c.Donation_Amount__c';
import DI_DONATION_CAMPAIGN_NAME_FIELD from '@salesforce/schema/DataImport__c.Donation_Campaign_Name__c';
import { isNotEmpty } from 'c/utilCommon';

const PAYMENT_STATUS__C = DI_PAYMENT_STATUS_FIELD.fieldApiName;
const PAYMENT_DECLINED_REASON__C = DI_PAYMENT_DECLINED_REASON_FIELD.fieldApiName;
const PAYMENT_AUTHORIZE_TOKEN__C = DI_PAYMENT_AUTHORIZE_TOKEN_FIELD.fieldApiName;
const PAYMENT_METHOD__C = DI_PAYMENT_METHOD_FIELD.fieldApiName;
const DONATION_AMOUNT__C = DI_DONATION_AMOUNT_FIELD.fieldApiName;
const DONATION_CAMPAIGN_NAME__C = DI_DONATION_CAMPAIGN_NAME_FIELD.fieldApiName;
const TOKENIZE_TIMEOUT = 10000; // 10 seconds, long enough for cold starts?
const PAYMENT_TRANSACTION_STATUS_ENUM = Object.freeze({
    PENDING: 'PENDING',
    AUTHORIZED: 'AUTHORIZED',
    CANCELED: 'CANCELED',
    CAPTURED: 'CAPTURED',
    DECLINED: 'DECLINED',
    NONRETRYABLEERROR: 'NONRETRYABLEERROR',
    RETRYABLEERROR: 'RETRYABLEERROR',
    REFUNDISSUED: 'REFUNDISSUED'
});

export default class GeGiftEntryFormApp extends NavigationMixin(LightningElement) {
    @api recordId;
    @api sObjectName;

    @track isPermissionError;
    @track loadingText = 'Saving data import...';

    dataImportRecord = {};
    tokenPromise;
    errorCallback;

    CUSTOM_LABELS = GeLabelService.CUSTOM_LABELS;

    connectedCallback() {
        registerListener('tokenRequested', this.handleTokenRequested, this);
    }

    disconnectedCallback() {
        unregisterListener('tokenRequested', this.handleTokenRequested, this);
    }

    get isBatchMode() {
        return this.sObjectName &&
            this.sObjectName === DATA_IMPORT_BATCH_OBJECT.objectApiName;
    }

    handleTokenRequested() {
        this.tokenPromise = new Promise((resolve, reject) => {
            registerListener('tokenResponse', message => {
                if (message.error) {
                    reject(message);
                } else if (message.token) {
                    resolve(message.token);
                }
            }, this);
            setTimeout(() => {
                reject('Request timed out');
                unregisterListener('tokenResponse', resolve, this);
            }, TOKENIZE_TIMEOUT);
        });
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
                this.singleGiftSubmit(event);
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
        saveAndDryRunDataImport({ batchId: this.recordId, dataImport: this.dataImportRecord })
            .then((result) => {
                let dataImportModel = JSON.parse(result);
                Object.assign(dataImportModel.dataImportRows[0],
                    dataImportModel.dataImportRows[0].record);
                table.upsertData(dataImportModel.dataImportRows[0], 'Id');
                table.setTotalCount(dataImportModel.totalCountOfRows);
                table.setTotalAmount(dataImportModel.totalAmountOfRows);
                event.detail.success(); //Re-enable the Save button
            })
            .catch(error => {
                event.detail.error(error);
            });
    }

    /*******************************************************************************
    * @description Handles a single gift entry submit. Saves a Data Import record,
    * makes an elevate payment if needed, and processes the Data Import through
    * BDI.
    *
    * @param {object} event: Custom Event containing the Data Import record and a
    * callback for handling and displaying errors in the form.
    */
    singleGiftSubmit = async (event) => {
        let { inMemoryDataImport } = event.detail;
        this.hasUserSelectedDonation = event.detail.hasUserSelectedDonation;

        try {
            await this.saveDataImport(inMemoryDataImport);

            const hasPaymentToProcess = this.dataImportRecord[PAYMENT_AUTHORIZE_TOKEN__C];
            if (hasPaymentToProcess) {
                this.processPayment();
            } else {
                this.processDataImport();
            }
        } catch (error) {
            this.errorCallback(error);
        }
    }

    /*******************************************************************************
    * @description Upserts the provided data import record. Attempts to retrieve
    * an Elevate token for a purchase call if needed.
    *
    * @param {object} inMemoryDataImport: DataImport__c object built from the form
    * fields.
    *
    * @return {object} dataImportRecord: A DataImport__c record
    */
    saveDataImport = async (inMemoryDataImport) => {
        if (this.dataImportRecord.Id) {
            this.loadingText = 'Updating Data Import record...';
            inMemoryDataImport = this.prepareInMemoryDataImportForUpdate(inMemoryDataImport);
        } else {
            this.loadingText = 'Saving Data Import record...';
        }

        inMemoryDataImport[PAYMENT_AUTHORIZE_TOKEN__C] = await this.tokenPromise;
        this.dataImportRecord = await upsertDataImport({ dataImport: inMemoryDataImport });
    }

    /*******************************************************************************
    * @description Re-apply Data Import id and relevant payment/elevate fields.
    * The inMemoryDataImport is built new from the form on every save click. We
    * need to catch it up with the correct id to make sure we update instead of
    * inserting a new record on re-save attempts.
    *
    * @param {object} inMemoryDataImport: DataImport__c object built from the form
    * fields.
    *
    * @return {object} inMemoryDataImport: DataImport__c object built from the form
    * fields.
    */
    prepareInMemoryDataImportForUpdate(inMemoryDataImport) {
        inMemoryDataImport.Id = this.dataImportRecord.Id;
        inMemoryDataImport[PAYMENT_METHOD__C] = this.dataImportRecord[PAYMENT_METHOD__C];
        inMemoryDataImport[PAYMENT_STATUS__C] = this.dataImportRecord[PAYMENT_STATUS__C];
        inMemoryDataImport[PAYMENT_DECLINED_REASON__C] =
            this.dataImportRecord[PAYMENT_DECLINED_REASON__C];

        return inMemoryDataImport;
    }
    /*******************************************************************************
    * @description Method attempts to make a purchase call to Payment
    * Services. Immediately attempts to the charge the card provided in the Payment
    * Services iframe (GE_TokenizeCard).
    *
    * @param {object} dataImportRecord: A DataImport__c record
    */
    processPayment = async () => {
        this.loadingText = 'Charging card...';

        const isReadyToCharge = this.checkPaymentTransactionStatus(this.dataImportRecord[PAYMENT_STATUS__C]);
        if (isReadyToCharge) {

            const purchaseResponse = await this.makePurchaseCall();
            if (purchaseResponse) {

                this.dataImportRecord[PAYMENT_STATUS__C] = this.getPaymentStatus(purchaseResponse);
                this.dataImportRecord[PAYMENT_DECLINED_REASON__C] =
                    this.getPaymentDeclinedReason(purchaseResponse);

                this.dataImportRecord = await upsertDataImport({ dataImport: this.dataImportRecord });

                const isFailedPurchase = purchaseResponse.statusCode !== 201;
                if (isFailedPurchase) {

                    let errors = this.getFailedPurchaseMessage(purchaseResponse);
                    this.errorCallback(errors);
                    return;
                }
            }
        }

        this.processDataImport();
    }

    /*******************************************************************************
    * @description Method checks the current payment transaction's status and
    * returns true if the card is in a 'chargeable' status.
    *
    * @param {string} paymentStatus: Payment transaction status
    *
    * @return {boolean}: True if card is in a 'chargeable' status
    */
    checkPaymentTransactionStatus = (paymentStatus) => {
        switch (paymentStatus) {
            case PAYMENT_TRANSACTION_STATUS_ENUM.PENDING: return false;
            case PAYMENT_TRANSACTION_STATUS_ENUM.AUTHORIZED: return false;
            case PAYMENT_TRANSACTION_STATUS_ENUM.CANCELED: return false;
            case PAYMENT_TRANSACTION_STATUS_ENUM.CAPTURED: return false;
            case PAYMENT_TRANSACTION_STATUS_ENUM.DECLINED: return true;
            case PAYMENT_TRANSACTION_STATUS_ENUM.NONRETRYABLEERROR: return false;
            case PAYMENT_TRANSACTION_STATUS_ENUM.RETRYABLEERROR: return true;
            case PAYMENT_TRANSACTION_STATUS_ENUM.REFUNDISSUED: return false;
            default: return true;
        }
    }

    /*******************************************************************************
    * @description Posts an http request through the `sendPurchaseRequest` apex
    * method and parses the response.
    *
    * @param {object} dataImportRecord: A DataImport__c record
    *
    * @return {object} response: An http response object
    */
    makePurchaseCall = async () => {
        let purchaseResponseString = await sendPurchaseRequest({
            requestBodyParameters: this.buildRequestBodyParameters()
        });
        let response = JSON.parse(purchaseResponseString);
        response.body = JSON.parse(response.body);

        return response;
    }

    /*******************************************************************************
    * @description Builds parts of the purchase request body that requires data
    * from the Data Import record upfront. We pass this into the `sendPurchaseRequest`
    * method and is eventually merged in with the rest of the purchase request body.
    *
    * @param {object} dataImportRecord: A DataImport__c record
    *
    * @return {object}: Object that we can deserialize and apply to the purchase
    * request body in apex.
    */
    buildRequestBodyParameters() {
        const names = this.getCardholderNames();
        const firstName = isNotEmpty(names.firstName) ? names.firstName : names.accountName;
        const lastName = isNotEmpty(names.lastName) ? names.lastName : names.accountName;
        const metadata = {
            campaignCode: this.dataImportRecord[DONATION_CAMPAIGN_NAME__C]
        }

        return JSON.stringify({
            amount: this.dataImportRecord[DONATION_AMOUNT__C],
            email: 'test@test.test',
            firstName: firstName,
            lastName: lastName,
            metadata: metadata,
            paymentMethodToken: this.dataImportRecord[PAYMENT_AUTHORIZE_TOKEN__C],
        })
    }

    /*******************************************************************************
    * @description Queries for the geFormRenderer component and retrieves the
    * fabricated cardholder names object.
    *
    * @return {object}: Object containing firstName, lastName, and accountName
    * from the form.
    */
    getCardholderNames() {
        const renderer = this.template.querySelector('c-ge-form-renderer');
        return renderer.fabricatedCardholderNames;
    }

    /*******************************************************************************
    * @description Get the value for DataImport__c.Payment_Status__c from the
    * purchase call response.
    *
    * @param {object} response: Http response object
    *
    * @return {string}: Status of the payment charge request
    */
    getPaymentStatus(response) {
        return response.body.status || response.status || CUSTOM_LABELS.commonUnknownError;
    }

    /*******************************************************************************
    * @description Get the value for DataImport__c.Payment_Declined_Reason__c from
    * the purchase call response.
    *
    * @param {object} response: Http response object
    *
    * @return {string}: Reason the payment was declined
    */
    getPaymentDeclinedReason(response) {
        const isSuccessfulPurchase = response.statusCode === 201;
        return isSuccessfulPurchase ? null : JSON.stringify(response.body);
    }

    /*******************************************************************************
    * @description Get the message or errors from a failed purchase call.
    *
    * @param {object} response: Http response object
    *
    * @return {string}: Message from a failed purchase call response
    */
    getFailedPurchaseMessage(response) {
        // For some reason the key in the body object for 'Message'
        // in the response we receive from Elevate is capitalized.
        // Also checking for lowercase M in message in case they fix it.
        return response.body.Message ||
            response.body.message ||
            response.body.errors.map(error => error.message).join(', ') ||
            this.CUSTOM_LABELS.commonUnknownError;
    }

    /*******************************************************************************
    * @description Sends the Data Import into BDI for processing and navigates to
    * the opportunity record detail page on success.
    *
    * @param {object} dataImportRecord: A DataImport__c record
    * @param {boolean} hasUserSelectedDonation: True if a selection had been made in
    * the 'Review Donations' modal.
    * Determines BDI matching criteria.
    *   true = "single match or create" and means we are updating
    *   false = "do not match"
    */
    processDataImport = async () => {
        this.loadingText = 'Processing data import record...';

        submitDataImportToBDI({ diRecord: this.dataImportRecord, updateGift: this.hasUserSelectedDonation })
            .then(opportunityId => {
                this.loadingText = 'Navigating to opportunity record...';
                this.navigateToRecordPage(opportunityId);
            })
            .catch(error => {
                // TODO: Placeholder method for handling the scenario in which
                // we've charged a card successfully, but BDI processing failed.
                this.doSomethingLoud(error);
            });
    }

    doSomethingLoud(error) {
        this.errorCallback(error);
        // TODO: Potentially have to check for other types of status that MAY
        // indicate a charge could still occur (pending, authorized, etc)
        if (this.dataImportRecord[PAYMENT_STATUS__C] === PAYMENT_TRANSACTION_STATUS_ENUM.CAPTURED) {
            showToast('HEY!',
                'Card was charged. Please fix the outstanding errors and try again.',
                'error',
                'sticky');
        }
    }

    handleSectionsRetrieved(event) {
        const formSections = event.target.sections;
        const table = this.template.querySelector('c-ge-batch-gift-entry-table');
        table.handleSectionsRetrieved(formSections);
    }

    handleBatchDryRun() {
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
        form.reset();
        form.load(event.detail);
    }

    handlePermissionErrors() {
        this.isPermissionError = true;
    }
    handleEditBatch() {
        this.dispatchEvent(new CustomEvent('editbatch'));
    }

    handleReviewDonationsModal(event) {
        this.dispatchEvent(new CustomEvent('togglereviewdonationsmodal', { detail: event.detail }));
    }

    navigateToRecordPage(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }
}