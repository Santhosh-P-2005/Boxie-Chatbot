/**
 * @description Unit tests for TwilioWebhook status callback and message handling.
 */
@isTest
public class TwilioWebhookTest {

    /**
     * @description Creates Twilio configuration custom setting for tests.
     */
    public static void createTwilioConfig() {
        SmartMsg__TwilioConfiguration__c config = new SmartMsg__TwilioConfiguration__c(
            SmartMsg__Account_SID__c = 'ACxxx',
            SmartMsg__Auth_Token__c = 'token',
            SmartMsg__Twilio_Phone_Number__c = '+10000000000',
            SmartMsg__Service_Id__c = 'ZSxxx',
            SmartMsg__Environment_Id__c = 'ZExxx',
            SmartMsg__StatusCallbackUrl__c = 'https://callback.url',
            SmartMsg__MediaBaseUrl__c = 'https://media.url',
            SmartMsg__Messaging_Service_SID__c = 'MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
			SmartMsg__Channel__c = 'SMS'
        );
        insert config;
    }

    /**
     * @description Creates and inserts a sample SMS message record for testing.
     * @param messageId The Twilio message ID to set on the record.
     * @return The inserted SmartMsg__Message__c record.
     */
    public static SmartMsg__Message__c createMessageRecord(String messageId) {
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__Message_Id__c = messageId,
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__channel__c = 'SMS',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert msg;
        return msg;
    }

    @isTest
    public static void testHandleStatusCallback() {
        createTwilioConfig();
        String testMessageId = 'SM1234567890';
        SmartMsg__Message__c msg = createMessageRecord(testMessageId);

        // Mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioStatus/';
        req.httpMethod = 'POST';
        req.addHeader('X-Twilio-Signature', 'dummy_signature');
        req.params.put('MessageSid', testMessageId);
        req.params.put('MessageStatus', 'Delivered');
        req.params.put('ErrorMessage', 'None');
        req.params.put('To', '+1234567890');
        req.params.put('Body', 'Test body');

        Test.startTest();
        RestContext.request = req;
        RestContext.response = res;
        TwilioWebhook.handleStatusCallback();
        Test.stopTest();

        // Assert that the message status is updated
        SmartMsg__Message__c updatedMsg = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertEquals('Delivered', updatedMsg.SmartMsg__Delivery_Status__c,'Delivery status failed');
    }

    @isTest
    public static void handleCallbackTest() {
        createTwilioConfig();
        String testMessageId = 'SM0987654321';
        SmartMsg__Message__c msg = createMessageRecord(testMessageId);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioStatus/';
        req.httpMethod = 'POST';
        req.addHeader('X-Twilio-Signature', 'dummy_signature');
        req.params.put('MessageSid', testMessageId);
        req.params.put('MessageStatus', 'queued');
        req.params.put('To', '+1234567890');
        req.params.put('Body', 'Test body');

        Test.startTest();
        RestContext.request = req;
        RestContext.response = res;
        TwilioWebhook.handleStatusCallback();
        Test.stopTest();

        SmartMsg__Message__c updatedMsg = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertEquals('Sent', updatedMsg.SmartMsg__Delivery_Status__c,'Scheduled SMS failed');
    }

    @isTest
    public static void testHandleIncomingMessage() {
        createTwilioConfig();

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/twilioStatus/';
        req.httpMethod = 'GET';
        req.params.put('From', '1234567890');
        req.params.put('To', '9876543210');
        req.params.put('Body', 'Hello &amp; welcome!');
        req.params.put('MessageSid', 'SMINBOUND123');
        req.params.put('MediaUrl0', 'https://media.example.com/file.jpg');

        Test.startTest();
        RestContext.request = req;
        RestContext.response = res;
        Test.setMock(HttpCalloutMock.class, new TwilioMediaMock());
        TwilioWebhook.handleIncomingMessage();
        Test.stopTest();

        // Assert that the message was created
        SmartMsg__Message__c[] msgs = [SELECT SmartMsg__Message_Body__c, SmartMsg__To_Number__c FROM SmartMsg__Message__c WHERE SmartMsg__Message_Id__c = 'SMINBOUND123'];
        System.assertEquals('Hello & welcome!', msgs[0].SmartMsg__Message_Body__c,'No message body in message');
    }

    @isTest
    public static void testNormalizePhoneNumber() {
        String normalized = TwilioWebhook.normalizePhoneNumber('+1 (234) 567-8901');
        System.assertEquals('2345678901', normalized,'Failed to normalize phone number');

        normalized = TwilioWebhook.normalizePhoneNumber('+91-9876543210');
        System.assertEquals('9876543210', normalized,'Failed to normalize phone number');

        normalized = TwilioWebhook.normalizePhoneNumber('0012345678901');
        System.assertEquals('2345678901', normalized,'Failed to normalize phone number');
    }

    @isTest
    public static void processMediaTest() {
        createTwilioConfig();
        // Create a message record to attach media
        SmartMsg__Message__c msg = createMessageRecord('MEDIA123');

        // Set up HTTP mock
        Test.setMock(HttpCalloutMock.class, new TwilioMediaMock());

        Test.startTest();
        TwilioWebhook.processIncomingMedia(msg.Id, 'https://media.example.com/file.jpg');
        Test.stopTest();

        // Assert that the message record was updated with a media URL (File Id)
        SmartMsg__Message__c msgAfter = [SELECT SmartMsg__Media_Url__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertNotEquals(null, msgAfter.SmartMsg__Media_Url__c,'Media URL was not set');
    }

    // Mock class for HTTP callouts
    private class TwilioMediaMock implements HttpCalloutMock {
        /**
         * @description Responds to an HTTP request.
         * @param req The HTTP request to respond to.
         * @return The HTTP response.
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('media.example.com')) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'image/jpeg');
                res.setBodyAsBlob(Blob.valueOf('fakeimagedata'));
            } else {
                res.setStatusCode(307);
                res.setHeader('Location', 'https://media.example.com/redirected.jpg');
            }
            return res;
        }
    }
}