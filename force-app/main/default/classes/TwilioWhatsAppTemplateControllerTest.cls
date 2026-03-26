/**
 * @description Unit tests for TwilioWhatsAppTemplateController.
 */
@isTest
public class TwilioWhatsAppTemplateControllerTest {

    /**
     * @description Mock HTTP response for listing Twilio contents.
     */
    public class ContentListMock implements HttpCalloutMock {
        /**
         * @description Responds to HTTP request with mock content list.
         * @param req The HTTP request object.
         * @return HttpResponse
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"contents":[{"sid":"HX123","friendly_name":"test_template","language":"en","status":"approved"}]}');
            return res;
        }
    }

    /**
     * @description Mock HTTP response for creating Twilio content successfully.
     */
    public class ContentCreateMock implements HttpCalloutMock {
        /**
         * @description Responds to HTTP request with mock content creation success.
         * @param req The HTTP request object.
         * @return HttpResponse
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"sid":"HXNewContentSID456"}');
            return res;
        }
    }

    /**
     * @description Mock HTTP response for content creation failure.
     */
    public class ContentCreateFailMock implements HttpCalloutMock {
        /**
         * @description Responds to HTTP request with mock content creation failure.
         * @param req The HTTP request object.
         * @return HttpResponse
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setStatus('Bad Request');
            res.setBody('{"error":"Invalid payload"}');
            return res;
        }
    }

    /**
     * @description Mock HTTP response: First call returns 201 + sid (content create). Second call returns 400 (approval fails) -> template saved with Failed + Error_Response.
     */
    public class ContentCreateSuccessApprovalFailMock implements HttpCalloutMock {
        /**
         * @description Counter to track the number of HTTP calls made.
         */
        public Integer callCount = 0;
        /**
         * @description Responds to HTTP request with different responses based on call count.
         * @param req The HTTP request object.
         * @return HttpResponse
         */
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(201);
                res.setBody('{"sid":"HXApprovalFailSID"}');
            } else {
                res.setStatusCode(400);
                res.setBody('Meta approval request failed: validation error');
            }
            return res;
        }
    }

    /**
     * @description Same as ContentCreateSuccessApprovalFailMock but approval returns very long error to cover errMsg.length() > 255 truncation.
     */
    public class ContentCreateSuccessApprovalFailLongErrorMock implements HttpCalloutMock {
        /**
         * @description Counter to track the number of HTTP calls made.
         */
        public Integer callCount = 0;
        /**
         * @description Responds to HTTP request with different responses based on call count, including long error message.
         * @param req The HTTP request object.
         * @return HttpResponse
         */
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(201);
                res.setBody('{"sid":"HXLongErrSID"}');
            } else {
                res.setStatusCode(400);
                String longErr = 'x';
                for (Integer i = 0; i < 300; i++) longErr += 'y';
                res.setBody(longErr);
            }
            return res;
        }
    }

    /**
     * @description Tests retrieving all objects for template object picker.
     */
    @isTest
    public static void testGetAllObject() {
        Test.startTest();
        Map<String, String> objects = TwilioWhatsAppTemplateController.getAllObject();
        Test.stopTest();
        System.assert(objects != null, 'getAllObject should return a map');
    }

    /**
     * @description Tests retrieving all fields for an object.
     */
    @isTest
    public static void testGetAllFields() {
        Test.startTest();
        Map<String, String> fields = TwilioWhatsAppTemplateController.getAllFields('Account');
        Test.stopTest();
        System.assert(fields != null, 'getAllFields should return a map');
    }

    /**
     * @description Tests listing all Twilio Content templates.
     */
    @isTest
    public static void testListTwilioContents() {
        Test.setMock(HttpCalloutMock.class, new ContentListMock());
        Test.startTest();
        List<Map<String, String>> contents = TwilioWhatsAppTemplateController.listTwilioContents();
        Test.stopTest();
        System.assert(contents != null, 'listTwilioContents should return a list');
        System.assert(contents.size() == 1, 'Should return one content');
        System.assert(contents[0].get('sid') == 'HX123', 'SID should match');
    }

    /**
     * @description Tests creating and saving a text Twilio Content template.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_Text() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        String templateDataStr = '{"templateName":"Test Text Template","objectName":"Account","bodyText":"Hello {{1}}","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(result != null, 'Result should not be null');
        System.assert(Boolean.valueOf(result.get('success')) == true, 'Create should succeed');
        System.assert(result.get('contentSid') == 'HXNewContentSID456', 'Content SID should match');
        List<SmartMsg__Message_Template__c> templates = [SELECT Id, SmartMsg__Channel__c, SmartMsg__WhatsApp_Template_ID__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Test Text Template' LIMIT 1];
        System.assert(templates.size() == 1, 'One template record should be created');
        System.assert(templates[0].SmartMsg__Channel__c == 'Twilio WhatsApp', 'Channel should be Twilio WhatsApp');
        System.assert(templates[0].SmartMsg__WhatsApp_Template_ID__c == 'HXNewContentSID456', 'Content SID should be stored');
    }

    /**
     * @description Tests creating and saving a Quick Reply Twilio Content template.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_QuickReply() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        List<Object> options = new List<Object>();
        options.add(new Map<String, Object>{ 'text' => 'Yes' });
        options.add(new Map<String, Object>{ 'text' => 'No' });
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'Quick Reply Test',
            'objectName' => 'Contact',
            'bodyText' => '{{1}}',
            'responseType' => 'Button',
            'options' => options
        };
        String templateDataStr = JSON.serialize(data);
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(result != null && Boolean.valueOf(result.get('success')) == true, 'Quick reply template should be created');
    }

    /**
     * @description Tests validation error when creating template with blank name.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ValidationError() {
        String templateDataStr = '{"templateName":"","objectName":"Account","bodyText":"{{1}}","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == false, 'Should fail when template name is blank');
        System.assert(result.get('error') != null, 'Error message should be set');
    }

    /**
     * @description Tests creating List Picker template with description. Covers: options as Map with non-blank description (listPickerWithDescription = true), and buildTwilioListPickerPayloadWithDescription.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ListPickerWithDescription() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        List<Object> options = new List<Object>();
        options.add(new Map<String, Object>{ 'text' => 'Option A', 'description' => 'Desc A' });
        options.add(new Map<String, Object>{ 'text' => 'Option B', 'description' => 'Desc B' });
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'List Picker With Desc',
            'objectName' => 'Account',
            'bodyText' => '{{1}}',
            'responseType' => 'List Picker',
            'options' => options
        };
        String templateDataStr = JSON.serialize(data);
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'List Picker with description should succeed');
    }

    /**
     * @description Tests creating List Picker template with string options. Covers: options as plain String and list-picker without description.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ListPickerOptionsAsStrings() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        List<Object> options = new List<Object>();
        options.add('OptionOne');
        options.add('OptionTwo');
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'List Picker Strings',
            'objectName' => 'Account',
            'bodyText' => '{{1}}',
            'responseType' => 'List Picker',
            'options' => options
        };
        String templateDataStr = JSON.serialize(data);
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'List Picker with string options should succeed');
    }

    /**
     * @description Tests creating List Picker template with hyphenated options. Covers: buildTwilioContentPayload list-picker branch when options contain hyphen.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ListPickerOptionsWithHyphen() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        List<Object> options = new List<Object>();
        options.add('item-with-dash');
        options.add('item-two');
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'List Picker Hyphen',
            'objectName' => 'Account',
            'bodyText' => '{{1}}',
            'responseType' => 'List Picker',
            'options' => options
        };
        String templateDataStr = JSON.serialize(data);
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'List Picker with hyphen in option should succeed');
    }

    /**
     * @description Tests handling of AuraHandledException when Twilio API returns non-200. Covers: catch (AuraHandledException e).
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_AuraHandledException() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateFailMock());
        String templateDataStr = '{"templateName":"Fail Template","objectName":"Account","bodyText":"{{1}}","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == false, 'Should fail on API error');
        System.assert(result.get('error') != null, 'Error should be set from AuraHandledException');
    }

    /**
     * @description Tests handling of generic Exception when invalid JSON is provided. Covers: catch (Exception e).
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_GenericException() {
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate('not valid json');
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == false, 'Should fail on invalid JSON');
        System.assert(result.get('error') != null, 'Error should be set from Exception');
        System.assert(String.valueOf(result.get('error')).startsWith('Failed to create template:'), 'Error message should be generic exception format');
    }

    // ---------- Validation error branches (lines 94-104) ----------

    /**
     * @description Tests validation error when Quick Reply has no options.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_NoOptionsForQuickReply() {
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'No Options Button',
            'objectName' => 'Account',
            'bodyText' => 'Choose one',
            'responseType' => 'Button',
            'options' => new List<Object>()
        };
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(JSON.serialize(data));
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == false, 'Should fail when no options for Button');
        System.assertEquals('At least one option is required for Quick Reply or List Picker.', result.get('error'), 'Error message should match');
    }

    /**
     * @description Tests validation error when Button has more than 3 options.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ButtonMoreThanThreeOptions() {
        List<Object> options = new List<Object>();
        for (Integer i = 0; i < 4; i++) options.add(new Map<String, Object>{ 'text' => 'Opt' + i });
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'Four Buttons',
            'objectName' => 'Account',
            'bodyText' => 'Pick',
            'responseType' => 'Button',
            'options' => options
        };
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(JSON.serialize(data));
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == false, 'Should fail when Button has >3 options');
        System.assertEquals('Quick Reply allows at most 3 buttons.', result.get('error'), 'Error message should match');
    }

    /**
     * @description Tests validation error when List Picker has more than 10 options.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ListPickerMoreThanTenOptions() {
        List<Object> options = new List<Object>();
        for (Integer i = 0; i < 11; i++) options.add('Option' + i);
        Map<String, Object> data = new Map<String, Object>{
            'templateName' => 'Eleven Options',
            'objectName' => 'Account',
            'bodyText' => 'Pick one',
            'responseType' => 'List Picker',
            'options' => options
        };
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(JSON.serialize(data));
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == false, 'Should fail when List Picker has >10 options');
        System.assertEquals('List Picker allows at most 10 options.', result.get('error'), 'Error message should match');
    }

    // ---------- Approval failed: Status Failed + Error_Response (lines 148-151) ----------

    /**
     * @description Tests that template is saved with Failed status when Meta approval fails.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ApprovalFails_TemplateSavedAsFailed() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateSuccessApprovalFailMock());
        String templateDataStr = '{"templateName":"Approval Fail Template","objectName":"Account","bodyText":"Hello","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'Template record should still be created');
        List<SmartMsg__Message_Template__c> templates = [SELECT Id, SmartMsg__Status__c, SmartMsg__Error_Response__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Approval Fail Template' LIMIT 1];
        System.assert(templates.size() == 1, 'One template should be created');
        System.assertEquals('Failed', templates[0].SmartMsg__Status__c, 'Status should be Failed when approval fails');
        System.assert(templates[0].SmartMsg__Error_Response__c != null && templates[0].SmartMsg__Error_Response__c.contains('400'), 'Error_Response should contain approval failure');
    }

    /**
     * @description Tests that long error messages are truncated to 255 characters when approval fails.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_ApprovalFails_LongErrorTruncated() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateSuccessApprovalFailLongErrorMock());
        String templateDataStr = '{"templateName":"Long Err Template","objectName":"Account","bodyText":"Hi","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'Template record should still be created when approval fails (success = true, status = Failed)');
        List<SmartMsg__Message_Template__c> templates = [SELECT Id, SmartMsg__Error_Response__c, SmartMsg__Status__c FROM SmartMsg__Message_Template__c WHERE SmartMsg__Template_Name__c = 'Long Err Template' LIMIT 1];
        System.assert(templates.size() == 1, 'One template should be created');
        System.assertEquals('Failed', templates[0].SmartMsg__Status__c, 'Status should be Failed when approval fails');
        System.assert(templates[0].SmartMsg__Error_Response__c != null && templates[0].SmartMsg__Error_Response__c.length() == 255, 'Error_Response should be truncated to 255');
    }

    // ---------- getBodyVariableDescriptions, mergeFieldToVariableDescription, buildVariablesJson, convertMergeFieldsToTwilioPlaceholders ----------

    /**
     * @description Tests creating text template with blank body.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_TextWithBlankBody() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        String templateDataStr = '{"templateName":"Blank Body Template","objectName":"Account","bodyText":"","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'Text template with blank body should succeed');
    }

    /**
     * @description Tests creating text template with merge fields.
     */
    @isTest
    public static void testCreateAndSaveTwilioContentTemplate_TextWithMergeFields() {
        Test.setMock(HttpCalloutMock.class, new ContentCreateMock());
        String templateDataStr = '{"templateName":"Merge Fields Template","objectName":"Account","bodyText":"Hello {!Name}, your account is {!AccountNumber}.","responseType":"text","options":[]}';
        Test.startTest();
        Map<String, Object> result = TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate(templateDataStr);
        Test.stopTest();
        System.assert(Boolean.valueOf(result.get('success')) == true, 'Text template with merge fields should succeed');
    }

    /**
     * @description Tests mergeFieldToVariableDescription with blank input.
     */
    @isTest
    public static void testMergeFieldToVariableDescription_Blank() {
        Test.startTest();
        String out = TwilioWhatsAppTemplateController.mergeFieldToVariableDescription('');
        Test.stopTest();
        System.assertEquals('Dynamic content will be replaced here', out, 'Blank should return default');
    }

    /**
     * @description Tests mergeFieldToVariableDescription with null input.
     */
    @isTest
    public static void testMergeFieldToVariableDescription_Null() {
        Test.startTest();
        String out = TwilioWhatsAppTemplateController.mergeFieldToVariableDescription(null);
        Test.stopTest();
        System.assertEquals('Dynamic content will be replaced here', out, 'Null should return default');
    }

    /**
     * @description Tests mergeFieldToVariableDescription with non-blank input.
     */
    @isTest
    public static void testMergeFieldToVariableDescription_NonBlank() {
        Test.startTest();
        String out = TwilioWhatsAppTemplateController.mergeFieldToVariableDescription('Name');
        Test.stopTest();
        System.assertEquals('Name will be replaced here', out, 'Non-blank should append suffix');
    }

    /**
     * @description Tests buildVariablesJson with non-empty list and null elements.
     */
    @isTest
    public static void testBuildVariablesJson_NonEmptyAndNullElement() {
        Test.startTest();
        String json1 = TwilioWhatsAppTemplateController.buildVariablesJson(new List<String>{ 'First', 'Second' });
        String json2 = TwilioWhatsAppTemplateController.buildVariablesJson(new List<String>{ 'A', null, 'B' });
        Test.stopTest();
        System.assert(json1.contains('First') && json1.contains('Second') && json1.contains('variables'), 'Non-empty list should produce variable keys and values');
        System.assert(json2.contains('Dynamic content will be replaced here'), 'Null element should use default description');
    }

    /**
     * @description Tests getBodyVariableDescriptions with blank body and body with merge fields.
     */
    @isTest
    public static void testGetBodyVariableDescriptions_BlankAndWithMergeFields() {
        Test.startTest();
        List<String> blank = TwilioWhatsAppTemplateController.getBodyVariableDescriptions('');
        List<String> noMerge = TwilioWhatsAppTemplateController.getBodyVariableDescriptions('Hello world');
        List<String> withMerge = TwilioWhatsAppTemplateController.getBodyVariableDescriptions('Hello {!Name} from {!Account.Name}');
        Test.stopTest();
        System.assert(blank.size() == 1 && blank[0] == 'Body text will be replaced here', 'Blank body should return single description');
        System.assert(noMerge.isEmpty(), 'No merge fields should return empty');
        System.assert(withMerge.size() == 2, 'Two merge fields should return two descriptions');
    }

    /**
     * @description Tests convertMergeFieldsToTwilioPlaceholders with blank input.
     */
    @isTest
    public static void testConvertMergeFieldsToTwilioPlaceholders_Blank() {
        Test.startTest();
        String out = TwilioWhatsAppTemplateController.convertMergeFieldsToTwilioPlaceholders('');
        Test.stopTest();
        System.assertEquals('', out, 'Blank input should return as-is');
    }

    /**
     * @description Tests convertMergeFieldsToTwilioPlaceholders with merge fields.
     */
    @isTest
    public static void testConvertMergeFieldsToTwilioPlaceholders_WithMergeFields() {
        Test.startTest();
        String out = TwilioWhatsAppTemplateController.convertMergeFieldsToTwilioPlaceholders('Hello {!Name}, your id is {!Id}.');
        Test.stopTest();
        System.assertEquals('Hello {{1}}, your id is {{2}}.', out, 'Merge fields should become {{1}}, {{2}}');
    }
}