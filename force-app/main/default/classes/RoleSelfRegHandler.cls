global without sharing class RoleSelfRegHandler implements Auth.ConfigurableSelfRegHandler {
    global Id createUser(
        Id accountId,
        Id profileId,
        Map<SObjectField, String> registrationAttributes,
        String password
    ) {
        Map<String, String> userAttributes = new Map<String, String>();

        for (SObjectField field : registrationAttributes.keySet()) {
            String fieldName = field.getDescribe().getName().toLowerCase();
            if (
                fieldName == 'firstname' ||
                fieldName == 'lastname' ||
                fieldName == 'email' ||
                fieldName == 'role_selection__c'
            ) {
                userAttributes.put(fieldName, registrationAttributes.get(field));
            }
        }

        User userRecord = buildUser(
            userAttributes.get('firstname'),
            userAttributes.get('lastname'),
            userAttributes.get('email'),
            userAttributes.get('role_selection__c'),
            profileId
        );

        return createExternalUser(
            userRecord,
            getSharedAccountId(),
            password
        );
    }

    @AuraEnabled
    global static void registerUser(
        String fullName,
        String email,
        String password,
        String role
    ) {
        if (String.isBlank(fullName) || fullName.trim().length() > 80) {
            throw new AuraHandledException('Enter a valid name (up to 80 characters).');
        }
        validatePassword(password);

        List<String> nameParts = fullName.trim().split('\\s+');
        Integer lastNameIndex = nameParts.size() - 1;
        String lastName = nameParts[lastNameIndex];
        List<String> firstNameParts = new List<String>();
        for (Integer index = 0; index < lastNameIndex; index++) {
            firstNameParts.add(nameParts[index]);
        }

        String firstName = String.join(firstNameParts, ' ');
        Id profileId = getRegistrationProfileId();
        User userRecord = buildUser(
            firstName,
            lastName,
            email,
            role,
            profileId
        );

        createExternalUser(userRecord, getSharedAccountId(), password);
    }

    @AuraEnabled
    global static String loginUser(String email, String password) {
        if (String.isBlank(email) || String.isBlank(password)) {
            throw new AuraHandledException('Enter your email and password.');
        }

        String pathPrefix = Site.getPathPrefix();
        String startUrl = String.isBlank(pathPrefix)
            ? '/'
            : pathPrefix + '/s/';
        PageReference loginPage = Site.login(
            email.trim(),
            password,
            startUrl
        );
        if (loginPage == null) {
            throw new AuraHandledException('Email or password is incorrect.');
        }

        return loginPage.getUrl();
    }

    private static User buildUser(
        String firstName,
        String lastName,
        String email,
        String role,
        Id profileId
    ) {
        if (String.isBlank(lastName) || lastName.trim().length() > 80) {
            throw new AuraHandledException('Enter a valid name.');
        }
        if (!String.isBlank(firstName) && firstName.trim().length() > 40) {
            throw new AuraHandledException('The first name cannot exceed 40 characters.');
        }
        if (
            String.isBlank(email) ||
            email.trim().length() > 80 ||
            !email.trim().contains('@') ||
            email.trim().contains(' ')
        ) {
            throw new AuraHandledException('Enter a valid email address.');
        }
        if (role != 'Customer' && role != 'Driver') {
            throw new AuraHandledException('Select Customer or Driver as your role.');
        }
        if (profileId == null) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }

        String normalizedEmail = email.trim().toLowerCase();
        String safeFirstName = String.isBlank(firstName) ? null : firstName.trim();
        String safeLastName = lastName.trim();

        User userRecord = new User(
            FirstName = safeFirstName,
            LastName = safeLastName,
            Email = normalizedEmail,
            Username = normalizedEmail,
            ProfileId = profileId,
            Role_Selection__c = role,
            Alias = (
                (String.isBlank(safeFirstName) ? '' : safeFirstName.left(1)) +
                safeLastName
            ).left(8),
            CommunityNickname = buildCommunityNickname(normalizedEmail),
            LocaleSidKey = UserInfo.getLocale(),
            LanguageLocaleKey = UserInfo.getLanguage(),
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'Asia/Kolkata'
        );

        return userRecord;
    }

    private static String buildCommunityNickname(String email) {
        String nicknamePrefix = email.substringBefore('@').left(20);
        String suffix = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).left(8);
        return nicknamePrefix + '.' + suffix;
    }

    private static Id createExternalUser(
        User userRecord,
        Id accountId,
        String password
    ) {
        validatePassword(password);

        Id userId = Site.createExternalUser(userRecord, accountId);
        System.setPassword(userId, password);
        return userId;
    }

    private static void validatePassword(String password) {
        if (String.isBlank(password)) {
            throw new AuraHandledException('Enter a password.');
        }
        if (password.length() < 8 || password.length() > 80) {
            throw new AuraHandledException('Use a password between 8 and 80 characters.');
        }
    }

    private static Id getSharedAccountId() {
        Self_Registration_Settings__mdt settings = getSettings();
        String configuredAccountId = settings.Shared_Account_Id__c;
        if (
            String.isBlank(configuredAccountId) ||
            !Pattern.matches(
                '[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?',
                configuredAccountId.trim()
            )
        ) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }

        Id accountId;
        try {
            accountId = Id.valueOf(configuredAccountId.trim());
        } catch (StringException invalidAccountIdError) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }
        if (accountId.getSObjectType() != Account.SObjectType) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }

        return accountId;
    }

    private static Id getRegistrationProfileId() {
        Self_Registration_Settings__mdt settings = getSettings();
        String configuredProfileId = settings.External_Profile_Id__c;
        if (
            String.isBlank(configuredProfileId) ||
            !Pattern.matches(
                '[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?',
                configuredProfileId.trim()
            )
        ) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }

        Id profileId;
        try {
            profileId = Id.valueOf(configuredProfileId.trim());
        } catch (StringException invalidProfileIdError) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }
        if (profileId.getSObjectType() != Profile.SObjectType) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }

        return profileId;
    }

    private static Self_Registration_Settings__mdt getSettings() {
        Self_Registration_Settings__mdt settings =
            Self_Registration_Settings__mdt.getInstance('Default');
        if (settings == null) {
            throw new AuraHandledException('Registration is not configured. Please contact the site administrator.');
        }
        return settings;
    }
}
