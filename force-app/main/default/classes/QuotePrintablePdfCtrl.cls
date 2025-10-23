public with sharing class QuotePrintablePdfCtrl {
    public QuotePrintCache.PrintPayload payload { get; private set; }

    // Null/Key-safe address fields for VF bindings
    public String billToStreet     { get; private set; }
    public String billToCity       { get; private set; }
    public String billToState      { get; private set; }
    public String billToPostalCode { get; private set; }
    public String billToCountry    { get; private set; }

    public String shipToStreet     { get; private set; }
    public String shipToCity       { get; private set; }
    public String shipToState      { get; private set; }
    public String shipToPostalCode { get; private set; }
    public String shipToCountry    { get; private set; }

    public QuotePrintablePdfCtrl() {
        String key = ApexPages.currentPage().getParameters().get('k');
        if (String.isBlank(key)) {
            payload = new QuotePrintCache.PrintPayload();
        } else {
            payload = QuotePrintCache.getAndConsume(key);
        }
        // Fill safe fields (no exceptions if map/keys missing)
        billToStreet     = getSafe(payload != null ? payload.billTo : null, 'street');
        billToCity       = getSafe(payload != null ? payload.billTo : null, 'city');
        billToState      = getSafe(payload != null ? payload.billTo : null, 'state');
        billToPostalCode = getSafe(payload != null ? payload.billTo : null, 'postalCode');
        billToCountry    = getSafe(payload != null ? payload.billTo : null, 'country');

        shipToStreet     = getSafe(payload != null ? payload.shipTo : null, 'street');
        shipToCity       = getSafe(payload != null ? payload.shipTo : null, 'city');
        shipToState      = getSafe(payload != null ? payload.shipTo : null, 'state');
        shipToPostalCode = getSafe(payload != null ? payload.shipTo : null, 'postalCode');
        shipToCountry    = getSafe(payload != null ? payload.shipTo : null, 'country');
    }

    private static String getSafe(Map<String,String> m, String key) {
        if (m == null) return '';
        if (!m.containsKey(key)) return '';
        String v = m.get(key);
        return v == null ? '' : v;
    }
}
