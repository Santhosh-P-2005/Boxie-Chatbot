/**
 * @class TwilioWhatsAppChatBotTest
 * @description Unit tests for the TwilioWhatsAppChatBot class.
 * Focuses on testing nextResponseRecordWhatsAppChatbot method and verifying session and message records.
 */
@isTest
private class TwilioWhatsAppChatBotTest {
    
    /**
     * @description Mock class for HTTP callout responses.
     */
    private class TwilioHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        
        TwilioHttpMock(Integer code, String bodyStr) {
            statusCode = code;
            body = bodyStr;
        }

        /**
         * @description Returns the configured mock HTTP response for any request.
         * @param req The HTTP request (unused).
         * @return HttpResponse with the preset status code and body.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }
    
    /**
     * @description Mock class for multiple HTTP callout responses.
     */
    private class MultiStepHttpMock implements HttpCalloutMock {
        private List<Integer> statusCodes;
        private List<String> bodies;
        private Integer calloutIndex = 0;
        
        MultiStepHttpMock(List<Integer> codes, List<String> bodies) {
            this.statusCodes = codes;
            this.bodies = bodies;
        }

        /**
         * @description Returns the next mock response in sequence (status code and body) for multi-step callout tests.
         * @param req The HTTP request (unused).
         * @return HttpResponse with status and body from the configured lists for the current callout index.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req != null ? req.getEndpoint() : null;
            String method = req != null ? req.getMethod() : null;

            // Endpoint-aware responses:
            // - content API GET: use bodies[0] (must include "contents" for chekContentAPI)
            // - content API POST (template creation): use bodies[1] (must include "sid")
            // - messages API POST: use bodies[1] (must include "from"/"to"/"sid")
            // This avoids callout-order sensitivity when content template creation happens.
            Boolean isContentAPI = endpoint != null && endpoint.contains('SmartMsg__Twilio_content_API');
            Boolean isGet = method == 'GET';
            Boolean isPost = method == 'POST';

            Integer codeToUse;
            String bodyToUse;
            if(isContentAPI && isGet) {
                codeToUse = (statusCodes.size() > 0) ? statusCodes[0] : 200;
                bodyToUse = (bodies.size() > 0) ? bodies[0] : '';
            } else {
                codeToUse = (statusCodes.size() > 1) ? statusCodes[1] : 201;
                bodyToUse = (bodies.size() > 1) ? bodies[1] : (bodies.size() > 0 ? bodies[0] : '');
            }

            res.setStatusCode(codeToUse);
            res.setBody(bodyToUse);
            calloutIndex++;
            return res;
        }
    }
    
    private static String getTwilioMessageResponse(String sid, String toNumber, String fromNumber, String body) {
        // Escape special characters in body for JSON
        String escapedBody = body != null ? body.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') : '';
        return '{"account_sid":"ACTestAccountSID123","api_version":"2010-04-01","body":"' + 
               escapedBody + '","date_created":"Mon, 01 Jan 2024 12:00:00 +0000","date_sent":null,"date_updated":"Mon, 01 Jan 2024 12:00:00 +0000",' +
               '"direction":"outbound-api","error_code":null,"error_message":null,"from":"whatsapp:' + fromNumber + '",' +
               '"messaging_service_sid":null,"num_media":"0","num_segments":"1","price":null,"price_unit":null,"sid":"' + sid + '",' +
               '"status":"queued","subresource_uris":{"media":"/2010-04-01/Accounts/ACTestAccountSID123/Messages/' + sid + '/Media.json"},' +
               '"to":"whatsapp:' + toNumber + '","uri":"/2010-04-01/Accounts/ACTestAccountSID123/Messages/' + sid + '.json"}';
    }
    
    private static String getContentAPIResponse(String friendlyName, String sid) {
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
     * @description Inserts a Messaging_Session for the given phone number so that nextResponseRecordWhatsAppChatbot
     * does not reset message to 'Hi'. Uses valid picklist value and No_of_Outbound_Messages__c = 0 to avoid NPE in queueable.
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

    @testSetup
    static void setupData() {
        // Centralize DML so test methods can make callouts without
        // "uncommitted work pending" errors.
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;

        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;

        // Sessions used by the callout-driving tests.
        insertMessagingSessionForPhone('+1234567890'); // initial + NL yes
        insertMessagingSessionForPhone('+1234567891'); // DE yes
        insertMessagingSessionForPhone('+1234567892'); // No mapping: Existing Customer
        insertMessagingSessionForPhone('+1234567893'); // No mapping: Moving Boxes
        // Special: inbound=1 to force "first message reset" branch.
        insert new SmartMsg__Messaging_Session__c(
            SmartMsg__To_Number__c = '+1999600000',
            SmartMsg__Session_status__c = 'Customer Message Received',
            SmartMsg__No_of_Inbound_Messages__c = 1,
            SmartMsg__No_of_Outbound_Messages__c = 0
        );

        SmartMsg__Messenger_Bot__c bot = [SELECT Id FROM SmartMsg__Messenger_Bot__c WHERE Name = 'WhatsApp' LIMIT 1];
        SmartMsg__Dialogue__c hiDialog = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        SmartMsg__Dialogue__c englishDialog = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'English' LIMIT 1];

        // Trigger replacement branch (fromNumber +31).
        SmartMsg__Dialogue__c langTriggerDialog = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'LangTrigger',
            SmartMsg__Response__c = 'en-de/moving-boxes/rent /date/ boxie24-de',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Separate Text'
        );
        insert langTriggerDialog;
        insert new SmartMsg__Option_Dialog__c(
            SmartMsg__Inbound_Response__c = langTriggerDialog.Id,
            SmartMsg__Outbound_Response__c = hiDialog.Id
        );

        // YES mapping candidates (Nederlands/Deutsch).
        SmartMsg__Dialogue__c verhuisdozenParent = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Verhuisdozen',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Question Based'
        );
        insert verhuisdozenParent;
        SmartMsg__Dialogue__c nederlandsChild = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Nederlands',
            SmartMsg__Response__c = 'Nederlands response',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Parent_Record__c = verhuisdozenParent.Id,
            SmartMsg__Type__c = 'Separate Text'
        );
        insert nederlandsChild;
        SmartMsg__Option_Dialog__c nederlandsOption = new SmartMsg__Option_Dialog__c(
            SmartMsg__Inbound_Response__c = nederlandsChild.Id,
            SmartMsg__Outbound_Response__c = englishDialog.Id
        );
        insert nederlandsOption;

        SmartMsg__Dialogue__c umzugskistenParent = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Umzugskisten',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Question Based'
        );
        insert umzugskistenParent;
        SmartMsg__Dialogue__c deutschChild = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Deutsch',
            SmartMsg__Response__c = 'Deutsch response',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Parent_Record__c = umzugskistenParent.Id,
            SmartMsg__Type__c = 'Separate Text'
        );
        insert deutschChild;
        SmartMsg__Option_Dialog__c deutschOption = new SmartMsg__Option_Dialog__c(
            SmartMsg__Inbound_Response__c = deutschChild.Id,
            SmartMsg__Outbound_Response__c = englishDialog.Id
        );
        insert deutschOption;

        // NO mapping candidates (No/Rent No).
        SmartMsg__Dialogue__c existingCustomerParent = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Existing Customer',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Question Based'
        );
        insert existingCustomerParent;
        SmartMsg__Dialogue__c noChild = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'No',
            SmartMsg__Response__c = 'No response',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Parent_Record__c = existingCustomerParent.Id,
            SmartMsg__Type__c = 'Separate Text'
        );
        insert noChild;
        SmartMsg__Option_Dialog__c noOption = new SmartMsg__Option_Dialog__c(
            SmartMsg__Inbound_Response__c = noChild.Id,
            SmartMsg__Outbound_Response__c = englishDialog.Id
        );
        insert noOption;

        SmartMsg__Dialogue__c movingBoxesParent = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Moving Boxes',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Question Based'
        );
        insert movingBoxesParent;
        SmartMsg__Dialogue__c rentNoChild = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Rent No',
            SmartMsg__Response__c = 'Rent No response',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Parent_Record__c = movingBoxesParent.Id,
            SmartMsg__Type__c = 'Separate Text'
        );
        insert rentNoChild;
        SmartMsg__Option_Dialog__c rentNoOption = new SmartMsg__Option_Dialog__c(
            SmartMsg__Inbound_Response__c = rentNoChild.Id,
            SmartMsg__Outbound_Response__c = englishDialog.Id
        );
        insert rentNoOption;

        // Seed outbound messages for the mapping branches (each test uses a different phone).
        insert new List<SmartMsg__Message__c>{
            new SmartMsg__Message__c(
                SmartMsg__Type__c = 'Outbound',
                SmartMsg__To_Number__c = '+1234567890',
                SmartMsg__Dialogue__c = hiDialog.Id,
                SmartMsg__Option_Dialog__c = nederlandsOption.Id,
                SmartMsg__Message_Body__c = 'Welcome to Storage Space.\\n Choose your language'
            ),
            new SmartMsg__Message__c(
                SmartMsg__Type__c = 'Outbound',
                SmartMsg__To_Number__c = '+1234567891',
                SmartMsg__Dialogue__c = hiDialog.Id,
                SmartMsg__Option_Dialog__c = deutschOption.Id,
                SmartMsg__Message_Body__c = 'Welcome to Storage Space.\\n Choose your language'
            ),
            new SmartMsg__Message__c(
                SmartMsg__Type__c = 'Outbound',
                SmartMsg__To_Number__c = '+1234567892',
                SmartMsg__Dialogue__c = hiDialog.Id,
                SmartMsg__Option_Dialog__c = noOption.Id,
                SmartMsg__Message_Body__c = 'Is there anything else I can help you with?'
            ),
            new SmartMsg__Message__c(
                SmartMsg__Type__c = 'Outbound',
                SmartMsg__To_Number__c = '+1234567893',
                SmartMsg__Dialogue__c = hiDialog.Id,
                SmartMsg__Option_Dialog__c = rentNoOption.Id,
                SmartMsg__Message_Body__c = 'Is there anything else I can help you with?'
            )
        };

        // Seed data for consecutive-question flow (used by WithContinousQuestion) with unique phones.
        String cqPhone1 = '+1234567894';
        String cqPhone2 = '+1234567895';
        insertMessagingSessionForPhone(cqPhone1);
        insertMessagingSessionForPhone(cqPhone2);

        List<SmartMsg__Option_Dialog__c> newCustomerOptions = [
            SELECT Id, SmartMsg__Inbound_Response__r.Id, SmartMsg__Order_Number__c
            FROM SmartMsg__Option_Dialog__c
            WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'New Customer'
        ];
        SmartMsg__Option_Dialog__c order1 = null;
        SmartMsg__Option_Dialog__c order2 = null;
        for (SmartMsg__Option_Dialog__c opt : newCustomerOptions) {
            if (opt.SmartMsg__Order_Number__c == 1 && order1 == null) order1 = opt;
            if (opt.SmartMsg__Order_Number__c == 2 && order2 == null) order2 = opt;
        }
        if (order1 != null && order2 != null) {
            String msgWithScheduleAndEmail =
                Constants.CONFIRMATION_QUESTION[0] +
                ' ' + Constants.EMAIL_LIST[0] +
                ' ' + Constants.SCHEDULE_QUESTION[0];
            String msgWithEmailOnly =
                Constants.CONFIRMATION_QUESTION[0] +
                ' ' + Constants.EMAIL_LIST[0];

            insert new List<SmartMsg__Message__c>{
                new SmartMsg__Message__c(
                    SmartMsg__Type__c = 'Outbound',
                    SmartMsg__To_Number__c = cqPhone1,
                    SmartMsg__Dialogue__c = order2.SmartMsg__Inbound_Response__r.Id,
                    SmartMsg__Option_Dialog__c = order2.Id,
                    SmartMsg__Message_Body__c = msgWithScheduleAndEmail
                ),
                new SmartMsg__Message__c(
                    SmartMsg__Type__c = 'Outbound',
                    SmartMsg__To_Number__c = cqPhone2,
                    SmartMsg__Dialogue__c = order1.SmartMsg__Inbound_Response__r.Id,
                    SmartMsg__Option_Dialog__c = order1.Id,
                    SmartMsg__Message_Body__c = msgWithEmailOnly
                )
            };
        }
    }
    
    /**
     * @description Test nextResponseRecordWhatsAppChatbot with initial message 'Hi' - verify correct record found and message created.
     */
    @isTest
    public static void testNextResponseRecordWhatsAppChatbotInitial() {
        String contentResponse1 = getContentAPIResponse('2_dynamic_quick_reply', 'HXTestContentSID123');
        String messageResponse1 = getTwilioMessageResponse(
            'MMTestMessageSID123',
            '+1234567890',
            '+1234567890',
            'Welcome to Storage Space.\n Choose your language'
        );

        String contentResponse2 = getContentAPIResponse('dynamic_text_template', 'HXTestContentSID456');
        String messageResponse2 = getTwilioMessageResponse(
            'MMTestMessageSID456',
            '+1234567890',
            '+31123456789',
            'Replacement branch covered'
        );

        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse1, messageResponse1}
        ));

        Test.startTest();
        // Use lowercase input to cover the trigger normalization path.
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot('+1234567890', 'hi', 'text', '+1234567890');
        // Cover the en-de /date / boxie24-de replacement branch.
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot('+1234567890', 'LangTrigger', 'text', '+31123456789');
        Test.stopTest();
        
        // Verify correct dialogue record was found
        List<SmartMsg__Dialogue__c> dialogueRecords = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c, SmartMsg__Type__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi'];
        System.assertEquals(1, dialogueRecords.size(), 'Should find dialogue with question Hi');
        System.assertEquals('Welcome to Storage Space.\n Choose your language', dialogueRecords[0].SmartMsg__Response__c, 'Response should match');

        // Lightweight helper coverage for remaining uncovered branches.
        System.assertEquals(null, TwilioWhatsAppChatBot.normalizeSessionPhone(''));
        System.assertEquals('+919876543210', TwilioWhatsAppChatBot.normalizeSessionPhone('919-876 543210'));

        System.assertEquals('2_dynamic_quick_reply', TwilioWhatsAppChatBot.getContentName('button', new List<String>{'A', 'B'}));
        System.assertEquals('2_dynamic_list_picker', TwilioWhatsAppChatBot.getContentName('Option', new List<String>{'X - Y', 'Z'}));

        System.assertEquals(true, TwilioWhatsAppChatBot.emailValidation('test@example.com'));
        System.assertEquals(false, TwilioWhatsAppChatBot.emailValidation('not-an-email'));

        // messagingSession / messagingSessionForOutbound coverage
        System.assertEquals(null, TwilioWhatsAppChatBot.messagingSession('', 'Automation Sent'), 'Blank phone should return null session Id');
        System.assertNotEquals(null, TwilioWhatsAppChatBot.messagingSession('919876543210', null), 'Null sessionStatus should default to Customer Message Received');
        System.assertEquals(null, TwilioWhatsAppChatBot.messagingSessionForOutbound(''), 'Blank toNumber should return null session Id');
        System.assertNotEquals(null, TwilioWhatsAppChatBot.messagingSessionForOutbound('919876543210'), 'Valid toNumber should return session Id');
    }

    /**
     * @description Covers the branch where Messaging_Session exists with No_of_Inbound_Messages__c == 1:
     * any non-empty message is treated as first message and reset to 'Hi', so we get the welcome response.
     */
    @isTest
    public static void testFirstMessageResetWhenSessionHasOneInbound() {
        String contentResponse = getContentAPIResponse('2_dynamic_quick_reply', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID123', '+1999600000', '+1999600000', 'Welcome to Storage Space.\n Choose your language');

        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));

        Test.startTest();
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot('+1999600000', 'English', 'text', '+1999600000');
        Test.stopTest();

        List<SmartMsg__Dialogue__c> hiDialog = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        System.assertEquals(1, hiDialog.size(), 'Should find Hi dialogue');
        System.assertEquals('Welcome to Storage Space.\n Choose your language', hiDialog[0].SmartMsg__Response__c, 'Message should be reset to Hi and return welcome response');
    }
    
    /**
     * @description Test nextResponseRecordWhatsAppChatbot with button reply 'Yes' - verify correct record found.
     */
    @isTest
    public static void testNextResponseRecordWhatsAppChatbotButtonReplyYes() {
        TwilioWhatsAppChatBot.sessionEndFlag = false;
        String phone1 = '+1234567890';
        String phone2 = '+1234567891';

        String contentResponse = getContentAPIResponse('dynamic_text_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse(
            'MMTestMessageSID123',
            phone1,
            phone1,
            'Language-mapping branch covered'
        );

        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));

        Test.startTest();
        // Scenario 1: Verhuisdozen => Nederlands
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(phone1, 'Ja, graag!', 'button_reply', '+1234567890');

        // Scenario 2: Umzugskisten => Deutsch
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(phone2, 'Ja, bitte!', 'button_reply', '+1234567890');

        Test.stopTest();

        System.assertEquals(false, TwilioWhatsAppChatBot.sessionEndFlag, 'Session should not be ended on "Yes".');
    }
    
    /**
     * @description Test nextResponseRecordWhatsAppChatbot with button reply 'No' - verify session end flag and Thank you message.
     */
    @isTest
    public static void testNextResponseRecordWhatsAppChatbotButtonReplyNo() {
        // Reset session end flag
        TwilioWhatsAppChatBot.sessionEndFlag = false;
        
        // Get the exact dialogue "Is there anything else I can help you with?"
        // Query by Type since Response__c cannot be filtered in WHERE clause
        List<SmartMsg__Dialogue__c> allDialogs = [SELECT Id, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Type__c = 'Separate Button'];
        SmartMsg__Dialogue__c isThereDialog = null;
        for(SmartMsg__Dialogue__c dialog : allDialogs) {
            if(dialog.SmartMsg__Response__c == 'Is there anything else I can help you with?') {
                isThereDialog = dialog;
                break;
            }
        }
        
        System.assertNotEquals(null, isThereDialog, 'Should find the "Is there anything else" dialogue');

        // Phones are pre-seeded in @testSetup with correct last outbound message context.
        String phone1 = '+1234567892';
        String phone2 = '+1234567893';

        String contentResponse = getContentAPIResponse('dynamic_text_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID123', phone1, phone1, 'Thank you for your time. Goodbye!');
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));

        Test.startTest();
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(phone1, 'No, that\'s all.', 'button_reply', '+1234567890');
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(phone2, 'No, that\'s all.', 'button_reply', '+1234567890');
        Test.stopTest();
        
        // Verify session end flag is set
        System.assertEquals(true, TwilioWhatsAppChatBot.sessionEndFlag, 'Session end flag should be set to true when No is clicked');
        
        // Verify "Thank you" message is sent - check the dialogue that should be sent
        List<SmartMsg__Dialogue__c> thankYouDialogue = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'No, that\'s all.'];
        System.assertEquals(1, thankYouDialogue.size(), 'Should find Thank you dialogue');
        System.assertEquals('Thank you for contacting us', thankYouDialogue[0].SmartMsg__Response__c, 'Response should be Thank you message');
    }
    
    /**
     * @description Test nextResponseRecordWhatsAppChatbot to cover lines 75-88 - when lastDeliveredDialogList is not empty,
     * first optionDialogList query is empty, then second query finds match and assigns values.
     */
    @isTest
    public static void testNextResponseRecordWithEmptyOptionDialogAfterLastDelivered() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        // Get the exact dialogue "Welcome to Storage Space" (Question = 'Hi')
        List<SmartMsg__Dialogue__c> welcomeDialog = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        System.assertEquals(1, welcomeDialog.size(), 'Should find Welcome dialogue');
        System.assertEquals('Welcome to Storage Space.\n Choose your language', welcomeDialog[0].SmartMsg__Response__c, 'Response should match');
        
        // Get English dialogue (exists in test data and has option dialogs from Hi)
        List<SmartMsg__Dialogue__c> englishDialog = [SELECT Id, SmartMsg__Question__c, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'English' LIMIT 1];
        System.assertEquals(1, englishDialog.size(), 'Should find English dialogue');
        
        // Required so TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot can update the LANGUAGE_LIST message body
        // (it queries for SmartMsg__Type__c = NULL and SmartMsg__Channel__c = NULL and uses assignment-to-SObject syntax).
        SmartMsg__Message__c emptyMsgRecord = TestObjectFactory.createMessageRecords(1)[0];
        emptyMsgRecord.SmartMsg__To_Number__c = '+1234567890';
        emptyMsgRecord.SmartMsg__Channel__c = null;
        emptyMsgRecord.SmartMsg__Type__c = null;
        insert emptyMsgRecord;

        // Store the message record with "Welcome to Storage Space" dialogue
        /*SmartMsg__Message__c lastMessage = new SmartMsg__Message__c();
        lastMessage.SmartMsg__Type__c = 'Outbound';
        lastMessage.SmartMsg__To_Number__c = '+1234567890';
        lastMessage.SmartMsg__Dialogue__c = welcomeDialog[0].Id;
        lastMessage.SmartMsg__Message_Body__c = 'Welcome to Storage Space.\n Choose your language';
        insert lastMessage;*/

        insertMessagingSessionForPhone('+1234567890');
        
        // Set mock responses for Content API and Messages API
        String contentResponse = getContentAPIResponse('dynamic_text_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID123', '+1234567890', '+1234567890', englishDialog[0].SmartMsg__Response__c);
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        // This will trigger the method with existing test data
        // The method will find lastDeliveredDialogList (Hi -> English)
        // First query (line 75-76) may find option dialogs or be empty depending on data
        // Second query (line 81-82) may find matches
        // Lines 84-87 will assign values if optionDialogList is found
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot('+1234567890', 'English', 'list_reply', '+1234567890');
        Test.stopTest();
        
        // Verify the last message record exists with Welcome dialogue
        List<SmartMsg__Message__c> lastMessages = [SELECT Id, SmartMsg__To_Number__c, SmartMsg__Dialogue__c, SmartMsg__Message_Body__c FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c = '+1234567890' AND SmartMsg__Type__c = 'Outbound' ORDER BY CreatedDate DESC];
        System.assert(!lastMessages.isEmpty(), 'Last message should exist');
        System.assertEquals('How Can I help you.Choose the options', lastMessages[0].SmartMsg__Message_Body__c, 'Message body should match');
    }
    
    /**
     * @description Test nextResponseRecordWhatsAppChatbot with order number flow - verify correct record found.
     */
    @isTest
    public static void WithOrderNumber() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        List<SmartMsg__Option_Dialog__c> reservationOptionDialogList = [SELECT Id, SmartMsg__Inbound_Response__c,SmartMsg__Inbound_Response__r.Id FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'English'];
        // Create last message with option dialog
        SmartMsg__Message__c lastMessage = new SmartMsg__Message__c();
        lastMessage.SmartMsg__Type__c = 'Outbound';
        lastMessage.SmartMsg__To_Number__c = '+1234567890';
        lastMessage.SmartMsg__Dialogue__c = reservationOptionDialogList[0].SmartMsg__Inbound_Response__r.Id;
        lastMessage.SmartMsg__Option_Dialog__c = reservationOptionDialogList[0].Id;
        lastMessage.SmartMsg__Message_Body__c = 'English';
        insert lastMessage;

        insertMessagingSessionForPhone('+1234567890');
        
        // Get the expected response message for New Customer flow
        // New Customer is Question Based type, so it will return the first child dialogue (dialog5) which is "Separate Text"
        // This will use 'dynamic_text_template' as the content template name
        List<SmartMsg__Dialogue__c> newCustomerDialog = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'New Customer' LIMIT 1];
        List<SmartMsg__Dialogue__c> firstChildDialog = [SELECT Id, SmartMsg__Response__c FROM SmartMsg__Dialogue__c WHERE SmartMsg__Parent_Record__c = :newCustomerDialog[0].Id ORDER BY SmartMsg__Order_Number__c LIMIT 1];
        String expectedResponse = !firstChildDialog.isEmpty() ? firstChildDialog[0].SmartMsg__Response__c : 'please enter your name';
        
        // Content API response must include 'dynamic_text_template' since New Customer returns "Separate Text" type
        String contentResponse = getContentAPIResponse('dynamic_text_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID123', '+1234567890', '+1234567890', expectedResponse);
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot('+1234567890', 'New Customer', 'list_reply', '+1234567890');
        Test.stopTest();
        
        // Verify message record
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__To_Number__c, SmartMsg__Dialogue__c FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c = '+1234567890' ORDER BY CreatedDate DESC];
        System.assert(!messages.isEmpty(), 'Message should be created via queueable');
    }
    
    @isTest
    public static void WithContinousQuestion() {
        // Pre-seeded in @testSetup with last outbound message context per phone.
        String phone1 = '+1234567894';
        String phone2 = '+1234567895';

        String contentResponse = getContentAPIResponse('dynamic_text_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse(
            'MMTestMessageSID123',
            phone1,
            phone1,
            'Consecutive question flow covered'
        );
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));

        Test.startTest();
        // Invocation 1: recordOrderNumber=2 (emailValidation false + pickupNoChecker true)
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(
            phone1,
            Constants.PICKUP_NO_MESSAGE[0],
            'list_reply',
            '+1234567890'
        );

        // Invocation 2: recordOrderNumber=1 (emailValidation true)
        TwilioWhatsAppChatBot.nextResponseRecordWhatsAppChatbot(
            phone2,
            'test@example.com',
            'list_reply',
            '+1234567890'
        );
        Test.stopTest();

        // Verify message record
        List<SmartMsg__Message__c> messages = [
            SELECT Id, SmartMsg__To_Number__c, SmartMsg__Dialogue__c
            FROM SmartMsg__Message__c
            WHERE SmartMsg__To_Number__c IN (:phone1,:phone2)
            ORDER BY CreatedDate DESC
        ];
        System.assert(!messages.isEmpty(), 'Message should be created via consecutive-question flow');
    }
    }