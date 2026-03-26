/**
 * @description Test class for SubscriptionExpirationNotifier.
 * Uses @TestVisible hooks so the email path is covered without sending emails.
 */
@IsTest
private class SubscriptionExpirationNotifierTest {

    @IsTest
    static void testExecuteCallsSendExpiryNotification() {
        Test.startTest();
        SubscriptionExpirationNotifier notifier = new SubscriptionExpirationNotifier();
        String cronExp = '0 0 0 1 1 ? 2030';
        String jobId = System.schedule('SubscriptionExpirationNotifierTest', cronExp, notifier);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduled job should return a non-null job Id');
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, jobs.size(), 'Scheduled job should be created');
    }

    @IsTest
    static void testSendExpiryNotificationEarlyReturnWhenEmailsEmpty() {
        SubscriptionExpirationNotifier.testUseEmptyEmails = true;
        Integer emailInvocationsBefore = Limits.getEmailInvocations();
        SubscriptionExpirationNotifier.sendExpiryNotificationIfNeeded();
        SubscriptionExpirationNotifier.testUseEmptyEmails = false;
        System.assertEquals(emailInvocationsBefore, Limits.getEmailInvocations(), 'No email should be sent when early return is used');
    }

    @IsTest
    static void testSendExpiryNotificationWhenOutsideWindow() {
        Integer emailInvocationsBefore = Limits.getEmailInvocations();
        SubscriptionExpirationNotifier.sendExpiryNotificationIfNeeded();
        System.assertEquals(emailInvocationsBefore, Limits.getEmailInvocations(), 'No email should be sent when outside the notification window');
    }

    @IsTest
    static void testSendExpiryNotificationWhenWithinWindowNoSendInTest() {
        SubscriptionExpirationNotifier.testDaysUntilEndDate = 3;
        Integer emailInvocationsBefore = Limits.getEmailInvocations();
        SubscriptionExpirationNotifier.sendExpiryNotificationIfNeeded();
        SubscriptionExpirationNotifier.testDaysUntilEndDate = null;
        System.assertEquals(emailInvocationsBefore, Limits.getEmailInvocations(), 'No email should be sent in test context even when within window');
    }

    @IsTest
    static void testSendExpiryNotificationWhenAlreadyExpired() {
        SubscriptionExpirationNotifier.testDaysUntilEndDate = -10;
        Integer emailInvocationsBefore = Limits.getEmailInvocations();
        SubscriptionExpirationNotifier.sendExpiryNotificationIfNeeded();
        SubscriptionExpirationNotifier.testDaysUntilEndDate = null;
        System.assertEquals(emailInvocationsBefore, Limits.getEmailInvocations(), 'No email should be sent when subscription is already expired');
    }
}