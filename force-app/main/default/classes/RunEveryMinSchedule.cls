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
}