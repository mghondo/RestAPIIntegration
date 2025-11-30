public with sharing class GeocodeService {
    
    private static final String NOMINATIM_ENDPOINT = 'https://nominatim.openstreetmap.org/search';
    private static final Integer TIMEOUT = 10000;
    
    public class GeocodeResult {
        public Boolean success;
        public Decimal latitude;
        public Decimal longitude;
        public String errorMessage;
        
        public GeocodeResult(Boolean success, Decimal latitude, Decimal longitude, String errorMessage) {
            this.success = success;
            this.latitude = latitude;
            this.longitude = longitude;
            this.errorMessage = errorMessage;
        }
    }
    
    public static void geocodeAccount(Id accountId) {
        try {
            Account acc = getAccountBillingAddress(accountId);
            if (acc == null) {
                System.debug('Account not found: ' + accountId);
                return;
            }
            
            String address = buildAddressString(acc);
            if (String.isBlank(address)) {
                System.debug('No billing address found for Account: ' + accountId);
                return;
            }
            
            GeocodeResult result = callGeocodingAPI(address);
            
            if (result.success) {
                updateAccountCoordinates(accountId, result.latitude, result.longitude);
                System.debug('Successfully geocoded Account: ' + accountId + 
                           ' Lat: ' + result.latitude + ' Lng: ' + result.longitude);
            } else {
                System.debug('Geocoding failed for Account: ' + accountId + 
                           ' Error: ' + result.errorMessage);
            }
            
        } catch (Exception e) {
            System.debug('Exception in geocodeAccount: ' + e.getMessage());
        }
    }
    
    @TestVisible
    private static Account getAccountBillingAddress(Id accountId) {
        try {
            return [SELECT Id, BillingStreet, BillingCity, BillingState, 
                          BillingPostalCode, BillingCountry 
                   FROM Account 
                   WHERE Id = :accountId 
                   LIMIT 1];
        } catch (QueryException e) {
            System.debug('Query exception: ' + e.getMessage());
            return null;
        }
    }
    
    @TestVisible
    private static String buildAddressString(Account acc) {
        List<String> addressParts = new List<String>();
        
        if (String.isNotBlank(acc.BillingStreet)) {
            addressParts.add(acc.BillingStreet);
        }
        if (String.isNotBlank(acc.BillingCity)) {
            addressParts.add(acc.BillingCity);
        }
        if (String.isNotBlank(acc.BillingState)) {
            addressParts.add(acc.BillingState);
        }
        if (String.isNotBlank(acc.BillingPostalCode)) {
            addressParts.add(acc.BillingPostalCode);
        }
        if (String.isNotBlank(acc.BillingCountry)) {
            addressParts.add(acc.BillingCountry);
        }
        
        return String.join(addressParts, ', ');
    }
    
    @TestVisible
    private static GeocodeResult callGeocodingAPI(String address) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            String encodedAddress = EncodingUtil.urlEncode(address, 'UTF-8');
            String endpoint = NOMINATIM_ENDPOINT + '?format=json&limit=1&q=' + encodedAddress;
            
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setTimeout(TIMEOUT);
            request.setHeader('User-Agent', 'Salesforce-GeocodeService/1.0');
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                return parseGeocodingResponse(response.getBody());
            } else {
                return new GeocodeResult(false, null, null, 
                    'HTTP Error: ' + response.getStatusCode() + ' - ' + response.getStatus());
            }
            
        } catch (Exception e) {
            return new GeocodeResult(false, null, null, 
                'Exception during API call: ' + e.getMessage());
        }
    }
    
    @TestVisible
    private static GeocodeResult parseGeocodingResponse(String responseBody) {
        try {
            List<Object> results = (List<Object>) JSON.deserializeUntyped(responseBody);
            
            if (results == null || results.isEmpty()) {
                return new GeocodeResult(false, null, null, 'No geocoding results found');
            }
            
            Map<String, Object> firstResult = (Map<String, Object>) results[0];
            String latStr = (String) firstResult.get('lat');
            String lonStr = (String) firstResult.get('lon');
            
            if (String.isBlank(latStr) || String.isBlank(lonStr)) {
                return new GeocodeResult(false, null, null, 'Invalid coordinates in response');
            }
            
            Decimal latitude = Decimal.valueOf(latStr);
            Decimal longitude = Decimal.valueOf(lonStr);
            
            return new GeocodeResult(true, latitude, longitude, null);
            
        } catch (Exception e) {
            return new GeocodeResult(false, null, null, 
                'Error parsing response: ' + e.getMessage());
        }
    }
    
    @TestVisible
    private static void updateAccountCoordinates(Id accountId, Decimal latitude, Decimal longitude) {
        try {
            Account acc = new Account(
                Id = accountId,
                Billing_Latitude__c = latitude,
                Billing_Longitude__c = longitude
            );
            
            update acc;
            
        } catch (DmlException e) {
            System.debug('DML Exception updating coordinates: ' + e.getMessage());
        }
    }
}