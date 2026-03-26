/**
 * @description Test class for ProviderSettingsConfigController.
 *
 * This test class verifies the functionality of the ProviderSettingsConfigController methods,
 * including the retrieval and upserting of provider settings records. It ensures that the
 * operations handle data correctly and handle exceptions appropriately.
 */
@isTest
public class ProviderSettingsConfigControllerTest {
    /** Used by Twilio WhatsApp tests to run as a user with full FLS on custom settings. */
    private static final String ADMIN_USER_LASTNAME = 'ProviderSettingsConfigTestAdmin';

    /**
     * @description Creates test data for Meta_Configuration__c, TwilioConfiguration__c and Twilio_Whatsapp__c custom settings. Shared across all test methods.
     */
    @testSetup
    public static void createTestProviderSettings() {
        // Only custom settings in testSetup to avoid MIXED_DML_OPERATION (no User/PermissionSetAssignment here).
        SmartMsg__Meta_Configuration__c metaSetting = TestObjectFactory.metaConfigurations();
        upsert metaSetting;

        SmartMsg__TwilioConfiguration__c twilioSetting = TestObjectFactory.twilioConfigurationSettings();
        upsert twilioSetting;

        SmartMsg__Twilio_Whatsapp__c twilioWhatsAppSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioWhatsAppSetting;
    }

    private static void ensurePermsetAssignedToRunningUser(String permsetName) {
        if (String.isBlank(permsetName)) {
            return;
        }
        Id userId = UserInfo.getUserId();
        List<PermissionSetAssignment> existing = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSet.Name = :permsetName LIMIT 1];
        if (!existing.isEmpty()) {
            return;
        }
        List<PermissionSet> psList = [SELECT Id FROM PermissionSet WHERE Name = :permsetName LIMIT 1];
        if (!psList.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = psList[0].Id);
        }
    }

    /**
     * @description Assigns SmartMsg_Admin to running user in a separate transaction to avoid MIXED_DML_OPERATION.
     */
    private static void ensurePermsetInTestContext() {
        Test.startTest();
        ensurePermsetAssignedToRunningUser('SmartMsg_Admin');
        Test.stopTest();
    }

    /**
     * @description Creates admin user with SmartMsg_Admin in a separate transaction; for use in runAs in Twilio WhatsApp tests.
     * @return User The created admin User record with SmartMsg_Admin permission set assigned.
     */
    private static User createAdminUserForTwilioWhatsAppTests() {
        List<Profile> adminProfiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile p = adminProfiles.isEmpty() ? [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1] : adminProfiles[0];
        String uniq = String.valueOf(DateTime.now().getTime());
        User adminUser = new User(
            Alias = 'pscadm',
            Email = 'provconfigadmin' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = ADMIN_USER_LASTNAME,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'provconfigadmin' + uniq + '@example.com',
            ProfileId = p.Id
        );
        Test.startTest();
        insert adminUser;
        List<PermissionSet> psList = [SELECT Id FROM PermissionSet WHERE Name = 'SmartMsg_Admin' LIMIT 1];
        if (!psList.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = adminUser.Id, PermissionSetId = psList[0].Id);
        }
        Test.stopTest();
        return [SELECT Id FROM User WHERE Id = :adminUser.Id LIMIT 1];
    }

    /**
     * @description Tests the retrieval of all provider settings using the getProviderSettings method for WhatsApp channel.
     *              Verifies that the correct record is returned and that specific field values match expectations.
     * @isTest
     */
    @isTest
    public static void testGetProviderSettings() {
        ensurePermsetInTestContext();
        List<ProtectedSettingsWrapper> settings = ProviderSettingsConfigController.getProviderSettings();
        System.assertEquals(3, settings.size(), 'Expected 3 provider settings record.');
    }

    /**
     * @description Tests the insertion of a new provider setting record using the upsertProviderSetting method.
     *              It verifies that the new record is inserted with the correct values for Twilio WhatsApp channel.
     * @isTest
     */
    @isTest
    public static void testUpsertProviderSettingInserttwilioWhatsApp() {
        ensurePermsetInTestContext();
        ProtectedSettingsWrapper newSetting = TestObjectFactory.createTwilioWhatsAppWrapper(1);
        newSetting.isActive = false;

        String providerSettingStr = JSON.serialize(newSetting);
        ProviderSettingsConfigController.upsertProviderSetting(providerSettingStr);

        SmartMsg__Twilio_Whatsapp__c insertedSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
        System.assertNotEquals(null, insertedSetting, 'Expected the provider setting record to be inserted.');
        System.assertEquals('Twilio_WhatsApp', insertedSetting.SmartMsg__Channel__c, 'Expected Application ID to match.');
    }
    
    /**
     * @description Tests the insertion of a new provider setting record using the upsertProviderSetting method.
     *              It verifies that the new record is inserted with the correct values for WhatsApp channel.
     * @isTest
     */
    @isTest
    public static void testUpsertProviderSettingInsertWhatsApp() {
        ensurePermsetInTestContext();
        ProtectedSettingsWrapper newSetting = TestObjectFactory.createMetaWhatsAppWrapper(1);
        newSetting.isActive = true;

        String providerSettingStr = JSON.serialize(newSetting);
        ProviderSettingsConfigController.upsertProviderSetting(providerSettingStr);

        SmartMsg__Meta_Configuration__c insertedSetting = SmartMsg__Meta_Configuration__c.getInstance();
        System.assertNotEquals(null, insertedSetting, 'Expected the provider setting record to be inserted.');
        System.assertEquals('ApplicationId1', insertedSetting.SmartMsg__Application_Id__c, 'Expected Application ID to match.');
    }


    /**
     * @description Tests the insertion of a new provider setting record using the upsertProviderSetting method.
     *              It verifies that the new record is inserted with the correct values for SMS channel.
     * @isTest
     */
    @isTest
    public static void testUpsertProviderSettingInsertSMS() {
        ensurePermsetInTestContext();
        ProtectedSettingsWrapper newSetting = TestObjectFactory.createTwilioSMSWrapper(1);
        newSetting.isActive = true;

        String providerSettingStr = JSON.serialize(newSetting);
        ProviderSettingsConfigController.upsertProviderSetting(providerSettingStr);

        SmartMsg__TwilioConfiguration__c insertedSetting = SmartMsg__TwilioConfiguration__c.getInstance();
        System.assertNotEquals(null, insertedSetting, 'Expected the provider setting record to be inserted.');
        System.assertEquals('AccountSID1', insertedSetting.SmartMsg__Account_SID__c, 'Expected Account SID to match.');
    }

    /**
     * @description Tests the update functionality of the upsertProviderSetting method.
     *              Updates an existing provider setting and verifies that the changes are correctly saved for WhatsApp channel.
     * @isTest
     */
    @isTest
    public static void testUpsertProviderSettingUpdateWhatsApp() {
        ensurePermsetInTestContext();
        SmartMsg__Meta_Configuration__c existingSetting = SmartMsg__Meta_Configuration__c.getInstance();
        ProtectedSettingsWrapper wrapper = TestObjectFactory.createMetaWhatsAppWrapper(2);
        wrapper.id = existingSetting.Id;
        wrapper.name = existingSetting.Name;
        wrapper.isActive = true;

        String providerSettingStr = JSON.serialize(wrapper);
        ProviderSettingsConfigController.upsertProviderSetting(providerSettingStr);

        SmartMsg__Meta_Configuration__c updatedSetting = SmartMsg__Meta_Configuration__c.getInstance();
        System.assertEquals('AuthToken2', updatedSetting.SmartMsg__Auth_Token__c, 'Expected the Auth Token to be updated.');
    }

    /**
     * @description Tests the update functionality of the upsertProviderSetting method.
     *              Updates an existing provider setting and verifies that the changes are correctly saved for SMS channel.
     * @isTest
     */
    @isTest
    public static void testUpsertProviderSettingUpdateSMS() {
        ensurePermsetInTestContext();
        SmartMsg__TwilioConfiguration__c existingSetting = SmartMsg__TwilioConfiguration__c.getInstance();
        ProtectedSettingsWrapper wrapper = TestObjectFactory.createTwilioSMSWrapper(2);
        wrapper.id = existingSetting.Id;
        wrapper.name = existingSetting.Name;
        wrapper.isActive = true;

        String providerSettingStr = JSON.serialize(wrapper);
        ProviderSettingsConfigController.upsertProviderSetting(providerSettingStr);

        SmartMsg__TwilioConfiguration__c updatedSetting = SmartMsg__TwilioConfiguration__c.getInstance();
        System.assertEquals('AuthToken2', updatedSetting.SmartMsg__Auth_Token__c, 'Expected the Auth Token to be updated.');
    }

    /**
     * @description Tests the exception handling of the upsertProviderSetting method when provided with invalid data.
     *              It attempts to insert a provider setting with missing required fields and expects an AuraHandledException.
     * @isTest
     */
    @isTest
    public static void testUpsertProviderSettingException() {
        ensurePermsetInTestContext();
        ProtectedSettingsWrapper invalidSetting = new ProtectedSettingsWrapper();
        try {
            String providerSettingStr = JSON.serialize(invalidSetting);
            ProviderSettingsConfigController.upsertProviderSetting(providerSettingStr);
            System.assert(false, 'Expected an AuraHandledException due to missing required fields.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Expected an exception message due to missing required fields.');
        }
    }


    /**
     * @description Tests the validation logic that ensures only one WhatsApp service provider can be active at a time.
     *              First sets Meta WhatsApp as active, then attempts to set Twilio_WhatsApp as active, which should throw an exception.
     * @isTest
     */
    @isTest
    public static void testValidateSingleActiveWhatsAppProvider() {
        ensurePermsetInTestContext();
        // Ensure Twilio_WhatsApp is inactive first
        SmartMsg__Twilio_Whatsapp__c twilioWhatsAppSetting = TestObjectFactory.twilioWhatsAppSettings();
        twilioWhatsAppSetting.SmartMsg__Active__c = false;
        upsert twilioWhatsAppSetting;

        // First, set Meta WhatsApp as active
        SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getInstance();
        ProtectedSettingsWrapper metaWrapper = TestObjectFactory.createMetaWhatsAppWrapper(3);
        metaWrapper.id = metaSetting.Id;
        metaWrapper.name = metaSetting.Name;
        metaWrapper.applicationId = metaSetting.SmartMsg__Application_Id__c;
        metaWrapper.phoneNumberId = metaSetting.SmartMsg__Phone_Number_Id__c;
        metaWrapper.whatsAppBusinessId = metaSetting.SmartMsg__WhatsApp_Business_Id__c;
        metaWrapper.isActive = true;

        String metaSettingStr = JSON.serialize(metaWrapper);
        ProviderSettingsConfigController.upsertProviderSetting(metaSettingStr);

        // Now try to set Twilio_WhatsApp as active - should throw exception
        ProtectedSettingsWrapper twilioWhatsAppWrapper = TestObjectFactory.createTwilioWhatsAppWrapper(4);
        twilioWhatsAppWrapper.isActive = true;

        try {
            String twilioWhatsAppSettingStr = JSON.serialize(twilioWhatsAppWrapper);
            ProviderSettingsConfigController.upsertProviderSetting(twilioWhatsAppSettingStr);
            System.assert(false, 'Expected an exception when trying to activate second WhatsApp provider.');
        } catch (AuraHandledException e) {
            // The Aura framework wraps exceptions from @AuraEnabled methods as "Script-thrown exception" in test context
            // We verify that an exception was thrown, which indicates the validation logic worked correctly
            System.assert(e.getMessage() != null && (e.getMessage().contains('Script-thrown exception') || e.getMessage().contains('Only one Whatsapp service provider can be active at a time.')), 'Expected exception when trying to activate second WhatsApp provider. Actual message: ' + e.getMessage());
        }
    }
}