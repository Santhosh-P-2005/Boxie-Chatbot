/**
 * @description Chatbot controller for WhatsApp conversation flow: sends payloads, manages messaging sessions,
 * and determines the next response based on dialogue and option-dialog configuration (Meta WhatsApp).
 */
public without sharing class WhatsAppChatBot {
    public static Boolean sessionEndFlag = false;
    /**
     * @description Sends a text message payload for WhatsApp messaging.
     * @param response The response text to be sent as the message body.
     * @param toNumber The recipient's phone number.
     * @return A Map<String,Object> containing the formatted payload for the WhatsApp API.
     */
    public static Map<String,Object> sendTextMessagePayload(String response, String toNumber){
        Map<String,Object> payload;
        Map<String,Object> text = new Map<String,Object>{
            'preview_url' => false,
            'body' => response
        };
        payload = new Map<String,Object>{
            'messaging_product' => 'whatsapp',
            'recipient_type' => 'individual',
            'to' => toNumber,
            'type' => 'text',
            'text' => text
        };
        if(payload != null){
            return payload;
        }else{
            return null;
        }
    }
    /**
     * @description Retrieves or creates a messaging session based on the provided phone number and session status.
     * @param toNumber The phone number to search for or create a session for.
     * @param sessionStatus The status to set for the messaging session.
     * @return The Id of the existing or newly created messaging session.
     */
    public static Id messagingSession(String toNumber, String sessionStatus){
        // toNumber = '+' + toNumber;
        List<SmartMsg__Messaging_Session__c> messagingSession = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c FROM SmartMsg__Messaging_Session__c WHERE SmartMsg__To_Number__c = :toNumber AND SmartMsg__Session_status__c != 'Completed'  WITH SECURITY_ENFORCED];
        if(!messagingSession.isEmpty()){
            return messagingSession[0].Id;
        }else{
            SmartMsg__Messaging_Session__c newMessagingSession = new SmartMsg__Messaging_Session__c();
            newMessagingSession.SmartMsg__To_Number__c = toNumber;
            newMessagingSession.SmartMsg__Session_status__c = sessionStatus;
            newMessagingSession.SmartMsg__Start_Time__c = System.Now();
            newMessagingSession.SmartMsg__No_of_Inbound_Messages__c = 1;
            newMessagingSession.SmartMsg__No_of_Outbound_Messages__c = 0;
            WhatsAppMessageUpdateHelper.sessionUpdateFlag = false;
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
     * @description Gets the next response record based on the incoming message and enqueues the WhatsApp send job (option/dialogue flow).
     * @param phoneNumber The recipient phone number used in the payload.
     * @param message The incoming message text (e.g. user reply or button title).
     * @param responseType The type of response (e.g. 'text', 'button_reply', 'list_reply').
     */
    public static void nextResponseRecordWhatsAppChatbot(String phoneNumber, String message, String responseType){
        String messageResponse;
        String type;
        Id dialogId;
        Id optionDialogId;
        List<String> interactionsList = new List<String>();
        Map<String,Object> payload;
        List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>();
        List<SmartMsg__Dialogue__c> dialogList = new List<SmartMsg__Dialogue__c>();
        List<SmartMsg__Option_Dialog__c> lastDeliveredDialogList = new List<SmartMsg__Option_Dialog__c>();
        List<SmartMsg__Message__c> lastOutBoundMessageRecord = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Dialogue__r.SmartMsg__Parent_Record__r.SmartMsg__Question__c,SmartMsg__Dialogue__r.Id, SmartMsg__Dialogue__r.SmartMsg__Order_Number__c, SmartMsg__Option_Dialog__c, SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c,SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.Id
                                            FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c =: phoneNumber AND SmartMsg__Type__c = 'Outbound' WITH SECURITY_ENFORCED  ORDER BY CreatedDate DESC LIMIT 1 ];
        // List<SmartMsg__Message__c> lastInBoundMessageRecord = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Dialogue__r.Id, SmartMsg__Dialogue__r.SmartMsg__Order_Number__c, SmartMsg__Option_Dialog__c, SmartMsg__Option_Dialog__r.SmartMsg__Order_Number__c,SmartMsg__Option_Dialog__r.SmartMsg__Inbound_Response__r.Id
        //                                     FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c =: phoneNumber AND SmartMsg__Type__c = 'Inbound'  ORDER BY CreatedDate DESC LIMIT 1 ];
        
        if(message != null && message != ''){
            List<SmartMsg__Messaging_Session__c> messagingSession = [SELECT Id, SmartMsg__To_Number__c, SmartMsg__No_of_Inbound_Messages__c,  SmartMsg__Session_status__c FROM SmartMsg__Messaging_Session__c WHERE SmartMsg__To_Number__c = :phoneNumber AND SmartMsg__Session_status__c != 'Completed'  WITH SECURITY_ENFORCED];
            if(messagingSession.isEmpty() || messagingSession[0].SmartMsg__No_of_Inbound_Messages__c == 1){
                message = 'Hi';
            }
        }

        if(lastOutBoundMessageRecord.isEmpty() || message == 'Hi' || (responseType == 'button_reply' && lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && message == 'Yes') || (responseType == 'button_reply'&& lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && message == 'No, that\'s all.')){
            // get the option dialog record for "Hi"
            if((responseType == 'button_reply' && message == 'Yes')){
                message = 'English';
            }
            if((responseType == 'button_reply' && lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Order_Number__c == null && message == 'No, that\'s all.')){
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
            //System.debug(optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c);
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
            // if(optionDialogId == null){
                //     dialogId = dialogList[0].Id;
            // }
            dialogId = dialogList[0].Id;
            if(type == 'Button' || type == 'Option'){
                for(SmartMsg__Dialogue__c optionDialog : dialogList){
                    interactionsList.addAll((optionDialog.SmartMsg__Buttons_or_Options__c).split('\n'));
                }
            }
        }
        if(type != null && (type == 'Button' || type == 'Option')){
            payload = dynamicJSON(messageResponse,interactionsList,type,phoneNumber);
        }else{
            payload = sendTextMessagePayload(messageResponse,phoneNumber);
        }
        if(payload != null){
            System.enqueueJob(new SendWhatsAppMessagesWithUpdatedJSON(payload,messageResponse,phoneNumber,dialogId,optionDialogId,sessionEndFlag));
        }
    }
    
    /**
     * @description Generates a dynamic JSON payload for WhatsApp interactive messages (buttons or list picker).
     * @param response The text content of the message body.
     * @param quickReplyButtonsList List of button or option titles for the interactive message.
     * @param type Type of interactive message ('button', 'Separate Button', or 'option').
     * @param toNumber The recipient's phone number.
     * @return A map containing the formatted payload for the WhatsApp API.
     */
    public static Map<String,Object> dynamicJSON(String response, List<String> quickReplyButtonsList, String type,String toNumber){
        //List<String> quickReplyButtonsList = buttons.split('\n');
        Map<String,Object> payload;
        List<Object> rows = new List<Object>();
        if(type != null){
            Map<String,Object> interactive;
            Map<String,Object> actionMap;
            if(type == 'button' || type == 'Separate Button'){
                for(String quickReplyButton : quickReplyButtonsList){
                    
                    Map<String, Object> values = new Map<String, Object>{
                        'id' => quickReplyButton!= null? quickReplyButton.toLowerCase().replaceAll('\\s+', '_') : null,
                        'title' => quickReplyButton
                    };
                    Map<String, Object> wrapperValues = new Map<String, Object>{
                        'reply' => values,
                        'type' => 'reply'
                    };
                    rows.add(wrapperValues);
                }
                actionMap = new Map<String,Object>{
                    'buttons' => rows
                };
                interactive = new Map<String,Object>{
                    'type' => 'button',
                    'body' => new Map<String,Object>{
                        'text' => response
                    },
                    'action' => actionMap
                };
            }else if(type == 'option'){
                for (String options : quickReplyButtonsList) {
                    String description = options;
                    if(options.length() > 24){
                        options = options.substring(0,23);
                    }
                    Map<String, Object> row = new Map<String, Object>{
                        'id' =>  options != null? options.toLowerCase().replaceAll('\\s+', '_') : null ,
                        'title' => options.contains('-') ? options.split('-')[0] : options
                    };
                    String descriptionValue = description.contains('-') ? description.split('-')[1] : '';
                    if(descriptionValue != null && descriptionValue.trim() != ''){
                        row.put('description', descriptionValue);
                    }
                    rows.add(row);
                }
                Map<String, Object> section = new Map<String, Object>{
                    'title' => 'Support Options',
                    'rows'  => rows
                };
                actionMap = new Map<String,Object>{
                    'sections' => new List<object>{section},
                    'button' => 'Choose Option'
                };
                interactive = new Map<String,Object>{
                    'type' => 'list',
                    'body' => new Map<String,Object>{
                        'text' => response
                    },
                    'action' => actionMap
                };
            }
            payload = new Map<String,Object>{
                'messaging_product' => 'whatsapp',
                'to' => toNumber,
                'type' => 'interactive',
                'recipient_type' => 'individual',
                'interactive' => interactive
            };
        }
        return payload;
    }






    /**
     * @description Sends a WhatsApp text message via Twilio API. Used when channel is Twilio WhatsApp.
     * @param phoneNumber The recipient phone number (E.164).
     * @param messageBody The body text of the message.
     * @param recordId Optional related record Id (unused in current implementation).
     * @return List of Message__c records (currently always null after successful send).
     */
    public static List<SmartMsg__Message__c> makeCallout(String phoneNumber, String messageBody, String recordId){
        // List<SmartMsg__Dialogue__c> dialogList = new  List<SmartMsg__Dialogue__c>();
        SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = ProviderSettingUtil.getTwilioWhatsAppProviderSetting('Twilio_WhatsApp');
        //SmartMsg__Meta_Configuration__c whatsAppCreds = WhatsAppProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        String accountSid = twilioWhatsappSetting.SmartMsg__Account_SID__c;
        // String statusCallbackUrl = twilioWhatsappSetting.SmartMsg__StatusCallbackUrl__c;
        // Construct endpoint with Named Credential
        String endpoint = 'callout:SmartMsg__Twilio_API/2010-04-01/Accounts/' + accountSid + '/Messages.json';
        // Construct HTTP Request
        HttpRequest req = new HttpRequest();
            String fromStr = 'whatsapp:' + String.valueOf(twilioWhatsappSetting.SmartMsg__Twilio_Phone_Number__c);
            //req.setEndpoint(TwilioConfigs.Twilio_Endpoint__c + TwilioConfigs.Account_SID__c + '/Messages.json');
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            //req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(TwilioConfigs.Account_SID__c + ':' + TwilioConfigs.Auth_Token__c)));
            // Start constructing the request body
            String bodyContent = 'To=whatsapp:' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8') + 
                                '&From=' + EncodingUtil.urlEncode(fromStr, 'UTF-8') + 
                                '&Body=' + EncodingUtil.urlEncode(messageBody, 'UTF-8');
        //String messageBody = constructSMSBody(phoneNumber, smsBody, statusCallbackUrl);
        req.setBody(bodyContent);
        Http http = new Http();
        try{
            /*HttpResponse response = */http.send(req);
            // if( response.getStatusCode() == 200 ){
            //     whatsAppServices responseFromWA = (whatsAppServices) JSON.deserialize( response.getBody() , whatsAppServices.class);
            //     if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() && !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
            //         throw new AuraHandledException('You do not have permission to create this message.');
            //     }
            //     //salesforceMessage.SmartMsg__From_Number__c = fromNumber;
            //     SmartMsg__Message__c salesforceMessage = new SmartMsg__Message__c();
            //     salesforceMessage.SmartMsg__Message_Body__c = messageBody;
            //     salesforceMessage.SmartMsg__To_Number__c = toPhone;
            //     salesforceMessage.SmartMsg__Message_ID__c = responseFromWA.messages.get(0).id;
            //     salesforceMessage.SmartMsg__Message_Type__c = 'text';
            //     salesforceMessage.SmartMsg__Type__c = 'Outbound';
            //     salesforceMessage.SmartMsg__Channel__c = 'WhatsApp';
            //     salesforceMessage.SmartMsg__Delivery_Status__c = 'Sent';
            //     salesforceMessage.SmartMsg__Outgoing__c = True;
            //     salesforceMessage.SmartMsg__Response__c = response.getBody();
            //     salesforceMessage.SmartMsg__Sent_Date_and_Time__c = DateTime.now();
            //     if(dialogueId != null){
            //         salesforceMessage.SmartMsg__Dialogue__c = dialogueId;
            //     }
            //     if(optionDialogId != null){
            //         salesforceMessage.SmartMsg__Option_Dialog__c = optionDialogId;
            //     }
            //     salesforceMessageList.add(salesforceMessage);
            //     if (!CommonUtil.hasFLS(salesforceMessage)) {
            //         throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
            //     }
            //     List<String> quickReplyActionsList = new List<String>();
            //     List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>();
            //     if(optionDialogId != null){
            //         optionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c, SmartMsg__Inbound_Response__r.Id,SmartMsg__Outbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id =: dialogueId];
            //         if(!optionDialogList.isEmpty()){
            //             dialogList = [SELECT Id, SmartMsg__Parent_Record__c, SmartMsg__Buttons_or_Options__c,SmartMsg__Type__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE Id =: optionDialogList[0].SmartMsg__Outbound_Response__r.Id];
            //         }
            //     }
            //     if(!dialogList.isEmpty() && (dialogList.get(0).SmartMsg__Type__c == 'Separate Button' || dialogList.get(0).SmartMsg__Type__c == 'Separate Option' || dialogList.get(0).SmartMsg__Type__c == 'Separate Text')){
            //         String messageBody = dialogList.get(0).SmartMsg__Response__c;
            //         String type = dialogList.get(0).SmartMsg__Type__c;
            //         if(!dialogList.isEmpty()){
            //             if(dialogList[0].SmartMsg__Buttons_or_Options__c != null ){
            //                 quickReplyActionsList = (dialogList[0].SmartMsg__Buttons_or_Options__c).split('\n');
            //             }
            //             Map<String,Object> finalInteractionPayload = WhatsAppChatBot.dynamicJSON(messageBody,quickReplyActionsList,type,toPhone);
            //             makeCallout(finalInteractionPayload, messageBody, toPhone, dialogList.get(0).Id,null);
            //         }
            //     }
            // }
        }catch(System.CalloutException ex){
            throw new AuraHandledException('CalloutException: ' + ex.getMessage());
        }
        return null;
    }
}