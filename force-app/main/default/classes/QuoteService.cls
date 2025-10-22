/**
 * Service class to handle quote-related operations
 */
public with sharing class QuoteService {
    
    /**
     * Retrieves the quote number for a given quote ID
     * @param quoteId The ID of the quote
     * @return The quote number or null if not found
     */
    @AuraEnabled
    public static String getQuoteNumber(Id quoteId) {
        try {
            if (quoteId == null) {
                return null;
            }
            
            // Query the quote to get its number
            cg_Quote__c quote = [SELECT cg_Quote_number__c FROM cg_Quote__c WHERE Id = :quoteId LIMIT 1];
            
            return quote.cg_Quote_number__c;
            
        } catch (Exception e) {
            System.debug('Error retrieving quote number: ' + e.getMessage());
            return null;
        }
    }
}
