/**
 * @description Test class for ProviderSettingsUtil.
 * 
 * This test class verifies the functionality of the ProviderSettingsUtil methods,
 * including the retrieval of provider settings records based on the channel.
 */
@isTest
public class ProviderSettingUtilTest {
    /**
     * @description Creates test data for the ProviderSettings__c, TwilioConfiguration__c, and Meta_Configuration__c custom settings.
     *              This method inserts test records with different channels ("SMS" and "WhatsApp").
     *              The data setup is shared across all test methods.
     * @testSetup
     */
    @testSetup
    public static void createTestProviderSettings() {
        
        SmartMsg__TwilioConfiguration__c twilioSetting = SmartMsg__TwilioConfiguration__c.getOrgDefaults();
        twilioSetting.SmartMsg__Account_SID__c = 'TestAccountSID';
        twilioSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        twilioSetting.SmartMsg__Channel__c = 'SMS';
        twilioSetting.SmartMsg__Messaging_Service_SID__c = 'TestMessagingServiceSID';
        twilioSetting.SmartMsg__Service_Provider_Name__c = 'Twilio';
        twilioSetting.SmartMsg__Twilio_Phone_Number__c = '1234567890';
        twilioSetting.SmartMsg__Active__c = false;
        upsert twilioSetting;

        SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getOrgDefaults();
        metaSetting.SmartMsg__Application_Id__c = 'TestApplicationId';
        //metaSetting.App_Secret_key__c = 'TestSecretKey';
        metaSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        metaSetting.SmartMsg__Phone_Number_Id__c = 'TestPhoneNumberId';
        metaSetting.SmartMsg__WhatsApp_Business_Id__c = 'TestWhatsAppBusinessId';
        metaSetting.SmartMsg__Service_Provider_Name__c = 'Meta';
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Active__c = false;
        upsert metaSetting;
        
    }

    
    /**
     * @description Tests the retrieval of provider settings using the getSMSProviderSettings method.
     *              Verifies that the correct record is returned and that specific field values match expectations.
     * @isTest
     */
    @isTest
    public static void testGetSMSProviderSettings() {
        Test.startTest();
        SmartMsg__TwilioConfiguration__c settings = ProviderSettingUtil.getSMSProviderSettings('SMS');
        Test.stopTest();
        System.assertNotEquals(null, settings, 'Expected Twilio settings record to be retrieved.');
        System.assertEquals('SMS', settings.SmartMsg__Channel__c, 'Expected Channel to match.');
    }

    /**
     * @description Tests exception handling in the getSMSProviderSettings method when no records are present for the specified channel.
     *              Expects the method to handle the absence of data gracefully.
     * @isTest
     */
    @isTest
    public static void testGetSMSProviderSettingsException() {
        
        Test.startTest();
        
        try {
            ProviderSettingUtil.getSMSProviderSettings('NonExistentChannel');
            System.assert(false, 'Expected an AuraHandledException due to no provider settings found.');
        } catch (AuraHandledException e) {
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Expected exception message to match.');
        }
        Test.stopTest();
    }

    /**
     * @description Tests the retrieval of provider settings using the getWhatsAppProviderSettings method.
     *              Verifies that the correct record is returned and that specific field values match expectations.
     * @isTest
     */
    @isTest
    public static void testGetWhatsAppProviderSettings() {
        Test.startTest();
        SmartMsg__Meta_Configuration__c settings = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        Test.stopTest();
        System.assertNotEquals(null, settings, 'Expected Meta settings record to be retrieved.');
        System.assertEquals('WhatsApp', settings.SmartMsg__Channel__c, 'Expected Channel to match.');
    }

    /**
     * @description Tests exception handling in the getWhatsAppProviderSettings method when no records are present for the specified channel.
     *              Expects the method to handle the absence of data gracefully.
     * @isTest
     */
    @isTest
    public static void testGetWhatsAppProviderSettingsException() {
        Test.startTest();
        try {
            ProviderSettingUtil.getWhatsAppProviderSettings('NonExistentChannel');
            System.assert(false, 'Expected an AuraHandledException due to no provider settings found.');
        } catch (AuraHandledException e) {
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Expected exception message to match.');
        }
        Test.stopTest();
    }
    
    @isTest
    public static void testTwilioWhatsAppProvider(){
        SmartMsg__Twilio_Whatsapp__c twilioWhatsApp = TestObjectFactory.twilioWhatsAppSettings();
        insert twilioWhatsApp;
        Test.startTest();
		SmartMsg__Twilio_Whatsapp__c twilioWhatsAppSetting = ProviderSettingUtil.getTwilioWhatsAppProviderSetting('Twilio_WhatsApp');
        Test.stopTest();
        System.assertEquals(twilioWhatsAppSetting != null, true,'Failed to retrieve the Twilio WhatsApp record');
    }
}