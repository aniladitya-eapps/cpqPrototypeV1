/**
 * Service class to handle quote-related operations
 */
public with sharing class QuoteService {

    /**
     * Retrieves the quote number for a given quote ID
     * @param quoteId The ID of the quote
     * @return The quote number or null if not found / not accessible
     */
    @AuraEnabled(cacheable=true)
    public static String getQuoteNumber(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required');
        }

        // Enforce FLS for the field we return
        List<cg_Quote__c> rows = [
            SELECT cg_Quote_number__c
            FROM cg_Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];
        // Strip any fields the caller cannot access
        rows = (List<cg_Quote__c>) Security.stripInaccessible(
            AccessType.READABLE,
            rows
        ).getRecords();

        if (rows.isEmpty()) return null;
        return rows[0].cg_Quote_number__c;
    }

    /**
     * Returns Bill To and Ship To addresses from the Opportunity's Account
     * Keys: accountName, billToStreet, billToCity, billToState, billToPostalCode, billToCountry,
     *       shipToStreet,  shipToCity,  shipToState,  shipToPostalCode,  shipToCountry
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getOpportunityAddresses(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required');
        }

        // Query the Opportunity and its Account address fields
        List<Opportunity> rows = [
            SELECT Id,
                   AccountId,
                   Account.Name,
                   Account.BillingStreet,  Account.BillingCity,  Account.BillingState,
                   Account.BillingPostalCode,  Account.BillingCountry,
                   Account.ShippingStreet, Account.ShippingCity, Account.ShippingState,
                   Account.ShippingPostalCode, Account.ShippingCountry
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        // Enforce FLS for all potentially returned fields
        rows = (List<Opportunity>) Security.stripInaccessible(
            AccessType.READABLE,
            rows
        ).getRecords();

        if (rows.isEmpty()) {
            // No such Opportunity (or not visible)
            return new Map<String, String>();
        }

        Opportunity opp = rows[0];
        Account acct = opp.Account;

        Map<String, String> result = new Map<String, String>();
        result.put('accountName', acct != null ? acct.Name : null);

        // Bill To (Account billing)
        result.put('billToStreet',     acct != null ? acct.BillingStreet     : null);
        result.put('billToCity',       acct != null ? acct.BillingCity       : null);
        result.put('billToState',      acct != null ? acct.BillingState      : null);
        result.put('billToPostalCode', acct != null ? acct.BillingPostalCode : null);
        result.put('billToCountry',    acct != null ? acct.BillingCountry    : null);

        // Ship To (Account shipping)
        result.put('shipToStreet',     acct != null ? acct.ShippingStreet     : null);
        result.put('shipToCity',       acct != null ? acct.ShippingCity       : null);
        result.put('shipToState',      acct != null ? acct.ShippingState      : null);
        result.put('shipToPostalCode', acct != null ? acct.ShippingPostalCode : null);
        result.put('shipToCountry',    acct != null ? acct.ShippingCountry    : null);

        return result;
    }

    /**
     * Retrieves specific fields from a quote record
     * @param quoteId The ID of the quote
     * @param fieldNames A list of field API names to retrieve (optional, defaults to common fields)
     * @return A map containing requested quote fields
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getQuoteFields(Id quoteId, List<String> fieldNames) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required');
        }

        // Default fields to retrieve if none specified
        if (fieldNames == null || fieldNames.isEmpty()) {
            fieldNames = new List<String>{'Id', 'cg_Quote_number__c', 'cg_Quote_Status__c'};
        }

        // Build the SOQL query dynamically
        String query = 'SELECT ';
        for (Integer i = 0; i < fieldNames.size(); i++) {
            if (i > 0) query += ', ';
            query += fieldNames[i];
        }
        query += ' FROM cg_Quote__c WHERE Id = :quoteId LIMIT 1';

        // Query the quote with the specified fields
        List<cg_Quote__c> rows = Database.query(query);
        
        // Strip any fields the caller cannot access
        rows = (List<cg_Quote__c>) Security.stripInaccessible(
            AccessType.READABLE,
            rows
        ).getRecords();

        Map<String, Object> result = new Map<String, Object>();
        
        if (rows.isEmpty()) {
            return result;
        }
        
        cg_Quote__c quote = rows[0];
        // Populate the result map with the requested fields
        for (String fieldName : fieldNames) {
            if (fieldName == 'Id') {
                result.put('id', quote.Id);
            } else if (fieldName == 'cg_Quote_number__c') {
                result.put('quoteNumber', quote.cg_Quote_number__c);
            } else if (fieldName == 'cg_Quote_Status__c') {
                result.put('quoteStatus', quote.cg_Quote_Status__c);
            } else {
                // For other fields, we can get the value dynamically
                // This is a simplified approach - in a real scenario you'd want to handle this more robustly
                result.put(fieldName, quote.get(fieldName));
            }
        }
        
        return result;
    }
}
