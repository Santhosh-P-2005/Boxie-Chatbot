@isTest
public class DialogTriggerHandlerTest {

    /**
     * @description Tests the insert context, verifying the 3-button limit 
     * and the 20-character limit for 'Button' and 'Separate Button' types.
     */
    @isTest
    static void testButtonInsertValidations() {
        List<SmartMsg__Dialogue__c> dialogsToInsert = new List<SmartMsg__Dialogue__c>();
        
        // 1. Valid Button (<= 3 items, <= 20 chars)
        dialogsToInsert.add(new SmartMsg__Dialogue__c(
            SmartMsg__Type__c = 'Button',
            SmartMsg__Buttons_or_Options__c = 'Btn 1\nBtn 2'
        ));
        
        // 2. Invalid Button Count (> 3 items)
        dialogsToInsert.add(new SmartMsg__Dialogue__c(
            SmartMsg__Type__c = 'Button',
            SmartMsg__Buttons_or_Options__c = 'Btn 1\nBtn 2\nBtn 3\nBtn 4'
        ));
        
        // 3. Invalid Button Length (> 20 chars) using 'Separate Button' to cover that branch
        dialogsToInsert.add(new SmartMsg__Dialogue__c(
            SmartMsg__Type__c = 'Separate Button',
            SmartMsg__Buttons_or_Options__c = 'This is a very long button text\nBtn 2'
        ));
        
        Test.startTest();
        // Use Database.insert with allOrNone = false so the test doesn't crash on addError
        Database.SaveResult[] results = Database.insert(dialogsToInsert, false);
        Test.stopTest();
        
        // Assertions to verify the specific errors were caught
        System.assertEquals(true, results[0].isSuccess(), 'First record should insert successfully.');
        
        System.assertEquals(false, results[1].isSuccess(), 'Second record should fail due to > 3 buttons limit.');
        System.assert(results[1].getErrors()[0].getMessage().contains('Only 3 buttons could be added'), 'Incorrect error message for button count.');
        
        System.assertEquals(false, results[2].isSuccess(), 'Third record should fail due to > 20 characters limit.');
        System.assert(results[2].getErrors()[0].getMessage().contains('Exceeds the character limit of 20'), 'Incorrect error message for character limit.');
    }
    
    /**
     * @description Tests the update context, verifying the 10-option limit 
     * for the 'Option' type.
     */
    @isTest
    static void testOptionUpdateValidations() {
        List<SmartMsg__Dialogue__c> dialogsToInsert = new List<SmartMsg__Dialogue__c>();
        
        // Insert initially valid Option records
        dialogsToInsert.add(new SmartMsg__Dialogue__c(
            SmartMsg__Type__c = 'Option',
            SmartMsg__Buttons_or_Options__c = 'Opt 1\nOpt 2'
        ));
        dialogsToInsert.add(new SmartMsg__Dialogue__c(
            SmartMsg__Type__c = 'Option',
            SmartMsg__Buttons_or_Options__c = 'Opt 1\nOpt 2'
        ));
        
        // Insert should succeed cleanly
        insert dialogsToInsert; 
        
        // Modify records to test update trigger
        // 1. Valid update (still <= 10 options)
        dialogsToInsert[0].SmartMsg__Buttons_or_Options__c = 'Opt 1\nOpt 2\nOpt 3';
        
        // 2. Invalid update (> 10 options)
        dialogsToInsert[1].SmartMsg__Buttons_or_Options__c = '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11';
        
        Test.startTest();
        // Use Database.update with allOrNone = false
        Database.SaveResult[] updateResults = Database.update(dialogsToInsert, false);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, updateResults[0].isSuccess(), 'First record should update successfully.');
        
        System.assertEquals(false, updateResults[1].isSuccess(), 'Second record should fail due to > 10 options.');
        System.assert(updateResults[1].getErrors()[0].getMessage().contains('Only 10 Options could be added'), 'Incorrect error message for option limit.');
    }
}