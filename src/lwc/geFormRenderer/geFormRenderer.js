import {LightningElement, api, track} from 'lwc';
import GeFormService from 'c/geFormService';
import { NavigationMixin } from 'lightning/navigation';
import messageLoading from '@salesforce/label/c.labelMessageLoading';

export default class GeFormRenderer extends NavigationMixin(LightningElement) {
    @track sections = [];
    @track ready = false;
    @track name = '';
    @track description = '';
    @track mappingSet = '';
    @track version = '';
    @api showSpinner = false;
    @api isBatchMode = false;
    @api submissions = [];

    connectedCallback() {
        GeFormService.getFormTemplate().then(response => {
            // read the template header info
            if(response !== null && typeof response !== 'undefined') {
                const { formTemplate } = response;
                this.ready = true;
                this.name = formTemplate.name;
                this.description = formTemplate.description;
                this.version = formTemplate.layout.version;

                if (typeof formTemplate.layout !== 'undefined'
                        && Array.isArray(formTemplate.layout.sections)) {
                    this.sections = formTemplate.layout.sections;
                }
            }

        });
    }

    handleCancel() {
        console.log('Form Cancel button clicked');
    }

    handleSave() {
        console.log('Form Save button clicked');

        // show the spinner
        this.toggleSpinner();

        // TODO: Pass the actual Data Import record, and navigate to the new Opportunity
        // const OpportunityId = GeFormService.createOpportunityFromDataImport(dataImport);
        const sectionsList = this.template.querySelectorAll('c-ge-form-section');

        if (this.isBatchMode) {
            this.submissions = [...this.submissions, sectionsList];
            this.dispatchEvent(new CustomEvent('submit'));
            this.toggleSpinner();
        } else {
            GeFormService.handleSave(sectionsList).then(opportunityId => {
                this.navigateToRecordPage(opportunityId);
            });
        }
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

    // change showSpinner to the opposite of its current value
    toggleSpinner() {
        this.showSpinner = !this.showSpinner;
    }

    // Expose the labels to use in the template
    label = { messageLoading };
}