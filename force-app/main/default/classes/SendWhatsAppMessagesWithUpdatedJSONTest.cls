/**
 * @description Unit tests for SendWhatsAppMessagesWithUpdatedJSON Queueable (Meta WhatsApp send and session update).
 */
@IsTest
public class SendWhatsAppMessagesWithUpdatedJSONTest {

    /**
     * @description Mock HTTP callout that returns a configurable response for Meta API tests.
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse mockResponse;

        /**
         * @description Constructs the mock with the given response.
         * @param response The HttpResponse to return from respond().
         */
        public MockHttpResponseGenerator(HttpResponse response) {
            this.mockResponse = response;
        }

        /**
         * @description Responds to the HTTP request with the configured mocked response.
         * @param req The HTTP request to respond to.
         * @return The mocked HTTP response.
         */
        public HttpResponse respond(HttpRequest req) {
            return mockResponse;
        }
    }

    @IsTest
    public static void getInitialRecordWithButtons(){
        List<SmartMsg__Option_Dialog__c> databaseOptionDialogList = TestObjectFactory.optionDialogRecords();
        insert databaseOptionDialogList;
        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));
        //(String response, List<String> quickReplyButtonsList, String type,String toNumber
        List<String> quickReplyButtonsList = new List<String>();
        List<SmartMsg__Option_Dialog__c> optionDialogList = [SELECT Id,SmartMsg__Inbound_Response__c,SmartMsg__Inbound_Response__r.SmartMsg__Response__c,SmartMsg__Inbound_Response__r.SmartMsg__Question__c,SmartMsg__Inbound_Response__r.Id,SmartMsg__Inbound_Response__r.SmartMsg__Type__c,SmartMsg__Outbound_Response__c FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'Hi'];
        for(SmartMsg__Option_Dialog__c optionDialog : optionDialogList){
            if(optionDialog.SmartMsg__Inbound_Response__r.SmartMsg__Question__c != null){
                quickReplyButtonsList.add(optionDialog.SmartMsg__Inbound_Response__r.SmartMsg__Question__c);
            }
        }
        Map<String,Object> payload = WhatsAppChatBot.dynamicJSON(optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c,quickReplyButtonsList,optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Type__c,'12345');
        Test.startTest();
        System.enqueueJob(new SendWhatsAppMessagesWithUpdatedJSON(payload,optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c,'12345',optionDialogList[0].SmartMsg__Inbound_Response__r.Id,optionDialogList[0].Id,false));
        Test.stopTest();
        List<SmartMsg__Message__c> lastOutBoundMessageRecord = [SELECT Id, SmartMsg__Dialogue__r.Id, SmartMsg__Dialogue__r.SmartMsg__Response__c
                                            FROM SmartMsg__Message__c WHERE SmartMsg__Type__c = 'Outbound' ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('Welcome to Storage Space.\n Choose your language',lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Response__c,'Response not mismatching');
    }

   /* @IsTest
    public static void sendTextMessages(){
        List<SmartMsg__Option_Dialog__c> databaseOptionDialogList = TestObjectFactory.optionDialogRecords();
        insert databaseOptionDialogList;
        List<SmartMsg__Dialogue__c> dialogList = [SELECT Id FROM SmartMsg__Dialogue__c WHERE SmartMsg__Question__c = 'Existing Customer' LIMIT 1];
        SmartMsg__Message__c messageRecord = new SmartMsg__Message__c();
        messageRecord.SmartMsg__Type__c = 'Outbound';
        messageRecord.SmartMsg__To_Number__c = '12345';
        messageRecord.SmartMsg__Dialogue__c = dialogList[0].Id;
        insert messageRecord;

        SmartMsg__Meta_Configuration__c metaConfigurations = TestObjectFactory.metaConfigurations();
        insert metaConfigurations;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"messages":[{"id":"wamid.HBgLNTEyMzQ1Njc4OTA"}]}');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(res));

        List<String> quickReplyButtonsList = new List<String>();
        List<SmartMsg__Option_Dialog__c> optionDialogList = [SELECT Id,SmartMsg__Inbound_Response__c,SmartMsg__Inbound_Response__r.SmartMsg__Response__c,SmartMsg__Inbound_Response__r.SmartMsg__Question__c,SmartMsg__Inbound_Response__r.Id,SmartMsg__Inbound_Response__r.SmartMsg__Type__c,SmartMsg__Outbound_Response__c FROM SmartMsg__Option_Dialog__c WHERE SmartMsg__Inbound_Response__r.SmartMsg__Question__c = 'Followup pickup'];
        for(SmartMsg__Option_Dialog__c optionDialog : optionDialogList){
            if(optionDialog.SmartMsg__Inbound_Response__r.SmartMsg__Question__c != null){
                quickReplyButtonsList.add(optionDialog.SmartMsg__Inbound_Response__r.SmartMsg__Question__c);
            }
        }
        Map<String,Object> payload = WhatsAppChatBot.dynamicJSON(optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c,quickReplyButtonsList,optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Type__c,'12345');
        Test.startTest();
        System.enqueueJob(new SendWhatsAppMessagesWithUpdatedJSON(payload,optionDialogList[0].SmartMsg__Inbound_Response__r.SmartMsg__Response__c,'12345',optionDialogList[0].SmartMsg__Inbound_Response__r.Id,optionDialogList[0].Id,false));
        Test.stopTest();
        List<SmartMsg__Message__c> lastOutBoundMessageRecord = [SELECT Id, SmartMsg__Dialogue__r.Id, SmartMsg__Dialogue__r.SmartMsg__Response__c
                                            FROM SmartMsg__Message__c WHERE SmartMsg__Type__c = 'Outbound' ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('Select any one of the options',lastOutBoundMessageRecord[0].SmartMsg__Dialogue__r.SmartMsg__Response__c,'Response not mismatching');
    }*/
}