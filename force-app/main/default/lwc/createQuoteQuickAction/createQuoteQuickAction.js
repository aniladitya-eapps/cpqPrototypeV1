// createQuoteQuickAction.js (your existing component stays ScreenAction)
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import createQuoteFromOpportunityWithNumber
  from '@salesforce/apex/CreateQuoteFromOpportunity.createQuoteFromOpportunityWithNumber';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateQuoteQuickAction extends NavigationMixin(LightningElement) {
  @api recordId;

  async handleCreateQuote() {
    try {
      const result = await createQuoteFromOpportunityWithNumber({ opportunityId: this.recordId });

      this.dispatchEvent(new ShowToastEvent({
        title: 'Success',
        message: 'Quote created successfully!',
        variant: 'success'
      }));

      // 🔑 Close the action modal first to avoid the in-between screen
      this.dispatchEvent(new CloseActionScreenEvent());

      // Let the modal finish closing, then navigate
      setTimeout(() => {
        this[NavigationMixin.Navigate]({
          type: 'standard__navItemPage',
          attributes: { apiName: 'Quote_Console' },
          state: {
            c__quoteId: result.quoteId,
            c__quoteNumber: result.quoteNumber,
            c__opportunityId: this.recordId
          }
        });
      }, 0);
    } catch (error) {
      const msg =
        (error?.body && (error.body.message || error.body.pageErrors?.[0]?.message)) ||
        error?.message || 'An unexpected error occurred';
      this.dispatchEvent(new ShowToastEvent({
        title: 'Error',
        message: 'Failed to create quote: ' + msg,
        variant: 'error'
      }));
      // eslint-disable-next-line no-console
      console.error(error);
    }
  }
}
