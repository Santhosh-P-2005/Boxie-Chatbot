/**
 * @description Trigger handler for SmartMsg__Dialogue__c. Validates buttons and options on before insert and before update.
 */
public class DialogTriggerHandler {

    /**
     * @description Runs validation for new Dialogue records before insert.
     * @param dialogList List of new SmartMsg__Dialogue__c records being inserted.
     */
    public static void beforeInsert(List<SmartMsg__Dialogue__c> dialogList){
        buttonsAndOptionsValidation(dialogList,null);
    }

    /**
     * @description Runs validation for Dialogue records before update.
     * @param dialogList List of SmartMsg__Dialogue__c records being updated.
     * @param oldDialog Map of existing SmartMsg__Dialogue__c records by Id before the update.
     */
    public static void beforeUpdate(List<SmartMsg__Dialogue__c> dialogList, Map<Id,SmartMsg__Dialogue__c> oldDialog){
        buttonsAndOptionsValidation(dialogList,oldDialog);
    }

    /**
     * @description Validates Buttons_or_Options__c: Button/Separate Button allows max 3 items and 20 chars per item; Option allows max 10 items.
     * @param dialogList List of SmartMsg__Dialogue__c records to validate.
     * @param oldDialog Map of existing records by Id, or null for insert context.
     */
    public static void buttonsAndOptionsValidation(List<SmartMsg__Dialogue__c> dialogList, Map<Id,SmartMsg__Dialogue__c> oldDialog){
        if(!dialogList.isEmpty()){
            for(SmartMsg__Dialogue__c dialog : dialogList){
                SmartMsg__Dialogue__c oldDialogMap = oldDialog != null ? oldDialog.get(dialog.Id) : null ;
                if((oldDialogMap == null) || oldDialogMap != null && (oldDialogMap.SmartMsg__Buttons_or_Options__c != dialog.SmartMsg__Buttons_or_Options__c || oldDialogMap.SmartMsg__Type__c != dialog.SmartMsg__Type__c)){
                    if(dialog.SmartMsg__Type__c == 'Button' || dialog.SmartMsg__Type__c == 'Separate Button'){
                        if(dialog.SmartMsg__Buttons_or_Options__c != null){
                            List<String> buttonValuesList = dialog.SmartMsg__Buttons_or_Options__c.split('\n');
                            if(buttonValuesList.size() > 3){
                                dialog.SmartMsg__Buttons_or_Options__c.addError('Only 3 buttons could be added');
                            }else {
                                for(String button : buttonValuesList){
                                    if(button.length() > 20 ){
                                        dialog.SmartMsg__Buttons_or_Options__c.addError('" '+button +' "' + ' Exceeds the character limit of 20');
                                    }
                                }
                            }
                        }
                    }else{
                        if(dialog.SmartMsg__Type__c == 'Option'){
                            if(dialog.SmartMsg__Buttons_or_Options__c != null){
                                List<String> buttonValuesList = dialog.SmartMsg__Buttons_or_Options__c.split('\n');
                                if(buttonValuesList.size() > 10){
                                    dialog.SmartMsg__Buttons_or_Options__c.addError('Only 10 Options could be added');
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}