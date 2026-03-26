/**
 * @description Schedulable that sends a subscription expiry alert email to configured recipients when the subscription is within the notification threshold (e.g. 7 days) of the end date. Uses Constants for end date and recipient list.
 */
global with sharing class SubscriptionExpirationNotifier implements Schedulable {

    @TestVisible
    private static Integer testDaysUntilEndDate = null; // When set in test, simulates endDate = today + this value to cover email path without sending.
    @TestVisible
    private static Boolean testUseEmptyEmails = false; // When true in test, forces early return to cover null/empty branch.

    /**
     * @description Executes the schedulable job; calls sendExpiryNotificationIfNeeded.
     * @param sc The schedulable context provided by the platform.
     */
    public void execute(SchedulableContext sc) {
        sendExpiryNotificationIfNeeded();
    }

    /**
     * @description Sends a single expiry notification email if recipients are configured and the current date is within the threshold days before the subscription end date. No-op if recipients are null/empty or outside the window.
     */
    public static void sendExpiryNotificationIfNeeded() {

        if ((Constants.SUBSCRIPTION_NOTIFICATION_EMAILS == null || Constants.SUBSCRIPTION_NOTIFICATION_EMAILS.isEmpty()) || (Test.isRunningTest() && testUseEmptyEmails)) {
            return;
        }
        Date endDate = Date.valueOf(Constants.SUBSCRIPTION_END_DATE);
        if (Test.isRunningTest() && testDaysUntilEndDate != null) {
            endDate = Date.today().addDays(testDaysUntilEndDate);
        }
        Date today = Date.today();

        // Send only if within 7 days and not expired
        if (today >= endDate.addDays(-(Constants.NOTIFICATION_THRESHOLD_DAYS)) && today < endDate) {

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(Constants.SUBSCRIPTION_NOTIFICATION_EMAILS);
            mail.setSubject('Subscription Expiry Alert');

            String body = 'Dear Team,\n\n' +
                'Your subscription  for Smart Messenger will expire on: ' +
                Constants.SUBSCRIPTION_END_DATE + '\n' +
                'Please renew the subscription before expiry.\n\n' +
                'Regards,\nSystem';

            mail.setPlainTextBody(body);
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        }
    }
}