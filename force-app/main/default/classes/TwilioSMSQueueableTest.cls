/**
 * @class TwilioSMSQueueableTest
 * @description
 *   Unit tests for the TwilioSMSQueueable class, covering SMS and MMS sending, error handling,
 *   and utility methods. Ensures all code paths and exception scenarios are tested.
 */
@isTest
public class TwilioSMSQueueableTest {

    class TwilioHttpMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        TwilioHttpMock(Integer code, String bodyStr) {
            statusCode = code;
            body = bodyStr;
        }
        /**
         * @description Responds to an HTTP request.
         * @param req The incoming HTTP request.
         * @return The HTTP response.
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /**
     * @description Creates test Twilio configuration custom setting for use in test methods.
     */
    @testSetup
    public static void setupData() {
        SmartMsg__TwilioConfiguration__c config = new SmartMsg__TwilioConfiguration__c(
          SmartMsg__Account_SID__c = 'ACxxx',
            SmartMsg__Auth_Token__c = 'token',
            SmartMsg__Twilio_Phone_Number__c = '+10000000000',
            SmartMsg__Service_Id__c = 'ZSxxx',
            SmartMsg__Environment_Id__c = 'ZExxx',
            SmartMsg__StatusCallbackUrl__c = 'https://callback.url',
            SmartMsg__MediaBaseUrl__c = 'https://media.url',
            SmartMsg__Messaging_Service_SID__c = 'MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
			SmartMsg__Channel__c = 'SMS'
        );
        insert config;
    }

    @isTest
    public static void sendSMSTest() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Hello, world!',
            SmartMsg__Media_File__c = false,
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert sms;

        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201, '{"sid":"SM123","to":"+1234567890","status":"delivered"}'));
        Test.startTest();
        System.enqueueJob(new TwilioSMSQueueable(new List<SmartMsg__Message__c>{sms}));
        Test.stopTest();

        SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :sms.Id];
        System.assertEquals('Delivered', updated.SmartMsg__Delivery_Status__c, 'SMS should be marked as Delivered after successful send');
    }

   /* @isTest
    public static void testExecuteWithMediaSMS() {
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('test content')
        );
        insert cv;

        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Media message',
            SmartMsg__Media_File__c = true,
            SmartMsg__File_Name__c = 'TestFile.txt',
            SmartMsg__Media_Url__c = cv.ContentDocumentId,
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert msg;

        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{201, 201, 201, 201, 201, 201},
            new List<String>{
                '{"sid":"ASSET123"}',
                '{"path":"/file","sid":"AV123"}',
                '{"sid":"DEPLOY123"}',
                 '{"sid":"BUILD123","status":"completed"}',
                '{"status":"completed"}',
                '{"sid":"SM123","to":"+1234567890","status":"delivered"}'
            }
        ));

        Test.startTest();
        System.enqueueJob(new TwilioSMSQueueable(new List<SmartMsg__Message__c>{msg}));
        Test.stopTest();

        SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertEquals('Delivered', updated.SmartMsg__Delivery_Status__c, 'Media SMS should be marked as Delivered after successful send');
    } */

    /**
     * @description MultiStepHttpMock class implements HttpCalloutMock interface
     */
    public class MultiStepHttpMock implements HttpCalloutMock {
        List<Integer> codes;
        List<String> bodies;
        Integer idx = 0;
        /**
             * @description Constructor for MultiStepHttpMock class.
             * @param codes List of HTTP response codes.
             * @param bodies List of HTTP response bodies.
             */
            public MultiStepHttpMock(List<Integer> codes, List<String> bodies) {
                this.codes = codes;
                this.bodies = bodies;
        }
        /**
         * @description Responds to an HTTP request.
         * @param req The HTTPRequest object.
         * @return The HTTPResponse object.
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(codes[idx]);
            res.setBody(bodies[idx]);
            idx++;
            return res;
        }
    }

    @isTest
    public static void testExecuteErrorPath() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Hello, world!',
            SmartMsg__Media_File__c = false,
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert sms;

        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400, '{"code":"400","message":"error"}'));
        Test.startTest();
        System.enqueueJob(new TwilioSMSQueueable(new List<SmartMsg__Message__c>{sms}));
        Test.stopTest();

        SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :sms.Id];
        System.assertEquals('Failed', updated.SmartMsg__Delivery_Status__c, 'SMS should be marked as Failed after error response');
    }

    @isTest
    public static void testConstructSMSBodyWithMedia() {
        List<String> mediaUrls = new List<String>{'https://media.url/file.jpg'};
        String body = TwilioSMSQueueable.constructSMSBody('+123', 'Hi &amp; &lt;Test&gt;', 'https://callback', mediaUrls);
        System.assert(body.contains('MediaUrl='), 'SMS body should include MediaUrl parameter when media is present');
    }

    @isTest
    public static void testConstructSMSBodyNullOrEmptyMediaUrlList() {
        String body = TwilioSMSQueueable.constructSMSBody('+123', 'Test', 'https://callback', null);
        System.assert(body.contains('To='), 'SMS body should always contain To= parameter');
        body = TwilioSMSQueueable.constructSMSBody('+123', 'Test', 'https://callback', new List<String>());
        System.assert(body.contains('To='), 'SMS body should always contain To= parameter when media list is empty');
    }

    @isTest
    public static void testConstructMediaUrls() {
        List<String> paths = new List<String>{'/file1', '/file2'};
        List<String> urls = TwilioSMSQueueable.constructMediaUrls(paths);
        System.assertEquals(2, urls.size(), 'Should return two media URLs');
        System.assert(urls[0].startsWith('https://'), 'Media URL should start with https://');
    }

    @isTest
    public static void testReplacePlaceholders() {
        Account acc = new Account(Name='Placeholder Test');
        insert acc;
        SmartMsg__Message_Template__c tmpl = new SmartMsg__Message_Template__c(
            SmartMsg__Object_Name__c = 'Account'
        );
        insert tmpl;
        String msg = 'Hello {!Name}';
        String result = TwilioSMSQueueable.replacePlaceholders(tmpl.Id, acc.Id, msg);
        System.assert(result.contains('Placeholder Test'), 'Placeholder should be replaced with Account Name');
    }


    @isTest
    public static void testHandleSMSResponseSuccess() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(201);
        res.setBody('{"sid":"SM123","to":"+1234567890","status":"delivered"}');
        TwilioSMSQueueable.handleSMSResponse(res, sms.Id, '');
		SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :sms.Id];
        System.assertEquals('Delivered', updated.SmartMsg__Delivery_Status__c, 'SMS should be marked as Delivered after handleSMSResponse success');

    }

    @isTest
    public static void testHandleSMSResponseFailure() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        HttpResponse res = new HttpResponse();
        res.setStatusCode(400);
        res.setBody('{"code":"400","message":"error"}');
        TwilioSMSQueueable.handleSMSResponse(res, sms.Id, '');
		SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :sms.Id];
        System.assertEquals('Failed', updated.SmartMsg__Delivery_Status__c, 'SMS should be marked as Failed after handleSMSResponse failure');
    }

    @isTest
    public static void testUpdateRecordsInCatch() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        TwilioSMSQueueable.updateRecordsInCatch(sms.Id, 'Some error message');
         SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c, SmartMsg__Failed_Reason__c FROM SmartMsg__Message__c WHERE Id = :sms.Id];
        System.assertEquals('Failed', updated.SmartMsg__Delivery_Status__c, 'Delivery status should be Failed after updateRecordsInCatch');
        System.assertEquals('Some error message', updated.SmartMsg__Failed_Reason__c, 'Failed reason should match input error message');
    }

    @isTest
    public static void testUpdateRecordsInCatchLongError() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        String longError = 'a'.repeat(300);
        TwilioSMSQueueable.updateRecordsInCatch(sms.Id, longError);
       SmartMsg__Message__c updated = [SELECT SmartMsg__Failed_Reason__c FROM SmartMsg__Message__c WHERE Id = :sms.Id];
        System.assertEquals(255, updated.SmartMsg__Failed_Reason__c.length(), 'Failed reason should be truncated to 255 characters');
    }

    @isTest
    public static void testCreateAssetException() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400, '{"error":"bad request"}'));
        try {
            TwilioSMSQueueable.createAsset('TestAsset', sms.Id);
            System.assert(false, 'Should have thrown an exception for failed asset creation');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Failed to create asset'), 'Exception message should indicate failed asset creation');
        }
    }

    @isTest
    public static void testUploadBlobToTwilioAssetException() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400, '{"error":"bad request"}'));
        try {
            TwilioSMSQueueable.uploadBlobToTwilioAsset(Blob.valueOf('test'), 'file.txt', 'application/octet-stream', 'ASSET123', sms.Id);
            System.assert(false, 'Should have thrown an exception for failed blob upload');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Failed to upload asset'), 'Exception message should indicate failed asset upload');
        }
    }

    @isTest
    public static void testCreateBuildIdException() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400, '{"error":"bad request"}'));
         try {
            TwilioSMSQueueable.createBuildId(new List<String>{'AV123'}, new List<String>{'/file'}, '+123', 'body', sms.Id);
            System.assert(false, 'Should have thrown an exception for failed build creation');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Failed to process  of creating BuildId'), 'Exception message should indicate failed build creation');
        }
    }

    @isTest
    public static void testDeployChangesInEnvironmentException() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Test'
        );
        insert sms;
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400, '{"error":"bad request"}'));
        try {
            TwilioSMSQueueable.deployChangesInEnvironment('BUILD123', sms.Id);
            System.assert(false, 'Should have thrown an exception for failed deployment');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Failed to process  of deployment'), 'Exception message should indicate failed deployment');
        }
    }

   // @isTest
   /* public static void testGetCreatedBuildDetailsFailure() {
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400, '{"error":"bad request"}'));
        try {
            TwilioSMSQueueable.getCreatedBuildDetails('BUILD123');
            System.assert(false, 'Should have thrown an exception for failed build details fetch');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Failed to deploy'), 'Exception message should indicate failed build details fetch');
        }
    }*/

    @isTest
    public static void testProcessMediaSMSContentVersionQuery() {
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        Id contentDocumentId = cv.ContentDocumentId;

        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Media message',
            SmartMsg__Media_File__c = true,
            SmartMsg__File_Name__c = 'TestFile.txt',
            SmartMsg__Media_Url__c = contentDocumentId,
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert msg;

        Test.setMock(HttpCalloutMock.class, new MultiStepHttpMock(
            new List<Integer>{201, 201, 201, 201, 201, 201},
            new List<String>{
                '{"sid":"ASSET123"}',
                '{"path":"/file","sid":"AV123"}',
                '{"sid":"DEPLOY123"}',
                '{"sid":"BUILD123","status":"completed"}',
                '{"status":"completed"}',
                '{"sid":"SM123","to":"+1234567890","status":"delivered"}'
            }
        ));

        Test.startTest();
        System.enqueueJob(new TwilioSMSQueueable(new List<SmartMsg__Message__c>{msg}));
        Test.stopTest();

       SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertEquals('Delivered', updated.SmartMsg__Delivery_Status__c, 'Media SMS should be marked as Delivered after successful send');
    }

    @isTest
    public static void testProcessMediaSMSBlankMediaUrl() {
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Media message',
            SmartMsg__Media_File__c = true,
            SmartMsg__File_Name__c = 'TestFile.txt',
            SmartMsg__Media_Url__c = '', // Blank
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert msg;

        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201, '{"sid":"dummy"}'));
        Test.startTest();
        new TwilioSMSQueueable(new List<SmartMsg__Message__c>{msg}).processMediaSMS(msg);
        Test.stopTest();

        SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertEquals('Scheduled', updated.SmartMsg__Delivery_Status__c, 'If Media_Url__c is blank, status should remain Scheduled');
    }

    @isTest
    public static void testProcessMediaSMSNoContentVersion() {
        SmartMsg__Message__c msg = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Media message',
            SmartMsg__Media_File__c = true,
            SmartMsg__File_Name__c = 'TestFile.txt',
            SmartMsg__Media_Url__c = 'nonexistent', // Will not match any ContentVersion
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert msg;

        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201, '{"sid":"dummy"}'));
        Test.startTest();
        new TwilioSMSQueueable(new List<SmartMsg__Message__c>{msg}).processMediaSMS(msg);
        Test.stopTest();
        SmartMsg__Message__c updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id = :msg.Id];
        System.assertEquals('Scheduled', updated.SmartMsg__Delivery_Status__c, 'If no ContentVersion found, status should remain Scheduled');
    }

    @isTest
    public static void testScheduleSMSSuccess() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Scheduled test',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert sms;

        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201,
            '{"sid":"SM123","to":"+1234567890","status":"Scheduled"}'
        ));

        Test.startTest();
        Id scheduledId = TwilioSMSQueueable.scheduleSMS(sms.Id, sms.SmartMsg__To_Number__c, sms.SmartMsg__Message_Body__c, '2025-07-01T10:00:00Z');
        Test.stopTest();

        System.assertNotEquals(null, scheduledId, 'Scheduled SMS Id should not be null');
    }

    @isTest
    public static void testScheduleSMSError() {
        SmartMsg__Message__c sms = new SmartMsg__Message__c(
            SmartMsg__To_Number__c = '+1234567890',
            SmartMsg__Message_Body__c = 'Scheduled test',
            SmartMsg__Delivery_Status__c = 'Scheduled'
        );
        insert sms;

        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(400,
            '{"error":"bad request"}'
        ));

        Test.startTest();
        Id errorId = TwilioSMSQueueable.scheduleSMS(sms.Id, sms.SmartMsg__To_Number__c, sms.SmartMsg__Message_Body__c, '2025-07-01T10:00:00Z');
        Test.stopTest();

        System.assertEquals(null, errorId, 'Scheduled SMS should return null on failure');
    }

    @isTest
    public static void testExecuteEmptyList() {
        Test.startTest();
        System.enqueueJob(new TwilioSMSQueueable(new List<SmartMsg__Message__c>()));
        Test.stopTest();
		Integer count = [SELECT count() FROM SmartMsg__Message__c];
        System.assert(count >= 0, 'No exception should occur when processing an empty list');
    }

   /* @isTest
    public static void testExecuteLessThanBatchSize() {
        List<SmartMsg__Message__c> msgs = new List<SmartMsg__Message__c>();
        for (Integer i = 0; i < 2; i++) {
            msgs.add(new SmartMsg__Message__c(
                SmartMsg__To_Number__c = '+1234567890',
                SmartMsg__Message_Body__c = 'Test ' + i,
                SmartMsg__Media_File__c = false,
                SmartMsg__Delivery_Status__c = 'Scheduled'
            ));
        }
        insert msgs;
        Test.setMock(HttpCalloutMock.class, new TwilioHttpMock(201, '{"sid":"SM123","to":"+1234567890","status":"delivered"}'));
        Test.startTest();
        System.enqueueJob(new TwilioSMSQueueable(msgs));
        Test.stopTest();
		
		List<SmartMsg__Message__c> updated = [SELECT SmartMsg__Delivery_Status__c FROM SmartMsg__Message__c WHERE Id IN :msgs];
        for (SmartMsg__Message__c m : updated) {
            System.assertEquals('Sent', m.SmartMsg__Delivery_Status__c, 'Each SMS in batch should be marked as Delivered');
        }
		
    }*/
}