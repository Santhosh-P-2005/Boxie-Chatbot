/**
 * @description Controller class for WhatsApp chat component functionality.
 *              Handles messaging, templates, scheduling, and record management for WhatsApp communications.
 */
public with sharing class WhatsappChatComponentController {

    /**
     * @description Retrieves all messages sent to a specific phone number.
     * @return List of messages sent to the specified phone number.
     * @throws AuraHandledException if there's an error during the query execution.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasUserPermission() {

        List<PermissionSetAssignment> permissionSetAssignments = [SELECT Id, PermissionSetId, PermissionSet.Name, AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE (PermissionSet.Name = 'WhatsApp_Chatbot_Admin' OR PermissionSet.Name = 'WhatsApp_Chatbot_User' OR PermissionSet.Name = 'WhatsApp_Chatbot_Site_User') AND AssigneeId = :UserInfo.getUserId() WITH SECURITY_ENFORCED];

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

                if (Schema.getGlobalDescribe().containsKey(objectName)) {
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

        List<SmartMsg__Message__c> messages = [SELECT SmartMsg__Business_Phone_Number__c, SmartMsg__Channel__c, CreatedById, CreatedDate, SmartMsg__Customer_Name__c, SmartMsg__Delivery_Status__c, SmartMsg__Error_Code__c, SmartMsg__ErrorMessage__c, SmartMsg__Failed_Reason__c, SmartMsg__From_Number__c, Id, SmartMsg__Image_type__c, SmartMsg__is_Bulk__c, SmartMsg__Is_Outgoing__c, SmartMsg__Is_Read__c, IsDeleted, SmartMsg__Media_File__c, SmartMsg__Media_Url__c,SmartMsg__File_Name__c, SmartMsg__Message__c, SmartMsg__Message_Body__c, SmartMsg__Message_Id__c, SmartMsg__Message_Template__c, SmartMsg__Message_Template_Body__c, SmartMsg__Message_Type__c, Name, SmartMsg__Outgoing__c, OwnerId, SmartMsg__Parent_Message_Id__c, SmartMsg__Pinned__c, SmartMsg__Reaction__c, SmartMsg__Related_Record_Id__c, SmartMsg__Response__c, SmartMsg__Retry_Count__c, SmartMsg__Scheduled_Date_Time__c, SmartMsg__Sent_At__c, SmartMsg__Sent_By_User__c, SmartMsg__Sent_Date_and_Time__c, SmartMsg__Starred__c, SystemModstamp, SmartMsg__To_Number__c, SmartMsg__Type__c,SmartMsg__Location_Address__c,SmartMsg__Location_Latitude__c,SmartMsg__Location_Longitude__c,SmartMsg__Location_Name__c,SmartMsg__Location_Link__c FROM SmartMsg__Message__c WHERE (SmartMsg__To_Number__c = :customerPhone OR SmartMsg__From_Number__c = :customerPhone) AND SmartMsg__Channel__c = 'Whatsapp' WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
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
                    List<Opportunity> opportunityList = [SELECT Id, AccountId FROM Opportunity WHERE Id =: recordId WITH SECURITY_ENFORCED LIMIT 1 ];
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
     * @param relatedRecordId Optional Id of the related record (e.g. Lead/Contact) to link the message to.
     * @return The message record created in Salesforce.
     * @throws AuraHandledException if there's an error during the WhatsApp service call or message query.
     */
    @AuraEnabled
    public static SmartMsg__Message__c sendTextMessage(String messageContent, String toPhone, Id relatedRecordId){
        if (Constants.SUBSCRIPTION_END_DATE <= String.valueOf(System.today())) {
            throw new AuraHandledException('Subscription expired');
        }
        SmartMsg__Message__c message = null;
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            message = whatsAppServices.sendTextMessage(messageContent, toPhone);
        } else if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            message = TwilioWhatsAppServices.sendTextMessage(messageContent, '+' + toPhone);
            // Twilio path returns an in-memory record only; insert it so it exists in Salesforce and can be queried.
            if (message != null && message.Id == null) {
                message.SmartMsg__Outgoing__c = true;
                if (relatedRecordId != null) {
                    message.SmartMsg__Related_Record_Id__c = relatedRecordId;
                }
                if (Schema.sObjectType.SmartMsg__Message__c.isCreateable() && CommonUtil.hasFLS(message)) {
                    insert message;
                    // Share with Guest so Twilio status callback webhook (runs as Guest) can update delivery status, same as bot (TwilioWhatsAppController).
                    WhatsAppMessageUpdateHelper.shareMessageWithGuestUserForStatusCallback(message.Id);
                }
            }
        }
        if (message == null) {
            throw new AuraHandledException('No active WhatsApp provider (Meta or Twilio) configured.');
        }
        List<SmartMsg__Message__c> messages = [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__To_Number__c, SmartMsg__Message_Type__c, SmartMsg__Channel__c, SmartMsg__Customer_Name__c, SmartMsg__Type__c, SmartMsg__Delivery_Status__c, SmartMsg__Outgoing__c, SmartMsg__Scheduled_Date_Time__c, CreatedDate FROM SmartMsg__Message__c WHERE Id = :message.Id WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC LIMIT 1];
        //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
        return messages.isEmpty() ? null : messages[0];
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
     * @description Returns the active WhatsApp provider channel for template filtering.
     * Meta active -> 'WhatsApp', Twilio WhatsApp active -> 'Twilio WhatsApp'.
     * @return string
     */
    @AuraEnabled(cacheable=true)
    public static String getActiveWhatsAppChannel(){
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            return 'WhatsApp';
        }
        if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            return 'Twilio WhatsApp';
        }
        return 'WhatsApp';
    }

    /**
     * @description Retrieves message templates for the given type. When templateType is 'WhatsApp',
     * returns only templates for the active provider (Meta -> Channel 'WhatsApp', Twilio -> Channel 'Twilio WhatsApp').
     *
     * @param objectApiName The API Name of Object
     * @param templateType The type of the template (e.g. 'WhatsApp'). For WhatsApp, channel is resolved from active provider.
     * @return A list of message templates.
     */
    @AuraEnabled(cacheable=true)
    public static List<SmartMsg__Message_Template__c> getTemplates(String objectApiName,String templateType) {
        try {
            String channel = templateType;
            if ('WhatsApp'.equalsIgnoreCase(templateType)) {
                channel = getActiveWhatsAppChannel();
            }
            List<SmartMsg__Message_Template__c> allTemplate = [SELECT Id, SmartMsg__Channel__c, SmartMsg__Template_API_Name__c, SmartMsg__Status__c, SmartMsg__Template_Name__c, SmartMsg__Header__c, SmartMsg__Body__c, SmartMsg__Footer__c, SmartMsg__Button__c, SmartMsg__Object_Name__c, SmartMsg__WhatsApp_Template_ID__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Channel__c = :channel AND (SmartMsg__Object_Name__c = :objectApiName OR SmartMsg__Object_Name__c = NULL) AND SmartMsg__Status__c = 'Approved' WITH SECURITY_ENFORCED LIMIT 100];
            return allTemplate;
        } catch (Exception e) {
            throw new AuraHandledException('Error Fetching Message Template Records ' + e.getMessage());
        }
    }

    /**
     * @description Sends a template message via the active WhatsApp provider (Meta or Twilio).
     * If Meta is active, uses Meta template API; if Twilio is active, uses Twilio Content template.
     *
     * @param recordId Related record Id for placeholder replacement.
     * @param templateId Message template Id.
     * @param phoneNumber Recipient phone number.
     * @param headerMediaURL Header media URL (used for Meta templates).
     * @param fileName File name (used for Meta templates).
     * @return The sent message record.
     */
    @AuraEnabled
    public static SmartMsg__Message__c sendTemplateMessage(String recordId, String templateId, String phoneNumber, String headerMediaURL, String fileName) {
        SmartMsg__Message__c result = null;
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            result = WhatAppChatServices.constructPayload(recordId, templateId, phoneNumber, headerMediaURL, fileName);
        } else if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            result = sendTwilioContentTemplateMessage(recordId, templateId, phoneNumber);
        } else {
            throw new AuraHandledException('No active WhatsApp provider (Meta or Twilio) configured.');
        }
        //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
        return result;
    }

    /**
     * @description Public entry point for sending a template via Twilio only (no from number). Used by ChatComponentController when Twilio WhatsApp is the active provider.
     * @param recordId The record Id used to resolve merge fields in the template body.
     * @param templateId The Id of the SmartMsg__Message_Template__c record.
     * @param phoneNumber The recipient phone number.
     * @return The created SmartMsg__Message__c record for the sent message.
     */
    public static SmartMsg__Message__c sendTwilioTemplateMessage(String recordId, String templateId, String phoneNumber) {
        return sendTwilioContentTemplateMessage(recordId, templateId, phoneNumber, null);
    }

    /**
     * @description Sends a Twilio template message with optional from number (e.g. from chat component dropdown).
     * @param recordId The record Id used to resolve merge fields in the template body.
     * @param templateId The Id of the SmartMsg__Message_Template__c record.
     * @param phoneNumber The recipient phone number.
     * @param fromNumber Optional. When provided, used as the From number; otherwise uses default from settings.
     * @return The created SmartMsg__Message__c record for the sent message.
     */
    public static SmartMsg__Message__c sendTwilioTemplateMessage(String recordId, String templateId, String phoneNumber, String fromNumber) {
        return sendTwilioContentTemplateMessage(recordId, templateId, phoneNumber, fromNumber);
    }

    /**
     * @description Sends a Twilio Content template message (no from number). Builds ContentVariables from template body (with placeholder replacement) and options.
     * @param recordId The record Id used to resolve merge fields in the template body.
     * @param templateId The Id of the SmartMsg__Message_Template__c record.
     * @param phoneNumber The recipient phone number.
     * @return The created SmartMsg__Message__c record for the sent message.
     */
    private static SmartMsg__Message__c sendTwilioContentTemplateMessage(String recordId, String templateId, String phoneNumber) {
        return sendTwilioContentTemplateMessage(recordId, templateId, phoneNumber, null);
    }

    /**
     * @description Sends a Twilio Content template message with optional from number (from chat component dropdown). Builds ContentVariables and calls Twilio Content API.
     * @param recordId The record Id used to resolve merge fields in the template body.
     * @param templateId The Id of the SmartMsg__Message_Template__c record.
     * @param phoneNumber The recipient phone number.
     * @param fromNumberParam Optional. When provided, used as the From number; otherwise uses default from settings.
     * @return The created SmartMsg__Message__c record for the sent message.
     */
    private static SmartMsg__Message__c sendTwilioContentTemplateMessage(String recordId, String templateId, String phoneNumber, String fromNumberParam) {
        SmartMsg__Message_Template__c template = [SELECT Id, SmartMsg__Body__c, SmartMsg__Button__c, SmartMsg__WhatsApp_Template_ID__c, SmartMsg__Object_Name__c, SmartMsg__List_Picker_With_Description__c
                                                   FROM SmartMsg__Message_Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED LIMIT 1];
        String contentSid = template.SmartMsg__WhatsApp_Template_ID__c;
        if (String.isBlank(contentSid)) {
            throw new AuraHandledException('Template does not have a Twilio Content SID.');
        }
        String bodyText = String.isNotBlank(template.SmartMsg__Body__c) ? template.SmartMsg__Body__c : '{{1}}';
        List<String> bodyVariableValues = new List<String>();
        Boolean bodyHasMergeFields = (bodyText != null && bodyText.contains('{!'));
        if (bodyHasMergeFields && String.isNotBlank(recordId)) {
            bodyVariableValues = getMergeFieldValuesInOrder(template.SmartMsg__Object_Name__c, recordId, bodyText);
            bodyText = replacePlaceholders(template.SmartMsg__Object_Name__c, recordId, bodyText);
        } else if (String.isNotBlank(recordId) && bodyText != null && bodyText.contains('{')) {
            bodyText = replacePlaceholders(template.SmartMsg__Object_Name__c, recordId, bodyText);
        }
        List<String> optionTexts = new List<String>();
        List<String> optionDescriptions = new List<String>();
        if (String.isNotBlank(template.SmartMsg__Button__c)) {
            try {
                List<Object> buttons = (List<Object>) JSON.deserializeUntyped(template.SmartMsg__Button__c);
                for (Object b : buttons) {
                    if (b instanceof Map<String, Object>) {
                        Map<String, Object> m = (Map<String, Object>) b;
                        String text = (String) m.get('text');
                        String descriptionVal = (String) m.get('description');
                        if (String.isNotBlank(text)) {
                            if (String.isBlank(descriptionVal)) {
                                String titlePart = text;
                                String descPart = '';
                                if (text.contains(' - ')) {
                                    Integer dashIdx = text.indexOf(' - ');
                                    titlePart = text.substring(0, dashIdx).trim();
                                    descPart = text.substring(dashIdx + 3).trim();
                                } else if (text.contains('-')) {
                                    Integer dashIdx = text.indexOf('-');
                                    titlePart = text.substring(0, dashIdx).trim();
                                    descPart = text.substring(dashIdx + 1).trim();
                                }
                                optionTexts.add(titlePart);
                                optionDescriptions.add(descPart);
                            } else {
                                optionTexts.add(text);
                                optionDescriptions.add(descriptionVal != null ? descriptionVal : '');
                            }
                        } else {
                            optionTexts.add('');
                            optionDescriptions.add(descriptionVal != null ? descriptionVal : '');
                        }
                    } else if (b instanceof String) {
                        String s = (String) b;
                        String titlePart = s;
                        String descPart = '';
                        if (s.contains(' - ')) {
                            Integer dashIdx = s.indexOf(' - ');
                            titlePart = s.substring(0, dashIdx).trim();
                            descPart = s.substring(dashIdx + 3).trim();
                        } else if (s.contains('-')) {
                            Integer dashIdx = s.indexOf('-');
                            titlePart = s.substring(0, dashIdx).trim();
                            descPart = s.substring(dashIdx + 1).trim();
                        }
                        optionTexts.add(titlePart);
                        optionDescriptions.add(descPart);
                    }
                }
            } catch (Exception e) {
                // ignore malformed button JSON
            }
        }
        Boolean templateUsesListPickerWithDesc = template.SmartMsg__List_Picker_With_Description__c == true;
        String contentVariable;
        if (bodyHasMergeFields && !bodyVariableValues.isEmpty()) {
            contentVariable = buildTwilioContentVariablesFromBodyValues(bodyVariableValues, optionTexts, optionDescriptions, templateUsesListPickerWithDesc);
        } else {
            contentVariable = buildTwilioContentVariables(bodyText, optionTexts, optionDescriptions, templateUsesListPickerWithDesc);
        }
        String fromNumber = String.isNotBlank(fromNumberParam) ? (fromNumberParam.startsWith('+') ? fromNumberParam : '+' + fromNumberParam) : getTwilioWhatsAppFromNumber(phoneNumber);
        SmartMsg__Twilio_Whatsapp__c twilioSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
        String accountSid = twilioSetting.SmartMsg__Account_SID__c;
        String body = 'To=whatsapp:' + EncodingUtil.urlEncode(phoneNumber.startsWith('+') ? phoneNumber : '+' + phoneNumber, 'UTF-8') +
            '&From=whatsapp:' + EncodingUtil.urlEncode(fromNumber, 'UTF-8') +
            '&ContentSid=' + EncodingUtil.urlEncode(contentSid, 'UTF-8') +
            '&ContentVariables=' + EncodingUtil.urlEncode(contentVariable, 'UTF-8');
        // Status callback only for chatbot (TwilioWhatsAppController); manual template sends from UI do not use it.
        String endpoint = 'callout:SmartMsg__Twilio_WhatsApp/2010-04-01/Accounts/' + accountSid + '/Messages.json';
        HttpRequest req = new HttpRequest();
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setBody(body);
        Http http = new Http();
        HttpResponse response = http.send(req);
        if (response.getStatusCode() != 200 && response.getStatusCode() != 201) {
            throw new AuraHandledException('Twilio send failed: ' + response.getStatus() + ' ' + response.getBody());
        }
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        SmartMsg__Message__c messageRec = new SmartMsg__Message__c();
        messageRec.SmartMsg__From_Number__c = String.valueOf(result.get('from')).split(':')[1];
        messageRec.SmartMsg__To_Number__c = String.valueOf(result.get('to')).split(':')[1];
        messageRec.SmartMsg__Message_Body__c = bodyText;
        messageRec.SmartMsg__Delivery_Status__c = 'sent';
        messageRec.SmartMsg__Sent_Date_and_Time__c = Datetime.now();
        messageRec.SmartMsg__Message_ID__c = (String) result.get('sid');
        messageRec.SmartMsg__Channel__c = 'WhatsApp';
        messageRec.SmartMsg__Type__c = 'Outbound';
        insert messageRec;
        // No status callback / sharing for manual template sends; only chatbot uses delivery status updates.
        return [SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__To_Number__c, SmartMsg__Message_Type__c, SmartMsg__Channel__c, SmartMsg__Customer_Name__c, SmartMsg__Type__c, SmartMsg__Delivery_Status__c, SmartMsg__Outgoing__c, SmartMsg__Scheduled_Date_Time__c, CreatedDate FROM SmartMsg__Message__c WHERE Id = :messageRec.Id WITH SECURITY_ENFORCED LIMIT 1];
    }

    /**
     * @description Builds Twilio ContentVariables JSON. Supports list-picker with or without description:
     * - With description (templateListPickerWithDesc=true or any option has description): 1=body, 2=item1, 3=desc1, 4=item2, 5=desc2, ...
     * - Without description: 1=body, 2=item1, 3=item2, ...
     * @param bodyText The body text for the content variables.
     * @param optionTexts List of option text values.
     * @param optionDescriptions List of option description values.
     * @param templateListPickerWithDesc Boolean indicating if template uses list picker with description.
     * @return String JSON string containing the content variables.
     */
    private static String buildTwilioContentVariables(String bodyText, List<String> optionTexts, List<String> optionDescriptions, Boolean templateListPickerWithDesc){
        Map<String, String> vars = new Map<String, String>();
        /* Preserve real newlines so WhatsApp shows line breaks; only normalize \r */
        String bodyForVar = bodyText != null ? bodyText.replace('\r', '') : '{{1}}';
        vars.put('1', bodyForVar);
        Boolean hasAnyDescription = false;
        if (optionDescriptions != null) {
            for (String d : optionDescriptions) {
                if (String.isNotBlank(d)) {
                    hasAnyDescription = true;
                    break;
                }
            }
        }
        Boolean useListPickerWithDescription = (templateListPickerWithDesc == true) || (hasAnyDescription && optionTexts != null && optionDescriptions != null && optionDescriptions.size() == optionTexts.size() && !optionTexts.isEmpty());
        if (useListPickerWithDescription) {
            for (Integer i = 0; i < optionTexts.size(); i++) {
                Integer base = 2 + (i * 2);
                vars.put(String.valueOf(base), optionTexts[i] != null ? optionTexts[i] : '');
                vars.put(String.valueOf(base + 1), (i < optionDescriptions.size() && optionDescriptions[i] != null) ? optionDescriptions[i] : '');
            }
        } else if (optionTexts != null) {
            for (Integer i = 0; i < optionTexts.size(); i++) {
                vars.put(String.valueOf(i + 2), optionTexts[i] != null ? optionTexts[i] : '');
            }
        }
        return JSON.serialize(vars);
    }

    /**
     * @description Builds Twilio ContentVariables when body has merge fields: vars 1,2,... are the resolved merge field values only; then option vars follow.
     * @param bodyVariableValues List of resolved merge field values from the body.
     * @param optionTexts List of option text values.
     * @param optionDescriptions List of option description values.
     * @param templateListPickerWithDesc Boolean indicating if template uses list picker with description.
     * @return String JSON string containing the content variables.
     */
    private static String buildTwilioContentVariablesFromBodyValues(List<String> bodyVariableValues, List<String> optionTexts, List<String> optionDescriptions, Boolean templateListPickerWithDesc){
        Map<String, String> vars = new Map<String, String>();
        Integer bodyCount = bodyVariableValues != null ? bodyVariableValues.size() : 0;
        for (Integer i = 0; i < bodyCount; i++) {
            String val = bodyVariableValues[i] != null ? bodyVariableValues[i].replace('\r', '') : '';
            vars.put(String.valueOf(i + 1), val);
        }
        Integer nextIndex = bodyCount + 1;
        Boolean hasAnyDescription = false;
        if (optionDescriptions != null) {
            for (String d : optionDescriptions) {
                if (String.isNotBlank(d)) { hasAnyDescription = true; break; }
            }
        }
        Boolean useListPickerWithDescription = (templateListPickerWithDesc == true) || (hasAnyDescription && optionTexts != null && optionDescriptions != null && optionDescriptions.size() == optionTexts.size() && !optionTexts.isEmpty());
        if (useListPickerWithDescription && optionTexts != null) {
            for (Integer i = 0; i < optionTexts.size(); i++) {
                vars.put(String.valueOf(nextIndex), optionTexts[i] != null ? optionTexts[i] : '');
                vars.put(String.valueOf(nextIndex + 1), (i < optionDescriptions.size() && optionDescriptions[i] != null) ? optionDescriptions[i] : '');
                nextIndex += 2;
            }
        } else if (optionTexts != null) {
            for (Integer i = 0; i < optionTexts.size(); i++) {
                vars.put(String.valueOf(nextIndex + i), optionTexts[i] != null ? optionTexts[i] : '');
            }
        }
        return JSON.serialize(vars);
    }

    /**
     * @description Returns resolved values for each merge field in body, in the order they appear. Supports {!Name} and {!Account.Name}. Used when Twilio template has {{1}}, {{2}} only at merge positions.
     * @param objectName The sObject API name for the record (optional; recordId is used to resolve type).
     * @param recordId The record Id to read field values from.
     * @param bodyWithMergeFields The body string containing {!FieldName} merge fields.
     * @return List of resolved values in the order merge fields appear in bodyWithMergeFields.
     */
    private static List<String> getMergeFieldValuesInOrder(String objectName, String recordId, String bodyWithMergeFields) {
        List<String> values = new List<String>();
        if (String.isBlank(bodyWithMergeFields) || String.isBlank(recordId)) {
            return values;
        }
        try {
            String actualObjectName = Id.valueOf(recordId).getSObjectType().getDescribe().getName();
            if (!Schema.getGlobalDescribe().containsKey(actualObjectName)) {
                return values;
            }
            Pattern pattern = Pattern.compile('\\{!([^}]+)\\}');
            Matcher matcher = pattern.matcher(bodyWithMergeFields);
            List<String> mergeFieldNamesInOrder = new List<String>();
            while (matcher.find()) {
                mergeFieldNamesInOrder.add(matcher.group(1).trim());
            }
            if (mergeFieldNamesInOrder.isEmpty()) {
                return values;
            }
            Set<String> uniqueNames = new Set<String>(mergeFieldNamesInOrder);
            String queryFields = String.join(new List<String>(uniqueNames), ',');
            String query = 'SELECT ' + queryFields + ' FROM ' + actualObjectName + ' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1';
            SObject record = Database.query(query);
            if (record == null) {
                return values;
            }
            for (String fieldName : mergeFieldNamesInOrder) {
                Object val = getMergeFieldValue(record, fieldName);
                values.add(val != null ? String.valueOf(val) : '');
            }
        } catch (Exception e) {
            // return empty list on any error
        }
        return values;
    }

    /**
     * @description Resolves a merge field value from an SObject (supports dot notation for related fields).
     * @param record The SObject to read from.
     * @param fieldName The field or path (e.g. Account.Name).
     * @return The field value or null.
     */
    private static Object getMergeFieldValue(SObject record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) {
            return null;
        }
        if (fieldName.contains('.')) {
            List<String> parts = fieldName.split('\\.');
            SObject current = record;
            for (Integer i = 0; i < parts.size() - 1; i++) {
                current = current.getSObject(parts[i]);
                if (current == null) {
                    return null;
                }
            }
            return current.get(parts[parts.size() - 1]);
        }
        return record.get(fieldName);
    }

    /**
     * @description Returns the Twilio WhatsApp from number (custom setting or last message).
     * @param toPhone The recipient phone number used to look up last message if needed.
     * @return The from number including country code.
     */
    private static String getTwilioWhatsAppFromNumber(String toPhone) {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
        if (twilioSetting != null && String.isNotBlank(twilioSetting.SmartMsg__Twilio_Phone_Number__c)) {
            String p = twilioSetting.SmartMsg__Twilio_Phone_Number__c.trim();
            return p.startsWith('+') ? p : '+' + p;
        }
        List<SmartMsg__Message__c> lastMsg = [SELECT SmartMsg__From_Number__c FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c = :toPhone AND SmartMsg__Channel__c = 'WhatsApp' ORDER BY CreatedDate DESC LIMIT 1];
        if (!lastMsg.isEmpty() && String.isNotBlank(lastMsg[0].SmartMsg__From_Number__c)) {
            return lastMsg[0].SmartMsg__From_Number__c.startsWith('+') ? lastMsg[0].SmartMsg__From_Number__c : '+' + lastMsg[0].SmartMsg__From_Number__c;
        }
        throw new AuraHandledException('Twilio WhatsApp from number not found. Set Twilio_Phone_Number__c or send a message first.');
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
        try {
            String formattedPhoneNumber = formatPhoneNumber(phoneNumber);
            // Process message template if template is selected
            String processedMessage = smsBody;
            if(templateId != null && relatedRecordId != null) {
                SmartMsg__Message_Template__c template = [SELECT Id, SmartMsg__Object_Name__c
                                                          FROM SmartMsg__Message_Template__c
                                                          WHERE Id = :templateId WITH SECURITY_ENFORCED
                                                          LIMIT 1];
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
            Map<String, String> mergeNameToApiName = new Map<String, String>();
            for (String fieldName : fieldNames) {
                String apiName = findFieldApiNameCaseInsensitive(fieldMap, fieldName);
                if (apiName != null) {
                    mergeNameToApiName.put(fieldName, apiName);
                } else {
                    throw new AuraHandledException('Invalid field: ' + fieldName + ' for object: ' + actualObjectName);
                }
            }
            List<String> validFieldNames = new List<String>(mergeNameToApiName.values());
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
                String apiName = mergeNameToApiName.get(fieldName);
                String fieldValue = String.valueOf(record.get(apiName));
                messageText = messageText.replace(placeholder, fieldValue != null ? fieldValue : '');
            }
            return messageText;
        } catch(Exception e) {
            throw new AuraHandledException('Error replacing placeholders: ' + e.getMessage());
        }
    }

    /**
     * @description Finds a field API name in the map using case-insensitive match.
     * @param fieldMap Schema field map.
     * @param mergeFieldName The merge field name to resolve.
     * @return The matching API name or null.
     */
    private static String findFieldApiNameCaseInsensitive(Map<String, Schema.SObjectField> fieldMap, String mergeFieldName) {
        if (fieldMap == null || String.isBlank(mergeFieldName)) {
            return null;
        }
        if (fieldMap.containsKey(mergeFieldName)) {
            return mergeFieldName;
        }
        String lower = mergeFieldName.toLowerCase();
        for (String apiName : fieldMap.keySet()) {
            if (apiName.toLowerCase() == lower) {
                return apiName;
            }
        }
        return null;
    }

    /**
     * @description Updates the pin status of a message.
     * @param messageId The ID of the message to update.
     * @param isPinned The new pin status of the message.
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