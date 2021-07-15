import { LightningElement, api } from 'lwc';
import GeLabelService from 'c/geLabelService';
import { apiNameFor, isNotEmpty } from 'c/utilCommon';

import OPP_CONTACT_ROLE_OBJECT from '@salesforce/schema/OpportunityContactRole';
import ROLE_FIELD from '@salesforce/schema/OpportunityContactRole.Role';
import CONTACT_FIELD from '@salesforce/schema/OpportunityContactRole.ContactId';
import OPPORTUNITY_FIELD from '@salesforce/schema/OpportunityContactRole.OpportunityId';

export default class GeFormWidgetRowAllocation extends LightningElement {
    @api rowIndex;
    @api row;

    CUSTOM_LABELS = GeLabelService.CUSTOM_LABELS;

    handleFieldValueChange = (event) => {
        // do stuff
    }

    remove() {
        const { rowIndex, row } = this;
        this.dispatchEvent(new CustomEvent('remove', { detail: { rowIndex, row } }));
    }

    hasIdField() {
        return isNotEmpty(this.row.record.Id);
    }

    get isReadOnly() {
        return this.hasIdField();
    }

    get isRemovable() {
        return !this.hasIdField();
    }

    get softCreditObjectApiName() {
        return apiNameFor(OPP_CONTACT_ROLE_OBJECT);
    }

    get roleFieldApiName() {
        return apiNameFor(ROLE_FIELD);
    }

    get roleValue() {
        return this.row.record[apiNameFor(ROLE_FIELD)];
    }

    get contactFieldApiName() {
        return apiNameFor(CONTACT_FIELD);
    }

    get contactValue() {
        return this.row.record[apiNameFor(CONTACT_FIELD)];
    }

    get qaLocatorDeleteRow() {
        return `button ${this.CUSTOM_LABELS.commonDelete} ${this.rowIndex}`;
    }

    get qaLocatorSoftCreditContact() {
        return `autocomplete contact for Soft Credit ${this.rowIndex}`;
    }

    get qaLocatorSoftCreditRole() {
        return `input role for Soft Credit ${this.rowIndex}`;
    }
}
