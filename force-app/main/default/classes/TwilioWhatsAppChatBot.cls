/**
 * @description Chatbot controller for Twilio WhatsApp: messaging session, next-response flow, and content template name resolution. Used by TwilioWhatsAppWebhook and TwilioWhatsAppController.
 */
public without sharing class TwilioWhatsAppChatBot {
    public static Boolean sessionEndFlag = false;
    /**
     * @description Retrieves or creates a messaging session based on the provided phone number and session status.
     * @param toNumber The phone number to search for or create a session for.
     * @param sessionStatus The status to set for the messaging session.
     * @return The Id of the existing or newly created messaging session.
     */
    public static Id messagingSession(String toNumber, String sessionStatus){
        // system.debug('create session called ');
        // system.debug(toNumber);
        List<SmartMsg__Messaging_Session__c> messagingSession = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c FROM SmartMsg__Messaging_Session__c WHERE SmartMsg__To_Number__c = :toNumber AND SmartMsg__Session_status__c != 'Completed' WITH SECURITY_ENFORCED ];
        if(!messagingSession.isEmpty()){
            return messagingSession[0].Id;
        }else{
            SmartMsg__Messaging_Session__c newMessagingSession = new SmartMsg__Messaging_Session__c();
            newMessagingSession.SmartMsg__To_Number__c = toNumber;
            newMessagingSession.SmartMsg__Session_status__c = sessionStatus;
            newMessagingSession.SmartMsg__Start_Time__c = System.Now();
            newMessagingSession.SmartMsg__No_of_Inbound_Messages__c = 1;
            newMessagingSession.SmartMsg__No_of_Outbound_Messages__c = 0;
            TwilioWhatsAppWebhook.sessionUpdateFlag = false;
            if(Schema.SObjectType.SmartMsg__Messaging_Session__c.isAccessible() && Schema.SObjectType.SmartMsg__Messaging_Session__c.isCreateable() && CommonUtil.hasFLS(newMessagingSession)){
                try {
                    Database.insert(new List<SmartMsg__Messaging_Session__c>{ newMessagingSession }, AccessLevel.USER_MODE);
                } catch (Exception e) {
                    throw new AuraHandledException('Failed to create session record. Please contact your administrator.');
                }
            }else{
                throw new AuraHandledException('Permission required to create session record');
            }
            return newMessagingSession.Id;
        }
    }
    /**
     * @description Gets the next response record based on the incoming message and enqueues TwilioWhatsAppController to send the WhatsApp message (Twilio flow).
     * @param phoneNumber The recipient phone number used in the payload.
     * @param message The incoming message text (e.g. user reply or button title).
     * @param responseType The type of response (e.g. 'text', 'button_reply', 'list_reply').
     * @param fromNumber The sender phone number (Twilio format).
     */
    public static void nextResponseRecordWhatsAppChatbot(String phoneNumber, String message, String responseType, String fromNumber){
        String contentTemplateName;
        String messageResponse;
        String type;
        Id dialogId;
        Id optionDialogId;
        List<String> interactionsList = new List<String>();
        // Map<String,Object> payload;
        List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>();
        List<SmartMsg__Dialogue__c> dialogList = new List<SmartMsg__Dialogue__c>();
        List<SmartMsg__Option_Dialog__c> lastDeliveredDialogList = new List<SmartMsg__Option_Dialog__c>();
        List<SmartMsg__Message__c> lastOutBoundMessageRecord = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c,SmartMsg__Dialogue__r.Id, SmartMsg__Dialogue__r.SmartMsg__Order_Number__c, SmartMsg__Option_Dialog__c, SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c,SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.Id, SmartMsg__Option_Dialog__r.SmartMsg__Outbound_Response__r.Id, SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c,SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Question__c
                                                                    FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c =: phoneNumber AND SmartMsg__Type__c = 'Outbound'  WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1 ];
        

        //System.debug('message: ' + message);
        //System.debug('phoneNumber: ' + phoneNumber);
        
        if(message != null && message != ''){
            List<SmartMsg__Messaging_Session__c> messagingSession = [SELECT Id, SmartMsg__To_Number__c, SmartMsg__No_of_Inbound_Messages__c,  SmartMsg__Session_status__c FROM SmartMsg__Messaging_Session__c WHERE SmartMsg__To_Number__c = :phoneNumber AND SmartMsg__Session_status__c != 'Completed'  WITH SECURITY_ENFORCED];
            if(messagingSession.isEmpty() || messagingSession[0].SmartMsg__No_of_Inbound_Messages__c == 1){
                message = 'Hi';
            }
        }

        
        if(lastOutBoundMessageRecord.isEmpty() || message == 'Hi' || (responseType == 'button_reply' && lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && message == 'Yes, please!') || (responseType == 'button_reply'&& lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && message == 'No, that\'s all.')){
            // get the option dialog record for "Hi"
            if((responseType == 'button_reply' && message == 'Yes, please!')){
                if((lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c == 'Moving Boxes') || (lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c == '❓ View FAQs')){
                    message = 'English';
                }else{
                    message = lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c;
                }
            }
            if((responseType == 'button_reply' && !lastOutBoundMessageRecord.isEmpty() && lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && message == 'No, that\'s all.')){
                if(lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c == 'Existing Customer'){
                    message = 'No';
                }
                else if((lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c == 'Moving Boxes') || (lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c == '❓ View FAQs')){
                    message = 'Rent No';
                }
                sessionEndFlag = true;
            }
            optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c,SmartMsg__Inbound_Response__r.Id,SmartMsg__Outbound_Response__r.SmartMsg__Question_Description__c,SmartMsg__Inbound_Response__r.SmartMsg__Response__c,SmartMsg__Inbound_Response__r.SmartMsg__Type__c,SmartMsg__Outbound_Response__r.SmartMsg__Question__c , SmartMsg__Order_Number__c 
                                                FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND SmartMsg__Inbound_Response__r.SmartMsg__Question__c =: message.trim()  WITH SECURITY_ENFORCED ORDER BY createdDate];
        }
        else{
            //Exact option dialog record based on the end user chooses
            lastDeliveredDialogList = [SELECT Id, SmartMsg__Inbound_Response__r.Id, SmartMsg__Inbound_Response__r.SmartMsg__Response__c, SmartMsg__Inbound_Response__r.SmartMsg__Question__c,SmartMsg__Inbound_Response__r.SmartMsg__Type__c,SmartMsg__Outbound_Response__r.Id,SmartMsg__Outbound_Response__r.SmartMsg__Question__c, SmartMsg__Outbound_Response__r.SmartMsg__Response__c
                                                FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id =: lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.Id AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c =: message.trim() WITH SECURITY_ENFORCED LIMIT 1];
            if(!lastDeliveredDialogList.isEmpty()){
                //Get the next option dialog record match with incoming message
                //Outbound Id is checked with Inbound Id of the next record
                optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c, SmartMsg__Order_Number__c, SmartMsg__Inbound_Response__r.Id,SmartMsg__Inbound_Response__r.SmartMsg__Question__c,SmartMsg__Inbound_Response__r.SmartMsg__Response__c,SmartMsg__Inbound_Response__r.SmartMsg__Type__c,SmartMsg__Outbound_Response__r.SmartMsg__Question__c ,SmartMsg__Outbound_Response__r.SmartMsg__Question_Description__c
                                                FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND SmartMsg__Inbound_Response__r.Id =: lastDeliveredDialogList[0].SmartMsg__Outbound_Response__r.Id WITH SECURITY_ENFORCED ORDER BY createdDate];
                // Get the chosen option based on the customer chooses
                // compare Inbound with last delivered record and compare the outbound question with the incoming messsage
                /*if(optionDialogList.isEmpty()){
                    optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c, SmartMsg__Order_Number__c, SmartMsg__Outbound_Response__r.Id, SmartMsg__Inbound_Response__r.Id,SmartMsg__Outbound_Response__r.SmartMsg__Type__c,SmartMsg__Outbound_Response__r.SmartMsg__Question__c ,SmartMsg__Outbound_Response__r.SmartMsg__Response__c
                                                FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND  SmartMsg__Inbound_Response__r.Id =: lastDeliveredDialogList[0].SmartMsg__Inbound_Response__r.Id AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c =: message.trim()];
                    messageResponse = optionDialogList[0].SmartMsg__Outbound_Response__r.SmartMsg__Response__c;
                    type = optionDialogList[0].SmartMsg__Outbound_Response__r.SmartMsg__Type__c;
                    dialogId = optionDialogList[0].SmartMsg__Outbound_Response__r.Id ;
                    optionDialogId = optionDialogList[0].Id;
                }*/
            }
            if((!lastDeliveredDialogList.isEmpty() && optionDialogList.isEmpty()) || (lastDeliveredDialogList.isEmpty() && optionDialogList.isEmpty())){
                //Get the next record for the consecutive questions
                Decimal orderNumber;
                if(lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c != null){
                    orderNumber = lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c + 1;
                    if((lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c != Constants.OTHER_QUESTION && (lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c.contains(Constants.CONFIRMATION_QUESTION)) && message.contains(Constants.PICKUP_NO_MESSAGE)) || lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c != Constants.OTHER_QUESTION && (lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c.contains(Constants.SCHEDULE_QUESTION))){
                        orderNumber = orderNumber + 1;
                    }
                    if((lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c == 4 && message != 'Need help')){
                        orderNumber = orderNumber + 1;
                    }
                    //Get the next option dialog record to send the response
                    optionDialogList = [SELECT Id, SmartMsg__Outbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id =: lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.Id AND SmartMsg__Order_Number__c =: orderNumber WITH SECURITY_ENFORCED ORDER BY createdDate];
                    optionDialogId = optionDialogList[0].Id;
                    dialogList = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Order_Number__c, SmartMsg__Type__c
                                            FROM SmartMsg__Dialogue__c WHERE SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id WITH SECURITY_ENFORCED];
                    optionDialogList = new List<SmartMsg__Option_Dialog__c>();
                }
            }
            if(dialogList.isEmpty() && !optionDialogList.isEmpty() && optionDialogList[0].SmartMsg__Order_Number__c != null){
                optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__r.Id, SmartMsg__Inbound_Response__r.SmartMsg__Order_Number__c, SmartMsg__Outbound_Response__r.Id
                                        FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND Id =: optionDialogList[0].Id AND SmartMsg__Order_Number__c = 1 WITH SECURITY_ENFORCED ];
                optionDialogId = optionDialogList[0].Id;
                dialogList = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Order_Number__c, SmartMsg__Type__c
                                            FROM SmartMsg__Dialogue__c WHERE SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id WITH SECURITY_ENFORCED ];
                optionDialogList = new List<SmartMsg__Option_Dialog__c>();
            }
        }
        if(!optionDialogList.isEmpty()){
            if(messageResponse == null){
                messageResponse = optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c;
            }
            if(type == null){
                type = optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Type__c;
            }
            if(dialogId == null){
                dialogId = optionDialogList[0].SmartMsg__Inbound_Response__r.Id ;
            }
            optionDialogId = optionDialogList[0].Id;
            if(type == 'Button' || type == 'Option'){
                for(SmartMsg__Option_Dialog__c optionDialog : optionDialogList){
                    String combinedResponse;
                    if(optionDialog.SmartMsg__Outbound_Response__r.SmartMsg__Question_Description__c != null){
                        combinedResponse = optionDialog.SmartMsg__Outbound_Response__r.SmartMsg__Question__c +' - ' +optionDialog.SmartMsg__Outbound_Response__r.SmartMsg__Question_Description__c;
                    }else{
                        combinedResponse = optionDialog.SmartMsg__Outbound_Response__r.SmartMsg__Question__c;
                    }
                    if(!interactionsList.contains(combinedResponse)){
                        interactionsList.add(combinedResponse);
                    }
                }
            }
        }else{
            messageResponse = dialogList[0].SmartMsg__Response__c;
            type = dialogList[0].SmartMsg__Type__c;
            dialogId = dialogList[0].Id;
            if(type == 'Button' || type == 'Option'){
                for(SmartMsg__Dialogue__c optionDialog : dialogList){
                    interactionsList.addAll((optionDialog.SmartMsg__Buttons_or_Options__c).split('\n'));
                }
            }
        }
        if(type != null && (type == 'Button' || type == 'Option')){
            contentTemplateName = getContentName(type,interactionsList);
        }else{
            contentTemplateName = Constants.DYNAMIC_TEXT_TEMPLATE_NAME;
        }
        wrapper wrap = new wrapper();
        wrap.contentTemplateName = contentTemplateName;
        wrap.messageBody = messageResponse;
        wrap.interactionList = interactionsList;
        wrap.fromNumber = fromNumber;
        wrap.toNumber = phoneNumber;
        wrap.dialogId = dialogId;
        wrap.optionDialogId = optionDialogId;
        wrap.sessionEndFlag = sessionEndFlag;
        wrap.responseType = type;
        if(wrap != null){
            // System.debug('Inside of calling the Queueable');
            System.enqueueJob(new TwilioWhatsAppController(wrap));
            // System.debug('Queuable Executed');
        }
    }

    /**
     * @description Derives the Twilio Content template friendly name from the interaction type and list size (e.g. quick-reply or list-picker with/without description).
     * @param type The interaction type ('button', 'Separate Button', or 'option' for list picker).
     * @param interactionsList The list of button/option titles or items.
     * @return The content template name (e.g. 2_dynamic_quick_reply, 3_dynamic_list_picker).
     */
    public static string getContentName(String type, List<String> interactionsList){
        String size = String.valueOf(interactionsList.size());
        String contentTemplateName;
        if(type == 'button' || type == 'Separate Button'){
            contentTemplateName = size+Constants.DYNAMIC_QUICK_REPLY_TEMPLATE_NAME;
        }else{
            boolean description = false;
            for(String str : interactionsList){
                if(str.contains('-')){
                    description = true;
                }
            }
            if(description){
                contentTemplateName = size+Constants.DYNAMIC_LIST_PICKER_TEMPLATE_NAME;
            }else{
                contentTemplateName = size+Constants.DYNAMIC_LIST_PICKER_WITH_NO_DESCRIPTION;
            }
        }
        return contentTemplateName;
    }

    /**
     * @description Wrapper holding parameters passed from the chatbot flow to TwilioWhatsAppController (message body, template name, dialog/option IDs, session flag, etc.).
     */
    public class wrapper{
        public string contentTemplateName;
        public String messageBody;
        public List<String> interactionList;
        public String fromNumber;
        public String responseType;
        public String toNumber;
        public Id dialogId;
        public Id optionDialogId;
        public Boolean sessionEndFlag;
    }
}