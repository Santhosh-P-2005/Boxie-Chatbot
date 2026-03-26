/**
     * @class TwilioSMSQueueable
     * @description Queueable Apex class for sending SMS/MMS messages via Twilio, supporting batching, media uploads, and error handling.
     * Implements Database.AllowsCallouts for HTTP requests to Twilio.
     */
    public class TwilioSMSQueueable implements Queueable, Finalizer,Database.AllowsCallouts {
        private List<SmartMsg__Message__c> smsRecords;
        private Integer batchSize = 50;
        // @testVisible
        //private static Boolean doChainJob = true;
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
         * @description triggered records
         * @param records List of SmartMsg__Message__c records to process.
         */
        public TwilioSMSQueueable(List<SmartMsg__Message__c> records) {
            this.smsRecords = records;
        }
        /**
         * @description Entry point for the Queueable job. Processes messages in batches and sends SMS/MMS via Twilio.
         * @param context QueueableContext provided by Salesforce.
         */
        public void execute(QueueableContext context) {
            List<SmartMsg__Message__c> currentBatch = new List<SmartMsg__Message__c>();
            for(Integer i = 0; i < smsRecords.size(); i++) {
                if(i < batchSize) {
                    currentBatch.add(smsRecords[i]);
                }
                smsRecords.remove(smsRecords.indexOf(smsRecords[i]));
                break;
            }
            // Process current batch
            for(SmartMsg__Message__c sms : currentBatch) {
                try {
                    if(sms.SmartMsg__Media_File__c) {
                        processMediaSMS(sms);
                    } else {
                        sendSMSHelper(sms.SmartMsg__To_Number__c, sms.SmartMsg__Message_Body__c, new List<String>(), sms.Id);
                    }
                } catch(Exception e) {
                    updateRecordsInCatch(sms.Id, e.getMessage());
                }
            }
            //SubscriptionExpiryNotificationService.sendSubscriptionExpiryWarningIfNeeded();
            System.attachFinalizer(this);
        }
        /**
         * @description Executes the finalizer logic based on the result of the parent job.
         * @param ctx The FinalizerContext containing the result of the parent job.
         */
        public void execute(FinalizerContext ctx) {
            if (ctx.getResult() == ParentJobResult.SUCCESS) {
                Integer i = 0;
                i++;
            }
        }
        /**
         * @description Handles sending of MMS (media) messages by uploading media to Twilio and sending the message.
         * @param sms The SmartMsg__Message__c record containing media info.
         */
        public void processMediaSMS(SmartMsg__Message__c sms) {
            
            String assetId = createAsset('Asset-' + System.now() + '-' + sms.SmartMsg__File_Name__c, sms.Id);
            
            if (String.isNotBlank(assetId)) {
                Blob fileBlob;
                
                // Extract ContentDocumentId from Media_Url__c
                if (String.isNotBlank(sms.SmartMsg__Media_Url__c)) {
                    String contentDocumentId = sms.SmartMsg__Media_Url__c;  // Assuming it holds the ContentDocumentId
                    
                    try {
                        // Query the latest ContentVersion for the given ContentDocumentId
                        ContentVersion contentVersion = [
                        SELECT VersionData 
                        FROM ContentVersion 
                        WHERE ContentDocumentId = :contentDocumentId WITH SECURITY_ENFORCED
                        ORDER BY CreatedDate DESC 
                        LIMIT 1
                    ];
                        
                        if (contentVersion != null) {
                            fileBlob = contentVersion.VersionData;  // Get the Blob data
                        } else {
                            return;  // Exit if no file found
                        }
                    } catch (Exception e) {
                        return;
                    }
                } else {
                    return;
                }
                
                // Upload the blob data to Twilio
                List<String> assetVersionResponse = uploadBlobToTwilioAsset(fileBlob,sms.SmartMsg__File_Name__c,'application/octet-stream',assetId,sms.Id);
                if (!assetVersionResponse.isEmpty()) {
                    createBuildId(new List<String>{assetVersionResponse[1]}, new List<String>{assetVersionResponse[0]}, sms.SmartMsg__To_Number__c,sms.SmartMsg__Message_Body__c,sms.Id);
                }
            }
        }
        
        /**
         * @description Creates a new Asset in Twilio Serverless for media upload.
         * @param friendlyName The friendly name for the asset.
         * @param recordId The related message record Id for error handling.
         * @return The Asset SID if successful, null otherwise.
         */
        public static String createAsset(String friendlyName, Id recordId) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:SmartMsg__Twilio_Serverless/v1/Services/' + SERVICE_SID + '/Assets');
                req.setMethod('POST');
                // req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(ACCOUNT_SID + ':' + AUTH_TOKEN)));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                
                String bodyEncoded = 'FriendlyName=' + EncodingUtil.urlEncode(friendlyName, 'UTF-8');
                req.setBody(bodyEncoded);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                    return (String)responseMap.get('sid');
                }
                return null;
            } catch(Exception e) {
                updateRecordsInCatch(recordId, e.getMessage());
                throw new CalloutException('Failed to create asset: ' + e.getMessage());
            }
        }
        
        /**
         * @description Uploads a Blob file as a new Asset Version to Twilio Serverless.
         * @param fileBlob The file Blob to upload.
         * @param fileName The name of the file.
         * @param fileType The MIME type of the file.
         * @param assetId The Twilio Asset SID.
         * @param recordId The related message record Id for error handling.
         * @return List containing [path, sid] of the uploaded asset version.
         */
        public static List<String> uploadBlobToTwilioAsset(Blob fileBlob, String fileName, String fileType, String assetId, Id recordId) {
            if (fileName.contains('(') || fileName.contains(')')) {
                fileName = fileName.replaceAll('\\(|\\)', '').replace(' ', '');
            }
            
            try {
                HttpRequest req = new HttpRequest();
                //req.setEndpoint('https://serverless-upload.twilio.com/v1/Services/' + SERVICE_SID + '/Assets/' + assetId + '/Versions');
                req.setEndpoint('callout:SmartMsg__Twilio_Serverless_Upload/v1/Services/' + SERVICE_SID + '/Assets/' + assetId + '/Versions');
                req.setMethod('POST');
                //req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(ACCOUNT_SID + ':' + AUTH_TOKEN)));
                req.setHeader('Content-Type', 'multipart/form-data; boundary=boundary');
                
                String boundary = 'boundary';
                String startBody = '--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="Content"; filename="'+ assetId + fileName +'"\r\n' +
                    'Content-Type: ' + fileType + '\r\n\r\n';
                
                String endBody = '\r\n--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="Path"\r\n\r\n' +
                    //'/'+ assetId + fileName + '\r\n' +
                    '/prakash'+'\r\n'+
                    '--' + boundary + '\r\n' +
                    'Content-Disposition: form-data; name="Visibility"\r\n\r\n' +
                    'public\r\n' +
                    '--' + boundary + '--';
                String combinedDataAsHex = EncodingUtil.convertToHex(Blob.valueOf(startBody)) +
                    EncodingUtil.convertToHex(fileBlob) +
                    EncodingUtil.convertToHex(Blob.valueOf(endBody));
                
                req.setBodyAsBlob(EncodingUtil.convertFromHex(combinedDataAsHex));
                Http http = new Http();
                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                    return new List<String>{
                        (String)responseMap.get('path'),
                        (String)responseMap.get('sid')
                    };
                }
                return new List<String>();
            } catch(Exception e) {
                updateRecordsInCatch(recordId, e.getMessage());
                throw new CalloutException('Failed to upload asset: ' + e.getMessage());
            }
        }
        
        /**
         * @description Creates a Build in Twilio Serverless for the uploaded asset and deploys it, then sends the SMS with media.
         * @param assetVersionIds List of Asset Version SIDs.
         * @param responsePaths List of asset paths.
         * @param phoneNumber Recipient phone number.
         * @param smsBody SMS message body.
         * @param recordId The related message record Id for error handling.
         * @return 'messagesent' if successful, 'build failed' otherwise.
         */
        public static String createBuildId(List<String> assetVersionIds, List<String> responsePaths, String phoneNumber, String smsBody, Id recordId) {
            try{
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:SmartMsg__Twilio_Serverless/v1/Services/'+SERVICE_SID+'/Builds');
                req.setMethod('POST');
                //req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(ACCOUNT_SID + ':' + AUTH_TOKEN)));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                String bodyEncoded = '';
                for (String assetVersionId : assetVersionIds) {
                    String encodedId = EncodingUtil.urlEncode(assetVersionId, 'UTF-8');
                    bodyEncoded += 'AssetVersions=' + encodedId + '&';
                }
                if (bodyEncoded.endsWith('&')) {
                    bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 1);
                }
                req.setBody(bodyEncoded);
                Http http = new Http();
                HttpResponse res = http.send(req);
                if (!Test.isRunningTest()) {
                    DateTime start = DateTime.now();
                    while(System.Now()< start.addseconds(25)){
                        continue;
                    }
                }
                if (res.getStatusCode() == 201 || res.getStatusCode() == 200 ) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    string buildId = (String) responseMap.get('sid');
                    //string buildStatus = (String) responseMap.get('status');
                    string currentBuildStatus ='';
                    deployChangesInEnvironment(buildId, recordId);
                    List<String> mediaUrlList = new List<String>();
                    // string baseURL = 'https://demoservice-8227.twil.io';                //twiliofunctionservice-6973.twil.io';//sendstatus-3449.twil.io';//demoservice-2424.twil.io
                    String baseURL = TwilioCred.SmartMsg__MediaBaseUrl__c;
                    for (String path : responsePaths ) {
                        if(path !='' && path !=null){
                            String fullURL = baseURL + path;
                            mediaUrlList.add(fullURL);
                        }
                    }
                    currentBuildStatus =  getCreatedBuildDetails(buildId);//just only to check the status is changes or not!
                    if(currentBuildStatus == 'completed'){
                        string  sendSMSWithMedia = sendSMSHelper(  phoneNumber ,  smsBody,   mediaUrlList ,   recordId );
                        //return 'messagesent';
                        return sendSMSWithMedia;
                    }
                }
            }catch(Exception e){
                updateRecordsInCatch(  recordId,  e.getmessage());
                throw new CalloutException('Failed to process  of creating BuildId: '  + ' - ' + e.getmessage());
            }
            return 'build failed';
            
        }
        
        /**
         * @description Deploys a Build to a Twilio Serverless Environment.
         * @param liveBuildDetails The Build SID.
         * @param recordId The related message record Id for error handling.
         */
        public static void deployChangesInEnvironment(string liveBuildDetails, String recordId){
            try{
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:SmartMsg__Twilio_Serverless/v1/Services/'+SERVICE_SID+'/Environments/'+ENVIRONMENT_ID+'/Deployments');
                req.setMethod('POST');
                //req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(ACCOUNT_SID + ':' + AUTH_TOKEN)));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                String bodyEncoded = 'BuildSid=' + EncodingUtil.urlEncode(liveBuildDetails, 'UTF-8');
                req.setBody(bodyEncoded);
                Http http = new Http();
                http.send(req);
                // HttpResponse res = http.send(req);
                //Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                // for (String key : responseMap.keySet()) {
                    //     Object value = responseMap.get(key);
                // }
                // if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                    //string deployId = (String) responseMap.get('sid');
                    //return  deployId;
                // }
            }catch(Exception e){
                throw new CalloutException('Failed to process  of deployment: '  + ' - ' + e.getmessage());
            }
            //return 'not deployed';
            
        }
        
        /**
         * @description Gets the status of a created Build in Twilio Serverless.
         * @param buildId The Build SID.
         * @return The build status string.
         */
        public static string getCreatedBuildDetails( string buildId ){
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:SmartMsg__Twilio_Serverless/v1/Services/'+SERVICE_SID+'/Builds/' +buildId);
            req.setMethod('GET');
            //req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(ACCOUNT_SID + ':' + AUTH_TOKEN)));
            Http http = new Http();
            HttpResponse res = http.send(req);
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
           if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                string buildStatus = (String) responseMap.get('status');
                return  buildStatus;
            } else {
                
                throw new CalloutException('Failed to deploy: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        }
        
        /**
         * @description Sends an SMS (or MMS) message via Twilio API.
         * @param phoneNumber Recipient phone number.
         * @param smsBody SMS message body.
         * @param mediaUrlList List of media URLs (empty for SMS).
         * @param recordId The related message record Id for error handling.
         * @return Status string indicating result.
         */
        public static String sendSMSHelper(String phoneNumber, String smsBody, List<String> mediaUrlList, String recordId) {
            String statusCallbackUrl = TwilioCred.SmartMsg__StatusCallbackUrl__c;
            try {
                // Retrieve SMS credentials
                SmartMsg__TwilioConfiguration__c smsCreds = ProviderSettingUtil.getSMSProviderSettings('SMS');
                String accountSid = smsCreds.SmartMsg__Account_SID__c;
                // Construct endpoint with Named Credential
                String endpoint = 'callout:SmartMsg__Twilio_API/2010-04-01/Accounts/' + accountSid + '/Messages.json';
                // Construct HTTP Request
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('POST');
                // Standard Twilio headers
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
                
                // Use your constructSMSBody method here
                String messageBody = constructSMSBody(phoneNumber, smsBody, statusCallbackUrl, mediaUrlList);
                req.setBody(messageBody);
                
                // Execute request
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                // Handle the response
                handleSMSResponse(res, recordId, mediaUrlList != null && !mediaUrlList.isEmpty() ? mediaUrlList[0] : '');
                return (res.getStatusCode() == 201) ? 'SMS Sent Successfully' : 'SMS Failed with status: ' + res.getStatusCode();
                
            } catch(Exception e) {
                updateRecordsInCatch(recordId, e.getMessage());
                return 'Failed';
            }
        }
        
        /**
         * @description Updates the message record with error details and publishes a platform event.
         * @param recordId The message record Id.
         * @param errorMessage The error message to log.
         */
        public static void updateRecordsInCatch(String recordId, String errorMessage) {
            String limitedString = errorMessage.length() > 255 ? errorMessage.substring(0, 255) : errorMessage;
            update new SmartMsg__Message__c(
                Id = recordId,
            SmartMsg__Delivery_Status__c = 'Failed',
            SmartMsg__Failed_Reason__c = limitedString
                );
            // Publish platform event for real-time UI update
            SmartMsg__Incoming_Message__e statusEvent = new SmartMsg__Incoming_Message__e(
                
                SmartMsg__Channel__c = 'SMS',
            SmartMsg__Event_Type__c = 'Outbound',
            SmartMsg__Record_Id__c = recordId
                );
            EventBus.publish(statusEvent);
        }
        
        //  public void publishSuccessEvent(SMS__c sms) {
            
            //     // Publish platform event for real-time UI update
            //    Inbound_Sms_Event__e statusEvent = new Inbound_Sms_Event__e(
            // Event_Type__c = 'Outbound',
            // Record_Id__c = sms.Id,
            // SMS_Status__c = sms.Delivery_Status__c,
            // From_Phone_Number__c = sms.To_Number__c  // Using To_Number__c since it's outbound
            // );
            // EventBus.publish(statusEvent);
        // }
        
        /**
         * @description Constructs a list of full media URLs from asset paths.
         * @param responsePaths List of asset paths.
         * @return List of full media URLs.
         */
        public static List<String> constructMediaUrls(List<String> responsePaths) {
            List<String> mediaUrlList = new List<String>();
            String baseURL = 'https://demoservice-8227.twil.io';
            
            for(String path : responsePaths) {
                if(String.isNotBlank(path)) {
                    mediaUrlList.add(baseURL + path);
                }
            }
            return mediaUrlList;
        }
        /**
         * @description Constructs the HTTP body for a Twilio SMS/MMS API request.
         * @param phoneNumber Recipient phone number.
         * @param smsBody SMS message body.
         * @param statusCallbackUrl Twilio status callback URL.
         * @param mediaUrlList List of media URLs (empty for SMS).
         * @return URL-encoded request body string.
         */
        public static String constructSMSBody(String phoneNumber, String smsBody, String statusCallbackUrl, List<String> mediaUrlList) {
            
            // Add null check for mediaUrlList
            if (mediaUrlList == null) {
                mediaUrlList = new List<String>();
            }
            
            smsBody = smsBody.replace('&#39;', '\'')  // Apostrophe
                .replace('&quot;', '"')         // Double quote
                .replace('&amp;', '&')          // Ampersand
                .replace('&lt;', '<')           // Less than
                .replace('&gt;', '>')           // Greater than
                .replace('&ndash;', '–')        // En dash
                .replace('&mdash;', '—')        // Em dash
                .replace('&nbsp;', ' ');        // Non-breaking space
            
            
            String bodyEncoded = 'To=' + EncodingUtil.urlEncode(phoneNumber, 'UTF-8') +
                '&From=' + EncodingUtil.urlEncode(FROM_PHONE, 'UTF-8') +
                '&Body=' + EncodingUtil.urlEncode(smsBody, 'UTF-8') +
                '&StatusCallback=' + EncodingUtil.urlEncode(statusCallbackUrl, 'UTF-8');
            
            if(!mediaUrlList.isEmpty()) {
                for(String url : mediaUrlList) {
                    bodyEncoded += '&MediaUrl=' + EncodingUtil.urlEncode(url, 'UTF-8');
                }
            }
            return bodyEncoded;
        }
        /**
         * @description Handles the HTTP response from Twilio after sending an SMS/MMS, updates the record, and publishes a platform event.
         * @param res The HTTP response from Twilio.
         * @param recordId The message record Id.
         * @param mediaUrl The media URL (if any).
         */
        public static  void handleSMSResponse(HttpResponse res, String recordId, String mediaUrl) {
            
            Map<String, Object> jsonResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            SmartMsg__Message__c smsToUpdate = new SmartMsg__Message__c(Id = recordId);
            
            if(res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                
                smsToUpdate.SmartMsg__Message_Id__c = (String)jsonResponse.get('sid');
                smsToUpdate.SmartMsg__Failed_Reason__c = null;
                //smsToUpdate.Media_Url__c = mediaUrl;
                smsToUpdate.SmartMsg__Delivery_Status__c = 'Delivered';
                SmartMsg__Incoming_Message__e statusEvent = new SmartMsg__Incoming_Message__e(
                    SmartMsg__Event_Type__c = 'Outbound',
                SmartMsg__Record_Id__c = recordId,
                SmartMsg__Delivery_Status__c = smsToUpdate.Delivery_Status__c,
                SmartMsg__Channel__c = 'SMS',
                SmartMsg__From_Number__c = (String)jsonResponse.get('to')  // Using To_Number__c since it's outbound
                    );
                EventBus.publish(statusEvent);
            } else {
                ErrorResponseWrapper erw = (ErrorResponseWrapper)JSON.deserialize(res.getBody(), ErrorResponseWrapper.class);
                smsToUpdate.SmartMsg__Delivery_Status__c = 'Failed';
                smsToUpdate.SmartMsg__Message_Id__c = null;
                smsToUpdate.SmartMsg__Failed_Reason__c = erw.message;
                smsToUpdate.SmartMsg__Error_Code__c = erw.code;
                //smsToUpdate.Media_Url__c = mediaUrl;
                SmartMsg__Incoming_Message__e statusEvent = new SmartMsg__Incoming_Message__e(
                    SmartMsg__Channel__c = 'SMS',
                SmartMsg__Event_Type__c = 'Outbound',
                SmartMsg__Record_Id__c = recordId,
                SmartMsg__Delivery_Status__c = smsToUpdate.SmartMsg__Delivery_Status__c,
                SmartMsg__From_Number__c = (String)jsonResponse.get('to')  // Using To_Number__c since it's outbound
                    );
                EventBus.publish(statusEvent);
            }
            try{
                update smsToUpdate;
            } catch (DmlException e) {
                throw new AuraHandledException('Error updating message: ' + e.getMessage());
            }
            //update smsToUpdate
            
        }
        /**
         * @description Replaces merge field placeholders in a message template with values from a related record.
         * @param templateId The template record Id.
         * @param relatedRecordId The related record Id.
         * @param messageText The message text with placeholders.
         * @return The message text with placeholders replaced.
         */
        public static String replacePlaceholders(Id templateId, Id relatedRecordId, String messageText) {
            if (templateId == null || relatedRecordId == null || String.isBlank(messageText)) {
                return messageText;
            }
            
            SmartMsg__Message_Template__c template = [SELECT SmartMsg__Object_Name__c FROM SmartMsg__Message_Template__c WHERE Id = :templateId LIMIT 1];
            String objectName = template.SmartMsg__Object_Name__c;
            
            Pattern pattern = Pattern.compile('\\{!(\\w+)\\}');
            Matcher matcher = pattern.matcher(messageText);
            Set<String> fieldNames = new Set<String>();
            
            while (matcher.find()) {
                fieldNames.add(matcher.group(1));
            }
            
            if (!fieldNames.isEmpty()) {
                // Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                //     .get(objectName).getDescribe().fields.getMap();
                
                String query = 'SELECT ' + String.join(new List<String>(fieldNames), ',') +
                    ' FROM ' + objectName +
                    ' WHERE Id = :relatedRecordId WITH SECURITY_ENFORCED LIMIT 1';
                
                SObject relatedRecord = Database.query(query);
                
                if (relatedRecord != null) {
                    for (String fieldName : fieldNames) {
                    String placeholder = '{!' + fieldName + '}';
                    String fieldValue = String.valueOf(relatedRecord.get(fieldName));
                    messageText = messageText.replace(placeholder, fieldValue != null ? fieldValue : '');
                }
            }
        }
        return messageText;
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
        smsBody = String.escapeSingleQuotes(smsBody).replace('\n', '\\n');
        smsBody = smsBody.contains('{')?WhatsAppServices.replacePlaceholders(recordId,smsBody):smsBody;
        SmartMsg__TwilioConfiguration__c smsCreds = ProviderSettingUtil.getSMSProviderSettings('SMS');
        String accountSid = smsCreds.SmartMsg__Account_SID__c;
        String endPoint = 'callout:SmartMsg__Twilio_API/2010-04-01/Accounts/' + accountSid + '/Messages.json';
        String messagingServiceSid = smsCreds.SmartMsg__Messaging_Service_SID__c;
        String requestBody = 'To=' + EncodingUtil.urlEncode(phoneNo, 'UTF-8') +'&MessagingServiceSid=' + messagingServiceSid +'&Body=' + EncodingUtil.urlEncode(smsBody, 'UTF-8') +'&ScheduleType=fixed' +'&SendAt=' + scheduledTime;
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
        
        if (res.getStatusCode() == 201) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String messageSid = (String) jsonResponse.get('sid');
            String phoneNumber = (String) jsonResponse.get('to');
            String status = (String) jsonResponse.get('status');
            List<SmartMsg__Message__c> scheduleRecordUpdate = [SELECT Id, Name,SmartMsg__To_Number__c,SmartMsg__Message_ID__c, SmartMsg__Message_Body__c, SmartMsg__Type__c, SmartMsg__Outgoing__c, CreatedDate, SmartMsg__Delivery_Status__c,SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE SmartMsg__Delivery_Status__c = 'Scheduled' With SECURITY_ENFORCED Order By CreatedDate DESC LIMIT 1] ;
            List<SmartMsg__Message__c> smsScheduleList = new List<SmartMsg__Message__c>();
            for(SmartMsg__Message__c sms: scheduleRecordUpdate ){
                string phone = sms.SmartMsg__To_Number__c;
                If(phoneNumber == phone && status == 'Scheduled'){
                    if (!Schema.sObjectType.SmartMsg__Message__c.isUpdateable()) {
                        throw new AuraHandledException('You do not have permission to create this message.');
                    }
                    SmartMsg__Message__c scheduledMessage = new SmartMsg__Message__c();
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
            if(smsScheduleList.size()>0){
                update smsScheduleList;
            }
            return smsScheduleList[0].Id;
        }
        else {
            return null;
        }
    }
    
    
    /**
     * @description Wrapper for Twilio error response.
     */
    public class ErrorResponseWrapper {
        public String code;
        public String message;
        public String moreInfo;
        public String status;
    }
    /**
     * @description Wrapper for Twilio SMS response.
     */
    public class SMSResponse {
        public String sid;
        public String dateCreated;
        public String dateUpdated;
        public String dateSent;
        public String accountSid;
        public String to;
        public String body;
        public String status;
        public String numSegments;
        public String numMedia;
        public String direction;
        public String apiVersion;
        public String price;
        public String priceUnit;
        public String errorCode;
        public String errorMessage;
        public String uri;
        public String subresourceUris;
    }
    /**
     * @description Wrapper for Twilio Asset response.
     */
    public class AssetResponse {
        public String sid;
        public String serviceSid;
        public String url;
        public String visibility;
        public String dateCreated;
        public String dateUpdated;
    }
    
}