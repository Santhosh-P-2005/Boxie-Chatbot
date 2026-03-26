trigger DialogTrigger on SmartMsg__Dialogue__c (before insert, before update) {
    if(Trigger.isBefore && Trigger.isInsert){
        DialogTriggerHandler.beforeInsert(Trigger.new);
    }
    if(Trigger.isBefore && Trigger.isUpdate){
		DialogTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap); 
    }

}