/**
 *  @description A class for interacting with Twilio services to send and schedule SMS messages from Salesforce.
 * This class includes methods to send SMS immediately or schedule them for a future time.
 */
public with sharing class TwilioServices {
            private static SmartMsg__TwilioConfiguration__c twilioCred = SmartMsg__TwilioConfiguration__c.getInstance();
        
        // Twilio Configuration
        private static final String ACCOUNT_SID = TwilioCred.SmartMsg__Account_SID__c;
        private static final String AUTH_TOKEN = TwilioCred.SmartMsg__Auth_Token__c;
        private static final String FROM_PHONE = TwilioCred.SmartMsg__Twilio_Phone_Number__c;
        private static final String SERVICE_SID = TwilioCred.SmartMsg__Service_Id__c;
        private static final String ENVIRONMENT_ID = TwilioCred.SmartMsg__Environment_Id__c;
        private static final String STATUS_CALLBACK_URL = TwilioCred.SmartMsg__StatusCallbackUrl__c;
        private static final String MEDIA_BASE_URL = TwilioCred.SmartMsg__MediaBaseUrl__c;
/**
     * @description send the SMS to the given number
     * @param recordId
     * @param phoneNo
     * @param smsBody
	 * @return Id
     */
@AuraEnabled
public static Id sendSMS(String recordId, String phoneNo, String smsBody){
    smsBody = String.escapeSingleQuotes(smsBody);
    smsBody = smsBody.replace('\\\\', '\\');
    smsBody = smsBody.contains('{') ? WhatsAppServices.replacePlaceholders(recordId, smsBody) : smsBody;
    SmartMsg__TwilioConfiguration__c smsCreds = ProviderSettingUtil.getSMSProviderSettings('SMS');
    String accountSid = smsCreds.SmartMsg__Account_SID__c; 
    String endPoint = 'callout:SmartMsg__Twilio_API/2010-04-01/Accounts/' + accountSid + '/Messages.json';
    
    HttpRequest req = new HttpRequest();
    Http http = new Http();
    HTTPResponse res = new HTTPResponse();
    req.setEndpoint(endPoint);
    req.setMethod('POST');
    
    String version = '3.2.0';
    req.setHeader('X-Twilio-Client', 'salesforce-' + version);
    req.setHeader('User-Agent', 'twilio-salesforce/' + version);
    req.setHeader('Accept', 'application/json');
    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setHeader('Accept-Charset', 'utf-8');
    req.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    req.setHeader('Pragma', 'no-cache');
    req.setHeader('Expires', '0');
    req.setHeader('X-Content-Type-Options', 'nosniff');
    
    SmartMsg__TwilioConfiguration__c twilioConfig = SmartMsg__TwilioConfiguration__c.getInstance();
    String messageBody = 'To=' + EncodingUtil.urlEncode(phoneNo, 'UTF-8') +
                         '&From=' + EncodingUtil.urlEncode(smsCreds.SmartMsg__Twilio_Phone_Number__c, 'UTF-8') +
                         '&Body=' + EncodingUtil.urlEncode(smsBody, 'UTF-8');
    if (String.isNotBlank(twilioConfig.SmartMsg__StatusCallbackUrl__c)) {
        messageBody += '&StatusCallback=' + EncodingUtil.urlEncode(twilioConfig.SmartMsg__StatusCallbackUrl__c, 'UTF-8');
    }
    req.setBody(messageBody);
    
    res = http.send(req);
    if (res.getStatusCode() == 201) {
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String messageSid = (String) jsonResponse.get('sid');
        String phoneNumber = (String) jsonResponse.get('to');
        String status = (String) jsonResponse.get('status');
        
        List<SmartMsg__Message__c> recordsToUpdate = [
            SELECT Id, Name, SmartMsg__To_Number__c, SmartMsg__Message_ID__c, 
                   SmartMsg__Message_Body__c, SmartMsg__Type__c, SmartMsg__Outgoing__c, 
                   SmartMsg__Delivery_Status__c, SmartMsg__Scheduled_Date_Time__c 
            FROM SmartMsg__Message__c  
            WHERE SmartMsg__Delivery_Status__c = 'Sent' 
            WITH SECURITY_ENFORCED 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        List<SmartMsg__Message__c> smsList = new List<SmartMsg__Message__c>();
        
        for (SmartMsg__Message__c sms : recordsToUpdate) {
            String phone =  '+'+sms.SmartMsg__To_Number__c;
            if (phoneNumber == phone && status == 'queued') {
                if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() || !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                    throw new CalloutException('You do not have permission to create this message.');
                }  
                
                SmartMsg__Message__c messageRec = new SmartMsg__Message__c();
                messageRec.SmartMsg__Message_ID__c = messageSid;
                messageRec.SmartMsg__Delivery_Status__c = 'Sent';
                messageRec.Id = sms.Id;
                messageRec.SmartMsg__To_Number__c = phoneNumber;
                messageRec.SmartMsg__Message_Body__c = smsBody;
                messageRec.SmartMsg__Outgoing__c = true;
                messageRec.SmartMsg__Type__c = 'Outbound';
                
                if (!CommonUtil.hasFLS(messageRec)) {
                    throw new CalloutException('You do not have the necessary field permissions to create Message_Template__c records.');
                }
                
                smsList.add(messageRec);
                
            }
        }
        
        if (!smsList.isEmpty()) {
            if (!CommonUtil.hasFLS(smsList[0])) {
                throw new CalloutException('You do not have the necessary field permissions to create Message_Template__c records.');
            }
            update smsList;
            return smsList[0].Id;
        } else {
            // Handle the case where no message records are updated
            return null;  // or handle accordingly
        }
    } else {
        errorWrapper er = (errorWrapper) JSON.deserialize(res.getBody(), errorWrapper.class);
        if (!Test.isRunningTest()) {
            throw new CalloutException('Error : ' + er.message + ' Code: ' + er.code);
        }
        return null;
    }
}

    /**
     * @description Schedules an SMS message to be sent at a specified future time.
     * @param recordId The Id of the message record
     * @param phoneNo The phone number to which the SMS will be sent.
     * @param smsBody The body of the SMS message.
     * @param scheduledTime The time at which the SMS should be sent, in the format required by Twilio.
     * @return The ID of the created scheduled message record.
     * @throws AuraHandledException If there are issues with permissions or if an error occurs during the HTTP request.
     */
    @AuraEnabled
    public static Id scheduleSMS(String recordId, String phoneNo, String smsBody, String scheduledTime) {
        SmartMsg__Message__c scheduledMessage = new SmartMsg__Message__c();
        List<SmartMsg__Message__c> scheduleRecordUpdate = [SELECT Id, Name,SmartMsg__To_Number__c,SmartMsg__Message_ID__c, SmartMsg__Message_Body__c, SmartMsg__Type__c, SmartMsg__Outgoing__c, CreatedDate, SmartMsg__Delivery_Status__c,SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE SmartMsg__Delivery_Status__c = 'Scheduled' With SECURITY_ENFORCED Order By CreatedDate DESC LIMIT 1] ;
        List<SmartMsg__Message__c> smsScheduleList = new List<SmartMsg__Message__c>();
        smsBody = String.escapeSingleQuotes(smsBody).replace('\n', '\\n');
        smsBody = smsBody.contains('{')?WhatsAppServices.replacePlaceholders(recordId,smsBody):smsBody;
        SmartMsg__TwilioConfiguration__c smsCreds = ProviderSettingUtil.getSMSProviderSettings('SMS');
        String accountSid = smsCreds.SmartMsg__Account_SID__c;
        String endPoint = 'callout:SmartMsg__Twilio_API/2010-04-01/Accounts/' + accountSid + '/Messages.json';
        String messagingServiceSid = smsCreds.SmartMsg__Messaging_Service_SID__c;
        String requestBody = 'To=' + EncodingUtil.urlEncode(phoneNo, 'UTF-8') +'&MessagingServiceSid=' + messagingServiceSid +'&Body=' + EncodingUtil.urlEncode(smsBody, 'UTF-8') +'&ScheduleType=fixed' +'&SendAt=' + scheduledTime+'&StatusCallback=' + EncodingUtil.urlEncode(STATUS_CALLBACK_URL, 'UTF-8');
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endPoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
		req.setHeader('Pragma', 'no-cache');
		req.setHeader('Expires', '0');
		req.setHeader('X-Content-Type-Options', 'nosniff');
        req.setBody(requestBody);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String messageSid = (String) jsonResponse.get('sid');
            String phoneNumber = (String) jsonResponse.get('to');
            String status = (String) jsonResponse.get('status');
            for(SmartMsg__Message__c sms: scheduleRecordUpdate ){
                string phone = sms.SmartMsg__To_Number__c;
                If(phoneNumber == phone && status == 'Scheduled'){
                    if (!Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                		throw new AuraHandledException('You do not have permission to create this message.');
            		} 
                    scheduledMessage.SmartMsg__Message_ID__c = messageSid;
                    scheduledMessage.SmartMsg__Delivery_Status__c = 'Scheduled';
                    scheduledMessage.Id = sms.Id;
                    scheduledMessage.SmartMsg__To_Number__c = phoneNumber;
                    scheduledMessage.SmartMsg__Message_Body__c = smsBody;
                    scheduledMessage.SmartMsg__Outgoing__c = True;
                    scheduledMessage.SmartMsg__Type__c = 'Outbound';
                    if (!CommonUtil.hasFLS(scheduledMessage)) {
        			throw new AuraHandledException('You do not have the necessary field permissions to create Message_Template__c records.');
    				}
                    smsScheduleList.add(scheduledMessage); 
                }
    
            }
        } else if(res.getStatusCode() != 200 || res.getStatusCode() != 201) {
            Object error = (Object) JSON.deserializeUntyped(res.getBody());
            scheduledMessage.Id = scheduleRecordUpdate[0].Id;
            scheduledMessage.SmartMsg__ErrorMessage__c = String.valueOf(((Map<String, Object>) error).get('message'));
            scheduledMessage.SmartMsg__Failed_Reason__c = String.valueOf(((Map<String, Object>) error).get('message'));
            scheduledMessage.SmartMsg__Delivery_Status__c = 'Failed';
            smsScheduleList.add(scheduledMessage);
            // System.debug('Error : ' + ((Map<String, Object>) error).get('message'));
            //throw new CustomException('Error : ' + ((Map<String, Object>) error).get('message'));
        }

        if (smsScheduleList.size() > 0) {
            update smsScheduleList;
            return smsScheduleList[0].Id;
        }
        
        return null;
    }
    /**
     * @description Custom exception for template creation errors.
     */
    public class CustomException extends Exception {}

    /**
     * @description A wrapper class for handling errors returned by the Twilio API.
     */
    public class ErrorWrapper{
        String code;
        String message;
        String moreInfo;
        String status; 
    }
    /**
     * @description Creates a new AuraHandledException with the specified message.
     * @param message The message for the exception.
     * @return The newly created AuraHandledException.
     */
    private static AuraHandledException newMessageException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}