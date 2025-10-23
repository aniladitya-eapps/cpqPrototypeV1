import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createQuoteFromOpportunityWithNumber
  from '@salesforce/apex/CreateQuoteFromOpportunity.createQuoteFromOpportunityWithNumber';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateQuoteQuickActionHeadless extends NavigationMixin(LightningElement) {
  @api recordId;

  // Entry point for headless actions
  @api async invoke() {
    try {
      const result = await createQuoteFromOpportunityWithNumber({ opportunityId: this.recordId });

      this.dispatchEvent(new ShowToastEvent({
        title: 'Success',
        message: 'Quote created successfully!',
        variant: 'success'
      }));

      this[NavigationMixin.Navigate]({
        type: 'standard__navItemPage',          // or use 'standard__flexipage' (see Step 7)
        attributes: {
          apiName: 'Quote_Console'              // Lightning Page Tab API name
        },
        state: {
          c__quoteId: result.quoteId,
          c__quoteNumber: result.quoteNumber,
          c__opportunityId: this.recordId,
          c__quoteStatus : result.quoteStatus
        }
      });
    } catch (e) {
      const msg = e?.body?.message || e?.message || 'Unexpected error';
      this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
  }
}
