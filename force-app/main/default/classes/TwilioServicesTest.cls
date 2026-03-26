/**
 * @description Test class for the TwilioServices class.
 *              This class contains unit tests to verify the functionality
 *              of the methods in the TwilioServices class.
 */
@isTest
public class TwilioServicesTest {

    /**
     * @description Builds and upserts Twilio org default so sendSMS/scheduleSMS can run. Call at start of each test to avoid MIXED_DML_OPERATION.
     */
    public static void setupTwilioConfig() {
        SmartMsg__TwilioConfiguration__c twilioSetting = SmartMsg__TwilioConfiguration__c.getOrgDefaults();
        if (twilioSetting == null) {
            twilioSetting = new SmartMsg__TwilioConfiguration__c();
        }
        twilioSetting.SmartMsg__Account_SID__c = 'TestAccountSID';
        twilioSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        twilioSetting.SmartMsg__Channel__c = 'SMS';
        twilioSetting.SmartMsg__Messaging_Service_SID__c = 'TestMessagingServiceSID';
        twilioSetting.SmartMsg__Service_Provider_Name__c = 'Twilio';
        twilioSetting.SmartMsg__Twilio_Phone_Number__c = '1234567890';
        twilioSetting.SmartMsg__Active__c = false;
        twilioSetting.SmartMsg__StatusCallbackUrl__c = 'https://example.com/callback';
        twilioSetting.SmartMsg__MediaBaseUrl__c = 'https://example.com/media';
        twilioSetting.SmartMsg__Environment_Id__c = 'env1';
        twilioSetting.SmartMsg__Service_Id__c = 'svc1';
        upsert twilioSetting;
    }
	/**
     * @description Test method to verify the sendSMS functionality.
     */
    @isTest
    public static void testSendSMS() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", "to": "+1234567890", "status": "queued", "body": "Test SMS Body"}');
        res.setStatusCode(201);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+1234567890', 'Test SMS Body');
        Test.stopTest();
        Assert.areNotEqual(null, resultId, 'Result ID should not be null.');
        SmartMsg__Message__c updatedMessage = [SELECT Id, SmartMsg__Message_ID__c, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :resultId];
        Assert.areEqual('SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', updatedMessage.SmartMsg__Message_ID__c, 'Message ID should match.');
        Assert.areEqual('Sent', updatedMessage.SmartMsg__Delivery_Status__c, 'Delivery status should be Sent until status callback updates to Delivered.');
    }

    @isTest
    public static void testSendSMS_withMergeFieldsInBody() {
        setupTwilioConfig();
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY", "to": "+1234567890", "status": "queued", "body": "Hi Test Account"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.sendSMS(acc.Id, '+1234567890', 'Hello {!Name}');
        Test.stopTest();
        Assert.areNotEqual(null, resultId, 'Result ID should not be null when merge field in body.');
    }

    @isTest
    public static void testSendSMS_errorResponseReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"code": 21211, "message": "Invalid To phone number", "moreInfo": "https://www.twilio.com/docs/errors/21211", "status": 400}');
        res.setStatusCode(400);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+1234567890', 'Test body');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null on Twilio error response.');
    }

    @isTest
    public static void testSendSMS_201NoMatchingMessageReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ", "to": "+9999999999", "status": "queued", "body": "Test"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+9999999999', 'Test SMS');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null when no matching message record to update.');
    }

    @isTest
    public static void testSendSMS_201NoSentMessageRecordReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "to": "+1234567890", "status": "queued", "body": "Test"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        // Do not insert any message with Delivery_Status__c = 'Sent' - query returns empty

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+1234567890', 'Test SMS');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null when no Sent message record exists.');
    }

  	/**
     * @description Test method to verify the scheduleSMS functionality.
     */
    @isTest
    public static void testScheduleSMS() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", "to": "+1234567890", "status": "Scheduled", "body": "Scheduled SMS Body"}');
        res.setStatusCode(201);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS('', '+1234567890', 'Scheduled SMS Body', '2024-05-22T14:00:00Z');
        Test.stopTest();

        Assert.areNotEqual(null, resultId, 'Result ID should not be null.');
        SmartMsg__Message__c updatedMessage = [SELECT Id, SmartMsg__Message_ID__c, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :resultId];
        Assert.areEqual('SMXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', updatedMessage.SmartMsg__Message_ID__c, 'Message ID should match.');
        Assert.areEqual('Scheduled', updatedMessage.SmartMsg__Delivery_Status__c, 'Delivery status should be Scheduled.');
    }

    @isTest
    public static void testScheduleSMS_withMergeFieldsInBody() {
        setupTwilioConfig();
        Account acc = new Account(Name = 'Schedule Account');
        insert acc;

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", "to": "+1234567890", "status": "Scheduled", "body": "Scheduled"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS(acc.Id, '+1234567890', 'Hi {!Name}', '2024-06-01T12:00:00Z');
        Test.stopTest();
        Assert.areNotEqual(null, resultId, 'Result ID should not be null.');
    }

    /*@isTest
    public static void testScheduleSMS_errorResponseReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"code": 21608, "message": "Invalid SendAt time", "status": 400}');
        res.setStatusCode(400);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS('', '+1234567890', 'Body', '2024-05-22T14:00:00Z');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null on schedule error response.');
    }*/

    @isTest
    public static void testScheduleSMS_201NoMatchingRecordReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", "to": "+9876543210", "status": "Scheduled", "body": "Scheduled"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS('', '+9876543210', 'Scheduled body', '2024-06-15T10:00:00Z');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null when no matching scheduled record.');
    }

    @isTest
    public static void testScheduleSMS_201NoScheduledRecordReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD", "to": "+1234567890", "status": "Scheduled", "body": "Scheduled"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        // No message with Delivery_Status__c = 'Scheduled' inserted

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS('', '+1234567890', 'Scheduled body', '2024-06-15T10:00:00Z');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null when no Scheduled message record exists.');
    }

    @isTest
    public static void testSendSMS_bodyWithBackslash() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE", "to": "+1234567890", "status": "queued", "body": "Test"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+1234567890', 'Test \\ backslash');
        Test.stopTest();
        Assert.areNotEqual(null, resultId, 'Result ID should not be null.');
    }

    /**
     * @description Covers sendSMS when response is 201 but status is not "queued" - no record updated, return null.
     */
    @isTest
    public static void testSendSMS_201StatusNotQueuedReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMSTATUSNOTQUEUED", "to": "+1234567890", "status": "sent", "body": "Test"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+1234567890', 'Test SMS');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null when status is not queued.');
    }

    /**
     * @description Covers scheduleSMS body with newline (replace \\n path).
     */
    @isTest
    public static void testScheduleSMS_bodyWithNewline() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMNEWLINE", "to": "+1234567890", "status": "Scheduled", "body": "Line1\\nLine2"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS('', '+1234567890', 'Line1\nLine2', '2024-07-01T12:00:00Z');
        Test.stopTest();
        Assert.areNotEqual(null, resultId, 'Result ID should not be null.');
    }

    /**
     * @description Covers scheduleSMS when response is 201 but status is not "Scheduled" - no record updated.
     */
    @isTest
    public static void testScheduleSMS_201StatusNotScheduledReturnsNull() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMSTATUSNOTSCHED", "to": "+1234567890", "status": "queued", "body": "Scheduled"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.scheduleSMS('', '+1234567890', 'Body', '2024-07-01T12:00:00Z');
        Test.stopTest();
        Assert.areEqual(null, resultId, 'Should return null when status is not Scheduled.');
    }

    /**
     * @description Covers sendSMS with body that has no merge fields (contains('{') false).
     */
    @isTest
    public static void testSendSMS_noMergeFieldsInBody() {
        setupTwilioConfig();
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"sid": "SMNOMERGE", "to": "+1234567890", "status": "queued", "body": "Plain text"}');
        res.setStatusCode(201);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        SmartMsg__Message__c message = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Delivery_Status__c = 'Sent'
        );
        insert message;

        Test.startTest();
        Id resultId = TwilioServices.sendSMS('', '+1234567890', 'Plain text only');
        Test.stopTest();
        Assert.areNotEqual(null, resultId, 'Result ID should not be null.');
    }

    /**
     * @description MockHttpResponseGenerator class to generate mock HTTP responses.
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
}