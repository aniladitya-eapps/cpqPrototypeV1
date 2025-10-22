import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import jsPDF from '@salesforce/resourceUrl/jsPDF';
import jsPDFAutoTable from '@salesforce/resourceUrl/jsPDF_AutoTable';
import generateQuotePdf from '@salesforce/apex/QuotePdfGenerator.generateQuotePdf';
import getQuoteNumber from '@salesforce/apex/QuoteService.getQuoteNumber';


export default class ProductCart extends LightningElement {
@api quoteId; // Optional: pass a cg_Quote__c Id from parent when available
@track cartItems = [];
@track customText = '';
@track quoteNumber;
pdfLibsNotLoaded = true;


connectedCallback() {
    Promise.all([
        loadScript(this, jsPDF),
        loadScript(this, jsPDFAutoTable)
    ])
    .then(() => {
        // jsPDF UMD builds expose window.jspdf.jsPDF
        this.pdfLibsNotLoaded = false;
    })
    .catch(() => {
        this.pdfLibsNotLoaded = true; // keep button disabled
    });
    
    // Fetch quote number when quoteId is available
    if (this.quoteId) {
        this.fetchQuoteNumber();
    }
}

/**
 * Download PDF using server-side Apex + Visualforce.
 * Uses cart items directly (no cg_Quote__c required).
 */
async handleDownloadServerPdf() {
  try {
    // Prepare cart items in the expected format for Apex
    const cartItems = this.cartItems.map(item => ({
      productCode: item.ProductCode || '',
      qty: item.Quantity || 0,
      unitPrice: item.UnitPrice || 0,
      discount: 0, // No discount in current cart data
      total: (item.UnitPrice || 0) * (item.Quantity || 0)
    }));

    const base64 = await generateQuotePdf({ 
      quoteId: null, 
      customText: this.customText || '',
      cartItemsJson: JSON.stringify(cartItems)
    });

    // Create a blob and trigger download
    const byteCharacters = atob(base64);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: 'application/pdf' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = 'Quote.pdf';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (e) {
    // Fallback to print if CSP blocks blob or other errors occur
    this.handlePrint();
  }
}


@api
addItem(product) {
  console.log('Received from productSearch:', JSON.parse(JSON.stringify(product))); // Debug log
  // Normalize quantity coming from Product Search (Quantity or Quantity__c)
  const qty = Number(product.Quantity ?? product.Quantity__c ?? 1) || 1;
  const existing = this.cartItems.find(p => p.Id === product.Id);
  if (existing) {
    existing.Quantity = (existing.Quantity || 0) + qty;
    this.cartItems = [...this.cartItems];
  } else {
    this.cartItems = [...this.cartItems, { ...product, Quantity: qty }];
  }
}


handleRemove(event) {
  const productId = event.target.dataset.id;
  this.cartItems = this.cartItems.filter(p => p.Id !== productId);
}


handlePrint() {
  // Basic print of the HTML area; relies on CSS below for a clean layout
  window.print();
}


handleDownloadPdf() {
try {
const { jsPDF } = window.jspdf || {};
if (!jsPDF || !window.jspdf) {
  // Fallback safeguard
  this.handlePrint();
  return;
}
const doc = new jsPDF({ unit: 'pt', format: 'a4' });


const title = 'Cart Items';
doc.setFontSize(14);
doc.text(title, 40, 40);


const head = [['Name', 'Product Code', 'Qty']];
const body = this.cartItems.map(i => [i.Name || '', i.ProductCode || '', String(i.Quantity || 1)]);


// autoTable attached globally by plugin
// eslint-disable-next-line no-undef
window.jspdfAutoTable ? window.jspdfAutoTable(doc, { head, body, startY: 60 }) : doc.autoTable({ head, body, startY: 60 });


doc.save('Cart.pdf');
} catch (e) {
// If PDF fails (e.g., CSP), fallback to browser print
this.handlePrint();
  }
}


handleGenerateQuotePdf() {
  // Create a simple quote record with cart items for PDF generation
  // In a real implementation, you'd create a cg_Quote__c record first
  
  // For now, we'll use the existing cart data to generate a PDF
  // We'll create a temporary quote for demonstration purposes
  
  // In a production environment, you would:
  // 1. Create a cg_Quote__c record
  // 2. Add cg_Quote_Lines__c records for each cart item
  // 3. Call the generateQuotePdf method with the quote ID and custom text
  
  // Since we don't have a backend service to create quotes yet,
  // we'll just use the existing jsPDF functionality to generate a PDF
  // with the cart items and custom text
  
  try {
    const { jsPDF } = window.jspdf || {};
    if (!jsPDF || !window.jspdf) {
      this.handlePrint();
      return;
    }
    
    const doc = new jsPDF({ unit: 'pt', format: 'a4' });
    
    // Title
    doc.setFontSize(18);
    doc.text('Quote Summary', 40, 40);
    
    // Custom text if provided
    if (this.customText) {
      doc.setFontSize(12);
      doc.text('Custom Text:', 40, 60);
      doc.setFontSize(10);
      // Wrap text to fit within page width
      const wrappedText = doc.splitTextToSize(this.customText, 400);
      doc.text(wrappedText, 40, 70);
    }
    
    // Cart items table
    const head = [['Name', 'Product Code', 'Qty', 'Unit Price', 'Line Total']];
    const body = this.cartItems.map(i => [
      i.Name || '',
      i.ProductCode || '',
      String(i.Quantity || 1),
      '$' + (i.UnitPrice || 0).toFixed(2),
      '$' + (Number(i.UnitPrice || 0) * Number(i.Quantity || 0)).toFixed(2)
    ]);
    
    // autoTable attached globally by plugin
    // eslint-disable-next-line no-undef
    window.jspdfAutoTable ? window.jspdfAutoTable(doc, { head, body, startY: 120 }) : doc.autoTable({ head, body, startY: 120 });
    
    // Totals
    const subtotal = this.subtotal;
    const tax = this.taxAmount;
    const shipping = this.shippingAmount;
    const grandTotal = this.grandTotal;
    
    doc.setFontSize(12);
    doc.text(`Subtotal: $${subtotal.toFixed(2)}`, 40, doc.lastAutoTable.finalY + 20);
    doc.text(`Tax (10%): $${tax.toFixed(2)}`, 40, doc.lastAutoTable.finalY + 35);
    doc.text(`Shipping: $${shipping.toFixed(2)}`, 40, doc.lastAutoTable.finalY + 50);
    doc.setFontSize(14);
    doc.text(`Grand Total: $${grandTotal.toFixed(2)}`, 40, doc.lastAutoTable.finalY + 65);
    
    doc.save('Quote.pdf');
  } catch (e) {
    // If PDF fails (e.g., CSP), fallback to browser print
    this.handlePrint();
  }
}


// Handle input change for custom text
handleCustomTextChange(event) {
  this.customText = event.target.value;
}

  // Computed totals (Subtotal)
  get subtotal() {
    return this.cartItems.reduce((sum, i) => {
      const price = Number(i.UnitPrice ?? 0);
      const qty = Number(i.Quantity ?? 0);
      return sum + price * qty;
    }, 0);
  }

  // Precompute line totals for display
  get cartItemsWithTotals() {
    return this.cartItems.map(item => ({
      ...item,
      lineTotal: Number(item.UnitPrice ?? 0) * Number(item.Quantity ?? 0)
    }));
  }

  // Tax and shipping (placeholders)
  get taxAmount() {
    return this.subtotal * 0.1; // 10%
  }

  get shippingAmount() {
    return 5.00; // Fixed shipping
  }

  get grandTotal() {
    return this.subtotal + this.taxAmount + this.shippingAmount;
  }
  
  fetchQuoteNumber() {
    getQuoteNumber({ quoteId: this.quoteId })
        .then(result => {
            this.quoteNumber = result;
        })
        .catch(error => {
            console.error('Error fetching quote number:', error);
        });
  }
}
