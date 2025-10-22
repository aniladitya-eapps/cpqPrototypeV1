import { LightningElement, api } from 'lwc';
import createQuoteFromOpportunity from '@salesforce/apex/CreateQuoteFromOpportunity.createQuoteFromOpportunity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateQuoteQuickAction extends LightningElement {
    @api recordId;

    handleCreateQuote() {
        createQuoteFromOpportunity({ opportunityId: this.recordId })
            .then(result => {
                // Show success message
                const event = new ShowToastEvent({
                    title: 'Success',
                    message: 'Quote created successfully!',
                    variant: 'success'
                });
                this.dispatchEvent(event);
                
                // Close the quick action
                // Note: In a real scenario, this would close the quick action panel
                // For now, we'll just show an alert
                alert('Quote created successfully! ID: ' + result);
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
