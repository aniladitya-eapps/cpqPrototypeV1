/**
 * Controller for the ProductPageWithQuote Visualforce page
 */
public with sharing class ProductPageWithQuoteController {
    public String quoteId { get; set; }
    
    public ProductPageWithQuoteController() {
        // Get the quoteId from the URL parameters
        quoteId = ApexPages.currentPage().getParameters().get('quoteId');
    }
}
