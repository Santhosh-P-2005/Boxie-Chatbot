@isTest
public class SMSTriggerHandlerMinimalTest {

    @isTest
    public static void sMSTest() {
        // Arrange: Create a SmartMsg__Message__c record that qualifies for bulk SMS
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
			SmartMsg__To_Number__c = '91874523587',
            SmartMsg__is_Bulk__c = true,
            SmartMsg__channel__c = 'SMS'
        );
        insert msg;

        // Act: Call afterInsert
        Test.startTest();
        SMSTriggerHandlerMinimal.afterInsert(new List<SmartMsg__Message__c>{msg});
        Test.stopTest();

        // Assert: A job should be enqueued (check AsyncApexJob)
        List<AsyncApexJob> jobs = [SELECT Id, Status, JobType FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assert(!jobs.isEmpty(), 'Queueable job should be enqueued for bulk SMS');
    }

    @isTest
    public static void smsRecordWithNoBulkTest() {
        // Arrange: Create a non-bulk SMS message
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__is_Bulk__c = false,
			SmartMsg__To_Number__c = '91874523587',
            SmartMsg__channel__c = 'SMS'
        );
        insert msg;

        // Act: Call afterInsert
        Test.startTest();
        SMSTriggerHandlerMinimal.afterInsert(new List<SmartMsg__Message__c>{msg});
        Test.stopTest();

        // Assert: No job should be enqueued
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assertEquals(0, jobs.size(), 'No job should be enqueued for non-bulk SMS');
    }

    @isTest
    public static void sendSMS() {
        // Arrange: Create a bulk message, but not SMS channel
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__is_Bulk__c = true,
			SmartMsg__To_Number__c = '91874523587',
            SmartMsg__channel__c = 'WhatsApp'
        );
        insert msg;

        // Act: Call afterInsert
        Test.startTest();
        SMSTriggerHandlerMinimal.afterInsert(new List<SmartMsg__Message__c>{msg});
        Test.stopTest();

        // Assert: No job should be enqueued
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assertEquals(0, jobs.size(), 'No job should be enqueued for non-SMS channel');
    }

    @isTest
    public static void emptyMessageRecordListTest() {
        // Act: Call afterInsert with empty list
        Test.startTest();
        SMSTriggerHandlerMinimal.afterInsert(new List<SmartMsg__Message__c>());
        Test.stopTest();

        // Assert: No job should be enqueued
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assertEquals(0, jobs.size(), 'No job should be enqueued for empty list');
    }

    /**
     * @description Covers updateSession: Inbound messages per session (new key 46-47, increment 49-51, session update loop 56-57).
     * Uses in-memory messages (not inserted) so the handler runs once; session is inserted so the SOQL finds it and updates it.
     */
    @isTest
    public static void updateSessionInboundCountTest() {
        SmartMsg__Messaging_Session__c session = new SmartMsg__Messaging_Session__c(
            SmartMsg__To_Number__c = '91874523587',
            SmartMsg__Session_status__c = 'Customer Message Received',
            SmartMsg__No_of_Inbound_Messages__c = 0
        );
        insert session;

        List<SmartMsg__Message__c> inboundMessages = new List<SmartMsg__Message__c>{
            new SmartMsg__Message__c(
                SmartMsg__Type__c = 'Inbound',
                SmartMsg__Messaging_Session__c = session.Id,
                SmartMsg__To_Number__c = '91874523587',
            	SmartMsg__channel__c = 'SMS'
            ),
            new SmartMsg__Message__c(
                SmartMsg__Type__c = 'Inbound',
                SmartMsg__Messaging_Session__c = session.Id,
                SmartMsg__To_Number__c = '91874523587',
            	SmartMsg__channel__c = 'SMS'
            )
        };
        insert inboundMessages;

        /*Test.startTest();
        SMSTriggerHandlerMinimal.afterInsert(inboundMessages);
        Test.stopTest();*/

        SmartMsg__Messaging_Session__c updated = [SELECT Id, SmartMsg__No_of_Inbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id = :session.Id];
        System.assertEquals(2, updated.SmartMsg__No_of_Inbound_Messages__c, 'Session should have 2 inbound messages counted');
    }
}