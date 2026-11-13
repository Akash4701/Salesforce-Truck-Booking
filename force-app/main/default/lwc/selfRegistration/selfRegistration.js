import { LightningElement } from 'lwc';
import registerUser from '@salesforce/apex/RoleSelfRegHandler.registerUser';

const ROLE_OPTIONS = [
    { label: 'Customer', value: 'Customer' },
    { label: 'Driver', value: 'Driver' }
];

export default class SelfRegistration extends LightningElement {
    selectedRole = '';
    isSubmitting = false;
    errorMessage = '';
    successMessage = '';

    get roleOptions() {
        return ROLE_OPTIONS;
    }

    get submitLabel() {
        return this.isSubmitting ? 'Creating account...' : 'Create account';
    }

    handleRoleChange(event) {
        this.selectedRole = event.detail.value;
        this.errorMessage = '';
    }

    async handleSubmit(event) {
        event.preventDefault();
        this.errorMessage = '';
        this.successMessage = '';

        const fields = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox')
        ];
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
            await registerUser({
                fullName: values.fullName,
                email: values.email,
                password: values.password,
                role: values.role
            });
            this.successMessage =
                'Your account has been created. You can now sign in.';
            this.template.querySelector('[name="password"]').value = '';
        } catch (error) {
            this.errorMessage =
                error.body && error.body.message
                    ? error.body.message
                    : 'We could not create your account. Please try again.';
        } finally {
            this.isSubmitting = false;
        }
    }
}