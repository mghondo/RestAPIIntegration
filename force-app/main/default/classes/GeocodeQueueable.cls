public class GeocodeQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<Id> accountIds;
    private static final Integer BATCH_SIZE = 100;
    
    public GeocodeQueueable(List<Id> accountIds) {
        this.accountIds = accountIds;
    }
    
    public void execute(QueueableContext context) {
        if (accountIds == null || accountIds.isEmpty()) {
            System.debug('No account IDs provided to GeocodeQueueable');
            return;
        }
        
        List<Id> currentBatch = new List<Id>();
        List<Id> remainingIds = new List<Id>();
        
        for (Integer i = 0; i < accountIds.size(); i++) {
            if (i < BATCH_SIZE) {
                currentBatch.add(accountIds[i]);
            } else {
                remainingIds.add(accountIds[i]);
            }
        }
        
        System.debug('Processing batch of ' + currentBatch.size() + ' accounts');
        
        for (Id accountId : currentBatch) {
            try {
                GeocodeService.geocodeAccount(accountId);
            } catch (Exception e) {
                System.debug('Error geocoding account ' + accountId + ': ' + e.getMessage());
            }
        }
        
        if (!remainingIds.isEmpty()) {
            System.debug('Queueing remaining ' + remainingIds.size() + ' accounts');
            if (!Test.isRunningTest()) {
                System.enqueueJob(new GeocodeQueueable(remainingIds));
            }
        }
    }
    
    public static void enqueueGeocoding(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            System.debug('No account IDs provided to enqueueGeocoding');
            return;
        }
        
        System.debug('Enqueuing geocoding for ' + accountIds.size() + ' accounts');
        System.enqueueJob(new GeocodeQueueable(accountIds));
    }
}