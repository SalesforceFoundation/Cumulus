import {LightningElement, api} from 'lwc';
import { isUndefined } from 'c/utilCommon';

const COLLAPSED_DISPLAY_MODE = 'collapsed';

export default class GeFormSection extends LightningElement {
    @api gift;
    @api section;
    @api widgetConfig;
    @api formState;
    _hasPaymentWidget = false;

    renderedCallback() {
        this.registerPaymentWidget();
    }

    /**
     * Get the alternative text that represents the section expand/collapse button
     * @returns {string} containing the section expand alternative text
     */
    get altTextLabel() {
        return 'Toggle ' + this.section.label;
    }

    get isCollapsed() {
        return this.section.defaultDisplayMode === COLLAPSED_DISPLAY_MODE;
    }

    /**
     * Gets value and UI-label for the requestedFields in the section (if any)
     * @param requestedFields - Array of API Field Names to get information
     * @returns {Array} - field value and ui-label using api-field-name as key
     */
    @api
    getFieldValueAndLabel( requestedFields ) {

        const fields = this.template.querySelectorAll('c-ge-form-field');
        let dataImportFieldAndLabels = {};

        if (fields !== null && typeof fields !== 'undefined') {
            fields.forEach( field => {
                if ( requestedFields.indexOf(field.sourceFieldAPIName) !== -1 ){
                    field.clearCustomValidity();
                    dataImportFieldAndLabels = { ...dataImportFieldAndLabels, ...(field.fieldValueAndLabel) };
                }
            });
        }

        return dataImportFieldAndLabels;

    }

    /**
     * Sets custom validity on fields inside fieldsArray
     * @param fieldsArray
     * @param errorMessage
     */
    @api
    setCustomValidityOnFields( fieldsArray, errorMessage ) {

        const fields = this.template.querySelectorAll('c-ge-form-field');
        if (fields !== null && typeof fields !== 'undefined') {
            fields.forEach(f => {
                if ( fieldsArray.indexOf(f.sourceFieldAPIName)!== -1 ) {
                    f.setCustomValidity(errorMessage);
                }
            });
        }

    }

    /**
     * Get a list of fields that are required, but are null/undefined or otherwise blank in the dynamic form
     * @returns {Array} of invalid fields. If all fields are ok, the array is empty.
     */
    @api
    getInvalidFields() {
        const fields = this.template.querySelectorAll('c-ge-form-field');
        let invalidFields = [];

        fields.forEach(f => {
            if(!f.isValid()) {
                invalidFields.push(f.fieldLabel);
            }
        });

        return invalidFields;
    }

    @api
    getAllFieldsByAPIName() {
        const fields = this.template.querySelectorAll('c-ge-form-field');
        let fieldMappedByAPIName = {};

        fields.forEach(f => {
            fieldMappedByAPIName[f.sourceFieldAPIName] = f;
        });

        return fieldMappedByAPIName;
    }

    registerPaymentWidget() {
        if (!isUndefined(this.section)) {
            this.section.elements.forEach(element => {
                if (element.componentName === 'geFormWidgetTokenizeCard') {
                    this._hasPaymentWidget = true;
                }
            })
        }
        if (this._hasPaymentWidget) {
            const registerPaymentWidgetEvent = new CustomEvent(
                'registerpaymentwidget'
            );
            this.dispatchEvent(registerPaymentWidgetEvent)
        }

    }

    @api
    get paymentToken() {
        let widgetValues = [];
        const widgets = this.template.querySelectorAll('c-ge-form-widget');
        if (widgets !== null && typeof widgets !== 'undefined') {
            widgets.forEach(widget => {
                if (widget.isElevateTokenizeCard) {
                    widgetValues.push(widget.paymentToken);
                }
            });
        }
        return widgetValues;
    }

    @api
    get isPaymentWidgetAvailable() {
        return this._hasPaymentWidget;
    }

    get renderableElements() {
        if (isUndefined(this.section)) {
            return [];
        }
        return this.section.elements.filter(e => e.isRenderable);
    }

    handleFormWidgetChange(event) {
        this.dispatchEvent(new CustomEvent('formwidgetchange', {detail: event.detail}));
    }

    handleFormFieldChange(event) {
        this.dispatchEvent(new CustomEvent('formfieldchange', {detail: event.detail}));
    }

}