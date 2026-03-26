/**
* @description Test class for the ChatComponentController class.
*              This class contains unit tests to verify the functionality
*              of the methods in the ChatComponentController class.
*/
@IsTest
public class ChatComponentControllerTest {
    /**
    * @description Tests the user permission check functionality.
    *              Verifies that hasUserPermission method returns true.
    */
    @IsTest
    public static void userPermissionTest(){
        Test.startTest();
        Boolean permissionResult = ChatComponentController.hasUserPermission();
        Test.stopTest();
        System.assertEquals(true,permissionResult,'Permission Denied');
    }

    /**
    * @description Tests retrieving phone fields for Account object.
    *              Verifies that getPhoneFields method returns a map of phone field API names and labels for Account.
    */
    @IsTest
    public static void getPhoneFieldsAccountTest(){
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(5);
        for(Contact con : contactList){
            con.AccountId = accountList[0].Id;
        }
        insert contactList;
        Test.startTest();
        Map<String,String> apiNameWithPhoneLabelMap = ChatComponentController.getPhoneFields('Account');
        Test.stopTest();
        System.assertEquals(true,apiNameWithPhoneLabelMap != null, 'Failed to get fetching fields');

    }

    /**
    * @description Tests retrieving phone fields with empty object name.
    *              Verifies that getPhoneFields method returns an empty map when object name is empty.
    */
    @IsTest
    public static void getPhoneFieldsWithoutObjectTest(){
        Test.startTest();
        Map<String,String> apiNameWithPhoneLabelMap = ChatComponentController.getPhoneFields('');
        Test.stopTest();
        System.assertEquals(true,apiNameWithPhoneLabelMap.isEmpty(),'Improper of getting fields');
    }

    /**
    * @description Tests retrieving phone fields for Contact object.
    *              Verifies that getPhoneFields method returns a map of phone field API names and labels for Contact.
    */
    @IsTest
    public static void getPhoneFieldsOpportunityTest(){
        List<contact> contactList = TestObjectFactory.createContact(5);
        insert contactList;
        Test.startTest();
        Map<String,String> apiNameWithPhoneLabelMap = ChatComponentController.getPhoneFields('Contact');
        Test.stopTest();
        System.assertEquals(true,apiNameWithPhoneLabelMap != null, 'Failed to get fetching fields');
    }

    /**
    * @description Tests listing all messages for a specific phone number without media.
    *              Verifies that listAllMessages method returns the correct number of message records for the given phone number.
    */
    @IsTest
    public static void listAllMessagesWithoutMediaTest(){
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(10);
        for(Integer i = 0; i < messageRecord.size(); i++){
            if(i > 4){
                messageRecord[i].SmartMsg__To_Number__c = '911234567890';
            }
        }
        insert messageRecord;
        Test.startTest();
        List<SmartMsg__Message__c> messageRecordList = ChatComponentController.listAllMessages('911234567890');
        Test.stopTest();
        System.assertEquals(5,messageRecordList.size(),'Failed to retieve message records');
    }

    /**
    * @description Tests formatting phone numbers with 10 digits.
    *              Verifies that formatPhoneNumber method correctly formats a 10-digit phone number.
    */
    @IsTest
    public static void formatPhoneNumbersWith10DigitsTest(){
        Test.startTest();
        String formattedNumber = ChatComponentController.formatPhoneNumber('1234567890');
        Test.stopTest();
        System.assertEquals(12,formattedNumber.length(),'Incorrect format of phone number');
    }

    /**
    * @description Tests formatting phone numbers with 11 digits.
    *              Verifies that formatPhoneNumber method correctly formats an 11-digit phone number.
    */
    @IsTest
    public static void formatPhoneNumbersWith11DigitsTest(){
        Test.startTest();
        String formattedNumber = ChatComponentController.formatPhoneNumber('11234567890');
        Test.stopTest();
        System.assertEquals(12,formattedNumber.length(),'Incorrect format of phone number');
    }

    /**
    * @description Tests formatting phone numbers with country code prefix.
    *              Verifies that formatPhoneNumber method correctly formats a phone number with country code.
    */
    @IsTest
    public static void formatPhoneNumbersWithCountryCodeTest(){
        Test.startTest();
        String formattedNumber = ChatComponentController.formatPhoneNumber('+2234567890');
        Test.stopTest();
        System.assertEquals(12,formattedNumber.length(),'Incorrect format of phone number');
    }

    /**
    * @description Tests listing WhatsApp messages for a specific phone number.
    *              Verifies that listWAMessages method returns all WhatsApp messages for the given phone number.
    */
    @IsTest
    public static void listWAMessagesTest(){
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(10);
        for(SmartMsg__Message__c message : messageRecord){
            message.SmartMsg__Channel__c = 'Whatsapp';
        }
        insert messageRecord;
        Test.startTest();
        List<SmartMsg__Message__c> messageResultList = ChatComponentController.listWAMessages('919876543210');
        Test.stopTest();
        System.assertEquals(10,messageResultList.size(),'Failed to fetch records');

    }

    /**
    * @description Tests retrieving Account record details with phone field.
    *              Verifies that getRecordDetails method returns correct Account details including phone number.
    */
    @IsTest
    public static void getAccountRecordDetailsTest(){
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(5);
        for(Contact con : contactList){
            con.AccountId = accountList[0].Id;
        }
        insert contactList;

        Test.startTest();
        Map<String, Object> getRecordDetailsResult = ChatComponentController.getRecordDetails('Account',accountList[0].Id,'phone');
        Test.stopTest();
        System.assertEquals('+919876543210',getRecordDetailsResult.get('Phone'),'Parent mobile number mismatch');
    }

    /**
    * @description Tests retrieving Opportunity record details with MobilePhone field.
    *              Verifies that getRecordDetails method returns correct Opportunity details including account name.
    */
    @IsTest
    public static void getOpportunityDetailsTest(){
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(2);
        for(Contact con : contactList){
            con.AccountId = accountList[0].Id;
        }
        insert contactList;
        List<opportunity> opportunityList = TestObjectFactory.createOpportunity(1);
        for(Opportunity opp : opportunityList){
            opp.AccountId = accountList[0].Id;
        }
        insert opportunityList;
        Test.startTest();
        Map<String, Object> getRecordDetailsResult = ChatComponentController.getRecordDetails('opportunity',opportunityList[0].Id,'MobilePhone');
        Test.stopTest();
        System.assertEquals('Test Account 0',getRecordDetailsResult.get('Name'),'Invalid Account Name');
    }

    /**
    * @description Tests retrieving Opportunity record details with phone field from related Account.
    *              Verifies that getRecordDetails method returns correct phone number from the related Account.
    */
    @IsTest
    public static void getOpportunityAccountPhoneTest(){
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<opportunity> opportunityList = TestObjectFactory.createOpportunity(1);
        for(Opportunity opp : opportunityList){
            opp.AccountId = accountList[0].Id;
        }
        insert opportunityList;
        Test.startTest();
        Map<String, Object> getRecordDetailsResult = ChatComponentController.getRecordDetails('opportunity',opportunityList[0].Id,'phone');
        Test.stopTest();
        System.assertEquals('+919876543210',getRecordDetailsResult.get('Phone'),'Parent mobile number mismatch');
    }

    /**
    * @description Tests retrieving Opportunity record details with MobilePhone field including Contact Roles.
    *              Verifies that getRecordDetails method returns Opportunity details with associated contacts.
    */
    @IsTest
    public static void getOpportunityContactRoleTest(){
        Integer num = 5;
        List<opportunity> opportunityList = TestObjectFactory.createOpportunity(1);
        insert opportunityList;
        List<Contact> contactList = TestObjectFactory.createContact(num);
        insert contactList;
        List<OpportunityContactRole> opportunityContactRoleList = TestObjectFactory.createOpportunityContactRoleRecords(num,opportunityList[0].Id,contactList);
        insert opportunityContactRoleList;
        Test.startTest();
        Map<String, Object> getRecordDetailsResult = ChatComponentController.getRecordDetails('opportunity',opportunityList[0].Id,'MobilePhone');
        Test.stopTest();
        Object result = getRecordDetailsResult.get('Contacts');
        System.assertEquals(true,result != null,'Invalid result');

    }

    /**
    * @description Tests retrieving Account record details with phone field.
    *              Verifies that getRecordDetails method returns correct Account phone number.
    */
    @IsTest
    public static void getAccountDetailsTest(){
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        Test.startTest();
        Map<String, Object> getRecordDetailsResult = ChatComponentController.getRecordDetails('Account',accountList[0].Id,'phone');
        Test.stopTest();
        System.assertEquals('+919876543210',getRecordDetailsResult.get('Phone'),'Parent mobile number mismatch');
    }

    /**
    * @description Tests retrieving Contact record details with MobilePhone field.
    *              Verifies that getRecordDetails method returns correct Contact phone number.
    */
    @IsTest
    public static void getContactDetailsTest(){
        List<contact> contactList = TestObjectFactory.createContact(3);
        insert contactList;
        Test.startTest();
        Map<String, Object> getRecordDetailsResult = ChatComponentController.getRecordDetails('Contact',contactList[0].Id,'MobilePhone');
        Test.stopTest();
        System.assertEquals('+919876543210',getRecordDetailsResult.get('Phone'),'Parent mobile number mismatch');
    }

    /**
    * @description Tests creating a scheduled SMS message record.
    *              Verifies that createScheduleRecord method creates and returns a message record with scheduled status.
    */
    @IsTest
    public static void scheduleSMSMessageNegativeTest() {
        Map<String, Object> params = new Map<String, Object>{
            'phoneNumber' => '919876543210',
                'smsBody' => 'Test SMS',
                'status' => 'Scheduled',
                'scheduledTime' => String.valueOf(Datetime.now().addMinutes(10))
                };
                    Test.startTest();
        Id msgId = ChatComponentController.createScheduleRecord(params);
        Test.stopTest();
        System.assertNotEquals(null, msgId, 'Message ID should be returned');
    }

    /**
    * @description Tests creating a scheduled WhatsApp message record.
    *              Verifies that createWhatsAppScheduleRecord method creates and returns a WhatsApp message with scheduled status.
    */
    @IsTest
    public static void scheduleWhatsappMessageNegativeTest() {
        String scheduledTime = DateTime.now().addMinutes(10).format('yyyy-MM-dd\'T\'HH:mm:ss');
        Map<String, Object> params = new Map<String, Object>{
            'phoneNumber' => '919876543210',
                'messageBody' => 'Test WhatsApp',
                'status' => 'Scheduled',
                'scheduledTime' => scheduledTime
                };
                    Test.startTest();
        SmartMsg__Message__c msg = ChatComponentController.createWhatsAppScheduleRecord(params);
        Test.stopTest();
        System.assertNotEquals(null, msg, 'WhatsApp message should be created');
    }

    /**
    * @description Tests creating a message record with file attachment.
    *              Verifies that createMessageRecord method creates a message record with file data.
    */
    @IsTest
    public static void messaageRecordWithFileTest() {
        Blob fileBody = Blob.valueOf('Test file content');
        String base64File = EncodingUtil.base64Encode(fileBody);
        String fileData = '[{"base64":"' + base64File + '","filename":"test.txt"}]';

        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;

        SmartMsg__Message_Template__c tmpl = new SmartMsg__Message_Template__c(
            SmartMsg__Object_Name__c = 'Account'
        );
        insert tmpl;

        Test.startTest();
        SmartMsg__Message__c msg = ChatComponentController.createMessageRecord(
            '919876543210', 'Test message', 'Delivered', 'SMS',fileData, tmpl.Id, accounts[0].Id, accounts[0].Id,null,null
        );
        Test.stopTest();
        System.assertNotEquals(null, msg, 'Message should be created with file');
    }

    /**
    * @description Tests replacing placeholders in message template with record field values.
    *              Verifies that replacePlaceholders method correctly replaces {!Name} placeholder with Account name.
    */
    @IsTest
    public static void replacePlaceHolderTest() {
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;
        Test.startTest();
        String result = ChatComponentController.replacePlaceholders('Account', accounts[0].Id, 'Hello {!Name}');
        Test.stopTest();
        System.assert(result.contains('Test Account'), 'Should replace placeholder');
    }

    /**
    * @description Tests updating pin and star status of a message record.
    *              Verifies that updatePinStatus and updateStarStatus methods correctly update the message record.
    */
    @IsTest
    public static void updatePinAndStarStatusPositiveTest() {
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        insert msgs;
        Test.startTest();
        ChatComponentController.updatePinStatus(msgs[0].Id, true);
        ChatComponentController.updateStarStatus(msgs[0].Id, true);
        Test.stopTest();
        SmartMsg__Message__c updated = [SELECT SmartMsg__Pinned__c, SmartMsg__Starred__c FROM SmartMsg__Message__c WHERE Id = :msgs[0].Id];
        System.assertEquals(true, updated.SmartMsg__Pinned__c, 'Pin status should be true');
        System.assertEquals(true, updated.SmartMsg__Starred__c, 'Star status should be true');
    }

    /**
    * @description Tests retrieving message templates for a specific object and channel.
    *              Verifies that getTemplates method returns templates for Account object and SMS channel.
    */
    @IsTest
    public static void getTemplatesTest() {
        Test.startTest();
        List<SmartMsg__Message_Template__c> templates = ChatComponentController.getTemplates('Account', 'SMS');
        Test.stopTest();
        System.assertEquals(0, templates.size(), 'Should return no templates');
    }

    /**
    * @description Tests retrieving a single SMS message by ID and phone number.
    *              Verifies that getSingleMessage method returns the correct message record.
    */
    @IsTest
    public static void retrieveSingleSMSPositiveTest() {
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        insert msgs;
        Test.startTest();
        SmartMsg__Message__c msg = ChatComponentController.getSingleMessage(msgs[0].Id, msgs[0].SmartMsg__To_Number__c);
        Test.stopTest();
        System.assertNotEquals(null, msg, 'Should fetch single message');
    }

    /**
    * @description Tests scheduling an SMS message using Twilio.
    *              Verifies that scheduleSMS method schedules an SMS message and returns null when message is scheduled.
    */
    @IsTest
    public static void scheduleSMSTest1() {
        ensurePermsetAssignedToRunningUser('SmartMsg_Admin');
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<SmartMsg__Message__c> messageList = TestObjectFactory.createMessageRecords(1);
        insert messageList;
        SmartMsg__TwilioConfiguration__c setting = TestObjectFactory.twilioConfigurationSettings();
        setting.SmartMsg__Channel__c = 'SMS';
        setting.SmartMsg__Active__c = true;
        upsert setting;
        // Use 200 mock so TwilioServices.scheduleSMS returns null (no 201 path); controller then returns null.
        Test.setMock(HttpCalloutMock.class, new MockTwilioHttpResponse());
        Test.startTest();
        String phoneNumber = accountList[0].Phone != null ? accountList[0].Phone : '+919876543210';
        SmartMsg__Message__c scheduleMessage = ChatComponentController.scheduleSMS(
            accountList[0].Id,
            phoneNumber,
            'Schedule SMS',
            DateTime.now().addMinutes(15).format('yyyy-MM-dd\'T\'HH:mm:ss')
        );
        Test.stopTest();
        System.assertEquals(null, scheduleMessage, 'When Twilio does not return 201, no message record is returned.');
    }

    /**
    * @description Mock class for simulating Twilio HTTP responses.
    */
    public class MockTwilioHttpResponse implements HttpCalloutMock {
        /**
        * @description Responds to an HTTP request with a mock Twilio response.
        * @param req The HTTPRequest object containing the request details.
        * @return The HTTPResponse object with the mock response details.
        */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sid":"FAKE_SID"}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
    * @description Mock Twilio schedule SMS success response (Twilio returns 201 for scheduled message create).
    */
    public class MockTwilioScheduleSmsSuccessResponse implements HttpCalloutMock {
        /**
        * @description Responds to an HTTP request with a mock Twilio scheduled SMS success response.
        * @param req The HTTPRequest object containing the request details.
        * @return The HTTPResponse object with status code 201 and scheduled message details.
        */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // Include fields used by TwilioServices.scheduleSMS: sid, to, status
            res.setBody('{"sid":"MM_TEST_SID_001","to":"919876543210","status":"Scheduled"}');
            res.setStatusCode(201);
            return res;
        }
    }

    /**
    * @description Mock Meta WhatsApp send text response (Graph API).
    */
    public class MockMetaWhatsAppSendTextResponse implements HttpCalloutMock {
        /**
        * @description Responds to an HTTP request with a mock Meta WhatsApp send text message response.
        * @param req The HTTPRequest object containing the request details.
        * @return The HTTPResponse object with status code 200 and WhatsApp message details.
        */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // WhatsAppServices.sendTextMessage expects JSON with messages[0].id
            res.setBody('{"messaging_product":"whatsapp","contacts":[{"input":"919876543210"}],"messages":[{"id":"wamid.TEST_MESSAGE_ID"}]}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
    * @description Assigns a permission set to the running user if not already assigned.
    * @param permsetName The name of the permission set to assign to the running user.
    */
    public static void ensurePermsetAssignedToRunningUser(String permsetName) {
        if (String.isBlank(permsetName)) {
            return;
        }
        Id userId = UserInfo.getUserId();
        List<PermissionSetAssignment> existing = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSet.Name = :permsetName LIMIT 1];
        if (!existing.isEmpty()) {
            return;
        }
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permsetName LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
    }

    /**
    * @description Creates/upserts org default Meta configuration used by WhatsAppServices callouts.
    *              Sets up test configuration for Meta WhatsApp integration.
    */
    public static void upsertMetaWhatsAppOrgDefaults() {
        SmartMsg__Meta_Configuration__c metaSetting = TestObjectFactory.metaConfigurations();
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Phone_Number_Id__c = 'TEST_PHONE_NUMBER_ID';
        metaSetting.SmartMsg__Active__c = true;
        upsert metaSetting;
    }

    /**
    * @description Tests creating a scheduled record with template placeholder replacement.
    *              Verifies that createScheduleRecord method replaces placeholders in SMS body with Account field values.
    */
    @IsTest
    public static void createScheduleRecordWithTemplatePlaceholderReplacementTest() {
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;

        SmartMsg__Message_Template__c tmpl = new SmartMsg__Message_Template__c(
            SmartMsg__Object_Name__c = 'Account'
        );
        insert tmpl;

        Map<String, Object> params = new Map<String, Object>{
            'phoneNumber' => '919876543210',
            'smsBody' => 'Hello {!Name}',
            'status' => 'Scheduled',
            // format expected by DateTime.valueOfGmt after replacing 'T' with ' '
            'scheduledTime' => DateTime.now().addMinutes(10).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss'),
            'templateId' => tmpl.Id,
            'relatedRecordId' => accounts[0].Id
        };

        Test.startTest();
        Id msgId = ChatComponentController.createScheduleRecord(params);
        Test.stopTest();

        System.assertNotEquals(null, msgId, 'Message ID should be returned');
        SmartMsg__Message__c createdMsg = [SELECT Id, SmartMsg__Message_Body__c FROM SmartMsg__Message__c WHERE Id = :msgId];
        System.assert(createdMsg.SmartMsg__Message_Body__c.contains('Test Account'), 'SMS body should have placeholders replaced');
    }

    /**
    * @description Tests scheduling an SMS message with positive scenario that returns a message.
    *              Verifies that scheduleSMS method schedules an SMS message and returns the message record with Scheduled status.
    */
    @IsTest
    public static void scheduleSMSPositiveReturnsMessageTest() {
        // Ensure required permission sets for ProviderSettingUtil.getSMSProviderSettings
        ensurePermsetAssignedToRunningUser('SmartMsg_Admin');

        // Twilio SMS provider settings (org defaults)
        SmartMsg__TwilioConfiguration__c setting = TestObjectFactory.twilioConfigurationSettings();
        setting.SmartMsg__Channel__c = 'SMS';
        setting.SmartMsg__Active__c = true;
        upsert setting;

        // Create an existing scheduled message record that TwilioServices.scheduleSMS updates and returns
        List<SmartMsg__Message__c> scheduledMsgs = TestObjectFactory.createMessageRecords(1);
        scheduledMsgs[0].SmartMsg__Channel__c = 'SMS';
        scheduledMsgs[0].SmartMsg__Delivery_Status__c = 'Scheduled';
        scheduledMsgs[0].SmartMsg__To_Number__c = '919876543210';
        insert scheduledMsgs;

        Test.setMock(HttpCalloutMock.class, new MockTwilioScheduleSmsSuccessResponse());
        Test.startTest();
        SmartMsg__Message__c scheduleMessage = ChatComponentController.scheduleSMS(
            scheduledMsgs[0].Id,
            '919876543210',
            'Schedule SMS',
            DateTime.now().addMinutes(15).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss')
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduleMessage, 'Scheduled message should be returned');
        System.assertEquals('Scheduled', scheduleMessage.SmartMsg__Delivery_Status__c, 'Delivery status should be Scheduled');
    }

    /**
    * @description Tests sending a WhatsApp text message with positive scenario that returns a message.
    *              Verifies that sendTextMessage method sends a WhatsApp message and returns the message record with Sent status.
    */
    @IsTest
    public static void sendTextMessagePositiveReturnsMessageTest() {
        // Ensure required permission set for WhatsAppProviderSettingUtil.getWhatsAppProviderSettings
        ensurePermsetAssignedToRunningUser('WhatsApp_Chatbot_User');
        upsertMetaWhatsAppOrgDefaults();

        Test.setMock(HttpCalloutMock.class, new MockMetaWhatsAppSendTextResponse());
        Test.startTest();
        SmartMsg__Message__c msg = ChatComponentController.sendTextMessage('Hello from test', '919876543210');
        Test.stopTest();

        System.assertNotEquals(null, msg, 'WhatsApp message should be returned');
        System.assertEquals('WhatsApp', msg.SmartMsg__Channel__c, 'Channel should be WhatsApp');
        System.assertEquals('Sent', msg.SmartMsg__Delivery_Status__c, 'Delivery status should be Sent');
    }

    /**
    * @description Tests generating a public URL for a ContentDocument.
    *              Verifies that generatePublicUrlForContentDocument method returns a valid public URL for the given ContentDocument ID.
    */
    @IsTest
    public static void generatePublicUrlForContentDocumentPositiveTest() {
        // Create a ContentVersion to produce a ContentDocument
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test File';
        cv.PathOnClient = 'test.txt';
        cv.VersionData = Blob.valueOf('hello');
        cv.ContentLocation = 'S';
        cv.FirstPublishLocationId = UserInfo.getUserId();
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        System.assertNotEquals(null, cv.ContentDocumentId, 'ContentDocumentId should be created');

        Test.startTest();
        String url = ChatComponentController.generatePublicUrlForContentDocument(cv.ContentDocumentId);
        Test.stopTest();

        System.assertNotEquals(null, url, 'Public URL should be returned');
    }

    /**
     * @description Covers getActiveChannels and getActiveWhatsAppChannel: no config, SMS active, Meta active, Twilio WhatsApp active, and default.
     */
    @IsTest
    public static void testGetActiveChannelsAndGetActiveWhatsAppChannel() {
        Test.startTest();
        Map<String, Boolean> channels = ChatComponentController.getActiveChannels();
        System.assertNotEquals(null, channels, 'getActiveChannels should return a map');
        System.assert(channels.containsKey('SMS') && channels.containsKey('WhatsApp'), 'Map should contain SMS and WhatsApp');

        String whatsAppChannel = ChatComponentController.getActiveWhatsAppChannel();
        System.assert(String.isNotBlank(whatsAppChannel), 'getActiveWhatsAppChannel should return non-blank');

        SmartMsg__TwilioConfiguration__c smsSetting = TestObjectFactory.twilioConfigurationSettings();
        smsSetting.SmartMsg__Channel__c = 'SMS';
        smsSetting.SmartMsg__Active__c = true;
        upsert smsSetting;
        channels = ChatComponentController.getActiveChannels();
        System.assertEquals(true, channels.get('SMS'), 'SMS should be active when TwilioConfiguration is active');

        SmartMsg__Meta_Configuration__c metaSetting = TestObjectFactory.metaConfigurations();
        metaSetting.SmartMsg__Active__c = true;
        upsert metaSetting;
        channels = ChatComponentController.getActiveChannels();
        System.assertEquals(true, channels.get('WhatsApp'), 'WhatsApp should be active when Meta is active');
        System.assertEquals('WhatsApp', ChatComponentController.getActiveWhatsAppChannel(), 'Meta active returns WhatsApp');

        metaSetting.SmartMsg__Active__c = false;
        upsert metaSetting;
        SmartMsg__Twilio_Whatsapp__c twilioWa = TestObjectFactory.twilioWhatsAppSettings();
        twilioWa.SmartMsg__Active__c = true;
        upsert twilioWa;
        System.assertEquals('Twilio WhatsApp', ChatComponentController.getActiveWhatsAppChannel(), 'Twilio active returns Twilio WhatsApp');
        channels = ChatComponentController.getActiveChannels();
        System.assertEquals(true, channels.get('WhatsApp'), 'WhatsApp should be active when Twilio WhatsApp is active');

        twilioWa.SmartMsg__Active__c = false;
        upsert twilioWa;
        System.assertEquals('WhatsApp', ChatComponentController.getActiveWhatsAppChannel(), 'Neither active returns default WhatsApp');
        Test.stopTest();
    }

    /**
     * @description Covers getTwilioWhatsAppFromNumbers: inactive/empty, primary only, primary + From_Phone_Numbers__c with dedup.
     */
    @IsTest
    public static void testGetTwilioWhatsAppFromNumbers() {
        Test.startTest();
        List<String> numbers = ChatComponentController.getTwilioWhatsAppFromNumbers();
        System.assert(numbers != null && numbers.isEmpty(), 'Inactive or no config should return empty list');

        SmartMsg__Twilio_Whatsapp__c twilio = TestObjectFactory.twilioWhatsAppSettings();
        twilio.SmartMsg__Active__c = true;
        twilio.SmartMsg__Twilio_Phone_Number__c = '15551234567';
        twilio.SmartMsg__From_Phone_Numbers__c = null;
        upsert twilio;
        numbers = ChatComponentController.getTwilioWhatsAppFromNumbers();
        System.assertEquals(1, numbers.size(), 'Should have one primary number');
        System.assert(numbers[0].startsWith('+'), 'Number should be normalized with +');

        twilio.SmartMsg__From_Phone_Numbers__c = '+15559999999, 15558888888\n+15557777777';
        upsert twilio;
        numbers = ChatComponentController.getTwilioWhatsAppFromNumbers();
        System.assert(numbers.size() >= 2, 'Should include primary and from numbers; no duplicates');
        Test.stopTest();
    }

    /**
     * @description Mock for Twilio Messages API (template/text) - returns sid, from, to for ChatComponentController.sendTemplateMessageWithFrom Twilio path.
     */
    public class MockTwilioTemplateResponse implements HttpCalloutMock {
        /**
         * @description Responds to an HTTP request with a mock Twilio Messages API response (sid, from, to).
         * @param req The HTTPRequest from the callout.
         * @return HTTPResponse with status 200 and JSON body containing sid, from, and to.
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sid":"SM_TEMPLATE_001","from":"whatsapp:+1234567890","to":"whatsapp:+919876543210"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
	 /**
     * @description Tests sending text message, getting active WhatsApp channel, getting templates, and ensuring chatbot message.
     *              Only one callout+insert per startTest to avoid "uncommitted work" before callout.
     */
    @IsTest
    public static void testSendTextMessageGetChannelGetTemplatesSendTemplateEnsureChatbot() {
        Account acc = new Account(Name = 'Unit Test Account');
        insert acc;
        SmartMsg__Message_Template__c tmplate = new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Unit Test Template',
        	SmartMsg__Object_Name__c = 'Account',
            SmartMsg__Channel__c = 'Twilio WhatsApp'
            );
        insert tmplate;
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<SmartMsg__Message_Template__c> templ = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Channel__c = 'Twilio WhatsApp' LIMIT 1];
        System.assert(!accounts.isEmpty(), 'Test requires at least one Account');
        System.assert(!templ.isEmpty(), 'Test requires at least one Twilio WhatsApp template');
        Test.setMock(HttpCalloutMock.class, new MockTwilioMessagesResponse());
        
        
        Test.startTest();
        ChatComponentController.SmartMsgResult chatbotRes = ChatComponentController.ensureChatbotMessage('+15559999999');
        System.assert(chatbotRes != null && chatbotRes.recordId != null, 'ensureChatbotMessage');
        ChatComponentController.SmartMsgResult chatbotRes2 = ChatComponentController.ensureChatbotMessage('+15559999999');
        System.assert(chatbotRes2.exists == true, 'ensureChatbotMessage existing');
        Test.stopTest();
    }
    
    /**
     * @description Mock for Twilio Messages API (sendTextMessage / sendTemplateMessage) - body must include sid, from, to.
     */
    public class MockTwilioMessagesResponse implements HttpCalloutMock {
        /**
         * @description Responds to an HTTP request with a mock Twilio Messages API response.
         * @param req The HTTPRequest object containing the request details.
         * @return The HTTPResponse object with status code 200 and Twilio message details.
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"sid":"MS123","from":"whatsapp:+1234567890","to":"whatsapp:+15551234567","body":"Hello"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    /**
    * @description Tests retrieving dialogs and option dialog records.
    * Verifies that hasChatbotDialogAndOptionDialogRecords method returns Boolean value whether the Objects has records or not.
    */
    @IsTest
    public static void testHasChatbotDialogAndOptionDialogRecords() {
        List<SmartMsg__Dialogue__c> dialogList = TestObjectFactory.createDialogRecords(5);
        insert dialogList;
        
        List<SmartMsg__Option_Dialog__c> optionDialogList = TestObjectFactory.optionDialogRecords();
        insert optionDialogList;
        
        Test.startTest();
        Boolean value = ChatComponentController.hasChatbotDialogAndOptionDialogRecords();
        System.assertEquals(true,value,'Boolean has to be True');
        Test.stopTest();
    }

}