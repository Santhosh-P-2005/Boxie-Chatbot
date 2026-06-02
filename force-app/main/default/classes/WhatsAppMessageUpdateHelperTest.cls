/**
 * @description Test class for the MessageUpdateHelper class.
 *              This class contains unit tests to verify the functionality 
 *              of the methods in the MessageUpdateHelper class.
 */
@IsTest
public class WhatsAppMessageUpdateHelperTest {
     /**
     * @description Setup method to insert test data.
     */  
    @testSetup
    public static void setup() {
        SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getOrgDefaults();
        metaSetting.SmartMsg__Application_Id__c = 'TestApplicationId';
        metaSetting.App_Secret_key__c = 'TestSecretKey';
        metaSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        metaSetting.SmartMsg__Phone_Number_Id__c = 'TestPhoneNumberId';
        metaSetting.SmartMsg__WhatsApp_Business_Id__c = '6789';
        metaSetting.SmartMsg__Service_Provider_Name__c = 'Meta';
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Active__c = false;
        insert metaSetting;
       
        SmartMsg__Messenger_Bot__c bot = new SmartMsg__Messenger_Bot__c();
        bot.Name = 'WhatsApp';
        bot.SmartMsg__Active__c  = true;
        insert bot; 

        SmartMsg__Dialogue__c dialog1 = new SmartMsg__Dialogue__c();
        dialog1.SmartMsg__Question__c = 'Hi';
        dialog1.SmartMsg__Parent_Template__c = bot.Id;
        dialog1.SmartMsg__Response__c = 'Welcome to Storage Space.\n Choose your language';
        dialog1.SmartMsg__Type__c = 'button';
        insert dialog1;

        SmartMsg__Dialogue__c dialog2 = new SmartMsg__Dialogue__c();
        dialog2.SmartMsg__Question__c = 'English';
        dialog2.SmartMsg__Parent_Template__c = bot.Id;
        dialog2.SmartMsg__Response__c = 'How Can I help you.Choose the options';
        dialog2.SmartMsg__Type__c = 'option';
        insert dialog2;

        SmartMsg__Dialogue__c dialog3 = new SmartMsg__Dialogue__c();
        dialog3.SmartMsg__Question__c = 'Nederlands';
        dialog3.SmartMsg__Parent_Template__c = bot.Id;
        dialog3.SmartMsg__Response__c = 'How Can I help you.Choose the options';
        dialog3.SmartMsg__Type__c = 'option';
        insert dialog3;

        SmartMsg__Dialogue__c dialog4 = new SmartMsg__Dialogue__c(
        SmartMsg__Question__c = 'New Customer',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Type__c = 'Question Based'
        );
        insert dialog4;

        SmartMsg__Dialogue__c dialog5 = new SmartMsg__Dialogue__c(
        SmartMsg__Parent_Record__c = dialog4.Id,
        SmartMsg__Response__c = 'In which city do you need storage?',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Order_Number__c = 1,
        SmartMsg__Buttons_or_Options__c = 'Berlin\nAmsterdam\nMunich\nParis\nLondon',
        SmartMsg__Type__c = 'option'
        );
        insert dialog5;

        SmartMsg__Dialogue__c dialog6 = new SmartMsg__Dialogue__c(
        SmartMsg__Parent_Record__c = dialog4.Id,
        SmartMsg__Response__c = 'What Storage size do you need?',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Order_Number__c = 2,
        SmartMsg__Buttons_or_Options__c = '1m²\n2m²\n3m²\n4m²',
        SmartMsg__Type__c = 'option'
        );
        insert dialog6;

        

        SmartMsg__Dialogue__c dialog7 = new SmartMsg__Dialogue__c(
        SmartMsg__Parent_Record__c = dialog4.Id,
        SmartMsg__Response__c = 'For how long do you need storage?',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Order_Number__c = 3,
        SmartMsg__Buttons_or_Options__c = '3 Months\n6 Months\n12 Months',
        SmartMsg__Type__c = 'option'
        );
        insert dialog7;

        SmartMsg__Dialogue__c dialog8 = new SmartMsg__Dialogue__c(
        SmartMsg__Response__c = 'Is there anything else I can help you with?',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Buttons_or_Options__c = 'Yes\nNo',
        SmartMsg__Type__c = 'Separate Button'
        );
        insert dialog8;

        SmartMsg__Dialogue__c dialog9 = new SmartMsg__Dialogue__c(
        SmartMsg__Question__c = 'Existing Customer',
        SmartMsg__Response__c = 'Select any one of the options',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Type__c = 'option'
        );
        insert dialog9;

        SmartMsg__Dialogue__c dialog10 = new SmartMsg__Dialogue__c(
        SmartMsg__Question__c = 'Invoice Question',
        SmartMsg__Response__c = 'Invoice related queries',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Type__c = 'Separate Text'
        );
        insert dialog10;

        SmartMsg__Dialogue__c dialog11 = new SmartMsg__Dialogue__c(
        SmartMsg__Question__c = 'Followup pickup',
        SmartMsg__Response__c = 'You can followup based on your pcikup',
        SmartMsg__Parent_Template__c = bot.Id,
        SmartMsg__Type__c = 'Separate Text'
        );
        insert dialog11;

        List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>{
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog1.Id,
                SmartMsg__Outbound_Response__c = dialog2.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog2.Id,
                SmartMsg__Outbound_Response__c = dialog4.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog2.Id,
                SmartMsg__Outbound_Response__c = dialog9.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog9.Id,
                SmartMsg__Outbound_Response__c = dialog10.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog9.Id,
                SmartMsg__Outbound_Response__c = dialog11.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog4.Id,
                SmartMsg__Order_Number__c = 1
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog4.Id,
                SmartMsg__Order_Number__c = 2
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog4.Id,
                SmartMsg__Order_Number__c = 3
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog7.Id,
                SmartMsg__Outbound_Response__c = dialog8.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog10.Id,
                SmartMsg__Outbound_Response__c = dialog8.Id
            ),
            new SmartMsg__Option_Dialog__c(
                SmartMsg__Inbound_Response__c = dialog11.Id,
                SmartMsg__Outbound_Response__c = dialog8.Id
            )
        };
        insert optionDialogList;
    }

    /**
     * @description Mock HTTP callout that returns a configurable response for tests.
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        /** @description The response to return for any request. */
        public HttpResponse mockResponse;

        /**
         * @description Constructs the mock with the given response.
         * @param response The HTTP response to return.
         */
        public MockHttpResponseGenerator(HttpResponse response){
            this.mockResponse = response;
        }

        /**
         * @description Responds to an HTTP request with the configured mock response.
         * @param req The HTTP request (ignored).
         * @return The configured mock HttpResponse.
         */
        public HttpResponse respond(HttpRequest req) {
            return mockResponse;
        }
    }

    private class HttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        void setMockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
          /**
         * @description Handles the HTTP request and generates an appropriate response based on the request's endpoint.
         * If the request endpoint contains 'image123', it returns a success response with a JSON body containing a URL to an image.
         * If the request endpoint contains 'http://example.com/image.jpg', it returns a success response with a body containing fake image data.
         * Otherwise, it returns an error response with status code 400 (Bad Request) and a JSON body with an error message indicating an unexpected endpoint.
         * @param req The HttpRequest object representing the incoming request.
         * @return An HttpResponse object representing the response to the incoming request.
         */
            public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            String endpoint = req.getEndpoint();
            if (endpoint.contains('image123')) {
                res.setStatusCode(200);
                res.setBody('{"url":"http://example.com/image.jpg"}');
            } else if (endpoint.contains('http://example.com/image.jpg')) {
                res.setStatusCode(200);
                res.setBody('fakeImageData');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Unexpected endpoint"}');
            }
            return res;
        }
        
    }
     /**
     * @description Test method for verifying GET request with a valid token.
     */
    @IsTest
    public static void testDoGetValidToken() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'TestSecretKey');
        req.params.put('hub.challenge', 'test_challenge');
        
        RestContext.request = req;
        RestContext.response = res;
        
        WhatsAppWebhook.doGet();
        
        Assert.areEqual('test_challenge', res.responseBody.toString(), 'Response body should match the challenge.');
    } 
     /**
     * @description Test method for verifying GET request with an invalid token.
     
    @IsTest
    public static void testDoGetInvalidToken() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'INVALIDTOKEN');
        req.params.put('hub.challenge', 'test_challenge');
        RestContext.request = req;
        RestContext.response = res;
        WhatsAppWebhook.doGet();
        Assert.areEqual(null, res.responseBody, 'Response body should be null for invalid token.');
    }
    /**
     * @description Test method for verifying POST request with a valid signature.
     */
    @IsTest
    public static void testDoPostValidSignature() {
        //String validPayload = '{"entry":[{"id":"TestWhatsAppBusinessId","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"id":"message123","type":"text","text":{"body":"Hello"},"image":{"id":"image123","mime_type":"image/jpeg","sha256":"imageSHA256"},"video":{"id":"video123","mime_type":"video/mp4","sha256":"videoSHA256"},"document":{"id":"doc123","mime_type":"application/pdf","sha256":"docSHA256"},"location":{"address":"123 Street","latitude":"45.0","longitude":"-93.0","name":"LocationName","url":"http://location.url"},"button":{"text":"ButtonText"},"reaction":{"emoji":"👍","message_id":"parentMessageId"},"context":{"id":"context123"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(1);
        insert messageRecord;
        String validPayload = '{"object":"whatsapp_business_account","entry":[{"id":"TestWhatsAppBusinessId","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"123-456-7890"},"statuses":[{"id":"12345","status":"sent","timestamp":"1754549882","recipient_id":"916380304219","conversation":{"id":"f3b49be7723865ccf934b1eb375b0afc","expiration_timestamp":"1754549882","origin":{"type":"service"}}}]},"field":"messages"}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
        HttpMock mock = new HttpMock();
        mock.setMockHttpResponse(200, '{"url":"http://example.com/image.jpg"}');        
        Test.setMock(HttpCalloutMock.class, mock);      
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Business_Phone_Number__c, SmartMsg__From_Number__c, SmartMsg__Customer_Name__c, 
                                               SmartMsg__Message_ID__c, SmartMsg__Message_Type__c, SmartMsg__Message_Body__c, SmartMsg__Reaction__c, 
                                               SmartMsg__Parent_Message_Id__c, SmartMsg__Image_ID__c, SmartMsg__Image_type__c, SmartMsg__Image_SHA256__c,
                                               SmartMsg__Video_ID__c, SmartMsg__Video_Type__c, SmartMsg__Video_SHA256__c, SmartMsg__Document_ID__c, 
                                               SmartMsg__Document_Type__c, SmartMsg__Document_SHA256__c, SmartMsg__Location_Address__c, SmartMsg__Location_Latitude__c, 
                                               SmartMsg__Location_Longitude__c, SmartMsg__Location_Name__c, SmartMsg__Location_Link__c FROM SmartMsg__Message__c];      
        Assert.areEqual(1, messages.size(), 'Expected one message record to be inserted.');        
        SmartMsg__Message__c message = messages[0];
      	Assert.areEqual('123-456-7890', message.SmartMsg__Business_Phone_Number__c, 'Business phone number should match.');
        Assert.areEqual('12345', message.SmartMsg__Message_ID__c, 'Message ID should match.');
        
       }
    
    @isTest
    public static void processWhatsappIncomingMessageTest(){
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"7890","phone_number_id":"9876"},"contacts":[{"profile":{"name":"Prakash"},"wa_id":"12345"}],"messages":[{"from":"12345","id":"6789","timestamp":"1764650051","text":{"body":"HI"},"type":"text"}]},"field":"messages"}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;
        HttpMock mock = new HttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(response));
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Message_Body__c,SmartMsg__Message_ID__c,SmartMsg__From_Number__c  FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('6789',messageList[0].SmartMsg__Message_ID__c,'Message Id mis match');
    }
    
    @isTest
    public static void processIncomingImageTest(){
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"image":{"id":"image123","mime_type":"image/jpeg","sha256":"imageSHA256"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(response));     
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Message_Body__c,SmartMsg__Image_ID__c,SmartMsg__From_Number__c  FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('image123',messageList[0].SmartMsg__Image_ID__c,'Image ID mismatching');
    }
    
    @isTest
    public static void processIncomingAudioTest(){
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"audio":{"id":"Audio123","mime_type":"audio/ogg","sha256":"audioSHA256"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        //ring validPayload = '{"entry":[{"id":"6789","changes":[{"value":{metadata":{"display_phone_number":"9186789","phone_number_id":"64210409"},"contacts":[{"profile":{"name":"Prakash"},"wa_id":"9163219"}],"messages":[{"from":"914219","id":"Audio123","timestamp":"1764653889","type":"audio","audio":{"mime_type":"audio/ogg; codecs=opus","sha256":"dztyeh7RTcfeAcQ5/,"id":"890674739978203","voice":true}}]},"field":"messages"}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(response));     
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Message_Body__c,SmartMsg__Video_ID__c,SmartMsg__From_Number__c  FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('Audio123',messageList[0].SmartMsg__Video_ID__c,'Audio ID mismatching');
    }
    
    @isTest
    public static void processIncomingVedioTest(){
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"video":{"id":"video123","mime_type":"video/mp4","sha256":"videoSHA256"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(response));        
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Message_Body__c,SmartMsg__Video_ID__c,SmartMsg__From_Number__c  FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('video123',messageList[0].SmartMsg__Video_ID__c,'Video ID mismatching');
    }
    
    @isTest
    public static void processIncomingDocumentTest(){
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"document":{"id":"doc123","mime_type":"application/pdf","sha256":"docSHA256"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(response));    
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Message_Body__c,SmartMsg__Document_ID__c,SmartMsg__From_Number__c  FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('doc123',messageList[0].SmartMsg__Document_ID__c,'Document Id mismatching');
    }
    
    @isTest
    public static void processIncomingLocationTest(){
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"location":{"address":"123 Street","latitude":"45.0","longitude":"-93.0","name":"LocationName","url":"http://location.url"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(response));      
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Location_Latitude__c,SmartMsg__Document_ID__c,SmartMsg__From_Number__c  FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('45.0',messageList[0].SmartMsg__Location_Latitude__c,'Document Id mismatching');
    }
    
    @isTest
    public static void processHandleStatusErrorTest(){
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(1);
        insert messageRecord;
        String validPayload = '{"entry":[{"id":"6789","changes":[{"value":{"statuses":[{"id":"12345","status":"Failed","errors":[{"code":"124","title":"Test Error","message":"Failed to sent message","error_data":{"details":"Test error details"}}]}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"button":{"text":"ButtonText"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(validPayload), Blob.valueOf('TestSecretKey'))));        
        RestContext.request = req;
        RestContext.response = res;        
             
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c LIMIT 1];
        System.assertEquals('Failed',messageList[0].SmartMsg__Delivery_Status__c,'Failed status mis matching');
    }
	/**
     * @description Test method for verifying POST request with an invalid signature.
     
    @IsTest
    public static void testDoPostInvalidSignature() {
        String validPayload = '{"entry":[{"changes":[{"value":{"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"id":"message123","type":"text","text":{"body":"Hello"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(validPayload);
        req.addHeader('X-Hub-Signature-256', 'invalid_signature');
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();
        Assert.areEqual(401, res.statusCode,'Response status code should be 401.');
        System.assert(res.responseBody.toString().contains('Unknown'), 'Response body should contain "Unknown" message.');
    }
	/**
     * @description Test method for validating WhatsApp signature.
     */
      @IsTest
    public static void testValidateWhatsAppSignature() {
        String payload = '{"test":"data"}';
        String validSignature = 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(payload), Blob.valueOf('TestSecretKey')));        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.addHeader('X-Hub-Signature-256', validSignature);        
        String result = WhatsAppWebhook.validateWhatsAppSignature(req, payload);
        Assert.areEqual(WhatsAppWebhook.SIGNATURE_VALID_MESSAGE, result, 'Signature should be valid.');
        req.headers.put('X-Hub-Signature-256', 'invalid_signature');
        result = WhatsAppWebhook.validateWhatsAppSignature(req, payload);
        Assert.areEqual(WhatsAppWebhook.SIGNATURE_NOT_VALID_MESSAGE, result, 'Signature should be not valid.');
    }
    /**
     * @description Test method for getting image URL.
     */
   @IsTest
    public static void testGetImageUrl() {
        Test.startTest();
        HttpMock mock = new HttpMock();
        mock.setMockHttpResponse(200, '{"url":"http://example.com/image.jpg"}');
        Test.setMock(HttpCalloutMock.class, mock);
        String imageId = '123456';
        String result = WhatsAppWebhook.getImageUrl(imageId);        
        Test.stopTest();
        Assert.areEqual(null, result, 'Image URL should be null.');
    }

    /**
     * @description Covers WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid and twilioStatusOrder:
     * blank params, no message found, status-order no-op, Failed + failedReason + callbackPayload, platform event.
     */
    @IsTest
    public static void testUpdateDeliveryStatusByTwilioMessageSid() {
        // Blank messageSid or deliveryStatus -> return false
        System.assert(!WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('', 'Sent', null, null), 'blank messageSid');
        System.assert(!WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('SID', '', null, null), 'blank deliveryStatus');
        // No message found -> return false
        System.assert(!WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('NonExistentSID', 'Sent', null, null), 'no message');

        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(3);
        msgs[0].SmartMsg__Message_ID__c = 'TW_SID_DELIVERED';
        msgs[0].SmartMsg__Delivery_Status__c = 'Delivered';
        msgs[0].SmartMsg__Channel__c = null;
        msgs[1].SmartMsg__Message_ID__c = 'TW_SID_SENT';
        msgs[1].SmartMsg__Delivery_Status__c = 'Sent';
        msgs[2].SmartMsg__Message_ID__c = 'TW_SID_READ';
        msgs[2].SmartMsg__Delivery_Status__c = 'Read';
        insert msgs;

        // newOrder <= currentOrder -> return true without update (Delivered -> Sent; covers twilioStatusOrder sent/delivered)
        System.assert(WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('TW_SID_DELIVERED', 'Sent', null, null), 'no-op advance');
        // Same for Read -> Sent (covers twilioStatusOrder read)
        System.assert(WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('TW_SID_READ', 'Scheduled', null, null), 'no-op read');

        // Message with null status: update to Delivered (covers twilioStatusOrder null and delivered)
        List<SmartMsg__Message__c> msgNull = TestObjectFactory.createMessageRecords(1);
        msgNull[0].SmartMsg__Message_ID__c = 'TW_SID_NULL';
        msgNull[0].SmartMsg__Delivery_Status__c = null;
        insert msgNull;
        System.assert(WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('TW_SID_NULL', 'Delivered', null, null), 'null to delivered');

        // Failed + failedReason + callbackPayload -> update and publish event (Channel null -> 'Twilio WhatsApp')
        System.assert(WhatsAppMessageUpdateHelper.updateDeliveryStatusByTwilioMessageSid('TW_SID_SENT', 'Failed', 'Some error', '{"callback":true}'), 'failed with reason and payload');
        SmartMsg__Message__c updated = [SELECT Id, SmartMsg__Failed_Reason__c, SmartMsg__Response__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'TW_SID_SENT' LIMIT 1];
        System.assert(updated.SmartMsg__Failed_Reason__c == 'Some error', 'failed reason');
        System.assert(updated.SmartMsg__Response__c == '{"callback":true}', 'callback payload');

        // shareMessageWithGuestUserForStatusCallback: null messageId -> early return; valid Id -> query guest users, create shares if any (or early return if empty)
        WhatsAppMessageUpdateHelper.shareMessageWithGuestUserForStatusCallback(null);
        WhatsAppMessageUpdateHelper.shareMessageWithGuestUserForStatusCallback(msgs[0].Id);
    }

    /**
     * @description Covers WhatsAppMessageUpdateHelper template update in storeIncomingWAMessage: APPROVED, REJECTED/FAILED, find by template name, rejection_reason truncation.
     */
    @IsTest
    public static void testProcessIncomingMessageTemplateStatusUpdate() {
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(2, 'Twilio WhatsApp', 'Pending', 'TID_APPROVED');
        templates[0].SmartMsg__WhatsApp_Template_ID__c = 'TID_APPROVED';
        templates[0].SmartMsg__Template_API_Name__c = 'approved_template';
        templates[1].SmartMsg__WhatsApp_Template_ID__c = 'TID_REJECTED';
        templates[1].SmartMsg__Template_API_Name__c = 'rejected_template';
        insert templates;

        // Use empty messages[] so we never create an inbound message or trigger the chatbot (which enqueues SendWhatsAppMessagesWithUpdatedJSON and NPEs when mock returns {}).
        String payloadApproved = '{"entry":[{"id":"6789","changes":[{"value":{"message_template_id":"TID_APPROVED","event":"APPROVED","metadata":{"display_phone_number":"123"},"messages":[]}}]}]}';
        String payloadRejected = '{"entry":[{"id":"6789","changes":[{"value":{"message_template_id":"TID_REJECTED","event":"REJECTED","rejection_reason":"Short reason","metadata":{"display_phone_number":"123"},"messages":[]}}]}]}';
        String longReason = '';
        for (Integer i = 0; i < 300; i++) longReason += 'x';
        String payloadFailedLongReason = '{"entry":[{"id":"6789","changes":[{"value":{"message_template_id":"NONEXISTENT","name":"rejected_template","event":"FAILED","rejection_reason":"' + longReason + '","metadata":{"display_phone_number":"123"},"messages":[]}}]}]}';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1/';
        req.httpMethod = 'POST';

        req.requestBody = Blob.valueOf(payloadApproved);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(payloadApproved), Blob.valueOf('TestSecretKey'))));
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        WhatsAppMessageUpdateHelper.processIncomingMessage(payloadApproved);
        Test.stopTest();
        SmartMsg__Message_Template__c tApproved = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__WhatsApp_Template_ID__c = 'TID_APPROVED' LIMIT 1];
        System.assert(tApproved.SmartMsg__Status__c == 'Approved' && tApproved.SmartMsg__Error_Response__c == null, 'APPROVED branch');

        req.requestBody = Blob.valueOf(payloadRejected);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(payloadRejected), Blob.valueOf('TestSecretKey'))));
        WhatsAppMessageUpdateHelper.processIncomingMessage(payloadRejected);
        SmartMsg__Message_Template__c tRejected = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__WhatsApp_Template_ID__c = 'TID_REJECTED' LIMIT 1];
        System.assert(tRejected.SmartMsg__Status__c == 'Failed' && tRejected.SmartMsg__Error_Response__c == 'Short reason', 'REJECTED branch');

        req.requestBody = Blob.valueOf(payloadFailedLongReason);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(payloadFailedLongReason), Blob.valueOf('TestSecretKey'))));
        WhatsAppMessageUpdateHelper.processIncomingMessage(payloadFailedLongReason);
        SmartMsg__Message_Template__c tFailed = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_API_Name__c = 'rejected_template' LIMIT 1];
        System.assert(tFailed.SmartMsg__Status__c == 'Failed' && tFailed.SmartMsg__Error_Response__c != null && tFailed.SmartMsg__Error_Response__c.length() == 255, 'FAILED by name, reason truncated');

        // ContentDocumentLink coverage (lines 331-336): payload with image sets mediaId -> test-only path sets Media_Url__c -> link created (type image avoids chatbot/callout)
        String payloadWithImage = '{"entry":[{"id":"6789","changes":[{"value":{"metadata":{"display_phone_number":"123"},"contacts":[{"wa_id":"1234567890","profile":{"name":"Test"}}],"messages":[{"id":"img1","type":"image","image":{"id":"img1","mime_type":"image/jpeg","sha256":"x"}}]}}]}]}';
        req.requestBody = Blob.valueOf(payloadWithImage);
        req.addHeader('X-Hub-Signature-256', 'sha256=' + EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(payloadWithImage), Blob.valueOf('TestSecretKey'))));
        WhatsAppMessageUpdateHelper.processIncomingMessage(payloadWithImage);
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM SmartMsg__Message__c WHERE SmartMsg__Message_ID__c = 'img1')];
        System.assert(!cdls.isEmpty(), 'ContentDocumentLink should be created when Media_Url__c is set');
    }

     /**
     * @description Inner class for mocking HTTP callouts.
     */
    
    
   /* @isTest
    public static void testHandleIncomingMessage() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/twilioWebhook/';
        request.addParameter('From', '1234567890');
        request.addParameter('Body', 'Test message');
        request.addParameter('AccountSid', 'testAccountSID');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        RestContext.request = request;
        RestContext.response = response;
        TwilioWebHook.handleIncomingMessage();
        Test.stopTest();

        Assert.areEqual('text/plain', RestContext.response.headers.get('Content-Type'), 'Unexpected Content-Type header');
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__To_Number__c, SmartMsg__Message_Body__c, SmartMsg__Outgoing__c, SmartMsg__Type__c, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c];
        Assert.areEqual(1, messages.size(), 'Unexpected number of message records created');
        SmartMsg__Message__c message = messages[0];
        Assert.areEqual('+1234567890', message.SmartMsg__To_Number__c, 'Unexpected phone number');
        Assert.areEqual('Test message', message.SmartMsg__Message_Body__c, 'Unexpected message body');
        Assert.areEqual(false, message.SmartMsg__Outgoing__c, 'Expected message to be inbound');
        Assert.areEqual('Inbound', message.SmartMsg__Type__c, 'Unexpected message type');
        Assert.areEqual('Received', message.SmartMsg__Delivery_Status__c, 'Unexpected message delivery status');
    }*/
    
    
	/**
     * @description Mock HTTP response generator for simulating HTTP callouts.
     */
    
}