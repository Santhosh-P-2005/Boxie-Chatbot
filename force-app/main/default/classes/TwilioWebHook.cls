/**
 * @description REST service for handling Twilio webhooks.
 */
@RestResource(urlMapping='/twilioStatus/*')
global without sharing class TwilioWebHook {
    // Twilio Configuration
    // private static SmartMsg__TwilioConfiguration__c twilioCred = SmartMsg__TwilioConfiguration__c.getInstance();
    // private static final String ACCOUNT_SID = twilioCred.SmartMsg__Account_SID__c;
    // private static final String AUTH_TOKEN = twilioCred.SmartMsg__Auth_Token__c;

    private static SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = SmartMsg__Twilio_Whatsapp__c.getInstance();
    private static final String ACCOUNT_SID = twilioWhatsappSetting.SmartMsg__Account_SID__c;
    private static final String AUTH_TOKEN = twilioWhatsappSetting.SmartMsg__Auth_Token__c;
   @HttpPost
    /**
     * @description Handles the status callback for SMS messages.
     */
    global static void handleStatusCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        //res.addHeader('Content-Type','application/x-www-form-urlencoded');
        //res.addHeader('Content-Type','text/xml');
        Map<String, String> sms = req.params;
        
        string messageId;
        if (sms.containsKey('MessageSid')) {
            messageId = sms.get('MessageSid');
            // System.debug('messageId ---> '+messageId);
        }
        string messageStatus;
        if (sms.containsKey('MessageStatus')) {
            String raw = sms.get('MessageStatus');
            if (raw == 'queued') {
                messageStatus = 'Scheduled';
            } else if (raw == 'delivered') {
                messageStatus = 'Delivered';
            } else if (raw == 'sent' || raw == 'sending' || raw == 'accepted') {
                messageStatus = 'Sent';
            } else if (raw == 'failed' || raw == 'undelivered') {
                messageStatus = 'Failed';
            } else {
                messageStatus = raw != null ? raw.substring(0,1).toUpperCase() + raw.substring(1).toLowerCase() : raw;
            }
        }
        string errorMessage;
        if (sms.containsKey('ErrorMessage')) {
            errorMessage = sms.get('ErrorMessage');
        }
        if (String.isNotBlank(messageStatus) && String.isNotBlank(messageId)) {
            if (!Schema.sObjectType.SmartMsg__Message__c.isCreateable() && !Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to create this message.');
            }else{
                List<SmartMsg__Message__c> smsRecords = new List<SmartMsg__Message__c>();
                try{
                    smsRecords = [SELECT Id, SmartMsg__Delivery_Status__c, SmartMsg__Message_Id__c,SmartMsg__channel__c, SmartMsg__To_Number__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = :messageId LIMIT 1];
                    if(messageStatus == 'Scheduled'){
                        messageStatus = smsRecords[0].SmartMsg__Delivery_Status__c;
                     }
                    else if(smsRecords[0].SmartMsg__Delivery_Status__c == 'Scheduled' && messageStatus == 'Sent'){
                       messageStatus = 'Sent';
                    }
                    else if(smsRecords[0].SmartMsg__Delivery_Status__c == 'Sent' && messageStatus == 'Delivered'){
                        messageStatus = 'Delivered';
                    }
                }catch(Exception e){
                }
                if (!smsRecords.isEmpty()) {
                    SmartMsg__Message__c getSMS = smsRecords[0]; // Use the first record
                    SmartMsg__Message__c updateSMS = new SmartMsg__Message__c();
                    updateSMS.Id = getSMS.Id;
                    updateSMS.SmartMsg__Delivery_Status__c = messageStatus;
                    updateSMS.SmartMsg__Sent_Date_and_Time__c  = DateTime.now();
                    if (messageStatus == 'Failed') {
                        updateSMS.SmartMsg__Failed_Reason__c = errorMessage;
                    }
                    if (!CommonUtil.hasFLS(updateSMS)) {
                        throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                    }else{
                        // System.debug('updateSMS ---> '+updateSMS);
                        update updateSMS;
                    }
                    String fromPhNumber;
                    String smsBody;
                    if (sms.containsKey('To')) {
                        fromPhNumber = sms.get('To');
                    }
                    if (sms.containsKey('Body')) {
                        smsBody = sms.get('Body');
                    }
                    res.statusCode = 200;
                    SmartMsg__Incoming_Message__e event = new SmartMsg__Incoming_Message__e();
                    event.SmartMsg__Sent_date_and_Time__c = Datetime.now();
                    event.SmartMsg__Event_Type__c ='Outbound';
                    event.SmartMsg__From_Number__c = fromPhNumber;
                    event.SmartMsg__Record_Id__c = smsRecords[0].Id;
                    event.SmartMsg__Channel__c = smsRecords[0].SmartMsg__channel__c;
                    event.SmartMsg__Delivery_Status__c = messageStatus;
                    EventBus.publish(event);
                }
            }
        }
    }
    @HttpGet
    /**
     * @description Handles an incoming message via REST request.
     * @throws AuraHandledException if the user does not have permission to create a message or if a callout fails.
     */
    global static void handleIncomingMessage() {
        
        if(Constants.SUBSCRIPTION_END_DATE > String.valueOf(System.today())){
            RestRequest req = RestContext.request;
            Map<String, String> sms = req.params;
            //System.debug('SMS ---> '+sms);
            // Twilio status callback: same POST endpoint receives MessageStatus + MessageSid
            if (!sms.isEmpty() && sms.containsKey('MessageStatus')) {
                handleStatusCallback();
                return;
            }
            String fromPhNumber;
            String smsBody;
            string messageSid;
            String mediaUrl0;
            if(!sms.isEmpty()){
            if (sms.containsKey('From')) {
                fromPhNumber = sms.get('From');
            }
            if (sms.containsKey('Body')) {
                smsBody = sms.get('Body');
            }
            if (sms.containsKey('MessageSid')) {
                messageSid = sms.get('MessageSid');
            }
            // Extract Media URL
            if (sms.containsKey('MediaUrl0')) {
                mediaUrl0 = sms.get('MediaUrl0');
            }
            // RestResponse res = RestContext.response;
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
                messageRec.SmartMsg__To_Number__c = String.valueOf('+'+fromPhNumber).remove(' ');
                messageRec.SmartMsg__From_Number__c = String.valueOf('+1'+sms.get('To')).remove(' ');
                messageRec.SmartMsg__Message_Body__c = smsBody;
                messageRec.SmartMsg__Message_Id__c = MessageSid;
                messageRec.SmartMsg__Is_Outgoing__c = False;
                messageRec.SmartMsg__Type__c = 'Inbound';
                messageRec.SmartMsg__Channel__c = 'SMS';
                messageRec.SmartMsg__Delivery_Status__c = 'Received';
                messageRec.SmartMsg__Response__c = JSON.serialize(sms); // Store the entire response
            }
            Datetime currentDateTime = Datetime.now(); // UTC
            messageRec.SmartMsg__Sent_Date_and_Time__c = currentDateTime; // Store as UTC
            
            try {
                Insert messageRec;
                string recId =messageRec.Id;
                string toNum = messageRec.SmartMsg__To_Number__c;
                // Asynchronously process media if a media URL is present
                if (String.isNotBlank(mediaUrl0)) {
                    processIncomingMedia(messageRec.Id, mediaUrl0);
                }
                SmartMsg__Incoming_Message__e event = new SmartMsg__Incoming_Message__e();
                event.SmartMsg__Record_Id__c = recId;
                event.SmartMsg__From_Number__c = toNum;
                event.SmartMsg__Event_Type__c ='Inbound';
                event.SmartMsg__Channel__c = messageRec.SmartMsg__Channel__c;
                EventBus.publish(event);
            } catch (Exception e) {
                throw new AuraHandledException('CalloutException: ' +e.getMessage());
            }
        }
        }
        
    }
    
    /**
     * @description Normalizes a phone number by removing non-numeric characters and adjusting the length.
     *
     * @param phoneNumber The input phone number to be normalized.
     * @return The normalized phone number containing only the last 10 digits.
     */
    public static String normalizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return null;
        }
        
        // Remove all non-numeric characters
        String incomingNumber = phoneNumber.replaceAll('[^0-9]', '');
        
        // Handle specific lengths (11, 12, 13 digits)
        if (incomingNumber.length() == 11) {
            incomingNumber = incomingNumber.substring(1); // Remove leading country code (e.g., '1')
        } else if (incomingNumber.length() == 12) {
            incomingNumber = incomingNumber.substring(2); // Remove leading country code (e.g., '91')
        } else if (incomingNumber.length() == 13) {
            incomingNumber = incomingNumber.substring(3); // Remove longer prefixes
        }
        
        // Ensure only the last 10 digits are returned
        return incomingNumber.right(10);
    }
    
    
    
    
    /**
     * @description Processes incoming media for an SMS record.
     * This method is annotated with @future to allow asynchronous callouts.
     * @param smsId The ID of the SMS record.
     * @param mediaUrl The URL of the media to be processed.
     */
    @future(callout=true)
    public static void processIncomingMedia(String smsId, String mediaUrl) {
        SmartMsg__Message__c sms = [SELECT Id, SmartMsg__Media_Url__c FROM SmartMsg__Message__c WHERE Id = :smsId WITH SECURITY_ENFORCED];
        
        if (sms != null && String.isNotBlank(mediaUrl)) {
            try {
                // String accountSid = ACCOUNT_SID;
                // String authToken = AUTH_TOKEN;
                String authenticatedMediaUrl = getAuthenticatedMediaUrl(mediaUrl);
                if (String.isNotBlank(authenticatedMediaUrl)) {
                    // Download and store the media
                    ContentVersion cv = downloadAndStoreMedia(smsId, authenticatedMediaUrl);
                    if (cv != null) {
                        // Update the SMS record with the ContentDocumentId
                        sms.SmartMsg__Media_Url__c = cv.ContentDocumentId;  // Store the File Id
                        if (!CommonUtil.hasFLS(sms)) {
                            throw new AuraHandledException('You do not have the necessary field permissions to update Message records records.');
                        }else{
                            if (!Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                                throw new AuraHandledException('You do not have permission to create this message.');
                            }else{
                                update sms;
                            }
                        }
                    } else {
                        throw new AuraHandledException('Error: Could not download and store media for SMS record: ' + smsId);
                    }
                } else {
                    throw new AuraHandledException('Error: Could not retrieve authenticated media URL for SMS record: ' + smsId);
                }
                
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        } else {
            throw new AuraHandledException('Failed to process media');
        }
    }
    
    // Helper method to get the authenticated media URL
    // private static String getAuthenticatedMediaUrl(String mediaUrl, String accountSid, String authToken) {
        //     Http http = new Http();
        //     HttpRequest request = new HttpRequest();
        //     request.setEndpoint(mediaUrl);
        //     request.setMethod('GET');
        
        //     String authString = accountSid + ':' + authToken;
        //     Blob authBlob = Blob.valueOf(authString);
        //     String encodedAuth = EncodingUtil.base64Encode(authBlob);
        //     request.setHeader('Authorization', 'Basic ' + encodedAuth);
        
        //     try {
            //         HttpResponse response = http.send(request);
            
            //         if (response.getStatusCode() == 307) {
                //             return response.getHeader('Location'); // Redirect URL
            //         } else if (response.getStatusCode() == 200) {
                //             // If Twilio directly returns the image without redirect
                //             return mediaUrl;
            //         } else {
                //             //system.debug('Error fetching image: ' + response.getStatusCode() + ' ' + response.getStatus());
                //             return null;
            //         }
        //     } catch (Exception e) {
            //         //system.debug('Exception in getAuthenticatedMediaUrl: ' + e.getMessage());
            //         return null;
        //     }
    // }
    
    /**
     * @description Retrieves the authenticated media URL for a file sent via Twilio SMS.
     *              This method first attempts to use the Twilio Named Credential (Twilio_Auth)
     *              for secure authentication. If Twilio responds with a redirect (e.g., to a CDN),
     *              it falls back to manually setting the Authorization header.
     *
     * @param mediaUrl The full Twilio media URL (e.g., https://api.twilio.com/...). May be redirected to a CDN.
     * @return The final media URL to be used for downloading the file, or null if it cannot be resolved.
     */
    private static String getAuthenticatedMediaUrl(String mediaUrl) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        // Check if this URL is within Named Credential scope
        if (mediaUrl.startsWith('https://api.twilio.com')) {
            // Use Named Credential – remove base domain
            String relativePath = mediaUrl.removeStart('https://api.twilio.com');
            request.setEndpoint('callout:SmartMsg__Twilio_API' + relativePath);
        } else {
            // Use fallback if outside the Named Credential (like redirected CDN URL)
            request.setEndpoint(mediaUrl);
            String authString = ACCOUNT_SID + ':' + AUTH_TOKEN;
            String encodedAuth = EncodingUtil.base64Encode(Blob.valueOf(authString));
            request.setHeader('Authorization', 'Basic ' + encodedAuth);
        }
        
        request.setMethod('GET');
        
        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 307) {
                // Twilio redirect to CDN, e.g., media.twiliocdn.com
                return response.getHeader('Location');
            } else if (response.getStatusCode() == 200) {
                return mediaUrl;
            } else {
                return null;
            }
        } catch (Exception e) {
            return null;
        }
    }
    
    
    // Helper method to download and store the media as a File
    // private static ContentVersion downloadAndStoreMedia(String smsId, String mediaUrl, String accountSid, String authToken) {
        //     Http http = new Http();
        //     HttpRequest request = new HttpRequest();
        //     request.setEndpoint(mediaUrl);
        //     request.setMethod('GET');
        
        //     String authString = accountSid + ':' + authToken;
        //     Blob authBlob = Blob.valueOf(authString);
        //     String encodedAuth = EncodingUtil.base64Encode(authBlob);
        //     request.setHeader('Authorization', 'Basic ' + encodedAuth);
        
        //     try {
            //         HttpResponse response = http.send(request);
            
            //         if (response.getStatusCode() == 200) {
                //             String contentType = response.getHeader('Content-Type');
                //             Blob imageBlob = response.getBodyAsBlob();
                
                //             // Create ContentVersion (File)
                //             ContentVersion cv = new ContentVersion();
                //             cv.ContentLocation = 'S'; // 'S' for Salesforce, 'E' for External
                //             cv.PathOnClient = 'TwilioMedia' + DateTime.now().getTime() + '.' + contentType.substringAfter('/').trim(); // Give it a unique filename
                //             cv.Title = 'Twilio Media ' + DateTime.now();
                //             cv.VersionData = imageBlob;
                //             cv.FirstPublishLocationId = smsId;  // Link it to the SMS record
                //             if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                    //                 throw new AuraHandledException('You do not have permission to create this message.');
                //             }else{
                    //                 insert cv;
                //             }
                //             cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH SECURITY_ENFORCED];
                //             return cv;
            //         } else {
                //             return null;
            //         }
        //     } catch (Exception e) {
            //         return null;
        //     }
    // }
    
    /**
     * @description Downloads a media file from a Twilio URL and stores it in Salesforce as a ContentVersion record.
     *              If the media URL is under api.twilio.com, the request is authenticated via a Named Credential.
     *              If the media URL is a redirected CDN URL, it falls back to manual Basic Authentication.
     *
     * @param smsId The ID of the SmartMsg__Message__c record this media will be attached to.
     * @param mediaUrl The Twilio or CDN URL from which the media will be downloaded.
     * @return The created ContentVersion record that contains the downloaded media file, or null if download fails.
     */
    private static ContentVersion downloadAndStoreMedia(String smsId, String mediaUrl) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        if (mediaUrl.startsWith('https://api.twilio.com')) {
            String relativePath = mediaUrl.removeStart('https://api.twilio.com');
            request.setEndpoint('callout:SmartMsg__Twilio_API' + relativePath);
        } else {
            request.setEndpoint(mediaUrl);
            String authString = ACCOUNT_SID + ':' + AUTH_TOKEN;
            String encodedAuth = EncodingUtil.base64Encode(Blob.valueOf(authString));
            request.setHeader('Authorization', 'Basic ' + encodedAuth);
        }
        
        request.setMethod('GET');
        
        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                String contentType = response.getHeader('Content-Type');
                Blob imageBlob = response.getBodyAsBlob();
                
                ContentVersion cv = new ContentVersion();
                cv.ContentLocation = 'S';
                cv.PathOnClient = 'TwilioMedia_' + DateTime.now().getTime() + '.' + contentType.substringAfter('/').trim();
                cv.Title = 'Twilio Media ' + DateTime.now();
                cv.VersionData = imageBlob;
                cv.FirstPublishLocationId = smsId;
                
                if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                    throw new AuraHandledException('You do not have permission to create this file.');
                }
                insert cv;
                
                cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH SECURITY_ENFORCED];
                return cv;
            } else {
                return null;
            }
        } catch (Exception e) {
            return null;
        }
    }
    
}