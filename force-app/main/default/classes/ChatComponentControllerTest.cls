/**
 * @description Test class for ChatComponentController.
 */
@IsTest
public class ChatComponentControllerTest {

    @IsTest
    public static void userPermissionTest() {
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;
        Test.startTest();
        System.assertEquals(true, ChatComponentController.hasUserPermission());
        System.assertEquals('Account', ChatComponentController.getObjectApiNameFromRecordId(accounts[0].Id));
        System.assertEquals(null, ChatComponentController.getObjectApiNameFromRecordId(null));
        System.assertEquals(null, ChatComponentController.getObjectApiNameFromRecordId('not-an-id'));
        Test.stopTest();
    }

    @IsTest
    public static void getPhoneFieldsAccountTest() {
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(2);
        for (Contact con : contactList) {
            con.AccountId = accountList[0].Id;
        }
        insert contactList;

        Test.startTest();
        System.assert(!ChatComponentController.getPhoneFields('Account').isEmpty());
        System.assert(!ChatComponentController.getPhoneFields('Contact').isEmpty());
        Test.stopTest();
    }

    @IsTest
    public static void getPhoneFieldsWithoutObjectTest() {
        Test.startTest();
        System.assert(ChatComponentController.getPhoneFields('').isEmpty());
        Test.stopTest();
    }

    @IsTest
    public static void formatPhoneNumbersWith10DigitsTest() {
        Test.startTest();
        System.assertEquals(12, ChatComponentController.formatPhoneNumber('1234567890').length());
        System.assertEquals(12, ChatComponentController.formatPhoneNumber('11234567890').length());
        System.assertEquals('+12234567890', ChatComponentController.formatPhoneNumber('+2234567890'));
        System.assertEquals('+442234567890', ChatComponentController.formatPhoneNumber('+442234567890'));
        Boolean invalidThrown = false;
        try {
            ChatComponentController.formatPhoneNumber('123');
        } catch (AuraHandledException e) {
            invalidThrown = true;
        }
        Test.stopTest();
        System.assert(invalidThrown);
    }

    @IsTest
    public static void listAllMessagesWithoutMediaTest() {
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(10);
        for (Integer i = 0; i < messageRecord.size(); i++) {
            messageRecord[i].SmartMsg__Channel__c = 'SMS';
            messageRecord[i].SmartMsg__Delivery_Status__c = 'Sent';
            if (i > 4) {
                messageRecord[i].SmartMsg__To_Number__c = '+911234567890';
            }
        }
        insert messageRecord;

        Test.startTest();
        System.assertEquals(0, ChatComponentController.listAllMessages('').size());
        System.assertEquals(5, ChatComponentController.listAllMessages('911234567890').size());
        Test.stopTest();
    }

    @IsTest
    public static void listWAMessagesTest() {
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(5);
        for (SmartMsg__Message__c message : messageRecord) {
            message.SmartMsg__Channel__c = 'Whatsapp';
        }
        insert messageRecord;

        Test.startTest();
        System.assertEquals(5, ChatComponentController.listWAMessages('919876543210').size());
        Test.stopTest();
    }

    @IsTest
    public static void getAccountRecordDetailsTest() {
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(3);
        for (Contact con : contactList) {
            con.AccountId = accountList[0].Id;
        }
        insert contactList;

        List<Opportunity> opportunityList = TestObjectFactory.createOpportunity(1);
        opportunityList[0].AccountId = accountList[0].Id;
        insert opportunityList;

        Test.startTest();
        Map<String, Object> accountResult = ChatComponentController.getRecordDetails('Account', accountList[0].Id, 'phone');
        System.assertEquals('+919876543210', accountResult.get('Phone'));

        Map<String, Object> oppResult = ChatComponentController.getRecordDetails('opportunity', opportunityList[0].Id, 'MobilePhone');
        System.assertEquals('Test Account 0', oppResult.get('Name'));
        System.assertEquals('+919876543210', ChatComponentController.getRecordDetails('opportunity', opportunityList[0].Id, 'phone').get('Phone'));
        Test.stopTest();
    }

    @IsTest
    public static void getOpportunityContactRoleTest() {
        List<Opportunity> opportunityList = TestObjectFactory.createOpportunity(1);
        insert opportunityList;
        List<Contact> contactList = TestObjectFactory.createContact(3);
        insert contactList;
        insert TestObjectFactory.createOpportunityContactRoleRecords(3, opportunityList[0].Id, contactList);

        Test.startTest();
        System.assertNotEquals(null, ChatComponentController.getRecordDetails('opportunity', opportunityList[0].Id, 'MobilePhone').get('Contacts'));
        Test.stopTest();
    }

    @IsTest
    public static void getContactDetailsTest() {
        List<Contact> contactList = TestObjectFactory.createContact(1);
        insert contactList;

        Contact phoneContact = TestObjectFactory.createContact(1)[0];
        phoneContact.Phone = '(919) 876-5432';
        phoneContact.MobilePhone = '8887776666';
        insert phoneContact;

        Case descCase = new Case(
            Subject = 'Support Case',
            ContactId = phoneContact.Id,
            Description = 'Note\nPhone : +919344754079'
        );
        insert descCase;

        Case contactCase = new Case(Subject = 'Case With Contact', ContactId = phoneContact.Id);
        insert contactCase;

        Case noPhoneCase = new Case(Description = 'No phone');
        insert noPhoneCase;

        Test.startTest();
        System.assertEquals('+919876543210', ChatComponentController.getRecordDetails('Contact', contactList[0].Id, 'MobilePhone').get('Phone'));
        System.assertEquals('Description', ChatComponentController.getRecordDetails('Case', descCase.Id, 'Phone').get('PhoneSource'));
        System.assertEquals('+919344754079', ChatComponentController.getRecordDetails('Case', descCase.Id, 'Phone').get('Phone'));
        System.assertEquals('Contact', ChatComponentController.getRecordDetails('Case', contactCase.Id, 'Phone').get('PhoneSource'));
        System.assertEquals('None', ChatComponentController.getRecordDetails('Case', noPhoneCase.Id, null).get('PhoneSource'));
        Test.stopTest();
    }

    @IsTest
    public static void createScheduleRecordWithTemplatePlaceholderReplacementTest() {
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;
        SmartMsg__Message_Template__c tmpl = new SmartMsg__Message_Template__c(SmartMsg__Object_Name__c = 'Account');
        insert tmpl;

        Map<String, Object> smsParams = new Map<String, Object>{
            'phoneNumber' => '919876543210',
            'smsBody' => 'Hello {!Name}',
            'status' => 'Scheduled',
            'scheduledTime' => DateTime.now().addMinutes(10).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss'),
            'templateId' => tmpl.Id,
            'relatedRecordId' => accounts[0].Id
        };
        Map<String, Object> waParams = new Map<String, Object>{
            'phoneNumber' => '919876543210',
            'messageBody' => 'Test WhatsApp',
            'status' => 'Scheduled',
            'scheduledTime' => DateTime.now().addMinutes(10).format('yyyy-MM-dd\'T\'HH:mm:ss')
        };

        Test.startTest();
        Id smsId = ChatComponentController.createScheduleRecord(smsParams);
        SmartMsg__Message__c waMsg = ChatComponentController.createWhatsAppScheduleRecord(waParams);
        Test.stopTest();

        System.assertNotEquals(null, smsId);
        System.assertNotEquals(null, waMsg);
        System.assert([SELECT SmartMsg__Message_Body__c FROM SmartMsg__Message__c WHERE Id = :smsId].SmartMsg__Message_Body__c.contains('Test Account'));
    }

    @IsTest
    public static void messaageRecordWithFileTest() {
        ensurePermsetAssignedToRunningUser('WhatsApp_Chatbot_User');
        String fileData = '[{"base64":"' + EncodingUtil.base64Encode(Blob.valueOf('Test file content')) + '","filename":"test.txt"}]';
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;
        SmartMsg__Message_Template__c tmpl = new SmartMsg__Message_Template__c(SmartMsg__Object_Name__c = 'Account');
        insert tmpl;

        SmartMsg__Meta_Configuration__c metaOff = TestObjectFactory.metaConfigurations();
        metaOff.SmartMsg__Active__c = false;
        upsert metaOff;
        SmartMsg__Twilio_Whatsapp__c twilio = TestObjectFactory.twilioWhatsAppSettings();
        twilio.SmartMsg__Active__c = true;
        upsert twilio;

        Test.startTest();
        SmartMsg__Message__c smsMsg = ChatComponentController.createMessageRecord(
            '919876543210', 'Test message', 'Delivered', 'SMS', fileData, tmpl.Id, accounts[0].Id, accounts[0].Id, null, null
        );
        SmartMsg__Message__c waMsg = ChatComponentController.createMessageRecord(
            '919876543210', 'WA media', 'Sent', 'Twilio WhatsApp', null, null, accounts[0].Id, accounts[0].Id,
            'https://example.com/file.pdf', 'file.pdf'
        );
        Test.stopTest();

        Test.setMock(HttpCalloutMock.class, new MockTwilioTemplateResponse());
        SmartMsg__Message__c sentMedia = ChatComponentController.sendMediaMessageWithFrom(
            waMsg.Id, 'image', 'https://example.com/photo.jpg', '919876543210', 'Media caption', 'photo.jpg', '+1234567890'
        );

        waMsg = [
            SELECT SmartMsg__Media_File__c, SmartMsg__Media_Url__c
            FROM SmartMsg__Message__c
            WHERE Id = :waMsg.Id
        ];
        System.assertNotEquals(null, smsMsg);
        System.assertEquals(true, waMsg.SmartMsg__Media_File__c);
        System.assertNotEquals(null, sentMedia);
    }

    @IsTest
    public static void replacePlaceHolderTest() {
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;
        Test.startTest();
        System.assert(ChatComponentController.replacePlaceholders('Account', accounts[0].Id, 'Hello {!Name}').contains('Test Account'));
        System.assertEquals('', ChatComponentController.replacePlaceholders('Account', accounts[0].Id, ''));
        Test.stopTest();
    }

    @IsTest
    public static void updatePinAndStarStatusPositiveTest() {
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        insert msgs;
        Test.startTest();
        ChatComponentController.updatePinStatus(msgs[0].Id, true);
        ChatComponentController.updateStarStatus(msgs[0].Id, true);
        Test.stopTest();
        SmartMsg__Message__c updated = [SELECT SmartMsg__Pinned__c, SmartMsg__Starred__c FROM SmartMsg__Message__c WHERE Id = :msgs[0].Id];
        System.assertEquals(true, updated.SmartMsg__Pinned__c);
        System.assertEquals(true, updated.SmartMsg__Starred__c);
    }

    @IsTest
    public static void retrieveSingleSMSPositiveTest() {
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        insert msgs;
        Test.startTest();
        System.assertNotEquals(null, ChatComponentController.getSingleMessage(msgs[0].Id, msgs[0].SmartMsg__To_Number__c));
        Test.stopTest();
    }

    @IsTest
    public static void scheduleSMSPositiveReturnsMessageTest() {
        ensurePermsetAssignedToRunningUser('SmartMsg_Admin');
        SmartMsg__TwilioConfiguration__c setting = TestObjectFactory.twilioConfigurationSettings();
        setting.SmartMsg__Channel__c = 'SMS';
        setting.SmartMsg__Active__c = true;
        upsert setting;

        List<SmartMsg__Message__c> scheduledMsgs = TestObjectFactory.createMessageRecords(1);
        scheduledMsgs[0].SmartMsg__Channel__c = 'SMS';
        scheduledMsgs[0].SmartMsg__Delivery_Status__c = 'Scheduled';
        scheduledMsgs[0].SmartMsg__To_Number__c = '919876543210';
        insert scheduledMsgs;

        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;

        Test.setMock(HttpCalloutMock.class, new MockTwilioScheduleSmsSuccessResponse());
        Test.startTest();
        SmartMsg__Message__c successMsg = ChatComponentController.scheduleSMS(
            scheduledMsgs[0].Id, '919876543210', 'Schedule SMS',
            DateTime.now().addMinutes(15).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss')
        );
        Test.stopTest();
        System.assertNotEquals(null, successMsg);
    }

    @IsTest
    public static void sendTextMessagePositiveReturnsMessageTest() {
        ensurePermsetAssignedToRunningUser('WhatsApp_Chatbot_User');
        SmartMsg__Twilio_Whatsapp__c twilioOff = TestObjectFactory.twilioWhatsAppSettings();
        twilioOff.SmartMsg__Active__c = false;
        upsert twilioOff;
        upsertMetaWhatsAppOrgDefaults();

        Account acc = new Account(Name = 'Messaging Account');
        insert acc;
        SmartMsg__Message_Template__c metaTemplate = new SmartMsg__Message_Template__c(
            SmartMsg__Template_API_Name__c = 'hello_world',
            SmartMsg__Template_Name__c = 'Meta Template',
            SmartMsg__Body__c = 'Hello template',
            SmartMsg__Object_Name__c = 'Account'
        );
        insert metaTemplate;

        Test.setMock(HttpCalloutMock.class, new MockMetaWhatsAppSendTextResponse());
        Test.startTest();
        SmartMsg__Message__c metaText = ChatComponentController.sendTextMessage('Hello from test', '919876543210');
        Test.stopTest();
        System.assertNotEquals(null, metaText);
        System.assertEquals('WhatsApp', metaText.SmartMsg__Channel__c);

        ChatComponentController.testForceSubscriptionExpired = true;
        Boolean subscriptionExpiredThrown = false;
        try {
            ChatComponentController.sendTemplateMessageWithFrom(
                acc.Id, metaTemplate.Id, '919876543210', null, null, '+1234567890'
            );
        } catch (AuraHandledException e) {
            subscriptionExpiredThrown = true;
        } finally {
            ChatComponentController.testForceSubscriptionExpired = false;
        }
        System.assert(subscriptionExpiredThrown);

        twilioOff.SmartMsg__Active__c = false;
        upsert twilioOff;
        SmartMsg__Meta_Configuration__c metaOff = TestObjectFactory.metaConfigurations();
        metaOff.SmartMsg__Active__c = false;
        upsert metaOff;
        Boolean noProviderThrown = false;
        try {
            ChatComponentController.sendTemplateMessage(acc.Id, metaTemplate.Id, '919876543210', null, null);
        } catch (AuraHandledException e) {
            noProviderThrown = true;
        }
        System.assert(noProviderThrown);
    }

    @IsTest
    public static void generatePublicUrlForContentDocumentPositiveTest() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('hello'),
            ContentLocation = 'S',
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Test.startTest();
        System.assertNotEquals(null, ChatComponentController.generatePublicUrlForContentDocument(cv.ContentDocumentId));
        Test.stopTest();
    }

    @IsTest
    public static void testGetActiveChannelsAndGetActiveWhatsAppChannel() {
        SmartMsg__Message_Template__c approved = new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Approved WA Template',
            SmartMsg__Object_Name__c = 'Account',
            SmartMsg__Channel__c = 'WhatsApp',
            SmartMsg__Status__c = 'Approved',
            SmartMsg__Body__c = 'Hello'
        );
        insert approved;

        Test.startTest();
        System.assert(ChatComponentController.getActiveChannels().containsKey('SMS'));
        System.assert(String.isNotBlank(ChatComponentController.getActiveWhatsAppChannel()));
        System.assertEquals('WhatsApp', ChatComponentController.getActiveChannel());

        SmartMsg__TwilioConfiguration__c smsSetting = TestObjectFactory.twilioConfigurationSettings();
        smsSetting.SmartMsg__Channel__c = 'SMS';
        smsSetting.SmartMsg__Active__c = true;
        upsert smsSetting;
        System.assertEquals(true, ChatComponentController.getActiveChannels().get('SMS'));

        SmartMsg__Meta_Configuration__c metaSetting = TestObjectFactory.metaConfigurations();
        metaSetting.SmartMsg__Active__c = true;
        upsert metaSetting;
        System.assertEquals('WhatsApp', ChatComponentController.getActiveWhatsAppChannel());
        System.assert(!ChatComponentController.getTemplates('Account', 'WhatsApp').isEmpty());

        metaSetting.SmartMsg__Active__c = false;
        upsert metaSetting;
        SmartMsg__Twilio_Whatsapp__c twilioWa = TestObjectFactory.twilioWhatsAppSettings();
        twilioWa.SmartMsg__Active__c = true;
        upsert twilioWa;
        System.assertEquals('Twilio WhatsApp', ChatComponentController.getActiveChannel());
        Test.stopTest();
    }

    @IsTest
    public static void testGetTwilioWhatsAppFromNumbers() {
        ensurePermsetAssignedToRunningUser('WhatsApp_Chatbot_User');
        Test.startTest();
        System.assert(ChatComponentController.getTwilioWhatsAppFromNumbers().isEmpty());

        SmartMsg__Twilio_Whatsapp__c twilio = TestObjectFactory.twilioWhatsAppSettings();
        twilio.SmartMsg__Active__c = true;
        twilio.SmartMsg__Twilio_Phone_Number__c = '15551234567';
        twilio.SmartMsg__From_Phone_Numbers__c = '+15559999999,15558888888';
        upsert twilio;
        System.assert(ChatComponentController.getTwilioWhatsAppFromNumbers().size() >= 2);
        Test.stopTest();
    }

    @IsTest
    public static void testHasChatbotDialogAndOptionDialogRecords() {
        insert TestObjectFactory.createDialogRecords(2);
        insert TestObjectFactory.optionDialogRecords();

        Test.startTest();
        System.assertEquals(true, ChatComponentController.hasChatbotDialogAndOptionDialogRecords());
        ChatComponentController.SmartMsgResult first = ChatComponentController.ensureChatbotMessage('+15559999999');
        ChatComponentController.SmartMsgResult second = ChatComponentController.ensureChatbotMessage('+15559999999');
        Test.stopTest();

        System.assertNotEquals(null, first.recordId);
        System.assertEquals(true, second.exists);
    }

    public class MockTwilioHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sid":"FAKE_SID"}');
            res.setStatusCode(200);
            return res;
        }
    }

    public class MockTwilioScheduleSmsSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sid":"MM_TEST_SID_001","to":"919876543210","status":"Scheduled"}');
            res.setStatusCode(201);
            return res;
        }
    }

    public class MockMetaWhatsAppSendTextResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"messaging_product":"whatsapp","contacts":[{"input":"919876543210"}],"messages":[{"id":"wamid.TEST_MESSAGE_ID"}]}');
            res.setStatusCode(200);
            return res;
        }
    }

    public class MockTwilioTemplateResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sid":"SM_TEMPLATE_001","from":"whatsapp:+1234567890","to":"whatsapp:+919876543210"}');
            res.setStatusCode(200);
            return res;
        }
    }

    public static void ensurePermsetAssignedToRunningUser(String permsetName) {
        if (String.isBlank(permsetName)) {
            return;
        }
        Id userId = UserInfo.getUserId();
        if (![SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSet.Name = :permsetName LIMIT 1].isEmpty()) {
            return;
        }
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permsetName LIMIT 1].Id
        );
    }

    public static void upsertMetaWhatsAppOrgDefaults() {
        SmartMsg__Meta_Configuration__c metaSetting = TestObjectFactory.metaConfigurations();
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Phone_Number_Id__c = 'TEST_PHONE_NUMBER_ID';
        metaSetting.SmartMsg__Active__c = true;
        upsert metaSetting;
    }
}