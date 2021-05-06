import {createElement} from 'lwc';
import Rd2EntryForm from 'c/rd2EntryForm';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import { mockGetIframeReply } from "c/psElevateTokenHandler";

import getRecurringSettings from '@salesforce/apex/RD2_EntryFormController.getRecurringSettings';
import getRecurringData from '@salesforce/apex/RD2_EntryFormController.getRecurringData';
import hasRequiredFieldPermissions from '@salesforce/apex/RD2_EntryFormController.hasRequiredFieldPermissions';

import RD2_EntryFormMissingPermissions from '@salesforce/label/c.RD2_EntryFormMissingPermissions';
import FIELD_INSTALLMENT_PERIOD from '@salesforce/schema/npe03__Recurring_Donation__c.npe03__Installment_Period__c';
import FIELD_DAY_OF_MONTH from '@salesforce/schema/npe03__Recurring_Donation__c.Day_of_Month__c';
import RECURRING_DONATION_OBJECT from '@salesforce/schema/npe03__Recurring_Donation__c';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import CONTACT_OBJECT from '@salesforce/schema/Contact';


const recurringSettingsResponse = require('./data/getRecurringSettings.json');
const recurringDonationObjectInfo = require('./data/recurringDonationObjectInfo.json');
const installmentPeriodPicklistValues = require('./data/installmentPeriodPicklistValues.json');
const dayOfMonthPicklistValues = require('./data/dayOfMonthPicklistValues.json');
const contactPartialDescribe = require('./data/contactPartialDescribe.json');
const accountPartialDescribe = require('./data/accountPartialDescribe.json');
const contactGetRecord = require('./data/contactGetRecord.json');
const accountGetRecord = require('./data/accountGetRecord.json');
const rd2WithCardCommitment = require('./data/rd2WithCardCommitment.json');
const rd2WithACHCommitment = require('./data/rd2WithACHCommitment.json');
const rd2WithoutCommitmentCard = require('./data/rd2WithoutCommitmentCard.json');
const recurringDataContactResponse = require('./data/recurringDataContactResponse.json');

const mockScrollIntoView = jest.fn();

const FAKE_ACH_RD2_ID = 'a0963000008pebAAAQ';
const FAKE_CARD_RD2_ID = 'a0963000008oxZnAAI';

const EXPECTED_BUSINESS_ACH_PARAMS = {
    nameOnAccount: "Donor Organization",
    accountHolder: {
        type: "BUSINESS",
        businessName: "Anthropy",
        accountName: "Donor Organization",
        bankType: "CHECKING"
    },
    achCode: 'WEB'
};

const EXPECTED_INDIVIDUAL_ACH_PARAMS = {
    nameOnAccount: "John Smith",
    accountHolder: {
        type: "INDIVIDUAL",
        firstName: "John",
        lastName: "Smith",
        bankType: "CHECKING"
    },
    achCode: 'WEB'
};

jest.mock('@salesforce/apex/RD2_EntryFormController.getRecurringSettings',
    () => {
        return { default: jest.fn() }
    },
    { virtual: true }
);

jest.mock('@salesforce/apex/RD2_EntryFormController.hasRequiredFieldPermissions',
    () => {
        return { default: jest.fn() }
    },
    { virtual: true }
);

jest.mock('@salesforce/apex/RD2_EntryFormController.getRecurringData',
    () => {
        return { default: jest.fn() }
    },
    { virtual: true }
);


describe('c-rd2-entry-form', () => {

    beforeEach(() => {
        getRecurringSettings.mockResolvedValue(recurringSettingsResponse);
        hasRequiredFieldPermissions.mockResolvedValue(true);
        window.HTMLElement.prototype.scrollIntoView = mockScrollIntoView;
    });

    afterEach(() => {
        clearDOM();
        jest.clearAllMocks();
    });

    describe('creating new records', () => {
        it('displays an error when user does not have required permissions', async () => {
            hasRequiredFieldPermissions.mockResolvedValue(false);
            const element = createRd2EntryForm();
            const controller = new RD2FormController(element);

            await flushPromises();

            expect(mockScrollIntoView).toHaveBeenCalledTimes(1);

            const saveButton = controller.saveButton();
            expect(saveButton.disabled).toBe(true);

            const formattedText = element.shadowRoot.querySelector('lightning-formatted-text');
            expect(formattedText.value).toBe(RD2_EntryFormMissingPermissions);
        });

        it('elevate customer selects Credit Card payment method then widget displayed', async () => {
            const element = createRd2EntryForm();
            const controller = new RD2FormController(element);

            await flushPromises();

            await setupWireMocksForElevate();
            controller.setDefaultInputFieldValues();

            controller.paymentMethod().changeValue('Credit Card');

            await flushPromises();

            const elevateWidget = controller.elevateWidget();
            expect(elevateWidget).toBeTruthy();

        });

        it('elevate customer selects ACH payment method then widget displayed', async () => {
            const element = createRd2EntryForm();
            const controller = new RD2FormController(element);
            await flushPromises();

            await setupWireMocksForElevate();
            controller.setDefaultInputFieldValues();

            controller.paymentMethod().changeValue('ACH');

            await flushPromises();

            const elevateWidget = controller.elevateWidget();
            expect(elevateWidget).toBeTruthy();
        });
    });

    describe('tokenization', () => {

        beforeEach(() => {
            setupIframeReply();
        });

        it('individual donor, contact name is used for account holder name when tokenizing an ACH payment', async () => {
            const element = createRd2EntryForm();
            const controller = new RD2FormController(element);

            await flushPromises();

            await setupWireMocksForElevate();

            controller.setDefaultInputFieldValues();
            controller.contactLookup().changeValue('001fakeContactId');
            await flushPromises();

            getRecord.emit(contactGetRecord, config => {
                return config.recordId === '001fakeContactId';
            });

            controller.amount().changeValue(1.00);
            controller.paymentMethod().changeValue('ACH');

            await flushPromises();

            const elevateWidget = controller.elevateWidget();
            expect(elevateWidget).toBeTruthy();
            expect(elevateWidget.payerFirstName).toBe('John');
            expect(elevateWidget.payerLastName).toBe('Smith');

            controller.saveButton().click();

            await flushPromises();
            validateIframeMessage(mockGetIframeReply.mock.calls[0], EXPECTED_INDIVIDUAL_ACH_PARAMS);
        });

        it('organization donor, account name is used when tokenizing an ACH payment', async () => {

            const element = createRd2EntryForm();
            const controller = new RD2FormController(element);

            await flushPromises();

            await setupWireMocksForElevate();

            controller.setDefaultInputFieldValues();
            controller.donorType().changeValue('Account');
            controller.paymentMethod().changeValue('ACH');
            await flushPromises();


            controller.accountLookup().changeValue('001fakeAccountId');
            await flushPromises();

            getRecord.emit(accountGetRecord, config => {
                return config.recordId === '001fakeAccountId';
            });
            await flushPromises();
            controller.amount().changeValue(1.00);

            await flushPromises();

            const elevateWidget = controller.elevateWidget();
            expect(elevateWidget).toBeTruthy();
            expect(elevateWidget.payerOrganizationName).toBe("Donor Organization");

            controller.saveButton().click();

            await flushPromises();

            expect(mockGetIframeReply).toHaveBeenCalled();

            validateIframeMessage(mockGetIframeReply.mock.calls[0], EXPECTED_BUSINESS_ACH_PARAMS);
        });
    });

    describe('edit mode', () => {

        beforeEach(() => {
            getRecurringData.mockResolvedValue(recurringDataContactResponse);
        })

        it('rd2 record with card payment, when editing, displays card information', async () => {

            const element = createRd2EditForm(FAKE_CARD_RD2_ID);
            const controller = new RD2FormController(element);
            await flushPromises();

            getRecord.emit(rd2WithCardCommitment, config => {
                return config.recordId === FAKE_CARD_RD2_ID;
            });

            await setupWireMocksForElevate();
            const elevateWidget = controller.elevateWidget();
            expect(elevateWidget).toBeTruthy();

            expect(controller.last4().value).toBe('1212');
            expect(controller.cardExpriation().value).toBe('02/2023');

        });


        it('rd2 record with ACH payment, when editing, displays ACH last 4', async () => {

            const element = createRd2EditForm(FAKE_ACH_RD2_ID);
            const controller = new RD2FormController(element);
            await flushPromises();

            getRecord.emit(rd2WithACHCommitment, config => {
                return config.recordId === FAKE_ACH_RD2_ID;
            });

            await setupWireMocksForElevate();

            const elevateWidget = controller.elevateWidget();
            expect(elevateWidget).toBeTruthy();
            expect(controller.last4().value).toBe('1111');

        });


        it('rd2 record with credit card payment type but no commitment, when editing, displays widget', async () => {
            const element = createRd2EditForm(FAKE_CARD_RD2_ID);
            const controller = new RD2FormController(element);
            await flushPromises();

            getRecord.emit(rd2WithoutCommitmentCard, config => {
                return config.recordId === FAKE_CARD_RD2_ID;
            });

            await flushPromises();

            getRecord.emit(contactGetRecord, config => {
                return config.recordId === '001fakeContactId';
            });

            await setupWireMocksForElevate();

            expect(controller.elevateWidget()).toBeTruthy();

        });

        it('rd2 record with check payment type, when editing and payment type changed to credit card, displays widget', async () => {
            const element = createRd2EditForm(FAKE_CARD_RD2_ID);
            const controller = new RD2FormController(element);
            await flushPromises();

            const rd2WithoutCommitmentCheck = generateMockFrom(rd2WithoutCommitmentCard)
                .withFieldValue('PaymentMethod__c', 'Check');

            getRecord.emit(rd2WithoutCommitmentCheck, config => {
                return config.recordId === FAKE_CARD_RD2_ID;
            });

            await flushPromises();

            getRecord.emit(contactGetRecord, config => {
                return config.recordId === '001fakeContactId';
            });

            await setupWireMocksForElevate();
            controller.setDefaultInputFieldValues();

            expect(controller.elevateWidget()).toBeNull();

            controller.paymentMethod().changeValue('Credit Card');

            await flushPromises();

            expect(controller.elevateWidget()).toBeTruthy();
        });

        it('rd2 record, when editing, uses existing contact information in tokenization', async () => {
            setupIframeReply();

            const element = createRd2EditForm(FAKE_CARD_RD2_ID);
            const controller = new RD2FormController(element);
            await flushPromises();

            getRecord.emit(rd2WithoutCommitmentCard, config => {
                return config.recordId === FAKE_CARD_RD2_ID;
            });

            await flushPromises();

            getRecord.emit(contactGetRecord, config => {
                return config.recordId === '001fakeContactId';
            });

            await setupWireMocksForElevate();
            controller.setDefaultInputFieldValuesEdit();

            controller.paymentMethod().changeValue('ACH');

            await flushPromises();

            expect(controller.elevateWidget()).toBeTruthy();

            controller.saveButton().click();

            await flushPromises();

            expect(mockGetIframeReply).toHaveBeenCalled();
            expect(mockGetIframeReply).toHaveBeenCalledTimes(2);
            validateIframeMessage(mockGetIframeReply.mock.calls[1], EXPECTED_INDIVIDUAL_ACH_PARAMS);
        })

    })
});

const createRd2EntryForm = () => {
    const element = createElement('c-rd2-entry-form', {is: Rd2EntryForm});
    document.body.appendChild(element);
    return element;
}

const createRd2EditForm = (recordId) => {
    const element = createElement('c-rd2-entry-form', {is: Rd2EntryForm});
    element.recordId = recordId;
    document.body.appendChild(element);
    return element;
}

const generateMockFrom = (recordMock) => {
    return {
        withFieldValue: (field, value) => {
            return {
                ...recordMock,
                fields: {
                    ...recordMock.fields,
                    [field]: { value }
                }
            }
        }
    }
}

const setupIframeReply = () => {
    mockGetIframeReply.mockImplementation((iframe, message, targetOrigin) => {
        const type = "post__npsp";
        const token = "a_dummy_token";
        // if message action is "createToken", reply with dummy token immediately
        // instead of trying to hook into postMessage
        // see sendIframeMessage in mocked psElevateTokenHandler
        if (message.action === 'createToken' || message.action === 'createAchToken') {
            return { type, token };
        }

        if (message.action === 'setPaymentMethod') {
            return { type };
        }
    });
}

const validateIframeMessage = (tokenizeMockCall, expectedParams) => {

    expect(mockGetIframeReply).toHaveBeenCalled();
    const tokenizeMessage = tokenizeMockCall[1];
    const serializedParams = tokenizeMessage.params;
    const deserializedParams = JSON.parse(serializedParams);
    expect(deserializedParams).toMatchObject(expectedParams);

    expect(mockGetIframeReply).toHaveBeenCalledWith(
        expect.any(HTMLIFrameElement), // iframe
        expect.objectContaining({
            action: "createAchToken",
            params: expect.any(String)
        }),
        undefined
    );
}

const setupWireMocksForElevate = async () => {
    getObjectInfo.emit(recurringDonationObjectInfo, config => {
        return config.objectApiName === RECURRING_DONATION_OBJECT.objectApiName;
    });

    getObjectInfo.emit(contactPartialDescribe, config => {
        return config.objectApiName.objectApiName === CONTACT_OBJECT.objectApiName;
    });

    getObjectInfo.emit(accountPartialDescribe, config => {
        return config.objectApiName.objectApiName === ACCOUNT_OBJECT.objectApiName;
    });

    getPicklistValues.emit(installmentPeriodPicklistValues, config => {
        return config.fieldApiName.fieldApiName === FIELD_INSTALLMENT_PERIOD.fieldApiName;
    });

    getPicklistValues.emit(dayOfMonthPicklistValues, config => {
        return config.fieldApiName.fieldApiName === FIELD_DAY_OF_MONTH.fieldApiName;
    });

    await flushPromises();
}


class RD2FormController {
    element;

    constructor(element) {
        this.element = element;
    }

    setDefaultInputFieldValues() {
        this.recurringType().changeValue('Open');
        this.dateEstablished().changeValue('2021-02-03');
        this.startDate().changeValue('2021-02-03');
    }

    setDefaultInputFieldValuesEdit() {
        this.setDefaultInputFieldValues();
        this.status().setValue('Active');
        this.amount().setValue(0.50);
        this.dayOfMonth().setValue('5');
        this.contactLookup().setValue('001fakeContactId');
    }

    donorSection() {
        return this.element.shadowRoot.querySelector('c-rd2-entry-form-donor-section');
    }

    scheduleSection() {
        return this.element.shadowRoot.querySelector('c-rd2-entry-form-schedule-section');
    }

    elevateWidget() {
        return this.element.shadowRoot.querySelector('c-rd2-elevate-credit-card-form');
    }

    amount() {
        const field = this.element.shadowRoot.querySelector('lightning-input-field[data-id="amountField"]');
        return new RD2FormField(field);
    }

    dateEstablished() {
        const donorSection = this.donorSection();
        const field = donorSection.shadowRoot.querySelector('lightning-input-field[data-id="dateEstablished"]');
        return new RD2FormField(field);
    }

    donorType() {
        const donorSection = this.donorSection();
        const field = donorSection.shadowRoot.querySelector('lightning-combobox[data-id="donorType"]');
        return new RD2FormField(field);
    }

    contactLookup() {
        const donorSection = this.donorSection();
        const field = donorSection.shadowRoot.querySelector('lightning-input-field[data-id="contactLookup"]');
        return new RD2FormField(field);
    }

    accountLookup() {
        const donorSection = this.donorSection();
        const field = donorSection.shadowRoot.querySelector('lightning-input-field[data-id="accountLookup"]');
        return new RD2FormField(field);
    }

    paymentMethod() {
        const field = this.element.shadowRoot.querySelector('lightning-input-field[data-id="paymentMethod"]');
        return new RD2FormField(field);
    }

    last4() {
        const widget = this.elevateWidget();
        return widget.shadowRoot.querySelector('lightning-formatted-text[data-qa-locator="text Last Four Digits"]');
    }

    cardExpriation() {
        const widget = this.elevateWidget();
        return widget.shadowRoot.querySelector('lightning-formatted-text[data-qa-locator="text Expiration Date"]');
    }

    dayOfMonth() {
        const scheduleSection = this.scheduleSection();
        const field = scheduleSection.shadowRoot.querySelector('lightning-input-field[data-id="dayOfMonth"]');
        return new RD2FormField(field);
    }

    recurringType() {
        const scheduleSection = this.scheduleSection();
        const field = scheduleSection.shadowRoot.querySelector('lightning-input-field[data-id="RecurringType__c"]');
        return new RD2FormField(field);
    }

    startDate() {
        const scheduleSection = this.scheduleSection();
        const field = scheduleSection.shadowRoot.querySelector('lightning-input-field[data-id="startDate"]');
        return new RD2FormField(field);
    }

    status() {
        const field = this.element.shadowRoot.querySelector('lightning-input-field[data-id="status"]');
        return new RD2FormField(field);
    }

    cardholderName() {
        const field = this.elevateWidget().shadowRoot.querySelector('[data-id="cardholderName"]');
        return new RD2FormField(field);
    }

    saveButton() {
        return this.element.shadowRoot.querySelector('lightning-button[data-id="submitButton"]');
    }

}

class RD2FormField {

    constructor(element) {
        this.element = element;
    }

    setValue(value) {
        this.element.value = value;
    }

    changeValue(value) {
        this.setValue(value);
        this.dispatchChangeEvent();
    }

    dispatchChangeEvent() {
        const { value } = this.element;
        this.element.dispatchEvent(new CustomEvent('change', { detail: { value } }));
    }
}