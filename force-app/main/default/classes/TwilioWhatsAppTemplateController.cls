/**
 * @description Controller for Twilio WhatsApp Content Template creation from UI.
 * Lists/create Twilio Content templates via Content API and saves to SmartMsg__Message_Template__c.
 */
public with sharing class TwilioWhatsAppTemplateController {

    public static final String TWILIO_CONTENT_ENDPOINT = 'callout:SmartMsg__Twilio_content_API';

    /**
     * @description Lists all Twilio Content templates.
     * @return List<Map<String, String>>
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> listTwilioContents() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(TWILIO_CONTENT_ENDPOINT);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse response = http.send(req);
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('Twilio Content API error: ' + response.getStatus());
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            List<Object> contents = (List<Object>) body.get('contents');
            if (contents == null) {
                return result;
            }
            for (Object obj : contents) {
                Map<String, Object> content = (Map<String, Object>) obj;
                Map<String, String> item = new Map<String, String>();
                item.put('sid', (String) content.get('sid'));
                item.put('friendly_name', (String) content.get('friendly_name'));
                item.put('language', content.get('language') != null ? String.valueOf(content.get('language')) : '');
                item.put('status', (String) content.get('status'));
                result.add(item);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error listing Twilio contents: ' + e.getMessage());
        }
        return result;
    }

    /**
     * @description Creates a Twilio Content template and saves it to SmartMsg__Message_Template__c.
     * @param templateDataStr JSON string with: templateName, objectName, bodyText, responseType, options (list of {text} or {text, description}).
     * @return Map<String, Object>
     */
    @AuraEnabled
    public static Map<String, Object> createAndSaveTwilioContentTemplate(String templateDataStr) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(templateDataStr);
            String templateName = (String) data.get('templateName');
            String objectName = (String) data.get('objectName');
            String bodyText = (String) data.get('bodyText');
            String responseType = (String) data.get('responseType');
            List<Object> optionsRaw = (List<Object>) data.get('options');
            List<String> options = new List<String>();
            List<String> optionTitles = new List<String>();
            List<String> optionDescriptions = new List<String>();
            Boolean listPickerWithDescription = false;
            if (optionsRaw != null) {
                for (Object o : optionsRaw) {
                    if (o instanceof Map<String, Object>) {
                        Map<String, Object> m = (Map<String, Object>) o;
                        String text = (String) m.get('text');
                        String descriptionVal = (String) m.get('description');
                        if (String.isNotBlank(text) || String.isNotBlank(descriptionVal)) {
                            optionTitles.add(String.isNotBlank(text) ? text : '');
                            optionDescriptions.add(descriptionVal != null ? descriptionVal : '');
                            if (String.isNotBlank(descriptionVal)) {
                                listPickerWithDescription = true;
                            }
                            options.add(String.isNotBlank(text) ? text : '');
                        }
                    } else if (o instanceof String) {
                        String s = (String) o;
                        options.add(s);
                        optionTitles.add(s);
                        optionDescriptions.add('');
                    }
                }
            }

            if (String.isBlank(templateName)) {
                result.put('error', 'Template Name is required.');
                return result;
            }
            String friendlyName = templateName.replaceAll('\\s+', '_').toLowerCase();
            Integer optionCount = options.size();
            if (optionCount == 0 && !'text'.equalsIgnoreCase(responseType)) {
                result.put('error', 'At least one option is required for Quick Reply or List Picker.');
                return result;
            }
            if ('Button'.equalsIgnoreCase(responseType) && optionCount > 3) {
                result.put('error', 'Quick Reply allows at most 3 buttons.');
                return result;
            }
            if (!'text'.equalsIgnoreCase(responseType) && !'Button'.equalsIgnoreCase(responseType) && optionCount > 10) {
                result.put('error', 'List Picker allows at most 10 options.');
                return result;
            }

            String payload;
            if ('text'.equalsIgnoreCase(responseType)) {
                payload = buildTwilioTextPayload(friendlyName, bodyText);
            } else if ('List Picker'.equalsIgnoreCase(responseType) && listPickerWithDescription) {
                payload = buildTwilioListPickerPayloadWithDescription(friendlyName, bodyText, optionTitles, optionDescriptions);
            } else {
                payload = buildTwilioContentPayload(friendlyName, bodyText, responseType, options);
            }
            String contentSid = createTwilioContent(payload);

            if (String.isBlank(contentSid)) {
                result.put('error', 'Twilio Content was not created.');
                return result;
            }

            // Submit for Meta approval before any DML (Salesforce does not allow callouts after DML).
            Map<String, Object> approvalResult = submitContentForMetaApproval(contentSid, friendlyName, (String) data.get('category'));
            result.put('approvalSubmitted', Boolean.valueOf(approvalResult.get('approvalSubmitted')));
            if (approvalResult.get('approvalError') != null) {
                result.put('approvalError', (String) approvalResult.get('approvalError'));
            }

            if (!Schema.sObjectType.SmartMsg__Message_Template__c.isCreateable()) {
                result.put('error', 'You do not have permission to create Message Template records.');
                return result;
            }

            SmartMsg__Message_Template__c mt = new SmartMsg__Message_Template__c();
            mt.SmartMsg__Template_Name__c = templateName;
            mt.SmartMsg__Channel__c = 'Twilio WhatsApp';
            mt.SmartMsg__Object_Name__c = objectName;
            mt.SmartMsg__Body__c = bodyText;
            mt.SmartMsg__Template_API_Name__c = friendlyName;
            mt.SmartMsg__WhatsApp_Template_ID__c = contentSid;
            mt.SmartMsg__Header__c = null;
            mt.SmartMsg__Footer__c = null;
            mt.SmartMsg__Button__c = (optionsRaw == null || optionsRaw.isEmpty()) ? null : JSON.serialize(optionsRaw);
            // Status follows Meta template flow: Pending when submitted for approval, Failed when submission failed.
            if (Boolean.valueOf(approvalResult.get('approvalSubmitted'))) {
                mt.SmartMsg__Status__c = 'Pending';
            } else {
                mt.SmartMsg__Status__c = 'Failed';
                if (approvalResult.get('approvalError') != null) {
                    String errMsg = (String) approvalResult.get('approvalError');
                    mt.SmartMsg__Error_Response__c = errMsg != null && errMsg.length() > 255 ? errMsg.substring(0, 255) : errMsg;
                }
            }
            mt.SmartMsg__List_Picker_With_Description__c = ('List Picker'.equalsIgnoreCase(responseType) && listPickerWithDescription);

            if (!CommonUtil.hasFLS(mt)) {
                result.put('error', 'Insufficient field permissions on Message Template.');
                return result;
            }
            insert mt;

            result.put('success', true);
            result.put('messageTemplateId', mt.Id);
            result.put('contentSid', contentSid);
        } catch (AuraHandledException e) {
            result.put('error', e.getMessage());
        } catch (Exception e) {
            result.put('error', 'Failed to create template: ' + e.getMessage());
        }
        return result;
    }

    /**
     * @description Builds Twilio text content payload JSON.
     * @param friendlyName The friendly name for the template.
     * @param bodyText The body text for the template.
     * @return String
     */
    public static String buildTwilioTextPayload(String friendlyName, String bodyText) {
        String bodyPlaceholder = bodyPlaceholderForTwilio(bodyText);
        List<String> varDescriptions = getBodyVariableDescriptions(bodyText);
        String variablesJson = buildVariablesJson(varDescriptions);
        return '{"friendly_name": "' + escapeJson(friendlyName) + '","language": "en",' + variablesJson + ',"types": {"twilio/text": {"body": "' + escapeJson(bodyPlaceholder) + '"}}}';
    }

    /**
     * @description Returns descriptive variable values for each merge field in body, for Meta approval.
     * Uses the merge field value as-is and appends " will be replaced here" (e.g. {!Name} -> "Name will be replaced here").
     * If body is blank (single {{1}}), returns one entry: "Body text will be replaced here".
     * @param bodyText The body text containing merge fields.
     * @return List<String>
     */
    public static List<String> getBodyVariableDescriptions(String bodyText) {
        List<String> descriptions = new List<String>();
        if (String.isBlank(bodyText)) {
            descriptions.add('Body text will be replaced here');
            return descriptions;
        }
        if (!bodyText.contains('{!')) {
            return descriptions;
        }
        Pattern pattern = Pattern.compile('\\{!([^}]+)\\}');
        Matcher matcher = pattern.matcher(bodyText);
        while (matcher.find()) {
            String innerMergeField = matcher.group(1);
            descriptions.add(mergeFieldToVariableDescription(innerMergeField));
        }
        return descriptions;
    }

    /**
     * @description Converts a merge field value to a variable description: value + " will be replaced here".
     * Dynamic: uses whatever the user entered (e.g. "Name", "Account.BillingStreet") with no static mapping.
     * @param mergeFieldValue The merge field value to convert.
     * @return String
     */
    public static String mergeFieldToVariableDescription(String mergeFieldValue) {
        if (String.isBlank(mergeFieldValue)) {
            return 'Dynamic content will be replaced here';
        }
        return mergeFieldValue.trim() + ' will be replaced here';
    }

    /**
     * @description Builds the "variables" JSON object for Twilio Content API so Meta can approve the template.
     * Keys are "1", "2", ... and values are descriptive placeholders.
     * @param variableDescriptions List of variable descriptions.
     * @return String
     */
    public static String buildVariablesJson(List<String> variableDescriptions) {
        if (variableDescriptions == null || variableDescriptions.isEmpty()) {
            return '"variables": {}';
        }
        List<String> pairs = new List<String>();
        for (Integer i = 0; i < variableDescriptions.size(); i++) {
            String varDesc = variableDescriptions[i] != null ? variableDescriptions[i] : 'Dynamic content will be replaced here';
            pairs.add('"' + (i + 1) + '": "' + escapeJson(varDesc) + '"');
        }
        return '"variables": {' + String.join(pairs, ',') + '}';
    }

    /**
     * @description Builds the body string for Twilio Content API.
     * - Static text only: returns body as-is (exact text in Twilio).
     * - With merge fields {!fieldName}: replaces each with {{1}}, {{2}}, ... in order so only those slots are dynamic in Twilio.
     * Salesforce stores the original body (with {!name}) in Message_Template__c.Body__c.
     * @param bodyText The body text to process.
     * @return String
     */
    public static String bodyPlaceholderForTwilio(String bodyText) {
        if (String.isBlank(bodyText)) {
            return '{{1}}';
        }
        if (!bodyText.contains('{!')) {
            return bodyText;
        }
        return convertMergeFieldsToTwilioPlaceholders(bodyText);
    }

    /**
     * @description Replaces each Salesforce merge field {!fieldName} with {{1}}, {{2}}, ... in order.
     * Supports {!Name} and {!Account.Name}. Used when creating Twilio content so the template in Twilio has numbered placeholders only where the user had merge fields.
     * @param bodyText The body text containing merge fields.
     * @return String
     */
    public static String convertMergeFieldsToTwilioPlaceholders(String bodyText) {
        if (String.isBlank(bodyText)) {
            return bodyText;
        }
        Pattern pattern = Pattern.compile('\\{![^}]+\\}');
        Matcher matcher = pattern.matcher(bodyText);
        Integer lastEnd = 0;
        String result = '';
        Integer index = 1;
        while (matcher.find()) {
            result += bodyText.substring(lastEnd, matcher.start()) + '{{' + index + '}}';
            lastEnd = matcher.end();
            index++;
        }
        result += bodyText.substring(lastEnd);
        return result;
    }

    /**
     * @description Builds Twilio list-picker content payload using separate title and description per option.
     * Body may use {{1}}, {{2}} for merge fields; options/descriptions store the exact user-given values.
     * @param friendlyName The friendly name for the template.
     * @param bodyText The body text for the template.
     * @param optionTitles List of option titles.
     * @param optionDescriptions List of option descriptions.
     * @return String
     */
    public static String buildTwilioListPickerPayloadWithDescription(String friendlyName, String bodyText, List<String> optionTitles, List<String> optionDescriptions) {
        String bodyPlaceholder = bodyPlaceholderForTwilio(bodyText);
        List<String> varDescriptions = getBodyVariableDescriptions(bodyText);
        String variablesJson = buildVariablesJson(varDescriptions);
        Integer size = optionTitles != null ? optionTitles.size() : 0;
        if (size == 0) {
            return '{"friendly_name": "' + escapeJson(friendlyName) + '","language": "en",' + variablesJson + ',"types": {"twilio/list-picker": {"body": "' + escapeJson(bodyPlaceholder) + '","button": "Choose Option","items": []}}}';
        }
        String title0 = size > 0 ? (optionTitles[0] != null ? optionTitles[0] : '') : '';
        String desc0 = (optionDescriptions != null && optionDescriptions.size() > 0 && optionDescriptions[0] != null) ? optionDescriptions[0] : '';
        String payload = '{"friendly_name": "' + escapeJson(friendlyName) + '","language": "en",' + variablesJson + ',"types": {"twilio/list-picker": {"body": "' + escapeJson(bodyPlaceholder) + '","button": "Choose Option","items": [{"item": "' + escapeJson(title0) + '","id": "' + escapeJson(title0) + '","description": "' + escapeJson(desc0) + '"}';
        for (Integer i = 1; i < size; i++) {
            String ti = optionTitles[i] != null ? optionTitles[i] : '';
            String di = (optionDescriptions != null && optionDescriptions.size() > i && optionDescriptions[i] != null) ? optionDescriptions[i] : '';
            payload += ',{"item": "' + escapeJson(ti) + '","id": "' + escapeJson(ti) + '","description": "' + escapeJson(di) + '"}';
        }
        payload += ']}}}';
        return payload;
    }

    /**
     * @description Builds the Twilio Content API JSON payload.
     * Body may use {{1}}, {{2}} for merge fields; buttons/options store the exact user-given values.
     * @param friendlyName The friendly name for the template.
     * @param bodyText The body text for the template.
     * @param responseType The response type (Button, List Picker, etc.).
     * @param options List of option strings.
     * @return String
     */
    public static String buildTwilioContentPayload(String friendlyName, String bodyText, String responseType, List<String> options) {
        Integer size = options != null ? options.size() : 0;
        String bodyPlaceholder = bodyPlaceholderForTwilio(bodyText);
        List<String> varDescriptions = getBodyVariableDescriptions(bodyText);
        String variablesJson = buildVariablesJson(varDescriptions);
        String payload;
        if ('Button'.equalsIgnoreCase(responseType) || 'Separate Button'.equalsIgnoreCase(responseType) || 'quick_reply'.equalsIgnoreCase(responseType)) {
            payload = '{"friendly_name": "' + escapeJson(friendlyName) + '","language": "en",' + variablesJson + ',"types": {"twilio/quick-reply": {"body": "' + escapeJson(bodyPlaceholder) + '","actions": [';
            for (Integer i = 0; i < size; i++) {
                String opt = options[i] != null ? options[i] : '';
                if (i > 0) payload += ',';
                payload += '{"title": "' + escapeJson(opt) + '","id": "' + escapeJson(opt) + '"}';
            }
            payload += ']}}}';
        } else {
            Boolean hasDescription = false;
            if (options != null) {
                for (String s : options) {
                    if (s != null && s.contains('-')) {
                        hasDescription = true;
                        break;
                    }
                }
            }
            if (hasDescription) {
                payload = '{"friendly_name": "' + escapeJson(friendlyName) + '","language": "en",' + variablesJson + ',"types": {"twilio/list-picker": {"body": "' + escapeJson(bodyPlaceholder) + '","button": "Choose Option","items": [';
                for (Integer i = 0; i < size; i++) {
                    String s = options[i] != null ? options[i] : '';
                    String itemText = s;
                    String descText = '';
                    Integer dashIdx = s.indexOf('-');
                    if (dashIdx >= 0) {
                        itemText = s.substring(0, dashIdx);
                        descText = dashIdx < s.length() - 1 ? s.substring(dashIdx + 1) : '';
                    }
                    if (i > 0) payload += ',';
                    payload += '{"item": "' + escapeJson(itemText) + '","id": "' + escapeJson(itemText) + '","description": "' + escapeJson(descText) + '"}';
                }
                payload += ']}}}';
            } else {
                payload = '{"friendly_name": "' + escapeJson(friendlyName) + '","language": "en",' + variablesJson + ',"types": {"twilio/list-picker": {"body": "' + escapeJson(bodyPlaceholder) + '","button": "Choose Option","items": [';
                for (Integer i = 0; i < size; i++) {
                    String opt = options[i] != null ? options[i] : '';
                    if (i > 0) payload += ',';
                    payload += '{"item": "' + escapeJson(opt) + '","id": "' + escapeJson(opt) + '"}';
                }
                payload += ']}}}';
            }
        }
        return payload;
    }

    /**
     * @description Escapes special characters in a string for JSON.
     * @param s The string to escape.
     * @return String
     */
    public static String escapeJson(String s) {
        if (s == null) {
            return '';
        }
        return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r');
    }

    /**
     * @description POST to Twilio Content API to create content. Returns content SID or null.
     * @param payload The JSON payload for creating the content.
     * @return String
     */
    public static String createTwilioContent(String payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TWILIO_CONTENT_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        Http http = new Http();
        HttpResponse response = http.send(req);
        if (response.getStatusCode() != 200 && response.getStatusCode() != 201) {
            throw new AuraHandledException('Twilio Content API error: ' + response.getStatusCode() + ' ' + response.getBody());
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        return (String) body.get('sid');
    }

    /**
     * @description Submits the created Twilio content template to Meta for WhatsApp approval.
     * POST to Twilio Content API: /Content/{contentSid}/ApprovalRequests/WhatsApp with body name and category.
     * @param contentSid The Twilio Content SID returned from createTwilioContent.
     * @param templateName The template name (friendly_name) for the approval request, e.g. welcome_greetings.
     * @param category WhatsApp template category, e.g. MARKETING (default if blank).
     * @return Map<String, Object>
     */
    public static Map<String, Object> submitContentForMetaApproval(String contentSid, String templateName, String category) {
        Map<String, Object> approvalResult = new Map<String, Object>();
        approvalResult.put('approvalSubmitted', false);
        if (String.isBlank(contentSid) || String.isBlank(templateName)) {
            approvalResult.put('approvalError', 'Content SID and template name are required for Meta approval.');
            return approvalResult;
        }
        String approvalCategory = 'MARKETING';
        String approvalEndpoint = TWILIO_CONTENT_ENDPOINT + '/' + contentSid + '/ApprovalRequests/whatsapp';
        String bodyJson = '{"name":"' + escapeJson(templateName) + '","category":"' + escapeJson(approvalCategory) + '"}';
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(approvalEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(bodyJson);
            //req.setTimeout(120000);
            Http http = new Http();
            HttpResponse response = http.send(req);
            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                approvalResult.put('approvalSubmitted', true);
            } else {
                approvalResult.put('approvalError', 'Meta approval request failed: ' + response.getStatusCode() + ' ' + response.getBody());
            }
        } catch (Exception e) {
            approvalResult.put('approvalError', 'Meta approval request failed: ' + e.getMessage());
        }
        return approvalResult;
    }

    /**
     * @description Reuse: get all objects for template object picker.
     * @return Map<String, String>
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAllObject() {
        Map<String, String> objectMap = new Map<String, String>();
        for (Schema.SObjectType objTyp : Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult d = objTyp.getDescribe();
            String name = d.getName();
            String label = d.getLabel();
            if (!name.containsIgnoreCase('history') && !name.containsIgnoreCase('tag') && !name.containsIgnoreCase('event')
                && !name.containsIgnoreCase('share') && !name.containsIgnoreCase('feed') && !name.containsIgnoreCase('Devops')
                && !name.containsIgnoreCase('group') && !name.containsIgnoreCase('public')
                && !d.isCustomSetting() && d.isCreateable()
                && d.getRecordTypeInfos().size() > 0) {
                objectMap.put(label, name);
            }
        }
        List<String> sortedKeys = new List<String>(objectMap.keySet());
        sortedKeys.sort();
        Map<String, String> sortedMap = new Map<String, String>();
        for (String key : sortedKeys) {
            sortedMap.put(key, objectMap.get(key));
        }
        return sortedMap;
    }

    /**
     * @description Reuse: get all fields for an object (merge fields).
     * @param objectName The API name of the object.
     * @return Map<String, String>
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAllFields(String objectName) {
        Map<String, String> allFields = new Map<String, String>();
        if (String.isBlank(objectName)) {
            return allFields;
        }
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            return allFields;
        }
        for (String fieldName : objType.getDescribe().fields.getMap().keySet()) {
            Schema.DescribeFieldResult f = objType.getDescribe().fields.getMap().get(fieldName).getDescribe();
            allFields.put(f.getLabel(), fieldName);
        }
        return allFields;
    }
}