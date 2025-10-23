/**
 * Controller for the ProductPageWithQuote Visualforce page
 */
public with sharing class ProductPageWithQuoteController {
    public String quoteId { get; set; }
    public String quoteNumber { get; set; }
    
    public ProductPageWithQuoteController() {
        // Get the quoteId from the URL parameters
        quoteId = ApexPages.currentPage().getParameters().get('quoteId');
        
        // Get the quote number if quoteId is provided
        if (quoteId != null) {
            cg_Quote__c quote = [SELECT cg_Quote_number__c FROM cg_Quote__c WHERE Id = :quoteId LIMIT 1];
            if (quote != null) {
                quoteNumber = quote.cg_Quote_number__c;
            }
        }
    }
}
