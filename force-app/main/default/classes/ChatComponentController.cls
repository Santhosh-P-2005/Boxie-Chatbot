/**
 *  * @description chat component controller
 */
public with sharing class ChatComponentController {

    @TestVisible
    private static Boolean testForceSubscriptionExpired = false;

    /**
     * @description Retrieves all messages sent to a specific phone number.
     * @return List of messages sent to the specified phone number.
     * @throws AuraHandledException if there's an error during the query execution.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasUserPermission() {

        List<PermissionSetAssignment> permissionSetAssignments = [SELECT Id, PermissionSetId, PermissionSet.Name, AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE (PermissionSet.Name = 'SmartMsg_Admin' OR PermissionSet.Name = 'SmartMsg_User' OR PermissionSet.Name = 'SmartMsg_Site_User') AND AssigneeId = :UserInfo.getUserId() WITH SECURITY_ENFORCED];

        if (permissionSetAssignments.isEmpty() || permissionSetAssignments.size() == 0) {
            throw new AuraHandledException('You do not have the required permissions to access this feature.');
        }
        return true;
    }

    /**
     * @description Retrieves a map of phone fields for a specified object.
     * @param objectName The name of the object for which to retrieve phone fields.
     * @return A map where keys are field API names and values are field labels.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String,String> getPhoneFields(String objectName) {
        if(objectName == null || String.isBlank(objectName)){
            return new Map<String,String>();
        }else{
            Map<String,String> apiNameWithPhoneLabelMap = new Map<String,string>();
            List<String> phoneFields = new List<String>();
            try {
                if (objectName == 'Opportunity' || objectName == 'Account') {
                    Map<String, Schema.SObjectField> contactFields = Schema.getGlobalDescribe().get('Contact').getDescribe().fields.getMap();
                    for (String fieldName : contactFields.keySet()) {
                        Schema.DescribeFieldResult fieldDescribe = contactFields.get(fieldName).getDescribe();
                        if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
                            phoneFields.add(fieldDescribe.getLabel());
                            if(!apiNameWithPhoneLabelMap.containsKey(fieldName)){
                                apiNameWithPhoneLabelMap.put(fieldName,fieldDescribe.getLabel());
                            }
                        }
                    }
                } else if (Schema.getGlobalDescribe().containsKey(objectName)) {
                    // Generic handling for all other objects
                    Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe()
                        .get(objectName)
                        .getDescribe()
                        .fields
                        .getMap();
                    for (String fieldName : fields.keySet()) {
                        Schema.DescribeFieldResult fieldDescribe = fields.get(fieldName).getDescribe();
                        if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
                            phoneFields.add(fieldDescribe.getLabel());
                            if(!apiNameWithPhoneLabelMap.containsKey(fieldName)){
                                apiNameWithPhoneLabelMap.put(fieldName,fieldDescribe.getLabel());
                            }
                        }
                    }
                }
            } catch (Exception e) {
                throw new AuraHandledException('Error fetching phone fields: ' + e.getMessage());
            }
            return apiNameWithPhoneLabelMap;
        }
    }

    /**
     * @description Returns which channels are active for the chat component dropdown.
     * SMS is active when TwilioConfiguration__c (SMS) is active; WhatsApp is active when
     * Meta_Configuration__c or Twilio_Whatsapp__c is active.
     * @return Map with keys 'SMS' and 'WhatsApp' and Boolean values indicating if each channel is active.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getActiveChannels() {
        Map<String, Boolean> activeChannels = new Map<String, Boolean>();
        SmartMsg__TwilioConfiguration__c twilioSms = SmartMsg__TwilioConfiguration__c.getInstance();
        Boolean smsActive = twilioSms != null && twilioSms.SmartMsg__Active__c == true && twilioSms.SmartMsg__Channel__c == 'SMS';
        activeChannels.put('SMS', smsActive);
        Boolean whatsAppActive = (SmartMsg__Meta_Configuration__c.getInstance() != null && SmartMsg__Meta_Configuration__c.getInstance().SmartMsg__Active__c == true)
            || (SmartMsg__Twilio_Whatsapp__c.getInstance() != null && SmartMsg__Twilio_Whatsapp__c.getInstance().SmartMsg__Active__c == true);
        activeChannels.put('WhatsApp', whatsAppActive);
        return activeChannels;
    }

    /**
     * @description Returns the active WhatsApp provider: 'WhatsApp' (Meta) or 'Twilio WhatsApp'.
     * @return 'WhatsApp' if Meta is active, 'Twilio WhatsApp' if Twilio WhatsApp is active, otherwise 'WhatsApp'.
     */
    @AuraEnabled(cacheable=true)
    public static String getActiveWhatsAppChannel() {
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            return 'WhatsApp';
        }
        if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            return 'Twilio WhatsApp';
        }
        return 'WhatsApp';
    }

    /**
     * @description Returns list of from phone numbers for Twilio WhatsApp: SmartMsg__Twilio_Phone_Number__c first (default),
     * then any numbers from From_Phone_Numbers__c (newline or comma separated). No duplicates.
     * @return List of phone number strings (with + prefix if missing). Empty if Twilio WhatsApp not active or no numbers configured.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getTwilioWhatsAppFromNumbers() {
        List<String> numbers = new List<String>();
        Set<String> seen = new Set<String>();
        SmartMsg__Twilio_Whatsapp__c twilio = SmartMsg__Twilio_Whatsapp__c.getInstance();
        if (twilio == null || twilio.SmartMsg__Active__c != true) {
            return numbers;
        }
        // Add Twilio_Phone_Number__c first so it is the default in the dropdown
        if (String.isNotBlank(twilio.SmartMsg__Twilio_Phone_Number__c)) {
            String p = twilio.SmartMsg__Twilio_Phone_Number__c.trim();
            String normalized = p.startsWith('+') ? p : '+' + p;
            numbers.add(normalized);
            seen.add(normalized);
        }
        // Add numbers from From_Phone_Numbers__c, skipping duplicates
        String raw = twilio.SmartMsg__From_Phone_Numbers__c;
        if (String.isNotBlank(raw)) {
            for (String line : raw.split('[,\\n\\r]+')) {
                line = line.trim();
                if (String.isNotBlank(line)) {
                    String normalized = line.startsWith('+') ? line : '+' + line;
                    if (!seen.contains(normalized)) {
                        numbers.add(normalized);
                        seen.add(normalized);
                    }
                }
            }
        }
        return numbers;
    }

    /**
     * @description Returns true only when both Dialogue__c and Option_Dialog__c have at least one record (used to show chatbot on/off toggle in chat component).
     * @return true if both dialog and option dialog records exist; false otherwise.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasChatbotDialogAndOptionDialogRecords() {
        List<SmartMsg__Dialogue__c> dialogs = [SELECT Id FROM SmartMsg__Dialogue__c WITH SECURITY_ENFORCED LIMIT 1];
        // System.debug('dialogs - > ' + dialogs);
        List<SmartMsg__Option_Dialog__c> optionDialogs = [SELECT Id FROM SmartMsg__Option_Dialog__c WITH SECURITY_ENFORCED LIMIT 1];
        // System.debug('optionDialogs - > ' + optionDialogs);
        return !dialogs.isEmpty() && !optionDialogs.isEmpty();
    }

    /**
     * @description Returns the object API name for a given record Id (e.g. Account, Lead, Contact, Opportunity).
     * Used by chat component when placed on record pages where objectApiName may not be set by the page.
     * @param recordId The record Id (15 or 18 char).
     * @return Object API name, or null if invalid.
     */
    @AuraEnabled(cacheable=true)
    public static String getObjectApiNameFromRecordId(String recordId) {
        if (String.isBlank(recordId)) {
            return null;
        }
        try {
            return Id.valueOf(recordId.trim()).getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Retrieves all messages sent to a specific phone number.
     * @param phoneNumber The phone number to filter messages.
     * @return List of messages sent to the specified phone number.
     * @throws AuraHandledException if there's an error during the query execution.
     */
    @AuraEnabled
    public static List<SmartMsg__Message__c> listAllMessages(String phoneNumber) {

        if (String.isBlank(phoneNumber)) {
            return new List<SmartMsg__Message__c>();
        }else{
            String formattedPhoneNumber = formatPhoneNumber(phoneNumber);
            try {
                String searchPhone = '%' + formattedPhoneNumber.substring(1) + '%';
                List<SmartMsg__Message__c> messageList = [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__Channel__c, SmartMsg__To_Number__c, SmartMsg__Media_Url__c, SmartMsg__Failed_Reason__c, SmartMsg__Retry_Count__c, SmartMsg__FilesBiSync_Related_Folder_Ids__c, SmartMsg__Delivery_Status__c, SmartMsg__is_Bulk__c, SmartMsg__Pinned__c, SmartMsg__Starred__c, CreatedDate, SmartMsg__Type__c, SmartMsg__File_Content__c, SmartMsg__File_Name__c, SmartMsg__Sent_Date_and_Time__c, CreatedBy.Name, SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c LIKE :searchPhone AND SmartMsg__Delivery_Status__c != null AND SmartMsg__Channel__c = 'SMS' WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];

                if(!messageList.isEmpty()){
                    return messageList;
                }else{
                    return new List<SmartMsg__Message__c>();
                }
            }catch (Exception e) {
                throw new AuraHandledException('Error fetching messages: ' + e.getMessage());
            }
        }
    }
    /**
     * Formats a phone number by adding a country code.
     * @description Assumes US numbers if the length is 10 digits, otherwise treats it as an international number.
     * @param phoneNumber The phone number to format.
     * @return The formatted phone number with a country code.
     * @throws AuraHandledException if the phone number format is invalid.
     */
    public static String formatPhoneNumber(String phoneNumber) {

        String cleanedNumber = phoneNumber.replaceAll('[^\\d+]', '');
        if (cleanedNumber.startsWith('+')) {
            if(cleanedNumber.length() == 11){
                cleanedNumber = cleanedNumber.substring(1);  // Remove the leading '+'
                return '+1' + cleanedNumber;
            }
            else {
                return cleanedNumber;
            }
        } else {
            if (cleanedNumber.length() == 10) {
                return '+1' + cleanedNumber;//Assume it's a US number and prepend '+1'
            } else if (cleanedNumber.length() > 10) {
                return '+' + cleanedNumber;//Assume it's an international number and prepend '+'
            } else {
                throw new AuraHandledException('Invalid phone number format. Please provide a valid phone number.');
            }
        }
    }

    /**
     * @description Retrieves WhatsApp messages for a specific customer phone number.
     * @param customerPhone
    * @return List of WhatsApp messages associated with the specified phone number.
     */ 
    @AuraEnabled
    public static List<SmartMsg__Message__c> listWAMessages(String customerPhone){

        List<SmartMsg__Message__c> messages = [SELECT SmartMsg__Business_Phone_Number__c, SmartMsg__Channel__c, CreatedById, CreatedDate, SmartMsg__Customer_Name__c, SmartMsg__Delivery_Status__c, SmartMsg__Error_Code__c, SmartMsg__ErrorMessage__c, SmartMsg__Failed_Reason__c, SmartMsg__From_Number__c, Id, SmartMsg__Image_type__c, SmartMsg__is_Bulk__c, SmartMsg__Is_Outgoing__c, SmartMsg__Is_Read__c, IsDeleted, SmartMsg__Media_File__c, SmartMsg__Media_Url__c,SmartMsg__File_Name__c, SmartMsg__Message__c, SmartMsg__Message_Body__c, SmartMsg__Message_Id__c, SmartMsg__Message_Template__c, SmartMsg__Message_Template_Body__c, SmartMsg__Message_Type__c, Name, SmartMsg__Outgoing__c, OwnerId, SmartMsg__Parent_Message_Id__c, SmartMsg__Pinned__c, SmartMsg__Reaction__c, SmartMsg__Related_Record_Id__c, SmartMsg__Response__c, SmartMsg__Retry_Count__c, SmartMsg__Scheduled_Date_Time__c, SmartMsg__Sent_At__c, SmartMsg__Sent_By_User__c, SmartMsg__Sent_Date_and_Time__c, SmartMsg__Starred__c, SystemModstamp, SmartMsg__To_Number__c, SmartMsg__Type__c,SmartMsg__Location_Address__c,SmartMsg__Location_Latitude__c,SmartMsg__Location_Longitude__c,SmartMsg__Location_Name__c,SmartMsg__Location_Link__c FROM SmartMsg__Message__c WHERE (SmartMsg__To_Number__c = :customerPhone OR SmartMsg__From_Number__c = :customerPhone) AND (SmartMsg__Channel__c = 'Whatsapp' OR SmartMsg__Channel__c = 'Twilio WhatsApp') WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
        return messages;
    }

    /**
     * @description Returns a list of accounts and their related contacts
     * @param accountId The ID of the account to retrieve
     * @param contactPhoneFields List of contact phone fields to retrieve
     * @param accountPhoneFields List of account phone fields to retrieve
     * @return List of accounts and their related contacts
     */
    public static List<Account> accountRelatedContactRecords(Id accountId,List<String> contactPhoneFields,List<String> accountPhoneFields){
        String queryFields = 'Id, Name';
        for (String field : accountPhoneFields) {
            queryFields += ', ' + field;
        }
        String contactSubFields = '';
        for (String field : contactPhoneFields) {
            contactSubFields += ', ' + field;
        }
        String fullQuery = 'SELECT ' + queryFields +
            ', (SELECT Id, Name' + contactSubFields + ' FROM Contacts) ' +
            'FROM Account WHERE Id = '+'\''+accountId+'\''+' LIMIT 1';
        return Database.query(fullQuery);
    }

    /**
     * @description Combines account and contact phone fields into a map.
     * @param accountPhoneFields List of account phone fields to combine.
     * @param accountList List of accounts to retrieve phone fields from.
     * @param phoneField The main phone field to include in the result.
     * @param contactPhoneFields List of contact phone fields to combine.
     * @return Map containing combined phone fields, main phone, account name, and contact details.
     */
    public static Map<String,Object> combinedResult (List<String> accountPhoneFields, List<Account> accountList, String phoneField,List<String> contactPhoneFields){
        Map<String, String> phoneFieldMap = new Map<String, String>();
        List<Map<String, String>> contactDetails = new List<Map<String, String>>();
        Map<String, Object> recordDetails = new Map<String, Object>();
        Map<String, String> contact = new Map<String, String>();
        for (String field : accountPhoneFields) {
            Object val = accountList[0].get(field);
            if (val != null) {
                phoneFieldMap.put(field, String.valueOf(val).startsWith('+') ? String.valueOf(val) : '+' + String.valueOf(val));
            } else {
                phoneFieldMap.put(field, null);
            }
        }
        recordDetails.put('PhoneFields', phoneFieldMap);
        recordDetails.put('Phone', phoneFieldMap.get(phoneField)); // optionally include main phone
        recordDetails.put('Name', accountList[0].Name);
        for (Contact role : accountList[0].Contacts) {
            String selectedPhoneNumber = String.valueOf(role.get(phoneField));
            if (String.isNotBlank(selectedPhoneNumber)) {
                contact.put('Name', role.Name);
                contact.put('Id', role.Id);
                for (String field : contactPhoneFields) {
                    String value = String.valueOf(role.get(field));
                    if (String.isNotBlank(value)) {
                        value = value.startsWith('+') ? value : '+' + value;
                    }
                    contact.put(field, value);
                }
                contactDetails.add(contact);
                contact = new Map<String, String>();
            }
        }
        if(!contactDetails.isEmpty()){
            recordDetails.put('Contacts', contactDetails);
        }
        return recordDetails;
    }

    /**
     * @description Retrieves details of a record, including phone fields, based on the provided object name, record ID, and phone field.
     * @param objectName The API name of the Salesforce object (e.g., 'Account', 'Opportunity').
     * @param recordId The ID of the record to retrieve details for.
     * @param phoneField The specific phone field to retrieve. If blank, defaults to 'Phone'.
     * @return A map containing record details, including phone fields and their values.
     */
    @AuraEnabled
    public static Map<String, Object> getRecordDetails(String objectName, String recordId, String phoneField) {
        try {
            Map<String, Object> recordDetails = new Map<String, Object>();
            if (String.isBlank(phoneField)) {
                phoneField = 'Phone';
            }

            if (objectName == 'Opportunity' || objectName == 'Account') {
                Map<String, Schema.SObjectField> fieldMap;
                if (objectName == 'Opportunity') {
                    fieldMap = Schema.SObjectType.Contact.fields.getMap();
                } else if (objectName == 'Account') {
                    // For Account, we need BOTH Account phone fields and Contact phone fields
                    fieldMap = Schema.SObjectType.Contact.fields.getMap(); // Not Account!
                }
                List<String> accountPhoneFields = new List<String>();
                List<String> contactPhoneFields = new List<String>();
                for (String fieldName : fieldMap.keySet()) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                    if (fieldDescribe.getType() == Schema.DisplayType.PHONE) {
                        contactPhoneFields.add(fieldName);
                    }
                }
                Map<String, Schema.SObjectField> accountFieldMap = Schema.SObjectType.Account.fields.getMap();
                for (String fieldName : accountFieldMap.keySet()) {
                    Schema.DescribeFieldResult fieldDescribe = accountFieldMap.get(fieldName).getDescribe();
                    if (fieldDescribe.getType() == Schema.DisplayType.PHONE) {
                        accountPhoneFields.add(fieldName);
                    }
                }

                List<Map<String, String>> contactDetails = new List<Map<String, String>>();
                Map<String, String> contact = new Map<String, String>();
                Map<String, String> phoneFieldMap = new Map<String, String>();
                if (objectName == 'Opportunity') {
                    List<Opportunity> opportunityList = [SELECT Id, AccountId FROM Opportunity WHERE Id =: recordId WITH SECURITY_ENFORCED LIMIT 1];
                    if(!opportunityList.isEmpty() && opportunityList[0].AccountId != null){
                        Id accountId = opportunityList[0].AccountId;
                        List<Account> accountList = accountRelatedContactRecords(accountId,contactPhoneFields,accountPhoneFields);
                        if(!accountList[0].contacts.isEmpty() && !contactPhoneFields.isEmpty()){
                            recordDetails = combinedResult(accountPhoneFields,accountList,phoneField,contactPhoneFields);
                        }else{
                            if(!accountPhoneFields.isEmpty()){
                                for (String field : accountPhoneFields) {
                                    Object val = accountList[0].get(field);
                                    if (val != null) {
                                        phoneFieldMap.put(field, String.valueOf(val).startsWith('+') ? String.valueOf(val) : '+' + String.valueOf(val));
                                    } else {
                                        phoneFieldMap.put(field, null);
                                    }
                                }
                                recordDetails.put('PhoneFields', phoneFieldMap);
                                recordDetails.put('Phone', phoneFieldMap.get(phoneField)); // optionally include main phone
                                recordDetails.put('Name', accountList[0].Name);
                            }
                        }
                    }else if(!opportunityList.isEmpty() && opportunityList[0].AccountId == null){
                        //Opportunity contact role
                        Set<Id> contactIdSet = new Set<Id>();
                        if (Schema.sObjectType.OpportunityContactRole.isAccessible() ) {
                            List<OpportunityContactRole> opportunityContactRoleList = new List<OpportunityContactRole>();
                            opportunityContactRoleList = [SELECT Id, ContactId, OpportunityId FROM OpportunityContactRole WHERE OpportunityId =: recordId WITH SECURITY_ENFORCED];
                            for(OpportunityContactRole ocr : opportunityContactRoleList){
                                if(ocr.ContactId != null){
                                    contactIdSet.add(ocr.ContactId);
                                }
                            }
                        } else {
                            throw new AuraHandledException('Access to OpportunityContactRole is denied');
                        }
                        String contactSubFields = '';
                        for (String field : contactPhoneFields) {
                            contactSubFields += ', ' + field;
                        }
                        String contactQuery = 'SELECT Id, Name '+contactSubFields+' FROM contact WHERE Id IN : contactIdSet';
                        List<Contact> contactList = Database.query(contactQuery);
                        for (Contact role : contactList) {
                            String selectedPhoneNumber = String.valueOf(role.get(phoneField));
                            if (String.isNotBlank(selectedPhoneNumber)) {
                                contact.put('Name', role.Name);
                                contact.put('Id', role.Id);
                                for (String field : contactPhoneFields) {
                                    String value = String.valueOf(role.get(field));
                                    if (String.isNotBlank(value)) {
                                        value = value.startsWith('+') ? value : '+' + value;
                                    }
                                    contact.put(field, value);
                                }
                                contactDetails.add(contact);
                                contact = new Map<String, String>();
                            }
                        }
                        recordDetails.put('Contacts', contactDetails);
                    }
                }
                else if (objectName == 'Account') {
                    List<Account> accountList = accountRelatedContactRecords(recordId,contactPhoneFields,accountPhoneFields);
                    if(!accountList[0].contacts.isEmpty()){
                        recordDetails = combinedResult(accountPhoneFields,accountList,phoneField,contactPhoneFields);
                    }else{
                        if(!accountPhoneFields.isEmpty()){
                            for (String field : accountPhoneFields) {
                                Object val = accountList[0].get(field);
                                if (val != null) {
                                    phoneFieldMap.put(field, String.valueOf(val).startsWith('+') ? String.valueOf(val) : '+' + String.valueOf(val));
                                } else {
                                    phoneFieldMap.put(field, null);
                                }
                            }
                            recordDetails.put('PhoneFields', phoneFieldMap);
                            recordDetails.put('Phone', phoneFieldMap.get(phoneField)); // optionally include main phone
                            recordDetails.put('Name', accountList[0].Name);
                        }
                    }
                }
            }
            else if (Schema.getGlobalDescribe().containsKey(objectName)) {
                objectName = objectName != null ? objectName.trim() : '';
                if (!Schema.getGlobalDescribe().containsKey(objectName)) {
                    throw new AuraHandledException('Invalid or unauthorized object name: ' + objectName);
                }
                Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
                List<String> phoneFields = new List<String>();
                for (String fieldName : fieldMap.keySet()) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                    if (fieldDescribe.getType() == Schema.DisplayType.PHONE) {
                        phoneFields.add(fieldName);
                    }
                }
                String queryFields = 'Name';
                for (String field : phoneFields) {
                    queryFields += ', ' + field;
                }
                String safeObjectName = Schema.getGlobalDescribe().get(objectName).getDescribe().getName();
                String query = 'SELECT ' + queryFields + ' FROM ' + String.escapeSingleQuotes(safeObjectName) + ' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1 ';

                // String query = 'SELECT ' + queryFields + ' FROM ' + objectName + ' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1 ';
                SObject record = Database.query(query); //NOPMD
                if (record != null) {
                    recordDetails.put('Name', (String) record.get('Name'));
                    String selectedPhone = (String) record.get(phoneField);
                    recordDetails.put('Phone', selectedPhone != null ? (selectedPhone.startsWith('+') ? selectedPhone : '+' + selectedPhone) : null);
                    Map<String, String> phoneValues = new Map<String, String>();
                    for (String field : phoneFields) {
                        String phone = (String) record.get(field);
                        if (phone != null) {
                            phoneValues.put(field, phone.startsWith('+') ? phone : '+' + phone);
                        } else {
                            phoneValues.put(field, null);
                        }
                    }
                    recordDetails.put('PhoneFields', phoneValues);
                }
            }

            return recordDetails;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching record details: ' + e.getMessage());
        }
    }

    /**
     * @description Schedules an SMS using the Twilio service.
     *
     * @param recordId The Id of the message record
     * @param phoneNumber The recipient's phone number.
     * @param smsBody The body of the SMS message.
     * @param scheduledTime The time at which the SMS should be sent.
     * @return The scheduled message record created in Salesforce.
     * @throws AuraHandledException if there's an error during the Twilio call or message query.
     */
    @AuraEnabled
    public static SmartMsg__Message__c scheduleSMS(String recordId, String phoneNumber, String smsBody, String scheduledTime) {
        if (Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        Id scheduledMessage = TwilioServices.scheduleSMS(recordId, phoneNumber, smsBody, scheduledTime);
        try {
            List<SmartMsg__Message__c> message = [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__Type__c, SmartMsg__Channel__c, SmartMsg__Outgoing__c, CreatedDate, SmartMsg__Delivery_Status__c, SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE Id = :scheduledMessage WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
            //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
            return message.size() > 0 ? message[0] : null;
        } catch (Exception e) {
            throw new AuraHandledException('Error scheduling SMS: ' + e.getMessage());
        }
    }
    /**
     * @description Creates a scheduled message record in Salesforce.
     *
     * @param smsparams A map containing SMS parameters (phoneNumber, smsBody, status, scheduledTime).
     * @return The ID of the created scheduled message record.
     * @throws AuraHandledException if the user does not have permission to create the message or if there's an error during the insert operation.
     */
    @AuraEnabled(cacheable=false)
    public static Id createScheduleRecord(Map<String, Object> smsparams) {
        if (Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        try {
            String phoneNumber = (String) smsparams.get('phoneNumber');
            String smsBody = (String) smsparams.get('smsBody');
            String status = (String) smsparams.get('status');
            String scheduledTime = (String) smsparams.get('scheduledTime');
            Id templateId = (Id) smsparams.get('templateId');
            Id relatedRecordId = (Id) smsparams.get('relatedRecordId');

            // If templateId and relatedRecordId are provided, do placeholder replacement
            if(templateId != null && relatedRecordId != null) {
                SmartMsg__Message_Template__c template = [SELECT Id, SmartMsg__Object_Name__c FROM SmartMsg__Message_Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED LIMIT 1];
                smsBody = replacePlaceholders(template.SmartMsg__Object_Name__c,relatedRecordId,smsBody);
            }
            if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create this message.');
            }
            DateTime resultDateTime;
            if (scheduledTime != null) {
                String inputString = scheduledTime;
                resultDateTime = DateTime.ValueofGmt(inputString.replace('T', ' '));
            }
            SmartMsg__Message__c scheduledMessage = new SmartMsg__Message__c(
                SmartMsg__To_Number__c = phoneNumber,
            SmartMsg__Message_Body__c = smsBody,
            SmartMsg__Channel__c = 'SMS',
            SmartMsg__Delivery_Status__c = status,
            SmartMsg__Type__c = 'Outbound',
            SmartMsg__Outgoing__c = true,
            SmartMsg__Scheduled_Date_Time__c = resultDateTime
                );
            if (!Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__To_Number__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Message_Body__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Channel__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Delivery_Status__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Type__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Outgoing__c.isCreateable() ||
            !Schema.sObjectType.SmartMsg__Message__c.fields.Scheduled_Date_Time__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create one or more fields on this message.');
            }
            insert scheduledMessage;
            //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
            return scheduledMessage.ID;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating scheduled message record: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves a single message record by its ID and customer phone number.
     *
     * @param recordId The ID of the message record.
     * @param customerPhone The customer's phone number.
     * @return The message record if found.
     */
    @AuraEnabled(cacheable=true)
    public static SmartMsg__Message__c getSingleMessage(String recordId, String customerPhone){
        if(customerPhone.startsWith('+')){
            customerPhone = customerPhone.substring(1);
        }
        customerPhone = customerPhone.substring(1);
        String phoneFilter = '%' + customerPhone + '%';
        List<SmartMsg__Message__C> messageList = [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__Channel__c, SmartMsg__To_Number__c, SmartMsg__Media_Url__c, SmartMsg__Failed_Reason__c, SmartMsg__Retry_Count__c,SmartMsg__FilesBiSync_Related_Folder_Ids__c, SmartMsg__Delivery_Status__c, SmartMsg__is_Bulk__c, CreatedDate, SmartMsg__Type__c, SmartMsg__File_Content__c,SmartMsg__Location_Address__c,SmartMsg__Location_Latitude__c,SmartMsg__Location_Longitude__c,SmartMsg__Location_Name__c,SmartMsg__Location_Link__c, SmartMsg__File_Name__c, SmartMsg__Sent_Date_and_Time__c, CreatedBy.Name, SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__C WHERE Id = :recordId AND SmartMsg__To_Number__c LIKE :phoneFilter WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
        if(!messageList.isEmpty()){
            return messageList[0];
        }
        else{
            throw new AuraHandledException('Failed to retrieve the message');
        }
    }

    /**
     * @description Sends a WhatsApp text message.
     *
     * @param messageContent The content of the WhatsApp message.
     * @param toPhone The recipient's phone number.
     * @return The message record created in Salesforce.
     * @throws AuraHandledException if there's an error during the WhatsApp service call or message query.
     */
    @AuraEnabled
    public static SmartMsg__Message__c sendTextMessage(String messageContent, String toPhone){
        return sendTextMessageWithFrom(messageContent, toPhone, null);
    }

    /**
     * @description Sends a WhatsApp text message, with optional from number for Twilio WhatsApp.
     * @param messageContent The content of the message.
     * @param toPhone The recipient's phone number.
     * @param fromNumber Optional. When Twilio WhatsApp is active, use this as the from number (e.g. +1234567890). Ignored for Meta.
     * @return The message record.
     */
    @AuraEnabled
    public static SmartMsg__Message__c sendTextMessageWithFrom(String messageContent, String toPhone, String fromNumber){
        if (Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        // SmartMsg__Message__c message = whatsAppServices.sendTextMessage(messageContent, toPhone);
        SmartMsg__Message__c message = null;
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            message = whatsAppServices.sendTextMessage(messageContent, toPhone);
        } else if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            message = TwilioWhatsAppServices.sendTextMessage(messageContent, '+' + toPhone, fromNumber);
        }
        List<SmartMsg__Message__c> messages = [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__To_Number__c, SmartMsg__Message_Type__c, SmartMsg__Channel__c, SmartMsg__Customer_Name__c, SmartMsg__Type__c, SmartMsg__Delivery_Status__c, SmartMsg__Outgoing__c, SmartMsg__Scheduled_Date_Time__c, CreatedDate FROM SmartMsg__Message__c WHERE Id = :message.Id WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
        //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
        return messages.size() > 0 ? messages[0] : null;
    }

    /**
     * @description Sends a WhatsApp template message via the active provider (Meta or Twilio).
     * Routes to WhatAppChatServices (Meta) or WhatsappChatComponentController.sendTwilioTemplateMessage (Twilio), same pattern as sendTextMessage.
     * @param recordId Related record Id for placeholder replacement.
     * @param templateId Message template Id.
     * @param phoneNumber Recipient phone number.
     * @param headerMediaURL Header media URL (used for Meta templates).
     * @param fileName File name (used for Meta templates).
     * @return The sent message record.
     */
    @AuraEnabled
    public static SmartMsg__Message__c sendTemplateMessage(String recordId, String templateId, String phoneNumber, String headerMediaURL, String fileName) {
        if (Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        SmartMsg__Message__c result = null;
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            result = WhatAppChatServices.constructPayload(recordId, templateId, phoneNumber, headerMediaURL, fileName);
        } else if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            result = WhatsappChatComponentController.sendTwilioTemplateMessage(recordId, templateId, phoneNumber, null);
        } else {
            throw new AuraHandledException('No active WhatsApp provider (Meta or Twilio) configured.');
        }
        //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
        return result;
    }

    /**
     * @description Sends a WhatsApp template message with optional from number for Twilio WhatsApp.
     * @param recordId The related record Id for merge fields.
     * @param templateId The Id of the message template.
     * @param phoneNumber The recipient phone number.
     * @param headerMediaURL Optional header media URL for the template.
     * @param fileName Optional file name for the template header.
     * @param fromNumber Optional. When Twilio WhatsApp is active, the from number to use (e.g. from dropdown).
     * @return The created SmartMsg__Message__c record for the sent template message.
     */
    @AuraEnabled
    public static SmartMsg__Message__c sendTemplateMessageWithFrom(String recordId, String templateId, String phoneNumber, String headerMediaURL, String fileName, String fromNumber) {
        if (Test.isRunningTest() && testForceSubscriptionExpired) {
            throw new AuraHandledException('Subscription expired');
        }
        if (Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        SmartMsg__Message__c result = null;
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            result = WhatAppChatServices.constructPayload(recordId, templateId, phoneNumber, headerMediaURL, fileName);
        } else if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            result = WhatsappChatComponentController.sendTwilioTemplateMessage(recordId, templateId, phoneNumber, fromNumber);
        } else {
            throw new AuraHandledException('No active WhatsApp provider (Meta or Twilio) configured.');
        }
        //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
        return result;
    }

    /**
     * @description Creates a scheduled WhatsApp message record in Salesforce.
     *
     * @param whatsappparams A map containing WhatsApp parameters (phoneNumber, messageBody, status, scheduledTime).
     * @return The created scheduled message record.
     * @throws AuraHandledException if the user does not have permission to create the message or if there's an error during the insert operation.
     */
    @AuraEnabled(cacheable=false)
    public static SmartMsg__Message__c createWhatsAppScheduleRecord(Map<String, Object> whatsappparams) {
        try {
            String phoneNumber = (String) whatsappparams.get('phoneNumber');
            String messageBody = (String) whatsappparams.get('messageBody');
            String status = (String) whatsappparams.get('status');
            String scheduledTime = (String) whatsappparams.get('scheduledTime');
            Id templateId = (Id) whatsappparams.get('templateId');
            Id relatedRecordId = (Id) whatsappparams.get('relatedRecordId');
            // If templateId and relatedRecordId are provided, do placeholder replacement
            if(templateId != null && relatedRecordId != null) {
                SmartMsg__Message_Template__c template = [SELECT Id, SmartMsg__Object_Name__c
                                                              FROM SmartMsg__Message_Template__c
                                                              WHERE Id = :templateId WITH SECURITY_ENFORCED
                                                              LIMIT 1];
                messageBody = replacePlaceholders(template.SmartMsg__Object_Name__c,relatedRecordId,messageBody);
            }
            if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create this message.');
            }
            DateTime myDate;
            if (scheduledTime != null) {
                myDate = (DateTime)JSON.deserialize('"' + scheduledTime + '"', DateTime.class);
            }
            SmartMsg__Message__c scheduledMessage = new SmartMsg__Message__c(
                SmartMsg__To_Number__c = phoneNumber,
            SmartMsg__Message_Body__c = messageBody,
            SmartMsg__Channel__c = 'WhatsApp',
            SmartMsg__Delivery_Status__c = status,
            SmartMsg__Type__c = 'Outbound',
            SmartMsg__Outgoing__c = true,
            SmartMsg__Scheduled_Date_Time__c = myDate
                );
            if (!Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__To_Number__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Message_Body__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Channel__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Delivery_Status__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Type__c.isCreateable() ||
                !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Outgoing__c.isCreateable() ||
            !Schema.sObjectType.SmartMsg__Message__c.fields.SmartMsg__Scheduled_Date_Time__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create one or more fields on this message.');
            }
            insert scheduledMessage;
            scheduledMessage = [SELECT Id, CreatedDate, SmartMsg__To_Number__c, SmartMsg__Message_Body__c, SmartMsg__Channel__c, SmartMsg__Delivery_Status__c, SmartMsg__Type__c, SmartMsg__Outgoing__c, SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE Id = :scheduledMessage.Id WITH SECURITY_ENFORCED];
            //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
            return scheduledMessage;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating message record: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all message templates.
     *
     * @param objectApiName The API Name of Object
     * @param templateType The type of the template
     * @return A list of all message templates.
     */
    @AuraEnabled(cacheable=true)
    public static List<SmartMsg__Message_Template__c> getTemplates(String objectApiName,String templateType) {
        try {
            String channel = templateType;
            if ('WhatsApp'.equalsIgnoreCase(templateType)) {
                channel = getActiveChannel();
            }
            List<SmartMsg__Message_Template__c> allTemplate = [SELECT Id, SmartMsg__Channel__c, SmartMsg__Template_API_Name__c, SmartMsg__Status__c, SmartMsg__Template_Name__c, SmartMsg__Header__c, SmartMsg__Body__c, SmartMsg__Footer__c, SmartMsg__Button__c, SmartMsg__Object_Name__c, SmartMsg__WhatsApp_Template_ID__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Channel__c = :channel AND (SmartMsg__Object_Name__c = :objectApiName OR SmartMsg__Object_Name__c = NULL) AND SmartMsg__Status__c = 'Approved' WITH SECURITY_ENFORCED LIMIT 100];
            return allTemplate;
        } catch (Exception e) {
            throw new AuraHandledException('Error Fetching Message Template Records ' + e.getMessage());
        }
    }

    /**
     * @description Returns the active WhatsApp provider channel for template filtering.
     * Meta active -> 'WhatsApp', Twilio WhatsApp active -> 'Twilio WhatsApp'.
     * @return string
     */
     @AuraEnabled(cacheable=true)
     public static String getActiveChannel(){
        // if (SmartMsg__TwilioConfiguration__c.getInstance()?.SmartMsg__Active__c == true) {
        //     return 'SMS';
        // }
         if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
             return 'WhatsApp';
         }
         if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
             return 'Twilio WhatsApp';
         }
         return 'WhatsApp';
     }

    /**
     *@description Creates a new message record with the provided details.
     *
     * @param phoneNumber The recipient's phone number.
     * @param smsBody The body of the SMS message.
     * @param status The delivery status of the message.
     * @param channel The communication channel (e.g., SMS, WhatsApp).
     * @param fileData JSON string containing file data (base64 encoded).
     * @param templateId ID of the message template to be used.
     * @param relatedRecordId ID of the related record for template processing.
     * @param relatedObjectId ID of the related object.
     * @param publicMediaUrl Public URL for the media file.
     * @param publicFileName Name of the public media file.
     * @return The newly created message record.
     */
    @AuraEnabled
    public static SmartMsg__Message__c createMessageRecord(String phoneNumber, String smsBody, String status, String channel, String fileData, Id templateId, Id relatedRecordId, Id relatedObjectId, String publicMediaUrl,String publicFileName) {
        if ('SMS'.equalsIgnoreCase(channel) && Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        try {
            String formattedPhoneNumber = formatPhoneNumber(phoneNumber);
            // Process message template if template is selected
            String processedMessage = smsBody;
            if(templateId != null && relatedRecordId != null) {
                SmartMsg__Message_Template__c template = [SELECT Id, SmartMsg__Object_Name__c FROM SmartMsg__Message_Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED LIMIT 1];
                processedMessage = replacePlaceholders(template.SmartMsg__Object_Name__c,relatedRecordId,smsBody);
            }
            // Step 1: Insert ContentVersion first (assign a dummy User as parent)
            Id dummyParentId = UserInfo.getUserId(); // Assigning to the current user temporarily
            ContentVersion cv;
            String fileName = '';
            String contentDocumentId = '';
            Boolean hasFile = false;
            Boolean hasPublicUrl = String.isNotBlank(publicMediaUrl);
            if (fileData != null && fileData != '' && fileData != '[]') {
                List<Object> filesList = (List<Object>) JSON.deserializeUntyped(fileData);
                if (filesList.size() == 1) {
                    hasFile = true;
                    Map<String, Object> fileDataMap = (Map<String, Object>) filesList[0];
                    String base64Data = (String) fileDataMap.get('base64');
                    fileName = (String) fileDataMap.get('filename');
                    if (!Schema.sObjectType.ContentVersion.isCreateable() && !Schema.sObjectType.ContentVersion.isUpdateable()) {
                        throw new AuraHandledException('You do not have permission to create this message.');
                    } else{
                        cv = new ContentVersion();
                        cv.ContentLocation = 'S'; // 'S' for Salesforce storage
                        cv.PathOnClient = fileName;
                        cv.Title = 'Outbound Media ' + Datetime.now();
                        cv.VersionData = EncodingUtil.base64Decode(base64Data);
                        cv.FirstPublishLocationId = dummyParentId; // Temporarily link to User
                        if (!CommonUtil.hasFLS(cv)) {
                            throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                        }else{
                            insert cv;
                        }
                        // Query ContentDocumentId
                        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH SECURITY_ENFORCED];
                        contentDocumentId = cv.ContentDocumentId;
                    }
                }
            }
            // Step 2: Insert the SMS record
            SmartMsg__Message__c newMessage = new SmartMsg__Message__c();
            newMessage.SmartMsg__To_Number__c = formattedPhoneNumber;
            newMessage.SmartMsg__Message_Body__c = processedMessage;
            newMessage.SmartMsg__Delivery_Status__c = status;
            newMessage.SmartMsg__Type__c = 'Outbound';
            newMessage.SmartMsg__channel__c = channel;
            newMessage.SmartMsg__Is_Outgoing__c = true;
            newMessage.SmartMsg__is_Bulk__c = true;
            newMessage.SmartMsg__Sent_Date_and_Time__c = Datetime.now();
            newMessage.SmartMsg__Related_Record_Id__c = relatedObjectId;
            if (hasFile) {
                newMessage.SmartMsg__Media_Url__c = contentDocumentId;
                newMessage.SmartMsg__File_Name__c = fileName;
                newMessage.SmartMsg__Media_File__c = true;
            }
            else if (hasPublicUrl) {
                newMessage.SmartMsg__Media_Url__c = publicMediaUrl;
                newMessage.SmartMsg__File_Name__c = publicFileName;
                newMessage.SmartMsg__Media_File__c = true; // Still mark as media
            }
            insert newMessage;
            // Step 3: Link ContentDocument to Message__c (actual record)
            if (hasFile) {
                if (!Schema.sObjectType.ContentDocumentLink.isCreateable() && !Schema.sObjectType.ContentDocumentLink.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                } else{
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = contentDocumentId;
                    cdl.LinkedEntityId = newMessage.Id;
                    cdl.ShareType = 'V'; // Viewer access
                    if (!CommonUtil.hasFLS(cdl)) {
                        throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                    }else{
                        insert cdl;
                    }
                }
            }
            // Query the updated SMS record
            List<SmartMsg__Message__c> messages = [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__Channel__c, SmartMsg__To_Number__c, SmartMsg__Media_Url__c, SmartMsg__Failed_Reason__c, SmartMsg__Retry_Count__c,SmartMsg__FilesBiSync_Related_Folder_Ids__c,SmartMsg__Delivery_Status__c, SmartMsg__is_Bulk__c, SmartMsg__Pinned__c, SmartMsg__Starred__c, CreatedDate, SmartMsg__Type__c, SmartMsg__File_Content__c, SmartMsg__File_Name__c,SmartMsg__Message_Type__c, SmartMsg__Sent_Date_and_Time__c, CreatedBy.Name,SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE Id = :newMessage.Id WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
            //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
            return messages.size() > 0 ? messages[0] : null;

        } catch (Exception e) {
            //TransactionErrorLogger.logException(e, 'ChatComponentController', 'createMessageRecord', null);
            throw new AuraHandledException('Error creating message record: ' + e.getMessage());
        }
    }

    /**
         * @description generatePublicUrlForContentDocument
         * @param  contentDocumentId contentDocumentId
         * @return String
         */
    @AuraEnabled
    public static String generatePublicUrlForContentDocument(Id contentDocumentId) {
        try {
            // Get the latest ContentVersion for the given ContentDocument
            ContentVersion version = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId ORDER BY CreatedDate DESC LIMIT 1];
            ContentDistribution distribution = new ContentDistribution();
            if (!Schema.sObjectType.ContentDistribution.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create this message.');
            }else{
                // Create the ContentDistribution using the ContentVersionId
                distribution.Name = 'WA Media Public Link ' + DateTime.now().format();
                distribution.ContentVersionId = version.Id;
                distribution.PreferencesAllowViewInBrowser = true;
                distribution.PreferencesAllowOriginalDownload = true;
                distribution.PreferencesNotifyOnVisit = false;
                if (!CommonUtil.hasFLS(distribution)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                }else{
                    insert distribution;
                }
            }
            // Retrieve the public URL
            distribution = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id = :distribution.Id WITH SECURITY_ENFORCED];

            return distribution.ContentDownloadUrl;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Replaces placeholders in the given message text with actual field values from the specified record.
     * @param objectName The API name of the Salesforce object.
     * @param recordId The ID of the record from which to fetch field values.
     * @param messageText The message text containing placeholders to be replaced.
     * @return The message text with placeholders replaced by actual field values.
     */
    public static String replacePlaceholders(String objectName, String recordId, String messageText) {
        if (String.isBlank(messageText) || String.isBlank(recordId)) {
            return messageText;
        }
        try {
             String sanitizedRecordId = String.escapeSingleQuotes(recordId);
             String actualObjectName = Id.valueOf(sanitizedRecordId).getSObjectType().getDescribe().getName();

                if (!Schema.getGlobalDescribe().containsKey(actualObjectName)) {
                    throw new AuraHandledException('Invalid or unauthorized object type: ' + actualObjectName);
                }
            Pattern pattern = Pattern.compile('\\{!(\\w+)\\}');
            Matcher matcher = pattern.matcher(messageText);
            Set<String> fieldNames = new Set<String>();
            while (matcher.find()) {
                fieldNames.add(matcher.group(1));
            }
            if (fieldNames.isEmpty()) {
                return messageText;
            }
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(actualObjectName).getDescribe().fields.getMap();
            List<String> validFieldNames = new List<String>();
            for (String fieldName : fieldNames) {
                if (fieldMap.containsKey(fieldName)) {
                    validFieldNames.add(fieldName);
                } else {
                    throw new AuraHandledException('Invalid field: ' + fieldName + ' for object: ' + actualObjectName);
                }
            }
            SObject record;
            if(Schema.getGlobalDescribe().get(actualObjectName).getDescribe().isCreateable()){
                String safeObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
                String query = 'SELECT ' + String.join(validFieldNames, ',') +' FROM ' + safeObjectName +' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1';
                record = Database.query(query);//NOPMD
            }
            if (record == null) {
                throw new AuraHandledException('No record found for Id: ' + recordId + ' in object: ' + actualObjectName);
            }
            matcher.reset();
            while (matcher.find()) {
                String placeholder = matcher.group();
                String fieldName = matcher.group(1);
                String fieldValue = String.valueOf(record.get(fieldName));
                messageText = messageText.replace(placeholder, fieldValue != null ? fieldValue : '');
            }
            return messageText;
        } catch(Exception e) {
            throw new AuraHandledException('Error replacing placeholders: ' + e.getMessage());
        }
    }
    /**
     * @description [brief description]
     * @param  messageId [description]
     * @param  isPinned  [description]
     */
    @AuraEnabled
    public static void updatePinStatus(Id messageId, Boolean isPinned) {

        if (isPinned == null) {
            throw new AuraHandledException('Invalid boolean value for pin status');
        }
        if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() && !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to create this message.');
        }else{
            SmartMsg__Message__c msg = [SELECT Id FROM SmartMsg__Message__c WHERE Id = :messageId WITH SECURITY_ENFORCED LIMIT 1];
            msg.SmartMsg__Pinned__c = isPinned;
            if (!CommonUtil.hasFLS(msg)) {
                throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
            }else{
                update msg;
            }
        }
    }
    /**
     * @description Updates the star status of a message.
     * @param messageId The ID of the message to update.
     * @param isStarred The new star status of the message.
     */
    @AuraEnabled
    public static void updateStarStatus(Id messageId, Boolean isStarred) {
        if (isStarred == null) {
            throw new AuraHandledException('Invalid boolean value for star status');
        }
        if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() && !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to create this message.');
        }else{
            SmartMsg__Message__c msg = [SELECT Id FROM SmartMsg__Message__c WHERE Id = :messageId WITH SECURITY_ENFORCED LIMIT 1];
            msg.SmartMsg__Starred__c = isStarred;
                update msg;
            }
        }

        
    /**
     * @description Creates or retrieves a message record for chatbot activation/deactivation.
     * @param phoneNumber The phone number associated with the chatbot.
     * @return SmartMsgResult containing the chatbot status and record information.
     */
    @AuraEnabled
    public static SmartMsgResult ensureChatbotMessage(String phoneNumber) {
        SmartMsgResult res = new SmartMsgResult();

        SmartMsg__Message__c existing;
        try {
            existing = [SELECT Id,SmartMsg__Chatbot_on_off__c FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c = :phoneNumber AND SmartMsg__Type__c = NULL AND SmartMsg__Channel__c = NULL LIMIT 1];
        } catch (QueryException e) {
            existing = null;
        }

        if (existing != null) {
            res.exists = true;
            res.recordId = existing.Id;
            res.chatBotActive = String.valueof(existing.SmartMsg__Chatbot_on_off__c);
            res.message = 'SmartMsg record already exists with chatbot ON';
            return res;
        }

        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__To_Number__c      = phoneNumber,
            SmartMsg__Chatbot_on_off__c = true
            );
        if(!hasChatbotDialogAndOptionDialogRecords()){
            msg.SmartMsg__Chatbot_on_off__c = false;
        }
        insert msg;

        res.exists = false;
        res.recordId = msg.Id;
        res.chatBotActive = String.valueof(msg.SmartMsg__Chatbot_on_off__c);
        res.message = 'New SmartMsg record created and chatbot turned ON';
        return res;
    }
    /**
     * @description Inner class to hold the result of chatbot message operations.
     */
    public class SmartMsgResult {
        /**
         * @description Indicates whether the message record already exists.
         */
        @AuraEnabled public Boolean exists;
        /**
         * @description The chatbot active status as a string.
         */
        @AuraEnabled public String chatBotActive;
        /**
         * @description The ID of the message record.
         */
        @AuraEnabled public Id recordId;
        /**
         * @description The status message describing the operation result.
         */
        @AuraEnabled public String message;
    }
}