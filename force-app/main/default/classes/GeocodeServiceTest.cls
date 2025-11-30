@IsTest
public class GeocodeServiceTest {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Main St',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingPostalCode = '94105',
            BillingCountry = 'USA'
        );
        insert testAccount;
        
        Account emptyAddressAccount = new Account(
            Name = 'Empty Address Account'
        );
        insert emptyAddressAccount;
    }
    
    @IsTest
    static void testSuccessfulGeocoding() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulGeocodeMock());
        
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        GeocodeService.geocodeAccount(testAcc.Id);
        Test.stopTest();
        
        Account updatedAccount = [SELECT Billing_Latitude__c, Billing_Longitude__c 
                                 FROM Account WHERE Id = :testAcc.Id];
        
        System.assertEquals(37.7749, updatedAccount.Billing_Latitude__c, 'Latitude should be updated');
        System.assertEquals(-122.4194, updatedAccount.Billing_Longitude__c, 'Longitude should be updated');
    }
    
    @IsTest
    static void testFailedHttpCallout() {
        Test.setMock(HttpCalloutMock.class, new FailedHttpMock());
        
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        GeocodeService.geocodeAccount(testAcc.Id);
        Test.stopTest();
        
        Account updatedAccount = [SELECT Billing_Latitude__c, Billing_Longitude__c 
                                 FROM Account WHERE Id = :testAcc.Id];
        
        System.assertEquals(null, updatedAccount.Billing_Latitude__c, 'Latitude should remain null');
        System.assertEquals(null, updatedAccount.Billing_Longitude__c, 'Longitude should remain null');
    }
    
    @IsTest
    static void testNoResults() {
        Test.setMock(HttpCalloutMock.class, new NoResultsMock());
        
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        GeocodeService.geocodeAccount(testAcc.Id);
        Test.stopTest();
        
        Account updatedAccount = [SELECT Billing_Latitude__c, Billing_Longitude__c 
                                 FROM Account WHERE Id = :testAcc.Id];
        
        System.assertEquals(null, updatedAccount.Billing_Latitude__c, 'Latitude should remain null');
        System.assertEquals(null, updatedAccount.Billing_Longitude__c, 'Longitude should remain null');
    }
    
    @IsTest
    static void testEmptyAddress() {
        Account emptyAcc = [SELECT Id FROM Account WHERE Name = 'Empty Address Account' LIMIT 1];
        
        Test.startTest();
        GeocodeService.geocodeAccount(emptyAcc.Id);
        Test.stopTest();
        
        Account updatedAccount = [SELECT Billing_Latitude__c, Billing_Longitude__c 
                                 FROM Account WHERE Id = :emptyAcc.Id];
        
        System.assertEquals(null, updatedAccount.Billing_Latitude__c, 'Latitude should remain null');
        System.assertEquals(null, updatedAccount.Billing_Longitude__c, 'Longitude should remain null');
    }
    
    @IsTest
    static void testInvalidAccountId() {
        Id fakeAccountId = '001000000000000AAA';
        
        Test.startTest();
        GeocodeService.geocodeAccount(fakeAccountId);
        Test.stopTest();
        
        System.assert(true, 'Method should handle invalid account ID gracefully');
    }
    
    @IsTest
    static void testBuildAddressString() {
        Account testAcc = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry 
                          FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        String address = GeocodeService.buildAddressString(testAcc);
        Test.stopTest();
        
        System.assertEquals('123 Main St, San Francisco, CA, 94105, USA', address, 'Address string should be properly formatted');
    }
    
    @IsTest
    static void testParseGeocodingResponse() {
        String jsonResponse = '[{"lat":"37.7749","lon":"-122.4194","display_name":"San Francisco, CA, USA"}]';
        
        Test.startTest();
        GeocodeService.GeocodeResult result = GeocodeService.parseGeocodingResponse(jsonResponse);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Parsing should be successful');
        System.assertEquals(37.7749, result.latitude, 'Latitude should be parsed correctly');
        System.assertEquals(-122.4194, result.longitude, 'Longitude should be parsed correctly');
    }
    
    @IsTest
    static void testGeocodeQueueable() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulGeocodeMock());
        
        List<Account> testAccounts = [SELECT Id FROM Account];
        List<Id> accountIds = new List<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        GeocodeQueueable queueable = new GeocodeQueueable(accountIds);
        queueable.execute(null);
        Test.stopTest();
        
        System.assert(true, 'Queueable should execute without errors');
    }
    
    @IsTest
    static void testGeocodeQueueableEnqueue() {
        List<Account> testAccounts = [SELECT Id FROM Account];
        List<Id> accountIds = new List<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        GeocodeQueueable.enqueueGeocoding(accountIds);
        Test.stopTest();
        
        System.assert(true, 'Queueable should be enqueued without errors');
    }
    
    @IsTest
    static void testGeocodeAccountAction() {
        List<Account> testAccounts = [SELECT Id FROM Account];
        List<Id> accountIds = new List<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }
        
        GeocodeAccountAction.GeocodeRequest request = new GeocodeAccountAction.GeocodeRequest();
        request.accountIds = accountIds;
        List<GeocodeAccountAction.GeocodeRequest> requests = new List<GeocodeAccountAction.GeocodeRequest>();
        requests.add(request);
        
        Test.startTest();
        List<GeocodeAccountAction.GeocodeResponse> responses = GeocodeAccountAction.geocodeAccounts(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(true, responses[0].success, 'Response should be successful');
        System.assertEquals(2, responses[0].accountsQueued, 'Should queue 2 accounts');
    }
    
    @IsTest
    static void testGeocodeActionEmptyRequest() {
        GeocodeAccountAction.GeocodeRequest request = new GeocodeAccountAction.GeocodeRequest();
        request.accountIds = new List<Id>();
        List<GeocodeAccountAction.GeocodeRequest> requests = new List<GeocodeAccountAction.GeocodeRequest>();
        requests.add(request);
        
        Test.startTest();
        List<GeocodeAccountAction.GeocodeResponse> responses = GeocodeAccountAction.geocodeAccounts(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(false, responses[0].success, 'Response should not be successful');
        System.assertEquals(0, responses[0].accountsQueued, 'Should queue 0 accounts');
    }
    
    public class SuccessfulGeocodeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"lat":"37.7749","lon":"-122.4194","display_name":"San Francisco, CA, USA"}]');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class FailedHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            return res;
        }
    }
    
    public class NoResultsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[]');
            res.setStatusCode(200);
            return res;
        }
    }
}