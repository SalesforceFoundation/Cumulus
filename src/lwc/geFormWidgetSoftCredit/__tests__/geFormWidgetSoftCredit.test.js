import { createElement } from 'lwc';
import GeFormWidgetSoftCredit from 'c/geFormWidgetSoftCredit';

describe('c-form-widget-soft-credit', () => {
    afterEach(() => {
        clearDOM();
    });

    function flushPromises() {
        return new Promise((resolve) => setImmediate(resolve));
    }

    const setup = () => {
        const element = createElement('c-form-widget-soft-credit', {
            is: GeFormWidgetSoftCredit
        });
        let aGift = {
            softCredits: [
                {
                    Role: 'Influencer',
                    ContactId: '1',
                    Id: '1'
                },
                {
                    Role: 'Honoree',
                    ContactId: '2'
                }
            ]
        };
        element.gift = aGift;
        document.body.appendChild(element);
        return element;
    }

    describe('component render', () => {
        it('renders the title', async () => {
            const element = setup();

            await flushPromises();

            const headerElement = element.shadowRoot.querySelector('h2');
            const text = headerElement.innerHTML;
            expect(text).toBe('c.commonSoftCredits');
        });
        
        it('renders the soft credit rows', async () => {
            const element = setup();

            await flushPromises();

            const rowElements = shadowSelectorAll(element, 'c-ge-form-widget-soft-credit-row');
            expect(rowElements.length).toBe(2);
        });  
    });

    const shadowSelectorAll = (element, selector) => {
        return element.shadowRoot.querySelectorAll(selector);
    }
});