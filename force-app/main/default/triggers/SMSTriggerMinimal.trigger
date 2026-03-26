/**
 * @description Trigger to handle SmartMsg__Message__c events. 
 * All logic is delegated to the SMSTriggerHandlerMinimal class.
 */
trigger SMSTriggerMinimal on SmartMsg__Message__c (after insert) {
   SMSTriggerHandlerMinimal.afterInsert(Trigger.new);
    //System.debug(Trigger.new);
}