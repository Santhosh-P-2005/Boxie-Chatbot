/**
 * @description Controller class for handling WhatsApp Template creation and editing.
 * @class WhatsAppTemplateCreationController
 * @with sharing
 */

public with sharing class WhatsAppTemplateCreationController {
    /**
     * @description Wrapper for active channel provider settings (SMS, Meta WhatsApp, Twilio WhatsApp).
     */
    public class ActiveSettingWrapper{
        @AuraEnabled
        public Boolean sMSActive;
        @AuraEnabled
        public Boolean whatsAppActive;
        @AuraEnabled
        public Boolean twilioWhatsAppActive;
    }
    /**
     * @description Returns which channel providers are active (SMS, Meta WhatsApp, Twilio WhatsApp).
     * @return ActiveSettingWrapper with sMSActive, whatsAppActive, twilioWhatsAppActive flags.
     */
    @AuraEnabled
    public static ActiveSettingWrapper getActiveSettings(){
        // System.debug('inside getActiveSettings');
        ActiveSettingWrapper wrap = new ActiveSettingWrapper();
        if (SmartMsg__Meta_Configuration__c.getInstance()?.SmartMsg__Active__c == true) {
            wrap.whatsAppActive = true;
        }
        if (SmartMsg__Twilio_Whatsapp__c.getInstance()?.SmartMsg__Active__c == true) {
            wrap.twilioWhatsAppActive = true;
        }
        if (SmartMsg__TwilioConfiguration__c.getInstance()?.SmartMsg__Active__c == true) {
            wrap.sMSActive = true;
        }
        // System.debug('wrap --> '+wrap);
        return wrap;
    }
    /**
     * @description Retrieves all available SObjects and their labels.
     * @return A map where the key is the SObject API name and the value is the label.
     * @AuraEnabled
     */
    @AuraEnabled
    public static Map<String, String> getAllObject(){
        
        Map<String,String> objectMap = new Map<String,String>();
        for(Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()){
            String name = objTyp.getDescribe().getName();
            String label = objTyp.getDescribe().getLabel();
            if(!name.containsignorecase('history') && !name.containsignorecase('tag') &&
                !name.containsignorecase('share') && !name.containsignorecase('feed') &&
                !name.containsignorecase('group') && !name.containsignorecase('public') &&
                !objTyp.getDescribe().isCustomSetting() && objTyp.getDescribe().isCreateable() &&
            objTyp.getDescribe().getRecordTypeInfos().size() > 0){
                objectMap.put(label,name);
            }
        }
        
        List<String> sortedKeys = new List<String>(objectMap.keySet());
        sortedKeys.sort();
        Map<String, String> sortedMap = new Map<String, String>();
        for (String key : sortedKeys) {
            sortedMap.put(key, objectMap.get(key));
        }
        if(sortedMap != null && sortedMap.size() > 0){
            return sortedMap;
        }else{
            return null;
        }
    }
    /**
     * @description Retrieves all fields for a given SObject.
     * @param objectName The API name of the SObject.
     * @return A map where the key is the field label and the value is the field API name.
     * @AuraEnabled
     */
    @AuraEnabled
    public static Map<String, String> getAllfields(String objectName){
        Map<String, String> allFields = new Map<String, String>();
        Map<String, Schema.SObjectType> objectMap = Schema.getGlobalDescribe();
        SObjectType objType = objectMap.get(objectName);
        Map<String,Schema.SObjectField> objTypeFields = objType.getDescribe().fields.getMap();
        if(!objTypeFields.isEmpty()){
            for (String fieldName: objTypeFields.keySet()) {
                String fieldLabel = objTypeFields.get(fieldName).getDescribe().getLabel();
                allFields.put(fieldLabel,fieldName);
            }
        }
        return allFields;
    }

    /**
     * @description Normalizes LWC button objects to Meta WhatsApp API format (type, text, and url/phone_number only).
     * @param rawButtons List of button maps from the client (may contain id, isQuickReply, isCallToAction).
     * @return List of maps with only type, text, and url or phone_number as required by Meta API.
     */
    private static List<Map<String, Object>> normalizeButtonsForMetaApi(List<Object> rawButtons) {
        List<Map<String, Object>> apiButtons = new List<Map<String, Object>>();
        if (rawButtons == null || rawButtons.isEmpty()) {
            return apiButtons;
        }
        for (Object o : rawButtons) {
            Map<String, Object> btn = (Map<String, Object>) o;
            String btnType = (String) btn.get('type');
            if (String.isBlank(btnType)) continue;
            String textVal = btn.get('text') != null ? String.valueOf(btn.get('text')).trim() : '';
            Map<String, Object> apiBtn = new Map<String, Object>();
            apiBtn.put('type', btnType);
            apiBtn.put('text', String.isNotBlank(textVal) ? textVal : 'Button');
            if ('URL'.equalsIgnoreCase(btnType)) {
                if (btn.get('url') == null || String.isBlank(String.valueOf(btn.get('url')))) continue;
                apiBtn.put('url', String.valueOf(btn.get('url')).trim());
            } else if ('PHONE_NUMBER'.equalsIgnoreCase(btnType)) {
                if (btn.get('phone_number') == null || String.isBlank(String.valueOf(btn.get('phone_number')))) continue;
                apiBtn.put('phone_number', String.valueOf(btn.get('phone_number')).trim());
            }
            apiButtons.add(apiBtn);
        }
        return apiButtons;
    }

    /**
     * @description Handles the saving of a WhatsApp template.
     * @param templateDataStr The template data as a JSON string.
     * @throws AuraHandledException if the user lacks the necessary permissions.
     * @AuraEnabled
     */
    @AuraEnabled
    public static void handleSave(String templateDataStr) {
        try{
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(templateDataStr);
            Map<String, Object> headerMedia = new Map<String, Object>();
            if(results.get('headerMedia') != null && results.get('headerMedia') != ''){
                headerMedia = (Map<String, Object>) results.get('headerMedia');
            }
            
            String templateName = (String) results.get('templateName');
            if (!Schema.sObjectType.SmartMsg__Message_Template__c.isCreateable()) {
                throw new CustomException('You do not have permission to create Message_Template__c records.');
            }
            SmartMsg__Message_Template__c msgtemp = new SmartMsg__Message_Template__c();
            msgtemp.SmartMsg__Template_Name__c = templateName;
            msgtemp.SmartMsg__Channel__c = (String) results.get('channel');
            msgtemp.SmartMsg__Object_Name__c = (String) results.get('objectName');
            msgtemp.SmartMsg__Body__c = (String) results.get('bodyText');
            msgtemp.SmartMsg__Template_API_Name__c = templateName.replaceAll(' ','_').toLowerCase();
            if (!CommonUtil.hasFLS(msgtemp)) {
                throw new CustomException('You do not have the necessary field permissions to create Message_Template__c records.');
            }
            Map<String, Object> requestBody = new Map<String, Object>();
            if((String) results.get('channel') == 'WhatsApp'){
                
                checkTemplateNameInWhatsApp(templateName);
                requestBody.put('name', msgtemp.SmartMsg__Template_API_Name__c);
                requestBody.put('category','Marketing');
                requestBody.put('language','en_US');
                List<Object> components = new List<Object>();
                Map<String, Object> bodyParams = new Map<String, Object>();
                bodyParams.put('type','BODY');
                bodyParams.put('text',results.get('formattedBodyText'));
                if(results.containsKey('example')){
                    bodyParams.put('example',results.get('example'));
                }
                components.add(bodyParams);
                String headerVal = (String) results.get('header');
                if (headerVal == 'Text' && String.isNotBlank((String) results.get('headerText'))) {
                    Map<String, Object> headerParams = new Map<String, Object>();
                    headerParams.put('type', 'HEADER');
                    headerParams.put('format', 'TEXT');
                    headerParams.put('text', results.get('headerText'));
                    components.add(headerParams);
                    msgtemp.SmartMsg__Header__c = (String) results.get('headerText');
                } else if (headerVal == 'Image' || headerVal == 'Video' || headerVal == 'Document') {
                    String fileData = (String) headerMedia.get('fileData');
                    if (String.isNotBlank(fileData)) {
                        Blob fileBlob = EncodingUtil.base64Decode(fileData);
                        Integer fileLength = (Integer) headerMedia.get('fileSize');
                        String fileType = (String) headerMedia.get('fileType');
                        String fileId = uploadFileDetails(fileLength, fileType);
                        String headerHandle = initiateUpload(fileId, fileBlob);
                        Map<String, Object> headerParams = new Map<String, Object>();
                        headerParams.put('type', 'HEADER');
                        headerParams.put('format', headerVal.toUpperCase());
                        if (String.isNotBlank(headerHandle)) {
                            List<String> headerHandles = new List<String>();
                            headerHandles.add(headerHandle);
                            Map<String, Object> exampleMap = new Map<String, Object>{ 'header_handle' => headerHandles };
                            headerParams.put('example', exampleMap);
                        }
                        components.add(headerParams);
                        msgtemp.SmartMsg__Header__c = headerVal;
                    }
                }
                if(String.isNotBlank((String) results.get('footerText'))){
                    Map<String, Object> footerParams = new Map<String, Object>();
                    footerParams.put('type','FOOTER');
                    footerParams.put('text',results.get('footerText'));
                    components.add(footerParams);
                    msgtemp.SmartMsg__Footer__c = (String) results.get('footerText');
                }
                List<Object> buttons = (List<Object>) results.get('buttons');
                if (buttons != null && !buttons.isEmpty()) {
                    List<Map<String, Object>> apiButtons = normalizeButtonsForMetaApi(buttons);
                    if (!apiButtons.isEmpty()) {
                        Map<String, Object> buttonParams = new Map<String, Object>();
                        buttonParams.put('type', 'BUTTONS');
                        buttonParams.put('buttons', apiButtons);
                        components.add(buttonParams);
                        msgtemp.SmartMsg__Button__c = JSON.serialize(buttons);
                    }
                }
                requestBody.put('components',components);
                SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
                String endpointUrl = 'callout:SmartMsg__Meta_API/v18.0/' + whatsAppCreds.SmartMsg__WhatsApp_Business_Id__c + '/message_templates';
                HttpRequest httpRequest = new HttpRequest();
                httpRequest.setEndpoint(endpointUrl);
                httpRequest.setMethod('POST');
                httpRequest.setHeader('Content-Type', 'application/json');
                httpRequest.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
                httpRequest.setHeader('Pragma', 'no-cache');
                httpRequest.setHeader('Expires', '0');
                httpRequest.setHeader('X-Content-Type-Options', 'nosniff');
                httpRequest.setBody(JSON.serialize(requestBody));
                Http http = new Http();
                HttpResponse response = http.send(httpRequest);
                if (response.getStatusCode() == 200) {
                    Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    msgtemp.SmartMsg__Status__c	 = 'Pending';
                    msgtemp.SmartMsg__WhatsApp_Template_ID__c = (String) resBody.get('id');
                    insert msgtemp;
                } else {
                    msgtemp.SmartMsg__Status__c = 'Failed';
                    if(response.getBody().length() > 255){
                        msgtemp.SmartMsg__Error_Response__c = 'Invalid Parameter';
                    }else{
                        msgtemp.SmartMsg__Error_Response__c = response.getBody();
                    }
                    insert msgtemp;
                    throw new CustomException(msgtemp.SmartMsg__Error_Response__c);
                }
            } else {
                
                msgtemp.SmartMsg__Status__c	 = 'Approved';
                insert msgtemp;
            }
            
        }
        catch(Exception e){
            throw new CustomException('Error Failed to create template '+e.getMessage());
        }
    }

    /**
     * @description Checks whether the given template name already exists in WhatsApp (Meta) message templates.
     * @param templateName The template name to check.
     * @throws CustomException If the template name already exists in WhatsApp.
     */
    public static void checkTemplateNameInWhatsApp(String templateName){
        templateName = templateName.replaceAll(' ','_').toLowerCase();
        SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        String endpointUrl = 'callout:SmartMsg__Meta_API/v18.0/' + whatsAppCreds.SmartMsg__WhatsApp_Business_Id__c + '/message_templates?name='+templateName;
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint(endpointUrl);
        httpRequest.setMethod('GET');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        httpRequest.setHeader('Pragma', 'no-cache');
        httpRequest.setHeader('Expires', '0');
        httpRequest.setHeader('X-Content-Type-Options', 'nosniff');
        //httpRequest.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse response = http.send(httpRequest);
        Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<String> templateNames = new List<String>();
        if (resBody.containsKey('data')) {
            List<Object> templates = (List<Object>) resBody.get('data');
            for (Object obj : templates) {
                Map<String, Object> template = (Map<String, Object>) obj;
                
                if (template.containsKey('name')) {
                    templateNames.add((String) template.get('name'));
                }
            }
        }
        for(String str : templateNames){
            if(str.equals(templateName)){
                throw new CustomException('Template name already exists');
            }
        }
    }

    /**
     * @description Custom exception for template creation errors.
     */
    public class CustomException extends Exception {}
    /**
     * @description Uploads file details to the Facebook Graph API.
     * @param fileLength The length of the file.
     * @param fileType The type of the file.
     * @return The file ID returned by the Facebook Graph API.
     * @throws CalloutException if the file upload fails.
     */
    public static String uploadFileDetails(Integer fileLength, String fileType) {
        SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        String endpointUrl = 'callout:SmartMsg__Meta_API/v18.0/' + whatsAppCreds.SmartMsg__Application_Id__c + '/uploads';
        String authToken = whatsAppCreds.SmartMsg__Auth_Token__c;
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpointUrl);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        request.setHeader('Pragma', 'no-cache');
        request.setHeader('Expires', '0');
        request.setHeader('X-Content-Type-Options', 'nosniff');
        request.setBody('file_length=' + fileLength + '&file_type=' + fileType + '&access_token=' + authToken);
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            return (String) jsonResponse.get('id');
        } else {
            throw new CalloutException('Failed to upload file details. Error: ' + response.getBody());
        }
    }
    /**
     * @description Initiates the file upload process to the Facebook Graph API.
     * @param fileId The file ID returned from the uploadFileDetails method.
     * @param fileBlob The file data as a Blob.
     * @return The handle returned by the Facebook Graph API for the uploaded file.
     * @throws CalloutException if the file upload initiation fails.
     */
    public static String initiateUpload(String fileId, Blob fileBlob) {
        //SmartMsg__Meta_Configuration__c whatsAppCreds = ProviderSettingUtil.getWhatsAppProviderSettings('WhatsApp');
        String endpoint = 'callout:SmartMsg__Meta_API_OAuth/v18.0/' + fileId;
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('file_offset', '0');
        request.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        request.setHeader('Pragma', 'no-cache');
        request.setHeader('Expires', '0');
        request.setHeader('X-Content-Type-Options', 'nosniff');
        request.setBodyAsBlob(fileBlob);
        Http http = new Http();
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            return (String) jsonResponse.get('h');
        } else {
            throw new CalloutException('Failed to initiate upload session. Error: ' + response.getBody());
        }
    }
    /**
     * @description Handles the editing of an existing WhatsApp template.
     * @param templateDataStr The template data as a JSON string.
     * @param waTemplateId The WhatsApp template ID.
     * @param templateId The Salesforce template record ID.
     * @return A status string indicating the result of the operation.
     * @AuraEnabled
     */
    @AuraEnabled
    public static String handleEdit(String templateDataStr, String waTemplateId, String templateId) {
        try{
            SmartMsg__Message_Template__c tempRecord = [SELECT Id, LastModifiedDate, createdDate FROM SmartMsg__Message_Template__c WHERE Id = :templateId With SECURITY_ENFORCED LIMIT 1];
            DateTime now = DateTime.now();
            DateTime lastModified = tempRecord.LastModifiedDate;
            DateTime createdDate = tempRecord.createdDate;
            if (lastModified.addHours(24) > now && lastModified != createdDate) {
                return 'error_24_hour_limit';
            }
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(templateDataStr);
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('name', (String) results.get('templateName'));
            requestBody.put('category', 'Marketing');
            requestBody.put('language', 'en');
            List<Object> components = new List<Object>();
            Map<String, Object> bodyParams = new Map<String, Object>();
            bodyParams.put('type', 'BODY');
            bodyParams.put('text', (String) results.get('formattedBodyText'));
            if (results.containsKey('example')) {
                bodyParams.put('example', results.get('example'));
            }
            components.add(bodyParams);
            if ((String) results.get('header') == 'Text' && String.isNotBlank((String) results.get('headerText'))) {
                Map<String, Object> headerParams = new Map<String, Object>();
                headerParams.put('type', 'HEADER');
                headerParams.put('format', 'TEXT');
                headerParams.put('text', results.get('headerText'));
                components.add(headerParams);
            }
            if (String.isNotBlank((String) results.get('footerText'))) {
                Map<String, Object> footerParams = new Map<String, Object>();
                footerParams.put('type', 'FOOTER');
                footerParams.put('text', results.get('footerText'));
                components.add(footerParams);
            }
            List<Object> buttons = (List<Object>) results.get('buttons');
            if (buttons != null && !buttons.isEmpty()) {
                List<Map<String, Object>> apiButtons = normalizeButtonsForMetaApi(buttons);
                if (!apiButtons.isEmpty()) {
                    Map<String, Object> buttonParams = new Map<String, Object>();
                    buttonParams.put('type', 'BUTTONS');
                    buttonParams.put('buttons', apiButtons);
                    components.add(buttonParams);
                }
            }
            requestBody.put('components', components);
            String endpointUrl = 'callout:SmartMsg__Meta_API/v18.0/' +waTemplateId;
            HttpRequest httpRequest = new HttpRequest();
            httpRequest.setEndpoint(endpointUrl);
            httpRequest.setMethod('POST');
            httpRequest.setHeader('Content-Type', 'application/json');
            httpRequest.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            httpRequest.setHeader('Pragma', 'no-cache');
            httpRequest.setHeader('Expires', '0');
            httpRequest.setHeader('X-Content-Type-Options', 'nosniff');
            httpRequest.setBody(JSON.serialize(requestBody));
            Http http = new Http();
            HttpResponse response = http.send(httpRequest);
            if (response.getStatusCode() == 200) {
                if (!Schema.sObjectType.SmartMsg__Message_Template__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to update SmartMsg__Message_Template__c records.');
                }
                SmartMsg__Message_Template__c templateRecord = new SmartMsg__Message_Template__c(Id = TemplateId);
                templateRecord.SmartMsg__Template_Name__c = (String) results.get('templateName');
                templateRecord.SmartMsg__Channel__c = 'WhatsApp';
                templateRecord.SmartMsg__Body__c = (String) results.get('bodyText');
                templateRecord.SmartMsg__Header__c = (String) results.get('headerText');
                templateRecord.SmartMsg__Footer__c = (String) results.get('footerText');
                templateRecord.SmartMsg__Button__c = JSON.serialize((List<Object>) results.get('buttons'));
                if (!CommonUtil.hasFLS(templateRecord)) {
                    throw new AuraHandledException('You do not have the necessary field permissions to update SmartMsg__Message_Template__c records.');
                }
                update templateRecord;
                return 'success';
            } else {
                return 'error';
            }
        } catch (QueryException e) {
            return 'error_no_record_found';
        } catch (Exception e) {
            return 'error_exception_occurred';
        }
        
    }
}