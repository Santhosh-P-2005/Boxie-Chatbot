/**
 * @description REST service for handling Twilio webhooks.
 */
@RestResource(urlMapping='/twilioWhatsAppStatus/*')
global without sharing class TwilioWhatsAppWebhook {
    private static SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
    private static final String ACCOUNT_SID = twilioWhatsappSetting.SmartMsg__Account_SID__c;
    private static final String AUTH_TOKEN = twilioWhatsappSetting.SmartMsg__Auth_Token__c;
    public static Boolean sessionUpdateFlag = true;
    @HttpPost
    /**
     * @description Handles an incoming message or delivery status callback via REST request.
     * When Twilio sends MessageStatus + MessageSid (status callback), updates the Message__c record and publishes platform event (same as Meta WhatsApp flow).
     * @throws AuraHandledException if the user does not have permission to create a message or if a callout fails.
     */
    global static void handleIncomingMessage() {
        
        if(Constants.SUBSCRIPTION_END_DATE > String.valueOf(System.today())){
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            Map<String, String> params = req.params != null ? req.params : new Map<String, String>();
            // Twilio sends status callbacks and incoming messages in POST body as form-urlencoded (or JSON). Parse body with UTF-8 so emojis/unicode are preserved.
            Map<String, String> bodyParams = new Map<String, String>();
            if (req.requestBody != null && req.requestBody.size() > 0) {
                bodyParams = parseRequestBody(req.requestBody, req.headers);
            }
            Map<String, String> sms = bodyParams.isEmpty() ? params : bodyParams;
            if (sms == null) sms = new Map<String, String>();
            // Twilio WhatsApp status callback: treat any POST with MessageStatus + MessageSid as delivery status update (sent/delivered/read)
            if (!sms.isEmpty() && sms.containsKey('MessageStatus') && sms.containsKey('MessageSid')) {
                handleTwilioWhatsAppStatusCallback(sms, res);
                return;
            }
            // Template approval status callback: when Twilio/Meta sends ContentSid + approval status, update Message_Template__c (no extra callouts).
            try {
                if (!sms.isEmpty() && handleTwilioTemplateApprovalCallback(sms, res)) return;
            } catch (Exception e) {
                if (!sms.isEmpty()) {
                    Map<String, String> lowerCk = new Map<String, String>();
                    for (String k : sms.keySet()) {
                        if (k != null) lowerCk.put(k.toLowerCase(), sms.get(k));
                    }
                    if (String.isNotBlank(lowerCk.get('contentsid')) || String.isNotBlank(lowerCk.get('content_sid'))) {
                        if (String.isNotBlank(lowerCk.get('status')) || String.isNotBlank(lowerCk.get('approvalstatus')) || String.isNotBlank(lowerCk.get('templatestatus'))) {
                            if (res != null) res.statusCode = 200;
                            return;
                        }
                    }
                }
                throw e;
            }
            // When callback returned false (e.g. unknown status or template not found), return without setting 200 so client knows it was not a successful template approval.
            if (!sms.isEmpty()) {
                Map<String, String> lowerKeys = new Map<String, String>();
                for (String k : sms.keySet()) {
                    if (k != null) lowerKeys.put(k.toLowerCase(), sms.get(k));
                }
                if (String.isNotBlank(lowerKeys.get('contentsid')) || String.isNotBlank(lowerKeys.get('content_sid'))) {
                    if (String.isNotBlank(lowerKeys.get('status')) || String.isNotBlank(lowerKeys.get('approvalstatus')) || String.isNotBlank(lowerKeys.get('templatestatus'))) {
                        return;
                    }
                }
            }
            String fromPhNumber;
            String smsBody;
            string messageSid;
            //String mediaUrl0;
            String responseType;
            Boolean messageStatus = false;
            if(!sms.isEmpty()){
                if (sms.containsKey('From')) {
                    fromPhNumber = sms.get('From');
                }
                if (sms.containsKey('MessageStatus')) {
                    messageStatus = true;
                }
                if (sms.containsKey('Body')) {
                    smsBody = sms.get('Body');
                }
                if (sms.containsKey('MessageSid')) {
                    messageSid = sms.get('MessageSid');
                }
                // For interactive (list/button) messages, use ListTitle as message body (same as Meta list_reply.title); Body can be corrupted for emoji.
                if ('interactive'.equalsIgnoreCase(sms.get('MessageType'))) {
                    if (String.isNotBlank(sms.get('ListTitle'))) {
                        smsBody = sms.get('ListTitle');
                    }
                    if (sms.containsKey('ButtonText')) {
                        responseType = 'button_reply';
                    } else {
                        responseType = 'list_reply';
                    }
                } else if (sms.containsKey('ButtonText')) {
                    responseType = 'button_reply';
                }
                //res.addHeader('Content-Type', 'application/vcard');
                if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                }
                SmartMsg__Message__c messageRec = new SmartMsg__Message__c();
                if(smsBody != null){
                    smsBody = smsBody.replace('&#39;', '\'')  // Apostrophe
                        .replace('&quot;', '"')         // Double quote
                        .replace('&amp;', '&')          // Ampersand
                        .replace('&lt;', '<')           // Less than
                        .replace('&gt;', '>')           // Greater than
                        .replace('&ndash;', '–')        // En dash
                        .replace('&mdash;', '—')        // Em dash
                        .replace('&nbsp;', ' ');
                    messageRec.SmartMsg__To_Number__c = String.valueOf(fromPhNumber).trim().split(':')[1];
                    messageRec.SmartMsg__From_Number__c = String.valueOf(sms.get('To')).trim().split(':')[1];
                    messageRec.SmartMsg__Message_Body__c = smsBody;
                    messageRec.SmartMsg__Message_Id__c = messageSid;
                    messageRec.SmartMsg__Is_Outgoing__c = False;
                    messageRec.SmartMsg__Type__c = 'Inbound';
                    messageRec.SmartMsg__Channel__c = 'WhatsApp';
                    messageRec.SmartMsg__Delivery_Status__c = 'Received';
                    messageRec.SmartMsg__Response__c = JSON.serialize(sms); // Store the entire response
                }
                Datetime currentDateTime = Datetime.now(); // UTC
                messageRec.SmartMsg__Sent_Date_and_Time__c = currentDateTime; // Store as UTC
                List<SmartMsg__Message__c> queriedMessageChatbotStatus = new List<SmartMsg__Message__c> ();
                Boolean botResponse = false;
                if(messageRec.SmartMsg__To_Number__c != null){
                    queriedMessageChatbotStatus = [SELECT Id, SmartMsg__To_Number__c,SmartMsg__Chatbot_on_off__c
                                                    FROM SmartMsg__Message__c
                                                    WHERE SmartMsg__To_Number__c = :messageRec.SmartMsg__To_Number__c
                                                    AND SmartMsg__Type__c = NULL
                                                    AND SmartMsg__Channel__c = NULL
                                                    LIMIT 1];
                    if(!queriedMessageChatbotStatus.isEmpty()){
                        botResponse = queriedMessageChatbotStatus[0].SmartMsg__Chatbot_on_off__c;
                    }
                    if(queriedMessageChatbotStatus.size() <= 0){
                        if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
                            throw new AuraHandledException('You do not have permission to create Message__c records.');
                        }
                        SmartMsg__Message__c smMsgStatusRecord = new SmartMsg__Message__c(SmartMsg__To_Number__c = messageRec.SmartMsg__To_Number__c,SmartMsg__Chatbot_on_off__c = true);
                        insert smMsgStatusRecord;
                        botResponse = true;
                    }
                }
                try {
                    // string recId =messageRec.Id;
                    // string toNum = messageRec.SmartMsg__To_Number__c;
                    if(!messageStatus){
                        messageRec.SmartMsg__Messaging_Session__c = TwilioWhatsAppChatBot.messagingSession(messageRec.SmartMsg__To_Number__c, 'Customer Message Received');
                        if(sessionUpdateFlag){
                            List<SmartMsg__Messaging_Session__c> messagingSessionList = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c, SmartMsg__No_of_Inbound_Messages__c,SmartMsg__No_of_Outbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id =: messageRec.SmartMsg__Messaging_Session__c WITH SECURITY_ENFORCED];
                            messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c = messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c + 1;
                            if(!messagingSessionList.isEmpty()){
                                // if (!Schema.sObjectType.SmartMsg__Messaging_Session__c.isUpdateable()) {
                                //     throw new AuraHandledException('You do not have permission to update Messaging_Session__c.');
                                // }
                                update messagingSessionList;
                            }
                        }
                        if(botResponse != null && botResponse == true){
                            TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(messageRec.SmartMsg__To_Number__c,smsBody,responseType,messageRec.SmartMsg__From_Number__c);
                        }
                        insert messageRec;
                        // if(sessionUpdateFlag){
                        //     List<SmartMsg__Messaging_Session__c> messagingSessionList = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c, SmartMsg__No_of_Inbound_Messages__c,SmartMsg__No_of_Outbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id =: messageRec.SmartMsg__Messaging_Session__c];
                        //     messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c = messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c + 1;
                        //     if(!messagingSessionList.isEmpty()){
                        //         // if (!Schema.sObjectType.SmartMsg__Messaging_Session__c.isUpdateable()) {
                        //         //     throw new AuraHandledException('You do not have permission to update Messaging_Session__c.');
                        //         // }
                        //         update messagingSessionList;
                        //     }
                        // }
                    }



                    // Asynchronously process media if a media URL is present
                    // if (String.isNotBlank(mediaUrl0)) {
                        //processIncomingMedia(messageRec.Id, mediaUrl0);
                    // }
                    // SmartMsg__Incoming_Message__e event = new SmartMsg__Incoming_Message__e();
                    // event.SmartMsg__Record_Id__c = recId;
                    // event.SmartMsg__From_Number__c = toNum;
                    // event.SmartMsg__Event_Type__c ='Inbound';
                    // event.SmartMsg__Channel__c = messageRec.SmartMsg__Channel__c;
                    // EventBus.publish(event);
                    SmartMsg__Incoming_Message__e platformEvent = new SmartMsg__Incoming_Message__e();
                    platformEvent.SmartMsg__Record_Id__c = messageRec.Id;
                    platformEvent.SmartMsg__From_Number__c = messageRec.SmartMsg__To_Number__c;
                    platformEvent.SmartMsg__Delivery_Status__c = messageRec.SmartMsg__Delivery_Status__c;
                    platformEvent.SmartMsg__Channel__c = 'WhatsApp';
                    platformEvent.SmartMsg__Event_Type__c = 'Inbound';
                    Eventbus.publish(platformEvent);
                } catch (Exception e) {
                    if (res != null) {
                        res.statusCode = 500;
                        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => e.getMessage() }));
                    }
                }
            }
        }
        
    }

    /**
     * @description Handles Twilio WhatsApp delivery status callback (Sent, Delivered, Read, Failed). Updates Message__c by SmartMsg__Message_Id__c = MessageSid and publishes Incoming_Message__e (Outbound) for UI refresh.
     * @param params Map of POST parameters (MessageSid, MessageStatus, ErrorMessage).
     * @param res RestResponse to set status code on success.
     */
    private static void handleTwilioWhatsAppStatusCallback(Map<String, String> params, RestResponse res) {
        String messageId = params.get('MessageSid');
        String rawStatus = params.get('MessageStatus');
        String messageStatus = null;
        if (String.isNotBlank(rawStatus)) {
            String lower = rawStatus.toLowerCase();
            if (lower == 'queued') {
                messageStatus = 'Scheduled';
            } else if (lower == 'delivered') {
                messageStatus = 'Delivered';
            } else if (lower == 'read') {
                messageStatus = 'Read';
            } else if (lower == 'sent' || lower == 'sending' || lower == 'accepted') {
                messageStatus = 'Sent';
            } else if (lower == 'failed' || lower == 'undelivered') {
                messageStatus = 'Failed';
            } else {
                messageStatus = rawStatus.substring(0, 1).toUpperCase() + rawStatus.substring(1).toLowerCase();
            }
        }
        String errorMessage = params.get('ErrorMessage');
        if (res != null) res.statusCode = 200;
        if (String.isBlank(messageStatus) || String.isBlank(messageId)) return;
        // Update Message__c directly (same as Meta WhatsApp: webhook handler updates record, no triggers).
        String callbackPayload = JSON.serialize(params);
        WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid(messageId, messageStatus, messageStatus == 'Failed' ? errorMessage : null, callbackPayload);
    }

    /**
     * @description Handles template approval/rejection status callback (e.g. from Twilio when Meta approves/rejects a Content template). Expects params with Content SID and status; updates Message_Template__c.
     * @param params Map of POST parameters (ContentSid/content_sid, ApprovalStatus/Status/TemplateStatus, optional rejection_reason).
     * @param res RestResponse to set status code on success.
     * @return True if the request was a template approval callback (had ContentSid + status), so caller can return and not process as message.
     */
    private static Boolean handleTwilioTemplateApprovalCallback(Map<String, String> params, RestResponse res) {
        Map<String, String> lowerKeys = new Map<String, String>();
        for (String k : params.keySet()) {
            if (k != null) lowerKeys.put(k.toLowerCase(), params.get(k));
        }
        String contentSid = lowerKeys.get('contentsid');
        if (String.isBlank(contentSid)) contentSid = lowerKeys.get('content_sid');
        if (String.isBlank(contentSid)) return false;
        contentSid = contentSid.trim();
        if (!contentSid.startsWith('HX') || contentSid.length() != 34) return false;
        String statusVal = lowerKeys.get('approvalstatus');
        if (String.isBlank(statusVal)) statusVal = lowerKeys.get('templatestatus');
        if (String.isBlank(statusVal)) statusVal = lowerKeys.get('status');
        if (String.isBlank(statusVal)) return false;
        statusVal = statusVal.toLowerCase();
        String newStatus = null;
        if (statusVal == 'approved') newStatus = 'Approved';
        else if (statusVal == 'rejected') newStatus = 'Failed';
        if (newStatus == null) return false;
        List<SmartMsg__Message_Template__c> templates = [
            SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c
            FROM SmartMsg__Message_Template__c
            WHERE SmartMsg__Channel__c = 'Twilio WhatsApp'
            AND SmartMsg__WhatsApp_Template_ID__c = :contentSid
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!templates.isEmpty()) {
            SmartMsg__Message_Template__c mt = templates[0];
            mt.SmartMsg__Status__c = newStatus;
            if (newStatus == 'Approved') {
                mt.SmartMsg__Error_Response__c = null;
            } else if (lowerKeys.containsKey('rejection_reason') && String.isNotBlank(lowerKeys.get('rejection_reason'))) {
                String reason = lowerKeys.get('rejection_reason');
                mt.SmartMsg__Error_Response__c = reason.length() > 255 ? reason.substring(0, 255) : reason;
            }
            if (Schema.sObjectType.SmartMsg__Message_Template__c.isUpdateable() && CommonUtil.hasFLS(mt)) {
                update mt;
            }
        }
        if (res != null) res.statusCode = 200;
        return true;
    }

    /**
     * @description Parses POST body as form-urlencoded or JSON. Uses UTF-8 so emojis and Unicode (e.g. 🛒) are preserved in Body.
     * @param bodyRaw Raw request body blob.
     * @param headers Request headers (for Content-Type).
     * @return Map of parameter names to values; empty if body is blank.
     */
    @TestVisible
    private static Map<String, String> parseRequestBody(Blob bodyRaw, Map<String, String> headers) {
        Map<String, String> out = new Map<String, String>();
        if (bodyRaw == null || bodyRaw.size() == 0) return out;
        String bodyStr = bodyRaw.toString(); // Platform uses UTF-8 for Blob.toString(); ensures Unicode is preserved
        if (String.isBlank(bodyStr)) return out;
        String contentType = null;
        if (headers != null) {
            for (String h : headers.keySet()) {
                if (h != null && 'content-type'.equals(h.toLowerCase())) {
                    contentType = headers.get(h);
                    break;
                }
            }
        }
        if (contentType != null && contentType.toLowerCase().contains('application/json')) {
            try {
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(bodyStr);
                for (String key : jsonMap.keySet()) {
                    Object v = jsonMap.get(key);
                    out.put(key, v != null ? String.valueOf(v) : '');
                }
                return out;
            } catch (Exception e) {
                // Fall through to form parsing
            }
        }
        return parseFormUrlEncodedBody(bodyStr);
    }

    /**
     * @description Parses application/x-www-form-urlencoded body string. Decodes keys and values with UTF-8 so emojis are preserved.
     * Replaces '+' with space before URL-decode per application/x-www-form-urlencoded spec.
     */
    @TestVisible
    private static Map<String, String> parseFormUrlEncodedBody(String body) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(body)) return out;
        for (String pair : body.split('&')) {
            Integer eq = pair.indexOf('=');
            if (eq > 0) {
                String key = pair.substring(0, eq);
                String val = eq < pair.length() - 1 ? pair.substring(eq + 1) : '';
                key = key.replace('+', ' ');
                val = val.replace('+', ' ');
                try {
                    out.put(EncodingUtil.urlDecode(key, 'UTF-8'), EncodingUtil.urlDecode(val, 'UTF-8'));
                } catch (Exception e) {
                    out.put(key, val);
                }
            }
        }
        return out;
    }
}