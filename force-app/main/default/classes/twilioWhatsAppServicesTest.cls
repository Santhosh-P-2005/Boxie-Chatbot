/**
 * @description Test class for twilioWhatsAppServices.
 *
 * This test class verifies the functionality of the twilioWhatsAppServices methods,
 * including sending text messages via WhatsApp and verifying message record creation.
 */
@isTest
public class twilioWhatsAppServicesTest {

    /**
     * @description Mock class for HTTP callout responses.
     */
    private class TwilioHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        /**
         * @description Constructs the mock with the given status code and response body.
         * @param code HTTP status code to return.
         * @param bodyStr Response body string.
         */
        TwilioHttpMock(Integer code, String bodyStr) {
            statusCode = code;
            body = bodyStr;
        }

        /**
         * @description Responds to an HTTP request with the configured status code and body.
         * @param req The HTTP request (ignored).
         * @return HttpResponse with the mock status code and body.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /**
     * @description Helper method to create Twilio message response JSON.
     * @param sid The message SID.
     * @param toNumber The recipient phone number.
     * @param fromNumber The sender phone number.
     * @param body The message body.
     * @return String The JSON response string.
     */
    private static String getTwilioMessageResponse(String sid, String toNumber, String fromNumber, String body) {
        return '{"account_sid":"ACTestAccountSID123","api_version":"2010-04-01","body":"' +
               body + '","date_created":"Mon, 01 Jan 2024 12:00:00 +0000","date_sent":null,"date_updated":"Mon, 01 Jan 2024 12:00:00 +0000",' +
               '"direction":"outbound-api","error_code":null,"error_message":null,"from":"whatsapp:' + fromNumber + '",' +
               '"messaging_service_sid":null,"num_media":"0","num_segments":"1","price":null,"price_unit":null,"sid":"' + sid + '",' +
               '"status":"queued","subresource_uris":{"media":"/2010-04-01/Accounts/ACTestAccountSID123/Messages/' + sid + '/Media.json"},' +
               '"to":"whatsapp:' + toNumber + '","uri":"/2010-04-01/Accounts/ACTestAccountSID123/Messages/' + sid + '.json"}';
    }

    /**
     * @description Tests the sendTextMessage method with successful HTTP response.
     *              Verifies that the message record is created correctly with all required fields.
     * @isTest
     */
    @isTest
    static void testSendTextMessage() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;

        String toPhone = '+1234567890';
        String fromPhone = '+1234567890';
        String messageContent = 'Test message content';
        String messageSid = 'SMTestMessageSID123';

        List<SmartMsg__Message__c> previousMessages = TestObjectFactory.createMessageRecords(1);
        previousMessages[0].SmartMsg__To_Number__c = toPhone;
        previousMessages[0].SmartMsg__From_Number__c = fromPhone;
        previousMessages[0].SmartMsg__Channel__c = 'WhatsApp';
        previousMessages[0].SmartMsg__Type__c = 'Inbound';
        insert previousMessages;

        String mockResponse = getTwilioMessageResponse(messageSid, toPhone, fromPhone, messageContent);
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201, mockResponse));

        Test.startTest();
        SmartMsg__Message__c result = twilioWhatsAppServices.sendTextMessage(messageContent, toPhone);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Message record should be created');
        System.assertEquals(toPhone, result.SmartMsg__To_Number__c, 'To number should match');
        System.assertEquals(fromPhone, result.SmartMsg__From_Number__c, 'From number should match');
        System.assertEquals(messageContent, result.SmartMsg__Message_Body__c, 'Message body should match');
        System.assertEquals('sent', result.SmartMsg__Delivery_Status__c, 'Delivery status should be sent');
        System.assertEquals('text', result.SmartMsg__Message_Type__c, 'Message type should be text');
        System.assertEquals('WhatsApp', result.SmartMsg__Channel__c, 'Channel should be Twilio WhatsApp');
        System.assertEquals('Outbound', result.SmartMsg__Type__c, 'Type should be Outbound');
        System.assertEquals(messageSid, result.SmartMsg__Message_ID__c, 'Message ID should match');
        System.assertNotEquals(null, result.SmartMsg__Sent_Date_and_Time__c, 'Sent date and time should be set');
    }

    /**
     * @description Tests sendMediaMessage for an existing Message__c record via Twilio WhatsApp.
     */
    @isTest
    static void testSendMediaMessage() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;

        SmartMsg__Message__c existing = TestObjectFactory.createMessageRecords(1)[0];
        existing.SmartMsg__To_Number__c = '+1234567890';
        existing.SmartMsg__Message_Body__c = 'Media caption';
        existing.SmartMsg__Type__c = 'Outbound';
        existing.SmartMsg__Media_Url__c = '069XXXXXXXXXXXX';
        existing.SmartMsg__File_Name__c = 'photo.jpg';
        insert existing;

        String toPhone = '+1234567890';
        String fromPhone = '+1234567890';
        String messageSid = 'SMTestMediaSID123';
        String mockResponse = getTwilioMessageResponse(messageSid, toPhone, fromPhone, 'Media caption');
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201, mockResponse));

        Test.startTest();
        SmartMsg__Message__c result = TwilioWhatsAppServices.sendMediaMessage(
            existing.Id,
            'https://example.com/photo.jpg',
            toPhone,
            'Media caption',
            fromPhone
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Updated message should be returned');
        System.assertEquals('Sent', result.SmartMsg__Delivery_Status__c, 'Delivery status should be Sent');
        System.assertEquals('photo.jpg', result.SmartMsg__File_Name__c, 'File name should remain on record');
    }
}