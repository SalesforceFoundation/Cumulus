import { LightningElement, track, api, wire } from 'lwc';
import {
    BATCH_CURRENCY_ISO_CODE,
    dispatch,
    handleError,
} from 'c/utilTemplateBuilder';
import { mutable, findIndexByProperty, isEmpty } from 'c/utilCommon';
import TemplateBuilderService from 'c/geTemplateBuilderService';
import GeLabelService from 'c/geLabelService';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

// Import schema for default form field element objects
import DATA_IMPORT_INFO from '@salesforce/schema/DataImport__c';

// Import schema for DataImport__c fields
import ACCOUNT1_IMPORTED_FIELD from '@salesforce/schema/DataImport__c.Account1Imported__c';
import ACCOUNT1_NAME_FIELD from '@salesforce/schema/DataImport__c.Account1_Name__c';
import CONTACT1_CONSENT_MESSAGE_FIELD from '@salesforce/schema/DataImport__c.Contact1_Consent_Message__c';
import CONTACT1_CONSENT_OPT_IN_FIELD from '@salesforce/schema/DataImport__c.Contact1_Consent_Opt_In__c';
import CONTACT1_IMPORTED_FIELD from '@salesforce/schema/DataImport__c.Contact1Imported__c';
import CONTACT1_LASTNAME_FIELD from '@salesforce/schema/DataImport__c.Contact1_Lastname__c';
import DONATION_ELEVATE_RECURRING_ID_FIELD from '@salesforce/schema/DataImport__c.Donation_Elevate_Recurring_ID__c';
import PAYMENT_AUTHORIZATION_TOKEN_FIELD from '@salesforce/schema/DataImport__c.Payment_Authorization_Token__c';
import PAYMENT_AUTHORIZED_DATE_FIELD from '@salesforce/schema/DataImport__c.Payment_Authorized_Date__c';
import PAYMENT_AUTHORIZED_UTC_TIMESTAMP_FIELD from '@salesforce/schema/DataImport__c.Payment_Authorized_UTC_Timestamp__c';
import PAYMENT_CARD_EXPIRATION_MONTH_FIELD from '@salesforce/schema/DataImport__c.Payment_Card_Expiration_Month__c';
import PAYMENT_CARD_EXPIRATION_YEAR_FIELD from '@salesforce/schema/DataImport__c.Payment_Card_Expiration_Year__c';
import PAYMENT_CARD_LAST_4_FIELD from '@salesforce/schema/DataImport__c.Payment_Card_Last_4__c';
import PAYMENT_CARD_NETWORK_FIELD from '@salesforce/schema/DataImport__c.Payment_Card_Network__c';
import PAYMENT_DECLINED_REASON_FIELD from '@salesforce/schema/DataImport__c.Payment_Declined_Reason__c';
import PAYMENT_ELEVATE_CREATED_DATE_FIELD from '@salesforce/schema/DataImport__c.Payment_Elevate_Created_Date__c';
import PAYMENT_ELEVATE_CREATED_UTC_TIMESTAMP_FIELD from '@salesforce/schema/DataImport__c.Payment_Elevate_Created_UTC_Timestamp__c';
import PAYMENT_ELEVATE_ID_FIELD from '@salesforce/schema/DataImport__c.Payment_Elevate_ID__c';
import PAYMENT_ELEVATE_ORIGINAL_PAYMENT_ID_FIELD from '@salesforce/schema/DataImport__c.Payment_Elevate_Original_Payment_ID__c';
import PAYMENT_GATEWAY_ID_FIELD from '@salesforce/schema/DataImport__c.Payment_Gateway_ID__c';
import PAYMENT_GATEWAY_PAYMENT_IDFIELD from '@salesforce/schema/DataImport__c.Payment_Gateway_Payment_ID__c';
import PAYMENT_ORIGIN_ID_FIELD from '@salesforce/schema/DataImport__c.Payment_Origin_ID__c';
import PAYMENT_ORIGIN_NAME_FIELD from '@salesforce/schema/DataImport__c.Payment_Origin_Name__c';
import PAYMENT_ORIGIN_TYPE_FIELD from '@salesforce/schema/DataImport__c.Payment_Origin_Type__c';
import PAYMENT_STATUS_FIELD from '@salesforce/schema/DataImport__c.Payment_Status__c';
import PAYMENT_TYPE_FIELD from '@salesforce/schema/DataImport__c.Payment_Type__c';
import PAYMENT_ACH_LAST_4 from '@salesforce/schema/DataImport__c.Payment_ACH_Last_4__c';
import PAYMENT_ACH_CODE from '@salesforce/schema/DataImport__c.Payment_ACH_Code__c';
import PAYMENT_DONOR_COVER_AMOUNT from '@salesforce/schema/DataImport__c.Payment_Donor_Cover_Amount__c';

const FIELD = 'field';
const BOOLEAN_TYPE = 'BOOLEAN';
const DONATION_DONOR_LABEL = 'Donation Donor';
const COMMA_CHARACTER = ', ';
const PERIOD_CHARACTER = '.';
let REQUIRED_FORM_FIELDS_MESSAGE = '';

// Required form fields for template save validation
const REQUIRED_FORM_FIELDS = [
    ACCOUNT1_IMPORTED_FIELD.fieldApiName,
    ACCOUNT1_NAME_FIELD.fieldApiName,
    CONTACT1_IMPORTED_FIELD.fieldApiName,
    CONTACT1_LASTNAME_FIELD.fieldApiName
];

const FIELD_BUNDLES_SECTION_ID = 'fieldBundles';
const FORM_FIELDS_SECTION_ID = 'formFields';
const ADVANCED_FIELDS_SECTION_ID = 'advancedFormFields';

// List of object mappings to exclude from Template Builder
const EXCLUDED_OBJECT_MAPPINGS = [
    'Opportunity_Contact_Role_1',
    'Opportunity_Contact_Role_2'
];

// List of field mappings to exclude from Template Builder
const EXCLUDED_FIELD_MAPPINGS_BY_SOURCE_API_NAME = [
    CONTACT1_CONSENT_MESSAGE_FIELD.fieldApiName,
    CONTACT1_CONSENT_OPT_IN_FIELD.fieldApiName,
    DONATION_ELEVATE_RECURRING_ID_FIELD.fieldApiName,
    PAYMENT_AUTHORIZATION_TOKEN_FIELD.fieldApiName,
    PAYMENT_AUTHORIZED_DATE_FIELD.fieldApiName,
    PAYMENT_AUTHORIZED_UTC_TIMESTAMP_FIELD.fieldApiName,
    PAYMENT_CARD_EXPIRATION_MONTH_FIELD.fieldApiName,
    PAYMENT_CARD_EXPIRATION_YEAR_FIELD.fieldApiName,
    PAYMENT_CARD_LAST_4_FIELD.fieldApiName,
    PAYMENT_CARD_NETWORK_FIELD.fieldApiName,
    PAYMENT_DECLINED_REASON_FIELD.fieldApiName,
    PAYMENT_ELEVATE_CREATED_DATE_FIELD.fieldApiName,
    PAYMENT_ELEVATE_CREATED_UTC_TIMESTAMP_FIELD.fieldApiName,
    PAYMENT_ELEVATE_ID_FIELD.fieldApiName,
    PAYMENT_ELEVATE_ORIGINAL_PAYMENT_ID_FIELD.fieldApiName,
    PAYMENT_GATEWAY_ID_FIELD.fieldApiName,
    PAYMENT_GATEWAY_PAYMENT_IDFIELD.fieldApiName,
    PAYMENT_ORIGIN_ID_FIELD.fieldApiName,
    PAYMENT_ORIGIN_NAME_FIELD.fieldApiName,
    PAYMENT_ORIGIN_TYPE_FIELD.fieldApiName,
    PAYMENT_STATUS_FIELD.fieldApiName,
    PAYMENT_TYPE_FIELD.fieldApiName,
    PAYMENT_ACH_LAST_4.fieldApiName,
    PAYMENT_ACH_CODE.fieldApiName,
    PAYMENT_DONOR_COVER_AMOUNT.fieldApiName
];

const FIELD_BUNDLE_MASTER_NAMES = [
    'Data Import',
    'Field Bundles'
];

const ADVANCED_MAPPING_MASTER_NAMES = [
    'Account 2',
    'Contact 2',
    'GAU Allocation 1',
    'GAU Allocation 2',
    'Household',
    'Opportunity Contact Role 1',
    'Opportunity Contact Role 2'
];

const OBJECT_MAPPING_HELP_TEXT = {
    'Account 1': 'geHelpTextAccount1Mapping',
    'Account 2': 'geHelpTextAccount2Mapping',
    'Address': 'geHelpTextAddressMapping',
    'Contact 1': 'geHelpTextContact1Mapping',
    'Contact 2': 'geHelpTextContact2Mapping',
    'GAU Allocation 1': 'geHelpTextAllocation1Mapping',
    'GAU Allocation 2': 'geHelpTextAllocation2Mapping',
    'Allocations': 'geHelpTextAllocationBundle',
    'Household': 'geHelpTextHouseholdMapping'
};

const FIELD_MAPPING_HELP_TEXT = {
    'Allocations': 'geHelpTextAllocationBundle',
    [DONATION_DONOR_LABEL]: 'geHelpTextDonationDonor'
};

export default class geTemplateBuilderFormFields extends LightningElement {


    @api previousSaveAttempted;
    @api selectedFieldMappingSet;
    @api formSections;
    @api activeFormSectionId;
    @api sectionIdsByFieldMappingDeveloperNames;

    @track objectMappings;
    @track pageLevelError = {};

    isInitialized;
    isLoading = true;
    isAllSectionsExpanded = false;
    isReadMoreActive = false;

    // Expose labels to template
    CUSTOM_LABELS = GeLabelService.CUSTOM_LABELS;
    objectMappingNames = [];
    // identifiers for use with querySelectors
    LOCATORS = {
        FIELD_BUNDLES_SECTION_ID,
        FORM_FIELDS_SECTION_ID,
        ADVANCED_FIELDS_SECTION_ID
    };
    sourceObjectFieldsDescribe;


    @wire(getObjectInfo, { objectApiName: DATA_IMPORT_INFO })
    dataImportObjectInfo({ data, error }) {
        if (data) {
            this.sourceObjectFieldsDescribe = data.fields;
            this.buildRequiredFieldsMessage(data);
        }
        if (error) {
            handleError(error);
        }
    }

    @api
    validate() {
        let isValid;
        let objectMappingsWithMissingRequiredFields = new Set();
        let missingRequiredFieldMappings = [];
        const elements = this.template.querySelectorAll('lightning-input');
        let countOfConditionallyRequiredFormFields = 0;

        elements.forEach(el => {
            if (REQUIRED_FORM_FIELDS.includes(el.getAttribute('data-source-api-name')) && el.checked) {
                countOfConditionallyRequiredFormFields++;
            }
            if (el.required && !el.checked) {
                objectMappingsWithMissingRequiredFields.add(el.getAttribute('data-object-mapping'));
                let objectMappingLabel = el.getAttribute('data-object-mapping-label');
                missingRequiredFieldMappings.push(`${objectMappingLabel}: ${el.label}`);
            }

            this.validateGiftField(el);
        });
        if (countOfConditionallyRequiredFormFields === 0) {
            let requiredGroupFieldsMessage = GeLabelService.format(
                this.CUSTOM_LABELS.geErrorPageLevelMissingRequiredGroupFields,
                [REQUIRED_FORM_FIELDS_MESSAGE]);
            missingRequiredFieldMappings.push(`${requiredGroupFieldsMessage}`);
        }

        if (missingRequiredFieldMappings.length > 0) {
            const lightningAccordion = this.template.querySelector('lightning-accordion');
            lightningAccordion.activeSectionName = [...objectMappingsWithMissingRequiredFields];

            this.pageLevelError = {
                hasErrors : true,
                title : this.CUSTOM_LABELS.commonError,
                message: this.CUSTOM_LABELS.geErrorPageLevelMissingRequiredFields,
                errors: [...missingRequiredFieldMappings],
                variant: 'error'
            }

            isValid = false;
        } else {
            isValid = true;

            this.pageLevelError = {
                hasErrors : false,
                errors: []
            }
        }

        dispatch(this, 'updatevalidity', { property: 'hasSelectFieldsTabError', hasError: this.pageLevelError.hasErrors });
        return isValid;
    }

    connectedCallback() {
        this.init();
    }

    init = async () => {
        this.objectMappings = await this.buildObjectMappingsList();
        this.handleSortFieldMappings();
        this.toggleCheckboxForSelectedFieldMappings(this.objectMappings);
        this.isLoading = false;
    };

    renderedCallback() {
        if (!this.isInitialized && this.isLoading === false && this.previousSaveAttempted) {
            this.isInitialized = true;
            this.validate();
        }

        // Set top section as active if there are multiple sections and none are selected on load
        if (!this.activeFormSectionId && this.formSections && this.formSections.length >= 2) {
            this.handleChangeActiveSection({ detail: this.formSections[0].id });
        }
    }

    toggleModal(event) {
        dispatch(this, 'togglemodal', event.detail);
    }

    toggleExpandableSection(sectionId) {
        const section = this.getSectionById(sectionId);
        section.isCollapsed = !section.isCollapsed;
        return section.isCollapsed;
    }

    expandSubSections(sectionId, objectMappings) {
        const lightningAccordion = this.template.querySelector(`[data-section-id=${sectionId}] lightning-accordion`);
        lightningAccordion.activeSectionName = objectMappings.map(mapping => mapping.DeveloperName);
    }

    collapseSubSections(sectionId) {
        const lightningAccordion = this.template.querySelector(`[data-section-id=${sectionId}] lightning-accordion`);
        lightningAccordion.activeSectionName = '';
    }

    isSectionCollapsed(sectionId) {
        const section = this.getSectionById(sectionId);
        return section && section.isCollapsed;
    }

    getSectionById(sectionId) {
        return this.template.querySelector(`[data-section-id=${sectionId}]`);
    }

    /*******************************************************************************
    * @description Intermediary async method for pulling the object and field mappings
    * stored in the TemplateBuilderService component and build an iterable list for
    * the UI.
    */
    buildObjectMappingsList = async () => {
        let objectMappings = [];

        const fieldMappingsByObjMappingDevName = TemplateBuilderService.fieldMappingsByObjMappingDevName;
        for (const objMappingDevName in fieldMappingsByObjMappingDevName) {

            if (Object.prototype.hasOwnProperty.call(fieldMappingsByObjMappingDevName, objMappingDevName)) {

                const isAllowed = this.checkIfObjectMappingIsAllowed(objMappingDevName);
                if (isAllowed) {
                    this.objectMappingNames = [...this.objectMappingNames, objMappingDevName];

                    let objectMapping = {
                        ...TemplateBuilderService.objectMappingByDevName[objMappingDevName],
                        Field_Mappings: this.getObjectMappingFieldMappings(objMappingDevName)
                    };

                    if (this.shouldMappingBeExcluded(objectMapping.Field_Mappings)) {
                        continue;
                    }

                    objectMappings.push(objectMapping)
                }
            }
        }

        return objectMappings;
    };

    /*******************************************************************************
    * @description Check if the provided object mapping developer name is allowed
    * to be used in Template Builder.
    *
    * @param {string} objMappingDevName: Data_Import_Object_Mapping__mdt developer name
    *
    * @return {boolean}: True if the Object Mapping is allowed to be used in Template
    * Builder
    */
    checkIfObjectMappingIsAllowed(objectMappingDeveloperName) {
        return !EXCLUDED_OBJECT_MAPPINGS.includes(
            objectMappingDeveloperName.substring(0, objectMappingDeveloperName.length - 10));
    }

    /*******************************************************************************
    * @description Collects, sorts, and returns the provided Object Mapping's Field
    * Mappings. Field Mappings that are in the EXCLUDED_FIELD_MAPPINGS_BY_SOURCE_API_NAME
    * array are removed from the returned array.
    *
    * @param {string} objMappingDevName: Data_Import_Object_Mapping__mdt developer name
    *
    * @return {array}: An array of the Object Mapping's Field Mappings
    */
    getObjectMappingFieldMappings(objectMappingDeveloperName) {
        let allowedFieldMappings = [];

        const fieldMappings = TemplateBuilderService.fieldMappingsByObjMappingDevName[objectMappingDeveloperName];

        fieldMappings.forEach(fieldMapping => {
            const isAllowed = this.checkIfFieldMappingIsAllowed(fieldMapping);

            if (isAllowed) {
                this.setFieldMappingRequiredness(fieldMapping);
                allowedFieldMappings.push(fieldMapping);
            }
        });

        return allowedFieldMappings;
    }

    /*******************************************************************************
    * @description Check if the provided field mapping is allowed to be used in the
    * Template Builder.
    *
    * @param {object} fieldMapping: An instance of Data_Import_Field_Mapping__mdt
    */
    checkIfFieldMappingIsAllowed(fieldMapping) {
        if (this.isCurrencyIsoCodeFieldMapping(fieldMapping)) {
            return false;
        }
        const formFieldName = fieldMapping.Element_Type === FIELD ?
            fieldMapping.Source_Field_API_Name :
            fieldMapping.DeveloperName;

        return !EXCLUDED_FIELD_MAPPINGS_BY_SOURCE_API_NAME.includes(formFieldName);
    }

    isCurrencyIsoCodeFieldMapping(fieldMapping) {
        return fieldMapping.Target_Field_API_Name === BATCH_CURRENCY_ISO_CODE;
    }

    /*******************************************************************************
    * @description Set the form field requiredness based on various criterias.
    *
    * @param {object} fieldMapping: An instance of Data_Import_Field_Mapping__mdt
    */
    setFieldMappingRequiredness = (fieldMapping) => {
        if (fieldMapping.Target_Field_Label === DONATION_DONOR_LABEL) {
            //Forcing the requiredness of the Donation Donor field mapping
            fieldMapping.Is_Required = true;
        }

        if (fieldMapping.Source_Field_Data_Type === BOOLEAN_TYPE) {
            // force checkboxes to not be required on the template builder
            fieldMapping.Is_Required = false;
        }
    }

    /*******************************************************************************
    * @description Sorts the field mappings within their respective object mappings
    * alphabetically and by their requiredness.
    */
    handleSortFieldMappings() {
        let objectMappings = mutable(this.objectMappings);
        for (let i = 0; i < objectMappings.length; i++) {
            let objectMapping = objectMappings[i];

            if (objectMapping.Field_Mappings) {
                objectMapping.Field_Mappings.sort(function (a, b) {
                    const requiredCompare = b.Is_Required - a.Is_Required;
                    const labelCompare = !isEmpty(a.Target_Field_Label) ?
                        a.Target_Field_Label.localeCompare(b.Target_Field_Label) :
                        null;

                    return requiredCompare || labelCompare;
                });
            }
        }

        this.objectMappings = objectMappings;
    }

    /*******************************************************************************
    * @description Removes a section and unchecks checkboxes for all the gift fields
    * contained in this section
    *
    * @param {object} event: Onclick event object from lightning-button-icon
    */
    @api
    handleDeleteFormSection(event) {
        const formSectionId = event.detail;
        let isRequiredFormElement = false;

        let formSections = mutable(this.formSections);
        let formSection = formSections.find(fs => fs.id === formSectionId);

        if (formSection.id === this.activeFormSectionId) {
            this.activeFormSectionId = undefined;
        }

        if (formSection.elements && formSection.elements.length > 0) {
            const formFields = formSection.elements;
            for (let i = 0; i < formFields.length; i++) {
                if (formFields[i].Is_Required) {
                    isRequiredFormElement = true;
                }

                const inputName = formFields[i].componentName ?
                    formFields[i].componentName :
                    formFields[i].dataImportFieldMappingDevNames[0];

                let checkbox =
                    this.template.querySelector(`lightning-input[data-field-mapping="${inputName}"]`);
                checkbox.checked = false;
            }
        }

        const formSectionIndex = findIndexByProperty(formSections, 'id', formSection.id);
        formSections.splice(formSectionIndex, 1);

        if (formSections.length === 1) {
            this.handleChangeActiveSection({ detail: this.formSections[0].id });
        }

        if (isRequiredFormElement) {
            this.validate();
        }

        dispatch(this, 'refreshformsections', formSections);
    }

    /*******************************************************************************
    * @description Receives event from the child component and dispatches an event to
    * notify parent component geTemplateBuilder that the active section has changed.
    *
    * @param {object} event: Event object containing the section id from the
    * child component geTemplateBuilderFormSection.
    */
    handleChangeActiveSection(event) {
        dispatch(this, 'changeactivesection', event.detail);
    }

    /*******************************************************************************
    * @description Handles onchange event of the gift fields checkboxes. Adds/removes
    * gift fields from sections by dispatching an event to the parent component.
    *
    * @param {object} event: Onchange event object from lightning-input checkbox
    */
    handleToggleFieldMapping(event) {
        const fieldMappingDeveloperName = event.target.value;
        const fieldMapping = TemplateBuilderService.fieldMappingByDevName[fieldMappingDeveloperName];
        const objectMapping =
            TemplateBuilderService.objectMappingByDevName[fieldMapping.Target_Object_Mapping_Dev_Name];

        fieldMapping.Is_Required = fieldMapping.Source_Field_Data_Type === BOOLEAN_TYPE ? false :
            (fieldMapping.Target_Field_Label === DONATION_DONOR_LABEL ? true : fieldMapping.Is_Required);

        if (fieldMapping.Is_Required ||
            REQUIRED_FORM_FIELDS.includes(fieldMapping.Source_Field_API_Name) ||
            fieldMapping.isDescribable === false) {

            this.validate();
        }

        dispatch(this, 'togglefieldmapping', {
            clickEvent: event,
            fieldMappingDeveloperName: fieldMappingDeveloperName,
            fieldMapping: fieldMapping,
            objectMapping: objectMapping
        });   
    }

    /*******************************************************************************
     * @description Handles the custom event fired from the geTemplateBuilderFormSection child when
     * there is a metadata error on the field such as a deleted field mapping or deleted source or
     * target field.
     * @param {object} event: object for the custom event
     */
    handleFieldMetadataValidation(event) {
        if (event.detail.showError) {
            this.pageLevelError = {
                hasErrors: true,
                title: this.CUSTOM_LABELS.commonFieldsNotFound,
                message: this.CUSTOM_LABELS.geFieldsNotFoundMessage,
                type: 'fieldMetadata',
                variant: 'warning'
            }
        } else {
            if (this.pageLevelError.type === 'fieldMetadata') {
                this.pageLevelError = {};
            }
        }
    }

    /*******************************************************************************
    * @description Handles adding a new section. Dispatches an event to notify parent
    * component geTemplateBuilder that a new section needs to be added.
    *
    * @return {string} label: Label for the new section.
    */
    addSection(label) {
        dispatch(this, 'addformsection', { label: label });
    }

    /*******************************************************************************
    * @description Receives event from child component and dispatches event to
    * parent to move the given FormField up within its parent FormSection.
    *
    * @param {object} event: Event object from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection -> here
    */
    handleFormElementUp(event) {
        dispatch(this, 'formelementup', event.detail);
    }

    /*******************************************************************************
    * @description Receives event from child component and dispatches event to
    * parent to move the given FormField down within its parent FormSection.
    *
    * @param {object} event: Event object from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection -> here
    */
    handleFormElementDown(event) {
        dispatch(this, 'formelementdown', event.detail);
    }

    /*******************************************************************************
    * @description Receives event from child component and dispatches event to
    * parent to remove the FormField from its parent FormSection.
    *
    * @param {object} event: Event object from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection -> here
    */
    handleDeleteFormElement(event) {
        const element = this.template.querySelector(`lightning-input[data-field-mapping="${event.detail.fieldName}"]`);
        if (element) {
            element.checked = false;
        }

        this.validate();

        dispatch(this, 'deleteformelement', event.detail);
    }

    /*******************************************************************************
    * @description Receives event from child component and dispatches event to
    * parent to update the details of the given FormField.
    *
    * @param {object} event: Event object from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection -> here
    */
    handleUpdateFormElement(event) {
        dispatch(this, 'updateformelement', event.detail);
    }

    /*******************************************************************************
    * @description Receives event from child component and dispatches event to
    * parent to move the given FormSection up.
    *
    * @param {object} event: Event object from child component.
    * component chain: geTemplateBuilderFormSection -> here
    */
    handleFormSectionUp(event) {
        const sectionId = event.detail;
        dispatch(this, 'formsectionup', sectionId);
    }

    /*******************************************************************************
    * @description Receives event from child component and dispatches event to
    * parent to move the given FormSection down.
    *
    * @param {object} event: Event object from child component.
    * component chain: geTemplateBuilderFormSection -> here
    */
    handleFormSectionDown(event) {
        const sectionId = event.detail;
        dispatch(this, 'formsectiondown', sectionId);
    }

    /*******************************************************************************
    * @description Method toggles the checkboxes for any existing/selected gift
    * fields. Used when retrieving an existing form template.
    *
    * @param {list} objectMappings: List of object mappings containing field mapping details
    */
    toggleCheckboxForSelectedFieldMappings(objectMappings) {
        const selectedFieldMappings = Object.keys(this.sectionIdsByFieldMappingDeveloperNames);

        if (selectedFieldMappings && selectedFieldMappings.length > 0) {
            for (let i = 0; i < objectMappings.length; i++) {
                let fieldMappings = objectMappings[i].Field_Mappings;

                for (let ii = 0; ii < fieldMappings.length; ii++) {
                    let fieldMapping = fieldMappings[ii];

                    if (selectedFieldMappings.includes(fieldMapping.DeveloperName)) {
                        fieldMapping.checked = true;
                    }
                }
            }

            this.objectMappings = objectMappings;
        }
    }

    /*******************************************************************************
    * @description Handles onsectiontoggle event handler of lightning-accordion.
    * Sets the isAllSectionsExpanded property.
    *
    * @param {object} event: Event object from lightning-accordion onsectiontoggle
    * event handler.
    */
    handleSectionToggle(event) {
        const openSections = event.detail.openSections;

        if (openSections.length === 0) {
            this.isAllSectionsExpanded = false;
        } else if (openSections.length === this.objectMappingNames.length) {
            this.isAllSectionsExpanded = true;
        }
    }

    /**
     * Expand/collapse the header and all sub-sections for advanced form fields
     * @param event
     */
    handleToggleAdvancedSection(event) {
        const collapsed = this.toggleExpandableSection(this.LOCATORS.ADVANCED_FIELDS_SECTION_ID);
        if(collapsed) {
            this.collapseSubSections(this.LOCATORS.ADVANCED_FIELDS_SECTION_ID);
        } else {
            this.expandSubSections(this.LOCATORS.ADVANCED_FIELDS_SECTION_ID, this.advancedObjectMappings);
        }
    }

    /**
     * Expand/collapse the bundles section, no sub-sections currently present for this section
     * @param event
     */
    handleToggleBundlesSection(event) {
        this.toggleExpandableSection(this.LOCATORS.FIELD_BUNDLES_SECTION_ID);
    }

    /**
     * Expand/collapse the header and all sub-section for basic form fields
     * @param event
     */
    handleToggleBasicSection(event) {
        const collapsed = this.toggleExpandableSection(this.LOCATORS.FORM_FIELDS_SECTION_ID);
        if(collapsed) {
            this.collapseSubSections(this.LOCATORS.FORM_FIELDS_SECTION_ID);
        } else {
            this.expandSubSections(this.LOCATORS.FORM_FIELDS_SECTION_ID, this.basicObjectMappings);
        }
    }

    /*******************************************************************************
    * @description Method takes in a lightning-input element and sets validity.
    *
    * @param {object} element: Lightning-input element to set and report validity
    * of.
    */
    validateGiftField(element) {
        let customValidity =
            (element.required && element.checked === false) ?
                this.CUSTOM_LABELS.geErrorRequiredField
                : '';
        element.setCustomValidity(customValidity);
        element.reportValidity();
    }

    /*******************************************************************************
    * @description Method shows additional text content under the left column body.
    */
    handleBodyReadMore() {
        this.isReadMoreActive = true;
    }

    /*******************************************************************************
     * @description Method generates the required fields text attached to the validation message.
     *
     * @param {object} objectData: Returned Object Schema
     */
    buildRequiredFieldsMessage(objectData) {
        REQUIRED_FORM_FIELDS_MESSAGE = ''; // Clear out required fields placeholder
        for (let i = 0; i < REQUIRED_FORM_FIELDS.length; i++) {
            let character;
            if (i < REQUIRED_FORM_FIELDS.length - 1) {
                character = COMMA_CHARACTER;
            } else if (i === REQUIRED_FORM_FIELDS.length - 1) {
                character = PERIOD_CHARACTER;
            }
            REQUIRED_FORM_FIELDS_MESSAGE += objectData.fields[REQUIRED_FORM_FIELDS[i]].label + character;
        }
    }

    /**
     * For a given object mapping, check if help text exists for it and its mapped fields.
     * Append the help text to the mapping javascript object and its mapped fields.
     *
     * @param {object} mapping to look up help text for
     * @return {{helpText: *}|*} mapping with help text appended to it
     */
    mapHelpText = (mapping) => {
        const labelName = OBJECT_MAPPING_HELP_TEXT[mapping.MasterLabel];
        const Field_Mappings = mapping.Field_Mappings.map(this.mapFieldHelpText);
        if(labelName) {
            const helpText = this.CUSTOM_LABELS[labelName];
            return { ...mapping, Field_Mappings, helpText };
        }
        return { ...mapping, Field_Mappings };
    };

    /**
     * Append help text to a field mapping, if it exists.
     * @param fieldMapping
     * @return {{helpText: *}|*}
     */
    mapFieldHelpText = (fieldMapping) => {
        const labelName = FIELD_MAPPING_HELP_TEXT[fieldMapping.MasterLabel];
        if(labelName) {
            const helpText = this.CUSTOM_LABELS[labelName];
            return { ...fieldMapping, helpText };
        }
        return fieldMapping;
    };

    /**
     * Get basic object mappings by filtering the list of object mappings. These mappings are shown in the form
     * template builder by default.
     * @return {*[]|*}
     */
    get basicObjectMappings() {
        if (this.objectMappings) {
            return this.objectMappings
                .filter(mapping =>
                    !ADVANCED_MAPPING_MASTER_NAMES.includes(mapping.MasterLabel) &&
                    !FIELD_BUNDLE_MASTER_NAMES.includes(mapping.MasterLabel))
                .map(this.mapHelpText);
        }
        return [];
    }

    /**
     * Get advanced object mappings for the sidebar. These mappings are hidden by default
     * @return {*[]|*}
     */
    get advancedObjectMappings() {
        if (this.objectMappings) {
            return this.objectMappings
                .filter(mapping => ADVANCED_MAPPING_MASTER_NAMES.includes(mapping.MasterLabel))
                .map(this.mapHelpText);
        }
        return [];
    }

    get advancedSectionCollapsed() {
        return this.isSectionCollapsed(this.LOCATORS.ADVANCED_FIELDS_SECTION_ID);
    }

    get basicSectionCollapsed() {
        return this.isSectionCollapsed(this.LOCATORS.FORM_FIELDS_SECTION_ID);

    }

    get bundlesSectionCollapsed() {
        return this.isSectionCollapsed(this.LOCATORS.FIELD_BUNDLES_SECTION_ID);
    }

    /**
     * Get field bundle mappings for the sidebar.
     */
    get fieldBundleMappings() {
        if (this.objectMappings) {
            return this.objectMappings
                .filter(mapping => FIELD_BUNDLE_MASTER_NAMES.includes(mapping.MasterLabel))
                .map(this.mapHelpText);
        }
        return [];
    }

    /*******************************************************************************
    * Start getters for data-qa-locator attributes
    */

    get qaLocatorSectionFieldBundles() {
        return `section ${this.CUSTOM_LABELS.geHeaderFieldBundles}`;
    }

    get qaLocatorExpandFieldBundles() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsExpandAll} ${this.CUSTOM_LABELS.geHeaderFieldBundles}`;
    }

    get qaLocatorCollapseFieldBundles() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsCollapseAll} ${this.CUSTOM_LABELS.geHeaderFieldBundles}`;
    }

    get qaLocatorSectionFormFields() {
        return `section ${this.CUSTOM_LABELS.geTabFormFields}`;
    }

    get qaLocatorExpandFormFields() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsExpandAll} ${this.CUSTOM_LABELS.geTabFormFields}`;
    }

    get qaLocatorCollapseFormFields() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsCollapseAll} ${this.CUSTOM_LABELS.geTabFormFields}`;
    }

    get qaLocatorSectionAdvancedFormFields() {
        return `section ${this.CUSTOM_LABELS.geHeaderAdvancedFormFields}`;
    }

    get qaLocatorExpandAdvancedFormFields() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsExpandAll} ${this.CUSTOM_LABELS.geHeaderAdvancedFormFields}`;
    }

    get qaLocatorCollapseAdvancedFormFields() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsCollapseAll} ${this.CUSTOM_LABELS.geHeaderAdvancedFormFields}`;
    }

    get qaLocatorAddSection() {
        return `button ${this.CUSTOM_LABELS.geButtonFormFieldsAddSection}`;
    }

    /*******************************************************************************
    * End getters for data-qa-locator attributes
    */

}