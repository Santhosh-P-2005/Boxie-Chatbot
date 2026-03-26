/**
 * @description Test class for the WhatsAppWebhook class.
 *              This class contains unit tests to verify the functionality 
 *              of the methods in the WhatsAppWebhook class.
 */
@IsTest
public class WhatsAppWebhookTest {
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
        metaSetting.SmartMsg__WhatsApp_Business_Id__c = 'TestWhatsAppBusinessId';
        metaSetting.SmartMsg__Service_Provider_Name__c = 'Meta';
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Active__c = false;
        
        insert metaSetting;
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
     */
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
     
    @IsTest
    public static void testDoPostValidSignature() {
        String validPayload = '{"entry":[{"id":"TestWhatsAppBusinessId","changes":[{"value":{"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"id":"message123","type":"text","text":{"body":"Hello"},"image":{"id":"image123","mime_type":"image/jpeg","sha256":"imageSHA256"},"video":{"id":"video123","mime_type":"video/mp4","sha256":"videoSHA256"},"document":{"id":"doc123","mime_type":"application/pdf","sha256":"docSHA256"},"location":{"address":"123 Street","latitude":"45.0","longitude":"-93.0","name":"LocationName","url":"http://location.url"},"button":{"text":"ButtonText"},"reaction":{"emoji":"👍","message_id":"parentMessageId"},"context":{"id":"context123"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
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
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Business_Phone_Number__c, SmartMsg__From_Number__c, SmartMsg__Customer_Name__c, SmartMsg__Message_ID__c, SmartMsg__Message_Type__c, SmartMsg__Message_Body__c, SmartMsg__Reaction__c, SmartMsg__Parent_Message_Id__c, SmartMsg__Image_ID__c, SmartMsg__Image_type__c, SmartMsg__Image_SHA256__c, SmartMsg__Video_ID__c, SmartMsg__Video_Type__c, SmartMsg__Video_SHA256__c, SmartMsg__Document_ID__c, SmartMsg__Document_Type__c, SmartMsg__Document_SHA256__c, SmartMsg__Location_Address__c, SmartMsg__Location_Latitude__c, SmartMsg__Location_Longitude__c, SmartMsg__Location_Name__c, SmartMsg__Location_Link__c FROM SmartMsg__Message__c];      
        Assert.areEqual(1, messages.size(), 'Expected one message record to be inserted.');        
        SmartMsg__Message__c message = messages[0];
      	Assert.areEqual('123-456-7890', message.SmartMsg__Business_Phone_Number__c, 'Business phone number should match.');
        //Assert.areEqual('12345', message.SmartMsg__From_Number__c, 'From number should match.');
        Assert.areEqual('John Doe', message.SmartMsg__Customer_Name__c, 'Customer name should match.');
        Assert.areEqual('message123', message.SmartMsg__Message_ID__c, 'Message ID should match.');
        Assert.areEqual('text', message.SmartMsg__Message_Type__c, 'Message type should be text.');
    }*/

	/**
     * @description Test method for verifying POST request with an invalid signature.
     */
    @IsTest
    public static void testDoPostInvalidSignature() {
        String validPayload = '{"entry":[{"id":"TestWhatsAppBusinessId","changes":[{"value":{"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"id":"message123","type":"text","text":{"body":"Hello"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
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
        String validPayload = '{"entry":[{"id":"TestWhatsAppBusinessId","changes":[{"value":{"statuses":[{"id":"12345","status":"sent"}],"contacts":[{"profile":{"name":"John Doe"},"wa_id":"12345"}],"messages":[{"image":{"id":"image123","mime_type":"image/jpeg","sha256":"imageSHA256"}}],"metadata":{"display_phone_number":"123-456-7890"}}}]}]}';
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
        String result = WhatsAppWebhook.getImageUrl('image123');
        Test.stopTest();
        System.assertEquals('ZmFrZUltYWdlRGF0YQ==', result, 'The result string should be matched.');
    }
     /**
     * @description Inner class for mocking HTTP callouts.
     */
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
}