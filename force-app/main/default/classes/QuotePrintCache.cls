public with sharing class QuotePrintCache {
    // If you have a namespace, change 'local' -> 'yourNs'
    public static final String SESSION_PARTITION = 'local.QuotePrint';
    public static final Integer TTL_SECONDS = 300; // 5 minutes

    public class PrintPayload {
        public String quoteId           { get; set; }
        public String quoteNumber       { get; set; }
        public Map<String, String> billTo { get; set; }
        public Map<String, String> shipTo { get; set; }
        public List<LineItem> items     { get; set; }
        public String terms             { get; set; }
    }
    public class LineItem {
        public String  ProductCode   { get; set; }
        public Decimal Quantity      { get; set; }
        public Decimal UnitPrice     { get; set; }
        public String  DiscountType  { get; set; } // 'Amount' | 'Percent'
        public Decimal DiscountValue { get; set; } // amount or percent
        public Decimal NetPrice      { get; set; }
    }

    @AuraEnabled
    public static String createCacheJob(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            throw new AuraHandledException('Missing print payload.');
        }
        Cache.SessionPartition part = Cache.Session.getPartition(SESSION_PARTITION);
        if (part == null) {
            throw new AuraHandledException('Platform Cache partition not found: ' + SESSION_PARTITION);
        }
        String key = generateKey();
        part.put(key, payloadJson, TTL_SECONDS);
        return key;
    }

    public static PrintPayload getAndConsume(String key) {
        Cache.SessionPartition part = Cache.Session.getPartition(SESSION_PARTITION);
        if (part == null) {
            throw new AuraHandledException('Platform Cache partition not found: ' + SESSION_PARTITION);
        }
        Object raw = part.get(key);
        if (raw == null) {
            throw new AuraHandledException('Print data expired or not found.');
        }
        part.remove(key);
        String jsonPayload = (String) raw;
        return (PrintPayload) JSON.deserialize(jsonPayload, PrintPayload.class);
    }

    private static String generateKey() {
        Blob seed = Blob.valueOf(UserInfo.getSessionId() + String.valueOf(System.now().getTime()));
        String hex = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', seed));
        return hex.substring(0, 24);
    }
}
