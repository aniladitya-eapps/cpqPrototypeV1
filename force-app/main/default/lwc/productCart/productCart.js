import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import jsPDF from '@salesforce/resourceUrl/jsPDF';
import jsPDFAutoTable from '@salesforce/resourceUrl/jsPDF_AutoTable';


export default class ProductCart extends LightningElement {
@track cartItems = [];
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
}
