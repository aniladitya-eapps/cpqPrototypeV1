import { LightningElement } from 'lwc';

export default class ProductPage extends LightningElement {
    handleAddToCart(event) {
        const product = event.detail;
        this.template.querySelector('c-product-cart').addItem(product);
    }
}
