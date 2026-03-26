/**
 * @description Unit tests for TwilioWhatsAppTemplateStatusBatch (template approval status sync via Twilio Content API).
 */
@isTest
private class TwilioWhatsAppTemplateStatusBatchTest {

    /**
     * @description Mock for Twilio Content ApprovalRequests API returning approved status.
     */
    private class ApprovalApprovedMock implements HttpCalloutMock {
        /**
         * @description Returns a 200 response with whatsapp status approved.
         * @param req The HTTP request (unused).
         * @return HttpResponse with JSON body indicating approved.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"whatsapp":{"status":"approved","rejection_reason":""}}');
            return res;
        }
    }

    /**
     * @description Mock for Twilio Content ApprovalRequests API returning rejected status with reason.
     */
    private class ApprovalRejectedMock implements HttpCalloutMock {
        /**
         * @description Returns a 200 response with whatsapp status rejected and rejection_reason.
         * @param req The HTTP request (unused).
         * @return HttpResponse with JSON body indicating rejected.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"whatsapp":{"status":"rejected","rejection_reason":"Placeholder at end of message"}}');
            return res;
        }
    }

    /**
     * @description Mock for Twilio Content ApprovalRequests API returning pending status.
     */
    private class ApprovalPendingMock implements HttpCalloutMock {
        /**
         * @description Returns a 200 response with whatsapp status pending.
         * @param req The HTTP request (unused).
         * @return HttpResponse with JSON body indicating pending.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"whatsapp":{"status":"pending","rejection_reason":""}}');
            return res;
        }
    }

    /**
     * @description Mock for Twilio Content ApprovalRequests API returning approval_requests array format.
     */
    private class ApprovalRequestsArrayMock implements HttpCalloutMock {
        /**
         * @description Returns a 200 response with approval_requests array containing approved whatsapp status.
         * @param req The HTTP request (unused).
         * @return HttpResponse with JSON body containing approval_requests array.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"approval_requests":[{"whatsapp":{"status":"approved","rejection_reason":""}}]}');
            return res;
        }
    }

    /**
     * @description Batch updates Pending template to Approved when Meta returns approved.
     */
    @isTest
    public static void testSyncUpdatesToApproved() {
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', 'HX12345678901234567890123456789012');
        insert templates;
        System.assert(templates[0].SmartMsg__Status__c == 'Pending', 'Should start Pending');

        Test.setMock(HttpCalloutMock.class, new ApprovalApprovedMock());
        Test.startTest();
        Database.executeBatch(new TwilioWhatsAppTemplateStatusBatch(), 1);
        Test.stopTest();

        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assert(updated.SmartMsg__Status__c == 'Approved', 'Status should be Approved');
        System.assert(updated.SmartMsg__Error_Response__c == null, 'Error should be cleared');
    }

    /**
     * @description Batch updates Pending template to Failed when Meta returns rejected and stores rejection reason.
     */
    @isTest
    public static void testSyncUpdatesToFailed() {
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', 'HX12345678901234567890123456789012');
        insert templates;

        Test.setMock(HttpCalloutMock.class, new ApprovalRejectedMock());
        Test.startTest();
        Database.executeBatch(new TwilioWhatsAppTemplateStatusBatch(), 1);
        Test.stopTest();

        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assert(updated.SmartMsg__Status__c == 'Failed', 'Status should be Failed');
        System.assert(updated.SmartMsg__Error_Response__c != null && updated.SmartMsg__Error_Response__c.contains('Placeholder'), 'Rejection reason should be stored');
    }

    /**
     * @description Batch leaves Status Pending when Meta still returns pending.
     */
    @isTest
    public static void testSyncLeavesPendingWhenMetaStillPending() {
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', 'HX12345678901234567890123456789012');
        insert templates;

        Test.setMock(HttpCalloutMock.class, new ApprovalPendingMock());
        Test.startTest();
        Database.executeBatch(new TwilioWhatsAppTemplateStatusBatch(), 1);
        Test.stopTest();

        SmartMsg__Message_Template__c unchanged = [SELECT Id, SmartMsg__Status__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assert(unchanged.SmartMsg__Status__c == 'Pending', 'Status should remain Pending');
    }

    /**
     * @description Batch parses approval_requests array response and updates to Approved.
     */
    @isTest
    public static void testSyncWithApprovalRequestsArrayResponse() {
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Pending', 'HX12345678901234567890123456789012');
        insert templates;

        Test.setMock(HttpCalloutMock.class, new ApprovalRequestsArrayMock());
        Test.startTest();
        Database.executeBatch(new TwilioWhatsAppTemplateStatusBatch(), 1);
        Test.stopTest();

        SmartMsg__Message_Template__c updated = [SELECT Id, SmartMsg__Status__c FROM SmartMsg__Message_Template__c WHERE Id = :templates[0].Id];
        System.assert(updated.SmartMsg__Status__c == 'Approved', 'Should parse approval_requests array');
    }

    /**
     * @description Batch with no pending templates completes without error.
     */
    @isTest
    public static void testSyncNoPendingDoesNotThrow() {
        List<SmartMsg__Message_Template__c> templates = TestObjectFactory.createMessageTemplateRecords(1, 'Twilio WhatsApp', 'Approved', 'HX12345678901234567890123456789012');
        insert templates;

        Test.startTest();
        Database.executeBatch(new TwilioWhatsAppTemplateStatusBatch(), 1);
        Test.stopTest();
        System.assert(true, 'Sync with no pending templates should complete');
    }
}