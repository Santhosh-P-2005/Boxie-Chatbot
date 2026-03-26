/**
     * @description incoming SMScontroller class handles the Incoming SMS functionality
     */
    public with sharing class IncomingSmsController {
        // Cached Schema Lookup for Phone Fields
        public static Map<String, List<String>> phoneFieldCache;
        @AuraEnabled(cacheable=false)
        /**
         * @description Retrieves a list of incoming SMS messages.
         * @return List of SmartMsg__Message__c records representing incoming SMS messages.
         */
        public static List<SmartMsg__Message__c> getIncomingSms() {
            return [
                SELECT Id, OwnerId, IsDeleted, Name, CreatedDate, CreatedById,  
                SmartMsg__Channel__c, SmartMsg__Delivery_Status__c,
                SmartMsg__Type__c, SmartMsg__Business_Phone_Number__c, SmartMsg__Customer_Name__c, SmartMsg__Document_ID__c, 
                SmartMsg__Document_SHA256__c, SmartMsg__Document_Type__c, SmartMsg__ErrorMessage__c, SmartMsg__Error_Code__c, 
                SmartMsg__Failed_Reason__c, SmartMsg__File_Content__c, SmartMsg__File_Name__c, SmartMsg__FilesBiSync_Related_Folder_Ids__c, 
                SmartMsg__From_Number__c, SmartMsg__Image_ID__c, SmartMsg__Image_SHA256__c, SmartMsg__Image_type__c, 
                SmartMsg__Is_Outgoing__c, SmartMsg__Is_Read__c, SmartMsg__Location_Address__c, SmartMsg__Location_Latitude__c, 
                SmartMsg__Location_Link__c, SmartMsg__Location_Longitude__c, SmartMsg__Location_Name__c, SmartMsg__Media_File__c, 
                SmartMsg__Media_Url__c, SmartMsg__Message_Body__c, SmartMsg__Message_Id__c, SmartMsg__Message_Template_Body__c, 
                SmartMsg__Message_Template__c, SmartMsg__Message_Type__c, SmartMsg__Message__c, SmartMsg__Outgoing__c, SmartMsg__Parent_Message_Id__c,
                SmartMsg__Reaction__c, SmartMsg__Related_Record_Id__c, SmartMsg__Response__c, SmartMsg__Retry_Count__c, SmartMsg__Scheduled_Date_Time__c, 
                SmartMsg__Sent_At__c, SmartMsg__Sent_By_User__c, SmartMsg__Sent_Date_and_Time__c, SmartMsg__To_Number__c, SmartMsg__Video_ID__c, 
                SmartMsg__Video_SHA256__c, SmartMsg__Video_Type__c, SmartMsg__is_Bulk__c, SmartMsg__Pinned__c, SmartMsg__Starred__c From SmartMsg__Message__c 
                WHERE SmartMsg__Type__c = 'Inbound' WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        }
        
        @AuraEnabled(cacheable=true)
        /**
         * @description Retrieves a single message based on the provided record ID and customer phone number.
         * @param recordId The ID of the message record to retrieve.
         * @param customerPhone The phone number of the customer associated with the message.
         * @return A list containing the retrieved message record, or an empty list if no matching record is found.
         * @throws AuraHandledException If an error occurs while fetching the message.
         */
        public static List<SmartMsg__Message__c> getSingleMessage(String recordId, String customerPhone) {
            try {
                List<SmartMsg__Message__c> messageRecord = [SELECT Id, OwnerId, IsDeleted, Name, CreatedDate, CreatedById,  
                                                            SmartMsg__Channel__c, SmartMsg__Delivery_Status__c,
                                                            SmartMsg__Type__c, SmartMsg__Business_Phone_Number__c, SmartMsg__Customer_Name__c, SmartMsg__Document_ID__c, 
                                                            SmartMsg__Document_SHA256__c, SmartMsg__Document_Type__c, SmartMsg__ErrorMessage__c, SmartMsg__Error_Code__c, 
                                                            SmartMsg__Failed_Reason__c, SmartMsg__File_Content__c, SmartMsg__File_Name__c, SmartMsg__FilesBiSync_Related_Folder_Ids__c, 
                                                            SmartMsg__From_Number__c, SmartMsg__Image_ID__c, SmartMsg__Image_SHA256__c, SmartMsg__Image_type__c, 
                                                            SmartMsg__Is_Outgoing__c, SmartMsg__Is_Read__c, SmartMsg__Location_Address__c, SmartMsg__Location_Latitude__c, 
                                                            SmartMsg__Location_Link__c, SmartMsg__Location_Longitude__c, SmartMsg__Location_Name__c, SmartMsg__Media_File__c, 
                                                            SmartMsg__Media_Url__c, SmartMsg__Message_Body__c, SmartMsg__Message_Id__c, SmartMsg__Message_Template_Body__c, 
                                                            SmartMsg__Message_Template__c, SmartMsg__Message_Type__c, SmartMsg__Message__c, SmartMsg__Outgoing__c, SmartMsg__Parent_Message_Id__c,
                                                            SmartMsg__Reaction__c, SmartMsg__Related_Record_Id__c, SmartMsg__Response__c, SmartMsg__Retry_Count__c, SmartMsg__Scheduled_Date_Time__c, 
                                                            SmartMsg__Sent_At__c, SmartMsg__Sent_By_User__c, SmartMsg__Sent_Date_and_Time__c, SmartMsg__To_Number__c, SmartMsg__Video_ID__c, 
                                                            SmartMsg__Video_SHA256__c, SmartMsg__Video_Type__c, SmartMsg__is_Bulk__c, SmartMsg__Pinned__c, SmartMsg__Starred__c From SmartMsg__Message__c 
                                                            WHERE Id = :recordId AND SmartMsg__To_Number__c = :customerPhone WITH SECURITY_ENFORCED 
                                                            ORDER BY CreatedDate ASC LIMIT 1];
                if(!messageRecord.isEmpty()){
                    return messageRecord;
                }else{
                    return new List<SmartMsg__Message__c>();
                }
            } catch (Exception e) {
                throw new AuraHandledException('Error fetching message: ' + e.getMessage());
            }
        }
        
        @AuraEnabled
        /**
         * @description Finds contacts or accounts based on the provided list of phone numbers.
         * @param phoneNumbers List of phone numbers to search for.
         * @return A map containing the search results.
         */
        public static Map<String, Map<String, String>> findContactOrAccount(List<String> phoneNumbers) {
            Map<String, Map<String, String>> results = new Map<String, Map<String, String>>();
            // 1. Normalize Phone Numbers & Remove Duplicates
            Map<String, String> normalizedPhoneMap = new Map<String, String>();
            Set<String> searchPatterns = new Set<String>();
            for (String phoneNumber : phoneNumbers) {
                String normalized = normalizePhoneNumber(phoneNumber);
                if (String.isBlank(normalized)) {
                    continue;
                }
                searchPatterns.add(normalized); // Store only one version to avoid excessive variations
                normalizedPhoneMap.put(phoneNumber, normalized);
            }
            if (searchPatterns.isEmpty()){ return results;} // Exit early if no valid numbers
            List<List<SObject>> searchResults = performSOSLSearch(new List<String>(searchPatterns));
            return processSearchResults(phoneNumbers, normalizedPhoneMap, (List<Contact>) searchResults[0], (List<Account>) searchResults[1], (List<Lead>) searchResults[2]);
        }
        
        
        /**
         * @description Normalizes a phone number by removing non-numeric characters and adjusting the length.
         * If the phone number has a leading country code, it is removed.
         * @param phoneNumber The phone number to be normalized.
         * @return The normalized phone number.
         */
        public static String normalizePhoneNumber(String phoneNumber) {
            if (String.isBlank(phoneNumber)) {
                return null;
            }
            String incomingNumber = phoneNumber.replaceAll('[^0-9]', '');
            if (incomingNumber.length() == 11) {
                incomingNumber = incomingNumber.substring(1); // Remove leading country code (e.g., '1')
            } else if (incomingNumber.length() == 12) {
                incomingNumber = incomingNumber.substring(2); // Remove leading country code (e.g., '91')
            } else if (incomingNumber.length() == 13) {
                incomingNumber = incomingNumber.substring(3); // Remove longer prefixes
            }
            return incomingNumber.right(10);
        }
        /**
         * @description Performs SOSL search based on the provided search patterns Searches for Contacts, Accounts, and Leads with specified phone fields.
         * @param searchPatterns List of search patterns to be used in SOSL query.
         * @return List of lists of SObjects representing the search results.
         */
        public static List<List<SObject>> performSOSLSearch(List<String> searchPatterns) {
            Map<String, List<String>> phoneFieldMap = getPhoneFieldMap();
            List<String> queryParts = new List<String>();
            if (!phoneFieldMap.get('Contact').isEmpty()) {
                queryParts.add('Contact(Id, Name, ' + String.join(phoneFieldMap.get('Contact'), ', ') + ')');
            }
            if (!phoneFieldMap.get('Account').isEmpty()) {
                queryParts.add('Account(Id, Name, ' + String.join(phoneFieldMap.get('Account'), ', ') + ')');
            }
            if (!phoneFieldMap.get('Lead').isEmpty()) {
                queryParts.add('Lead(Id, Name, ' + String.join(phoneFieldMap.get('Lead'), ', ') + ')');
            }
            if (queryParts.isEmpty()){
                return new List<List<SObject>>{ new List<SObject>(), new List<SObject>(), new List<SObject>() };
            }
        String soslQuery = 'FIND {' + String.join(searchPatterns, ' OR ') + '} IN PHONE FIELDS RETURNING ' + String.join(queryParts, ', ');
        return Search.query(soslQuery);
    }
    /**
     * @description processSearchResults description.
     * @param phoneNumbers phoneNumbers description.
     * @param normalizedPhoneMap normalizedPhoneMap description.
     * @param contacts contacts description.
     * @param accounts accounts description.
     * @param leads leads description.
     * @return return description.
     */
    public  static Map<String, Map<String, String>> processSearchResults(List<String> phoneNumbers,Map<String, String> normalizedPhoneMap,List<Contact> contacts,List<Account> accounts,List<Lead> leads) {
        Map<String, Map<String, String>> results = new Map<String, Map<String, String>>();
        Map<String, Map<String, String>> recordMap = new Map<String, Map<String, String>>();
        addRecordsToMap(recordMap, contacts, 'Contact');
        addRecordsToMap(recordMap, accounts, 'Account');
        addRecordsToMap(recordMap, leads, 'Lead');
        for (String phoneNumber : phoneNumbers) {
            String normalized = normalizedPhoneMap.get(phoneNumber);
            if (String.isBlank(normalized)) {
                continue;
            }
            if (recordMap.containsKey(normalized)) {
                results.put(phoneNumber, recordMap.get(normalized));
            }
        }
        return results;
    }
    /**
     *@description Adds records to a map with normalized phone numbers as keys.
     * @param recordMap Map to store records with normalized phone numbers as keys.
     * @param records List of SObject records to be processed.
     * @param objectType Type of the SObject records.
     */
    public static void addRecordsToMap(Map<String, Map<String, String>> recordMap, List<SObject> records, String objectType) {
        List<String> phoneFields = getPhoneFieldMap().get(objectType);
        
        for (SObject record : records) {
            for (String phoneField : phoneFields) {
                String phoneValue = (String) record.get(phoneField);
                if (!String.isBlank(phoneValue)) {
                    String normalized = normalizePhoneNumber(phoneValue);
                    if (!String.isBlank(normalized)) {
                        recordMap.put(normalized, new Map<String, String>{
                            'type' => objectType,
                            'name' => (String) record.get('Name'),
                            'id' => (String) record.get('Id')
                        });
                    }
                }
            }
        }
    }
    
    
    @AuraEnabled(cacheable=true)
    /**
     * @description Returns a map of objects to their phone fields.
     * @return      A map of object names to a list of phone fields.
     */
    public static Map<String, List<String>> getPhoneFieldMap() {
        if (phoneFieldCache == null) {
            phoneFieldCache = new Map<String, List<String>>();
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            for (String objectName : new List<String>{'Contact', 'Account', 'Lead'}) {
                List<String> phoneFields = new List<String>();
                Map<String, Schema.SObjectField> fieldsMap = globalDescribe.get(objectName).getDescribe().fields.getMap();
                for (Schema.SObjectField field : fieldsMap.values()) {
                    Schema.DescribeFieldResult fieldDescribe = field.getDescribe(); // Avoid calling getDescribe twice
                    if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
                        phoneFields.add(fieldDescribe.getName());
                    }
                }
                phoneFieldCache.put(objectName, phoneFields);
            }
        }
        return phoneFieldCache;
    }
    
    @AuraEnabled
    /**
     * @description Marks a message or messages from a sender as read.
     * @param messageId The ID of the message to mark as read.
     * @param phoneNumber The phone number of the sender whose messages should be marked as read.
     * @return True if the message(s) were successfully marked as read, false otherwise.
     */
    public static boolean markAsRead(String messageId, String phoneNumber) {
        if (String.isNotBlank(messageId)) {
            // Mark a single message as read
            List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Is_Read__c FROM SmartMsg__Message__c WHERE Id = :messageId WITH SECURITY_ENFORCED LIMIT 1];
            if (!messages.isEmpty()) {
                SmartMsg__Message__c message = messages[0];
                message.SmartMsg__Is_Read__c = true;
                if (!Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                }else{
                    update message;
                    return true;
                }
            } else {
                throw new AuraHandledException('No message found with the given ID');
            }
        } else if (String.isNotBlank(phoneNumber)) {
            // Mark all messages from a sender as read
            List<SmartMsg__Message__c> messages = [
                SELECT Id, SmartMsg__Is_Read__c 
                FROM SmartMsg__Message__c 
                WHERE SmartMsg__To_Number__c = :phoneNumber AND SmartMsg__Is_Read__c = false WITH SECURITY_ENFORCED
            ];
            
            if (!messages.isEmpty()) {
                for (SmartMsg__Message__c message : messages) {
                    message.SmartMsg__Is_Read__c = true;
                }
                if (!Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                }else{
                    update messages;
                    return true;
                }
            } else {
                return false;
            }
        } else {
            throw new AuraHandledException('Either message ID or phone number must be provided');
        }
    }
    @AuraEnabled
    /**
     * @description deleteMessage
     * @param  messageId
     * @return boolean
     */
    public static boolean deleteMessage(String messageId) {
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Is_Read__c FROM SmartMsg__Message__c WHERE Id = :messageId WITH SECURITY_ENFORCED LIMIT 1];
        if (!messages.isEmpty()) {
            if (!Schema.sObjectType.SmartMsg__Message__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to create this message.');
            }else{
                delete messages;
                return true;
            }
        } else {
            throw new AuraHandledException('No message found with the given ID');
        }
    }
    @AuraEnabled(cacheable=true)
    /**
     * @description Returns the count of unread inbound messages.
     * @return Integer The count of unread inbound messages.
     */
    public static Integer getUnreadCount() {
        return [
            SELECT COUNT() 
            FROM SmartMsg__Message__c 
            WHERE SmartMsg__Type__c = 'Inbound' 
            AND SmartMsg__Is_Read__c = false WITH SECURITY_ENFORCED
        ];
    }
    
    @AuraEnabled(cacheable=true)
    /**
     * @description Retrieves information about the second last outbound message sent to a specific phone number.
     * @param phoneNumber The phone number to which the message was sent.
     * @return A map containing the phone number and the user ID of the sender.
     */
    public static Map<String, String> getLastSentUser(String phoneNumber) {
        Map<String, String> result = new Map<String, String>();
        try {
            SmartMsg__Message__c secondLastOutboundMessage = [
                    SELECT SmartMsg__To_Number__c, CreatedById FROM SmartMsg__Message__c
                    WHERE SmartMsg__Type__c = 'Outbound' WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate DESC 
                    LIMIT 1 OFFSET 1
                ];
            result.put('phoneNumber', secondLastOutboundMessage.SmartMsg__To_Number__c);
            result.put('userId', secondLastOutboundMessage.CreatedById);
            return result;
        } catch (Exception e) {
            return null;
        }
    }

    
    
}