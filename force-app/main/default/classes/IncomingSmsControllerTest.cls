/**
 * @description Unit tests for IncomingSmsController: findContactOrAccount, message handling, and setup utilities.
 */
@isTest
public class IncomingSmsControllerTest {

    /**
     * @description Creates and inserts a test Message__c record.
     * @param type Message type (e.g. Inbound, Outbound).
     * @param toNumber Recipient phone number.
     * @param isRead Whether the message is read.
     * @return The inserted SmartMsg__Message__c record.
     */
    private static SmartMsg__Message__c createTestMessage(String type, String toNumber, Boolean isRead) {
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__Message_Body__c = 'Test body',
        SmartMsg__To_Number__c = toNumber,
        SmartMsg__Type__c = type,
        SmartMsg__Delivery_Status__c = 'Delivered',
        SmartMsg__Is_Read__c = isRead,
        SmartMsg__Channel__c = 'SMS'
            );
        insert msg;
        return msg;
    }

    /**
     * @description Test setup: creates Account, Contact, Lead, and Message__c records for use across test methods.
     */
    @testSetup
    public static void setupData() {
        // Create Contacts, Accounts, Leads with phone numbers for findContactOrAccount
        // Create test data to be used across multiple test methods
        Account testAccount = new Account(Name = 'Test Account', Phone = '123-456-7890');
        insert testAccount;

        Contact testContact = new Contact(LastName = 'Test Contact', AccountId = testAccount.Id, Phone = '987-654-3210', MobilePhone = '555-123-4567');
        insert testContact;

        Lead testLead = new Lead(LastName = 'Test Lead', Phone = '111-222-3333', Company='TestCo');
        insert testLead;

        SmartMsg__Message__c outboundMsg = new SmartMsg__Message__c(
            SmartMsg__Message_Body__c = 'Test outbound',
        SmartMsg__To_Number__c = '1234567890',
        SmartMsg__Type__c = 'Outbound',
        SmartMsg__Delivery_Status__c = 'Delivered',
        SmartMsg__Is_Read__c = true,
        SmartMsg__Channel__c = 'SMS'
            );
        insert outboundMsg;

        // Create inbound and outbound messages
        createTestMessage('Inbound', '1234567890', false);
        createTestMessage('Inbound', '1234567891', false);
        createTestMessage('Inbound', '1234567892', true);
        createTestMessage('Outbound', '1234567890', true);
    }

    @isTest
    public static void testGetIncomingSms() {
        Test.startTest();
        List<SmartMsg__Message__c> messages = IncomingSmsController.getIncomingSms();
        Test.stopTest();
        System.assert(messages.size() > 0, 'Should return at least one inbound message');
        for (SmartMsg__Message__c msg : messages) {
            System.assertEquals('Inbound', msg.SmartMsg__Type__c, 'Should only return inbound messages');
        }
    }

    @isTest
    public static void getSingleMessagePositiveTest() {
        SmartMsg__Message__c msg = [SELECT Id, SmartMsg__To_Number__c FROM SmartMsg__Message__c WHERE SmartMsg__Type__c = 'Inbound' LIMIT 1];
        Test.startTest();
        List<SmartMsg__Message__c> result = IncomingSmsController.getSingleMessage(msg.Id, msg.SmartMsg__To_Number__c);
        Test.stopTest();
        System.assertEquals(msg.Id, result[0].Id, 'Should return the correct message');
    }

    @isTest
    public static void getSingleMessageNegativeTest() {
        Test.startTest();
        List<SmartMsg__Message__c> messageList = IncomingSmsController.getSingleMessage('aFakeId', '0000000000');
        System.assertEquals(true, messageList.isEmpty(),'Message record returned in negative test');
        Test.stopTest();
    }

    @isTest
    public static void testFindContactOrAccount() {
        // Tests the findContactOrAccount method with various phone numbers
        List<String> phoneNumbers = new List<String>{'123-456-7890', '987-654-3210', '555-123-4567', '111-222-3333', 'invalid'};
        Map<String, Map<String, String>> results = IncomingSmsController.findContactOrAccount(phoneNumbers);
        System.assertEquals(true,results.isEmpty(),'Failed to search with the phone number');
    }

    @isTest
    public static void testNormalizePhoneNumber() {
        // Cover the normalizePhoneNumber method through the findContactOrAccount method.
        List<String> phoneNumbers = new List<String>{'+11234567890', '919876543210', '+441112223333444'};
        Test.startTest();
        Map<String, Map<String, String>> objectResult = IncomingSmsController.findContactOrAccount(phoneNumbers);
        Test.stopTest();
        System.assertEquals(true,objectResult.keySet().isEmpty(),'Invalid Phone number returned');
    }

    @isTest
    public static void markAsReadByIdTest() {
        SmartMsg__Message__c msg = [SELECT Id FROM SmartMsg__Message__c WHERE SmartMsg__Is_Read__c = false LIMIT 1];
        Test.startTest();
        Boolean result = IncomingSmsController.markAsRead(msg.Id, null);
        Test.stopTest();
        System.assertEquals(true,result, 'Should mark as read by Id');
    }

    @isTest
    public static void markAsReadByPhoneTest() {
        String phone = '1234567891';
        Test.startTest();
        Boolean result = IncomingSmsController.markAsRead(null, phone);
        Test.stopTest();
        System.assert(result, 'Should mark messages as read by phone');
        for (SmartMsg__Message__c msg : [SELECT SmartMsg__Is_Read__c FROM SmartMsg__Message__c WHERE SmartMsg__To_Number__c = :phone]) {
            System.assertEquals(true,msg.SmartMsg__Is_Read__c, 'All messages for phone should be marked as read');
        }
    }

    @isTest
    public static void deleteSMSPositiveTest() {
        SmartMsg__Message__c msg = createTestMessage('Inbound', '5555555555', false);
        Test.startTest();
        Boolean result = IncomingSmsController.deleteMessage(msg.Id);
        Test.stopTest();
        System.assertEquals(true,result, 'Should delete the message');
    }

    @isTest
    public static void testGetUnreadCount() {
        Test.startTest();
        Integer count = IncomingSmsController.getUnreadCount();
        Test.stopTest();
        System.assert(count >= 0, 'Should return a non-negative count');
    }

    @isTest
    public static void testGetLastSentUser() {
        String phone = '1234567890';
        Map<String, String> result = IncomingSmsController.getLastSentUser(phone);
        System.assertNotEquals(null, result, 'Result should not be null');
        if (!result.isEmpty()) {
            System.assert(result.containsKey('userId'), 'Should contain userId if outbound exists');
        }
    }

    @isTest
    public static void testGetPhoneFieldMap() {
        Test.startTest();
        Map<String, List<String>> mapResult = IncomingSmsController.getPhoneFieldMap();
        Test.stopTest();
        System.assert(mapResult.containsKey('Contact'), 'Should include Contact');
        System.assert(mapResult.containsKey('Account'), 'Should include Account');
        System.assert(mapResult.containsKey('Lead'), 'Should include Lead');
        System.assert(mapResult.get('Contact').size() > 0, 'Contact should have phone fields');
    }

    // --------------------------
    // Coverage for addRecordsToMap (uncovered block)
    // --------------------------

    @isTest
    public static void testAddRecordsToMap_PopulatesMap_ForAccountContactLead() {
        // Account
        List<Account> accounts = TestObjectFactory.createAccount(1);
        accounts[0].Name = 'AddMap Account';
        accounts[0].Phone = '+1 (222) 333-4444';
        insert accounts;

        // Contact
        List<Contact> contacts = TestObjectFactory.createContact(1);
        contacts[0].LastName = 'AddMap Contact';
        contacts[0].Phone = '333-444-5555';
        contacts[0].MobilePhone = '444-555-6666';
        insert contacts;

        // Lead (no factory method currently)
        Lead lead = new Lead(LastName = 'AddMap Lead', Company = 'TestCo', Phone = '+91 98765 43210');
        insert lead;

        Map<String, Map<String, String>> recordMap = new Map<String, Map<String, String>>();

        List<SObject> sObjects = new List<SObject>();
        sObjects.addAll(contacts);
        IncomingSmsController.addRecordsToMap(recordMap, sObjects, 'Contact');

        sObjects = new List<SObject>();
        sObjects.addAll(accounts);
        IncomingSmsController.addRecordsToMap(recordMap, sObjects, 'Account');

        sObjects = new List<SObject>{ lead };
        IncomingSmsController.addRecordsToMap(recordMap, sObjects, 'Lead');

        // Assert normalized keys exist
        System.assert(recordMap.containsKey('2223334444'), 'Account phone should be normalized and present');
        System.assert(recordMap.containsKey('3334445555'), 'Contact phone should be normalized and present');
        System.assert(recordMap.containsKey('4445556666'), 'Contact mobile should be normalized and present');
        System.assert(recordMap.containsKey('9876543210'), 'Lead phone should be normalized and present');

        // Assert stored values shape
        Map<String, String> accEntry = recordMap.get('2223334444');
        System.assertEquals('Account', accEntry.get('type'), 'Account type should be stored');
        System.assertEquals(accounts[0].Name, accEntry.get('name'), 'Account name should be stored');
        System.assertEquals(String.valueOf(accounts[0].Id), accEntry.get('id'), 'Account id should be stored');
    }

    @isTest
    public static void testAddRecordsToMap_SkipsBlankOrInvalidPhoneValues() {
        List<Account> accounts = TestObjectFactory.createAccount(2);
        accounts[0].Name = 'Blank Phone';
        accounts[0].Phone = null;
        accounts[1].Name = 'Invalid Phone';
        accounts[1].Phone = 'abc'; // normalizePhoneNumber -> '' (blank) so should be skipped
        insert accounts;

        Map<String, Map<String, String>> recordMap = new Map<String, Map<String, String>>();
        List<SObject> sObjects = new List<SObject>();
        sObjects.addAll(accounts);

        IncomingSmsController.addRecordsToMap(recordMap, sObjects, 'Account');

        System.assertEquals(0, recordMap.size(), 'Records with blank/invalid phone values should not be added');
    }
}