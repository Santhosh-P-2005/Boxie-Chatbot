@isTest
public class GenericLookupControllerTest {
	@isTest
    public static void searchRelatedContactsWithAccountTest(){
        Account acc = new Account();
        acc.Name = 'Test Account';
        insert acc;
        
        List<Contact> contactList = new List<contact>();
        for(Integer i = 1; i <= 3; i++){
            contact con = new contact();
            con.LastName = 'Test Contact '+i;
            con.AccountId = acc.Id;
            contactList.add(con);
        }
        insert contactList;
        Test.startTest();
		List<Map<String, String>> contactResultList = GenericLookupController.searchRelatedContacts('Account', acc.Id, 'act', '');
        Test.stopTest();
        System.assertEquals(contactList.size(),contactResultList.size(),'Result Miss match');
    }
    
    @isTest
    public static void searchRelatedContactsWithOpportunityTest(){
        contact con = new contact();
        con.LastName = 'Test contact ';
        insert con;
        contact con2 = new contact();
        con2.LastName = 'New contact ';
        insert con2;
        Opportunity opp = new opportunity();
        opp.Name = 'Test Opportunity ';
        opp.CloseDate = System.today();
        opp.StageName = 'Prospecting';
        insert opp;
        List<OpportunityContactRole> opportunityContactRoleList = new List<OpportunityContactRole>();
        for(Integer i = 1; i <= 3; i++){
            OpportunityContactRole ocr = new OpportunityContactRole();
            if(i == 2){
                ocr.ContactId = con2.Id;
            }else{
                ocr.ContactId = con.Id;
            }
            
            ocr.OpportunityId = opp.Id;
            opportunityContactRoleList.add(ocr);
        }
        insert opportunityContactRoleList;
        Test.startTest();
		List<Map<String, String>> contactResultList = GenericLookupController.searchRelatedContacts('Opportunity', opp.Id, 'New', '');
        Test.stopTest();
        System.assertEquals(1,contactResultList.size(),'Result Miss match');
    }
    
    @isTest 
    public static void getInitialRelatedContactsforAccountTest(){
        Account acc = new Account();
        acc.Name = 'Test Account';
        insert acc;
        List<Contact> contactList = new List<Contact>();
        for(Integer i = 1; i <= 3; i++){
            Contact con = new contact();
            con.LastName = 'Test Contact '+i;
            con.AccountId = acc.Id;
            contactList.add(con);
        }
        insert contactList;
        
        Test.startTest();
        List<Map<String, String>> contactResult = GenericLookupController.getInitialRelatedContacts('Account', acc.Id);
        Test.stopTest();
        
        System.assertEquals(4,contactResult.size(),'Count Mis match');
    }
    
    @isTest
    public static void getInitialRelatedContactsforOpportunityTest(){
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity';
        opp.CloseDate = System.today();
        opp.StageName = 'Qualification';
        insert opp;
        
        List<Contact> contactList = new List<Contact>();
        for(Integer i = 0; i < 10; i++){
            contact con = new contact();
            if(Math.mod(i,2) == 0){
                con.LastName = 'New Contact ';
            }else{
                con.LastName = 'Test Contact ';
            }
            contactList.add(con);
        }
        insert contactList;
        
        List<OpportunityContactRole> opportunityContactRoleList = new List<OpportunityContactRole>();
        for(Integer i = 0; i < 10; i++){
            OpportunityContactRole ocr = new OpportunityContactRole();
            ocr.OpportunityId = opp.Id;
            ocr.ContactId = contactList[i].Id;
            opportunityContactRoleList.add(ocr);
        }
        Insert opportunityContactRoleList;
        
        Test.startTest();
        List<Map<String, String>> contactResult = GenericLookupController.getInitialRelatedContacts('Opportunity', opp.Id);
        Test.stopTest();
        System.assertEquals(5,contactResult.size(),'Count Mis match');
    }

	@isTest
    public static void searchRelatedContactsWithNoContactsTest() {
        Account acc = new Account(Name = 'No Contacts Account');
        insert acc;
        Test.startTest();
        List<Map<String, String>> results = GenericLookupController.searchRelatedContacts('Account', acc.Id, 'Missing', '');
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return 0 when no contacts match');
    }
    
    @isTest
    public static void searchRelatedContactsWithCustomFieldsTest() {
        Account acc = new Account(Name = 'Field Account');
        insert acc;
        Contact con = new Contact(LastName = 'FieldTest', AccountId = acc.Id, Title = 'Manager');
        insert con;
        Test.startTest();
        List<Map<String, String>> results = GenericLookupController.searchRelatedContacts('Account', acc.Id, 'Field', 'Name,Title');
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should return 1 contact');
        System.assertEquals('Manager', results[0].get('Title'), 'Title field should be present');
    }
    
    @isTest
    public static void getInitialRelatedContactsForOpportunityNoAccountTest() {
        Opportunity opp = new Opportunity(Name = 'No Account Opp', CloseDate = System.today(), StageName = 'Prospecting');
        insert opp;
        Test.startTest();
        List<Map<String, String>> results = GenericLookupController.getInitialRelatedContacts('Opportunity', opp.Id);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should be 0 when Opportunity has no Account and no OCR');
    }

	@isTest
    public static void getInitialRelatedContactsForOpportunityWithAccountTest() {
        // Step 1: Create an Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    
        // Step 2: Create Contacts linked to the Account
        List<Contact> contactList = new List<Contact>();
        for (Integer i = 1; i <= 3; i++) {
            Contact con = new Contact(LastName = 'Contact ' + i, AccountId = acc.Id, Phone = '555-000' + i, Title = 'Title ' + i);
            contactList.add(con);
        }
        insert contactList;
    
        // Step 3: Create an Opportunity linked to the Account
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = System.today(),
            StageName = 'Prospecting',
            AccountId = acc.Id
        );
        insert opp;
    
        // Step 4: Call the method under test
        Test.startTest();
        List<Map<String, String>> results = GenericLookupController.getInitialRelatedContacts('Opportunity', opp.Id);
        Test.stopTest();
    
        // Step 5: Assert the Account is present
        Boolean accountFound = false;
        Integer contactCount = 0;
        for (Map<String, String> entry : results) {
            if (entry.get('Type') == 'Account' && entry.get('Id') == acc.Id) {
                accountFound = true;
            }
            if (entry.get('Type') == 'Contact') {
                contactCount++;
            }
        }
        System.assert(accountFound, 'Account should be present in the results');
        System.assertEquals(3, contactCount, 'Should return all 3 related contacts');
    }


}