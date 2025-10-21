/**
 * Controller for the Quote PDF Template Visualforce page
 */
public with sharing class QuotePdfController {
    public Quote__c quote { get; set; }
    public List<sObject> quoteLines { get; set; }
    public String customText { get; set; }
    public String quoteId { get; set; }
    
    public QuotePdfController() {
        // Initialize to avoid null checks in VF
        quoteLines = new List<sObject>();
        
        // Get the quote ID from the page parameters
        quoteId = ApexPages.currentPage().getParameters().get('quoteId');
        customText = ApexPages.currentPage().getParameters().get('customText');
        
        if (quoteId != null) {
            // Load the quote record (limit fields to those present in repo)
            quote = [SELECT Id, Quote_Number__c, Account__c, Account__r.Name, Notes__c, 
                     Grand_Total_Formula__c, Header_Charges_Formula__c, 
                     Header_Discount_Amt__c, Tax_Total_Formula__c, 
                     Shipping_Amount__c, Subtotal_Rollup__c, CreatedDate
                     FROM Quote__c WHERE Id = :quoteId LIMIT 1];
            
            // No Quote_Line__c fields available in repo; skip querying lines to avoid deployment errors
        }
    }
}
