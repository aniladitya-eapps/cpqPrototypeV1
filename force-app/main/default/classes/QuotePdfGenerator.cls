/**
 * Apex class to generate PDFs for Quotes with cart items and custom text
 */
public with sharing class QuotePdfGenerator {
    
    /**
     * Generates a PDF for a quote with cart items and custom text
     * @param quoteId The ID of the quote to generate PDF for
     * @param customText Custom text to include in the PDF
     * @return The generated PDF as a base64 string
     */
    @AuraEnabled
    public static String generateQuotePdf(Id quoteId, String customText) {
        try {
            // Validate input
            if (quoteId == null) {
                throw new AuraHandledException('quoteId is required');
            }

            // Create PDF document via Visualforce, pass only params; VF controller will query the Quote
            Blob pdfBlob = createQuotePdfDocument(quoteId, customText);

            // Convert to base64 string for return
            return EncodingUtil.base64Encode(pdfBlob);

        } catch (Exception e) {
            System.debug('Error generating PDF: ' + e.getMessage());
            throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
        }
    }
    
    /**
     * Creates the actual PDF document using Visualforce
     * @param quote The quote record
     * @param quoteLines The quote line items
     * @param customText Custom text to include in the PDF
     * @return The generated PDF as a Blob
     */
    private static Blob createQuotePdfDocument(Id quoteId, String customText) {
        // Create a Visualforce page to render the PDF
        PageReference pdfPage = new PageReference('/apex/QuotePdfTemplate');
        pdfPage.getParameters().put('quoteId', String.valueOf(quoteId));
        if (customText != null) {
            pdfPage.getParameters().put('customText', customText);
        }

        // Render the page as PDF
        return pdfPage.getContentAsPdf();
    }
    
    /**
     * Alternative method to generate PDF directly using Apex (without Visualforce)
     * This method would require more complex implementation with PDF libraries
     * For simplicity, we'll use the Visualforce approach
     */
    @AuraEnabled
    public static String generateQuotePdfDirect(Id quoteId, String customText) {
        // This would be a more complex implementation using external libraries
        // For now, we'll use the Visualforce approach which is simpler and more reliable
        return generateQuotePdf(quoteId, customText);
    }
}
