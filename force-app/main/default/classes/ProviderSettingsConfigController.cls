/**
 * @description The ProviderSettingController class is responsible for managing operations
 *              related to the Meta_Configuration__c and Twilio_Configuration__c custom setting.
 *              It provides methods to retrieve and upsert (create/update) records.
 */
// @SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class ProviderSettingsConfigController {
    /**
     * @description Retrieves all records from the ProviderSettings__c custom setting.
     * @return List<ProviderSettings__c> - A list of all provider settings records.
     * @throws AuraHandledException if there is an issue retrieving the records.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProtectedSettingsWrapper> getProviderSettings() {
        List<PermissionSetAssignment> permissionSetAssignments = [SELECT Id, PermissionSetId, PermissionSet.Name, AssigneeId FROM PermissionSetAssignment WHERE PermissionSet.Name = 'SmartMsg_Admin' AND AssigneeId =: UserInfo.getUserId() WITH SECURITY_ENFORCED];
        if(permissionSetAssignments == NULL || permissionSetAssignments.size() == 0){
            throw new AuraHandledException('User don\'t have the required permissions to access this feature.');
        }
        try {
            List<ProtectedSettingsWrapper> providerSettings = new List<ProtectedSettingsWrapper>();

            SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getInstance();
            if (metaSetting != null) {
                ProtectedSettingsWrapper providerSettingMeta = new ProtectedSettingsWrapper();
                providerSettingMeta.id = metaSetting.Id;
                providerSettingMeta.name = metaSetting.Name;
                providerSettingMeta.applicationId = metaSetting.SmartMsg__Application_Id__c;
                providerSettingMeta.channel = metaSetting.SmartMsg__Channel__c;
                providerSettingMeta.phoneNumberId = metaSetting.SmartMsg__Phone_Number_Id__c;
                providerSettingMeta.serviceProviderName = metaSetting.SmartMsg__Service_Provider_Name__c;
                providerSettingMeta.whatsAppBusinessId = metaSetting.SmartMsg__WhatsApp_Business_Id__c;
                providerSettingMeta.isActive = metaSetting.SmartMsg__Active__c;

                providerSettings.add(providerSettingMeta);
            }
            SmartMsg__TwilioConfiguration__c twilioSetting = SmartMsg__TwilioConfiguration__c.getInstance();
            if (twilioSetting != null) {
                ProtectedSettingsWrapper providerSetting = new ProtectedSettingsWrapper();
                providerSetting.id = twilioSetting.Id;
                providerSetting.name = twilioSetting.Name;
                providerSetting.accountSID = twilioSetting.SmartMsg__Account_SID__c;
                providerSetting.channel = twilioSetting.SmartMsg__Channel__c;
                providerSetting.messagingServiceSID = twilioSetting.SmartMsg__Messaging_Service_SID__c;
                providerSetting.serviceProviderName = twilioSetting.SmartMsg__Service_Provider_Name__c;
                providerSetting.twilioPhoneNumber = twilioSetting.SmartMsg__Twilio_Phone_Number__c;
                providerSetting.statusCallbackUrl = twilioSetting.SmartMsg__StatusCallbackUrl__c;
                providerSetting.environmentId = twilioSetting.SmartMsg__Environment_Id__c;
                providerSetting.mediaBaseUrl = twilioSetting.SmartMsg__MediaBaseUrl__c;
                providerSetting.serviceId = twilioSetting.SmartMsg__Service_Id__c;
                providerSetting.isActive = twilioSetting.SmartMsg__Active__c;
                providerSettings.add(providerSetting);
            }
            SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
            if (twilioWhatsappSetting != null) {
                ProtectedSettingsWrapper providerSetting = new ProtectedSettingsWrapper();
                providerSetting.id = twilioWhatsappSetting.Id;
                providerSetting.name = twilioWhatsappSetting.Name;
                providerSetting.accountSID = twilioWhatsappSetting.SmartMsg__Account_SID__c;
                providerSetting.channel = twilioWhatsappSetting.SmartMsg__Channel__c;
                providerSetting.messagingServiceSID = twilioWhatsappSetting.SmartMsg__Messaging_Service_SID__c;
                providerSetting.serviceProviderName = twilioWhatsappSetting.SmartMsg__Service_Provider_Name__c;
                providerSetting.twilioPhoneNumber = twilioWhatsappSetting.SmartMsg__Twilio_Phone_Number__c;
                providerSetting.statusCallbackUrl = twilioWhatsappSetting.SmartMsg__StatusCallbackUrl__c;
                providerSetting.fromPhoneNumbers = twilioWhatsappSetting.SmartMsg__From_Phone_Numbers__c;
                providerSetting.isActive = twilioWhatsappSetting.SmartMsg__Active__c;
                providerSettings.add(providerSetting);
            }

            return providerSettings;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to retrieve provider settings: ' + e.getMessage());
        }
    }

	/**
     * @description Inserts or updates a record in the ProviderSettings__c custom setting.
     *              If the Id field is populated, the existing record is updated; otherwise, a new record is created.
     * @param providerSettingStr The ProviderSettings__c record to upsert.
     * @throws AuraHandledException if there is an issue upserting the record.
     */
   @AuraEnabled
    public static void upsertProviderSetting(String providerSettingStr) {
        ProtectedSettingsWrapper providerSetting = (ProtectedSettingsWrapper) JSON.deserialize(providerSettingStr, ProtectedSettingsWrapper.class);
        List<PermissionSetAssignment> permissionSetAssignments = [SELECT Id, PermissionSetId, PermissionSet.Name , AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'SmartMsg_Admin' AND AssigneeId =: UserInfo.getUserId() WITH SECURITY_ENFORCED];
        if(permissionSetAssignments == NULL || permissionSetAssignments.size() == 0){
            throw new AuraHandledException('User don\'t have the required permissions to access this feature.');
        }
        try {
            ProtectedSettingsWrapper valproviderSetting =(ProtectedSettingsWrapper) JSON.deserialize(providerSettingStr, ProtectedSettingsWrapper.class);

            //Validate only ONE active provider
            validateSingleActiveProvider(valproviderSetting.channel,valproviderSetting.serviceProviderName,valproviderSetting.isActive);
			//System.debug('Crossed');
			// System.debug(providerSetting);
            if (providerSetting.channel == 'WhatsApp' && providerSetting.serviceProviderName == 'Meta') {
                SmartMsg__Meta_Configuration__c setting = SmartMsg__Meta_Configuration__c.getOrgDefaults();
                setting.SmartMsg__Application_Id__c = providerSetting.applicationId;
                setting.App_Secret_key__c = providerSetting.appSecretKey;
                setting.SmartMsg__Auth_Token__c = providerSetting.authToken;
                setting.SmartMsg__Phone_Number_Id__c = providerSetting.phoneNumberId;
                setting.SmartMsg__WhatsApp_Business_Id__c = providerSetting.whatsAppBusinessId;
                setting.SmartMsg__Service_Provider_Name__c = providerSetting.serviceProviderName;
                setting.SmartMsg__Channel__c = providerSetting.channel;
                setting.SmartMsg__Active__c = providerSetting.isActive;
                if (!CommonUtil.hasFLS(setting)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                }else{
                    if(Schema.sObjectType.SmartMsg__Meta_Configuration__c.isUpdateable() && Schema.sObjectType.SmartMsg__Meta_Configuration__c.isCreateable()){
                        upsert setting;
                    }
                    else{
                        throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                    }
                }
            } 
            else if (providerSetting.channel == 'SMS' && providerSetting.serviceProviderName == 'Twilio') {
                TwilioConfiguration__c setting = TwilioConfiguration__c.getOrgDefaults();
                setting.SmartMsg__Account_SID__c = providerSetting.accountSID;
                setting.SmartMsg__Auth_Token__c = providerSetting.authToken;
                setting.SmartMsg__Channel__c = providerSetting.channel;
                setting.SmartMsg__Service_Provider_Name__c = providerSetting.serviceProviderName;
                setting.SmartMsg__Messaging_Service_SID__c = providerSetting.messagingServiceSID;
                setting.SmartMsg__Twilio_Phone_Number__c = providerSetting.twilioPhoneNumber;
                setting.SmartMsg__StatusCallbackUrl__c = providerSetting.statusCallbackUrl;
                setting.SmartMsg__Environment_Id__c = providerSetting.environmentId;
                setting.SmartMsg__MediaBaseUrl__c = providerSetting.mediaBaseUrl;
                setting.SmartMsg__Service_Id__c = providerSetting.serviceId;
                setting.SmartMsg__Active__c = providerSetting.isActive;
                if (!CommonUtil.hasFLS(setting)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                }else{
                    if(Schema.sObjectType.TwilioConfiguration__c.isUpdateable() && Schema.sObjectType.TwilioConfiguration__c.isCreateable()){
                        upsert setting;
                    }
                    else{
                        throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                    }
                }
            }
            else if (providerSetting.channel == 'Twilio_WhatsApp' && providerSetting.serviceProviderName == 'Twilio') {
                SmartMsg__Twilio_Whatsapp__c setting = SmartMsg__Twilio_Whatsapp__c.getOrgDefaults();
                setting.SmartMsg__Account_SID__c = providerSetting.accountSID;
                setting.SmartMsg__Auth_Token__c = providerSetting.authToken;
                setting.SmartMsg__Channel__c = providerSetting.channel;
                setting.SmartMsg__Service_Provider_Name__c = providerSetting.serviceProviderName;
                setting.SmartMsg__Messaging_Service_SID__c = providerSetting.messagingServiceSID;
                setting.SmartMsg__Twilio_Phone_Number__c = providerSetting.twilioPhoneNumber;
                setting.SmartMsg__StatusCallbackUrl__c = providerSetting.statusCallbackUrl;
                setting.SmartMsg__From_Phone_Numbers__c = providerSetting.fromPhoneNumbers;
                setting.SmartMsg__Active__c = providerSetting.isActive;
                if (!CommonUtil.hasFLS(setting)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                }else{
                    if(Schema.sObjectType.SmartMsg__Twilio_Whatsapp__c.isUpdateable() && Schema.sObjectType.SmartMsg__Twilio_Whatsapp__c.isCreateable()){
                        upsert setting;
                    }
                    else{
                        throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                    }
                }
            }
             else {
                throw new AuraHandledException('Invalid channel specified.');
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void validateSingleActiveProvider(String currentChannel,String currentProvider,Boolean isActive) {
        if (isActive != true) {
            return;
        }

        Integer activeCount = 0;

        if(!(currentChannel == 'SMS' && currentProvider == 'Twilio')){
            if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true && !(currentChannel == 'WhatsApp' && currentProvider == 'Meta')) {
                activeCount++;
            }

            if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true &&
                !(currentChannel == 'Twilio_WhatsApp' && currentProvider == 'Twilio')) {
                activeCount++;
            }
        }

        if (activeCount > 0) {
            throw new activeServiceProviderException(
                'Only one Whatsapp service provider can be active at a time.'
            );
        }
    }

    /**
     * @description Exception thrown when more than one WhatsApp service provider is set active.
     */
    public class activeServiceProviderException extends Exception {}
}