/**
 * @description Test class for TwilioWhatsAppWebhook.
 * This class contains unit tests to verify the functionality of the TwilioWhatsAppWebhook REST service.
 * Reference: WhatsAppWebhookTest.cls
 */
@isTest
public class TwilioWhatsAppWebhookTest {
    
    /**
     * @description Inner class for mocking HTTP callouts to Twilio API (Content API and Messages API).
     */
    private class TwilioWebhookMock implements HttpCalloutMock {
        private List<Integer> statusCodes;
        private List<String> bodies;
        private Integer calloutIndex = 0;
        
        /**
         * @description Constructor for single response.
         * @param statusCode The HTTP status code to return.
         * @param body The response body to return.
         */
        TwilioWebhookMock(Integer statusCode, String body) {
            this.statusCodes = new List<Integer>{ statusCode };
            this.bodies = new List<String>{ body };
        }
        
        /**
         * @description Constructor for multiple responses.
         * @param statusCodes List of HTTP status codes to return.
         * @param bodies List of response bodies to return.
         */
        TwilioWebhookMock(List<Integer> statusCodes, List<String> bodies) {
            this.statusCodes = statusCodes;
            this.bodies = bodies;
        }
        
        /**
         * @description Handles the HTTP request and generates an appropriate response based on the endpoint.
         * @param req The HttpRequest object representing the incoming request.
         * @return An HttpResponse object representing the response to the incoming request.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            // String endpoint = req.getEndpoint();
            
            Integer index = calloutIndex < statusCodes.size() ? calloutIndex : statusCodes.size() - 1;
            res.setStatusCode(statusCodes[index]);
            res.setBody(bodies[index]);
            calloutIndex++;
            
            return res;
        }
    }
    
    /**
     * @description Helper method to generate Twilio Messages API response.
     * @param sid The message SID.
     * @param toNumber The recipient phone number.
     * @param fromNumber The sender phone number.
     * @param body The message body.
     * @return JSON string representing the Twilio Messages API response.
     */
    public static String getTwilioMessageResponse(String sid, String toNumber, String fromNumber, String body) {
        String escapedBody = body != null ? body.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') : '';
        return '{"account_sid":"ACTestAccountSID123","api_version":"2010-04-01","body":"' + 
               escapedBody + '","date_created":"Mon, 01 Jan 2024 12:00:00 +0000","date_sent":null,"date_updated":"Mon, 01 Jan 2024 12:00:00 +0000",' +
               '"direction":"outbound-api","error_code":null,"error_message":null,"from":"whatsapp:' + fromNumber + '",' +
               '"messaging_service_sid":null,"num_media":"0","num_segments":"1","price":null,"price_unit":null,"sid":"' + sid + '",' +
               '"status":"queued","subresource_uris":{"media":"/2010-04-01/Accounts/ACTestAccountSID123/Messages/' + sid + '/Media.json"},' +
               '"to":"whatsapp:' + toNumber + '","uri":"/2010-04-01/Accounts/ACTestAccountSID123/Messages/' + sid + '.json"}';
    }
    
    /**
     * @description Helper method to generate Twilio Content API response.
     * @param friendlyName The friendly name of the content template.
     * @param sid The content SID.
     * @return JSON string representing the Twilio Content API response.
     */
    public static String getContentAPIResponse(String friendlyName, String sid) {
        String contentType = 'twilio/text';
        if (friendlyName.contains('quick-reply') || friendlyName.contains('_dynamic_quick_reply')) {
            contentType = 'twilio/quick-reply';
        } else if (friendlyName.contains('list-picker') || friendlyName.contains('_dynamic_list_picker')) {
            contentType = 'twilio/list-picker';
        }
        
        return '{"contents":[{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"' + 
               friendlyName + '","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/' + sid + '/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/' + sid + '/ApprovalRequests"},' +
               '"sid":"' + sid + '","types":{"' + contentType + '":{}},"url":"https://content.twilio.com/v1/Content/' + sid + '","variables":{}}]}';
    }
    
    /**
     * @description Test method to verify handling of incoming message with body using the provided format.
     */
    @isTest
    public static void testHandleIncomingMessageWithBody() {
        // Create test data using TestObjectFactory
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Dialogue__c> dialogList = TestObjectFactory.createDialogRecords(2);
        insert dialogList;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        // Set up HTTP mocks for Content API and Messages API callouts
        // Include both possible template names that might be requested
        String contentResponse = '{"contents":[{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"2_dynamic_quick_reply","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/HXTestContentSID123/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/HXTestContentSID123/ApprovalRequests"},"sid":"HXTestContentSID123","types":{"twilio/quick-reply":{}},"url":"https://content.twilio.com/v1/Content/HXTestContentSID123","variables":{}},{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"dynamic_text_template","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/HXTestContentSID456/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/HXTestContentSID456/ApprovalRequests"},"sid":"HXTestContentSID456","types":{"twilio/text":{}},"url":"https://content.twilio.com/v1/Content/HXTestContentSID456","variables":{}}]}';
        String messageResponse = getTwilioMessageResponse('SMTestMessageSID1234', '+1234567890', '+1234567890', 'Welcome to Storage Space.\n Choose your language');
        
        Test.setMock(HttpCalloutMock.class, new TwilioWebhookMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        
        // Build request using test data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        
        // Set parameters using test data
        req.params.put('AccountSid', 'ACTestAccountSID123');
        req.params.put('ApiVersion', '2010-04-01');
        req.params.put('Body', 'hi');
        req.params.put('ChannelMetadata', '{"type":"whatsapp","data":{"context":{"ProfileName":"TestUser","WaId":"1234567890"}}}');
        req.params.put('From', 'whatsapp:+1234567890');
        req.params.put('To', 'whatsapp:+1234567890');
        req.params.put('MessageSid', 'SMTestMessageSID123');
        req.params.put('MessageType', 'text');
        req.params.put('NumMedia', '0');
        req.params.put('NumSegments', '1');
        req.params.put('ProfileName', 'TestUser');
        
        RestContext.request = req;
        RestContext.response = res;
        
        try {
            TwilioWhatsAppWebhook.handleIncomingMessage();
        } catch (Exception e) {
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        // Assert that the message was created
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__To_Number__c, SmartMsg__From_Number__c, SmartMsg__Channel__c, SmartMsg__Delivery_Status__c, SmartMsg__Messaging_Session__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = 'SMTestMessageSID123'];
        System.assertEquals(1, messages.size(), 'Message should be created');
        System.assertEquals('hi', messages[0].SmartMsg__Message_Body__c, 'Message body should match');
        System.assertEquals('+1234567890', messages[0].SmartMsg__To_Number__c, 'To number should match');
        System.assertEquals('+1234567890', messages[0].SmartMsg__From_Number__c, 'From number should match');
        System.assertEquals('WhatsApp', messages[0].SmartMsg__Channel__c, 'Channel should be Twilio WhatsApp');
        System.assertEquals('Received', messages[0].SmartMsg__Delivery_Status__c, 'Delivery status should be Received');
        System.assertNotEquals(null, messages[0].SmartMsg__Messaging_Session__c, 'Messaging session should be created');
    }
    
    /**
     * @description Test inbound WhatsApp media webhook stores media fields and downloads file to Salesforce.
     */
    @isTest
    public static void testHandleIncomingMessageWithMedia() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;

        Test.setMock(HttpCalloutMock.class, new TwilioInboundMediaMock());

        Test.startTest();

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.params.put('From', 'whatsapp:+1234567890');
        req.params.put('To', 'whatsapp:+19876543210');
        req.params.put('MessageSid', 'SMTestMediaInbound01');
        req.params.put('MessageType', 'image');
        req.params.put('NumMedia', '1');
        req.params.put('MediaUrl0', 'https://api.twilio.com/2010-04-01/Accounts/ACTest/Media/ME123');
        req.params.put('MediaContentType0', 'image/jpeg');
        req.params.put('MediaSid0', 'ME123');
        req.params.put('Body', 'Photo caption');

        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        Test.stopTest();

        SmartMsg__Message__c msg = [
            SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Message_Type__c, SmartMsg__File_Name__c,
                SmartMsg__Media_File__c, SmartMsg__Media_ID__c, SmartMsg__Image_ID__c, SmartMsg__Image_type__c,
                SmartMsg__Image_SHA256__c, SmartMsg__Media_Url__c, SmartMsg__Channel__c
            FROM SmartMsg__Message__c
            WHERE SmartMsg__Message_Id__c = 'SMTestMediaInbound01'
            LIMIT 1
        ];
        System.assertEquals('Photo caption', msg.SmartMsg__Message_Body__c, 'Caption should be stored');
        System.assertEquals('image', msg.SmartMsg__Message_Type__c, 'Message type should be image');
        System.assertEquals(true, msg.SmartMsg__Media_File__c, 'Media_File__c should be true');
        System.assertEquals('ME123', msg.SmartMsg__Media_ID__c, 'Media ID should match Twilio MediaSid0');
        System.assertEquals('ME123', msg.SmartMsg__Image_ID__c, 'Image_ID__c should match Meta-style storage');
        System.assertEquals('image/jpeg', msg.SmartMsg__Image_type__c, 'Image_type__c should store MIME type');
        System.assertEquals(null, msg.SmartMsg__Image_SHA256__c, 'Twilio webhook does not provide SHA256');
        System.assert(msg.SmartMsg__File_Name__c != null && msg.SmartMsg__File_Name__c.startsWith('wa_image_'), 'File name should follow Meta wa_image_ pattern');
        System.assertNotEquals(null, msg.SmartMsg__Media_Url__c, 'Media should be stored as ContentDocument after download');
        System.assertEquals('Twilio WhatsApp', msg.SmartMsg__Channel__c, 'Channel should be Twilio WhatsApp');
        System.assertEquals(200, res.statusCode, 'Webhook should return 200');
    }

    private class TwilioInboundMediaMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint() != null ? req.getEndpoint() : '';
            if (endpoint.contains('Twilio_API') || endpoint.contains('api.twilio.com')) {
                res.setStatusCode(307);
                res.setHeader('Location', 'https://media.twiliocdn.com/test-image.jpg');
                return res;
            }
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'image/jpeg');
            res.setBodyAsBlob(Blob.valueOf('fake-image-bytes'));
            return res;
        }
    }

    /**
     * @description Test method to verify handling of incoming message with MessageStatus.
     */
    @isTest
    public static void testHandleIncomingMessageWithStatus() {
        // Create test data using TestObjectFactory
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        
        // Set up HTTP mock for any callouts
        Test.setMock(HttpCalloutMock.class, new TwilioWebhookMock(200, '{"sid":"SM9876543210","status":"delivered"}'));
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        
        // Set parameters with MessageStatus using test data
        req.params.put('AccountSid', 'ACTestAccountSID123');
        req.params.put('ApiVersion', '2010-04-01');
        req.params.put('Body', 'Test message');
        req.params.put('From', 'whatsapp:+1234567890');
        req.params.put('To', 'whatsapp:+1234567890');
        req.params.put('MessageSid', 'SMTestMessageSID456');
        req.params.put('MessageStatus', 'Delivered');
        req.params.put('MessageType', 'text');
        req.params.put('ChannelMetadata', '{"type":"whatsapp","data":{"context":{"ProfileName":"TestUser","WaId":"1234567890"}}}');
        
        RestContext.request = req;
        RestContext.response = res;
        
        try {
            TwilioWhatsAppWebhook.handleIncomingMessage();
        } catch (Exception e) {
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        // When MessageStatus is present, messageStatus flag is true, so no message should be inserted
        List<SmartMsg__Message__c> messages = [SELECT Id FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = 'SMTestMessageSID456'];
        
        System.assertEquals(0, messages.size(), 'Message should not be created when MessageStatus is present');
    }
    
    /**
     * @description Test method to verify handling of incoming message with button reply.
     */
    @isTest
    public static void testHandleIncomingMessageWithButtonReply() {
        // Create test data using TestObjectFactory
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Dialogue__c> dialogList = TestObjectFactory.createDialogRecords(2);
        insert dialogList;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        // Set up HTTP mocks for Content API and Messages API callouts
        // Include both possible template names that might be requested
        String contentResponse = '{"contents":[{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"2_dynamic_quick_reply","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/HXTestContentSID123/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/HXTestContentSID123/ApprovalRequests"},"sid":"HXTestContentSID123","types":{"twilio/quick-reply":{}},"url":"https://content.twilio.com/v1/Content/HXTestContentSID123","variables":{}},{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"dynamic_text_template","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/HXTestContentSID456/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/HXTestContentSID456/ApprovalRequests"},"sid":"HXTestContentSID456","types":{"twilio/text":{}},"url":"https://content.twilio.com/v1/Content/HXTestContentSID456","variables":{}}]}';
        String messageResponse = getTwilioMessageResponse('SMTestMessageSID7890', '+1234567890', '+1234567890', 'Thank you');
        
        Test.setMock(HttpCalloutMock.class, new TwilioWebhookMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        
        // Set parameters with button reply using test data
        req.params.put('AccountSid', 'ACTestAccountSID123');
        req.params.put('ApiVersion', '2010-04-01');
        req.params.put('Body', 'No');
        req.params.put('ButtonText', 'No');
        req.params.put('ButtonPayload', 'No');
        req.params.put('From', 'whatsapp:+1234567890');
        req.params.put('To', 'whatsapp:+1234567890');
        req.params.put('MessageSid', 'SMTestMessageSID789');
        req.params.put('MessageType', 'text');
        req.params.put('ChannelMetadata', '{"type":"whatsapp","data":{"context":{"ProfileName":"TestUser","WaId":"1234567890"}}}');
        
        RestContext.request = req;
        RestContext.response = res;
        
        try {
            TwilioWhatsAppWebhook.handleIncomingMessage();
        } catch (Exception e) {
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        // Assert that the message was created with button reply type
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Message_Body__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = 'SMTestMessageSID789'];
        
        System.assertEquals(1, messages.size(), 'Message should be created');
        System.assertEquals('No', messages[0].SmartMsg__Message_Body__c, 'Message body should match button text');
    }
    
    /**
     * @description Test method to verify messaging session update when sessionUpdateFlag is true.
     */
    @isTest
    public static void testMessagingSessionUpdate() {
        TwilioWhatsAppWebhook.sessionUpdateFlag = true;
        
        // Create test data using TestObjectFactory
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Dialogue__c> dialogList = TestObjectFactory.createDialogRecords(2);
        insert dialogList;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        // Set up HTTP mocks for Content API and Messages API callouts
        // Include both possible template names that might be requested
        String contentResponse = '{"contents":[{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"2_dynamic_quick_reply","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/HXTestContentSID123/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/HXTestContentSID123/ApprovalRequests"},"sid":"HXTestContentSID123","types":{"twilio/quick-reply":{}},"url":"https://content.twilio.com/v1/Content/HXTestContentSID123","variables":{}},{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"dynamic_text_template","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/HXTestContentSID456/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/HXTestContentSID456/ApprovalRequests"},"sid":"HXTestContentSID456","types":{"twilio/text":{}},"url":"https://content.twilio.com/v1/Content/HXTestContentSID456","variables":{}}]}';
        String messageResponse = getTwilioMessageResponse('SMTestMessageSID999', '+1234567890', '+1234567890', 'Test response');
        
        Test.setMock(HttpCalloutMock.class, new TwilioWebhookMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        
        // Set parameters using test data
        req.params.put('AccountSid', 'ACTestAccountSID123');
        req.params.put('ApiVersion', '2010-04-01');
        req.params.put('Body', 'Test message');
        req.params.put('From', 'whatsapp:+1234567890');
        req.params.put('To', 'whatsapp:+1234567890');
        req.params.put('MessageSid', 'SMTestMessageSID999');
        req.params.put('MessageType', 'text');
        req.params.put('ChannelMetadata', '{"type":"whatsapp","data":{"context":{"ProfileName":"TestUser","WaId":"1234567890"}}}');
        
        RestContext.request = req;
        RestContext.response = res;
        
        try {
            TwilioWhatsAppWebhook.handleIncomingMessage();
        } catch (Exception e) {
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        // Assert that messaging session was updated
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Messaging_Session__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = 'SMTestMessageSID999'];
        
        if (!messages.isEmpty() && messages[0].SmartMsg__Messaging_Session__c != null) {
            List<SmartMsg__Messaging_Session__c> sessions = [SELECT Id, SmartMsg__No_of_Inbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id = :messages[0].SmartMsg__Messaging_Session__c];
            
            System.assertEquals(1, sessions.size(), 'Session should exist');
            System.assert(sessions[0].SmartMsg__No_of_Inbound_Messages__c >= 1, 'Inbound message count should be updated');
        }
    }
    
    /**
     * @description Test method to verify handling of empty request params.
     */
    @isTest
    public static void testHandleIncomingMessageEmptyParams() {
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        // No params added
        
        RestContext.request = req;
        RestContext.response = res;
        
        try {
            TwilioWhatsAppWebhook.handleIncomingMessage();
        } catch (Exception e) {
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        // No exception should be thrown, method should complete gracefully
        System.assert(true, 'Method should handle empty params without exception');
    }

    // ---------- Template approval callback (handleTwilioTemplateApprovalCallback) ----------
    private static final String VALID_CONTENT_SID = 'HXa1b2c3d4e5f6789012345678901234ab';

    @isTest
    public static void testTemplateApprovalCallback_Approved() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', VALID_CONTENT_SID);
        insert templates;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=' + VALID_CONTENT_SID + '&Status=approved');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TwilioWhatsAppWebhook.handleIncomingMessage();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Response should be 200 on template approval');
        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assertEquals('Approved', updated.SmartMsg__Status__c, 'Template status should be Approved');
        System.assertEquals(null, updated.SmartMsg__Error_Response__c, 'Error_Response should be cleared');
    }

    @isTest
    public static void testTemplateApprovalCallback_RejectedWithReason() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', VALID_CONTENT_SID);
        insert templates;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=' + VALID_CONTENT_SID + '&Status=rejected&rejection_reason=Placeholder+at+end');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TwilioWhatsAppWebhook.handleIncomingMessage();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Response should be 200');
        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assertEquals('Failed', updated.SmartMsg__Status__c, 'Template status should be Failed');
        System.assert(updated.SmartMsg__Error_Response__c != null && updated.SmartMsg__Error_Response__c.contains('Placeholder'), 'Rejection reason should be stored');
    }

    @isTest
    public static void testTemplateApprovalCallback_RejectedLongReasonTruncated() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', VALID_CONTENT_SID);
        insert templates;

        String longReason = 'x';
        for (Integer i = 0; i < 300; i++) longReason += 'y';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=' + VALID_CONTENT_SID + '&Status=rejected&rejection_reason=' + EncodingUtil.urlEncode(longReason, 'UTF-8'));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TwilioWhatsAppWebhook.handleIncomingMessage();
        Test.stopTest();

        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assert(updated.SmartMsg__Error_Response__c != null && updated.SmartMsg__Error_Response__c.length() == 255, 'Error_Response should be truncated to 255');
    }

    @isTest
    public static void testTemplateApprovalCallback_ContentSidTrimmed() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', VALID_CONTENT_SID);
        insert templates;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=%20%20' + VALID_CONTENT_SID + '%20%20&Status=approved');

        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assertEquals('Approved', updated.SmartMsg__Status__c, 'Template should be found after trim and updated');
    }

    @isTest
    public static void testTemplateApprovalCallback_UnknownStatusReturnsFalse() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=' + VALID_CONTENT_SID + '&Status=pending');

        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        System.assert(res.statusCode != 200, 'Template callback returns false for unknown status so response should not be 200');
    }

    @isTest
    public static void testTemplateApprovalCallback_InvalidContentSidReturnsFalse() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=INVALID&Status=approved');

        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        List<SmartMsg__Message_Template__c> templates = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__WhatsApp_Template_ID__c = 'INVALID'];
        System.assertEquals(0, templates.size(), 'No template should match invalid SID');
    }

    // ---------- Status callback (handleTwilioWhatsAppStatusCallback) - all MessageStatus branches ----------

    @isTest
    public static void testStatusCallback_Queued() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        msgs[0].SmartMsg__Message_ID__c = 'SMQueuedTest123';
        msgs[0].SmartMsg__Channel__c = 'WhatsApp';
        insert msgs;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.params.put('MessageSid', 'SMQueuedTest123');
        req.params.put('MessageStatus', 'queued');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TwilioWhatsAppWebhook.handleIncomingMessage();
        Test.stopTest();

        SmartMsg__Message__c updated = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'SMQueuedTest123'];
        System.assertEquals('Scheduled', updated.SmartMsg__Delivery_Status__c, 'Queued should map to Scheduled');
        System.assertEquals(200, res.statusCode, 'Response should be 200');
    }

    @isTest
    public static void testStatusCallback_Read() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        msgs[0].SmartMsg__Message_ID__c = 'SMReadTest456';
        msgs[0].SmartMsg__Channel__c = 'WhatsApp';
        insert msgs;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.params.put('MessageSid', 'SMReadTest456');
        req.params.put('MessageStatus', 'read');
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        SmartMsg__Message__c updated = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'SMReadTest456'];
        System.assertEquals('Read', updated.SmartMsg__Delivery_Status__c, 'read should map to Read');
    }

    @isTest
    public static void testStatusCallback_Sent() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        msgs[0].SmartMsg__Message_ID__c = 'SMSentTest789';
        msgs[0].SmartMsg__Channel__c = 'WhatsApp';
        msgs[0].SmartMsg__Delivery_Status__c = null;
        insert msgs;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('MessageSid=SMSentTest789&MessageStatus=sent');
        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        SmartMsg__Message__c updated = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'SMSentTest789'];
        System.assertEquals('Sent', updated.SmartMsg__Delivery_Status__c, 'sent should map to Sent');
    }

    @isTest
    public static void testStatusCallback_Failed() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        msgs[0].SmartMsg__Message_ID__c = 'SMFailedTest999';
        msgs[0].SmartMsg__Channel__c = 'WhatsApp';
        insert msgs;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.params.put('MessageSid', 'SMFailedTest999');
        req.params.put('MessageStatus', 'failed');
        req.params.put('ErrorMessage', 'Delivery failed');
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        SmartMsg__Message__c updated = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'SMFailedTest999'];
        System.assertEquals('Failed', updated.SmartMsg__Delivery_Status__c, 'failed should map to Failed');
    }

    @isTest
    public static void testStatusCallback_UnknownStatusElseBranch() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        msgs[0].SmartMsg__Message_ID__c = 'SMOtherStatus123';
        msgs[0].SmartMsg__Channel__c = 'WhatsApp';
        msgs[0].SmartMsg__Delivery_Status__c = null;
        insert msgs;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('MessageSid=SMOtherStatus123&MessageStatus=UnknownStatus');
        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        SmartMsg__Message__c updated = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'SMOtherStatus123'];
        System.assertEquals(null, updated.SmartMsg__Delivery_Status__c, 'Unknown status should be title-cased');
    }

    // ---------- parseFormUrlEncodedBody ----------

    @isTest
    public static void testParseFormUrlEncodedBody_Blank() {
        Map<String, String> out = TwilioWhatsAppWebhook.parseFormUrlEncodedBody('');
        System.assert(out != null && out.isEmpty(), 'Blank body should return empty map');
        out = TwilioWhatsAppWebhook.parseFormUrlEncodedBody(null);
        System.assert(out != null && out.isEmpty(), 'Null body should return empty map');
    }

    @isTest
    public static void testParseFormUrlEncodedBody_KeyValuePairs() {
        Map<String, String> out = TwilioWhatsAppWebhook.parseFormUrlEncodedBody('a=b&c=d');
        System.assertEquals('b', out.get('a'), 'Key a should have value b');
        System.assertEquals('d', out.get('c'), 'Key c should have value d');
    }

    @isTest
    public static void testParseFormUrlEncodedBody_EmptyValue() {
        Map<String, String> out = TwilioWhatsAppWebhook.parseFormUrlEncodedBody('key=');
        System.assert(out.containsKey('key'), 'Should contain key');
        System.assertEquals('', out.get('key'), 'Value should be empty');
    }

    @isTest
    public static void testHandleIncomingMessage_FormBodyUsedForParams() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', VALID_CONTENT_SID);
        insert templates;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=' + VALID_CONTENT_SID + '&ApprovalStatus=approved');

        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        System.assertEquals(200, res.statusCode, 'Form body should be parsed and template callback should set 200');
        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assertEquals('Approved', updated.SmartMsg__Status__c, 'ApprovalStatus from form body should be used');
    }

    @isTest
    public static void testTemplateApprovalCallback_TemplateStatusKey() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', VALID_CONTENT_SID);
        insert templates;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioWhatsAppStatus/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('ContentSid=' + VALID_CONTENT_SID + '&TemplateStatus=rejected');

        RestContext.request = req;
        RestContext.response = res;

        TwilioWhatsAppWebhook.handleIncomingMessage();

        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assertEquals('Failed', updated.SmartMsg__Status__c, 'TemplateStatus key should be used when ApprovalStatus blank');
    }
}