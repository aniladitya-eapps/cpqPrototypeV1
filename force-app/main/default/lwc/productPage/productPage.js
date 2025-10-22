import { LightningElement, api } from 'lwc';

export default class ProductPage extends LightningElement {
    @api quoteId;
    
    handleAddToCart(event) {
        const product = event.detail;
        this.template.querySelector('c-product-cart').addItem(product);
    }
}
