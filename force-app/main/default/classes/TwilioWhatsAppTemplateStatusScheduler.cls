/**
 * @description Schedulable job to sync Twilio WhatsApp template approval status from Meta/Twilio to SmartMsg__Message_Template__c.
 * Run every hour so Pending templates are updated to Approved or Failed once Meta completes review (callbacks not available).
 * Schedule once via: System.schedule('Twilio WhatsApp Template Status Sync', '0 0 * * * ?', new TwilioWhatsAppTemplateStatusScheduler());
 */
global with sharing class TwilioWhatsAppTemplateStatusScheduler implements Schedulable {

    /**
     * @description Schedulable execute: enqueues TwilioWhatsAppTemplateStatusBatch to sync Pending template status from Twilio/Meta.
     * @param sc The schedulable context (unused).
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TwilioWhatsAppTemplateStatusBatch(), 1);
    }
}