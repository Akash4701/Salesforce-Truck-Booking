import { createElement } from '@lwc/engine-dom';
import SelfRegistration from 'c/selfRegistration';

describe('c-self-registration', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders all required registration fields and role choices', () => {
        const element = createElement('c-self-registration', {
            is: SelfRegistration
        });

        document.body.appendChild(element);

        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        const role = element.shadowRoot.querySelector('lightning-combobox');

        expect(inputs).toHaveLength(3);
        expect([...inputs].map((input) => input.name)).toEqual([
            'fullName',
            'email',
            'password'
        ]);
        expect([...inputs].every((input) => input.required)).toBe(true);
        expect(role.name).toBe('role');
        expect(role.required).toBe(true);
        expect(role.options).toEqual([
            { label: 'Customer', value: 'Customer' },
            { label: 'Driver', value: 'Driver' }
        ]);
    });
});