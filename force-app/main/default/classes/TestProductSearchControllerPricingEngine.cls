@isTest
private class TestProductSearchControllerPricingEngine {
    @isTest static void testPricingEngineWithStandardPricebook() {
        // Create test products
        Product2 p1 = new Product2(Name='Test Product A', ProductCode='TPA', IsActive=true);
        Product2 p2 = new Product2(Name='Test Product B', ProductCode='TPB', IsActive=true);
        insert new List<Product2>{p1, p2};

        // Activate and get or create a standard pricebook
        Pricebook2 std = [SELECT Id, IsStandard FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

        // Create pricebook entries for standard pricebook
        PricebookEntry e1 = new PricebookEntry(Product2Id = p1.Id, Pricebook2Id = std.Id, UnitPrice = 10, IsActive = true);
        PricebookEntry e2 = new PricebookEntry(Product2Id = p2.Id, Pricebook2Id = std.Id, UnitPrice = 20, IsActive = true);
        insert new List<PricebookEntry>{e1, e2};

        // Prepare input
        List<ProductSearchController.ProductQuantity> items = new List<ProductSearchController.ProductQuantity>{
            new ProductSearchController.ProductQuantity(p1.Id, 2),
            new ProductSearchController.ProductQuantity(p2.Id, 3)
        };

        Test.startTest();
        ProductSearchController.PriceCalculationResult res = ProductSearchController.pricingEngine(items, null);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(2, res.lines.size());
        // line totals: p1 = 10*2 = 20, p2 = 20*3 = 60 => grandTotal = 80
        Decimal expectedGrand = 80;
        System.assertEquals(expectedGrand, res.grandTotal);
    }
}
