/**
* @description This class is responsible for scheduling and rescheduling a job
*              that runs every minute to process scheduled WhatsApp messages.
*/
// @SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class RunEveryMinSchedule implements Schedulable {

    /**
     * @description Invoked by the system scheduler. Reschedules itself and enqueues the WhatsApp processing job.
     * @param sc The schedulable context provided by the scheduler.
     */
    public void execute(SchedulableContext sc) {
        rescheduleJob();
        updateMessageRecordForInboundMedia();
        System.enqueueJob(new UpdateScheduledWhatsAppMessages());
    }

    /**
     * @description Reschedules the job to run every minute.
     */
    public static void rescheduleJob() {
        // Abort any existing instance of this job
        List<CronTrigger> schJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%RunEveryMinSchedule%'
            WITH SECURITY_ENFORCED
        ];

        if (!schJobs.isEmpty()) {
            System.abortJob(schJobs[0].Id);
        }

        // Schedule one minute from now
        DateTime cDateTime   = DateTime.now();
        DateTime newDateTime = cDateTime.addMinutes(1);
        Integer min          = newDateTime.minute();

        // Run at second 0 of the chosen minute, every hour, every day
        String cronExp = '0 ' + String.valueOf(min) + ' * * * ?';

        System.schedule('RunEveryMinSchedule', cronExp, new RunEveryMinSchedule());
    }
    
    public static void updateMessageRecordForInboundMedia() {
        List<SmartMsg__Message__c> messageList = [SELECT Id, SmartMsg__Media_Url__c FROM SmartMsg__Message__c WHERE SmartMsg__Media_File__c = true WITH SECURITY_ENFORCED ];
        if (messageList.isEmpty()) {
            return;
        }

        List<Id> messageIdList = new List<Id>();
        for (SmartMsg__Message__c msg : messageList) {
            messageIdList.add(msg.Id);
        }

        List<ContentDocumentLink> cdlList = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :messageIdList WITH SECURITY_ENFORCED];
        List<Id> cdlIdList = new List<Id>();
        for(ContentDocumentLink cdl : cdlList){
            cdlIdList.add(cdl.LinkedEntityId);
        }
        List<ContentDocumentLink> cdlListToInsert = new List<ContentDocumentLink>();
        for(SmartMsg__Message__c msg : messageList){
            if(!cdlIdList.contains(msg.Id)){
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.LinkedEntityId = msg.Id;
                cdl.ContentDocumentId = msg.SmartMsg__Media_Url__c;
                cdl.ShareType = 'V';
                cdlListToInsert.add(cdl);
            }
        }
        if(!cdlListToInsert.isEmpty()){
            insert cdlListToInsert;
        }
    }
}