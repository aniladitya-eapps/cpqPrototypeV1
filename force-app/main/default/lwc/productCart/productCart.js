import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex
import getQuoteNumber from '@salesforce/apex/QuoteService.getQuoteNumber';
import getQuoteFields from '@salesforce/apex/QuoteService.getQuoteFields';
import getOpportunityAddresses from '@salesforce/apex/QuoteService.getOpportunityAddresses';
import createCacheJob from '@salesforce/apex/QuotePrintCache.createCacheJob';

export default class ProductCart extends LightningElement {
  /** Inputs / context */
  @api quoteId; // optional: if provided, we'll fetch quote number
  @track cartItems = [];
  @track customText = '';
  @track discount = '';
  @track quoteNumber;
  @track quoteStatus;
  @track billTo = {};
  @track shipTo = {};
  @track opportunityId; // optionally passed in via parent/url

  /** Simple title for the delete icon */
  get itemDeleteTitle() {
    return 'Remove item';
  }

  connectedCallback() {
    if (this.quoteId) {
      this.fetchQuoteNumber();
      this.fetchQuoteFields();
    }
  }

  /** Public API for parent/sibling to add items */
  @api addItem(product) {
    if (!this.opportunityId && product?.OpportunityId) {
      this.opportunityId = product.OpportunityId;
      this.fetchAddresses();
    }

    const qty  = Number(product?.Quantity ?? product?.Quantity__c ?? 1) || 1;
    const unit = Number(product?.UnitPrice ?? 0);
    const id   = product?.Id || product?.ProductCode || `${Date.now()}-${Math.random()}`;

    const existing = this.cartItems.find(p => p.ProductCode === product.ProductCode);
    if (existing) {
      existing.Quantity = Number(existing.Quantity || 0) + qty;
      this.cartItems = [...this.cartItems];
    } else {
      const newLine = {
        id, // used by <li key> and delete button
        ...product,
        Quantity: qty,
        UnitPrice: unit,
        DiscountType: product?.DiscountType === 'Amount' ? 'Amount' : 'Percent',
        DiscountValue: Number(product?.DiscountValue ?? 0)
      };
      this.cartItems = [...this.cartItems, newLine];
    }

    if (!this.opportunityId) this.fetchAddresses(); // no-op until opportunityId exists
  }

  handleRemove(event) {
    const id = event.target.dataset.id;
    this.cartItems = this.cartItems.filter(p => p.id !== id);
  }

  handleCustomTextChange(event) {
    this.customText = event.detail.value;
  }

  handleDiscountChange(event) {
    let value = event.detail.value;
    
    // Validate that it's a positive number or empty
    if (value !== '' && (isNaN(value) || parseFloat(value) < 0)) {
      // Reset to empty if invalid input
      this.discount = '';
      return;
    }
    
    // Limit to maximum 100% 
    if (value !== '' && parseFloat(value) > 100) {
      this.discount = '100';
      return;
    }
    
    this.discount = value;
  }

  /** Totals */
  get subtotal() {
    return this.cartItems.reduce((sum, i) => {
      const price = Number(i.UnitPrice ?? 0);
      const qty   = Number(i.Quantity  ?? 0);
      return sum + price * qty;
    }, 0);
  }

  get cartItemsWithTotals() {
    return (this.cartItems || []).map(item => {
      const qty   = Number(item.Quantity  ?? 0);
      const price = Number(item.UnitPrice ?? 0);
      const gross = price * qty;

      const dt = (item.DiscountType || 'Percent');
      const dv = Number(item.DiscountValue ?? 0);

      let discountAmount = 0;
      if (dt === 'Amount') {
        discountAmount = Math.min(Math.max(dv, 0), gross);
      } else {
        const pct = Math.min(Math.max(dv, 0), 100);
        discountAmount = gross * (pct / 100);
      }

      const net = Math.max(gross - discountAmount, 0);

      return {
        ...item,
        lineTotal: gross,
        discountAmount,
        netPrice: net
      };
    });
  }

  get taxAmount()      { return this.subtotal * 0.1; }  // 10%
  get shippingAmount() { return 5.0; }                  // fixed
  get discountTotal()  { return this.cartItemsWithTotals.reduce((s,i)=>s + Number(i.discountAmount ?? 0), 0); }
  get netTotal()       { return this.cartItemsWithTotals.reduce((s,i)=>s + Number(i.netPrice ?? 0), 0); }
  get grandTotal() {
    let total = this.netTotal + this.taxAmount + this.shippingAmount;
    
    // Apply discount if provided
    if (this.discount !== '' && !isNaN(this.discount) && parseFloat(this.discount) > 0) {
      const discountPercent = parseFloat(this.discount);
      total = total * (1 - discountPercent / 100);
    }
    
    return total;
  }

  /** Apex calls */
  fetchQuoteNumber() {
    if (!this.quoteId) return;
    getQuoteNumber({ quoteId: this.quoteId })
      .then(n => { this.quoteNumber = n; })
      .catch(e => { /* eslint-disable-next-line no-console */ console.error('Quote number fetch failed', e); });
  }

  fetchAddresses() {
    if (!this.opportunityId) return;
    getOpportunityAddresses({ opportunityId: this.opportunityId })
      .then(addr => {
        this.billTo = {
          street: addr.billToStreet,
          city: addr.billToCity,
          state: addr.billToState,
          postalCode: addr.billToPostalCode,
          country: addr.billToCountry
        };
        this.shipTo = {
          street: addr.shipToStreet,
          city: addr.shipToCity,
          state: addr.shipToState,
          postalCode: addr.shipToPostalCode,
          country: addr.shipToCountry
        };
      })
      .catch(e => { /* eslint-disable-next-line no-console */ console.error('Address fetch failed', e); });
  }

  fetchQuoteFields() {
    if (!this.quoteId) return;
    getQuoteFields({ quoteId: this.quoteId })
      .then(fields => { 
        this.quoteNumber = fields.quoteNumber;
        this.quoteStatus = fields.quoteStatus;
      })
      .catch(e => { /* eslint-disable-next-line no-console */ console.error('Quote fields fetch failed', e); });
  }

  /** HTML escaping for safety when we build server HTML (also used client-side if needed) */
  _esc(str) {
    return (str ?? '').toString().replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  /**
   * PRINT: send payload to Platform Cache (Apex), then open VF renderAs="pdf"
   * No client-side document.write(), so no LWS violations.
   */
  handleGenerateQuotePdf() {
    if (!this.cartItems?.length) {
      this.dispatchEvent(new ShowToastEvent({
        title: 'Nothing to print',
        message: 'Your cart is empty.',
        variant: 'warning'
      }));
      return;
    }

    // Prepare payload the server expects
    const items = this.cartItemsWithTotals.map(i => ({
      ProductCode: i.ProductCode,
      Quantity: Number(i.Quantity || 0),
      UnitPrice: Number(i.UnitPrice || 0),
      DiscountType: i.DiscountType === 'Amount' ? 'Amount' : 'Percent',
      DiscountValue: Number(i.DiscountValue || 0),
      NetPrice: Number(i.netPrice || 0)
    }));

    const payload = {
      quoteId: this.quoteId || null,
      quoteNumber: this.quoteNumber || null,
      billTo: this.billTo || {},
      shipTo: this.shipTo || {},
      items,
      terms: this.customText || ''
    };

    // 1) Put payload in Session Cache → returns short-lived key
    createCacheJob({ payloadJson: JSON.stringify(payload) })
      .then(key => {
        // 2) Open the VF page that reads payload from cache and renders as PDF
        const url = '/apex/QuotePrintablePDF?k=' + key;
        window.open(url, '_blank'); // user gesture → popup allowed
      })
      .catch(err => {
        // eslint-disable-next-line no-console
        console.error('createCacheJob failed', err);
        this.dispatchEvent(new ShowToastEvent({
          title: 'Print failed',
          message: err?.body?.message || err?.message || 'Unknown error',
          variant: 'error'
        }));
      });
  }

  /**
   * Submit for Approval placeholder.
   * This button exists per request; implement server call here if/when approval logic is defined.
   * For now, just notify the user.
   */
  handleSubmitForApproval() {
    if (!this.quoteId) {
      this.dispatchEvent(new ShowToastEvent({
        title: 'No Quote to Submit',
        message: 'A Quote ID is required to submit for approval.',
        variant: 'warning'
      }));
      return;
    }
    this.dispatchEvent(new ShowToastEvent({
      title: 'Submitted',
      message: 'The quote has been submitted for approval (placeholder).',
      variant: 'success'
    }));
  }
}
