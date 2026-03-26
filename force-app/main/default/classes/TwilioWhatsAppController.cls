/**
 * @description Queueable that sends Twilio WhatsApp messages via Content API and Messages API: builds request body, resolves Content SID, performs callout, and updates messaging session. Implements Finalizer.
 */
public class TwilioWhatsAppController implements Queueable, Finalizer, Database.AllowsCallouts {

    private static SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
    private static final String ACCOUNT_SID = twilioWhatsappSetting.SmartMsg__Account_SID__c;
    private static final String AUTH_TOKEN = twilioWhatsappSetting.SmartMsg__Auth_Token__c;
    public static List<SmartMsg__Message__c> salesforceMessageList = new List<SmartMsg__Message__c>();
    
    public String messageContent;
    public String fromNumber;
    public String toPhone;
    public String contentTemplateName;
    public Id dialogId;
    public Id optionDialogId;
    public boolean sessionEndFlag;
    public List<String> interactionList;
    public String responseType;

    /**
     * @description Constructor for TwilioWhatsAppController; copies fields from the chatbot wrapper.
     * @param wrap The wrapper containing messageBody, toNumber, fromNumber, contentTemplateName, dialogId, optionDialogId, sessionEndFlag, interactionList, responseType.
     */
    public TwilioWhatsAppController(TwilioWhatsAppChatBot.wrapper wrap) {
        this.messageContent = wrap.messageBody;
        this.toPhone = wrap.toNumber;
        this.fromNumber = wrap.fromNumber;
        this.contentTemplateName = wrap.contentTemplateName;
        this.dialogId = wrap.dialogId;
        this.optionDialogId = wrap.optionDialogId;
        this.sessionEndFlag = wrap.sessionEndFlag;
        this.interactionList = wrap.interactionList;
        this.responseType = wrap.responseType;
    }

    /**
     * @description Builds the form-urlencoded request body for Twilio WhatsApp Messages API (To, From, ContentSid, ContentVariables).
     * @param contentSID The Twilio Content template SID.
     * @return The encoded request body string.
     */
    public String requestGenerator(String contentSID) {
        //fromNumber = '+13026001706';
        List<String> lines = messageContent.split('\\n');
        String finalResponse = String.join(lines, '\\n');
        String contentVariable = '{"1":"'+finalResponse;
        Integer a = 2;
        for(Integer i = 1; i <= interactionList.size(); i++){
            if(interactionList[i-1].contains('-')){
                contentVariable = contentVariable+'","'+a+'":"'+interactionList[i-1].split('-')[0]+'","'+(a+1)+'":"'+interactionList[i-1].split('-')[1];
                a = a+2;
            }else{
                contentVariable = contentVariable.trim()+'","'+(i+1)+'":"'+interactionList[i-1];
            }
        }
        contentVariable = contentVariable + '"}';
        String body = 'To=whatsapp:' + EncodingUtil.urlEncode(toPhone, 'UTF-8') +
            '&From=whatsapp:' + EncodingUtil.urlEncode(fromNumber, 'UTF-8') +
            '&ContentSid=' + EncodingUtil.urlEncode(contentSID, 'UTF-8') +
            '&ContentVariables=' + EncodingUtil.urlEncode(contentVariable, 'UTF-8');
        return body;
    }

    /**
     * @description Checks Twilio Content API for existing template by friendly name; if not found, creates content and returns request body via requestGenerator.
     * @return The request body string for the Messages API callout.
     */
    public String chekContentAPI() {
        String endPoint = 'callout:SmartMsg__Twilio_content_API';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse response = http.send(req);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> contents = (List<Object>) result.get('contents');
        String sid;
        String friendlyName;
        for (Object obj : contents) {
            Map<String, Object> contentMap = (Map<String, Object>) obj;
            friendlyName = (String) contentMap.get('friendly_name');
            if(contentTemplateName == friendlyName){
                sid = (String) contentMap.get('sid');
            }
        }
        if(sid == null){
            //String contentTemplateName = '5_dynamic_list_picker';
            String sizeStr = contentTemplateName.split('_')[0];
            Integer size = Integer.valueOf(sizeStr);
            String payload;
            if(responseType == 'Button' || responseType == 'Separate Button'){
                payload = '{"friendly_name": "' + contentTemplateName + '","language": "en","types": {"twilio/quick-reply": {"body": "{{1}}","actions": [{"title": "{{2}}","id": "{{2}}"}';
                for(Integer i=3; i <= size+1 ; i++){
                    payload = payload + ',{"title": "{{'+i+'}}","id": "{{'+i+'}}"}';
                }
            }else{
                if(contentTemplateName.contains('no_description')){
                    payload = '{"friendly_name": "' + contentTemplateName + '","language": "en","types": {"twilio/list-picker": {"body": "{{1}}","button": "Choose Option","items": [{"item": "{{2}}","id": "{{2}}"}';
                    for(Integer i=3; i <= size+1 ; i++){
                        payload = payload + ',{"item": "{{'+i+'}}","id": "{{'+i+'}}"}';
                    }
                }else{
                    payload = '{"friendly_name": "' + contentTemplateName + '","language": "en","types": {"twilio/list-picker": {"body": "{{1}}","button": "Choose Option","items": [{"item": "{{2}}","id": "{{2}}","description": "{{3}}"}';
                    for(Integer i=4; i < (size*2)+1 ; i+=2){
                        payload = payload + ',{"item": "{{'+i+'}}","id": "{{'+i+'}}","description": "{{'+(i+1)+'}}"}';
                    }
                }
            }
            payload = payload + ']}}}';
            //endpoint = 'callout:https://content.twilio.com/v1/Content';
            req = new HttpRequest();
            req.setHeader('Content-Type', 'application/json');
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setBody(payload);
            http = new Http();
            response = http.send(req);
            result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            sid = (String) result.get('sid');
        }
        
        return requestGenerator(sid);
    }

    /**
     * @description Queueable execute: calls chekContentAPI, makeCallout, updates messaging session and message records, attaches finalizer.
     * @param context The QueueableContext (unused).
     */
    public void execute(QueueableContext context) {
        salesforceMessageList = new List<SmartMsg__Message__c>();
        String body = chekContentAPI();
        List<SmartMsg__Message__c> messageList = makeCallout(body);
        //List<SmartMsg__Message__c> messageList = makeCallout(payload, messageContent, toPhone, dialogueId, optionDialogId);
        Id messagingSession = TwilioWhatsAppChatBot.messagingSession(toPhone,null);
        for(SmartMsg__Message__c outBoundMessageRecord : messageList){
            outBoundMessageRecord.SmartMsg__Messaging_Session__c = messagingSession;
        }
        insert messageList;
        for (SmartMsg__Message__c m : messageList) {
            if (m.Id != null) WhatsAppMessageUpdateHelper.shareMessageWithGuestUserForStatusCallback(m.Id);
        }
        if(!messageList.isEmpty() && messageList[0].SmartMsg__Messaging_Session__c != null){
            List<SmartMsg__Messaging_Session__c> messagingSessionList = [SELECT Id,SmartMsg__Start_Time__c,SmartMsg__End_Time__c,SmartMsg__Total_Duration__c, SmartMsg__To_Number__c,  SmartMsg__Session_status__c, SmartMsg__No_of_Outbound_Messages__c  FROM SmartMsg__Messaging_Session__c WHERE Id =: messageList[0].SmartMsg__Messaging_Session__c];
            messagingSessionList[0].SmartMsg__No_of_Outbound_Messages__c = messagingSessionList[0].SmartMsg__No_of_Outbound_Messages__c + 1;
            if(sessionEndFlag){
                messagingSessionList[0].SmartMsg__Session_status__c = 'Completed';
                messagingSessionList[0].SmartMsg__End_Time__c = System.now();
            }else{
                messagingSessionList[0].SmartMsg__Session_status__c = 'Automation Sent';
            }
            if(!messagingSessionList.isEmpty()){
                update messagingSessionList;
            }
        }
        System.attachFinalizer(this);
    }

    /**
     * @description Executes the finalizer logic after the Queueable completes.
     * @param ctx The FinalizerContext containing the result of the parent job.
     */
    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.SUCCESS) {
            Integer i = 0;
            i++;
        }
    }

    /**
     * @description Sends a WhatsApp message via Twilio Messages API using the provided form body; creates and returns Message__c records on success.
     * @param payload The form-urlencoded body (To, From, ContentSid, ContentVariables).
     * @return List of created SmartMsg__Message__c records, or empty list on failure.
     */
    public List<SmartMsg__Message__c> makeCallout(String payload) {
        List<SmartMsg__Dialogue__c> dialogList = new  List<SmartMsg__Dialogue__c>();
        String endpoint = 'callout:SmartMsg__Twilio_WhatsApp/2010-04-01/Accounts/'+ACCOUNT_SID+'/Messages.json';
        HttpRequest req = new HttpRequest();
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setBody(payload);
        Http http = new Http();
        HttpResponse response = http.send(req);
        if(response.getStatusCode() == 200 || response.getStatusCode() == 201){
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String messageSid = result.get('sid') != null ? String.valueOf(result.get('sid')) : null;
            SmartMsg__Message__c messageRec = new SmartMsg__Message__c();
            messageRec.SmartMsg__From_Number__c = String.valueOf(result.get('from')).split(':')[1];
            messageRec.SmartMsg__To_Number__c = String.valueOf(result.get('to')).split(':')[1];
            messageRec.SmartMsg__Message_Body__c = (String) result.get('body');
            messageRec.SmartMsg__Delivery_Status__c = 'Sent';
            messageRec.SmartMsg__Sent_Date_and_Time__c = Datetime.now();
            messageRec.SmartMsg__Message_ID__c = messageSid;
            messageRec.SmartMsg__Channel__c = 'WhatsApp';
            messageRec.SmartMsg__Dialogue__c = dialogId;
            messageRec.SmartMsg__Option_Dialog__c = optionDialogId;
            messageRec.SmartMsg__Type__c = 'Outbound';
            salesforceMessageList.add(messageRec);
            
            List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>();
            if(optionDialogId != null){
                optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c, SmartMsg__Inbound_Response__r.Id,SmartMsg__Outbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id =: dialogId];
                if(!optionDialogList.isEmpty()){
                    dialogList = [SELECT Id, SmartMsg__Parent_Record__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Type__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id];
                    if(!dialogList.isEmpty()){
                        dialogId = dialogList[0].Id;
                    }
                }
            }
            if(!dialogList.isEmpty() && (dialogList.get(0).SmartMsg__Type__c == 'Separate Button' || dialogList.get(0).SmartMsg__Type__c == 'Separate Option' || dialogList.get(0).SmartMsg__Type__c == 'Separate Text') && dialogList.get(0).SmartMsg__Parent_Record__c == null){
                messageContent = dialogList.get(0).SmartMsg__Response__c;
                responseType = dialogList.get(0).SmartMsg__Type__c;
                if(!dialogList.isEmpty()){
                    if(dialogList[0].SmartMsg__Buttons_or_Options__c != null ){
                        interactionList = (dialogList[0].SmartMsg__Buttons_or_Options__c).split('\n');
                    }
                }
                contentTemplateName = TwilioWhatsAppChatBot.getContentName(responseType,interactionList);
                String body = chekContentAPI();
                makeCallout(body);
            }
        }
        
        return salesforceMessageList;
    }
    

    // @future(callout=true)
    // public static void syncPendingTemplatesFuture() {
    //     // Simply call the existing static method logic
    //     syncPendingTemplates();
    // }

    // /**
    //  * @description Fetches approval status from Twilio for Pending Twilio WhatsApp templates and updates their status.
    //  * Only updates templates that are currently Pending. Maps: approved -> Approved; rejected/paused/disabled -> Failed.
    //  */
    // public static void syncPendingTemplates() {
    //     List<SmartMsg__Message_Template__c> pending = [
    //         SELECT Id, SmartMsg__WhatsApp_Template_ID__c, SmartMsg__Status__c, SmartMsg__Error_Response__c
    //         FROM SmartMsg__Message_Template__c
    //         WHERE SmartMsg__Channel__c = 'Twilio WhatsApp'
    //         AND SmartMsg__Status__c = 'Pending'
    //         AND SmartMsg__WhatsApp_Template_ID__c != null
    //         LIMIT :100
    //     ];
    //     if (pending.isEmpty()) {
    //         return;
    //     }

    //     List<SmartMsg__Message_Template__c> toUpdate = new List<SmartMsg__Message_Template__c>();
    //     for (SmartMsg__Message_Template__c mt : pending) {
    //         String contentSid = mt.SmartMsg__WhatsApp_Template_ID__c;
    //         if (String.isBlank(contentSid) || !contentSid.startsWith('HX')) {
    //             continue;
    //         }
    //         Map<String, Object> approval = fetchApprovalStatus(contentSid);
    //         if (approval == null) {
    //             continue;
    //         }
    //         String twilioStatus = (String) approval.get('status');
    //         String rejectionReason = (String) approval.get('rejection_reason');
    //         String newStatus = mapTwilioStatusToSalesforce(twilioStatus);
    //         if (newStatus == null) {
    //             continue;
    //         }
    //         mt.SmartMsg__Status__c = newStatus;
    //         if ('Approved'.equals(newStatus)) {
    //             mt.SmartMsg__Error_Response__c = null;
    //         } else if (String.isNotBlank(rejectionReason)) {
    //             mt.SmartMsg__Error_Response__c = rejectionReason.length() > 255 ? rejectionReason.substring(0, 255) : rejectionReason;
    //         }
    //         if (Schema.sObjectType.SmartMsg__Message_Template__c.isUpdateable() && CommonUtil.hasFLS(mt)) {
    //             toUpdate.add(mt);
    //         }
    //     }
    //     if (!toUpdate.isEmpty()) {
    //         update toUpdate;
    //     }
    // }

    // /**
    //  * @description GET Content/{contentSid}/ApprovalRequests and parse WhatsApp status/rejection_reason.
    //  * @param contentSid Twilio Content SID (e.g. HX...).
    //  * @return Map with keys status (lowercase) and optionally rejection_reason; null if call failed or no WhatsApp approval.
    //  */
    // @TestVisible
    // private static Map<String, Object> fetchApprovalStatus(String contentSid) {
    //     String endpoint = 'callout:SmartMsg__Twilio_content_API' + '/' + contentSid + '/ApprovalRequests';
    //     HttpRequest req = new HttpRequest();
    //     req.setEndpoint(endpoint);
    //     req.setMethod('GET');
    //     Http http = new Http();
    //     HttpResponse response;
    //     try {
    //         response = http.send(req);
    //     } catch (Exception e) {
    //         return null;
    //     }
    //     if (response.getStatusCode() != 200) {
    //         return null;
    //     }
    //     Map<String, Object> body;
    //     try {
    //         body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    //     } catch (JSONException e) {
    //         return null;
    //     }
    //     // Response shape: { "sid": "HX...", "whatsapp": { "status": "approved"|"rejected"|"pending", "rejection_reason": "..." } }
    //     Object whatsappObj = body.get('whatsapp');
    //     if (whatsappObj instanceof Map<String, Object>) {
    //         Map<String, Object> whatsapp = (Map<String, Object>) whatsappObj;
    //         String status = (String) whatsapp.get('status');
    //         if (String.isNotBlank(status)) {
    //             Map<String, Object> result = new Map<String, Object>();
    //             result.put('status', status.toLowerCase());
    //             Object reason = whatsapp.get('rejection_reason');
    //             result.put('rejection_reason', reason != null ? String.valueOf(reason) : '');
    //             return result;
    //         }
    //     }
    //     // Or approval_requests array
    //     List<Object> approvalRequests = (List<Object>) body.get('approval_requests');
    //     if (approvalRequests != null && !approvalRequests.isEmpty()) {
    //         for (Object o : approvalRequests) {
    //             Map<String, Object> ar = (Map<String, Object>) o;
    //             whatsappObj = ar.get('whatsapp');
    //             if (whatsappObj instanceof Map<String, Object>) {
    //                 Map<String, Object> whatsapp = (Map<String, Object>) whatsappObj;
    //                 String status = (String) whatsapp.get('status');
    //                 if (String.isNotBlank(status)) {
    //                     Map<String, Object> result = new Map<String, Object>();
    //                     result.put('status', status.toLowerCase());
    //                     Object reason = whatsapp.get('rejection_reason');
    //                     result.put('rejection_reason', reason != null ? String.valueOf(reason) : '');
    //                     return result;
    //                 }
    //             }
    //             String status = (String) ar.get('status');
    //             if (String.isNotBlank(status)) {
    //                 Map<String, Object> result = new Map<String, Object>();
    //                 result.put('status', status.toLowerCase());
    //                 Object reason = ar.get('rejection_reason');
    //                 result.put('rejection_reason', reason != null ? String.valueOf(reason) : '');
    //                 return result;
    //             }
    //         }
    //     }
    //     return null;
    // }

    // /**
    //  * @description Maps Twilio/Meta approval status to SmartMsg__Message_Template__c Status picklist.
    //  * Approved -> Approved; Rejected, Paused, Disabled -> Failed; others (e.g. pending, received) -> null (no update).
    //  */
    // @TestVisible
    // private static String mapTwilioStatusToSalesforce(String twilioStatus) {
    //     if (String.isBlank(twilioStatus)) return null;
    //     String lower = twilioStatus.toLowerCase();
    //     if (lower == 'approved') return 'Approved';
    //     if (lower == 'rejected' || lower == 'paused' || lower == 'disabled') return 'Failed';
    //     return null;
    // }





    // public static String sendSMSHelper(String phoneNumber, String smsBody, List<String> mediaUrlList, String recordId) {
    //     String statusCallbackUrl = TwilioCred.SmartMsg__StatusCallbackUrl__c;
    //     try {
    //         // Retrieve SMS credentials
    //         //SmartMsg__TwilioConfiguration__c smsCreds = ProviderSettingUtil.getSMSProviderSettings('SMS');
    //         String accountSid = smsCreds.SmartMsg__Account_SID__c;
    //         // Construct endpoint with Named Credential
    //         String endpoint = 'callout:SmartMsg__Twilio_API/2010-04-01/Accounts/' + accountSid + '/Messages.json';
    //         // Construct HTTP Request
    //         HttpRequest req = new HttpRequest();
    //         req.setEndpoint(endpoint);
    //         req.setMethod('POST');
    //         // Standard Twilio headers
    //         String version = '3.2.0';
    //         req.setHeader('X-Twilio-Client', 'salesforce-' + version);
    //         req.setHeader('User-Agent', 'twilio-salesforce/' + version);
    //         req.setHeader('Accept', 'application/json');
    //         req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    //         req.setHeader('Accept-Charset', 'utf-8');
    //         req.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    //         req.setHeader('Pragma', 'no-cache');
    //         req.setHeader('Expires', '0');
    //         req.setHeader('X-Content-Type-Options', 'nosniff');
    
    //         // Use your constructSMSBody method here
    //         String messageBody = constructSMSBody(phoneNumber, smsBody, statusCallbackUrl, mediaUrlList);
    //         req.setBody(messageBody);
    
    //         // Execute request
    //         Http http = new Http();
    //         HttpResponse res = http.send(req);
    
    //         // Handle the response
    //         handleSMSResponse(res, recordId, mediaUrlList != null && !mediaUrlList.isEmpty() ? mediaUrlList[0] : '');
    //         System.debug('Media response : '+res);
    //         System.debug('Response body :'+res.getBody());
    //         return (res.getStatusCode() == 201) ? 'SMS Sent Successfully' : 'SMS Failed with status: ' + res.getStatusCode();
    
    //     } catch(Exception e) {
    //         updateRecordsInCatch(recordId, e.getMessage());
    //         return 'Failed';
    //     }
    // }
    // public static String constructSMSBody(String phoneNumber, String smsBody, String statusCallbackUrl) {
    
    //     // Add null check for mediaUrlList
    //     if (mediaUrlList == null) {
    //         mediaUrlList = new List<String>();
    //     }
    
    //     smsBody = smsBody.replace('&#39;', '\'')  // Apostrophe
    //         .replace('&quot;', '"')         // Double quote
    //         .replace('&amp;', '&')          // Ampersand
    //         .replace('&lt;', '<')           // Less than
    //         .replace('&gt;', '>')           // Greater than
    //         .replace('&ndash;', '–')        // En dash
    //         .replace('&mdash;', '—')        // Em dash
    //         .replace('&nbsp;', ' ');        // Non-breaking space
    
    
    //     String bodyEncoded = 'To=' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8') +
    //         '&From=' + EncodingUtil.urlEncode(FROM_PHONE, 'UTF-8') +
    //         '&Body=' + EncodingUtil.urlEncode(smsBody, 'UTF-8') +
    //         '&StatusCallback=' + EncodingUtil.urlEncode(statusCallbackUrl, 'UTF-8');
    
    
    //     return bodyEncoded;
    // }
}