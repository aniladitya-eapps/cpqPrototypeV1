/**
 * Apex class to create a quote from an opportunity and redirect to product page
 */
public with sharing class CreateQuoteFromOpportunity {
    
    /**
     * Creates a new quote from an opportunity and redirects to product page
     * @param opportunityId The ID of the opportunity to create quote from
     * @return The ID of the newly created quote
     */
    @AuraEnabled
    public static String createQuoteFromOpportunity(Id opportunityId) {
        try {
            // Validate input
            if (opportunityId == null) {
                throw new AuraHandledException('Opportunity ID is required');
            }
            
            // Query the opportunity to get required fields
            Opportunity opp = [SELECT Id, AccountId, Name, CloseDate, StageName, Account.Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            
            // Create a new quote record
            cg_Quote__c newQuote = new cg_Quote__c();
            newQuote.cg_Opportunity__c = opportunityId;
            
            // Populate required fields from opportunity
            if (opp.AccountId != null) {
                newQuote.cg_Account__c = opp.AccountId;
            }
            
            // Set the quote name as "Account Name + Opportunity Name"
            if (opp.Account.Name != null && opp.Name != null) {
                newQuote.Name = opp.Account.Name + ' - ' + opp.Name;
            } else if (opp.Name != null) {
                newQuote.Name = opp.Name;
            } else if (opp.Account.Name != null) {
                newQuote.Name = opp.Account.Name;
            }
            
            // Insert the new quote
            insert newQuote;
            
            // Return the quote ID for redirection
            return newQuote.Id;
            
        } catch (Exception e) {
            System.debug('Error creating quote from opportunity: ' + e.getMessage());
            throw new AuraHandledException('Failed to create quote: ' + e.getMessage());
        }
    }
}
