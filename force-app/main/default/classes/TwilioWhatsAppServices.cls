/**
 * @description Service class for sending WhatsApp messages via Twilio. Handles text message delivery using Twilio WhatsApp API.
 */
public with sharing class TwilioWhatsAppServices {

    private static SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
    private static final String ACCOUNT_SID = twilioWhatsappSetting.SmartMsg__Account_SID__c;
    private static final String AUTH_TOKEN = twilioWhatsappSetting.SmartMsg__Auth_Token__c;
    private static final String FROM_NUMBER = twilioWhatsappSetting.SmartMsg__Twilio_Phone_Number__c;

/**
* @description Sends a text message to a specified phone number via WhatsApp.
* @param messageContent The content of the text message.
* @param toPhone The phone number to which the message will be sent.
* @return A Message__c record representing the sent message.
* @throws AuraHandledException If there are issues with permissions or if an error occurs during the HTTP request.
*/
    public static SmartMsg__Message__c sendTextMessage(String messageContent, String toPhone) {
        return sendTextMessage(messageContent, toPhone, null);
    }

    /**
     * @description Sends a text message with optional from number (used when user selects from dropdown in chat).
     * @param messageContent The content of the text message.
     * @param toPhone The phone number to which the message will be sent.
     * @param fromNumber Optional. When provided, used as the From number; otherwise uses Twilio_Phone_Number__c from settings.
     * @return The created SmartMsg__Message__c record representing the sent message.
     */
    public static SmartMsg__Message__c sendTextMessage(String messageContent, String toPhone, String fromNumber) {
        String fromNum = String.isNotBlank(fromNumber) ? (fromNumber.startsWith('+') ? fromNumber : '+' + fromNumber) : FROM_NUMBER;
        SmartMsg__Message__c messageRec;
        if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create this message.');
        }
        String endpoint = 'callout:SmartMsg__Twilio_WhatsApp/2010-04-01/Accounts/'+ACCOUNT_SID+'/Messages.json';
        HttpRequest req = new HttpRequest();
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        String messageBody = 'To=whatsapp:' + EncodingUtil.urlEncode(toPhone, 'UTF-8') +
                            '&From=whatsapp:' + EncodingUtil.urlEncode(fromNum, 'UTF-8') +
                            '&Body=' + EncodingUtil.urlEncode(messageContent, 'UTF-8');
        // Status callback is not used for manual sends; only chatbot (TwilioWhatsAppController) uses it.
        req.setBody(messageBody);
        Http http = new Http();
        HttpResponse response = http.send(req);
        if(response.getStatusCode() == 200 || response.getStatusCode() == 201){
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            messageRec = new SmartMsg__Message__c();
            messageRec.SmartMsg__From_Number__c = String.valueOf(result.get('from')).split(':')[1];
            messageRec.SmartMsg__To_Number__c = String.valueOf(result.get('to')).split(':')[1];
            messageRec.SmartMsg__Message_Body__c = (String) result.get('body');
            messageRec.SmartMsg__Delivery_Status__c = 'sent';
            messageRec.SmartMsg__Message_Type__c = 'text';
            messageRec.SmartMsg__Sent_Date_and_Time__c = Datetime.now();
            messageRec.SmartMsg__Message_ID__c = (String) result.get('sid');
            messageRec.SmartMsg__Channel__c = 'WhatsApp';
            messageRec.SmartMsg__Type__c = 'Outbound';
            if (!CommonUtil.hasFLS(messageRec)) {
                throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
            }
            insert messageRec;
        }

        return messageRec;
    }
}