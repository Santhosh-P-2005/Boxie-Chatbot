/**
 * @description Service class for sending WhatsApp messages via Twilio. Handles text message delivery using Twilio WhatsApp API.
 */
public without sharing class TwilioWhatsAppServices {

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
            incrementOutboundMessageCountForRecipient(toPhone);
        }

        return messageRec;
    }

    /**
     * @description Sends a WhatsApp media message via Twilio for an existing Message__c record.
     * @param messageRecordId Existing SmartMsg__Message__c Id (created before send).
     * @param mediaUrl Publicly accessible media URL for Twilio MediaUrl parameter.
     * @param toPhone Recipient phone number.
     * @param caption Optional message body/caption sent with the media.
     * @param fromNumber Optional from number; defaults to Twilio_Phone_Number__c from settings.
     * @return Updated SmartMsg__Message__c record.
     */
    public static SmartMsg__Message__c sendMediaMessage(Id messageRecordId, String mediaUrl, String toPhone, String caption, String fromNumber) {
        if (messageRecordId == null || String.isBlank(mediaUrl)) {
            throw new AuraHandledException('Message record Id and media URL are required.');
        }
        if (!Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update this message.');
        }

        SmartMsg__Message__c messageToUpdate = [
            SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Delivery_Status__c, SmartMsg__Message_ID__c,
                   SmartMsg__File_Name__c, SmartMsg__From_Number__c, SmartMsg__To_Number__c
            FROM SmartMsg__Message__c
            WHERE Id = :messageRecordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        String toNum = String.isNotBlank(toPhone) ? (toPhone.startsWith('+') ? toPhone : '+' + toPhone) : messageToUpdate.SmartMsg__To_Number__c;
        String fromNum = String.isNotBlank(fromNumber) ? (fromNumber.startsWith('+') ? fromNumber : '+' + fromNumber) : FROM_NUMBER;
        String endpoint = 'callout:SmartMsg__Twilio_WhatsApp/2010-04-01/Accounts/' + ACCOUNT_SID + '/Messages.json';

        HttpRequest req = new HttpRequest();
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setEndpoint(endpoint);
        req.setMethod('POST');

        String messageBody = 'To=whatsapp:' + EncodingUtil.urlEncode(toNum, 'UTF-8') +
            '&From=whatsapp:' + EncodingUtil.urlEncode(fromNum, 'UTF-8') +
            '&MediaUrl=' + EncodingUtil.urlEncode(mediaUrl, 'UTF-8');
        String bodyText = String.isNotBlank(caption) ? caption : messageToUpdate.SmartMsg__Message_Body__c;
        if (String.isNotBlank(bodyText)) {
            messageBody += '&Body=' + EncodingUtil.urlEncode(bodyText, 'UTF-8');
        }
        req.setBody(messageBody);

        Http http = new Http();
        HttpResponse response = http.send(req);

        if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            messageToUpdate.SmartMsg__From_Number__c = String.valueOf(result.get('from')).contains(':')
                ? String.valueOf(result.get('from')).split(':')[1]
                : fromNum;
            messageToUpdate.SmartMsg__To_Number__c = String.valueOf(result.get('to')).contains(':')
                ? String.valueOf(result.get('to')).split(':')[1]
                : toNum;
            messageToUpdate.SmartMsg__Message_Body__c = String.isNotBlank(bodyText) ? bodyText : (String) result.get('body');
            messageToUpdate.SmartMsg__Delivery_Status__c = 'Sent';
            messageToUpdate.SmartMsg__Message_ID__c = (String) result.get('sid');
            messageToUpdate.SmartMsg__Sent_Date_and_Time__c = Datetime.now();
            messageToUpdate.SmartMsg__Channel__c = 'WhatsApp';
            messageToUpdate.SmartMsg__Type__c = 'Outbound';
            if (!CommonUtil.hasFLS(messageToUpdate)) {
                throw new AuraHandledException('You do not have the necessary field permissions to update Message records.');
            }
            update messageToUpdate;
            WhatsAppMessageUpdateHelper.shareMessageWithGuestUserForStatusCallback(messageToUpdate.Id);
            incrementOutboundMessageCountForRecipient(toNum);
        } else {
            messageToUpdate.SmartMsg__Delivery_Status__c = 'Failed';
            messageToUpdate.SmartMsg__Failed_Reason__c = response.getBody();
            update messageToUpdate;
            throw new AuraHandledException('Twilio WhatsApp media send failed: ' + response.getBody());
        }

        List<SmartMsg__Message__c> messages = [
            SELECT Id, Name, SmartMsg__Message_Body__c, SmartMsg__Channel__c, SmartMsg__To_Number__c, SmartMsg__Media_Url__c,
                   SmartMsg__Retry_Count__c, SmartMsg__FilesBiSync_Related_Folder_Ids__c, SmartMsg__Delivery_Status__c,
                   SmartMsg__is_Bulk__c, SmartMsg__Pinned__c, SmartMsg__Starred__c, CreatedDate, SmartMsg__Type__c,
                   SmartMsg__File_Content__c, SmartMsg__File_Name__c, SmartMsg__Sent_Date_and_Time__c, CreatedBy.Name,
                   SmartMsg__Scheduled_Date_Time__c
            FROM SmartMsg__Message__c
            WHERE Id = :messageRecordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return messages.isEmpty() ? null : messages[0];
    }

    /**
     * @description Increments No_of_Outbound_Messages__c on the active Messaging Session for the recipient.
     * @param toPhone E.164 recipient phone number (with leading +).
     */
    private static void incrementOutboundMessageCountForRecipient(String toPhone) {
        try {
            if (String.isBlank(toPhone)) {
                return;
            }
            String normalizedTo = toPhone.startsWith('+') ? toPhone : '+' + toPhone;
            List<SmartMsg__Messaging_Session__c> sessions = [
                SELECT Id, SmartMsg__No_of_Outbound_Messages__c
                FROM SmartMsg__Messaging_Session__c
                WHERE SmartMsg__Session_status__c != 'Completed'
                AND SmartMsg__To_Number__c = :normalizedTo
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (sessions.isEmpty()) {
                return;
            }
            SmartMsg__Messaging_Session__c ms = sessions[0];
            Integer currentOutbound = ms.SmartMsg__No_of_Outbound_Messages__c == null
                ? 0
                : Integer.valueOf(ms.SmartMsg__No_of_Outbound_Messages__c);
            ms.SmartMsg__No_of_Outbound_Messages__c = currentOutbound + 1;
            update ms;
        } catch (Exception ignoreOutboundCount) {
            // Do not block message send if the counter update fails.
        }
    }
}