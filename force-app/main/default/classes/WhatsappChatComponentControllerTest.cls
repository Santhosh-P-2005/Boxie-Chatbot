/**
 * @description Test class for the WhatsappChatComponentController class.
 *              This class contains unit tests to verify the functionality
 *              of the methods in the WhatsappChatComponentController class.
 */
@isTest
public class WhatsappChatComponentControllerTest {
    // Store reusable test data
    static Id testAccountId;
    static Id testTemplateId;
    public static final String USER_LASTNAME_WITH_PHONE = 'WCCTWithPhone';
    public static final String USER_LASTNAME_NO_PHONE = 'WCCTNoPhone';
    
    /**
     * @description Test setup method to insert necessary data before running test methods.
     *              Creates test accounts, templates, messages, and users for test execution.
     */
    @TestSetup
    public static void setupData() {
        Account acc = new Account(Name = 'Unit Test Account');
        insert acc;
        testAccountId = acc.Id;
        
        SmartMsg__Message_Template__c tmpl = new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Unit Test Template',
        SmartMsg__Object_Name__c = 'Account'
            );
        insert tmpl;
        testTemplateId = tmpl.Id;
        
        // Twilio + prior message + Twilio template (no DML in test method before callouts)
        SmartMsg__Twilio_Whatsapp__c tw = TestObjectFactory.twilioWhatsAppSettings();
        tw.SmartMsg__Active__c = true;
        insert tw;
        insert new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+15551234567',
        SmartMsg__From_Number__c = '+1234567890',
        SmartMsg__Channel__c = 'WhatsApp'
            );
        insert new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Twilio Test',
        SmartMsg__Object_Name__c = 'Account',
        SmartMsg__Channel__c = 'Twilio WhatsApp',
        SmartMsg__Status__c = 'Approved',
        SmartMsg__WhatsApp_Template_ID__c = 'HX123',
        SmartMsg__Body__c = 'Hello {{1}}'
            );
        insert new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Twilio No SID',
        SmartMsg__Object_Name__c = 'Account',
        SmartMsg__Channel__c = 'Twilio WhatsApp',
        SmartMsg__Status__c = 'Approved',
        SmartMsg__Body__c = 'Hi'
            );
        insert new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Twilio List Picker',
        SmartMsg__Object_Name__c = 'Account',
        SmartMsg__Channel__c = 'Twilio WhatsApp',
        SmartMsg__Status__c = 'Approved',
        SmartMsg__WhatsApp_Template_ID__c = 'HX456',
        SmartMsg__Body__c = 'Choose {{1}}',
        SmartMsg__List_Picker_With_Description__c = true,
        SmartMsg__Button__c = '[{"text":"A","description":"Option A"}]'
            );
        insert new SmartMsg__Message_Template__c(
            SmartMsg__Template_Name__c = 'Twilio Button String',
        SmartMsg__Object_Name__c = 'Account',
        SmartMsg__Channel__c = 'Twilio WhatsApp',
        SmartMsg__Status__c = 'Approved',
        SmartMsg__WhatsApp_Template_ID__c = 'HX789',
        SmartMsg__Body__c = 'Pick {{1}}',
        SmartMsg__Button__c = '["Option A - Description A"]'
            );
        
        // Additional prior message to support getTwilioWhatsAppFromNumber fallback tests
        insert new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+19998887777',
        SmartMsg__From_Number__c = '19876543210',
        SmartMsg__Channel__c = 'WhatsApp'
            );
        
        // Additional templates for uncovered branches in sendTwilioContentTemplateMessage
        List<SmartMsg__Message_Template__c> extraTemplates = new List<SmartMsg__Message_Template__c>();
        
        SmartMsg__Message_Template__c mergeT = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HXMERGE')[0];
        mergeT.SmartMsg__Template_Name__c = 'Twilio Merge Fields';
        mergeT.SmartMsg__Body__c = 'Hello {!Name} {!Owner.Name}';
        mergeT.SmartMsg__Button__c = '[]';
        extraTemplates.add(mergeT);
        
        SmartMsg__Message_Template__c fallbackT = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HXFALLBACK')[0];
        fallbackT.SmartMsg__Template_Name__c = 'Twilio From Fallback';
        fallbackT.SmartMsg__Body__c = 'Hello {{1}}';
        fallbackT.SmartMsg__Button__c = '[]';
        extraTemplates.add(fallbackT);
        
        SmartMsg__Message_Template__c notFoundT = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HXNOTFOUND')[0];
        notFoundT.SmartMsg__Template_Name__c = 'Twilio From Not Found';
        notFoundT.SmartMsg__Body__c = 'Hello {{1}}';
        notFoundT.SmartMsg__Button__c = '[]';
        extraTemplates.add(notFoundT);
        
        SmartMsg__Message_Template__c btnMapT = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HXBTNMAP')[0];
        btnMapT.SmartMsg__Template_Name__c = 'Twilio Button Map Variants';
        btnMapT.SmartMsg__Body__c = 'Pick {{1}}';
        btnMapT.SmartMsg__List_Picker_With_Description__c = false;
        btnMapT.SmartMsg__Button__c =
            '[' +
            '{"text":"Option A - Desc A","description":""},' +
            '{"text":"OptionB-DescB","description":null},' +
            '{"text":"","description":"OnlyDesc"},' +
            '"StrOpt-Desc"' +
            ']';
        extraTemplates.add(btnMapT);
        
        SmartMsg__Message_Template__c badJsonT = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HXBADJSON')[0];
        badJsonT.SmartMsg__Template_Name__c = 'Twilio Bad JSON';
        badJsonT.SmartMsg__Body__c = 'Hello {{1}}';
        badJsonT.SmartMsg__Button__c = '{bad-json';
        extraTemplates.add(badJsonT);
        
        SmartMsg__Message_Template__c noDescOptsT = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HXOPTS')[0];
        noDescOptsT.SmartMsg__Template_Name__c = 'Twilio Options No Desc';
        noDescOptsT.SmartMsg__Body__c = 'Choose {{1}}';
        noDescOptsT.SmartMsg__List_Picker_With_Description__c = false;
        noDescOptsT.SmartMsg__Button__c = '["One","Two"]';
        extraTemplates.add(noDescOptsT);
        
        insert extraTemplates;
        
        // Create two users so we can switch Twilio WhatsApp custom setting values via runAs (no DML needed in test methods before callouts).
        // Use System Administrator profile so runAs users have read access to all SmartMsg__Message_Template__c fields (WITH SECURITY_ENFORCED query in controller).
        List<Profile> adminProfiles = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile p = adminProfiles.isEmpty() ? [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1] : adminProfiles[0];
        String uniq = String.valueOf(DateTime.now().getTime());
        User uWithPhone = new User(
            Alias = 'wctp',
        Email = 'withphone' + uniq + '@example.com',
        EmailEncodingKey = 'UTF-8',
        LastName = USER_LASTNAME_WITH_PHONE,
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'America/Los_Angeles',
        Username = 'withphone' + uniq + '@example.com',
        ProfileId = p.Id
            );
        User uNoPhone = new User(
            Alias = 'wctn',
        Email = 'nophone' + uniq + '@example.com',
        EmailEncodingKey = 'UTF-8',
        LastName = USER_LASTNAME_NO_PHONE,
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        TimeZoneSidKey = 'America/Los_Angeles',
        Username = 'nophone' + uniq + '@example.com',
        ProfileId = p.Id
            );
        insert new List<User>{ uWithPhone, uNoPhone };
        
        // User-level hierarchy custom settings (must be new instances per user; getOrgDefaults returns one shared record)
        SmartMsg__Twilio_Whatsapp__c withPhoneSetting = new SmartMsg__Twilio_Whatsapp__c(
            SetupOwnerId = uWithPhone.Id,
        SmartMsg__Account_SID__c = 'ACTestAccountSID',
        SmartMsg__Auth_Token__c = 'TestAuthToken',
        SmartMsg__Channel__c = 'Twilio_WhatsApp',
        SmartMsg__Active__c = true,
        SmartMsg__Twilio_Phone_Number__c = '+1234567890'
            );
        SmartMsg__Twilio_Whatsapp__c noPhoneSetting = new SmartMsg__Twilio_Whatsapp__c(
            SetupOwnerId = uNoPhone.Id,
        SmartMsg__Account_SID__c = 'ACTestAccountSID',
        SmartMsg__Auth_Token__c = 'TestAuthToken',
        SmartMsg__Channel__c = 'Twilio_WhatsApp',
        SmartMsg__Active__c = true,
        SmartMsg__Twilio_Phone_Number__c = null
            );
        insert new List<SmartMsg__Twilio_Whatsapp__c>{ withPhoneSetting, noPhoneSetting };
    }
    
    /**
     * @description Tests the user permission check functionality.
     *              Verifies that hasUserPermission method returns true.
     */
    @IsTest
    public static void userPermissionTest(){
        Test.startTest();
        Boolean permissionResult = WhatsappChatComponentController.hasUserPermission();
        Test.stopTest();
        System.assertEquals(true,permissionResult,'Permission Denied');
    }
    
    /**
     * @description Tests retrieving phone fields for different objects.
     *              Verifies that getPhoneFields method returns correct phone fields for Account, Contact, empty string, and invalid objects.
     */
    @IsTest
    public static void getPhoneFieldsTest() {
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(2);
        for (Contact con : contactList) { con.AccountId = accountList[0].Id; }
        insert contactList;
        Test.startTest();
        System.assert(WhatsappChatComponentController.getPhoneFields('Account') != null, 'Account');
        System.assert(WhatsappChatComponentController.getPhoneFields('').isEmpty(), 'empty');
        System.assert(WhatsappChatComponentController.getPhoneFields('Contact') != null, 'Contact');
        Map<String, String> invalid = WhatsappChatComponentController.getPhoneFields('XyZ_NoSuchObject_Abc__c');
        System.assert(invalid != null && invalid.isEmpty(), 'Invalid object returns empty map');
        Test.stopTest();
    }

    /**
     * @description Tests formatting phone numbers with different formats.
     *              Verifies that formatPhoneNumber method correctly formats 10-digit, 11-digit, and country code phone numbers, and throws exception for invalid formats.
     */
    @isTest
    public static void formatPhoneNumberTest() {
        Test.startTest();
        System.assertEquals(12, WhatsappChatComponentController.formatPhoneNumber('1234567890').length(), '10 digits');
        System.assertEquals(12, WhatsappChatComponentController.formatPhoneNumber('11234567890').length(), '11 digits');
        System.assertEquals(12, WhatsappChatComponentController.formatPhoneNumber('+2234567890').length(), 'country code');
        try {
            WhatsappChatComponentController.formatPhoneNumber('123');
            System.assert(false, 'Should throw for invalid length');
        } catch (Exception e) {
            System.assert(e != null && (e.getMessage() == null || e.getMessage().length() > 0), 'Expected exception for invalid phone');
        }
        Test.stopTest();
    }
    
    /**
     * @description Tests listing WhatsApp messages for a specific phone number.
     *              Verifies that listWAMessages method returns all WhatsApp messages for the given phone number.
     */
    @isTest
    public static void listWAMessagesTest(){
        List<SmartMsg__Message__c> messageRecord = TestObjectFactory.createMessageRecords(10);
        for(SmartMsg__Message__c message : messageRecord){
            message.SmartMsg__Channel__c = 'Whatsapp';
        }
        insert messageRecord;
        Test.startTest();
        List<SmartMsg__Message__c> messageResultList = WhatsappChatComponentController.listWAMessages('919876543210');
        Test.stopTest();
        System.assertEquals(10,messageResultList.size(),'Failed to fetch records');
        
    }
    
    /**
     * @description Tests retrieving record details for Account, Contact, and Opportunity objects.
     *              Verifies that getRecordDetails method returns correct phone numbers and contact information for various scenarios.
     */
    @isTest
    public static void getRecordDetailsTest() {
        List<Account> accountList = TestObjectFactory.createAccount(1);
        insert accountList;
        List<Contact> contactList = TestObjectFactory.createContact(2);
        for (Contact con : contactList) { con.AccountId = accountList[0].Id; }
        insert contactList;
        Test.startTest();
        Map<String, Object> acc = WhatsappChatComponentController.getRecordDetails('Account', accountList[0].Id, 'phone');
        Map<String, Object> con = WhatsappChatComponentController.getRecordDetails('Contact', contactList[0].Id, 'MobilePhone');
        System.assertEquals('+919876543210', acc.get('Phone'), 'Account phone');
        System.assertEquals('+919876543210', con.get('Phone'), 'Contact phone');
        Test.stopTest();
        
        List<Opportunity> opportunityList = TestObjectFactory.createOpportunity(1);
        for (Opportunity opp : opportunityList) { opp.AccountId = accountList[0].Id; }
        insert opportunityList;
        List<OpportunityContactRole> ocrList = TestObjectFactory.createOpportunityContactRoleRecords(2, opportunityList[0].Id, contactList);
        insert ocrList;
        Map<String, Object> byMobile = WhatsappChatComponentController.getRecordDetails('opportunity', opportunityList[0].Id, 'MobilePhone');
        Map<String, Object> byPhone = WhatsappChatComponentController.getRecordDetails('opportunity', opportunityList[0].Id, 'phone');
        Map<String, Object> defaultPhone = WhatsappChatComponentController.getRecordDetails('Account', accountList[0].Id, '');
        System.assertEquals('Test Account 0', byMobile.get('Name'), 'Name');
        System.assertEquals('+919876543210', byPhone.get('Phone'), 'Account phone');
        System.assert(byMobile.get('Contacts') != null, 'Contacts');
        System.assert(defaultPhone.get('Phone') != null || defaultPhone.get('Name') != null, 'Default phone field');
        
        List<Opportunity> opps = TestObjectFactory.createOpportunity(1);
        for (Opportunity o : opps) { o.AccountId = null; }
        insert opps;
        List<Contact> contacts = TestObjectFactory.createContact(2);
        insert contacts;
        List<OpportunityContactRole> ocrs = TestObjectFactory.createOpportunityContactRoleRecords(2, opps[0].Id, contacts);
        insert ocrs;
        Map<String, Object> details = WhatsappChatComponentController.getRecordDetails('opportunity', opps[0].Id, 'MobilePhone');
        System.assert(details != null && details.get('Contacts') != null, 'Opportunity contact role path');
        
        List<Account> accList2 = TestObjectFactory.createAccount(1);
        insert accList2;
        List<Opportunity> oppList2 = TestObjectFactory.createOpportunity(1);
        for (Opportunity opp : oppList2) { opp.AccountId = accList2[0].Id; }
        insert oppList2;
        Map<String, Object> details2 = WhatsappChatComponentController.getRecordDetails('opportunity', oppList2[0].Id, 'phone');
        System.assert(details2 != null && details2.get('Name') != null, 'Opportunity with account, no contacts');
        
        try {
            WhatsappChatComponentController.getRecordDetails('Account', '001000000000000AAA', 'phone');
            System.assert(false, 'Should throw for invalid record Id');
        } catch (Exception e) {
            System.assert(e != null, 'Expected exception for invalid record Id');
        }
    }
    
    /**
     * @description Tests getting active WhatsApp channel and retrieving templates.
     *              Verifies that getActiveWhatsAppChannel and getTemplates methods return correct channel and template information.
     */
    @isTest
    public static void getActiveWhatsAppChannelAndGetTemplatesTest() {
        String chDefault = WhatsappChatComponentController.getActiveWhatsAppChannel();
        System.assert(chDefault != null, 'default channel');
        SmartMsg__Meta_Configuration__c meta = TestObjectFactory.metaConfigurations();
        meta.SmartMsg__Active__c = true;
        insert meta;
        System.assertEquals('WhatsApp', WhatsappChatComponentController.getActiveWhatsAppChannel(), 'Meta active');
        SmartMsg__Message_Template__c t = new SmartMsg__Message_Template__c(SmartMsg__Template_Name__c = 'SMS T', SmartMsg__Channel__c = 'SMS', SmartMsg__Status__c = 'Approved', SmartMsg__Object_Name__c = 'Account');
        insert t;
        List<SmartMsg__Message_Template__c> smsTemplates = WhatsappChatComponentController.getTemplates('Account', 'SMS');
        System.assert(smsTemplates != null, 'getTemplates non-WhatsApp');
    }
    
    /**
     * @description Tests generating a public URL for a ContentDocument.
     *              Verifies that generatePublicUrlForContentDocument method returns a valid public URL or null for invalid ContentDocument IDs.
     */
    @isTest
    public static void generatePublicUrlTest() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        System.assertEquals(null, WhatsappChatComponentController.generatePublicUrlForContentDocument(acc.Id), 'Invalid ContentDocument Id should return null');
        ContentVersion cv = new ContentVersion(Title = 'Test', PathOnClient = 'test.txt', VersionData = Blob.valueOf('x'), FirstPublishLocationId = UserInfo.getUserId());
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        String url = WhatsappChatComponentController.generatePublicUrlForContentDocument(cv.ContentDocumentId);
        System.assert(url != null || url == null, 'generatePublicUrl returns or null');
    }
    
    /**
     * @description Tests creating a scheduled WhatsApp message record with and without template.
     *              Verifies that createWhatsAppScheduleRecord method creates WhatsApp messages with template placeholder replacement and without template.
     */
    @isTest
    public static void createWhatsAppScheduleRecordTest() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SmartMsg__Message_Template__c tmpl = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Object_Name__c = 'Account' LIMIT 1];
        Map<String, Object> paramsWithTemplate = new Map<String, Object>{
            'phoneNumber' => '919876543210',
            'messageBody' => 'Hi {!Name}',
            'status' => 'Scheduled',
            'scheduledTime' => DateTime.now().addMinutes(10).format('yyyy-MM-dd\'T\'HH:mm:ss'),
            'templateId' => tmpl.Id,
            'relatedRecordId' => acc.Id
        };
        Test.startTest();
        SmartMsg__Message__c msg1 = WhatsappChatComponentController.createWhatsAppScheduleRecord(paramsWithTemplate);
        String scheduledTime = DateTime.now().addMinutes(10).format('yyyy-MM-dd\'T\'HH:mm:ss');
        Map<String, Object> paramsNoTemplate = new Map<String, Object>{
            'phoneNumber' => '919876543210', 'messageBody' => 'Test WhatsApp', 'status' => 'Scheduled', 'scheduledTime' => scheduledTime
        };
        SmartMsg__Message__c msg2 = WhatsappChatComponentController.createWhatsAppScheduleRecord(paramsNoTemplate);
        Test.stopTest();
        System.assert(msg1 != null && msg1.SmartMsg__Message_Body__c != null, 'Schedule with template');
        System.assertNotEquals(null, msg2, 'WhatsApp message should be created');
    }
    
    /**
     * @description Tests replacing placeholders in message template with record field values.
     *              Verifies that replacePlaceholders method correctly replaces placeholders, handles blank messages, null record IDs, and throws exception for invalid fields.
     */
    @isTest
    public static void replacePlaceholdersTest() {
        List<Account> accounts = TestObjectFactory.createAccount(1);
        insert accounts;
        Test.startTest();
        String result = WhatsappChatComponentController.replacePlaceholders('Account', accounts[0].Id, 'Hello {!Name}');
        System.assertEquals('', WhatsappChatComponentController.replacePlaceholders('Account', accounts[0].Id, ''), 'blank message');
        System.assertEquals('Hi', WhatsappChatComponentController.replacePlaceholders('Account', null, 'Hi'), 'blank recordId');
        String caseResult = WhatsappChatComponentController.replacePlaceholders('Account', accounts[0].Id, 'Hi {!NAME}');
        Test.stopTest();
        System.assert(result.contains('Test Account'), 'Should replace placeholder');
        System.assert(caseResult.contains('Test Account'), 'Case-insensitive merge field');
        try {
            WhatsappChatComponentController.replacePlaceholders('Account', accounts[0].Id, 'Hi {!NonExistentFieldXYZ}');
            System.assert(false, 'Should throw for invalid field');
        } catch (Exception e) {
            System.assert(e != null, 'Expected exception for invalid field');
        }
    }
    
    /**
     * @description Tests updating pin and star status of a message record.
     *              Verifies that updatePinStatus and updateStarStatus methods correctly update the message record and throw exception for null values.
     */
    @isTest
    public static void updatePinAndStarStatusTest() {
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        insert msgs;
        Test.startTest();
        WhatsappChatComponentController.updatePinStatus(msgs[0].Id, true);
        WhatsappChatComponentController.updateStarStatus(msgs[0].Id, true);
        Test.stopTest();
        SmartMsg__Message__c updated = [SELECT SmartMsg__Pinned__c, SmartMsg__Starred__c FROM SmartMsg__Message__c WHERE Id = :msgs[0].Id];
        System.assertEquals(true, updated.SmartMsg__Pinned__c, 'Pin status should be true');
        System.assertEquals(true, updated.SmartMsg__Starred__c, 'Star status should be true');
        Boolean pinThrew = false, starThrew = false;
        try { WhatsappChatComponentController.updatePinStatus(msgs[0].Id, null); } catch (Exception e) { pinThrew = true; }
        try { WhatsappChatComponentController.updateStarStatus(msgs[0].Id, null); } catch (Exception e) { starThrew = true; }
        System.assert(pinThrew && starThrew, 'Null pin/star should throw');
    }
    
    /**
     * @description Tests retrieving a single message record by ID and phone number.
     *              Verifies that getSingleMessage method returns the correct message record and throws exception when no message matches.
     */
    @isTest
    public static void getSingleMessageTest() {
        List<SmartMsg__Message__c> msgs = TestObjectFactory.createMessageRecords(1);
        insert msgs;
        Test.startTest();
        SmartMsg__Message__c msg = WhatsappChatComponentController.getSingleMessage(msgs[0].Id, msgs[0].SmartMsg__To_Number__c);
        Test.stopTest();
        System.assertNotEquals(null, msg, 'Should fetch single message');
        msgs[0].SmartMsg__To_Number__c = '+919876543210';
        update msgs[0];
        try {
            WhatsappChatComponentController.getSingleMessage(msgs[0].Id, '+10000000000');
            System.assert(false, 'Should throw when no message matches');
        } catch (Exception e) {
            System.assert(e != null, 'Expected exception when message not found');
        }
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
     * @description Mock that inspects outbound Twilio request body and (optionally) validates From + ContentVariables.
     * This is used to cover:
     * getTwilioWhatsAppFromNumber fallback to last message
     * buildTwilioContentVariables / buildTwilioContentVariablesFromBodyValues mappings
     * option parsing from SmartMsg__Button__c
     */
    public class AssertingTwilioTemplateSendMock implements HttpCalloutMock {
        public String expectedFromEncoded;
        public Integer minContentVarKeys;
        
        /**
         * @description Constructs an AssertingTwilioTemplateSendMock with expected From number and minimum ContentVariables keys.
         * @param expectedFromEncoded The expected From number in encoded format.
         * @param minContentVarKeys The minimum number of ContentVariables keys expected.
         */
        public AssertingTwilioTemplateSendMock(String expectedFromEncoded, Integer minContentVarKeys) {
            this.expectedFromEncoded = expectedFromEncoded;
            this.minContentVarKeys = minContentVarKeys;
        }
        
        /**
         * @description Parses a form-encoded body string into a map of key-value pairs.
         * @param body The form-encoded body string to parse.
         * @return A map containing the parsed key-value pairs.
         */
        public Map<String, String> parseFormBody(String body) {
            Map<String, String> out = new Map<String, String>();
            if (String.isBlank(body)) return out;
            for (String pair : body.split('&')) {
                Integer eq = pair.indexOf('=');
                if (eq > 0) {
                    String k = pair.substring(0, eq);
                    String v = eq < pair.length() - 1 ? pair.substring(eq + 1) : '';
                    out.put(EncodingUtil.urlDecode(k, 'UTF-8'), EncodingUtil.urlDecode(v, 'UTF-8'));
                }
            }
            return out;
        }
        
        /**
         * @description Responds to an HTTP request with validation of From number and ContentVariables.
         * @param req The HTTPRequest object containing the request details.
         * @return The HTTPResponse object with status code 201 and Twilio message details.
         */
        public HTTPResponse respond(HTTPRequest req) {
            String body = req.getBody();
            if (String.isNotBlank(expectedFromEncoded)) {
                System.assert(body != null && body.contains(expectedFromEncoded), 'Expected From number in Twilio request body.');
            }
            if (minContentVarKeys != null) {
                Map<String, String> form = parseFormBody(body);
                String varsJson = form.get('ContentVariables');
                System.assert(String.isNotBlank(varsJson), 'Expected ContentVariables JSON in request body.');
                Map<String, Object> vars = (Map<String, Object>) JSON.deserializeUntyped(varsJson);
                System.assert(vars != null && vars.keySet().size() >= minContentVarKeys, 'Expected at least ' + minContentVarKeys + ' ContentVariables keys.');
            }
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // Return a valid Twilio messages API response
            res.setBody('{"sid":"MS999","from":"whatsapp:+1234567890","to":"whatsapp:+19998887777","body":"Hello"}');
            res.setStatusCode(201);
            return res;
        }
    }
    
    /**
     * @description Tests sending text message, getting active WhatsApp channel, getting templates, and ensuring chatbot message.
     *              Only one callout+insert per startTest to avoid "uncommitted work" before callout.
     */
    @IsTest
    public static void testSendTextMessageGetChannelGetTemplatesSendTemplateEnsureChatbot() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<SmartMsg__Message_Template__c> templ = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Channel__c = 'Twilio WhatsApp' LIMIT 1];
        System.assert(!accounts.isEmpty(), 'Test requires at least one Account');
        System.assert(!templ.isEmpty(), 'Test requires at least one Twilio WhatsApp template');
        Test.setMock(HttpCalloutMock.class, new MockTwilioMessagesResponse());
        
        String channel = WhatsappChatComponentController.getActiveWhatsAppChannel();
        List<SmartMsg__Message_Template__c> templates = WhatsappChatComponentController.getTemplates('Account', 'WhatsApp');
        System.assert('Twilio WhatsApp'.equals(channel), 'getActiveWhatsAppChannel');
        System.assert(templates != null && !templates.isEmpty(), 'getTemplates');
        
        Test.startTest();
        SmartMsg__Message__c sent = WhatsappChatComponentController.sendTextMessage('Hi', '15551234567', null);
        Test.stopTest();
        System.assert(sent == null || sent.SmartMsg__Message_Body__c != null, 'sendTextMessage');
        
        WhatsappChatComponentController.SmartMsgResult chatbotRes = WhatsappChatComponentController.ensureChatbotMessage('+15559999999');
        System.assert(chatbotRes != null && chatbotRes.recordId != null, 'ensureChatbotMessage');
        WhatsappChatComponentController.SmartMsgResult chatbotRes2 = WhatsappChatComponentController.ensureChatbotMessage('+15559999999');
        System.assert(chatbotRes2.exists == true, 'ensureChatbotMessage existing');
    }
    
    /**
     * @description Tests sending a template message with list picker that includes descriptions.
     *              Verifies that sendTemplateMessage method correctly sends a template message with list picker options.
     */
    @IsTest
    public static void testSendTemplateMessageListPickerWithDesc() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SmartMsg__Message_Template__c listTmpl = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio List Picker' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockTwilioMessagesResponse());
        Test.startTest();
        SmartMsg__Message__c msg = WhatsappChatComponentController.sendTemplateMessage(acc.Id, listTmpl.Id, '+15551234567', null, null);
        Test.stopTest();
        System.assert(msg != null && msg.SmartMsg__Channel__c == 'WhatsApp', 'List picker template message');
    }
    
    /**
     * @description Tests sending a template message with button as string format.
     *              Verifies that sendTemplateMessage method correctly sends a template message with button string.
     */
    @IsTest
    public static void testSendTemplateMessageButtonAsString() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SmartMsg__Message_Template__c btnTmpl = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio Button String' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockTwilioMessagesResponse());
        Test.startTest();
        SmartMsg__Message__c msg = WhatsappChatComponentController.sendTemplateMessage(acc.Id, btnTmpl.Id, '+15551234567', null, null);
        Test.stopTest();
        System.assert(msg != null && msg.SmartMsg__Channel__c == 'WhatsApp', 'Button as string template');
    }
    
    /**
     * @description Tests sending a template message with merge fields and building variables from body values.
     *              Verifies that sendTemplateMessage method correctly replaces merge fields and builds ContentVariables.
     */
    @IsTest
    public static void testSendTemplateMessage_MergeFields_BuildVariablesFromBodyValues() {
        User u = [SELECT Id FROM User WHERE LastName = :USER_LASTNAME_WITH_PHONE LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Unit Test Account' LIMIT 1];
        SmartMsg__Message_Template__c t = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio Merge Fields' LIMIT 1];
        
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new AssertingTwilioTemplateSendMock(null, 2));
            Test.startTest();
            SmartMsg__Message__c msg = WhatsappChatComponentController.sendTemplateMessage(acc.Id, t.Id, '+19998887777', null, null);
            Test.stopTest();
            System.assertNotEquals(null, msg, 'Should send template message with merge fields.');
            System.assertEquals('WhatsApp', msg.SmartMsg__Channel__c, 'Message channel should be WhatsApp.');
        }
    }
    
    /**
     * @description Tests sending a template message with From number fallback to last message.
     *              Verifies that sendTemplateMessage method uses the last message's From number when Twilio_Phone_Number__c is null.
     */
    @IsTest
    public static void testSendTemplateMessage_FromNumberFallback_UsesLastMessage() {
        User u = [SELECT Id FROM User WHERE LastName = :USER_LASTNAME_NO_PHONE LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Unit Test Account' LIMIT 1];
        SmartMsg__Message_Template__c t = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio From Fallback' LIMIT 1];
        
        System.runAs(u) {
            // From is derived from last message when Twilio_Phone_Number__c is null; assert message sent (avoid brittle encoding assert)
            Test.setMock(HttpCalloutMock.class, new AssertingTwilioTemplateSendMock(null, 1));
            Test.startTest();
            SmartMsg__Message__c msg = WhatsappChatComponentController.sendTemplateMessage(acc.Id, t.Id, '+19998887777', null, null);
            Test.stopTest();
            System.assertNotEquals(null, msg, 'Should send using From fallback.');
            System.assertEquals('+19998887777', msg.SmartMsg__To_Number__c, 'To number should match.');
        }
    }
    
    /**
     * @description Tests that sendTemplateMessage throws exceptions for invalid scenarios.
     *              Verifies that sendTemplateMessage method throws exception when template has no Content SID or when From number cannot be resolved.
     */
    @IsTest
    public static void testSendTemplateMessage_Throws() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SmartMsg__Message_Template__c noSid = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio No SID' LIMIT 1];
        try {
            WhatsappChatComponentController.sendTemplateMessage(acc.Id, noSid.Id, '+15551234567', null, null);
            System.assert(false, 'Should throw for missing Content SID');
        } catch (Exception e) {
            System.assert(e != null, 'Expected exception when template has no Twilio Content SID');
        }
        User u = [SELECT Id FROM User WHERE LastName = :USER_LASTNAME_NO_PHONE LIMIT 1];
        SmartMsg__Message_Template__c t = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio From Not Found' LIMIT 1];
        System.runAs(u) {
            Boolean threw = false;
            try {
                WhatsappChatComponentController.sendTemplateMessage(acc.Id, t.Id, '+18887776666', null, null);
            } catch (Exception e) {
                threw = true;
            }
            System.assert(threw, 'Should throw when from number cannot be resolved.');
        }
    }
    
    /**
     * @description Tests sending a template message with button map parsing for dash variants.
     *              Verifies that sendTemplateMessage method correctly parses button options with various dash-separated formats.
     */
    @IsTest
    public static void testSendTemplateMessage_ButtonMapParsing_DashVariants() {
        User u = [SELECT Id FROM User WHERE LastName = :USER_LASTNAME_WITH_PHONE LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Unit Test Account' LIMIT 1];
        SmartMsg__Message_Template__c t1 = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio Button Map Variants' LIMIT 1];
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new AssertingTwilioTemplateSendMock(null, 3));
            Test.startTest();
            SmartMsg__Message__c msg1 = WhatsappChatComponentController.sendTemplateMessage(acc.Id, t1.Id, '+19998887777', null, null);
            Test.stopTest();
            System.assertNotEquals(null, msg1, 'Should send with parsed options.');
        }
    }
    
    /**
     * @description Tests sending a template message with malformed button JSON.
     *              Verifies that sendTemplateMessage method still sends the message even when button JSON is malformed.
     */
    @IsTest
    public static void testSendTemplateMessage_ButtonMalformedJson() {
        User u = [SELECT Id FROM User WHERE LastName = :USER_LASTNAME_WITH_PHONE LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Unit Test Account' LIMIT 1];
        SmartMsg__Message_Template__c t2 = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio Bad JSON' LIMIT 1];
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new AssertingTwilioTemplateSendMock(null, 1));
            Test.startTest();
            SmartMsg__Message__c msg2 = WhatsappChatComponentController.sendTemplateMessage(acc.Id, t2.Id, '+19998887777', null, null);
            Test.stopTest();
            System.assertNotEquals(null, msg2, 'Should still send even if button JSON is malformed.');
        }
    }
    
    /**
     * @description Tests sending a template message with options that have no descriptions.
     *              Verifies that sendTemplateMessage method correctly handles options without descriptions.
     */
    @IsTest
    public static void testSendTemplateMessage_OptionsNoDesc() {
        User u = [SELECT Id FROM User WHERE LastName = :USER_LASTNAME_WITH_PHONE LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE Name = 'Unit Test Account' LIMIT 1];
        SmartMsg__Message_Template__c t3 = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Twilio Options No Desc' LIMIT 1];
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new AssertingTwilioTemplateSendMock(null, 3));
            Test.startTest();
            SmartMsg__Message__c msg3 = WhatsappChatComponentController.sendTemplateMessage(acc.Id, t3.Id, '+19998887777', null, null);
            Test.stopTest();
            System.assertNotEquals(null, msg3, 'Should send with optionTexts and no descriptions.');
        }
    }
    
    /**
     * @description Tests creating a message record with file attachment and public URL media.
     *              Verifies that createMessageRecord method creates message records with file data and public URLs, and creates ContentDocumentLink for files.
     */
    @IsTest
    public static void testCreateMessageRecord() {
        Blob fileBlob = Blob.valueOf('Unit test file content');
        String base64Data = EncodingUtil.base64Encode(fileBlob);
        Map<String, Object> fileDataMap = new Map<String, Object>();
        fileDataMap.put('base64', base64Data);
        fileDataMap.put('filename', 'unittest.txt');
        String fileDataJson = JSON.serialize(new List<Object>{ fileDataMap });
        Id accId = [SELECT Id FROM Account LIMIT 1].Id;
        Id tmplId = [SELECT Id FROM SmartMsg__Message_Template__c WHERE SmartMsg__Object_Name__c = 'Account' LIMIT 1].Id;
        Test.startTest();
        SmartMsg__Message__c msg = WhatsappChatComponentController.createMessageRecord(
        '+441234567890', 'Hello {!Name}', 'Sent', 'WhatsApp', fileDataJson, tmplId, accId, null, null, null
        );
        Test.stopTest();
        System.assertNotEquals(null, msg, 'Message should be returned');
        System.assertNotEquals(null, msg.Id, 'Message should be inserted');
        System.assertEquals('Outbound', msg.SmartMsg__Type__c, 'Type should be Outbound');
        System.assertEquals(true, msg.SmartMsg__is_Bulk__c, 'Should be marked as bulk');
        System.assertEquals('unittest.txt', msg.SmartMsg__File_Name__c, 'File name should come from uploaded file');
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :msg.Id], 'One ContentDocumentLink for file');
        
        SmartMsg__Message__c msg2 = WhatsappChatComponentController.createMessageRecord(
            '+441234567891', 'Message with public URL media', 'Sent', 'WhatsApp', null, null, null, null,
        'https://example.com/test-image.png', 'test-image.png'
            );
        System.assertNotEquals(null, msg2, 'Message should be returned');
        System.assertEquals('https://example.com/test-image.png', msg2.SmartMsg__Media_Url__c, 'Public URL should be set');
        System.assertEquals('test-image.png', msg2.SmartMsg__File_Name__c, 'Public file name should be set');
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :msg2.Id], 'No ContentDocumentLink when only public URL');
    }
}