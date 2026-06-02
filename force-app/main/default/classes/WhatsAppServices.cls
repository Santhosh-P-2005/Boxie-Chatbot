/**
* @description A class for sending and managing WhatsApp messages using the Facebook Graph API.
* This class includes methods to send text messages, send template messages, and construct payloads for template messages.
*/
public without sharing class WhatsAppServices {
    public static  String messagingProduct = 'messaging_product';
    public Contacts[] contacts;
    public Messages[] messages;
    /**
* @description A nested class representing a WhatsApp contact.
*/
    public class Contacts {
        public String input;
    }
    /**
* @description A nested class representing a WhatsApp message.
*/
    public class Messages {
        public String id;
    }
    /**
* @description Sends a text message to a specified phone number via WhatsApp.
* @param messageContent The content of the text message.
* @param toPhone The phone number to which the message will be sent.
* @return A Message__c record representing the sent message.
* @throws AuraHandledException If there are issues with permissions or if an error occurs during the HTTP request.
*/
    public static SmartMsg__Message__c sendTextMessage(String messageContent, String toPhone){
        SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        HttpRequest httpReq = new HttpRequest();
        String endpointUrl = 'callout:SmartMsg__Meta_API/v23.0/' + whatsAppCreds.SmartMsg__Phone_Number_Id__c + '/messages';
        httpReq.setEndpoint(endpointUrl);
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        httpReq.setHeader('Pragma', 'no-cache');
        httpReq.setHeader('Expires', '0');
        httpReq.setHeader('X-Content-Type-Options', 'nosniff');
        Map<String, Object> payload = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
            'recipient_type' => 'individual',
            'to' => toPhone,
            'type' => 'text',
            'text' => new Map<String, Object>{
                'preview_url' => false,
                'body' => messageContent.replace('\n', '\\n')
            }
        };
        httpReq.setBody(JSON.serialize(payload));
        Http http = new Http();
        SmartMsg__Message__c salesforceMessage = new SmartMsg__Message__c();
        try{
            HttpResponse response = http.send(httpReq);
            if( response.getStatusCode() == 200 || response.getStatusCode() == 201 ){
                whatsAppServices responseFromWA = (whatsAppServices) JSON.deserialize( response.getBody() , whatsAppServices.class);
                if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() && !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                } 
                //salesforceMessage.SmartMsg__From_Number__c = fromNumber;
                salesforceMessage.SmartMsg__Message_Body__c = messageContent;
                if(toPhone.startsWith('+')){
                    toPhone = toPhone;
                }else{
                    toPhone = '+'+toPhone;
                }
                salesforceMessage.SmartMsg__To_Number__c = toPhone;
                salesforceMessage.SmartMsg__Message_ID__c = responseFromWA.messages.get(0).id;
                salesforceMessage.SmartMsg__Message_Type__c = 'text';
                salesforceMessage.SmartMsg__Type__c = 'Outbound';
                salesforceMessage.SmartMsg__Channel__c = 'WhatsApp';
                salesforceMessage.SmartMsg__Delivery_Status__c = 'Sent';
                salesforceMessage.SmartMsg__Outgoing__c = True;
                salesforceMessage.SmartMsg__Response__c = response.getBody();
                salesforceMessage.SmartMsg__Sent_Date_and_Time__c = DateTime.now();
                if (!CommonUtil.hasFLS(salesforceMessage)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
                }
                insert salesforceMessage;

                // Increment outbound count on the active Messaging Session for this recipient.
                // This covers outbounds sent via WhatsAppServices (e.g., Agentforce replies).
                try {

                    if (toPhone != null && toPhone != '') {
                        List<SmartMsg__Messaging_Session__c> sessions = [
                            SELECT Id, SmartMsg__No_of_Outbound_Messages__c
                            FROM SmartMsg__Messaging_Session__c
                            WHERE SmartMsg__Session_status__c != 'Completed'
                            AND SmartMsg__To_Number__c = :toPhone
                            WITH SECURITY_ENFORCED
                            ORDER BY CreatedDate DESC
                            LIMIT 1
                        ];
                        if (!sessions.isEmpty()) {
                            SmartMsg__Messaging_Session__c ms = sessions[0];
                            Integer currentOutbound = ms.SmartMsg__No_of_Outbound_Messages__c == null
                                ? 0
                                : Integer.valueOf(ms.SmartMsg__No_of_Outbound_Messages__c);
                            ms.SmartMsg__No_of_Outbound_Messages__c = currentOutbound + 1;
                            update ms;
                        }
                    }
                } catch (Exception ignoreOutboundCount) {
                    // Do not block message send if the counter update fails.
                    // System.debug('Outbound count increment failed: ' + ignoreOutboundCount.getMessage());
                }
            }
            else {
                System.debug(LoggingLevel.ERROR, 'Meta WhatsApp sendTextMessage failed. Status=' + response.getStatusCode() + ' Body=' + response.getBody());
            }
        }catch(System.CalloutException ex){
            throw new AuraHandledException('CalloutException: ' + ex.getMessage());
        }catch(System.Exception ex){
            if(!Test.isRunningTest()){
                throw new AuraHandledException('CalloutException: ' + ex.getStackTraceString());
            }    
        }
        return salesforceMessage;
    }
    
    /**
* @description Sends a media message via WhatsApp.
* @param messageRecordId The ID of the message record to be updated.
* @param mediaType The type of media being sent (e.g., 'image', 'video', 'document').
* @param mediaUrl The URL of the media to be sent.
* @param toPhone The recipient's phone number.
* @param caption The caption for the media (optional).
* @param fileName The name of the file being sent (optional).
* @return The updated message record.
*/
    @AuraEnabled
    public static SmartMsg__Message__c sendMediaMessage(Id messageRecordId,String mediaType,String mediaUrl,String toPhone,String caption,String fileName) {
        SmartMsg__Meta_Configuration__c waCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        HttpRequest req = new HttpRequest();
        String endpointUrl = 'callout:SmartMsg__Meta_API/v23.0/' + waCreds.SmartMsg__Phone_Number_Id__c + '/messages';
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        // Construct WhatsApp API payload
        Map<String, Object> body = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
                'to' => toPhone,
                'type' => mediaType
                };
                    Map<String, Object> media = new Map<String, Object>{ 'link' => mediaUrl };
                        if (mediaType == 'document' && String.isNotBlank(fileName)) {
                            media.put('filename', fileName);
                        }
        if (String.isNotBlank(caption)) {
            media.put('caption', caption);
        }
        body.put(mediaType, media);
        
        req.setBody(JSON.serialize(body));
        Http http = new Http();
        HttpResponse res;
        
        try {
            res = http.send(req);
            
            // Fetch the existing message record
            SmartMsg__Message__c messageToUpdate = [
                SELECT Id, SmartMsg__Delivery_Status__c, SmartMsg__Message_Id__c
                FROM SmartMsg__Message__c
                WHERE Id = :messageRecordId WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            Integer statusCode = res.getStatusCode();
            String responseBody = res.getBody();
            String waMessageId = null;
            
            if (statusCode == 200 || statusCode == 201) {
                // Parse WhatsApp response for message ID
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                List<Object> messages = (List<Object>) jsonResponse.get('messages');
                if (messages != null && !messages.isEmpty()) {
                    Map<String, Object> msgObj = (Map<String, Object>) messages[0];
                    waMessageId = (String) msgObj.get('id');
                }
                messageToUpdate.SmartMsg__Delivery_Status__c = 'Sent';
                messageToUpdate.SmartMsg__Message_Id__c = waMessageId;
                //messageToUpdate.SmartMsg__Failed_Reason__c = null;
            } else {
                messageToUpdate.SmartMsg__Delivery_Status__c = 'Failed';
                //messageToUpdate.SmartMsg__Failed_Reason__c = responseBody;
            }
            
            update messageToUpdate;
            
            // Return updated record
            SmartMsg__Message__c updatedMsg = [
                SELECT  Id, Name, SmartMsg__Message_Body__c, SmartMsg__Channel__c, SmartMsg__To_Number__c, SmartMsg__Media_Url__c,  
                SmartMsg__Retry_Count__c,SmartMsg__FilesBiSync_Related_Folder_Ids__c,SmartMsg__Delivery_Status__c, SmartMsg__is_Bulk__c, SmartMsg__Pinned__c, SmartMsg__Starred__c,
                CreatedDate, SmartMsg__Type__c, SmartMsg__File_Content__c, SmartMsg__File_Name__c, SmartMsg__Sent_Date_and_Time__c, CreatedBy.Name,SmartMsg__Scheduled_Date_Time__c
                FROM SmartMsg__Message__c
                WHERE Id = :messageRecordId WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return updatedMsg;
            
        } catch (Exception e) {
            // On error, update record as failed
            SmartMsg__Message__c failedMsg = new SmartMsg__Message__c(
                Id = messageRecordId,
                SmartMsg__Delivery_Status__c = 'Failed'
                //SmartMsg__Failed_Reason__c = e.getMessage()
            );
            update failedMsg;
            throw new AuraHandledException('Error sending WhatsApp media message: ' + e.getMessage());
        }
    }
    
    /**
* @description Sends a media message via WhatsApp.
* @param toPhone The recipient's phone number.
* @param messageId The ID of the message record to be updated.
* @param messageBody The content of the text message.
* @return The updated message record.
*/
    /* @AuraEnabled
public static SmartMsg__Message__c sendLocationRequestMessage(String toPhone, Id messageId, String messageBody) {
SmartMsg__Meta_Configuration__c waCreds = WhatsAppProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');

String endpointUrl = 'callout:SmartMsg__Meta_API/v18.0/' + waCreds.SmartMsg__Phone_Number_Id__c + '/messages';

HttpRequest req = new HttpRequest();
req.setEndpoint(endpointUrl);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');

Map<String, Object> payload = new Map<String, Object>{
'messaging_product' => 'whatsapp',
'to' => toPhone,
'type' => 'interactive',
'interactive' => new Map<String, Object>{
'type' => 'location_request_message',
'body' => new Map<String, Object>{
'text' => messageBody
},
'action' => new Map<String, Object>{
'name' => 'send_location'
}
}
};

req.setBody(JSON.serialize(payload));

Http http = new Http();
SmartMsg__Message__c msgToUpdate = [SELECT Id, SmartMsg__Delivery_Status__c, SmartMsg__Message_Type__c FROM SmartMsg__Message__c WHERE Id = :messageId LIMIT 1];

try {
HttpResponse res = http.send(req);
if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
msgToUpdate.SmartMsg__Delivery_Status__c = 'Delivered';
msgToUpdate.SmartMsg__Message_Type__c = 'location-request';
//msgToUpdate.SmartMsg__Failed_Reason__c = null;
} else {
msgToUpdate.SmartMsg__Delivery_Status__c = 'Failed';
//msgToUpdate.SmartMsg__Failed_Reason__c = res.getBody();
}

update msgToUpdate;

return [
SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__To_Number__c, SmartMsg__Message_Type__c,
SmartMsg__Delivery_Status__c, CreatedDate
FROM SmartMsg__Message__c
WHERE Id = :messageId
LIMIT 1
];

} catch (Exception ex) {
msgToUpdate.SmartMsg__Delivery_Status__c = 'Failed';
//msgToUpdate.SmartMsg__Failed_Reason__c = ex.getMessage();
update msgToUpdate;

throw new AuraHandledException('Failed to send location request: ' + ex.getMessage());
}
}*/
    
    
    
    /**
* @description Sends a template message to a specified phone number via WhatsApp.
* @param payload The JSON payload of the template message.
* @param messageBody The body of the template message.
* @return A Message__c record representing the sent message.
* @throws AuraHandledException If there are issues with permissions or if an error occurs during the HTTP request.
*/
    @AuraEnabled
    public static SmartMsg__Message__c sendTemplateMessage(String payload, String messageBody) {
        SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        String endpointUrl = 'callout:SmartMsg__Meta_API/v23.0/' + whatsAppCreds.SmartMsg__Phone_Number_Id__c + '/messages';        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl); 
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json'); 
        req.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        req.setHeader('Pragma', 'no-cache');
        req.setHeader('Expires', '0');
        req.setHeader('X-Content-Type-Options', 'nosniff');
        req.setBody(payload);
        Http http = new Http();
        HttpResponse res;
        try{
            res = http.send(req);
        } catch(System.CalloutException ex){
            throw new AuraHandledException('CalloutException: ' + ex.getMessage() + 'StackTraceString: '+ex.getStackTraceString());
        }
        SmartMsg__Message__c salesforceMessage = new SmartMsg__Message__c();       
        if (res.getStatusCode() == 200) {
            whatsAppServices responseFromWA = (whatsAppServices) JSON.deserialize( res.getBody() , whatsAppServices.class);
            salesforceMessage.SmartMsg__Message_Body__c = messageBody;
            salesforceMessage.SmartMsg__To_Number__c = responseFromWA.contacts.get(0).input;
            salesforceMessage.SmartMsg__Message_ID__c = responseFromWA.messages.get(0).id;
            salesforceMessage.SmartMsg__Message_Type__c = 'template';
            salesforceMessage.SmartMsg__Type__c = 'Outbound';
            salesforceMessage.SmartMsg__Channel__c = 'WhatsApp';
            salesforceMessage.SmartMsg__Delivery_Status__c = 'Sent';
            salesforceMessage.SmartMsg__Outgoing__c = true;
        }
        else {
            //system.debug('res : '+res.getBody());
            salesforceMessage.SmartMsg__Response__c = res.getBody();
            //salesforceMessage.SmartMsg__Failed_Reason__c = res.getBody();
        }
        
        if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create this message.');
        }
        
        if (!CommonUtil.hasFLS(salesforceMessage)) {
            throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
        }
        insert salesforceMessage;
        List<SmartMsg__Message__c> createdTempRec = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__To_Number__c, 
                                                     SmartMsg__Message_ID__c, SmartMsg__Message_Type__c, 
                                                     SmartMsg__Type__c, SmartMsg__Channel__c, 
                                                     SmartMsg__Delivery_Status__c, SmartMsg__Outgoing__c, 
                                                     CreatedDate 
                                                     FROM SmartMsg__Message__c 
                                                     WHERE Id = :salesforceMessage.Id WITH SECURITY_ENFORCED LIMIT 1]; 
        if (createdTempRec != null && !createdTempRec.isEmpty()) {
            return createdTempRec[0]; 
        } else {
            return null; 
        }
    }
    /**
* @description Constructs the payload for a template message.
* @param recordId The Id of the message record
* @param templateId The ID of the template.
* @param phoneNumber The phone number to which the message will be sent.
* @param headerMediaURL The URL for the header media (if applicable).
* @param fileName The Name of the uploading file
* @return A Message__c record representing the constructed message.
*/
    @AuraEnabled
    public static SmartMsg__Message__c constructPayload(String recordId, String templateId, String phoneNumber, String headerMediaURL, String fileName) {
        SmartMsg__Message_Template__c template = [SELECT Id, SmartMsg__Template_API_Name__c,SmartMsg__Template_Name__c, 
                                                  SmartMsg__Header__c,SmartMsg__Body__c, SmartMsg__Footer__c,
                                                  SmartMsg__Button__c  
                                                  FROM SmartMsg__Message_Template__c 
                                                  WHERE Id = :templateId WITH SECURITY_ENFORCED];
        Map<String, Object> payloadMap = new Map<String, Object>();
        payloadMap.put('messaging_product', 'whatsapp');
        payloadMap.put('recipient_type', 'individual');
        payloadMap.put('to', phoneNumber);
        payloadMap.put('type', 'template');
        Map<String, Object> templateObject = new Map<String, Object>();
        templateObject.put('name', template.SmartMsg__Template_API_Name__c);
        templateObject.put('language', new Map<String, String>{ 'code' => 'en_US' });
        List<Object> components = new List<Object>();
        if (String.isNotBlank(template.SmartMsg__Header__c) && (template.SmartMsg__Header__c == 'Image' || template.SmartMsg__Header__c == 'Video' || template.SmartMsg__Header__c == 'Document')) {
            components.add(constructComponent('header', template.SmartMsg__Header__c, headerMediaURL,null,fileName));
        }
        if (String.isNotBlank(template.SmartMsg__Body__c) && template.SmartMsg__Body__c.contains('{')) {
            components.add(constructComponent('body', template.SmartMsg__Body__c,null,recordId,null));
        }
        if (String.isNotBlank(template.SmartMsg__Button__c)) {
            components.addAll(constructButtons(template.SmartMsg__Button__c));
        }
        templateObject.put('components', components);
        payloadMap.put('template', templateObject);
        String payload = JSON.serialize(payloadMap);
        String messageBody = (String.isNotBlank(template.SmartMsg__Body__c) && template.SmartMsg__Body__c.contains('{'))?replacePlaceholders(recordId,template.SmartMsg__Body__c):template.SmartMsg__Body__c;
        return sendTemplateMessage(payload, messagebody);
    }
    /**
* @description Constructs a component for a WhatsApp message.
* @param type The type of the component (e.g., 'text', 'header').
* @param text The text content of the component.
* @param headerUrl The URL of the header image, if applicable.
* @param recordId The Id of the message record
* @param fileName The fileName of the uploading file
* @return A map representing the constructed component.
*/
    public static Map<String, Object> constructComponent(String type, String text, String headerUrl,String recordId, String fileName) {
        Map<String, Object> component = new Map<String, Object>();
        component.put('type', type);
        List<Object> parameters = new List<Object>();
        
        if (type.equalsIgnoreCase('text')) {
            parameters.add(new Map<String, Object>{ 'type' => 'text', 'text' => text });
        } else if (type.equalsIgnoreCase('header') && String.isNotBlank(headerUrl)) {
            Map<String, Object> imageParameter = new Map<String, Object>{ 'type' => text.toLowerCase() };
                
                Map<String, Object> imageMap = new Map<String, Object>{ 'link' => headerUrl };
                    if(text.toLowerCase() == 'document'){
                        imageMap.put('filename',fileName);
                    }
            imageParameter.put(text.toLowerCase(), imageMap);
            parameters.add(imageParameter);
        } else if(type.equalsIgnoreCase('body')){
            parameters.addAll(getBodyParams(recordId,text));
        }
        component.put('parameters', parameters);
        return component;
    }
    
    /**
* @description Replaces placeholders in the message text with actual field values from the record specified by the record ID.
* 
* @param recordId The ID of the record from which to retrieve field values.
* @param messageText The message text containing placeholders in the format {!fieldName}.
* @return The message text with placeholders replaced by actual field values.
*/ 
    public static String replacePlaceholders(String recordId, String messageText) {
        String sanitizedRecordId = String.escapeSingleQuotes(recordId);        
        Pattern pattern = Pattern.compile('\\{!(\\w+)\\}');
        Matcher matcher = pattern.matcher(messageText);   
        List<String> fieldNames = new List<String>();        
        while (matcher.find()) {
            String fieldName = matcher.group(1); 
            fieldNames.add(fieldName);
        }
        
        String query = 'SELECT ';
        query += String.join(fieldNames, ',');        
        String objName = ID.valueOf(sanitizedRecordId).getSObjectType().getDescribe().getName();
        query += ' FROM ' + String.escapeSingleQuotes(objName) + ' WHERE ID = :sanitizedRecordId WITH SECURITY_ENFORCED LIMIT 1';        
        
        SObject obj = Database.query(query);        
        matcher.reset();
        while (matcher.find()) {
            String placeholder = matcher.group(); 
            String fieldName = matcher.group(1); 
            String fieldValue = String.valueOf(obj.get(fieldName));
            messageText = messageText.replace(placeholder, fieldValue);
        }
        
        return messageText;
    }
    
    /**
* @description Extracts and returns a list of parameters from the message text, replacing placeholders with actual field values from the record specified by the record ID.
* 
* @param recordId The ID of the record from which to retrieve field values.
* @param messageText The message text containing placeholders in the format {!fieldName}.
* @return A list of maps, each containing a 'type' and 'text' key with corresponding values from the record fields.
*/
    public static List<Map<String, String>> getBodyParams(String recordId, String messageText) {
        List<Map<String, String>> params = new List<Map<String, String>>();        
        String sanitizedRecordId = String.escapeSingleQuotes(recordId);        
        Pattern pattern = Pattern.compile('\\{!(\\w+)\\}');
        Matcher matcher = pattern.matcher(messageText);        
        List<String> fieldNames = new List<String>();        
        while (matcher.find()) {
            String fieldName = matcher.group(1); 
            fieldNames.add(String.escapeSingleQuotes(fieldName));
        }        
        String query = 'SELECT ';
        query += String.join(fieldNames, ',');        
        String objName = ID.valueOf(sanitizedRecordId).getSObjectType().getDescribe().getName();
        query += ' FROM ' + String.escapeSingleQuotes(objName) + ' WHERE ID = :sanitizedRecordId WITH SECURITY_ENFORCED LIMIT 1';        
        SObject obj = Database.query(query);        
        matcher.reset();
        while (matcher.find()) {
            Map<String, String> param = new Map<String, String>();
            String fieldName = matcher.group(1); 
            param.put('type', 'text');
            param.put('text', String.valueOf(obj.get(fieldName)));
            params.add(param);
        }
        
        return params;
    }
    
    /**
* @description Constructs button parameters for a WhatsApp message from a JSON string.
* @param buttonsJson The JSON string representing the buttons.
* @return A list of maps representing the button parameters.
*/
    public static List<Map<String, Object>> constructButtons(String buttonsJson) {
        List<Object> buttons = (List<Object>) JSON.deserializeUntyped(buttonsJson);
        List<Map<String, Object>> buttonParameters = new List<Map<String, Object>>();
        Integer index = 0;
        for (Object button : buttons) {
            Map<String, Object> buttonMap = (Map<String, Object>) button;
            String buttonType = (String) buttonMap.get('type');
            
            if (!buttonType.equals('PHONE_NUMBER') && !buttonType.equals('URL')) {
                Map<String, Object> parameter = new Map<String, Object>{
                    'type' => 'button',
                        'sub_type' => buttonType.toUpperCase(), 
                        'index' => String.valueOf(index)
                        };
                            if (buttonType.equals('COPY_CODE')) {
                                parameter.put('parameters', new List<Object>{
                                    new Map<String, Object>{
                                        'type' => 'payload',
                                            'payload' => (String) buttonMap.get('example')
                                            }
                                });
                            } else {
                                parameter.put('parameters', new List<Object>{
                                    new Map<String, Object>{
                                        'type' => 'payload',
                                            'payload' => (String) buttonMap.get('text')
                                            }
                                });
                            }
                buttonParameters.add(parameter);
            }
            index++;
        }
        return buttonParameters;
    }
    
    
    /**
* @description Sends a typing indicator to a specified phone number using the WhatsApp Business API.
* @param toPhone The recipient's phone number.
* @param messageId The ID of the message for which the typing indicator is being sent.
* @throws AuraHandledException If there are missing parameters, an error occurs during the callout, or an unexpected exception is encountered.
*/
    /*@AuraEnabled
    public static void sendTypingIndicator(String toPhone, String messageId) {
        if (String.isBlank(toPhone) || String.isBlank(messageId)) {
            throw new AuraHandledException('Missing required parameters.');
        }
        
        SmartMsg__Meta_Configuration__c waCreds = WhatsAppProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        
        String endpointUrl = 'callout:SmartMsg__Meta_API/v23.0/'+ waCreds.SmartMsg__Phone_Number_Id__c + '/messages';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        // Correct payload per Facebook doc
        Map<String, Object> payload = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
                'to' => toPhone,
                'status' => 'read',
                'message_id' => messageId,
                'typing_indicator' => new Map<String, Object>{
                    'type' => 'text'
                        }
        };
            
            req.setBody(JSON.serialize(payload));
        
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new AuraHandledException('Error sending typing indicator: ' + res.getBody());
            }
        } catch (System.CalloutException ex) {
            throw new AuraHandledException('CalloutException: ' + ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Exception: ' + ex.getMessage());
        }
    }*/
    
    
}