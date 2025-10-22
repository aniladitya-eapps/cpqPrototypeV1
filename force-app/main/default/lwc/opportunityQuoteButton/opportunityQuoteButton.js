import { LightningElement, api } from 'lwc';
import createQuoteFromOpportunity from '@salesforce/apex/CreateQuoteFromOpportunity.createQuoteFromOpportunity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class OpportunityQuoteButton extends NavigationMixin(LightningElement) {
    @api recordId;

    handleCreateAndNavigate() {
        createQuoteFromOpportunity({ opportunityId: this.recordId })
            .then(result => {
                // Show success message
                const event = new ShowToastEvent({
                    title: 'Success',
                    message: 'Quote created successfully!',
                    variant: 'success'
                });
                this.dispatchEvent(event);
                
                // Navigate to the quote detail page
                // This is more compatible with Lightning Experience
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.error('Error creating quote:', error);
                // Show an error toast or notification
                const event = new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to create quote: ' + error.body.message,
                    variant: 'error'
                });
                this.dispatchEvent(event);
            });
    }
}
