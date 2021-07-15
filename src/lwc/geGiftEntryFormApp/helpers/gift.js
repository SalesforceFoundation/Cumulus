import getDummySoftCredits from '@salesforce/apex/GE_GiftEntryController.getDummySoftCredits';
import { isNotEmpty } from 'c/utilCommon';

class Gift {
    softCredits = [];    

    async init() {
        const softCreditOppContactRoles = await getDummySoftCredits();
        
        if (isNotEmpty(softCreditOppContactRoles)) {
            softCreditOppContactRoles.forEach( (oppContactRole, index) => {
                let softCredit = { ...oppContactRole };
                softCredit.Id = index;
                this.softCredits.push( softCredit );
            });
        }
    }
}

export default Gift;