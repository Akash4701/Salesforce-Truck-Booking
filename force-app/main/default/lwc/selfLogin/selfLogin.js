import { LightningElement } from 'lwc';
import loginUser from '@salesforce/apex/RoleSelfRegHandler.loginUser';

export default class SelfLogin extends LightningElement {
    isSubmitting = false;
    errorMessage = '';

    get submitLabel() {
        return this.isSubmitting ? 'Signing in...' : 'Sign in';
    }

    async handleSubmit(event) {
        event.preventDefault();
        this.errorMessage = '';

        const fields = [...this.template.querySelectorAll('lightning-input')];
        const isValid = fields.reduce((valid, field) => {
            field.reportValidity();
            return field.checkValidity() && valid;
        }, true);

        if (!isValid || this.isSubmitting) {
            return;
        }

        const values = Object.fromEntries(
            fields.map((field) => [field.name, field.value])
        );
        this.isSubmitting = true;

        try {
            const redirectUrl = await loginUser({
                email: values.email,
                password: values.password
            });
            if (!redirectUrl) {
                this.errorMessage =
                    'We could not sign you in. Please check your credentials and try again.';
                return;
            }
            window.location.assign(redirectUrl);
        } catch (error) {
            this.errorMessage =
                error.body && error.body.message
                    ? error.body.message
                    : 'We could not sign you in. Please check your credentials and try again.';
        } finally {
            this.isSubmitting = false;
        }
    }
}
