/** Apex Controller: ProductSearchController.cls (fixed wrapper and braces) */
public with sharing class ProductSearchController {
    @AuraEnabled(cacheable=true)
    public static List<Product2Wrapper> searchProducts(String searchKey) {
        String key = '%' + searchKey + '%';

        // Ensure we pull UnitPrice from the STANDARD PRICE BOOK specifically
        Id standardPbId;
        try {
            standardPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        } catch (Exception e) {
            // No Standard Price Book found; return empty
            return new List<Product2Wrapper>();
        }

        List<Product2> products = [
            SELECT Id, Name, ProductCode, Family, Description, IsActive, CreatedDate,
                   (SELECT Id, UnitPrice, Pricebook2Id
                    FROM PricebookEntries
                    WHERE IsActive = true AND Pricebook2Id = :standardPbId
                    LIMIT 1)
            FROM Product2
            WHERE Name LIKE :key
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        List<Product2Wrapper> results = new List<Product2Wrapper>();
        for (Product2 p : products) {
            Decimal unitPrice;
            if (!p.PricebookEntries.isEmpty()) {
                unitPrice = p.PricebookEntries[0].UnitPrice;
            }
            // Quantity placeholder - populate if you have a source
            // For in-memory field, we'll set a default quantity of 1
            results.add(new Product2Wrapper(
                p.Id,
                p.ProductCode,
                unitPrice,
                1
            ));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product2> searchBundledProducts() {
        // Query for all bundled products (where Bundled__c is true)
        List<Product2> products = [
            SELECT Id, Name, ProductCode, Family, Description, IsActive
            FROM Product2
            WHERE Bundled__c = true
            ORDER BY Name
        ];
        return products;
    }

    // Simple DTO for LWC (avoid __ in identifier names)
    public class Product2Wrapper {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String ProductCode { get; set; }
        @AuraEnabled public Decimal UnitPrice { get; set; }
        @AuraEnabled public Decimal Quantity { get; set; }

        public Product2Wrapper(Id id, String productCode, Decimal unitPrice, Decimal quantity) {
            this.Id = id;
            this.ProductCode = productCode;
            this.UnitPrice = unitPrice;
            this.Quantity = quantity;
        }
    }

    /**
     * pricingEngine - Calculate prices for a list of product/quantity pairs using a given pricebook.
     * If pricebookId is null, attempts to use the Standard Price Book; if that's not available,
     * falls back to any active Pricebook2. Returns per-line details and a grand total.
     */
    @AuraEnabled
    public static PriceCalculationResult pricingEngine(List<ProductQuantity> items, Id pricebookId) {
        if (items == null || items.isEmpty()) {
            return new PriceCalculationResult(new List<PriceLine>(), 0);
        }

        Id pbId = pricebookId;
        if (pbId == null) {
            try {
                pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            } catch (Exception e) {
                // No standard pricebook found in this context; try any active pricebook
                List<Pricebook2> pbs = [SELECT Id FROM Pricebook2 WHERE IsActive = true LIMIT 1];
                if (pbs.isEmpty()) {
                    return new PriceCalculationResult(new List<PriceLine>(), 0);
                }
                pbId = pbs[0].Id;
            }
        }

        Set<Id> productIds = new Set<Id>();
        for (ProductQuantity pq : items) {
            if (pq != null && pq.productId != null) productIds.add(pq.productId);
        }
        if (productIds.isEmpty()) return new PriceCalculationResult(new List<PriceLine>(), 0);

        Map<Id, PricebookEntry> priceMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice, Pricebook2Id
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
              AND Pricebook2Id = :pbId
              AND IsActive = true
        ]) {
            priceMap.put(pbe.Product2Id, pbe);
        }

        List<PriceLine> lines = new List<PriceLine>();
        Decimal grandTotal = 0;
        for (ProductQuantity pq : items) {
            Decimal qty = (pq == null || pq.quantity == null) ? 0 : pq.quantity;
            Decimal unit = 0;
            if (pq != null && priceMap.containsKey(pq.productId)) {
                unit = priceMap.get(pq.productId).UnitPrice;
            }
            Decimal lineTotal = unit * qty;
            grandTotal += lineTotal;
            lines.add(new PriceLine(pq == null ? null : pq.productId, unit, qty, lineTotal));
        }

        return new PriceCalculationResult(lines, grandTotal);
    }

    // Input DTO for pricingEngine
    public class ProductQuantity {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }

        public ProductQuantity() {}
        public ProductQuantity(Id productId, Decimal quantity) {
            this.productId = productId;
            this.quantity = quantity;
        }
    }

    // Per-line result
    public class PriceLine {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal lineTotal { get; set; }

        public PriceLine() {}
        public PriceLine(Id productId, Decimal unitPrice, Decimal quantity, Decimal lineTotal) {
            this.productId = productId;
            this.unitPrice = unitPrice;
            this.quantity = quantity;
            this.lineTotal = lineTotal;
        }
    }

    // Aggregated pricing result
    public class PriceCalculationResult {
        @AuraEnabled public List<PriceLine> lines { get; set; }
        @AuraEnabled public Decimal grandTotal { get; set; }

        public PriceCalculationResult() {
            this.lines = new List<PriceLine>();
            this.grandTotal = 0;
        }
        public PriceCalculationResult(List<PriceLine> lines, Decimal grandTotal) {
            this.lines = lines;
            this.grandTotal = grandTotal;
        }
    }
}
