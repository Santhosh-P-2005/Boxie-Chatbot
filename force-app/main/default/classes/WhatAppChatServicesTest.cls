/**
* @description Test class for the WhatAppChatServices class. 
*              This class contains unit tests to verify the functionality 
*              of the methods in the WhatAppChatServices class.
*/
@isTest
public class WhatAppChatServicesTest {
    /**
* @description MockHttpResponseGenerator class implements the HttpCalloutMock interface 
*              to generate a mock HTTP response for testing HTTP callouts.
*/
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private HttpResponse mockResponse;
        /**
* @description Constructs a MockHttpResponseGenerator object with the specified HTTP response.
* @param response The HttpResponse object representing the mock response to be returned.
*/
        public MockHttpResponseGenerator(HttpResponse response) {
            this.mockResponse = response;
        }
        /**
* @description Handles the HTTP request by returning the mock response provided during object instantiation.
* @param req The HttpRequest object representing the incoming request (not used in this implementation).
* @return The HttpResponse object representing the mock response provided during object instantiation.
*/
        public HttpResponse respond(HttpRequest req) {
            return mockResponse;
        }
    }    
    /**
* @description Test setup method to insert necessary data before running test methods in the WhatAppChatServices

Test class.
*/
    @testSetup
    public static void setup() {
        SmartMsg__Message_Template__c template = new SmartMsg__Message_Template__c(
            SmartMsg__Template_API_Name__c = 'hello_world',
            SmartMsg__Template_Name__c = 'Hello World Template',
            SmartMsg__Header__c = 'Media',
            SmartMsg__Body__c = 'Hello, this is a template message',
            SmartMsg__Footer__c = 'Footer Text',
            SmartMsg__Button__c = '[{"type":"QUICK_REPLY","text":"Yes"}]'
        );
        insert template;
        SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getOrgDefaults();
        metaSetting.SmartMsg__Application_Id__c = 'TestApplicationId';
        //metaSetting.App_Secret_key__c = 'TestSecretKey';
        metaSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        metaSetting.SmartMsg__Phone_Number_Id__c = 'TestPhoneNumberId';
        metaSetting.SmartMsg__WhatsApp_Business_Id__c = 'TestWhatsAppBusinessId';
        metaSetting.SmartMsg__Service_Provider_Name__c = 'Meta';
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Active__c = false;
        
        insert metaSetting;
    }
    /**
* @description Test method to verify the functionality of sending a text message using WhatsApp.
*/
    @isTest
    public static void testSendTextMessage() {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        SmartMsg__Message__c message = WhatAppChatServices.sendTextMessage('Hello, this is a test message', '1234567890');
        Test.stopTest();
        Assert.areNotEqual(null, message, 'Message should not be null.');
        Assert.areEqual('Hello, this is a test message', message.SmartMsg__Message_Body__c, 'Message body should match.');
        Assert.areEqual('+1234567890', message.SmartMsg__To_Number__c, 'Recipient number should match.');
        Assert.areEqual('wamid.HBgLNTEyMzQ1Njc4OTA', message.SmartMsg__Message_ID__c, 'Message ID should match.');
        Assert.areEqual('text', message.SmartMsg__Message_Type__c, 'Message type should be text.');
        Assert.areEqual('Outbound', message.SmartMsg__Type__c, 'Message direction should be outbound.');
        Assert.areEqual('WhatsApp', message.SmartMsg__Channel__c, 'Channel should be WhatsApp.');
        Assert.areEqual('Sent', message.SmartMsg__Delivery_Status__c, 'Delivery status should be Sent.');
        Assert.areEqual(true, message.SmartMsg__Outgoing__c, 'Message should be outgoing.');
    }
    /**
* @description Test method to verify the functionality of sending a template message using WhatsApp.
*/
    @isTest
    public static void testSendTemplateMessage() {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"contacts":[{"input":"1234567890","wa_id":"1234567890"}],"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        String payload = '{'+
            '"messaging_product": "whatsapp",'+
            '"recipient_type": "individual",'+
            '"to": "1234567890",'+
            '"type": "template",'+
            '"template": {'+
            '"name": "hello_world",'+
            '"language": {"code": "en"},'+
            '"components": []'+
            '}'+
            '}';
        Test.startTest();
        SmartMsg__Message__c message = WhatAppChatServices.sendTemplateMessage(payload, 'Template Message Body');
        Test.stopTest();
        Assert.areNotEqual(null, message, 'Message should not be null.');
        Assert.areEqual('Template Message Body', message.SmartMsg__Message_Body__c, 'Message body should match.');
        Assert.areEqual('1234567890', message.SmartMsg__To_Number__c, 'Recipient number should match.');
        Assert.areEqual('wamid.HBgLNTEyMzQ1Njc4OTA', message.SmartMsg__Message_ID__c, 'Message ID should match.');
        Assert.areEqual('template', message.SmartMsg__Message_Type__c, 'Message type should be template.');
        Assert.areEqual('Outbound', message.SmartMsg__Type__c, 'Message direction should be outbound.');
        Assert.areEqual('WhatsApp', message.SmartMsg__Channel__c, 'Channel should be WhatsApp.');
        Assert.areEqual('Sent', message.SmartMsg__Delivery_Status__c, 'Delivery status should be Sent.');
        Assert.areEqual(true, message.SmartMsg__Outgoing__c, 'Message should be outgoing.');
    }
    /**
* @description Test method to verify the functionality of constructing a payload for a WhatsApp message.
*/
    @isTest
    public static void testConstructPayload() {
        
        Account acc = new Account();
        acc.Name = 'Test Account';
        insert acc;
        
        SmartMsg__Message_Template__c template = new SmartMsg__Message_Template__c(
            SmartMsg__Template_API_Name__c = 'hello_world',
            SmartMsg__Template_Name__c = 'Hello World Template',
            SmartMsg__Header__c = 'Media',
            SmartMsg__Body__c = 'Hello {!name}, this is a template message',
            SmartMsg__Footer__c = 'Footer Text',
            SmartMsg__Button__c = '[{"type":"QUICK_REPLY","text":"Yes"}]'
        );
        insert template;
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"contacts":[{"input":"1234567890","wa_id":"1234567890"}],"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        SmartMsg__Message__c message = WhatAppChatServices.constructPayload(acc.Id,template.Id, '1234567890', 'https://example.com/image.jpg','');
        Test.stopTest();
        Assert.areNotEqual(null, message, 'Message should not be null.');
        Assert.areEqual('1234567890', message.SmartMsg__To_Number__c, 'Recipient number should match.');
        Assert.areEqual('wamid.HBgLNTEyMzQ1Njc4OTA', message.SmartMsg__Message_ID__c, 'Message ID should match.');
        Assert.areEqual('template', message.SmartMsg__Message_Type__c, 'Message type should be template.');
        Assert.areEqual('Outbound', message.SmartMsg__Type__c, 'Message direction should be outbound.');
        Assert.areEqual('WhatsApp', message.SmartMsg__Channel__c, 'Channel should be WhatsApp.');
        Assert.areEqual('Sent', message.SmartMsg__Delivery_Status__c, 'Delivery status should be Sent.');
        Assert.areEqual(true, message.SmartMsg__Outgoing__c, 'Message should be outgoing.');
    }
    
    @isTest
    public static void sendMediaMessageTest(){
        List<SmartMsg__Message__c> messageList = TestObjectFactory.createMessageRecords(1);
        insert messageList;
        Test.startTest();
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"contacts":[{"input":"1234567890","wa_id":"1234567890"}],"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        SmartMsg__Message__c updatedMessageRecord = WhatAppChatServices.sendMediaMessage(messageList[0].Id,'image','http://example.com/image.jpg','91987654321','Test caption','Test image');
        Test.stopTest();
        System.assertEquals('Sent',updatedMessageRecord.SmartMsg__Delivery_Status__c,'Delivery status should be Sent.');
    }
    
    @isTest
    public static void sendMediaMessageNegativeTest(){
        List<SmartMsg__Message__c> messageList = TestObjectFactory.createMessageRecords(1);
        insert messageList;
        Test.startTest();
        HttpResponse res = new HttpResponse();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        SmartMsg__Message__c updatedMessageRecord = WhatAppChatServices.sendMediaMessage(messageList[0].Id,'image','http://example.com/image.jpg','91987654321','Test caption','Test image');
        Test.stopTest();
        System.assertEquals('Failed',updatedMessageRecord.SmartMsg__Delivery_Status__c,'Delivery status should be Sent.');
    }
    
    @isTest
    public static void sendLocationRequestMessageTest(){
        List<SmartMsg__Message__c> messageList = TestObjectFactory.createMessageRecords(1);
        insert messageList;
        Test.startTest();
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"contacts":[{"input":"1234567890","wa_id":"1234567890"}],"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        SmartMsg__Message__c updatedMessageRecord = WhatAppChatServices.sendLocationRequestMessage('91987654321',messageList[0].Id,'Test MessageBody');
        Test.stopTest();
        System.assertEquals('location-request',updatedMessageRecord.SmartMsg__Message_Type__c,'Delivery status should be Sent.');
    }
    
    /* @isTest
    public static void sendLocationRequestMessageNegativeTest(){
        List<SmartMsg__Message__c> messageList = TestObjectFactory.createMessageRecords(1);
        insert messageList;
        Test.startTest();
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"contacts":[{"input":"1234567890","wa_id":"1234567890"}],"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        SmartMsg__Message__c updatedMessageRecord = WhatAppChatServices.sendLocationRequestMessage('91987654321',messageList[0].Id,'Test MessageBody');
        Test.stopTest();
        System.assertEquals('Failed',updatedMessageRecord.SmartMsg__Delivery_Status__c,'Delivery status should be Sent.');
    }*/
    
    @isTest
    public static void sendTypingIndicatorTest(){
        List<SmartMsg__Message__c> messageList = TestObjectFactory.createMessageRecords(1);
        insert messageList;
        Test.startTest();
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        WhatAppChatServices.sendTypingIndicator('91987654321',messageList[0].Id);
        Test.stopTest();
        System.assert(true, 'sendTypingIndicator should complete without exception');
    }
}