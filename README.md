# CPQ Prototype V1

This project contains a lightweight CPQ-style prototype with LWC components and Apex services to build quotes, cache a printable payload, and render a PDF.

## ProductCart → createCacheJob Payload

The `productCart` LWC builds a payload from the cart (selected products) and sends it to the Apex method `QuotePrintCache.createCacheJob`. The cached payload is then consumed by the Visualforce page `QuotePrintablePDF` to render a printable PDF.

Source:
- LWC: `force-app/main/default/lwc/productCart/productCart.js`
- Apex cache entry point: `@AuraEnabled QuotePrintCache.createCacheJob(payloadJson)`
- PDF renderer: `force-app/main/default/pages/QuotePrintablePdf.page` (controller: `QuotePrintablePdfCtrl.cls`)

### Trigger Point

Inside `productCart`, the action is initiated by `handleGenerateQuotePdf()`.

```
createCacheJob({ payloadJson: JSON.stringify(payload) })
  .then(key => {
    const url = '/apex/QuotePrintablePDF?k=' + key;
    window.open(url, '_blank');
  });
```

### Payload Shape

The payload is assembled from cart state and quote context, then JSON-stringified and passed as `payloadJson`:

```
{
  quoteId: string | null,
  quoteNumber: string | null,
  billTo: {
    street?: string,
    city?: string,
    state?: string,
    postalCode?: string,
    country?: string
  } | {},
  shipTo: {
    street?: string,
    city?: string,
    state?: string,
    postalCode?: string,
    country?: string
  } | {},
  items: Array<{
    ProductCode: string,
    Quantity: number,
    UnitPrice: number,
    DiscountType: 'Amount' | 'Percent',
    DiscountValue: number,
    NetPrice: number
  }>,
  terms: string
}
```

Notes:
- `quoteId` and `quoteNumber` are included if available; otherwise `null`.
- `billTo` and `shipTo` are populated from Opportunity addresses if `opportunityId` is known.
- `terms` comes from user-entered free text (`customText`).
- Each item includes a normalized `DiscountType` (`Amount` or `Percent`) and a numeric `DiscountValue`.
- `NetPrice` is precomputed client-side as gross - discount.

### How Each Field Is Derived

- quoteId: `@api quoteId` passed in from parent context.
- quoteNumber: Fetched via `QuoteService.getQuoteNumber` or `QuoteService.getQuoteFields`.
- billTo / shipTo: Fetched via `QuoteService.getOpportunityAddresses(opportunityId)` when an Opportunity Id is known.
- items: Built from `cartItemsWithTotals`, which itself normalizes quantity/price and calculates discounts:
  - Quantity: `Number(item.Quantity || 0)`
  - UnitPrice: `Number(item.UnitPrice || 0)`
  - DiscountType: `item.DiscountType === 'Amount' ? 'Amount' : 'Percent'`
  - DiscountValue: `Number(item.DiscountValue || 0)`
  - NetPrice: `Number(item.netPrice || 0)` (net of line-level discount)
- terms: `customText` input by the user in the cart.

### Upstream Data Flow Summary

1. User adds products to the cart via `@api addItem(product)`, which normalizes:
   - Quantity from `product.Quantity` or `product.Quantity__c` (default 1)
   - UnitPrice from `product.UnitPrice` (default 0)
   - Discount defaults to Percent when unspecified
2. If `OpportunityId` is detected on the first product, it is retained and addresses are fetched.
3. When "Generate PDF" is clicked:
   - `cartItemsWithTotals` computes `lineTotal`, `discountAmount`, and `netPrice` per line.
   - The `payload` object is constructed (see shape above).
   - `QuotePrintCache.createCacheJob(payloadJson)` caches the payload and returns a short-lived key.
   - The component opens `/apex/QuotePrintablePDF?k={key}` in a new tab. The page/controller read the cached payload and render the PDF.

### Validation and Edge Cases

- Empty cart: Shows a toast and aborts.
- Discount input: Only allows numeric, non-negative values, capped at 100% for cart-level discount (used in totals UI).
- Item-level discount: Each item enforces 0 ≤ Percent ≤ 100, and Amount capped to gross.

### Related Apex

- `QuoteService.getQuoteNumber(quoteId)`
- `QuoteService.getQuoteFields(quoteId)`
- `QuoteService.getOpportunityAddresses(opportunityId)`
- `QuotePrintCache.createCacheJob(payloadJson)`

### Where to Update If Payload Needs Changes

- Add/Remove fields in the client payload: `force-app/main/default/lwc/productCart/productCart.js` inside `handleGenerateQuotePdf()`.
- Update server cache handling: `force-app/main/default/classes/QuotePrintCache.cls`.
- Update the PDF controller mapping: `force-app/main/default/classes/QuotePrintablePdfCtrl.cls`.
- Adjust PDF layout: `force-app/main/default/pages/QuotePrintablePdf.page`.

### Example Payload

```
{
  "quoteId": "a1Q...001",
  "quoteNumber": "Q-000123",
  "billTo": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "postalCode": "94105",
    "country": "US"
  },
  "shipTo": {
    "street": "456 Market St",
    "city": "San Francisco",
    "state": "CA",
    "postalCode": "94107",
    "country": "US"
  },
  "items": [
    {
      "ProductCode": "CAR-SEDAN",
      "Quantity": 2,
      "UnitPrice": 25000,
      "DiscountType": "Percent",
      "DiscountValue": 10,
      "NetPrice": 45000
    }
  ],
  "terms": "Net 30. FOB shipping point."
}
```

## Development Notes

- Always use `sf` CLI, not `sfdx`.
- Prefer MCP tools where available.
- Ensure related metadata files are checked in for Apex classes and triggers.
