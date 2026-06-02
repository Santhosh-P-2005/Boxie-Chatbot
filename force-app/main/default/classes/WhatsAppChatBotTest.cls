/**
 * @description Unit tests for WhatsAppChatBot: sendTextMessagePayload, dynamicJSON, messagingSession, nextResponseRecordWhatsAppChatbot, makeCallout.
 */
@isTest
public class WhatsAppChatBotTest {

    /**
     * @description Mock HTTP callout that returns a configurable response for WhatsApp/Twilio API tests.
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        /** @description The response to return for each callout. */
        public HttpResponse mockResponse;
        /**
         * @description Constructs the mock with the given response.
         * @param response The HttpResponse to return from respond().
         */
        public MockHttpResponseGenerator(HttpResponse response) {
            this.mockResponse = response;
        }
        /**
         * @description Returns the configured mock response for any HttpRequest.
         * @param req The HTTP request (ignored).
         * @return The mock HttpResponse set in the constructor.
         */
        public HttpResponse respond(HttpRequest req) {
            return mockResponse;
        }
    }
    private static final String PHONE_1 = '19991';
    private static final String PHONE_2 = '19992';
    private static final String PHONE_3 = '19993';
    private static final String PHONE_4 = '19994';

    /**
     * @description Inserts a Messaging_Session for the given phone number so that nextResponseRecordWhatsAppChatbot
     * does not reset message to 'Hi'. The controller treats session as "not first message" when
     * SmartMsg__No_of_Inbound_Messages__c > 1.
     * @param toNumber Phone number (SmartMsg__To_Number__c) for the session.
     */
    private static void insertMessagingSessionForPhone(String toNumber) {
        SmartMsg__Messaging_Session__c session = new SmartMsg__Messaging_Session__c(
            SmartMsg__To_Number__c = toNumber,
            SmartMsg__Session_status__c = 'Customer Message Received',
            SmartMsg__No_of_Inbound_Messages__c = 2,
            SmartMsg__No_of_Outbound_Messages__c = 0
        );
        insert session;
    }

    /**
     * @description Returns true if any outbound message for the given number has body or dialogue response matching the expected string.
     * @param toNumber Recipient phone number to filter messages.
     * @param expectedResponse Expected message body or dialogue response text.
     * @return True when a matching outbound message is found.
     */
    private static Boolean outboundMessagesContainExpectedResponse(String toNumber, String expectedResponse) {
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__Message_Body__c, SmartMsg__Dialogue__r.SmartMsg__Response__c
            FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c = :toNumber AND SmartMsg__Type__c = 'Outbound'];
        for (SmartMsg__Message__c m : messages) {
            String body = m.SmartMsg__Message_Body__c;
            String dialogueResponse = m.SmartMsg__Dialogue__r != null ? m.SmartMsg__Dialogue__r.SmartMsg__Response__c : null;
            if (expectedResponse != null && (expectedResponse.equals(body) || expectedResponse.equals(dialogueResponse))) {
                return true;
            }
        }
        return false;
    }

    @isTest
    public static void getInitialRecordWithButtons(){
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot(PHONE_1,'Hi','text');
        Test.stopTest();
        List<SmartMsg__Dialogue__c> expectedDialog = [SELECT SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        System.assert(outboundMessagesContainExpectedResponse(PHONE_1, expectedDialog[0].SmartMsg__Response__c), 'Outbound message should contain expected response for PHONE_1');
    }

    /**
     * @description Covers the branch where Messaging_Session exists with No_of_Inbound_Messages__c == 1:
     * any non-empty message is treated as first message and reset to 'Hi', so we get the welcome response.
     */
    @isTest
    public static void testFirstMessageResetWhenSessionHasOneInbound() {
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        SmartMsg__Messaging_Session__c session = new SmartMsg__Messaging_Session__c(
            SmartMsg__To_Number__c = '19996',
            SmartMsg__Session_status__c = 'Customer Message Received',
            SmartMsg__No_of_Inbound_Messages__c = 1,
            SmartMsg__No_of_Outbound_Messages__c = 0
        );
        insert session;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.first"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19996', 'English', 'text');
        Test.stopTest();
        List<SmartMsg__Dialogue__c> hiDialog = [SELECT SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        System.assert(outboundMessagesContainExpectedResponse('19996', hiDialog[0].SmartMsg__Response__c), 'Message should be reset to Hi and return welcome response');
    }
    @isTest
    public static void getTheSecondMessageBasedOnFirstMessage(){
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        List<SmartMsg__Option_Dialog__c> optionDialogForHi = [SELECT Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'Hi' AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c = 'English' LIMIT 1];
        
        SmartMsg__Message__c messageRecord = new SmartMsg__Message__c();
        messageRecord.SmartMsg__Type__c = 'Outbound';
        messageRecord.SmartMsg__To_Number__c = PHONE_2;
        messageRecord.SmartMsg__Dialogue__c = dialogList[0].Id;
        messageRecord.SmartMsg__Option_Dialog__c = optionDialogForHi[0].Id;
        insert messageRecord;

        insertMessagingSessionForPhone(PHONE_2);
        
        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot(PHONE_2,'English','button_reply');
        Test.stopTest();
        List<SmartMsg__Option_Dialog__c> lastDeliveredDialog = [SELECT SmartMsg__Outbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'Hi' AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c = 'English' LIMIT 1];
        List<SmartMsg__Option_Dialog__c> expectedOptionDialog = [SELECT SmartMsg__Inbound_Response__r.SmartMsg__Response__c FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.Id = :lastDeliveredDialog[0].SmartMsg__Outbound_Response__r.Id ORDER BY CreatedDate LIMIT 1];
        System.assert(outboundMessagesContainExpectedResponse(PHONE_2, expectedOptionDialog[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c), 'Outbound message should contain expected response for PHONE_2');
    }
    @isTest
    public static void sendTextMessages(){
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Existing Customer' LIMIT 1];
        SmartMsg__Message__c messageRecord = new SmartMsg__Message__c();
        messageRecord.SmartMsg__Type__c = 'Outbound';
        messageRecord.SmartMsg__To_Number__c = PHONE_3;
        messageRecord.SmartMsg__Dialogue__c = dialogList[0].Id;
        insert messageRecord;

        insertMessagingSessionForPhone(PHONE_3);
        
        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot(PHONE_3,'Followup pickup','text');
        Test.stopTest();
        List<SmartMsg__Option_Dialog__c> optionDialog = [SELECT SmartMsg__Outbound_Response__r.SmartMsg__Response__c FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'Existing Customer' AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c = 'Followup pickup' LIMIT 1];
        System.assert(outboundMessagesContainExpectedResponse(PHONE_3, optionDialog[0].SmartMsg__Outbound_Response__r.SmartMsg__Response__c), 'Outbound message should contain expected response for PHONE_3');
    }
    @isTest
    public static void sendOrderMessages(){
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;	
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'English' LIMIT 1];
        List<SmartMsg__Option_Dialog__c> optionDialogForEnglish = [SELECT Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'English' AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c = 'New Customer' LIMIT 1];
        SmartMsg__Message__c messageRecord = new SmartMsg__Message__c();
        messageRecord.SmartMsg__Type__c = 'Outbound';
        messageRecord.SmartMsg__To_Number__c = PHONE_4;
        messageRecord.SmartMsg__Dialogue__c = dialogList[0].Id;
        messageRecord.SmartMsg__Option_Dialog__c = optionDialogForEnglish[0].Id;
        insert messageRecord;

        insertMessagingSessionForPhone(PHONE_4);
        
        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot(PHONE_4,'New Customer','list_reply');
        Test.stopTest();
        List<SmartMsg__Option_Dialog__c> optionDialog = [SELECT SmartMsg__Inbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'New Customer' AND SmartMsg__Order_Number__c = 1 LIMIT 1];
        List<SmartMsg__Dialogue__c> expectedDialog = [SELECT SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Parent_Record__c = :optionDialog[0].SmartMsg__Inbound_Response__r.Id AND SmartMsg__Order_Number__c = 1 LIMIT 1];
        System.assert(outboundMessagesContainExpectedResponse(PHONE_4, expectedDialog[0].SmartMsg__Response__c), 'Outbound message should contain expected response for PHONE_4');
    }

    /**
     * @description Covers sendTextMessagePayload, dynamicJSON, messagingSession: asserts non-null payloads and session creation.
     */
    @isTest
    public static void testPayloadDynamicJSONMessagingSession() {
        HttpResponse ok = new HttpResponse();
        ok.setStatusCode(200);
        ok.setBody('{"messages":[{"id":"wamid.x"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(ok));
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        insert TestObjectFactory.metaConfigurations();
        Test.startTest();
        System.assert(WhatsAppChatBot.sendTextMessagePayload('Hello', '15551234567') != null, 'sendTextMessagePayload should return non-null');
        System.assert(WhatsAppChatBot.dynamicJSON('Choose one', new List<String>{ 'Yes', 'No' }, 'button', '1') != null, 'dynamicJSON button should return non-null');
        System.assert(WhatsAppChatBot.dynamicJSON('Reply', new List<String>{ 'A', null }, 'Separate Button', '1') != null, 'dynamicJSON Separate Button should return non-null');
        System.assert(WhatsAppChatBot.dynamicJSON('Pick', new List<String>{ 'Opt - Desc', 'Long option text over twenty four chars' }, 'option', '1') != null, 'dynamicJSON option should return non-null');
        System.assert(WhatsAppChatBot.dynamicJSON('Body', new List<String>{ 'OnlyTitle' }, 'option', '1') != null, 'dynamicJSON option single should return non-null');
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19995', 'Hi', 'text');
        Test.stopTest();
        System.assert(WhatsAppChatBot.messagingSession('9995', null) != null, 'messagingSession should return non-null');
    }

    @isTest
    public static void testMakeCalloutTwilio() {
        insert TestObjectFactory.twilioWhatsAppSettings();
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        System.assert(WhatsAppChatBot.makeCallout('15559999', 'Test body', null) == null, 'makeCallout should return null when no settings');
        Test.stopTest();
    }

    /**
     * @description Covers optionDialogList empty then exact match: when Inbound=dialog8 has no options, exact match query returns option dialog7->dialog8 and sends follow-up message.
     */
    /*@isTest
    public static void testOptionDialogListEmptyThenExactMatch() {
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        insert TestObjectFactory.metaConfigurations();
        List<SmartMsg__Dialogue__c> dialog8List = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Type__c = 'Separate Button' LIMIT 1];
        if (!dialog8List.isEmpty()) {
            dialog8List[0].SmartMsg__Question__c = 'Anything else';
            update dialog8List;
        }
        List<SmartMsg__Dialogue__c> dialog7List = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Order_Number__c = 3 AND SmartMsg__Parent_Record__c != null LIMIT 1];
        SmartMsg__Message__c msg = new SmartMsg__Message__c();
        msg.SmartMsg__Type__c = 'Outbound';
        msg.SmartMsg__To_Number__c = '19990';
        msg.SmartMsg__Dialogue__c = dialog7List[0].Id;
        insert msg;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.a90"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19990', 'Anything else', 'text');
        Test.stopTest();
        System.assert(outboundMessagesContainExpectedResponse('19990', 'Is there anything else I can help you with?'), 'Outbound should contain follow-up message');
    }*/

    /**
     * @description Covers lastDeliveredDialogList empty (invalid option) and Option_Dialog Order_Number consecutive path; expects storage size question.
     */
    @isTest
    public static void testConsecutiveOrderInvalidOption() {
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        insert TestObjectFactory.metaConfigurations();
        List<SmartMsg__Dialogue__c> dialog4List = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'New Customer' LIMIT 1];
        List<SmartMsg__Option_Dialog__c> optOrder1 = [SELECT Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'New Customer' AND SmartMsg__Order_Number__c = 1 LIMIT 1];
        SmartMsg__Message__c msg = new SmartMsg__Message__c();
        msg.SmartMsg__Type__c = 'Outbound';
        msg.SmartMsg__To_Number__c = '19993';
        msg.SmartMsg__Dialogue__c = dialog4List[0].Id;
        msg.SmartMsg__Option_Dialog__c = optOrder1[0].Id;
        insert msg;

        insertMessagingSessionForPhone('19993');
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.invalid"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19993', 'Invalid', 'text');
        Test.stopTest();
        System.assert(outboundMessagesContainExpectedResponse('19993', 'What Storage size do you need?'), 'Outbound should contain storage size question');
    }

    @isTest
    public static void testNextResponseButtonReplyYes() {
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        insert TestObjectFactory.metaConfigurations();
        List<SmartMsg__Dialogue__c> hiDialog = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        List<SmartMsg__Option_Dialog__c> hiToEnglish = [SELECT Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'Hi' AND SmartMsg__Outbound_Response__r.SmartMsg__Question__c = 'English' LIMIT 1];
        SmartMsg__Message__c msgYes = new SmartMsg__Message__c();
        msgYes.SmartMsg__Type__c = 'Outbound';
        msgYes.SmartMsg__To_Number__c = '19997';
        msgYes.SmartMsg__Dialogue__c = hiDialog[0].Id;
        msgYes.SmartMsg__Option_Dialog__c = hiToEnglish[0].Id;
        insert msgYes;

        insertMessagingSessionForPhone('19997');
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19997', 'Yes', 'button_reply');
        Test.stopTest();
        System.assert(outboundMessagesContainExpectedResponse('19997', 'How Can I help you.Choose the options'), 'Outbound should contain options message');
    }

    /**
     * @description Covers optionDialog with null Outbound_Response (dialog12): sends end-of-flow text (e.g. thank you message).
     */
    @isTest
    public static void testNextResponseNoTextEndOption() {
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        insert TestObjectFactory.metaConfigurations();
        List<SmartMsg__Option_Dialog__c> noOption = [SELECT Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'No, that\'s all.' LIMIT 1];
        noOption[0].SmartMsg__Order_Number__c = 1;
        update noOption;
        List<SmartMsg__Dialogue__c> dialog12List = [SELECT Id, SmartMsg__Parent_Template__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'No, that\'s all.' LIMIT 1];
        SmartMsg__Dialogue__c child = new SmartMsg__Dialogue__c(
            SmartMsg__Parent_Record__c = dialog12List[0].Id,
            SmartMsg__Response__c = 'Thank you for contacting us',
            SmartMsg__Parent_Template__c = dialog12List[0].SmartMsg__Parent_Template__c,
            SmartMsg__Order_Number__c = 1,
            SmartMsg__Type__c = 'Separate Text'
        );
        insert child;

        insertMessagingSessionForPhone('19999');
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.no"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19999', 'No, that\'s all.', 'text');
        Test.stopTest();
        System.assert(outboundMessagesContainExpectedResponse('19999', 'Thank you for contacting us'), 'Outbound should contain thank you message');
    }

    @isTest
    public static void testNextResponseButtonReplyNo() {
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        insert TestObjectFactory.metaConfigurations();
        List<SmartMsg__Dialogue__c> dialog8 = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Type__c = 'Separate Button' LIMIT 1];
        SmartMsg__Message__c msgNo = new SmartMsg__Message__c();
        msgNo.SmartMsg__Type__c = 'Outbound';
        msgNo.SmartMsg__To_Number__c = '19998';
        msgNo.SmartMsg__Dialogue__c = dialog8[0].Id;
        insert msgNo;

        insertMessagingSessionForPhone('19998');
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.test"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        Test.startTest();
        WhatsAppChatBot.nextResponseRecordWhatsAppChatbot('19998', 'No, that\'s all.', 'button_reply');
        Test.stopTest();
        System.assertEquals(true, WhatsAppChatBot.sessionEndFlag, 'sessionEndFlag should be true after No button reply');
    }
}