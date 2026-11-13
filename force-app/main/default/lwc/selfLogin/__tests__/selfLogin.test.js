import { createElement } from '@lwc/engine-dom';
import SelfLogin from 'c/selfLogin';

describe('c-self-login', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders required email and password fields', () => {
        const element = createElement('c-self-login', {
            is: SelfLogin
        });

        document.body.appendChild(element);

        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        expect([...inputs].map((input) => input.name)).toEqual([
            'email',
            'password'
        ]);
        expect([...inputs].every((input) => input.required)).toBe(true);
    });
});
