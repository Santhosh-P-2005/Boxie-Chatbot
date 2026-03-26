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
        Test.startTest();
        RunEveryMinSchedule.RescheduleJob();
        Test.stopTest();
        List<CronTrigger> cronTriggers = [SELECT Id, CronExpression, State FROM CronTrigger WHERE CronJobDetail.Name LIKE '%RunEveryMinSchedule%'];
        Assert.areEqual(1, cronTriggers.size(), 'Job should be scheduled');
        Assert.areEqual('WAITING', cronTriggers[0].State, 'Job state should be WAITING');
        DateTime newDateTime = DateTime.now().addMinutes(1);
        String expectedCronExpression = '0 ' + String.valueOf(newDateTime.minute()) + ' * * * ? ';
        String actualCronExpression = cronTriggers[0].CronExpression.trim();
        Assert.areEqual(expectedCronExpression.trim(), actualCronExpression, 'Cron expression should match the expected pattern');
    }
}