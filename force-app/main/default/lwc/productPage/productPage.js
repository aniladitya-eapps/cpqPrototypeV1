import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import QUOTE_NUMBER from '@salesforce/schema/cg_Quote__c.cg_Quote_number__c';
import QUOTE_STATUS from '@salesforce/schema/cg_Quote__c.cg_Quote_Status__c';

export default class ProductPage extends NavigationMixin(LightningElement) {
  @api quoteId;
  @api quoteNumber;
  @api opportunityId;
  @api quoteStatus;

  // 1) Read params from URL state
  @wire(CurrentPageReference)
  parseState(ref) {
    if (!ref || !ref.state) return;
    this.quoteId       = this.quoteId       || ref.state.c__quoteId;
    this.quoteNumber   = this.quoteNumber   || ref.state.c__quoteNumber; // may be blank initially
    this.opportunityId = this.opportunityId || ref.state.c__opportunityId;
    this.quoteStatus = this.quoteStatus || ref.state.c__quoteStatus;
  }

  // 2) If we have an Id but no number, fetch it
  @wire(getRecord, { recordId: '$quoteId', fields: [QUOTE_NUMBER,QUOTE_STATUS] })
  wiredQuote({ data }) {
    if (!data) return;
    const num = getFieldValue(data, QUOTE_NUMBER);
    const status = getFieldValue(data, QUOTE_STATUS);
    if (num && !this.quoteNumber) {
      this.quoteNumber = num;
    }
    if (status && !this.quoteStatus) {
      this.quoteStatus = status;
    }
  }

  handleAddToCart(event) {
    const product = event.detail;
    const cart = this.template.querySelector('c-product-cart');
    if (cart) cart.addItem(product);
  }

  handleBackToOpportunity() {
    if (!this.opportunityId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: this.opportunityId,
        objectApiName: 'Opportunity',
        actionName: 'view'
      }
    });
  }

  handleProceedToAdvancedPricing() {
    // Navigate to the LWC tab or app page for advanced pricing if exists,
    // otherwise route to the pricing engine LWC via a Lightning page reference.
    // Placeholder navigation to a named page; adjust target as needed.
    this[NavigationMixin.Navigate]({
      type: 'standard__navItemPage',
      attributes: {
        apiName: 'Advanced_Pricing'
      },
      state: {
        c__quoteId: this.quoteId || null,
        c__opportunityId: this.opportunityId || null,
        c__quoteNumber: this.quoteNumber || null,
        c__quoteStatus: this.quoteStatus || null
      }
    });
  }
}
