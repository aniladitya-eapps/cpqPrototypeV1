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

            // Create PDF document via Visualforce; VF controller will query the Quote header
            Blob pdfBlob = createQuotePdfDocument(quoteId, customText, null);

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
    private static Blob createQuotePdfDocument(Id quoteId, String customText, String cartItemsJson) {
        // Create a Visualforce page to render the PDF
        PageReference pdfPage = new PageReference('/apex/QuotePdfTemplate');
        if (quoteId != null) {
            pdfPage.getParameters().put('quoteId', String.valueOf(quoteId));
        }
        if (customText != null) {
            pdfPage.getParameters().put('customText', customText);
        }
        if (cartItemsJson != null) {
            // Pass JSON of cart items to VF; controller will parse for rendering
            pdfPage.getParameters().put('cartItemsJson', cartItemsJson);
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

    /**
     * New: Generate PDF strictly from cart items JSON (no schema changes).
     * @param customText Custom text block for the PDF
     * @param cartItemsJson JSON array of items: [{productCode, qty, unitPrice, discount, total}, ...]
     */
    @AuraEnabled
    public static String generatePdfFromCart(String customText, String cartItemsJson) {
        try {
            if (String.isBlank(cartItemsJson)) {
                throw new AuraHandledException('cartItemsJson is required');
            }
            Blob pdfBlob = createQuotePdfDocument(null, customText, cartItemsJson);
            return EncodingUtil.base64Encode(pdfBlob);
        } catch (Exception e) {
            System.debug('Error generating PDF from cart: ' + e.getMessage());
            throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
        }
    }
}
