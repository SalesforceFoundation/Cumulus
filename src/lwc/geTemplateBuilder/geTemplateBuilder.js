import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import storeFormTemplate from '@salesforce/apex/GE_TemplateBuilderCtrl.storeFormTemplate';
import retrieveFormTemplate from '@salesforce/apex/GE_TemplateBuilderCtrl.retrieveFormTemplate';
import { FormTemplate, FormLayout, mutable, findIndexByProperty, shiftToIndex, removeByProperty, dispatch, getQueryParameters } from 'c/utilTemplateBuilder';

const FORMAT_VERSION = '1.0';

export default class geTemplateBuilder extends NavigationMixin(LightningElement) {

    /*******************************************************************************
    * @description Enums used for navigating and flagging active lightning-tabs.
    */
    TabEnums = Object.freeze({
        INFO_TAB: 'geTemplateBuilderTemplateInfo',
        SELECT_FIELDS_TAB: 'geTemplateBuilderSelectFields',
        BATCH_HEADER_TAB: 'geTemplateBuilderBatchHeader'
    })

    recordId;
    @track isLoading = true;
    @track activeTab = this.TabEnums.INFO_TAB;
    @track formTemplate = new FormTemplate();
    @track batchHeaderFields = [];
    @track formSections = [];
    @track activeFormSectionId;
    formLayout = new FormLayout();

    get inTemplateInfoTab() {
        return this.activeTab === this.TabEnums.INFO_TAB ? true : false;
    }

    get inBatchHeaderTab() {
        return this.activeTab === this.TabEnums.BATCH_HEADER_TAB ? true : false;
    }

    get inSelectFieldsTab() {
        return this.activeTab === this.TabEnums.SELECT_FIELDS_TAB ? true : false;
    }

    connectedCallback() {
        this.recordId = getQueryParameters().c__recordId;

        if (this.recordId) {
            retrieveFormTemplate({ templateId: this.recordId })
                .then(formTemplate => {
                    this.formTemplate = formTemplate;
                    this.batchHeaderFields = formTemplate.batchHeaderFields;
                    this.formLayout = formTemplate.layout;
                    this.formSections = this.formLayout.sections;
                    this.isLoading = false;
                })
                .catch(error => {
                    console.log('Error: ', error);
                })
        } else {
            this.isLoading = false;
        }
    }

    /*******************************************************************************
    * @description Handles the onactive event on a lightning-tab element. Sets the
    * activeTab property based on the lightning-tab element's value.
    *
    * @param {object} event: Event received from the lightning-tab element.
    */
    handleOnActiveTab(event) {
        const tabValue = event.target.value;

        switch (tabValue) {
            case this.TabEnums.INFO_TAB:
                this.activeTab = this.TabEnums.INFO_TAB;
                break;
            case this.TabEnums.BATCH_HEADER_TAB:
                this.activeTab = this.TabEnums.BATCH_HEADER_TAB;
                break;
            case this.TabEnums.SELECT_FIELDS_TAB:
                this.activeTab = this.TabEnums.SELECT_FIELDS_TAB;
                break;
            default:
                this.activeTab = this.TabEnums.INFO_Tab;
        }
    }

    /*******************************************************************************
    * @description Public method for receiving modal related events. Used in the
    * utilModal, GE_modalProxy, GE_TemplateBuilder component's event chain. Handles
    * the section save and section delete actions from the modal.
    *
    * @param {object} modalData: Event object containing the action and section
    * information.
    * component chain: utilModal -> GE_ModalProxy -> GE_TemplateBuilder -> here
    */
    @api
    notify(modalData) {
        if (modalData.action === 'save') {
            let formSections = mutable(this.formSections);
            let formSection = formSections.find((fs) => { return fs.id === modalData.section.id });

            formSection.label = modalData.section.label;
            this.formSections = formSections;
        }

        if (modalData.action === 'delete') {
            const selectFieldsComponent = this.template.querySelector('c-ge-template-builder-select-fields');
            selectFieldsComponent.handleDeleteFormSection({ detail: modalData.section.id });
        }
    }

    /*******************************************************************************
    * @description Dispatches an event notifying the parent component GE_TemplateBuilder
    * to open a modal.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormSection -> geTemplateBuilderSelectFields -> here
    */
    toggleModal(event) {
        dispatch(this, 'togglemodal', event.detail);
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to set the
    * template name.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderTemplateInfo -> here
    */
    handleChangeTemplateInfoName(event) {
        const name = event.detail;
        this.formTemplate.name = name;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to set the
    * template description.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderTemplateInfo -> here
    */
    handleChangeTemplateInfoDescription(event) {
        const description = event.detail;
        this.formTemplate.description = description;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to add a new
    * field to batch headers.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderbatchHeader -> here
    */
    handleAddBatchHeaderField(event) {
        let batchHeaderField = event.detail;
        this.batchHeaderFields = [...this.batchHeaderFields, batchHeaderField];
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to update the
    * details on a batch header field.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderbatchHeader -> here
    */
    handleUpdateBatchHeaderField(event) {
        const detail = event.detail;

        let batchHeaderField = this.batchHeaderFields.find((bf) => {
            return bf.value === detail.fieldName
        });

        if (batchHeaderField) {
            batchHeaderField[detail.property] = detail.value;
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to move a batch
    * header field up.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderbatchHeader -> here
    */
    handleBatchHeaderFieldUp(event) {
        const fieldName = event.detail;

        let index = findIndexByProperty(this.batchHeaderFields, 'value', fieldName);
        if (index > 0) {
            this.batchHeaderFields =
                shiftToIndex(this.batchHeaderFields, index, index - 1);
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to move a batch
    * header field down.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderbatchHeader -> here
    */
    handleBatchHeaderFieldDown(event) {
        const fieldName = event.detail;

        let index = findIndexByProperty(this.batchHeaderFields, 'value', fieldName);
        if (index < this.batchHeaderFields.length - 1) {
            this.batchHeaderFields =
                shiftToIndex(this.batchHeaderFields, index, index + 1);
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to remove a batch
    * header field.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderbatchHeader -> here
    * OR
    * geTemplateBuilderbatchHeader -> here
    */
    handleRemoveBatchHeaderField(event) {
        const batchHeaderFieldIndex = event.detail;
        this.batchHeaderFields.splice(batchHeaderFieldIndex, 1);
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to set the
    * form sections property. Used only for actions related to deleting a section.
    * Event is dispatched from geTemplateBuilderSelectFields.handleDeleteFormSection()
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderSelectFields -> here
    */
    handleRefreshFormSections(event) {
        const formSections = event.detail;
        this.formSections = formSections;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to set the
    * currently active section based on id.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormSection -> geTemplateBuilderSelectFields -> here
    */
    handleChangeActiveSection(event) {
        const sectionId = event.detail;
        this.activeFormSectionId = sectionId;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to add a new
    * form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderSelectFields -> here
    */
    handleAddFormSection(event) {
        let formSection = event.detail;
        this.formSections = [...this.formSections, formSection];
        this.activeFormSectionId = event.detail.id;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to move a form
    * section up.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormSection -> geTemplateBuilderSelectFields -> here
    */
    handleFormSectionUp(event) {
        const sectionId = event.detail;

        let index = findIndexByProperty(this.formSections, 'id', sectionId);
        if (index > 0) {
            this.formSections = shiftToIndex(this.formSections, index, index - 1);
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to move a form
    * section down.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormSection -> geTemplateBuilderSelectFields -> here
    */
    handleFormSectionDown(event) {
        const sectionId = event.detail;

        let index = findIndexByProperty(this.formSections, 'id', sectionId);
        if (index < this.formSections.length - 1) {
            this.formSections = shiftToIndex(this.formSections, index, index + 1);
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to add a form
    * field to a form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderSelectFields -> here
    */
    handleAddFieldToSection(event) {
        const sectionId = event.detail.sectionId;
        let field = event.detail.field;
        let formSections = mutable(this.formSections);

        let formSection = formSections.find(fs => fs.id === sectionId);

        if (formSection) {
            field.sectionId = sectionId;
            formSection.elements.push(field);
        }

        this.formSections = formSections;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to remove a form
    * field from a form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection ->
    * geTemplateBuilderSelectFields -> here
    */
    handleRemoveFieldFromSection(event) {
        const { sectionId, fieldName } = event.detail;

        let formSections = mutable(this.formSections);
        let section = formSections.find(fs => fs.id === sectionId);
        removeByProperty(section.elements, 'value', fieldName);

        this.formSections = formSections;
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to move a form
    * field up within its parent form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection ->
    * geTemplateBuilderSelectFields -> here
    */
    handleFormFieldUp(event) {
        const { sectionId, fieldName } = event.detail;

        let section = this.formSections.find((fs) => { return fs.id === sectionId });
        let index = findIndexByProperty(section.elements, 'value', fieldName);

        if (index > 0) {
            section = shiftToIndex(section.elements, index, index - 1);
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to move a form
    * field down within its parent form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection ->
    * geTemplateBuilderSelectFields -> here
    */
    handleFormFieldDown(event) {
        const { sectionId, fieldName } = event.detail;

        let section = this.formSections.find((fs) => { return fs.id === sectionId });
        let index = findIndexByProperty(section.elements, 'value', fieldName);

        if (index < section.elements.length - 1) {
            section = shiftToIndex(section.elements, index, index + 1);
        }
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to remove a form
    * field from its parent form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection ->
    * geTemplateBuilderSelectFields -> here
    * OR
    * geTemplateBuilderSelectFields -> here
    */
    handleDeleteFormField(event) {
        const { sectionId, fieldName } = event.detail;

        let section = this.formSections.find((fs) => { return fs.id === sectionId });
        let index = findIndexByProperty(section.elements, 'value', fieldName);

        section.elements.splice(index, 1);
    }

    /*******************************************************************************
    * @description Receives and handles event from child component to update the
    * details of a form field within its parent form section.
    *
    * @param {object} event: Event received from child component.
    * component chain: geTemplateBuilderFormField -> geTemplateBuilderFormSection ->
    * geTemplateBuilderSelectFields -> here
    */
    handleUpdateFormField(event) {
        const { sectionId, fieldName, property, value } = event.detail;

        let section = this.formSections.find((fs) => { return fs.id === sectionId });
        let element = section.elements.find((e) => { return e.value === fieldName });

        if (element) {
            element[property] = value;
        }
    }

    /*******************************************************************************
    * @description Handles previous and next tab navigation
    *
    * @param {object} event: Event received from lightning-button.
    */
    handleGoToTab(event) {
        this.activeTab = event.target.getAttribute('data-tab-value');

        // TODO: Explore writing to global step on every tab change
        const tabInfo = this.template.querySelector('c-ge-template-builder-template-info').getTabData();
        if (tabInfo) {
            this.formTemplate.name = tabInfo.name;
            this.formTemplate.description = tabInfo.description;
        }

        const batchHeaderFields = this.template.querySelector('c-ge-template-builder-batch-header').getTabData();
        if (batchHeaderFields) {
            this.batchHeaderFields = batchHeaderFields;
        }

        const formLayout = this.template.querySelector('c-ge-template-builder-select-fields').getTabData();
        if (formLayout) {
            this.formTemplate.layout = formLayout;
        }
    }

    /*******************************************************************************
    * @description Method sets properties on the formTemplate object and passes the
    * FormTemplate JSON to apex and waits for a record id so we can navigate
    * to the newly inserted Form_Template__c record detail page.
    */
    handleFormTemplateSave = async () => {
        this.isLoading = true;
        this.formLayout.sections = this.formSections;
        this.formTemplate.batchHeaderFields = this.batchHeaderFields;
        this.formTemplate.layout = this.formLayout;

        const preppedFormTemplate = {
            id: this.recordId || null,
            templateJSON: JSON.stringify(this.formTemplate),
            name: this.formTemplate.name,
            description: this.formTemplate.description,
            formatVersion: FORMAT_VERSION
        };

        const formTemplateRecordId = await storeFormTemplate(preppedFormTemplate);

        //this.navigateToRecordViewPage(formTemplateRecordId);
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'npsp__GE_Templates'
            }
        });
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'npsp__GE_Templates'
            }
        });
    }

    /*******************************************************************************
    * @description Navigates to a record detail page by record id.
    */
    navigateToRecordViewPage(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    /* TODO: Needs to be revisited, WIP tied to retrieving and rendering an existing template */
    getFormTemplate() {
        const templateId = this.template.querySelector('lightning-input[data-name="templateId"]').value;
        retrieveFormTemplate({ templateId: templateId })
            .then(formTemplate => {
                this.formTemplate = formTemplate;
                this.batchHeaderFields = formTemplate.batchHeaderFields;
                this.formLayout = formTemplate.layout;
                this.formSections = this.formLayout.sections;
            })
            .catch(error => {
                console.log('Error: ', error);
            })
    }
}