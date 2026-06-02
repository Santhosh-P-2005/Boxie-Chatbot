@isTest
public class RunEveryMinScheduleTest {
  /*  @isTest
    public static void testExecute() {
        List<SmartMsg__Message__c> scheduledMessages = new List<SmartMsg__Message__c>();
        for (Integer i = 0; i < 5; i++) {
            SmartMsg__Message__c message = new SmartMsg__Message__c(
                SmartMsg__Delivery_Status__c = 'Scheduled',
                SmartMsg__Scheduled_Date_Time__c = DateTime.now().addMinutes(-i),
                SmartMsg__To_Number__c = 'TestNumber' + i,
                SmartMsg__Outgoing__c = false,
                SmartMsg__Message_Body__c = 'Test message body ' + i,
                SmartMsg__Channel__c = 'WhatsApp'
            );
            scheduledMessages.add(message);
        }
        insert scheduledMessages;
        Test.startTest();
        RunEveryMinSchedule job = new RunEveryMinSchedule();
        job.execute(null);

        List<SmartMsg__Message__c> updatedMessages = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id IN :scheduledMessages];
        for (SmartMsg__Message__c message : updatedMessages) {
            Assert.areEqual('Sent', message.SmartMsg__Delivery_Status__c, 'Expected delivery status to be Sent');
        }
        Test.stopTest();
    }
    @isTest
    public static void testEnqueueJob() {
        Test.startTest();
        RunEveryMinSchedule job = new RunEveryMinSchedule();
        job.execute(null);
        Integer jobCount = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable' AND ApexClass.Name = 'UpdateScheduledWhatsAppMessages'];
        Assert.areEqual(1, jobCount, 'UpdateScheduledWhatsAppMessages job should be enqueued');
        Test.stopTest();
    }*/
    @isTest
    public static void testRescheduleJob() {
        ContentVersion cv = new ContentVersion(
            Title = 'Inbound Media',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('test-bytes'),
            ContentLocation = 'S'
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        SmartMsg__Message__c mediaMsg = new SmartMsg__Message__c(
            SmartMsg__Delivery_Status__c = 'Received',
            SmartMsg__To_Number__c = '+919876543210',
            SmartMsg__Outgoing__c = false,
            SmartMsg__Message_Body__c = 'Inbound media message',
            SmartMsg__Channel__c = 'WhatsApp',
            SmartMsg__Media_File__c = true,
            SmartMsg__Media_Url__c = cv.ContentDocumentId
        );
        insert mediaMsg;

        SmartMsg__Message__c linkedMediaMsg = new SmartMsg__Message__c(
            SmartMsg__Delivery_Status__c = 'Received',
            SmartMsg__To_Number__c = '+919876543211',
            SmartMsg__Outgoing__c = false,
            SmartMsg__Message_Body__c = 'Already linked media message',
            SmartMsg__Channel__c = 'WhatsApp',
            SmartMsg__Media_File__c = true,
            SmartMsg__Media_Url__c = cv.ContentDocumentId
        );
        insert linkedMediaMsg;
        insert new ContentDocumentLink(
            LinkedEntityId = linkedMediaMsg.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        RunEveryMinSchedule.updateMessageRecordForInboundMedia();
        RunEveryMinSchedule.rescheduleJob();
        Test.stopTest();

        List<ContentDocumentLink> createdLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :mediaMsg.Id
        ];
        System.assertEquals(1, createdLinks.size(), 'ContentDocumentLink should be created for unlinked media message');

        List<CronTrigger> cronTriggers = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%RunEveryMinSchedule%'
        ];
        System.assertEquals(1, cronTriggers.size(), 'Job should be scheduled');
        System.assertEquals('WAITING', cronTriggers[0].State, 'Job state should be WAITING');
        DateTime newDateTime = DateTime.now().addMinutes(1);
        String expectedCronExpression = '0 ' + String.valueOf(newDateTime.minute()) + ' * * * ? ';
        String actualCronExpression = cronTriggers[0].CronExpression.trim();
        System.assertEquals(expectedCronExpression.trim(), actualCronExpression, 'Cron expression should match the expected pattern');
    }
}