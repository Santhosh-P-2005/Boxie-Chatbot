/**
 * @description Helper class to update messages without enforcing sharing rules.
 * This class is used internally within a secure environment and is designed
 * to update fields that are managed by our application's logic, bypassing
 * Salesforce's record-level security for specific use cases.
 *
 * @security
 * - Access to this class is restricted to internal processes only.
 * - Custom security checks ensure that updates are performed only on records
 *   where the user has appropriate permissions based on application logic.
 */
//@SuppressWarnings('ApexSuggestUsingNamedCred')
//@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class WhatsAppMessageUpdateHelper {
    
    public static Boolean sessionUpdateFlag = true;
    /**
     * @description Processes the incoming WhatsApp message response.
     * @param responseString The response string from the WhatsApp webhook.
     * @throws AuraHandledException if there are any issues while processing the WhatsApp Message.
     */
    public static void processIncomingMessage(String responseString) {
        SmartMsg__Meta_Configuration__c whatsAppCreds = SmartMsg__Meta_Configuration__c.getInstance();
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseString);
            List<Object> entryList = (List<Object>) responseMap.get('entry');
            
            if (entryList != null && !entryList.isEmpty()) {
                
                Map<String, Object> entry = (Map<String, Object>) entryList[0];
                String entryId = (String) entry.get('id');
                if (entryId == whatsAppCreds.SmartMsg__WhatsApp_Business_Id__c) {
                    storeIncomingWAMessage(entryList, responseString);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error processing incoming message: ' + e.getMessage());
        }
    }
    /**
     * @description Stores the incoming WhatsApp message.
     * @param entryList The list of entries containing the message data.
     * @param responseString The response string to be stored in the message record.
     * @throws AuraHandledException if there are permissions issues or if an exception occurs during insertion or update.
     */
    public static void storeIncomingWAMessage(List<Object> entryList,String responseString) {
        String imcomingMsgPhone ;
        Map<String, Object> entry = (Map<String, Object>) entryList.get(0);
        List<Object> changesList = (List<Object>) entry.get('changes');
        if (changesList != null && !changesList.isEmpty()) {
            Map<String, Object> changes = (Map<String, Object>) changesList.get(0);
            Map<String, Object> value = (Map<String, Object>) changes.get('value');
            List<Object> contactsList = (List<Object>) value.get('contacts');
            List<Object> messagesList = (List<Object>) value.get('messages');
            List<Object> statusesList = (List<Object>) value.get('statuses');
            String templateId = String.valueOf(value.get('message_template_id'));
            if (statusesList != null && !statusesList.isEmpty()) {
                Map<String, Object> statuses = (Map<String, Object>) statusesList[0];
                String status = (String) statuses.get('status');
                // Normalize Meta webhook status to Title Case so LWC tick icons (Sent/Delivered/Read) match
                if (String.isNotBlank(status)) {
                    status = status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase();
                }
                String messageId = (String) statuses.get('id');
                // Add a delay of one second
                Long startTime = DateTime.now().getTime();
                Long finishTime = DateTime.now().getTime();
                while ((finishTime - startTime) < 1000) {
                    finishTime = DateTime.now().getTime();
                }
                List<SmartMsg__Message__c> queriedMessages = [SELECT Id, SmartMsg__Message_ID__c,SmartMsg__To_Number__c, SmartMsg__Delivery_Status__c 
                                                                   FROM SmartMsg__Message__c 
                                                                   WHERE SmartMsg__Message_ID__c = :messageId WITH SECURITY_ENFORCED LIMIT 1];
                if(queriedMessages != NULL && queriedMessages.size() > 0){
                    SmartMsg__Message__c existingMessage = queriedMessages[0];
                    existingMessage.SmartMsg__Delivery_Status__c = status;
                    existingMessage.SmartMsg__Response__c = responseString;
                    if (statuses.containsKey('errors')) {
                        List<Object> errorList = (List<Object>) statuses.get('errors');
                        if (errorList != null && !errorList.isEmpty()) {
                            Map<String, Object> errorData = (Map<String, Object>) errorList[0];
                            String errorCode = String.valueOf(errorData.get('code'));
                            String errorTitle = (String) errorData.get('title');
                            String errorMessage = (String) errorData.get('message');
                            String fullError = 'Code: ' + errorCode + ' | ' + errorTitle + ' - ' + errorMessage;
                            
                            if (errorData.containsKey('error_data')) {
                                Map<String, Object> errorDetails = (Map<String, Object>) errorData.get('error_data');
                                if (errorDetails.containsKey('details')) {
                                    fullError += ' | Details: ' + (String) errorDetails.get('details');
                                }
                            }
                            
                            existingMessage.SmartMsg__Failed_Reason__c = fullError;
                        }
                    }
                    if (CommonUtil.hasFLS(existingMessage)) {
                        //Database.update(existingMessage, AccessLevel.USER_MODE);
                        update existingMessage;
                    }
                    else {
                        throw new AuraHandledException('You do not have the necessary field permissions to create Message__c records.');
                    }
                    
                    SmartMsg__Incoming_Message__e platformEvent = new SmartMsg__Incoming_Message__e();
                    platformEvent.SmartMsg__Record_Id__c = existingMessage.Id;
                    platformEvent.SmartMsg__From_Number__c = existingMessage.SmartMsg__To_Number__c;
                    platformEvent.SmartMsg__Delivery_Status__c = existingMessage.SmartMsg__Delivery_Status__c;
                    platformEvent.SmartMsg__Event_Type__c = 'Outbound';
                    Eventbus.publish(platformEvent);
                    
                }
                // If this webhook payload contains only statuses (no inbound messages), stop here.
                if (messagesList == null || messagesList.isEmpty()) {
                    return;
                }
            }
            if(templateId != NULL){
                List<SmartMsg__Message_Template__c> templateList = [SELECT Id, SmartMsg__WhatsApp_Template_ID__c, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__WhatsApp_Template_ID__c = :templateId WITH SECURITY_ENFORCED LIMIT 1];
                if (templateList == null || templateList.isEmpty()) {
                    String templateName = value.get('name') != null ? String.valueOf(value.get('name')) : (value.get('template_name') != null ? String.valueOf(value.get('template_name')) : null);
                    if (String.isNotBlank(templateName)) {
                        templateList = [SELECT Id, SmartMsg__WhatsApp_Template_ID__c, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Channel__c = 'Twilio WhatsApp' AND SmartMsg__Template_API_Name__c = :templateName.trim() WITH SECURITY_ENFORCED LIMIT 1];
                    }
                }
                if(templateList != NULL && templateList.size() > 0){
                    String templateEvent = (String) value.get('event');
                    if (templateEvent == 'APPROVED') {
                        templateList[0].SmartMsg__Status__c = 'Approved';
                        templateList[0].SmartMsg__Error_Response__c = null;
                    } else if (templateEvent == 'REJECTED' || templateEvent == 'FAILED') {
                        templateList[0].SmartMsg__Status__c = 'Failed';
                        if (value.get('rejection_reason') != null) {
                            String reason = String.valueOf(value.get('rejection_reason'));
                            templateList[0].SmartMsg__Error_Response__c = reason.length() > 255 ? reason.substring(0, 255) : reason;
                        }
                    }
                    if (CommonUtil.hasFLS(templateList[0])) {
                        //Database.update(templateList[0], AccessLevel.USER_MODE);
                        update templateList[0];
                    }
                    else {
                        throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
                    }
                }
            }
            Map<String, Object> metadata = (Map<String, Object>) value.get('metadata');
            if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create this message.');
            }
            SmartMsg__Message__c salesforceMessage = new SmartMsg__Message__c();
            salesforceMessage.SmartMsg__Response__c = responseString;
            salesforceMessage.SmartMsg__Business_Phone_Number__c = metadata != null ? (String) metadata.get('display_phone_number') : null;
            salesforceMessage.SmartMsg__Type__c = 'Inbound';
            salesforceMessage.SmartMsg__Delivery_Status__c = 'Received';
            salesforceMessage.SmartMsg__Channel__c = 'WhatsApp';
            if (contactsList != null && !contactsList.isEmpty()) {
                Map<String, Object> contact = (Map<String, Object>) contactsList.get(0);
                salesforceMessage.SmartMsg__To_Number__c = '+'+(String) contact.get('wa_id');
                salesforceMessage.SmartMsg__Messaging_Session__c = WhatsAppChatBot.messagingSession(('+' + String.ValueOf(contact.get('wa_id'))), 'Customer Message Received');//messagingSession(phoneNumber.substring(1),'');
                if(sessionUpdateFlag){
                    List<SmartMsg__Messaging_Session__c> messagingSessionList = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c, SmartMsg__No_of_Inbound_Messages__c,SmartMsg__No_of_Outbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id =: salesforceMessage.SmartMsg__Messaging_Session__c WITH SECURITY_ENFORCED];
                    messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c = messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c + 1;
                    if(!messagingSessionList.isEmpty()){
                        //Database.update(messagingSessionList, AccessLevel.USER_MODE);
                        update messagingSessionList;
                    }
                }
                
                salesforceMessage.SmartMsg__Customer_Name__c = (String) ((Map<String, Object>) contact.get('profile')).get('name');
                imcomingMsgPhone = '+'+(String) contact.get('wa_id');
            }
            if (messagesList != null && !messagesList.isEmpty()) {
                Map<String, Object> message = (Map<String, Object>) messagesList.get(0);
                salesforceMessage.SmartMsg__Message_ID__c = (String) message.get('id');
                salesforceMessage.SmartMsg__Message_Type__c = (String) message.get('type');
                salesforceMessage.SmartMsg__Sent_Date_and_Time__c = Datetime.now();
                Map<String, Object> interactive;
                String interactiveResponse = '';
                if(message.containsKey('interactive')){
                    interactive =  ((Map<String, Object>) ((Map<String, Object>) message.get('interactive')));
                }
                if(interactive != null && interactive.containsKey('button_reply')){
                    interactiveResponse = (String) ((Map<String, Object>) interactive.get('button_reply')).get('title');
                }else if(interactive != null && interactive.containsKey('list_reply') ){
                    interactiveResponse = (String) ((Map<String, Object>) interactive.get('list_reply')).get('title');
                }else{
                    interactiveResponse = message.get('text') != null ? (String) ((Map<String, Object>) message.get('text')).get('body') : null;
                }
                salesforceMessage.SmartMsg__Message_Body__c = interactiveResponse;
                //salesforceMessage.SmartMsg__Reaction__c = message.get('reaction') != null ? (String) ((Map<String, Object>) message.get('reaction')).get('emoji') : null;
                if (message.get('reaction') != null) {
                    salesforceMessage.SmartMsg__Parent_Message_Id__c = (String) ((Map<String, Object>) message.get('reaction')).get('message_id');
                } else if (message.get('context') != null) {
                    salesforceMessage.SmartMsg__Parent_Message_Id__c = (String) ((Map<String, Object>) message.get('context')).get('id');
                }
                String mediaId = null;
                String mediaType = null;
                String fileName = null;
                //Blob mediaBlob = null;
                if (message.get('image') != null) {
                    String imageId = (String) ((Map<String, Object>) message.get('image')).get('id');
                    salesforceMessage.SmartMsg__Image_ID__c = imageId;
                    salesforceMessage.SmartMsg__Image_type__c = (String) ((Map<String, Object>) message.get('image')).get('mime_type');
                    salesforceMessage.SmartMsg__Image_SHA256__c = (String) ((Map<String, Object>) message.get('image')).get('sha256');
                    
                }
                if (message.get('image') != null) {
                    Map<String, Object> imageData = (Map<String, Object>) message.get('image');
                    mediaId = (String) imageData.get('id');
                    mediaType = (String) imageData.get('mime_type');
                    fileName = 'wa_image_' + Datetime.now().getTime() + '.jpg'; // Or use extension from mime_type
                    // Get the caption if present
                    if (imageData.containsKey('caption')) {
                        salesforceMessage.SmartMsg__Message_Body__c = (String) imageData.get('caption');
                    }
                }
                else if (message.get('video') != null) {
                    Map<String, Object> videoData = (Map<String, Object>) message.get('video');
                    mediaId = (String) videoData.get('id');
                    mediaType = (String) videoData.get('mime_type');
                    fileName = 'wa_video_' + Datetime.now().getTime() + '.mp4';
                    // Get the caption if present
                    if (videoData.containsKey('caption')) {
                        salesforceMessage.SmartMsg__Message_Body__c = (String) videoData.get('caption');
                    }
                    salesforceMessage.SmartMsg__Video_ID__c = message.get('video') != null ? (String) ((Map<String, Object>) message.get('video')).get('id') : null;
                    salesforceMessage.SmartMsg__Video_Type__c = message.get('video') != null ? (String) ((Map<String, Object>) message.get('video')).get('mime_type') : null;
                    salesforceMessage.SmartMsg__Video_SHA256__c = message.get('video') != null ? (String) ((Map<String, Object>) message.get('video')).get('sha256') : null;
                }
                else if (message.get('audio') != null) {
                    Map<String, Object> audioData = (Map<String, Object>) message.get('audio');
                    mediaId = (String) audioData.get('id');
                    mediaType = (String) audioData.get('mime_type');
                    fileName = 'wa_audio_' + Datetime.now().getTime() + '.mp4';
                    // Get the caption if present
                    if (audioData.containsKey('caption')) {
                        salesforceMessage.SmartMsg__Message_Body__c = (String) audioData.get('caption');
                    }
                    salesforceMessage.SmartMsg__Video_ID__c = message.get('audio') != null ? (String) ((Map<String, Object>) message.get('audio')).get('id') : null;
                    salesforceMessage.SmartMsg__Video_Type__c = message.get('audio') != null ? (String) ((Map<String, Object>) message.get('audio')).get('mime_type') : null;
                    salesforceMessage.SmartMsg__Video_SHA256__c = message.get('audio') != null ? (String) ((Map<String, Object>) message.get('audio')).get('sha256') : null;
                }
                else if (message.get('document') != null) {
                    Map<String, Object> docData = (Map<String, Object>) message.get('document');
                    mediaId = (String) docData.get('id');
                    mediaType = (String) docData.get('mime_type');
                    fileName = (String) docData.get('filename');
                    // Get the caption if present
                    if (docData.containsKey('caption')) {
                        salesforceMessage.SmartMsg__Message_Body__c = (String) docData.get('caption');
                    }
                    salesforceMessage.SmartMsg__Document_ID__c = message.get('document') != null ? (String) ((Map<String, Object>) message.get('document')).get('id') : null;
                    salesforceMessage.SmartMsg__Document_Type__c = message.get('document') != null ? (String) ((Map<String, Object>) message.get('document')).get('mime_type') : null;
                    salesforceMessage.SmartMsg__Document_SHA256__c = message.get('document') != null ? (String) ((Map<String, Object>) message.get('document')).get('sha256') : null;
                }
                else if (message.get('sticker') != null) {
                    // Map<String, Object> stickerData = (Map<String, Object>) message.get('sticker');
                    //mediaId = (String) stickerData.get('id');
                    //mediaType = (String) stickerData.get('mime_type');
                    // Boolean isAnimated = stickerData.containsKey('animated') ? (Boolean) stickerData.get('animated') : false;
                    // Use .webp for static, .gif for animated stickers (if WhatsApp provides gif)
                    //fileName = 'wa_sticker_' + Datetime.now().getTime() + (isAnimated ? '.gif' : '.webp');
                }
                else if (message.get('location') != null) {
                    Map<String, Object> location = (Map<String, Object>) message.get('location');
                    salesforceMessage.SmartMsg__Location_Latitude__c = location.get('latitude') != null ? String.valueOf(location.get('latitude')) : null;
                    salesforceMessage.SmartMsg__Location_Longitude__c = location.get('longitude') != null ? String.valueOf(location.get('longitude')) : null;
                    salesforceMessage.SmartMsg__Location_Address__c = (String) location.get('address');
                    salesforceMessage.SmartMsg__Location_Name__c = (String) location.get('name');
                    salesforceMessage.SmartMsg__Location_Link__c = (String) location.get('url');
                }
                // Download the media if present
                if (mediaId != null) {
                    salesforceMessage.SmartMsg__Media_ID__c = mediaId;
                    if (Test.isRunningTest()) {
                        ContentVersion cv = new ContentVersion();
                        cv.Title = fileName != null ? fileName : 'test.jpg';
                        cv.PathOnClient = cv.Title;
                        cv.VersionData = Blob.valueOf('x');
                        cv.ContentLocation = 'S';
                        insert cv;
                        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH SECURITY_ENFORCED];
                        salesforceMessage.SmartMsg__Media_Url__c = cv.ContentDocumentId;
                    }
                    // mediaBlob = downloadWhatsAppMedia(mediaId); // See helper below
                    // if (mediaBlob != null) {
                        //     ContentVersion cv = new ContentVersion();
                        //     cv.Title = fileName;
                        //     cv.PathOnClient = fileName;
                        //     cv.VersionData = mediaBlob;
                        //     cv.ContentLocation = 'S';
                        //     cv.FirstPublishLocationId = UserInfo.getUserId(); // Or link to related record if possible
                        //     insert cv;
                        //     // Retrieve ContentDocumentId
                        //     cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
                        //     salesforceMessage.SmartMsg__Media_Url__c = cv.ContentDocumentId;
                        //     salesforceMessage.SmartMsg__File_Name__c = fileName;
                        //     salesforceMessage.SmartMsg__Media_File__c = true;
                    // }
                }
                if (message.get('button') != null) {
                    salesforceMessage.SmartMsg__Message_Body__c = (String) ((Map<String, Object>) message.get('button')).get('text');
                }
                if (!CommonUtil.hasFLS(salesforceMessage)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to create Message__c records.');
                }else{
                    insert salesforceMessage;
                }
                String responseType;
                if( (String) message.get('type') == 'interactive'){
                    responseType = (String) ((Map<String, Object>) message.get('interactive')).get('type');
                }else{
                    responseType = (String) message.get('type');
                }
                List<SmartMsg__Message__c> queriedMessageChatbotStatus = new List<SmartMsg__Message__c> ();
                Boolean botResponse = false;
                if(imcomingMsgPhone != null){
                    queriedMessageChatbotStatus = [SELECT Id, SmartMsg__To_Number__c,SmartMsg__Chatbot_on_off__c
                                                     FROM SmartMsg__Message__c 
                                                     WHERE SmartMsg__To_Number__c = :imcomingMsgPhone 
                                                     AND SmartMsg__Type__c = NULL 
                                                     AND SmartMsg__Channel__c = NULL 
                                                      LIMIT 1];
                    if(!queriedMessageChatbotStatus.isEmpty()){
                        botResponse = queriedMessageChatbotStatus[0].SmartMsg__Chatbot_on_off__c;
                    }
                    if(queriedMessageChatbotStatus.size() <= 0){
                        SmartMsg__Message__c smMsgStatusRecord = new SmartMsg__Message__c(SmartMsg__To_Number__c = imcomingMsgPhone,SmartMsg__Chatbot_on_off__c = true);
                        // if(!hasChatbotDialogAndOptionDialogRecords()){
                        //     smMsgStatusRecord.SmartMsg__Chatbot_on_off__c = false;
                        // }
                        // System.debug('Inserted in message update helper');
                        insert smMsgStatusRecord;
                        botResponse = smMsgStatusRecord.SmartMsg__Chatbot_on_off__c;
                    }
                }
                if(((String) message.get('type') == 'interactive' || (String) message.get('type') == 'text') &&  (botResponse != null && botResponse == true)){
                    // WhatsAppChatBot.nextResponseRecordWhatsAppChatbot((String) salesforceMessage.SmartMsg__To_Number__c,interactiveResponse, responseType);   //Send another whatsapp automatic response
                    WhatsAppAgent.getAgentResponse(interactiveResponse, salesforceMessage.SmartMsg__To_Number__c, salesforceMessage.SmartMsg__From_Number__c);
                }
                // Link ContentDocument to Message__c (if media was saved)
                if (salesforceMessage.SmartMsg__Media_Url__c != null) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = salesforceMessage.SmartMsg__Media_Url__c;
                    cdl.LinkedEntityId = salesforceMessage.Id;
                    cdl.ShareType = 'V';
                    Database.insert(cdl, AccessLevel.USER_MODE);
                }
                SmartMsg__Incoming_Message__e platformEvent = new SmartMsg__Incoming_Message__e();
                platformEvent.SmartMsg__Record_Id__c = salesforceMessage.Id;
                platformEvent.SmartMsg__From_Number__c = salesforceMessage.SmartMsg__To_Number__c;
                platformEvent.SmartMsg__Delivery_Status__c = salesforceMessage.SmartMsg__Delivery_Status__c;
                platformEvent.SmartMsg__Channel__c = 'WhatsApp';
                platformEvent.SmartMsg__Event_Type__c = 'Inbound';
                Eventbus.publish(platformEvent);
            }
        }
    }
    /**
     *@description Downloads media from WhatsApp using the provided media ID.
     *
     * @param mediaId The ID of the media to download.
     * @return A Blob containing the downloaded media, or null if the download fails.
     */
    
    /*public static Blob downloadWhatsAppMedia(String mediaId) {
        try{
            SmartMsg__Meta_Configuration__c waCreds = SmartMsg__Meta_Configuration__c.getInstance();
            String endpointUrl = 'callout:SmartMsg__Meta_API/v19.0/' + mediaId;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpointUrl);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                // WhatsApp returns a JSON with a URL to the actual media file
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String mediaUrl = (String) jsonResponse.get('url');
                HttpRequest downloadReq = new HttpRequest();
                downloadReq.setEndpoint(mediaUrl);
                downloadReq.setMethod('GET');
                downloadReq.setHeader('Authorization', 'Bearer ' + waCreds.SmartMsg__Auth_Token__c);
                HttpResponse downloadRes = http.send(downloadReq);
                if (downloadRes.getStatusCode() == 200) {
                    return downloadRes.getBodyAsBlob();
                }
            }
            return null;
        }
        catch(Exception e){
            return null;
        }
    } */

    /**
     * @description Updates Message__c delivery status by Twilio message SID (used from Twilio WhatsApp status callback).
     * Runs without sharing so the webhook (often invoked as Site Guest) can find and update the outbound message.
     * Mirrors Meta WhatsApp: live status updates (sent → delivered → read) and optional Response__c storage.
     * @param messageSid Twilio Message SID (stored in SmartMsg__Message_Id__c).
     * @param deliveryStatus Mapped status: Sent, Delivered, Read, Failed, Scheduled.
     * @param failedReason Optional error message when status is Failed.
     * @return True if a record was updated, false otherwise.
     */
    public static Boolean updateDeliveryStatusByTwilioMessageSid(String messageSid, String deliveryStatus, String failedReason) {
        return updateDeliveryStatusByTwilioMessageSid(messageSid, deliveryStatus, failedReason, null);
    }

    private static final Map<String, Integer> DELIVERY_STATUS_ORDER = new Map<String, Integer>{
        'Sent' => 1, 'Delivered' => 2, 'Read' => 3, 'Scheduled' => 0, 'Failed' => -1
    };

    /**
     * @description Updates Message__c delivery status by Twilio message SID with optional callback payload (same pattern as Meta WhatsApp status update).
     * Only advances status order: Sent < Delivered < Read; never overwrites with an earlier status. Failed always applied.
     * @param messageSid Twilio Message SID (stored in SmartMsg__Message_Id__c).
     * @param deliveryStatus Mapped status: Sent, Delivered, Read, Failed, Scheduled.
     * @param failedReason Optional error message when status is Failed.
     * @param callbackPayload Optional JSON of Twilio status callback params; when provided, stored in SmartMsg__Response__c (like Meta WhatsApp responseString).
     * @return True if a record was updated, false otherwise.
     */
    public static Boolean updateDeliveryStatusByTwilioMessageSid(String messageSid, String deliveryStatus, String failedReason, String callbackPayload) {
        if (String.isBlank(messageSid) || String.isBlank(deliveryStatus)) return false;
        String sid = messageSid.trim();
        List<SmartMsg__Message__c> messages;
        try {
            messages = [SELECT Id, SmartMsg__Delivery_Status__c, SmartMsg__Message_Id__c, SmartMsg__Channel__c, SmartMsg__To_Number__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = :sid LIMIT 1];
        } catch (Exception e) {
            return false;
        }
        if (messages.isEmpty()) return false;
        String currentStatus = messages[0].SmartMsg__Delivery_Status__c;
        // Only advance status: Sent < Delivered < Read (same as Meta); never overwrite with an earlier status. Failed always applied.
        if (deliveryStatus != 'Failed' && currentStatus != null) {
            Integer currentOrder = twilioStatusOrder(currentStatus);
            Integer newOrder = twilioStatusOrder(deliveryStatus);
            if (newOrder <= currentOrder) return true; // no update needed
        }
        SmartMsg__Message__c toUpdate = new SmartMsg__Message__c();
        toUpdate.Id = messages[0].Id;
        toUpdate.SmartMsg__Delivery_Status__c = deliveryStatus;
        toUpdate.SmartMsg__Sent_Date_and_Time__c = DateTime.now();
        if (deliveryStatus == 'Failed' && String.isNotBlank(failedReason)) {
            toUpdate.SmartMsg__Failed_Reason__c = failedReason;
        }
        if (String.isNotBlank(callbackPayload)) {
            toUpdate.SmartMsg__Response__c = callbackPayload;
        }
        List<Database.SaveResult> results = Database.update(new List<SmartMsg__Message__c>{ toUpdate }, false);
        if (results.isEmpty() || !results[0].isSuccess()) {
            // if (!results.isEmpty() && results[0].getErrors() != null && !results[0].getErrors().isEmpty()) {
            // }
            return false;
        }
        try {
            SmartMsg__Incoming_Message__e evt = new SmartMsg__Incoming_Message__e();
            evt.SmartMsg__Event_Type__c = 'Outbound';
            evt.SmartMsg__Record_Id__c = messages[0].Id;
            evt.SmartMsg__From_Number__c = messages[0].SmartMsg__To_Number__c;
            evt.SmartMsg__Channel__c = messages[0].SmartMsg__Channel__c != null ? messages[0].SmartMsg__Channel__c : 'Twilio WhatsApp';
            evt.SmartMsg__Delivery_Status__c = deliveryStatus;
            evt.SmartMsg__Sent_date_and_Time__c = Datetime.now();
            EventBus.publish(evt);
        } catch (Exception e) {
            throw new CustomException('Error Failed to publish Incoming Message__e event: ' + e.getMessage());
        }
        return true;
    }

    /**
     * @description Returns a numeric order for Twilio delivery status for sorting (e.g. sent/scheduled=1, delivered=2, read=3).
     * @param status Twilio delivery status string (e.g. 'sent', 'delivered', 'read').
     * @return Integer order value; 0 for unknown or null.
     */
    public static Integer twilioStatusOrder(String status) {
        if (status == null) return 0;
        String s = status.toLowerCase();
        if (s == 'sent' || s == 'scheduled') return 1;
        if (s == 'delivered') return 2;
        if (s == 'read') return 3;
        return 0;
    }

    /**
     * @description Shares a Message__c record with all Site Guest users so the Twilio status callback webhook (runs as Guest) can update delivery status. Use for both manual and automated (chatbot) outbound messages.
     * @param messageId Message__c Id to share.
     */
    public static void shareMessageWithGuestUserForStatusCallback(Id messageId) {
        if (messageId == null) return;
        try {
            List<User> guestUsers = [SELECT Id FROM User WHERE UserType = 'Guest' AND IsActive = true WITH SECURITY_ENFORCED];
            if (guestUsers.isEmpty()) return;
            if (!Schema.sObjectType.SmartMsg__Message__Share.isCreateable()) return;
            List<SmartMsg__Message__Share> shares = new List<SmartMsg__Message__Share>();
            for (User gu : guestUsers) {
                SmartMsg__Message__Share shareRec = new SmartMsg__Message__Share();
                shareRec.ParentId = messageId;
                shareRec.UserOrGroupId = gu.Id;
                shareRec.AccessLevel = 'Edit';
                shareRec.RowCause = Schema.SmartMsg__Message__Share.RowCause.Manual;
                shares.add(shareRec);
            }
            Database.insert(shares, false);
        } catch (Exception e) {
            throw new CustomException('Error Failed to share Message__c record with Guest users: ' + e.getMessage());
        }
    }
    
    
    /**
     * @description Returns true only when both Dialogue__c and Option_Dialog__c have at least one record (used to show chatbot on/off toggle in chat component).
     * @return true if both dialog and option dialog records exist; false otherwise.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasChatbotDialogAndOptionDialogRecords() {
        List<SmartMsg__Dialogue__c> dialogs = [SELECT Id FROM SmartMsg__Dialogue__c WITH SECURITY_ENFORCED LIMIT 1];
        List<SmartMsg__Option_Dialog__c> optionDialogs = [SELECT Id FROM SmartMsg__Option_Dialog__c WITH SECURITY_ENFORCED LIMIT 1];
        return !dialogs.isEmpty() && !optionDialogs.isEmpty();
    }
    
    /**
     * @description Custom exception for template creation errors.
     */
    public class CustomException extends Exception {}
}