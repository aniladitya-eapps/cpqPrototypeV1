/**
 * Controller for the Quote PDF Template Visualforce page
 */
public with sharing class QuotePdfController {
    public cg_Quote__c quote { get; set; }
    // Strongly-typed DTO for cart lines passed from LWC
    public class CartLineDTO {
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public Decimal qty { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal discount { get; set; } // percent (0-100) or amount depending on LWC
        @AuraEnabled public Decimal total { get; set; }
    }
    public List<CartLineDTO> cartLines { get; set; }
    public String customText { get; set; }
    public String quoteId { get; set; }
    
    public QuotePdfController() {
        cartLines = new List<CartLineDTO>();
        
        // Read parameters
        quoteId = ApexPages.currentPage().getParameters().get('quoteId');
        customText = ApexPages.currentPage().getParameters().get('customText');
        String cartItemsJson = ApexPages.currentPage().getParameters().get('cartItemsJson');
        
        // If quoteId provided, load limited cg_Quote__c fields that exist in repo
        if (quoteId != null) {
            quote = [SELECT Id, cg_Quote_number__c, cg_Account__c, cg_Account__r.Name
                     FROM cg_Quote__c WHERE Id = :quoteId LIMIT 1];
        }
        
        // If cart JSON provided, parse to DTOs
        if (!String.isBlank(cartItemsJson)) {
            try {
                List<Object> raw = (List<Object>) JSON.deserializeUntyped(cartItemsJson);
                for (Object o : raw) {
                    Map<String, Object> m = (Map<String, Object>) o;
                    CartLineDTO dto = new CartLineDTO();
                    dto.productCode = (String) m.get('productCode');
                    // Coerce numeric values safely
                    dto.qty = toDecimal(m.get('qty'));
                    dto.unitPrice = toDecimal(m.get('unitPrice'));
                    dto.discount = toDecimal(m.get('discount'));
                    dto.total = toDecimal(m.get('total'));
                    cartLines.add(dto);
                }
            } catch (Exception e) {
                // If parsing fails, leave cartLines empty
                System.debug('Failed to parse cartItemsJson: ' + e.getMessage());
            }
        }
    }
    
    private static Decimal toDecimal(Object v) {
        if (v == null) return 0;
        if (v instanceof Decimal) return (Decimal) v;
        if (v instanceof Integer) return Decimal.valueOf((Integer) v);
        if (v instanceof Long) return Decimal.valueOf((Long) v);
        if (v instanceof Double) return Decimal.valueOf((Double) v);
        if (v instanceof String) {
            try { return Decimal.valueOf((String) v); } catch (Exception e) { return 0; }
        }
        return 0;
    }
}
