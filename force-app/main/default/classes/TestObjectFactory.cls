/**
 * @description TODO: method description
*/
public with sharing class TestObjectFactory {
    
    /*public static void getAgentResponse(String inputMessage, String toNumber) {

        String sessionId;
        String agentResponse;
        // Map<String, String> agentResult = new Map<String, String>();
        try {
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse', 
                'Copilot_for_Salesforce'
            );
            action.setInvocationParameter('userMessage', inputMessage);
            if (String.isNotBlank(sessionId)) {
                action.setInvocationParameter('sessionId', sessionId);
            }
            List<Invocable.Action.Result> results = action.invoke();
            Invocable.Action.Result result = results[0];
            System.debug('result -> ' + result);

            if (result.isSuccess()) {
                Map<String, Object> outputParams = result.getOutputParameters();
                Object agentResponseObj = outputParams.get('agentResponse');
                Map<String, Object> agentResponseMap;
                if (agentResponseObj instanceof String) {
                    agentResponseMap = (Map<String, Object>) JSON.deserializeUntyped((String)agentResponseObj);
                } 
                else {
                    agentResponseMap = (Map<String, Object>) agentResponseObj;
                }
                agentResponse = (String) agentResponseMap.get('value');
                sessionId = (String)outputParams.get('sessionId');
                System.debug('sessionId -> ' + sessionId);
                System.debug('agentResponse -> ' + agentResponse);

                WhatsAppServices.sendTextMessage(agentResponse, toNumber);
            }
        } 
        catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }*/
	/**
     * @description create the test account records
     * @param num
	 * @return List<Account>
     */
	public static List<Account> createAccount(Integer num){
		List<Account> accountList = new List<Account>();
		for(Integer i = 0; i < num; i++){
			Account acc = new Account();
			acc.Name = 'Test Account '+ i;
			acc.phone = '919876543210';
			accountList.add(acc);
		}
		return accountList;
	}
	/**
     * @description create the test contact records
     * @param num
	 * @return List<contact>
     */
	public static  List<contact> createContact(Integer num){
		List<Contact> contactList = new List<Contact>();
		for(Integer i = 0; i < num; i++){
			contact con = new contact();
			con.LastName = 'Test Contact '+i;
			con.MobilePhone = '919876543210';
			contactList.add(con);
		}
		return contactList;
	}
	/**
     * @description create the test opportunity records
     * @param num
	 * @return List<opportnity>
     */
	public static  List<opportunity> createOpportunity(Integer num){
		List<opportunity> opportunityList = new List<opportunity>();
		for(Integer i = 0; i < num; i++){
			opportunity opp = new opportunity();
			opp.Name = 'Test opportunity '+i;
			opp.stageName = 'Prospecting';
			opp.closeDate = System.today();
			opportunityList.add(opp);
		}
		return opportunityList;
	}
    /**
     * @description create the test message records
     * @param num
	 * @return List<SmartMsg__Message__c>
     */
    public static List<SmartMsg__Message__c> createMessageRecords(Integer num){
        List<SmartMsg__Message__c> messageRecordsList = new List<SmartMsg__Message__c>();
        for(Integer i = 0; i < num; i++){
            SmartMsg__Message__c message = new SmartMsg__Message__c();
            message.SmartMsg__Delivery_Status__c = 'Delivered';
            message.SmartMsg__Channel__c = 'SMS';
            message.SmartMsg__To_Number__c = '919876543210';
            message.SmartMsg__Delivery_Status__c = 'Scheduled';
            message.SmartMsg__Message_ID__c = '12345';
            message.SmartMsg__Business_Phone_Number__c = '123-456-7890';
            messageRecordsList.add(message);
        }
        return messageRecordsList;
    }
    /**
     * @description create the test opportunity contact role records
     * @param num The number of OpportunityContactRole records (and Contacts) to create.
 	 * @param opportunityId The Id of the Opportunity to which the contacts will be linked.
	 * @param contactList The list of Contacts to be linked to the Opportunity.
	 * @return List<OpportunityContactRole>
     */
    public static List<OpportunityContactRole> createOpportunityContactRoleRecords(Integer num, Id opportunityId,List<Contact> contactList){
        List<OpportunityContactRole> opportunityContactRoleList = new List<OpportunityContactRole>();
       	for(Integer i = 0; i < num; i++){
            OpportunityContactRole ocr = new OpportunityContactRole();
            ocr.OpportunityId = opportunityId;
			ocr.ContactId = contactList[i].Id;
            opportunityContactRoleList.add(ocr);
        }
        return opportunityContactRoleList;
    }
    /**
     * @description Creates a list of SmartMsg__Dialogue__c records with predefined values.
     * @param num The number of dialogue records to create
     * @return A list of SmartMsg__Dialogue__c records
     */
    public static List<SmartMsg__Dialogue__c> createDialogRecords(Integer num){
            List<SmartMsg__Dialogue__c> dialogList = new List<SmartMsg__Dialogue__c>();
            for(Integer i = 0; i < num; i++){
                SmartMsg__Dialogue__c dialog = new SmartMsg__Dialogue__c();
                dialog.SmartMsg__Question__c = 'Hi';
                dialog.SmartMsg__Response__c = 'Test Response';
                dialogList.add(dialog);
            }
            return dialogList;
    }
    /**
     * @description Retrieves and configures a default Meta Configuration record for testing purposes.
     * @return A SmartMsg__Meta_Configuration__c record with test values set
     */
    public static SmartMsg__Meta_Configuration__c metaConfigurations(){
            SmartMsg__Meta_Configuration__c metaSetting = SmartMsg__Meta_Configuration__c.getOrgDefaults();
            metaSetting.SmartMsg__Application_Id__c = 'TestApplicationId';
            metaSetting.App_Secret_key__c = 'TestSecretKey';
            metaSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
            metaSetting.SmartMsg__Phone_Number_Id__c = 'TestPhoneNumberId';
            metaSetting.SmartMsg__WhatsApp_Business_Id__c = 'TestWhatsAppBusinessId';
            metaSetting.SmartMsg__Service_Provider_Name__c = 'Meta';
            metaSetting.SmartMsg__Channel__c = 'WhatsApp';
            metaSetting.SmartMsg__Active__c = false;
            return metaSetting;
        }

    /**
     * @description Creates/returns Twilio WhatsApp custom setting for tests.
     * Note: No DML operations are performed. Test classes should upsert the returned record.
     * @return SmartMsg__Twilio_Whatsapp__c The custom setting record (not inserted)
     */
    public static SmartMsg__Twilio_Whatsapp__c twilioWhatsAppSettings() {
        SmartMsg__Twilio_Whatsapp__c twilioWhatsappSetting = SmartMsg__Twilio_Whatsapp__c.getOrgDefaults();
        twilioWhatsappSetting.SmartMsg__Account_SID__c = 'ACTestAccountSID';
        twilioWhatsappSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        twilioWhatsappSetting.SmartMsg__Channel__c = 'Twilio_WhatsApp';
        twilioWhatsappSetting.SmartMsg__Service_Provider_Name__c = 'Twilio';
        twilioWhatsappSetting.SmartMsg__Messaging_Service_SID__c = 'TestTwilioWhatsAppMessagingServiceSID';
        twilioWhatsappSetting.SmartMsg__Twilio_Phone_Number__c = '+1234567890';
        twilioWhatsappSetting.SmartMsg__StatusCallbackUrl__c = 'TestCallbackUrl';
        twilioWhatsappSetting.SmartMsg__Active__c = false;
        return twilioWhatsappSetting;
    }

    /**
     * @description Creates/returns Twilio Configuration (SMS) custom setting for tests.
     * Note: No DML operations are performed. Test classes should upsert the returned record.
     * @return SmartMsg__TwilioConfiguration__c The custom setting record (not inserted)
     */
    public static SmartMsg__TwilioConfiguration__c twilioConfigurationSettings() {
        SmartMsg__TwilioConfiguration__c twilioSetting = SmartMsg__TwilioConfiguration__c.getOrgDefaults();
        twilioSetting.SmartMsg__Account_SID__c = 'TestAccountSID';
        twilioSetting.SmartMsg__Auth_Token__c = 'TestAuthToken';
        twilioSetting.SmartMsg__Channel__c = 'SMS';
        twilioSetting.SmartMsg__Messaging_Service_SID__c = 'TestMessagingServiceSID';
        twilioSetting.SmartMsg__Service_Provider_Name__c = 'Twilio';
        twilioSetting.SmartMsg__Twilio_Phone_Number__c = '1234567890';
        twilioSetting.SmartMsg__StatusCallbackUrl__c = 'TestCallbackUrl';
        twilioSetting.SmartMsg__Environment_Id__c = 'TestEnvironmentId';
        twilioSetting.SmartMsg__MediaBaseUrl__c = 'TestMediaBaseUrl';
        twilioSetting.SmartMsg__Service_Id__c = 'TestServiceId';
        twilioSetting.SmartMsg__Active__c = false;
        return twilioSetting;
    }
    /**
     * @description Returns a list of SmartMsg__Option_Dialog__c records for WhatsApp messenger bot.
     * @return List<SmartMsg__Option_Dialog__c> List of option dialog records
     */
    public static List<SmartMsg__Option_Dialog__c> optionDialogRecords(){
            SmartMsg__Messenger_Bot__c bot = new SmartMsg__Messenger_Bot__c();
            bot.Name = 'WhatsApp';
            bot.SmartMsg__Active__c  = true;
            Database.insert(bot, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog1 = new SmartMsg__Dialogue__c();
            dialog1.SmartMsg__Question__c = 'Hi';
            dialog1.SmartMsg__Parent_Template__c = bot.Id;
            dialog1.SmartMsg__Response__c = 'Welcome to Storage Space.\n Choose your language';
            dialog1.SmartMsg__Type__c = 'button';
            Database.insert(dialog1, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog2 = new SmartMsg__Dialogue__c();
            dialog2.SmartMsg__Question__c = 'English';
            dialog2.SmartMsg__Parent_Template__c = bot.Id;
            dialog2.SmartMsg__Response__c = 'How Can I help you.Choose the options';
            dialog2.SmartMsg__Type__c = 'option';
            Database.insert(dialog2, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog3 = new SmartMsg__Dialogue__c();
            dialog3.SmartMsg__Question__c = 'Nederlands';
            dialog3.SmartMsg__Parent_Template__c = bot.Id;
            dialog3.SmartMsg__Response__c = 'How Can I help you.Choose the options';
            dialog3.SmartMsg__Type__c = 'option';
            Database.insert(dialog3, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog4 = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'New Customer',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Question Based'
            );
            Database.insert(dialog4, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog5 = new SmartMsg__Dialogue__c(
            SmartMsg__Parent_Record__c = dialog4.Id,
            SmartMsg__Response__c = 'please enter your name',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Order_Number__c = 1,
            SmartMsg__Type__c = 'Separate Text'
            );
            Database.insert(dialog5, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog6 = new SmartMsg__Dialogue__c(
            SmartMsg__Parent_Record__c = dialog4.Id,
            SmartMsg__Response__c = 'What Storage size do you need?',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Order_Number__c = 2,
            SmartMsg__Buttons_or_Options__c = '1m²\n2m²\n3m²\n4m²',
            SmartMsg__Type__c = 'option'
            );
            Database.insert(dialog6, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog7 = new SmartMsg__Dialogue__c(
            SmartMsg__Parent_Record__c = dialog4.Id,
            SmartMsg__Response__c = 'For how long do you need storage?',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Order_Number__c = 3,
            SmartMsg__Buttons_or_Options__c = '3 Months\n6 Months\n12 Months',
            SmartMsg__Type__c = 'option'
            );
            Database.insert(dialog7, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog8 = new SmartMsg__Dialogue__c(
            SmartMsg__Response__c = 'Is there anything else I can help you with?',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Buttons_or_Options__c = 'Yes\nNo',
            SmartMsg__Type__c = 'Separate Button'
            );
            Database.insert(dialog8, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog9 = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Existing Customer',
            SmartMsg__Response__c = 'Select any one of the options',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'option'
            );
            Database.insert(dialog9, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog10 = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Invoice Question',
            SmartMsg__Response__c = 'Invoice related queries',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Separate Text'
            );
            Database.insert(dialog10, AccessLevel.USER_MODE);

            SmartMsg__Dialogue__c dialog11 = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'Followup pickup',
            SmartMsg__Response__c = 'You can followup based on your pcikup',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Separate Text'
            );
            Database.insert(dialog11, AccessLevel.USER_MODE);
            SmartMsg__Dialogue__c dialog12 = new SmartMsg__Dialogue__c(
            SmartMsg__Question__c = 'No, that\'s all.',
            SmartMsg__Response__c = 'Thank you for contacting us',
            SmartMsg__Parent_Template__c = bot.Id,
            SmartMsg__Type__c = 'Separate Text'
            );
            Database.insert(dialog12, AccessLevel.USER_MODE);

            List<SmartMsg__Option_Dialog__c> optionDialogList = new List<SmartMsg__Option_Dialog__c>{
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog1.Id,
                    SmartMsg__Outbound_Response__c = dialog2.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog2.Id,
                    SmartMsg__Outbound_Response__c = dialog4.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog2.Id,
                    SmartMsg__Outbound_Response__c = dialog9.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog9.Id,
                    SmartMsg__Outbound_Response__c = dialog10.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog9.Id,
                    SmartMsg__Outbound_Response__c = dialog11.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog4.Id,
                    SmartMsg__Outbound_Response__c = dialog5.Id,
                    SmartMsg__Order_Number__c = 1
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog4.Id,
                    SmartMsg__Outbound_Response__c = dialog6.Id,
                    SmartMsg__Order_Number__c = 2
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog4.Id,
                    SmartMsg__Outbound_Response__c = dialog7.Id,
                    SmartMsg__Order_Number__c = 3
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog7.Id,
                    SmartMsg__Outbound_Response__c = dialog8.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog10.Id,
                    SmartMsg__Outbound_Response__c = dialog8.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog11.Id,
                    SmartMsg__Outbound_Response__c = dialog8.Id
                ),
                new SmartMsg__Option_Dialog__c(
                    SmartMsg__Inbound_Response__c = dialog12.Id
                )
            };
            //insert optionDialogList;
            return optionDialogList;
    }

    /**
     * @description Creates a ProtectedSettingsWrapper for Meta WhatsApp configuration
     * @param num Numeric suffix for unique test values
     * @return ProtectedSettingsWrapper The wrapper object with test values
     */
    public static ProtectedSettingsWrapper createMetaWhatsAppWrapper(Integer num) {
        ProtectedSettingsWrapper wrapper = new ProtectedSettingsWrapper();
        wrapper.name = 'MetaSetting' + num;
        wrapper.applicationId = 'ApplicationId' + num;
        wrapper.appSecretKey = 'SecretKey' + num;
        wrapper.authToken = 'AuthToken' + num;
        wrapper.channel = 'WhatsApp';
        wrapper.isActive = false;
        wrapper.phoneNumberId = 'PhoneNumberId' + num;
        wrapper.serviceProviderName = 'Meta';
        wrapper.whatsAppBusinessId = 'WhatsAppBusinessId' + num;
        return wrapper;
    }

    /**
     * @description Creates a ProtectedSettingsWrapper for Twilio SMS configuration
     * @param num Numeric suffix for unique test values
     * @return ProtectedSettingsWrapper The wrapper object with test values
     */
    public static ProtectedSettingsWrapper createTwilioSMSWrapper(Integer num) {
        ProtectedSettingsWrapper wrapper = new ProtectedSettingsWrapper();
        wrapper.name = 'TwilioSMSSetting' + num;
        wrapper.accountSID = 'AccountSID' + num;
        wrapper.authToken = 'AuthToken' + num;
        wrapper.channel = 'SMS';
        wrapper.isActive = false;
        wrapper.messagingServiceSID = 'MessagingServiceSID' + num;
        wrapper.serviceProviderName = 'Twilio';
        wrapper.twilioPhoneNumber = 'Phone' + num;
        wrapper.statusCallbackUrl = 'CallbackUrl' + num;
        wrapper.environmentId = 'EnvironmentId' + num;
        wrapper.mediaBaseUrl = 'MediaBaseUrl' + num;
        wrapper.serviceId = 'ServiceId' + num;
        return wrapper;
    }

    /**
     * @description Creates a ProtectedSettingsWrapper for Twilio WhatsApp configuration
     * @param num Numeric suffix for unique test values
     * @return ProtectedSettingsWrapper The wrapper object with test values
     */
    public static ProtectedSettingsWrapper createTwilioWhatsAppWrapper(Integer num) {
        ProtectedSettingsWrapper wrapper = new ProtectedSettingsWrapper();
        wrapper.name = 'TwilioWhatsAppSetting' + num;
        wrapper.accountSID = 'TwilioWhatsAppAccountSID' + num;
        wrapper.authToken = 'TwilioWhatsAppAuthToken' + num;
        wrapper.channel = 'Twilio_WhatsApp';
        wrapper.isActive = false;
        wrapper.messagingServiceSID = 'TwilioWhatsAppMessagingServiceSID' + num;
        wrapper.serviceProviderName = 'Twilio';
        wrapper.twilioPhoneNumber = '+91987654321' + num;
        wrapper.statusCallbackUrl = 'TwilioWhatsAppCallbackUrl' + num;
        wrapper.fromPhoneNumbers = '+919874563210,+919802315467';
        return wrapper;
    }

    /**
     * @description Creates test SmartMsg__Message_Template__c records for Twilio WhatsApp template status sync tests.
     * @param num Number of records to create
     * @param channel Channel value (e.g. 'Twilio WhatsApp')
     * @param status Status value (e.g. 'Pending', 'Approved')
     * @param whatsAppTemplateId WhatsApp Template ID / Content SID (e.g. HX...). If null, a default HX SID is used.
     * @return List of SmartMsg__Message_Template__c records (not inserted)
     */
    public static List<SmartMsg__Message_Template__c> createMessageTemplateRecords(Integer num, String channel, String status, String whatsAppTemplateId) {
        List<SmartMsg__Message_Template__c> listOut = new List<SmartMsg__Message_Template__c>();
        String contentSid = String.isNotBlank(whatsAppTemplateId) ? whatsAppTemplateId : 'HX12345678901234567890123456789012';
        for (Integer i = 0; i < num; i++) {
            SmartMsg__Message_Template__c mt = new SmartMsg__Message_Template__c();
            mt.SmartMsg__Template_Name__c = 'Sync Test Template ' + i;
            mt.SmartMsg__Channel__c = channel != null ? channel : 'Twilio WhatsApp';
            mt.SmartMsg__Status__c = status != null ? status : 'Pending';
            mt.SmartMsg__WhatsApp_Template_ID__c = contentSid;
            mt.SmartMsg__Template_API_Name__c = 'sync_test_template_' + i;
            mt.SmartMsg__Object_Name__c = 'Account';
            listOut.add(mt);
        }
        return listOut;
    }
}