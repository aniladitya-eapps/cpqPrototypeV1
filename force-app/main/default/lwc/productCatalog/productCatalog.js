import { LightningElement, track } from 'lwc';
import searchBundledProducts from '@salesforce/apex/ProductSearchController.searchBundledProducts';

export default class ProductCatalog extends LightningElement {
    @track products = [];
    @track error;
    @track isLoading = false;
    
    // Columns for the product table
    columns = [
        { label: 'Product Name', fieldName: 'Name', type: 'text', sortable: true },
        { label: 'Product Code', fieldName: 'ProductCode', type: 'text', sortable: true },
        { label: 'Description', fieldName: 'Description', type: 'text', sortable: true },
        { label: 'Family', fieldName: 'Family', type: 'text', sortable: true },
        { label: 'Is Active', fieldName: 'IsActive', type: 'boolean', sortable: true }
    ];
    
    connectedCallback() {
        this.loadBundledProducts();
    }
    
    loadBundledProducts() {
        this.isLoading = true;
        searchBundledProducts()
            .then(result => {
                this.products = result || [];
                this.error = undefined;
            })
            .catch(error => {
                this.error = error?.body?.message || error?.message;
                this.products = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleSort(event) {
        const fieldName = event.detail.fieldName;
        const sortDirection = event.detail.sortDirection;
        
        // Sort the products array
        this.products.sort((a, b) => {
            const aValue = a[fieldName];
            const bValue = b[fieldName];
            
            let result = 0;
            if (typeof aValue === 'string' && typeof bValue === 'string') {
                result = aValue.localeCompare(bValue);
            } else {
                result = aValue > bValue ? 1 : aValue < bValue ? -1 : 0;
            }
            
            return sortDirection === 'asc' ? result : -result;
        });
    }
}
