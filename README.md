# Salesforce CPQ Prototype - PDF Generator

This project includes a PDF generator feature that can take data from the product cart and also let you add custom text.

## Features

1. **Product Cart Component**: Displays selected products with quantities and pricing
2. **PDF Generation**: 
   - Generate PDFs from cart items
   - Add custom text to be included in the PDF
   - Two PDF generation options:
     - Download PDF (using jsPDF for immediate client-side generation)
     - Generate Quote PDF (using Visualforce for more professional formatting)

## Implementation Details

### Apex Classes
- `QuotePdfGenerator.cls`: Main Apex class for PDF generation
- `QuotePdfController.cls`: Controller for the Visualforce PDF template

### Visualforce Page
- `QuotePdfTemplate.page`: Template for generating professional PDFs with custom text

### Lightning Web Component
- `productCart`: Enhanced with custom text input and PDF generation buttons

## How to Use

1. Add products to the cart using the product search functionality
2. Enter any custom text you want to include in the PDF
3. Click "Generate Quote PDF" to create a professionally formatted PDF with:
   - Cart items and their details
   - Custom text (if provided)
   - Pricing breakdown (subtotal, tax, shipping, grand total)

## Technical Architecture

The solution uses a hybrid approach:
- Client-side PDF generation with jsPDF for quick previews
- Server-side PDF generation with Visualforce for professional formatting
- Integration with existing Quote__c and Quote_Line__c objects

## Deployment

To deploy this functionality:
1. Deploy all Apex classes and Visualforce pages
2. Deploy the updated LWC component
3. Ensure proper permissions are set for the Quote__c and Quote_Line__c objects

## Future Enhancements

- Integration with actual Quote__c record creation
- Support for different PDF templates
- Export to other formats (Word, Excel)
- Enhanced customization options for PDF styling
