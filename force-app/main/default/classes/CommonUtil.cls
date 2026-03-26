/**
 * @description Common utility class for performing reusable logic like FLS checks and number evaluations.
 */
public with sharing class CommonUtil {

    /**
     * @description Checks if the given record has Create and Update FLS access for all its custom fields.
     *              Ignores 'attributes' and non-custom fields.
     * @param record The SObject record to check field-level security on.
     * @return Boolean True if all custom fields are Createable or Updateable, False otherwise.
     */
    public static Boolean hasFLS(sObject record) {
        Map<String, Object> rec = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(record));
        String sobjectName = String.valueOf(record.getsobjecttype());
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sobjectName);
        Map<String, Schema.SObjectField> mapSchema = targetType.getDescribe().fields.getMap();
        Boolean isCreateAccess = true;
        for(String fieldToCheck : rec.keySet()) {
            if((fieldToCheck != null) && fieldToCheck <> 'attributes' && mapSchema.get(fieldToCheck) != null && mapSchema.get(fieldToCheck).getDescribe().isCustom() && (!mapSchema.get(fieldToCheck).getDescribe().isCreateable() && (!mapSchema.get(fieldToCheck).getDescribe().isUpdateable()))) {
                isCreateAccess = false;
                break;
            }
        }
        return isCreateAccess;
    }
}