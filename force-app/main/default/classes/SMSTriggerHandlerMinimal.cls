/**
* @description Handler class for SMSTriggerMinimal trigger.
*              Contains logic for filtering bulk SMS messages and invoking the SMS queueable.
*/
public class SMSTriggerHandlerMinimal {

    /**
* @description Filters SMS messages and triggers SMS sending if conditions are met.
* @param newMessageList List of new SmartMsg__Message__c records.
*/
    public static void afterInsert(List<SmartMsg__Message__c> newMessageList){
        callingSMSQueable(newMessageList);
        updateSession(newMessageList);
        // whatsAppChatBots(newMessageList);
        //educationIndustryBot(newMessageList);
    }

    /**
* @description Filters the messages marked as Bulk SMS and enqueues the TwilioSMSQueueable job.
* @param newMessageList List of SmartMsg__Message__c records to evaluate.
*/
    public static void callingSMSQueable(List<SmartMsg__Message__c> newMessageList){
        List<SmartMsg__Message__c> bulkSMSList = new List<SmartMsg__Message__c>();

        for(SmartMsg__Message__c sms : newMessageList) {
            if(sms.SmartMsg__is_Bulk__c && sms.SmartMsg__channel__c == 'SMS') {
                bulkSMSList.add(sms);
            }
        }

        if(!bulkSMSList.isEmpty()) {
            //System.debug('Trigger SMS queueable');
            System.enqueueJob(new TwilioSMSQueueable(bulkSMSList));
        }
    }

    /**
     * @description Updates Messaging_Session__c inbound message counts for sessions referenced by the new inbound messages.
     * @param newMessageList List of new Message__c records from the trigger.
     */
    public static void updateSession(List<SmartMsg__Message__c> newMessageList) {
        Map<Id,Integer> sessionIdWithIncomingCountMap = new Map<Id,Integer>();

        for(SmartMsg__Message__c message : newMessageList){
			// System.debug('ChatComponentController.getActiveChannel() -> '+ChatComponentController.getActiveChannel());
            if(message.SmartMsg__Type__c == 'Inbound' && message.SmartMsg__channel__c == 'SMS'){
                if(!sessionIdWithIncomingCountMap.containsKey(message.SmartMsg__Messaging_Session__c)){
                    sessionIdWithIncomingCountMap.put(message.SmartMsg__Messaging_Session__c,0);
                }
                Integer count = sessionIdWithIncomingCountMap.get(message.SmartMsg__Messaging_Session__c);
                count++;
                sessionIdWithIncomingCountMap.put(message.SmartMsg__Messaging_Session__c,count);
            }
        }
        List<SmartMsg__Messaging_Session__c> messagingSessionList = [SELECT Id, SmartMsg__To_Number__c,  SmartMsg__Session_status__c, SmartMsg__No_of_Inbound_Messages__c,SmartMsg__No_of_Outbound_Messages__c FROM SmartMsg__Messaging_Session__c WHERE Id IN : sessionIdWithIncomingCountMap.keySet() WITH SECURITY_ENFORCED];
        if(!messagingSessionList.isEmpty()){
            for(SmartMsg__Messaging_Session__c session : messagingSessionList){
                session.SmartMsg__No_of_Inbound_Messages__c = session.SmartMsg__No_of_Inbound_Messages__c + sessionIdWithIncomingCountMap.get(session.Id);
            }
        }
        if(!messagingSessionList.isEmpty()){
            /*if (!Schema.sObjectType.SmartMsg__Messaging_Session__c.isUpdateable()) {
                 throw new AuraHandledException('You do not have permission to update Messaging_Session__c.');
            }*/
            update messagingSessionList;
        }
    }
}