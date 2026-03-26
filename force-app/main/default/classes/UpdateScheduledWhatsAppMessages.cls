/**
 *  @description This class implements a Queueable interface to handle the updating and sending of scheduled WhatsApp messages.
 * It retrieves scheduled WhatsApp messages that are due for delivery, sends them out using WhatsApp API, and updates their delivery status.
 */
public with sharing class UpdateScheduledWhatsAppMessages implements Queueable,Finalizer  {
    
    public static  String messagingProduct = 'messaging_product';
    public Contacts[] contacts;
    public Messages[] messages;
    /**
     * @description A nested class representing a WhatsApp contact.
     */
    public class Contacts {
        public String input;
    }
    /**
     * @description A nested class representing a WhatsApp message.
     */
    public class Messages {
        public String id;
    }
    /**
     * @description Executes the queueable job to update and send scheduled WhatsApp messages.
     * Retrieves scheduled WhatsApp messages due for delivery and sends them out.
     * Updates the delivery status and message ID upon successful delivery.
     * @param context The queueable context.
     */
    public void execute(QueueableContext context) {
        Set<Id> scheduledMessageIds = new Set<Id>();
        List<SmartMsg__Message__c> scheduledMessages = [SELECT Id, SmartMsg__Delivery_Status__c, SmartMsg__Scheduled_Date_Time__c, SmartMsg__To_Number__c,SmartMsg__Outgoing__c,SmartMsg__Message_Body__c  FROM SmartMsg__Message__c  WHERE SmartMsg__Delivery_Status__c = 'Scheduled' AND SmartMsg__Scheduled_Date_Time__c <= :DateTime.now() AND SmartMsg__Channel__c = 'WhatsApp' With SECURITY_ENFORCED];
        for (SmartMsg__Message__c message : scheduledMessages) {
            scheduledMessageIds.add(message.Id);
        }
        if (!scheduledMessageIds.isEmpty()) {
            sendWhatsAppMessages(scheduledMessageIds);
        }
        System.attachFinalizer(this);
    }
    /**
     * @description Executes the finalizer logic.
     * @param ctx The FinalizerContext object containing the result of the parent job.
     */
    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.SUCCESS) {
            Integer i = 0;
            i++;
        } 
    }
    /**
     * @description Sends WhatsApp messages based on the provided message IDs.
     * @param scheduledMessageIds The IDs of scheduled WhatsApp messages to be sent.
     */
    @future(callout=true)
    public static void sendWhatsAppMessages(Set<Id> scheduledMessageIds) {
        List<SmartMsg__Message__c> messages = [SELECT Id, SmartMsg__To_Number__c, SmartMsg__Type__c, SmartMsg__Message_Body__c, SmartMsg__Delivery_Status__c, SmartMsg__Scheduled_Date_Time__c FROM SmartMsg__Message__c WHERE Id IN :scheduledMessageIds With SECURITY_ENFORCED];
        if (!Schema.sObjectType.Message__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update this message.');
        }
        SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        if (whatsAppCreds != null) {
            String endpointUrl = 'callout:SmartMsg__Meta_API/v19.0/' + whatsAppCreds.SmartMsg__Phone_Number_Id__c + '/messages';
            List<SmartMsg__Message__c> messagesToUpdate = new List<SmartMsg__Message__c>();
            for (SmartMsg__Message__c message : messages) {
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(endpointUrl);
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
                httpReq.setHeader('Pragma', 'no-cache');
                httpReq.setHeader('Expires', '0');
                httpReq.setHeader('X-Content-Type-Options', 'nosniff');
                String toPhone = message.SmartMsg__To_Number__c;
                String messageContent = message.SmartMsg__Message_Body__c;
                String messageBody = '{'+
                    +messagingProduct+ ' : "whatsapp",'+
                    '    "recipient_type": "individual",'+
                    '    "to": "'+toPhone+'",'+
                    '    "type": "text",'+
                    '    "text": {'+
                    '        "preview_url": false,'+
                    '        "body": "'+messageContent+'"'+
                    '    }'+
                    '}';
                
                httpReq.setBody(messageBody);
                Http http = new Http();
                try {
                    HttpResponse response = http.send(httpReq);
                    if (response.getStatusCode() == 200) {
                        whatsAppServices responseFromWA = (whatsAppServices) JSON.deserialize( response.getBody() , whatsAppServices.class);
                        message.SmartMsg__Message_ID__c = responseFromWA.messages.get(0).id;
                        message.SmartMsg__To_Number__c = toPhone;
                        message.SmartMsg__Message_Type__c = 'text';
                        message.SmartMsg__Delivery_Status__c = 'Sent';
                        message.SmartMsg__Outgoing__c = true;
                        message.SmartMsg__Type__c = 'Outbound';
                        message.SmartMsg__Sent_Date_and_Time__c = DateTime.now();
                        messagesToUpdate.add(message);
                        SmartMsg__Incoming_Message__e statusEvent = new SmartMsg__Incoming_Message__e(
                            SmartMsg__Event_Type__c = 'Outbound',
                        SmartMsg__Record_Id__c = message.Id,
                        SmartMsg__Delivery_Status__c = message.SmartMsg__Delivery_Status__c,
                        SmartMsg__From_Number__c = message.SmartMsg__To_Number__c  // Using To_Number__c since it's outbound
                            );
                        EventBus.publish(statusEvent);
                    }
                } catch (System.CalloutException ex) {
                    throw new AuraHandledException('CalloutException: ' + ex.getMessage());
                }
                
            }
            
            if (!messagesToUpdate.isEmpty()) {
                if (Schema.sObjectType.SmartMsg__Message__c.isUpdateable() && CommonUtil.hasFLS(messagesToUpdate[0])) {
                    update messagesToUpdate;
                }
                else {
                    throw new AuraHandledException('You do not have the necessary field permissions to update Message__c records.');
                }
            }
        } else {
            throw new AuraHandledException('WhatsApp credentials not found.');
        }
    }
    
}