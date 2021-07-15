import { LightningElement, api } from 'lwc';
import { apiNameFor } from 'c/utilCommon';
import GeLabelService from 'c/geLabelService';

import OCR_ROLE_FIELD from '@salesforce/schema/OpportunityContactRole.Role';
import OCR_CONTACT_FIELD from '@salesforce/schema/OpportunityContactRole.ContactId';

export default class geTemplateBuilderWidget extends LightningElement {

    CUSTOM_LABELS = GeLabelService.CUSTOM_LABELS;

    @api title;
    @api body;
    @api developerName;

    get uiTitle() {
        return GeLabelService.format(this.CUSTOM_LABELS.geBodyWidgetFields, [this.title]);
    }

    get isAllocations() {
        return this.developerName === 'geFormWidgetAllocation';
    }

    get isSoftCredit() {
        return this.developerName === 'geFormWidgetSoftCredit';
    }

    get isTokenizeCard() {
        return this.developerName === 'geFormWidgetTokenizeCard';
    }

    get ocrRoleFieldApiName() {
        return apiNameFor(OCR_ROLE_FIELD);
    }

    get ocrContactFieldApiName() {
        return apiNameFor(OCR_CONTACT_FIELD);
    }
}