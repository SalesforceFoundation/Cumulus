import { LightningElement, api, track } from 'lwc';
import { isNotEmpty } from 'c/utilCommon';

import GeLabelService from 'c/geLabelService';

export default class GeFormWidgetSoftCredit extends LightningElement {

    CUSTOM_LABELS = GeLabelService.CUSTOM_LABELS;

    @api gift;
    @api element;
    @track alertBanner = {};

    @track rowList = [];

    connectedCallback() {
        this.init();
    }

    init() {
        this.gift.softCredits.forEach(softCredit => {
            this.addRow(softCredit);
        });        
    };

    addRow(softCredit) {
        const record = { ...softCredit };
        let row = {};
        row.key = this.rowList.length;

        row = {
            ...row,
            record
        };
        this.rowList.push(row);
    }

    handleAddRow() {
        this.addRow();
    }

    handleRemove(event) {
        this.rowList.splice(event.detail.rowIndex, 1);
        // TODO fire event
    }

    reset() {
        // handle reset
    }

    validate() {
        // validate
    }

    get hasAlert() {
        return false;
    }

    get alertIcon() {
        if (isNotEmpty(this.alertBanner.level)) {
            const warningIcon = 'utility:warning';
            const errorIcon = 'utility:error';
            switch(this.alertBanner.level) {
                case 'error':
                    return errorIcon;
                case 'warning':
                    return warningIcon;
                default:
                    return errorIcon;
            }
        }
    }

    get alertClass() {
        if (isNotEmpty(this.alertBanner.level)) {
            const errorClass = 'error';
            const warningClass = 'warning';

            switch(this.alertBanner.level) {
                case errorClass:
                    return errorClass;
                case warningClass:
                    return warningClass;
                default:
                    return errorClass;
            }
        }
    }

    get qaLocatorAddNewSoftCredit() {
        return `button ${this.CUSTOM_LABELS.geAddNewAllocation}`;
    }
}