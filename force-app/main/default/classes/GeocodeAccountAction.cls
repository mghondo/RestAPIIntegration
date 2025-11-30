public class GeocodeAccountAction {
    
    public class GeocodeRequest {
        @InvocableVariable(label='Account IDs' description='List of Account IDs to geocode' required=true)
        public List<Id> accountIds;
    }
    
    public class GeocodeResponse {
        @InvocableVariable(label='Success' description='Whether the geocoding was successfully queued')
        public Boolean success;
        
        @InvocableVariable(label='Message' description='Result message')
        public String message;
        
        @InvocableVariable(label='Accounts Queued' description='Number of accounts queued for geocoding')
        public Integer accountsQueued;
    }
    
    @InvocableMethod(label='Geocode Account Addresses' 
                     description='Queues geocoding for the provided Account IDs' 
                     category='Account')
    public static List<GeocodeResponse> geocodeAccounts(List<GeocodeRequest> requests) {
        List<GeocodeResponse> responses = new List<GeocodeResponse>();
        
        for (GeocodeRequest request : requests) {
            GeocodeResponse response = new GeocodeResponse();
            
            try {
                if (request.accountIds == null || request.accountIds.isEmpty()) {
                    response.success = false;
                    response.message = 'No Account IDs provided';
                    response.accountsQueued = 0;
                } else {
                    List<Id> validAccountIds = validateAccountIds(request.accountIds);
                    
                    if (validAccountIds.isEmpty()) {
                        response.success = false;
                        response.message = 'No valid Account IDs found';
                        response.accountsQueued = 0;
                    } else {
                        GeocodeQueueable.enqueueGeocoding(validAccountIds);
                        response.success = true;
                        response.message = 'Geocoding queued successfully';
                        response.accountsQueued = validAccountIds.size();
                    }
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                response.accountsQueued = 0;
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    private static List<Id> validateAccountIds(List<Id> accountIds) {
        List<Id> validIds = new List<Id>();
        
        try {
            Set<Id> accountIdSet = new Set<Id>(accountIds);
            List<Account> existingAccounts = [SELECT Id FROM Account WHERE Id IN :accountIdSet];
            
            for (Account acc : existingAccounts) {
                validIds.add(acc.Id);
            }
        } catch (Exception e) {
            System.debug('Error validating Account IDs: ' + e.getMessage());
        }
        
        return validIds;
    }
}