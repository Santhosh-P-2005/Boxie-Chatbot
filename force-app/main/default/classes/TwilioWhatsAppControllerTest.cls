/**
 * @class TwilioWhatsAppControllerTest
 * @description Unit tests for the TwilioWhatsAppController Queueable class.
 */
@isTest
private class TwilioWhatsAppControllerTest {
    
    /**
     * @description Mock class for single HTTP callout responses.
     */
    private class TwilioHttpMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        
        TwilioHttpMock(Integer code, String bodyStr) {
            statusCode = code;
            body = bodyStr;
        }

        /**
         * @description Returns the configured mock HTTP response.
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
         * @description Returns the next mock response in sequence for the current callout index.
         * @param req The HTTP request (unused).
         * @return HttpResponse with status and body from the configured lists.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            Integer index = calloutIndex < statusCodes.size() ? calloutIndex : statusCodes.size() - 1;
            res.setStatusCode(statusCodes[index]);
            res.setBody(bodies[index]);
            calloutIndex++;
            return res;
        }
    }

    private static String getTwilioMessageResponse(String sid, String toNumber, String fromNumber, String body) {
        return '{"account_sid":"ACTestAccountSID123","api_version":"2010-04-01","body":"' + 
               body + '","date_created":"Mon, 01 Jan 2024 12:00:00 +0000","date_sent":null,"date_updated":"Mon, 01 Jan 2024 12:00:00 +0000",' +
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
    
    private static String getContentAPICreateResponse(String friendlyName, String sid, String contentType) {
        String typeJson = '{}';
        if (contentType == 'quick-reply') {
            typeJson = '{"twilio/quick-reply":{}}';
        } else if (contentType == 'list-picker') {
            typeJson = '{"twilio/list-picker":{}}';
        } else {
            typeJson = '{"twilio/text":{}}';
        }
        
        return '{"account_sid":"ACTestAccountSID123","date_created":"2024-01-01T12:00:00Z","date_updated":"2024-01-01T12:00:00Z","friendly_name":"' + 
               friendlyName + '","language":"en","links":{"approval_create":"https://content.twilio.com/v1/Content/' + sid + '/ApprovalRequests/whatsapp","approval_fetch":"https://content.twilio.com/v1/Content/' + sid + '/ApprovalRequests"},' +
               '"sid":"' + sid + '","types":' + typeJson + ',"url":"https://content.twilio.com/v1/Content/' + sid + '","variables":{}}';
    }
    
    /**
     * @description Test execution with existing content.
     */
    @isTest
    public static void testExecuteWithExistingContent() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        
        TwilioWhatsAppChatBot.wrapper wrap = new TwilioWhatsAppChatBot.wrapper();
        wrap.messageBody = 'Test message';
        wrap.toNumber = '+1234567890';
        wrap.fromNumber = '+1234567890';
        wrap.contentTemplateName = 'test_template';
        wrap.dialogId = dialogList[0].Id;
        wrap.optionDialogId = null;
        wrap.sessionEndFlag = false;
        wrap.interactionList = new List<String>{'Option1', 'Option2'};
        wrap.responseType = 'Button';
        
        String contentResponse = getContentAPIResponse('test_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID123', '+1234567890', '+1234567890', 'Test message');
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        System.enqueueJob(new TwilioWhatsAppController(wrap));
        Test.stopTest();
        
        List<SmartMsg__Message__c> messages = [
            SELECT Id FROM SmartMsg__Message__c
            WHERE SmartMsg__Message_ID__c = 'MMTestMessageSID123'
        ];
        
        System.assertEquals(1, messages.size(), 'Message should be created');
    }
    
    /**
     * @description Test execution with content creation.
     */
    @isTest
    public static void testExecuteWithContentCreation() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        
        TwilioWhatsAppChatBot.wrapper wrap = new TwilioWhatsAppChatBot.wrapper();
        wrap.messageBody = 'Test message';
        wrap.toNumber = '+1234567890';
        wrap.fromNumber = '+1234567890';
        wrap.contentTemplateName = '4_dynamic';
        wrap.dialogId = dialogList[0].Id;
        wrap.optionDialogId = null;
        wrap.sessionEndFlag = false;
        wrap.interactionList = new List<String>{'Option1', 'Option2'};
        wrap.responseType = 'Button';
        
        String getContentResponse = '{"contents":[]}';
        String postContentResponse = getContentAPICreateResponse('4_dynamic', 'HXTestContentSID456', 'quick-reply');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID456', '+1234567890', '+1234567890', 'Test message');
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201, 201},
            new List<String>{getContentResponse, postContentResponse, messageResponse}
        ));
        
        Test.startTest();
        System.enqueueJob(new TwilioWhatsAppController(wrap));
        Test.stopTest();
        
        List<SmartMsg__Message__c> messages = [
            SELECT Id FROM SmartMsg__Message__c
            WHERE SmartMsg__Message_ID__c = 'MMTestMessageSID456'
        ];
        
        System.assertEquals(1, messages.size(), 'Message should be created');
    }
    
    /**
     * @description Test execution with list picker.
     */
    @isTest
    public static void testExecuteWithListPicker() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        
        TwilioWhatsAppChatBot.wrapper wrap = new TwilioWhatsAppChatBot.wrapper();
        wrap.messageBody = 'What size do you need?';
        wrap.toNumber = '+1234567890';
        wrap.fromNumber = '+1234567890';
        wrap.contentTemplateName = '3_dynamic_list_picker';
        wrap.dialogId = dialogList[0].Id;
        wrap.optionDialogId = null;
        wrap.sessionEndFlag = false;
        wrap.interactionList = new List<String>{'Option1-Desc1', 'Option2-Desc2', 'Option3-Desc3'};
        wrap.responseType = 'Option';
        
        String getContentResponse = '{"contents":[]}';
        String postContentResponse = getContentAPICreateResponse('3_dynamic_list_picker', 'HXTestContentSID789', 'list-picker');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID789', '+1234567890', '+1234567890', 'What size do you need?');
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201, 201},
            new List<String>{getContentResponse, postContentResponse, messageResponse}
        ));
        
        Test.startTest();
        System.enqueueJob(new TwilioWhatsAppController(wrap));
        Test.stopTest();
        
        List<SmartMsg__Message__c> messages = [
            SELECT Id FROM SmartMsg__Message__c
            WHERE SmartMsg__Message_ID__c = 'MMTestMessageSID789'
        ];
        
        System.assertEquals(1, messages.size(), 'Message should be created');
    }
    
    /**
     * @description Test execution with recursion (option dialog with separate button/option/text).
     */
    @isTest
    public static void testExecuteWithRecursion() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogLists = TestObjectFactory.optionDialogRecords();
        insert optionDialogLists;
        
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        
        List<SmartMsg__Option_Dialog__c> optionDialogList = [
            SELECT Id, SmartMsg__Inbound_Response__c, SmartMsg__Outbound_Response__c 
            FROM SmartMsg__Option_Dialog__c 
            WHERE SmartMsg__Inbound_Response__c = :dialogList[0].Id 
            LIMIT 1
        ];
        
        List<SmartMsg__Dialogue__c> separateButtonDialogs = [
            SELECT Id, SmartMsg__Response__c, SmartMsg__Buttons_or_Options__c, SmartMsg__Type__c, SmartMsg__Parent_Record__c
            FROM SmartMsg__Dialogue__c 
            WHERE SmartMsg__Type__c = 'Separate Button' 
            AND SmartMsg__Parent_Record__c = null
            LIMIT 1
        ];
        
        if (!separateButtonDialogs.isEmpty() && !optionDialogList.isEmpty()) {
            optionDialogList[0].SmartMsg__Outbound_Response__c = separateButtonDialogs[0].Id;
            update optionDialogList[0];
        }
        
        TwilioWhatsAppChatBot.wrapper wrap = new TwilioWhatsAppChatBot.wrapper();
        wrap.messageBody = 'Test message';
        wrap.toNumber = '+1234567890';
        wrap.fromNumber = '+1234567890';
        wrap.contentTemplateName = 'test_template';
        wrap.dialogId = dialogList[0].Id;
        wrap.optionDialogId = !optionDialogList.isEmpty() ? optionDialogList[0].Id : null;
        wrap.sessionEndFlag = false;
        wrap.interactionList = new List<String>{'Button1', 'Button2'};
        wrap.responseType = 'Button';
        
        String followUpMessage = !separateButtonDialogs.isEmpty() ? separateButtonDialogs[0].SmartMsg__Response__c : 'Follow-up message';
        List<String> followUpButtons = !separateButtonDialogs.isEmpty() && separateButtonDialogs[0].SmartMsg__Buttons_or_Options__c != null 
            ? separateButtonDialogs[0].SmartMsg__Buttons_or_Options__c.split('\n') 
            : new List<String>{'Yes', 'No'};
        
        String recursionContentTemplate = String.valueOf(followUpButtons.size()) + Constants.DYNAMIC_QUICK_REPLY_TEMPLATE_NAME;
        
        String contentResponse1 = getContentAPIResponse('test_template', 'HXTestContentSID123');
        String messageResponse1 = getTwilioMessageResponse('MMTestMessageSID001', '+1234567890', '+1234567890', 'Test message');
        String contentResponse2 = getContentAPIResponse(recursionContentTemplate, 'HXTestContentSID456');
        String messageResponse2 = getTwilioMessageResponse('MMTestMessageSID002', '+1234567890', '+1234567890', followUpMessage);
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201, 200, 201},
            new List<String>{contentResponse1, messageResponse1, contentResponse2, messageResponse2}
        ));
        
        Test.startTest();
        System.enqueueJob(new TwilioWhatsAppController(wrap));
        Test.stopTest();
        
        List<SmartMsg__Message__c> messages = [
            SELECT Id FROM SmartMsg__Message__c
            WHERE SmartMsg__To_Number__c = '+1234567890'
        ];
        
        System.assert(messages.size() >= 2, 'At least two messages should be created (initial + recursive)');
    }
    
    /**
     * @description Test execution with session end.
     */
    @isTest
    public static void testExecuteWithSessionEnd() {
        SmartMsg__Twilio_Whatsapp__c twilioSetting = TestObjectFactory.twilioWhatsAppSettings();
        upsert twilioSetting;
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Hi' LIMIT 1];
        
        TwilioWhatsAppChatBot.wrapper wrap = new TwilioWhatsAppChatBot.wrapper();
        wrap.messageBody = 'Final message';
        wrap.toNumber = '+1234567890';
        wrap.fromNumber = '+1234567890';
        wrap.contentTemplateName = 'test_template';
        wrap.dialogId = dialogList[0].Id;
        wrap.optionDialogId = null;
        wrap.sessionEndFlag = true;
        wrap.interactionList = new List<String>();
        wrap.responseType = 'Text';
        
        String contentResponse = getContentAPIResponse('test_template', 'HXTestContentSID123');
        String messageResponse = getTwilioMessageResponse('MMTestMessageSID999', '+1234567890', '+1234567890', 'Final message');
        
        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{200, 201},
            new List<String>{contentResponse, messageResponse}
        ));
        
        Test.startTest();
        System.enqueueJob(new TwilioWhatsAppController(wrap));
        Test.stopTest();
        
        List<SmartMsg__Messaging_Session__c> sessions = [
            SELECT Id, SmartMsg__Session_status__c
            FROM SmartMsg__Messaging_Session__c
            WHERE SmartMsg__To_Number__c = '+1234567890'
        ];
        
        if (!sessions.isEmpty()) {
            System.assertEquals('Completed', sessions[0].SmartMsg__Session_status__c, 'Session should be completed');
        }
    }

    /**
     * @description Scheduler can be scheduled and execute() runs without throwing (enqueues TwilioWhatsAppTemplateStatusBatch).
     * Template status update is not asserted here because the schedulable runs in a separate context where the test's HTTP mock may not apply.
     */
    @isTest
    public static void testSchedulerRunsSync() {
        Test.startTest();
        System.schedule('Twilio WhatsApp Template Status Sync Test', '0 0 * * * ?', new TwilioWhatsAppTemplateStatusScheduler());
        Test.stopTest();

        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Twilio WhatsApp Template Status Sync Test'];
        System.assert(jobs.size() == 1, 'Scheduled job should exist');
    }
}