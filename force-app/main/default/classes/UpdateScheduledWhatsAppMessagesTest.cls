/**
 * @description Test class for the UpdateScheduledWhatsAppMessages class.
 */
@isTest
private class UpdateScheduledWhatsAppMessagesTest {
    
    /**
     * @description Sets up test data including WhatsApp credentials.
     * This method inserts a mock WhatsApp credential record into the database.
     */
     @testSetup
    public static void setup() {
        SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getOrgDefaults();
        metaSetting.SmartMsg__Application_Id__c = 'TestApplicationId';
        //metaSetting.App_Secret_key__c = 'TestSecretKey';
        metaSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        metaSetting.SmartMsg__Phone_Number_Id__c = 'TestPhoneNumberId';
        metaSetting.SmartMsg__WhatsApp_Business_Id__c = 'TestWhatsAppBusinessId';
        metaSetting.SmartMsg__Service_Provider_Name__c = 'Meta';
        metaSetting.SmartMsg__Channel__c = 'WhatsApp';
        metaSetting.SmartMsg__Active__c = false;
        insert metaSetting;
    }   
    /**
     * @description Tests the execute method of the UpdateScheduledWhatsAppMessages class.
     * This method creates a list of scheduled messages, enqueues the job, and asserts that the status of the messages remains 'Scheduled'.
     */
    @isTest
    public static void testExecute() {
        List<SmartMsg__Message__c> scheduledMessages = new List<SmartMsg__Message__c>();
        for(Integer i = 0; i < 5; i++) {
            SmartMsg__Message__c msg = new SmartMsg__Message__c(
                SmartMsg__Delivery_Status__c = 'Scheduled',
                SmartMsg__Scheduled_Date_Time__c = System.now().addDays(i),
                SmartMsg__To_Number__c = '1234567890',
                SmartMsg__Outgoing__c = false,
                SmartMsg__Message_Body__c	 = 'Test Message ' + i
            );
            scheduledMessages.add(msg);
        }
        insert scheduledMessages;
        
        Test.startTest();
        System.enqueueJob(new UpdateScheduledWhatsAppMessages());
        Test.stopTest();       
    List<SmartMsg__Message__c> updatedMessages = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id IN :scheduledMessages];
    for(SmartMsg__Message__c msg : updatedMessages) {
       Assert.areEqual('Scheduled', msg.SmartMsg__Delivery_Status__c, 'Expected message status to remain Scheduled after job execution.');
    }
    }
    /**
     * @description Tests the sendWhatsAppMessages method of the UpdateScheduledWhatsAppMessages class.
     * This method creates a test message, sets up an HTTP callout mock, and asserts that the message status changes to 'Sent' after the callout.
     */
    @isTest
    public static void testSendWhatsAppMessages() {
        SmartMsg__Message__c testMsg = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '1234567890',
            SmartMsg__Message_Body__c = 'Test Message',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert testMsg;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        UpdateScheduledWhatsAppMessages.sendWhatsAppMessages(new Set<Id>{testMsg.Id});
        Test.stopTest();
        
        testMsg = [SELECT Id, SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :testMsg.Id];
        Assert.areEqual('Sent', testMsg.SmartMsg__Delivery_Status__c, 'Expected message status to be Sent after callout.');
    }
    /**
     * @description Mock HTTP response generator for HTTP callouts.
     * This class generates a mock HTTP response to simulate the WhatsApp API call.
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        /**
         * @description Responds to the HTTP callout with a mock HTTP response.
         * This method simulates the response from the WhatsApp API by returning a fixed JSON response.
         * @param req The HTTP request object.
         * @return HttpResponse The mock HTTP response object with a status code of 200 and a fixed JSON body.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"messages":[{"id":"1234567890"}]}');
            return res;
        }
    }
}