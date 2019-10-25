import { LightningElement, api, track, wire } from 'lwc';
import { mutable, inputTypeByDescribeType, lightningInputTypeByDataType, showToast, dispatch } from 'c/utilTemplateBuilder';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

export default class geTemplateBuilderFormField extends LightningElement {
    @track field;

    @api
    set field(field) {
        this.field = field;
    }

    _wiredAdapterArgs;

    renderedCallback() {
        console.log('renderedCallback');
        if (!this._wiredAdapterArgs && this.field && this.field.fieldInfo) {
            console.log('Field: ', mutable(this.field));
            this._wiredAdapterArgs = this.field.fieldInfo;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$_wiredAdapterArgs.defaultRecordTypeId',
        fieldApiName: '$_wiredAdapterArgs' })
    wiredPicklistOptions({ error, data }) {
        if (data) {
            let field = mutable(this.field);
            const picklistOptions = data.values;
            field.picklistOptions = picklistOptions;
            this.field = field;

            let detail = {
                fieldName: this.field.apiName,
                property: 'picklistOptions',
                value: picklistOptions
            }

            dispatch(this, 'updateformfield', detail);
        }
    }

    get isRequired() {
        return (this.field.required === 'Yes' || this.field.required === true) ? true : false;
    }

    get isLightningTextarea() {
        return this.lightningInputType === 'textarea' ? true : false;
    }

    get isLightningCombobox() {
        return this.lightningInputType === 'combobox' ? true : false;
    }

    get isLightningSearch() {
        return this.lightningInputType === 'search' ? true : false;
    }

    get isLightningRichText() {
        return this.lightningInputType === 'richtext' ? true : false;
    }

    get isLightningCheckbox() {
        return this.lightningInputType === 'checkbox' ? true : false;
    }

    get isLightningInput() {
        if (this.lightningInputType !== 'textarea' &&
            this.lightningInputType !== 'combobox' &&
            this.lightningInputType !== 'richtext' &&
            this.lightningInputType !== 'search' &&
            this.lightningInputType !== 'checkbox') {
            return true;
        }
        return false;
    }

    get lightningInputType() {
        return this.field.dataType ? inputTypeByDescribeType[this.field.dataType.toLowerCase()] : 'text';
    }

    // TODO: Needs to be completed for lookup fields
    handleSearch(event) {
        event.stopPropagation();
        console.log('handle search');
        const isEnterKey = event.keyCode === 13;
        if (isEnterKey) {
            showToast(this, 'Search Test', event.target.value, 'warning');
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's required property has changed.
    *
    * @param {object} event: Event object from lightning-input checkbox onchange
    * event handler 
    */
    handleOnChangeRequiredField(event) {
        this.stopPropagation(event);
        let detail = {
            fieldName: this.field.apiName,
            property: 'required',
            value: event.target.checked
        }

        dispatch(this, 'updateformfield', detail);
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's defaultValue property for a combobox has changed.
    *
    * @param {object} event: Event object from lightning-combobox onchange event handler 
    */
    handleChangeCombobox(event) {
        let detail = {
            fieldName: this.field.apiName,
            property: 'defaultValue',
            value: event.target.value
        }

        dispatch(this, 'updateformfield', detail);
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's defaultValue property has changed.
    *
    * @param {object} event: Event object from various lightning-input type's
    * onblur event handler 
    */
    handleOnBlur(event) {
        let value;

        if (this.field.dataType && this.field.dataType.toLowerCase() === 'boolean') {
            value = event.target.checked;
        } else {
            value = event.target.value;
        }

        let detail = {
            fieldName: this.field.apiName,
            property: 'defaultValue',
            value: value
        }

        dispatch(this, 'updateformfield', detail);
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's customLabel property has changed.
    *
    * @param {object} event: Event object from lightning-input onblur event handler 
    */
    handleOnBlurCustomLabel(event) {
        let detail = {
            fieldName: this.field.apiName,
            property: 'customLabel',
            value: event.target.value
        }
        dispatch(this, 'updateformfield', detail);
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's needs to be removed.
    *
    * @param {object} event: Event object from lightning-button-icon onclick event handler
    */
    handleFormFieldDelete(event) {
        this.stopPropagation(event);
        dispatch(this, 'deleteformfield', this.field.apiName);
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's needs to be moved up.
    *
    * @param {object} event: Event object from lightning-button-icon onclick event handler
    */
    handleFormFieldUp(event) {
        this.stopPropagation(event);
        dispatch(this, 'formfieldup', this.field.apiName);
    }

    /*******************************************************************************
    * @description Dispatches an event to notify parent component that the form
    * field's needs to be moved down.
    *
    * @param {object} event: Event object from lightning-button-icon onclick event handler
    */
    handleFormFieldDown(event) {
        this.stopPropagation(event);
        dispatch(this, 'formfielddown', this.field.apiName);
    }

    /*******************************************************************************
    * @description Public method that collects the current values of all the relevant
    * input fields for this FormField and return an instance of FormField. 
    *
    * @return {object} field: Instance of the FormField class
    */
    @api
    getFormFieldValues() {
        const inputType = lightningInputTypeByDataType[this.lightningInputType] ? lightningInputTypeByDataType[this.lightningInputType] : 'lightning-input';
        const required = this.template.querySelector('lightning-input[data-name="required"]').checked;
        const customLabel = this.template.querySelector('lightning-input[data-name="customLabel"]').value;
        let defaultValue = this.template.querySelector(`${inputType}[data-name="defaultValue"]`).value;

        // TODO: Clean up way of getting default value if checkbox
        if (this.field.dataType && this.field.dataType.toLowerCase() === 'boolean') {
            defaultValue = this.template.querySelector(`${inputType}[data-name="defaultValue"]`).checked;
        }

        let field = mutable(this.field);
        field.required = required;
        field.defaultValue = defaultValue;
        // TODO: tbd on this prop's possible values (single/widget)
        //field.elementType = elementType;
        field.displayRule = undefined;
        field.validationRule = undefined;
        field.customLabel = customLabel;

        return field;
    }
}