/**
 * @description Queueable that sends WhatsApp messages via Meta API using a JSON payload; updates messaging session and supports Finalizer.
 */
public class SendWhatsAppMessagesWithUpdatedJSON implements Queueable, Finalizer, Database.AllowsCallouts {
    Map<String,Object> payload;
    String messageContent;
    String toPhone;
    Id dialogueId;
    Id optionDialogId;
    boolean sessionEndFlag;
    public static List<SmartMsg__Message__c> salesforceMessageList = new List<SmartMsg__Message__c>();
    /**
     * @description Constructor for SendWhatsAppMessagesWithUpdatedJSON; stores payload and message/session fields for execute.
     * @param payloads Map of payloads to be processed (WhatsApp API format).
     * @param messageContent Content of the message to be sent.
     * @param toPhone Phone number of the recipient.
     * @param dialogueId ID of the dialogue.
     * @param optionDialogId ID of the option dialog.
     * @param sessionEndFlag Flag indicating if the session has ended.
     */
    public SendWhatsAppMessagesWithUpdatedJSON(Map<String, Object> payloads, String messageContent, String toPhone, Id dialogueId, Id optionDialogId, Boolean sessionEndFlag) {
        this.payload = payloads;
        this.messageContent = messageContent;
        this.toPhone = toPhone;
        this.dialogueId = dialogueId;
        this.optionDialogId = optionDialogId;
        this.sessionEndFlag = sessionEndFlag;
    }

    /**
     * @description Executes the queueable job: makeCallout, link messaging session, update session record, attach finalizer.
     * @param context The context of the queueable execution.
     */
    public void execute(QueueableContext context) {
        List<SmartMsg__Message__c> messageList = makeCallout(payload, messageContent, toPhone, dialogueId, optionDialogId);
        Id messagingSession = WhatsAppChatBot.messagingSession(toPhone,null);
        for(SmartMsg__Message__c outBoundMessageRecord : messageList){
            outBoundMessageRecord.SmartMsg__Messaging_Session__c = messagingSession;
        }
        insert messageList;
        //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
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
     * @description Executes the finalizer logic.
     * @param ctx The FinalizerContext object containing the result of the parent job.
     */
    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.SUCCESS) {
            Integer i = 0;
            i++;
        }
    }
    /**
     * @description Makes a callout to the Meta WhatsApp API and creates Message__c records from the response.
     * @param payload The JSON payload to send in the callout.
     * @param messageContent The content of the message.
     * @param toPhone The recipient's phone number.
     * @param dialogueId The ID of the dialogue.
     * @param optionDialogId The ID of the option dialog.
     * @return List of SmartMsg__Message__c records created.
     */
    public static List<SmartMsg__Message__c> makeCallout(Map<String, Object> payload, String messageContent, String toPhone, Id dialogueId, Id optionDialogId) {
        List<SmartMsg__Dialogue__c> dialogList = new List<SmartMsg__Dialogue__c>();

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
        httpReq.setBody(JSON.serialize(payload));
        Http http = new Http();
        try{
            HttpResponse response = http.send(httpReq);
            if( response.getStatusCode() == 200 ){
                whatsAppServices responseFromWA = (whatsAppServices) JSON.deserialize( response.getBody() , whatsAppServices.class);
                if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() && !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to create this message.');
                }
                //salesforceMessage.SmartMsg__From_Number__c = fromNumber;
                SmartMsg__Message__c salesforceMessage = new SmartMsg__Message__c();
                salesforceMessage.SmartMsg__Message_Body__c = messageContent;
                salesforceMessage.SmartMsg__To_Number__c = toPhone;
                salesforceMessage.SmartMsg__Message_ID__c = responseFromWA.messages.get(0).id;
                salesforceMessage.SmartMsg__Message_Type__c = 'text';
                salesforceMessage.SmartMsg__Type__c = 'Outbound';
                salesforceMessage.SmartMsg__Channel__c = 'WhatsApp';
                salesforceMessage.SmartMsg__Delivery_Status__c = 'Sent';
                salesforceMessage.SmartMsg__Outgoing__c = True;
                salesforceMessage.SmartMsg__Response__c = response.getBody();
                salesforceMessage.SmartMsg__Sent_Date_and_Time__c = DateTime.now();
                if(dialogueId != null){
                    salesforceMessage.SmartMsg__Dialogue__c = dialogueId;
                }
                if(optionDialogId != null){
                    salesforceMessage.SmartMsg__Option_Dialog__c = optionDialogId;
                }
                salesforceMessageList.add(salesforceMessage);
                if (!CommonUtil.hasFLS(salesforceMessage)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
                }
                List<String> quickReplyActionsList = new List<String>();
                List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>();
                if(optionDialogId != null){
                    optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c, SmartMsg__Inbound_Response__r.Id,SmartMsg__Outbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id =: dialogueId];
                    if(!optionDialogList.isEmpty()){
                        dialogList = [SELECT Id, SmartMsg__Parent_Record__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Type__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id];
                    }
                }
                if(!dialogList.isEmpty() && (dialogList.get(0).SmartMsg__Type__c == 'Separate Button' || dialogList.get(0).SmartMsg__Type__c == 'Separate Option' || dialogList.get(0).SmartMsg__Type__c == 'Separate Text')){
                    String messageBody = dialogList.get(0).SmartMsg__Response__c;
                    String type = dialogList.get(0).SmartMsg__Type__c;
                    if(!dialogList.isEmpty()){
                        if(dialogList[0].SmartMsg__Buttons_or_Options__c != null ){
                            quickReplyActionsList = (dialogList[0].SmartMsg__Buttons_or_Options__c).split('\n');
                        }
                        Map<String,Object> finalInteractionPayload = WhatsAppChatBot.dynamicJSON(messageBody,quickReplyActionsList,type,toPhone);
                        makeCallout(finalInteractionPayload, messageBody, toPhone, dialogList.get(0).Id,null);
                    }
                }
            }
        }catch(System.CalloutException ex){
            throw new AuraHandledException('CalloutException: ' + ex.getMessage());
        }
        return salesforceMessageList;
    }
}