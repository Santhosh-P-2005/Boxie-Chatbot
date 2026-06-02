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
        String normalizedNumber = normalizeSessionPhone(toNumber);
        if (String.isBlank(normalizedNumber)) {
            return null;
        }
        List<SmartMsg__Messaging_Session__c> messagingSession = [
            SELECT Id, SmartMsg__To_Number__c, SmartMsg__Session_status__c
            FROM SmartMsg__Messaging_Session__c
            WHERE SmartMsg__To_Number__c = :normalizedNumber
            AND SmartMsg__Session_status__c != 'Completed'
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if(!messagingSession.isEmpty()){
            return messagingSession[0].Id;
        }else{
            SmartMsg__Messaging_Session__c newMessagingSession = new SmartMsg__Messaging_Session__c();
            newMessagingSession.SmartMsg__To_Number__c = normalizedNumber;
            newMessagingSession.SmartMsg__Session_status__c = String.isNotBlank(sessionStatus)
                ? sessionStatus
                : 'Customer Message Received';
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
     * @description Gets or creates an open messaging session for agent/UI outbound messages.
     *              Outbound count is incremented when the message is actually sent (e.g. TwilioWhatsAppServices).
     * @param toNumber Recipient phone number (with or without leading +).
     * @return The Id of the existing or newly created messaging session.
     */
    public static Id messagingSessionForOutbound(String toNumber) {
        String normalizedNumber = normalizeSessionPhone(toNumber);
        if (String.isBlank(normalizedNumber)) {
            return null;
        }
        return messagingSession(normalizedNumber, 'Automation Sent');
    }

  @TestVisible
    private static String normalizeSessionPhone(String toNumber) {
        if (String.isBlank(toNumber)) {
            return null;
        }
        String normalizedNumber = toNumber.replaceAll('[^\\d+]', '');
        if (!normalizedNumber.startsWith('+')) {
            normalizedNumber = '+' + normalizedNumber;
        }
        return normalizedNumber;
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
        List<SmartMsg__Message__c> lastOutBoundMessageRecord = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Dialogue__r.SmartMsg__Type__c, SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c,SmartMsg__Dialogue__r.Id, SmartMsg__Dialogue__r.SmartMsg__Order_Number__c, SmartMsg__Option_Dialog__c, SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c,SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.Id, SmartMsg__Option_Dialog__r.SmartMsg__Outbound_Response__r.Id, SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c,SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Question__c
                                                                    FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c =: phoneNumber AND SmartMsg__Type__c = 'Outbound'  WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1 ];
        

        //System.debug('message: ' + message);
        // System.debug('fromNumber: ' + fromNumber);
        if(fromNumber.startsWith('+49')){
            message = message.replace('Englisch', 'English');
        }
        List<String> triggerList = new List<String>{'hi','hoi','hallo'};
        if(triggerList.contains(message.toLowerCase())){
            if(fromNumber.startsWith('+49')){
                message = 'Hallo';
            } 
            else if(fromNumber.startsWith('+31')){
                message = 'Hoi';
            }
            else{
                message = 'Hi';
            }
        }
        System.debug('message: ' + message);
        if(message != null && message != ''){
            String normalizedPhone = normalizeSessionPhone(phoneNumber);
            List<SmartMsg__Messaging_Session__c> messagingSession = [
                SELECT Id, SmartMsg__To_Number__c, SmartMsg__No_of_Inbound_Messages__c, SmartMsg__Session_status__c
                FROM SmartMsg__Messaging_Session__c
                WHERE SmartMsg__To_Number__c = :normalizedPhone
                AND SmartMsg__Session_status__c != 'Completed'
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if(messagingSession.isEmpty() || messagingSession[0].SmartMsg__No_of_Inbound_Messages__c == 1){
                if(fromNumber.startsWith('+49')){
                    //German
                    message = 'Hallo';
                }
                else if(fromNumber.startsWith('+31')){
                    //Dutch
                    message = 'Hoi';
                }
                else{
                    //English
                    message = 'Hi';
                }
            }
        }

        if(Constants.LANGUAGE_LIST.contains(message)){
            SmartMsg__Message__c emptyMsgRecord = [SELECT Id FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c =: phoneNumber AND SmartMsg__Type__c = NULL AND SmartMsg__Channel__c = NULL WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1 ];
            if(emptyMsgRecord != null){
                emptyMsgRecord.SmartMsg__Message_Body__c = message;
                update emptyMsgRecord;
            }
        }

        List<String> yesList = new List<String>{'Yes, please!','Ja, graag!','Ja, bitte!'};
        List<String> noList = new List<String>{'No, that\'s all.','Nee, dat is alles.', 'Nein, das ist alles.'};
        List<String> movingBoxesList = new List<String>{'Moving Boxes','Verhuisdozen', 'Umzugskisten'};
        List<String> viewFAQsList = new List<String>{'❓ View FAQs','❓ Bekijk de FAQs','❓ FAQs ansehen'};
        List<String> existingCustomerList = new List<String>{'Existing Customer','Bestaande klant','Bestandskunde'};
        List<String> newCustomerList = new List<String>{'New Customer','Neukunde','Nieuwe klant'};
        
        if(lastOutBoundMessageRecord.isEmpty() || (message == 'Hi' || message == 'Hoi' || message == 'Hallo') || (responseType == 'button_reply' && lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && yesList.contains(message)) || (responseType == 'button_reply'&& lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && noList.contains(message))){
            // get the option dialog record for "Hi"
            
            if((responseType == 'button_reply' && yesList.contains(message))){
                String question = lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c;
                System.debug('question: ' + question);
                if(( movingBoxesList.contains(question)) || (viewFAQsList.contains(question)) || newCustomerList.contains(question)){
                    if(question == 'Moving Boxes' || question == '❓ View FAQs' || question == 'New Customer'){
                        message = 'English';
                        System.debug('First message: ' + message);  
                    }
                    else if(question == 'Verhuisdozen' || question == '❓ Bekijk de FAQs' || question == 'Nieuwe klant'){
                        message = 'Nederlands';
                    }
                    else if(question == 'Umzugskisten' || question == '❓ FAQs ansehen' || question == 'Neukunde'){
                        message = 'Deutsch';
                    }
                }else{
                    message = question;
                    System.debug('Second message: ' + message);
                }
            }
            System.debug('Third message: ' + message);
            if((responseType == 'button_reply' && !lastOutBoundMessageRecord.isEmpty() && lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && noList.contains(message))){
                String question = lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c;
                if(existingCustomerList.contains(question)){
                    if(question == 'Existing Customer'){
                        message = 'No';
                    }
                    else if(question == 'Bestaande klant'){
                        message = 'Nee';
                    }
                    else if(question == 'Bestandskunde'){
                        message = 'Nein';
                    }
                }
                else if((movingBoxesList.contains(question)) || (viewFAQsList.contains(question))){
                    if(question == 'Moving Boxes' || question == '❓ View FAQs'){
                        message = 'Rent No';
                    }
                    else if(question == 'Verhuisdozen' || question == '❓ Bekijk de FAQs'){
                        message = 'Huur No';
                    }
                    else if(question == 'Umzugskisten' || question == '❓ FAQs ansehen'){
                        message = 'Miete Nr.';
                    }
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
                    String question = lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c;
                    
                    // if(((lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c.contains(Constants.CONFIRMATION_QUESTION)) && message.contains(Constants.PICKUP_NO_MESSAGE)) || (lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c != Constants.OTHER_QUESTION && (lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c.contains(Constants.SCHEDULE_QUESTION)))){
                    //     orderNumber = orderNumber + 1;
                    // }
                    Boolean confirmChecker = false;
                    Boolean scheduleChecker = false;
                    Boolean pickupNoChecker = false;

                    for(String str : Constants.PICKUP_NO_MESSAGE){
                        if(message.contains(str)){
                            pickupNoChecker = true;
                        }
                    }
                    for(String str : Constants.CONFIRMATION_QUESTION){
                        if(lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c.contains(str)){
                            confirmChecker = true;
                        }
                    }
                    for(String str : Constants.SCHEDULE_QUESTION){
                        if(lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c.contains(str)){
                            scheduleChecker = true;
                        }
                    }

                    if((!Constants.OTHER_QUESTION.contains(question) && confirmChecker && pickupNoChecker)
                     || (!Constants.OTHER_QUESTION.contains(question) && scheduleChecker)){
                        orderNumber = orderNumber + 1;
                    }
                    String optionDialogQuestion = lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.SmartMsg__Question__c;
                    Boolean reservationChecker = false;
                    for(String str : Constants.RESERVATION){
                        if(optionDialogQuestion.contains(str)){
                            reservationChecker = true;
                        }
                    }
                    Integer recordOrderNumber = (Integer)lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c;
                    String lastResponseMessage = (String)lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c;
                    Boolean emailChecker = false;
                    for(String str : Constants.EMAIL_LIST){
                        if(lastResponseMessage.contains(str)){
                            emailChecker = true;
                        }
                    }
                    if(emailChecker && recordOrderNumber != null){
                        if(reservationChecker || Constants.MORE_ITEMS_LIST.contains(optionDialogQuestion)){
                            if(emailValidation(message) && (recordOrderNumber == 2)){
                                orderNumber = orderNumber + 1;
                            }
                            if(!emailValidation(message) && (recordOrderNumber == 3)){
                                orderNumber = orderNumber - 1;
                            }
                        }
                        else{
                            if(emailValidation(message) && (recordOrderNumber == 1)){
                                orderNumber = orderNumber + 1;
                            }
                            if(!emailValidation(message) && (recordOrderNumber == 2)){
                                orderNumber = orderNumber - 1;
                            }
                        }
                    }
                    if((lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c == 5 && reservationChecker)){
                        if(message != 'I Need help' && message != 'Ik ben hulp nodig' && message != 'Ich brauche Hilfe'){
                            orderNumber = orderNumber + 1;
                        }
                    }
                    // System.debug('lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Type__c: ' + lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Type__c);
                    // System.debug('messageBody: ' + lastOutBoundMessageRecord[0].SmartMsg__Message_Body__c);

                    if(lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Type__c == 'Separate Option'){
                        orderNumber = orderNumber + 1;
                    }
                    //Get the next option dialog record to send the response
                    optionDialogList = [SELECT Id, SmartMsg__Outbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id =: lastOutBoundMessageRecord[0].SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.Id AND SmartMsg__Order_Number__c =: orderNumber WITH SECURITY_ENFORCED ORDER BY createdDate];
                    optionDialogId = optionDialogList[0].Id;
                    dialogList = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Order_Number__c, SmartMsg__Type__c
                                            FROM SmartMsg__Dialogue__c WHERE SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
                    optionDialogList = new List<SmartMsg__Option_Dialog__c>();
                }
            }
            if(dialogList.isEmpty() && !optionDialogList.isEmpty() && optionDialogList[0].SmartMsg__Order_Number__c != null){
                optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__r.Id, SmartMsg__Inbound_Response__r.SmartMsg__Order_Number__c, SmartMsg__Outbound_Response__r.Id
                                        FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND Id =: optionDialogList[0].Id AND SmartMsg__Order_Number__c = 1 WITH SECURITY_ENFORCED ];
                optionDialogId = optionDialogList[0].Id;
                dialogList = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Order_Number__c, SmartMsg__Type__c
                                            FROM SmartMsg__Dialogue__c WHERE SmartMsg__Parent_Template__r.SmartMsg__Active__c = true AND Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC];
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
        if((messageResponse.contains('en-de') || messageResponse.contains('/date') || messageResponse.contains('boxie24-de')) && (fromNumber.startsWith('+31'))){
            messageResponse = messageResponse.replace('en-de/moving-boxes/rent', 'en-nl/moving-boxes');
            messageResponse = messageResponse.replace('en-de', 'en-nl');
            messageResponse = messageResponse.replace('/date/', '/appointment/');
            messageResponse = messageResponse.replace('boxie24-de', 'boxie24-nl');
        }
        String language;
        List<SmartMsg__Message__c> emptyMsgRecords = [
            SELECT Id, SmartMsg__Message_Body__c
            FROM SmartMsg__Message__c
            WHERE SmartMsg__To_Number__c =: phoneNumber AND SmartMsg__Type__c = NULL AND SmartMsg__Channel__c = NULL
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if(!emptyMsgRecords.isEmpty() && String.isNotBlank(emptyMsgRecords[0].SmartMsg__Message_Body__c)){
            language = emptyMsgRecords[0].SmartMsg__Message_Body__c.toLowerCase();
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
        wrap.language = language;
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

    public static Boolean emailValidation(String email){
        Pattern p = Pattern.compile('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
        Matcher m = p.matcher(email);
        if(m.matches()){
            return true;
        }
        return false;
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
        public String language;
        public String toNumber;
        public Id dialogId;
        public Id optionDialogId;
        public Boolean sessionEndFlag;
    }
}