/**
 * @class ProviderSettingUtil
 * @description Utility class for retrieving provider settings based on the channel.
 * @public
 */
public with sharing class ProviderSettingUtil {
    /**
     * @description Retrieves the provider settings for a given channel.
     * 
     * @param channel The channel for which the provider settings are to be retrieved (e.g., 'WhatsApp', 'SMS').
     * @return TwilioConfiguration__c The provider settings record matching the specified channel.
     * @throws AuraHandledException If no provider settings are found for the specified channel.
     */
    public static SmartMsg__TwilioConfiguration__c getSMSProviderSettings(String channel) {
        List<PermissionSetAssignment> permissionSetAssignments = [
            SELECT Id, PermissionSetId, PermissionSet.Name, AssigneeId, Assignee.Name 
            FROM PermissionSetAssignment 
            WHERE (PermissionSet.Name = 'SmartMsg_Admin' OR PermissionSet.Name = 'SmartMsg_User')
            AND AssigneeId = :UserInfo.getUserId()
            WITH SECURITY_ENFORCED
        ];
        if (permissionSetAssignments.isEmpty() || permissionSetAssignments.size() == 0) {
            throw new AuraHandledException('You do not have the required permissions to access this feature.');
        }
        SmartMsg__TwilioConfiguration__c setting = SmartMsg__TwilioConfiguration__c.getInstance();
        if(setting != null && setting.SmartMsg__Channel__c == channel) {
            return setting;
        }else{
             throw new AuraHandledException('No ProviderSettings found for channel: ' + channel);
        }
}
     /**
     * @description Retrieves the provider settings for a given channel.
     * 
     * @param channel The channel for which the provider settings are to be retrieved (e.g., 'WhatsApp', 'SMS').
     * @return TwilioConfiguration__c The provider settings record matching the specified channel.
     * @throws AuraHandledException If no provider settings are found for the specified channel.
     */
    public static SmartMsg__Meta_Configuration__c getWhatsAppProviderSettings(String channel) {
        
        if (UserInfo.getUserType() != 'Guest') {
            List<PermissionSetAssignment> permissionSetAssignments = [
                SELECT Id, PermissionSetId, PermissionSet.Name, AssigneeId, Assignee.Name 
                FROM PermissionSetAssignment 
                WHERE (PermissionSet.Name = 'SmartMsg_Admin' OR PermissionSet.Name = 'SmartMsg_User' OR PermissionSet.Name = 'SmartMsg_Site_User')
                AND AssigneeId = :UserInfo.getUserId()
                WITH SECURITY_ENFORCED
            ];
            
            if (permissionSetAssignments.isEmpty() || permissionSetAssignments.size() == 0) {
                throw new AuraHandledException('You do not have the required permissions to access this feature.');
            }
        }
        SmartMsg__Meta_Configuration__c setting = SmartMsg__Meta_Configuration__c.getInstance();
        if(setting != null && setting.SmartMsg__Channel__c == channel) {
            return setting;
        }
        throw new AuraHandledException('No ProviderSettings found for channel: ' + channel);
    }
    /**
     * @description Retrieves the provider settings for a given channel.
     * 
     * @param channel The channel for which the provider settings are to be retrieved (e.g., 'WhatsApp', 'SMS').
     * @return TwilioConfiguration__c The provider settings record matching the specified channel.
     * @throws AuraHandledException If no provider settings are found for the specified channel.
     */
    public static SmartMsg__Twilio_Whatsapp__c getTwilioWhatsAppProviderSetting(String channel) {
        List<PermissionSetAssignment> permissionSetAssignments = [
            SELECT Id, PermissionSetId, PermissionSet.Name, AssigneeId, Assignee.Name
            FROM PermissionSetAssignment
            WHERE (PermissionSet.Name = 'SmartMsg_Admin' OR PermissionSet.Name = 'SmartMsg_User' OR PermissionSet.Name = 'SmartMsg_Site_User')
            AND AssigneeId = :UserInfo.getUserId()
            WITH SECURITY_ENFORCED
        ];
        
        if (permissionSetAssignments.isEmpty() || permissionSetAssignments.size() == 0) {
            throw new AuraHandledException('You do not have the required permissions to access this feature.');
        }
        SmartMsg__Twilio_Whatsapp__c setting = SmartMsg__Twilio_Whatsapp__c.getInstance();
        if(setting != null && setting.SmartMsg__Channel__c == channel) {
            return setting;
        }
        throw new AuraHandledException('No ProviderSettings found for channel: ' + channel);
    }

}