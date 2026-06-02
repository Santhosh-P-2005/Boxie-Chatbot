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
            System.debug('req: ' + req);
            System.debug('res: ' + res);
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
            String messageSid;
            String mediaUrl0;
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
                if (sms.containsKey('MediaUrl0')) {
                    mediaUrl0 = sms.get('MediaUrl0');
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
                if (messageStatus) {
                    return;
                }
                Boolean hasMedia = hasTwilioInboundMedia(sms, mediaUrl0);
                if (String.isBlank(fromPhNumber) || String.isBlank(messageSid)) {
                    return;
                }
                if (String.isBlank(smsBody) && !hasMedia) {
                    return;
                }
                if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                }
                SmartMsg__Message__c messageRec = new SmartMsg__Message__c();
                if (String.isNotBlank(smsBody)) {
                    smsBody = decodeTwilioMessageBody(smsBody);
                }
                messageRec.SmartMsg__To_Number__c = extractWhatsAppPhoneNumber(fromPhNumber);
                messageRec.SmartMsg__From_Number__c = extractWhatsAppPhoneNumber(sms.get('To'));
                messageRec.SmartMsg__Message_Body__c = smsBody;
                messageRec.SmartMsg__Message_Id__c = messageSid;
                messageRec.SmartMsg__Is_Outgoing__c = false;
                messageRec.SmartMsg__Type__c = 'Inbound';
                messageRec.SmartMsg__Channel__c = 'WhatsApp';
                messageRec.SmartMsg__Delivery_Status__c = 'Received';
                messageRec.SmartMsg__Response__c = JSON.serialize(sms);
                if (hasMedia) {
                    applyIncomingMediaFields(messageRec, sms, mediaUrl0);
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
                    messageRec.SmartMsg__Messaging_Session__c = TwilioWhatsAppChatBot.messagingSession(messageRec.SmartMsg__To_Number__c, 'Customer Message Received');
                    if(sessionUpdateFlag){
                        List<SmartMsg__Messaging_Session__c> messagingSessionList = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c, SmartMsg__No_of_Inbound_Messages__c,SmartMsg__No_of_Outbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id =: messageRec.SmartMsg__Messaging_Session__c WITH SECURITY_ENFORCED];
                        messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c = messagingSessionList[0].SmartMsg__No_of_Inbound_Messages__c + 1;
                        if(!messagingSessionList.isEmpty()){
                            update messagingSessionList;
                        }
                    }
                    if(botResponse != null && botResponse == true && String.isNotBlank(smsBody)){
                        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(messageRec.SmartMsg__To_Number__c,smsBody,responseType,messageRec.SmartMsg__From_Number__c);
                    }
                    insert messageRec;
                    if (String.isNotBlank(mediaUrl0)) {
                        // TwilioWebhook.processIncomingMedia(messageRec.Id, mediaUrl0);
                    }
                    SmartMsg__Incoming_Message__e platformEvent = new SmartMsg__Incoming_Message__e();
                    platformEvent.SmartMsg__Record_Id__c = messageRec.Id;
                    platformEvent.SmartMsg__From_Number__c = messageRec.SmartMsg__To_Number__c;
                    platformEvent.SmartMsg__Delivery_Status__c = messageRec.SmartMsg__Delivery_Status__c;
                    platformEvent.SmartMsg__Channel__c = messageRec.SmartMsg__Channel__c;
                    platformEvent.SmartMsg__Event_Type__c = 'Inbound';
                    Eventbus.publish(platformEvent);
                    if (res != null) {
                        res.statusCode = 200;
                    }
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
     * @description Returns true when Twilio reports one or more media attachments on the inbound webhook.
     */
    @TestVisible
    private static Boolean hasTwilioInboundMedia(Map<String, String> sms, String mediaUrl0) {
        if (String.isNotBlank(mediaUrl0)) {
            return true;
        }
        if (sms == null || sms.isEmpty()) {
            return false;
        }
        String numMedia = sms.get('NumMedia');
        return String.isNotBlank(numMedia) && numMedia != '0';
    }

    /**
     * @description Strips whatsapp: prefix from Twilio From/To and returns E.164-style number with leading +.
     */
    @TestVisible
    private static String extractWhatsAppPhoneNumber(String twilioAddress) {
        if (String.isBlank(twilioAddress)) {
            return null;
        }
        String normalized = String.valueOf(twilioAddress).trim();
        if (normalized.contains(':')) {
            normalized = normalized.substring(normalized.indexOf(':') + 1);
        }
        normalized = normalized.trim();
        if (!normalized.startsWith('+')) {
            normalized = '+' + normalized;
        }
        return normalized;
    }

    /**
     * @description Decodes common HTML entities in Twilio message body text.
     */
    @TestVisible
    private static String decodeTwilioMessageBody(String smsBody) {
        if (smsBody == null) {
            return null;
        }
        return smsBody.replace('&#39;', '\'')
            .replace('&quot;', '"')
            .replace('&amp;', '&')
            .replace('&lt;', '<')
            .replace('&gt;', '>')
            .replace('&ndash;', '–')
            .replace('&mdash;', '—')
            .replace('&nbsp;', ' ');
    }

    /**
     * @description Maps Twilio inbound media webhook params onto Message__c (aligned with Meta WhatsApp inbound fields).
     */
    @TestVisible
    private static void applyIncomingMediaFields(SmartMsg__Message__c messageRec, Map<String, String> sms, String mediaUrl0) {
        if (messageRec == null || String.isBlank(mediaUrl0)) {
            return;
        }
        List<String> mediaUrl0List = mediaUrl0.split('/');
        String mediaSid = mediaUrl0List[mediaUrl0List.size() - 1];
        String contentType = sms != null ? sms.get('MediaContentType0') : null;
        String messageType = resolveTwilioInboundMessageType(sms, contentType);

        messageRec.SmartMsg__Media_File__c = true;
        messageRec.SmartMsg__Media_ID__c = mediaSid;
        messageRec.SmartMsg__Message_Type__c = messageType;
        messageRec.SmartMsg__File_Name__c = deriveTwilioMediaFileName(contentType, messageType);
        messageRec.SmartMsg__Media_Url__c = mediaUrl0;

        if ('image'.equalsIgnoreCase(messageType)) {
            messageRec.SmartMsg__Image_ID__c = mediaSid;
            messageRec.SmartMsg__Image_type__c = contentType;
        } else if ('video'.equalsIgnoreCase(messageType)) {
            messageRec.SmartMsg__Video_ID__c = mediaSid;
            messageRec.SmartMsg__Video_Type__c = contentType;
        } else if ('audio'.equalsIgnoreCase(messageType)) {
            messageRec.SmartMsg__Video_ID__c = mediaSid;
            messageRec.SmartMsg__Video_Type__c = contentType;
        } else if ('document'.equalsIgnoreCase(messageType)) {
            messageRec.SmartMsg__Document_ID__c = mediaSid;
            messageRec.SmartMsg__Document_Type__c = contentType;
        }
    }

    @TestVisible
    private static String resolveTwilioInboundMessageType(Map<String, String> sms, String contentType) {
        String messageType = sms != null ? sms.get('MessageType') : null;
        if (String.isNotBlank(messageType) && !'text'.equalsIgnoreCase(messageType)) {
            return messageType.toLowerCase();
        }
        if (String.isBlank(contentType)) {
            return 'document';
        }
        String lowerType = contentType.toLowerCase();
        if (lowerType.startsWith('image/')) {
            return 'image';
        }
        if (lowerType.startsWith('video/')) {
            return 'video';
        }
        if (lowerType.startsWith('audio/')) {
            return 'audio';
        }
        if (lowerType.startsWith('application/pdf') || lowerType.contains('document') || lowerType.contains('msword') || lowerType.contains('spreadsheet')) {
            return 'document';
        }
        return 'document';
    }

    @TestVisible
    private static String deriveTwilioMediaFileName(String contentType, String messageType) {
        String extension = 'bin';
        if (String.isNotBlank(contentType) && contentType.contains('/')) {
            extension = contentType.substringAfter('/').trim();
            if (extension.contains(';')) {
                extension = extension.substringBefore(';').trim();
            }
        } else if ('image'.equalsIgnoreCase(messageType)) {
            extension = 'jpg';
        } else if ('video'.equalsIgnoreCase(messageType)) {
            extension = 'mp4';
        } else if ('audio'.equalsIgnoreCase(messageType)) {
            extension = 'mp3';
        } else if ('document'.equalsIgnoreCase(messageType)) {
            extension = 'pdf';
        }
        return 'twilio_wa_' + messageType + '_' + Datetime.now().getTime() + '.' + extension;
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
        System.debug('bodyStr: ' + bodyStr);
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
     * @param body Raw request body.
     * @return Map of decoded form keys and values.
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