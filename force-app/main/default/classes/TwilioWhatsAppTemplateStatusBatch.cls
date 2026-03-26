/**
* @description Batch class to sync SmartMsg__Message_Template__c status with Meta/Twilio WhatsApp template approval status.
* Polls Twilio Content API ApprovalRequests for each Pending template in execute() (one callout per batch chunk) and updates Salesforce records to Approved or Failed.
* Use when status callbacks from Meta are not available. Run via TwilioWhatsAppTemplateStatusScheduler (e.g. every hour).
*/
public with sharing class TwilioWhatsAppTemplateStatusBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    private static final String TWILIO_CONTENT_ENDPOINT = 'callout:SmartMsg__Twilio_content_API';
    
    /**
     * @description Returns the query locator for Pending Twilio WhatsApp templates.
     * @param bc The batchable context provided by the batch framework.
     * @return QueryLocator for Message_Template__c records with channel Twilio WhatsApp, status Pending, and non-null WhatsApp_Template_ID__c.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, SmartMsg__WhatsApp_Template_ID__c, SmartMsg__Status__c, SmartMsg__Error_Response__c
            FROM SmartMsg__Message_Template__c
            WHERE SmartMsg__Channel__c = 'Twilio WhatsApp'
            AND SmartMsg__Status__c = 'Pending'
            AND SmartMsg__WhatsApp_Template_ID__c != null
            WITH SECURITY_ENFORCED
        ]);
    }
    
    /**
     * @description For each template in scope, fetches approval status via callout and updates the record if status changed.
     * @param bc The batchable context provided by the batch framework.
     * @param scope The list of Message_Template__c records for this batch chunk.
     */
    public void execute(Database.BatchableContext bc, List<SmartMsg__Message_Template__c> scope) {
        List<SmartMsg__Message_Template__c> toUpdate = new List<SmartMsg__Message_Template__c>();
        SmartMsg__Message_Template__c mt = scope[0];
        String contentSid = mt.SmartMsg__WhatsApp_Template_ID__c;
        if (String.isBlank(contentSid) || !contentSid.startsWith('HX')) {
            return;
        }
        Map<String, Object> approval = fetchApprovalStatus(contentSid);
        if (approval == null) {
            return;
        }
        String twilioStatus = (String) approval.get('status');
        String rejectionReason = (String) approval.get('rejection_reason');
        String newStatus = mapTwilioStatusToSalesforce(twilioStatus);
        if (newStatus == null) {
            return;
        }
        mt.SmartMsg__Status__c = newStatus;
        if ('Approved'.equals(newStatus)) {
            mt.SmartMsg__Error_Response__c = null;
        } else if (String.isNotBlank(rejectionReason)) {
            mt.SmartMsg__Error_Response__c = rejectionReason.length() > 255 ? rejectionReason.substring(0, 255) : rejectionReason;
        }
        if (Schema.sObjectType.SmartMsg__Message_Template__c.isUpdateable() && CommonUtil.hasFLS(mt)) {
            toUpdate.add(mt);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    
    /**
    * @description GET Content/{contentSid}/ApprovalRequests and parse WhatsApp status/rejection_reason.
    * @param contentSid Twilio Content SID (e.g. HX...).
    * @return Map with keys status (lowercase) and optionally rejection_reason; null if call failed or no WhatsApp approval.
    */
    @TestVisible
    private Map<String, Object> fetchApprovalStatus(String contentSid) {
        String endpoint = TWILIO_CONTENT_ENDPOINT + '/' + contentSid + '/ApprovalRequests';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse response;
        try {
            response = http.send(req);
        } catch (Exception e) {
            return null;
        }
        if (response.getStatusCode() != 200) {
            return null;
        }
        Map<String, Object> body;
        try {
            body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        } catch (JSONException e) {
            return null;
        }
        // Response shape: { "sid": "HX...", "whatsapp": { "status": "approved"|"rejected"|"pending", "rejection_reason": "..." } }
        Object whatsappObj = body.get('whatsapp');
        if (whatsappObj instanceof Map<String, Object>) {
            Map<String, Object> whatsapp = (Map<String, Object>) whatsappObj;
            String status = (String) whatsapp.get('status');
            if (String.isNotBlank(status)) {
                Map<String, Object> result = new Map<String, Object>();
                result.put('status', status.toLowerCase());
                Object reason = whatsapp.get('rejection_reason');
                result.put('rejection_reason', reason != null ? String.valueOf(reason) : '');
                return result;
            }
        }
        // Or approval_requests array
        List<Object> approvalRequests = (List<Object>) body.get('approval_requests');
        if (approvalRequests != null && !approvalRequests.isEmpty()) {
            for (Object o : approvalRequests) {
                Map<String, Object> ar = (Map<String, Object>) o;
                whatsappObj = ar.get('whatsapp');
                if (whatsappObj instanceof Map<String, Object>) {
                    Map<String, Object> whatsapp = (Map<String, Object>) whatsappObj;
                    String status = (String) whatsapp.get('status');
                    if (String.isNotBlank(status)) {
                        Map<String, Object> result = new Map<String, Object>();
                        result.put('status', status.toLowerCase());
                        Object reason = whatsapp.get('rejection_reason');
                        result.put('rejection_reason', reason != null ? String.valueOf(reason) : '');
                        return result;
                    }
                }
                String status = (String) ar.get('status');
                if (String.isNotBlank(status)) {
                    Map<String, Object> result = new Map<String, Object>();
                    result.put('status', status.toLowerCase());
                    Object reason = ar.get('rejection_reason');
                    result.put('rejection_reason', reason != null ? String.valueOf(reason) : '');
                    return result;
                }
            }
        }
        return null;
    }
    
    /**
     * @description Maps Twilio/Meta approval status to SmartMsg__Message_Template__c Status picklist. Approved -> Approved; Rejected, Paused, Disabled -> Failed; others (e.g. pending, received) -> null (no update).
     * @param twilioStatus The status string from Twilio/Meta (e.g. approved, rejected, pending).
     * @return 'Approved', 'Failed', or null if no status update should be applied.
     */
    @TestVisible
    private String mapTwilioStatusToSalesforce(String twilioStatus) {
        if (String.isBlank(twilioStatus)) return null;
        String lower = twilioStatus.toLowerCase();
        if (lower == 'approved') return 'Approved';
        if (lower == 'rejected' || lower == 'paused' || lower == 'disabled') return 'Failed';
        return null;
    }

    /**
     * @description Called by the batch framework when all batches have completed. No-op in this implementation.
     * @param bc The batchable context provided by the batch framework.
     */
    public void finish(Database.BatchableContext bc) {
        Integer i = 0;
        i++;
    }
}