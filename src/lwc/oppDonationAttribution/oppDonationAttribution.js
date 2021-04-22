import { LightningElement, api, track, wire } from 'lwc';
import getHardCreditDonorsFor 
    from '@salesforce/apex/DonorService.getHardCreditDonorsFor';
import getSoftCreditDonorsFor 
    from '@salesforce/apex/DonorService.getSoftCreditDonorsFor';

export default class OppDonationAttribution extends LightningElement {

    @api recordId;
    
    @track donors = [];
    @track softCredits = []; 
    error;

    @wire(getHardCreditDonorsFor, { opportunityId: '$recordId' }) 
    wiredDonors({data, error}) {
        if (data) {
            for (let i = 0; i < data.length; i++) {
                this.donors.push(Object.assign({}, data[i], {selectable: false}));
            }
            
            this.donors.map(donor => {
                let iconName = 'standard:contact';
                if (donor.donorType === 'HOUSEHOLD') {
                    iconName = 'standard:household';
                } else if (donor.donorType === 'ORGANIZATION') {
                    iconName = 'standard:account';
                }

                donor.iconName = iconName;
            });

        } else if (error) {
            this.error = 'Unknown error';
            if (Array.isArray(error.body)) {
                this.error = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                this.error = error.body.message;
            }
        }
    };

    @wire(getSoftCreditDonorsFor, { opportunityId: '$recordId' }) 
    wiredSoftCredit({data, error}) {
        if (data) {
            for (let i = 0; i < data.length; i++) {
                this.softCredits.push(Object.assign({}, data[i], {selectable: false}));
            }
            
            this.softCredits.map(softCredit => {
                let iconName = 'standard:contact';
                if (softCredit.donorType === 'HOUSEHOLD') {
                    iconName = 'standard:household';
                } else if (softCredit.donorType === 'ORGANIZATION') {
                    iconName = 'standard:account';
                }

                softCredit.iconName = iconName;
            });            
            //this.softCredits = data;
        } else if (error) {
            this.error = 'Unknown error';
            if (Array.isArray(error.body)) {
                this.error = error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                this.error = error.body.message;
            }
        }
    };
}