@IsTest
public class CommonUtilTest {
  @IsTest
    public static void testHasFLS() {
      SmartMsg__Message__c master =new SmartMsg__Message__c
          (SmartMsg__Outgoing__c=true,SmartMsg__Channel__c='WhatsApp');
       Test.startTest();
        CommonUtil.hasFLS(master);
        Test.stopTest();
        Boolean hasFLSResult = CommonUtil.hasFLS(master);
        Assert.areEqual(true, hasFLSResult, 'Expected value and Actual value are Same.');
    }
}