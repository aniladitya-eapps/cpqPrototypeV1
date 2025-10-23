# CPQ Prototype V1

A Salesforce DX project showcasing a lightweight CPQ-style flow with Lightning Web Components (LWC), Apex services, and a Visualforce PDF renderer. Users can search/select products, build a cart, generate a printable Quote PDF using Platform Cache, and optionally create Quotes from Opportunities.

- Project name: Prototype1
- API Version: 64.0
- Package directory: force-app
- Tooling: ESLint, Prettier, sfdx-lwc-jest, Husky

## Contents

- Overview
- App Architecture
- Key Features
- Data Model
- Components and Apex
- PDF Generation Flow
- Local Development
- Testing and Linting
- Deployment and Org Tasks
- Repository Structure

## Overview

This prototype implements:
- Product discovery and cart building in LWC.
- Quote context fetching (Quote number/status, Bill-To/Ship-To from Opportunity).
- Client-side discounting, line totals, and order totals.
- PDF generation via a cached payload and a Visualforce page.
- Utility Apex to create Quotes from Opportunities and a placeholder approval engine.

## App Architecture

- UI: Lightning Web Components in `force-app/main/default/lwc`.
- Server: Apex classes under `force-app/main/default/classes`.
- Persistence/Metadata: Custom objects `cg_Quote__c` and `cg_Quote_Lines__c`.
- Rendering: Visualforce page `QuotePrintablePdf` with controller `QuotePrintablePdfCtrl`.
- Temporary payload storage: Apex `QuotePrintCache` (Platform Cache/Session cache approach).

High-level flow:
1. Search products → add to cart.
2. Cart computes totals.
3. Generate PDF → LWC assembles payload → Apex caches → VF renders PDF from cached payload.

## Key Features

- Product search and catalog viewing.
- Cart with per-line discount (amount/percent), totals, and address capture from Opportunity.
- Quote number/status retrieval when `quoteId` is provided.
- PDF generation using Platform Cache handshake (short-lived key).
- Quote creation from Opportunity.
- Approval submission placeholder.

## Data Model

Custom objects:
- cg_Quote__c
  - Fields: cg_Account__c (Lookup), cg_Opportunity__c (Lookup), cg_Quote_number__c (Text)
- cg_Quote_Lines__c
  - Fields: cg_Product_Code__c (Text), cg_Quantity__c (Number), cg_Unit_Price__c (Currency),
            cg_Discount_percent__c (Percent), cg_Discount_Amount__c (Currency), cg_Total__c (Currency)

These are used by server processes and for potential persistence of quotes and lines.

## Components and Apex

LWC
- approvals: Placeholder UI for approvals.
- createQuoteQuickAction / createQuoteQuickActionHeadless: Quick actions to create quotes from Opportunity.
- opportunityQuoteButton: Button to launch quote creation from Opportunity.
- pricingEngine: UI for pricing/discount logic demonstration.
- productCatalog: Display available products.
- productSearch: Search products.
- productPage: Container page for catalog/cart experience.
- productCart: Main cart experience, builds the print payload and triggers PDF generation.

Apex Classes
- CreateQuoteFromOpportunity.cls: Logic to create a new quote from an Opportunity.
- ProductPageWithQuoteController.cls: Controller support for the product page with Quote context.
- ProductSearchController.cls: Product search endpoints.
- QuoteService.cls: Quote-related helpers
  - getQuoteNumber(quoteId)
  - getQuoteFields(quoteId) → quoteNumber, quoteStatus
  - getOpportunityAddresses(opportunityId) → billTo/shipTo address blobs
- QuotePrintCache.cls: Accepts serialized payload and writes/reads from a cache boundary
  - createCacheJob(payloadJson) → returns short-lived key
- QuotePrintablePdfCtrl.cls: Controller for PDF Visualforce page. Reads cache by key, prepares data for rendering.
- SpreadsheetApprovalEngine.cls / SpreadsheetRulesFromFiles.cls: Placeholder/sample rules/approvals engine.

Visualforce
- QuotePrintablePdf.page: Renders the printable PDF using the cached payload via `QuotePrintablePdfCtrl`.

Other
- Triggers: linkCOACustomerToLMALicense.trigger (sample linkage logic).
- Permissionsets, tabs, layouts, flexipages, flows: Supplemental metadata to support UI.

## PDF Generation Flow

From productCart LWC (handleGenerateQuotePdf):
1. Validate cart not empty.
2. Build items from `cartItemsWithTotals`:
   - ProductCode
   - Quantity (number)
   - UnitPrice (number)
   - DiscountType ('Amount' | 'Percent')
   - DiscountValue (number)
   - NetPrice (number)
3. Assemble payload:
   - quoteId (nullable)
   - quoteNumber (nullable)
   - billTo { street, city, state, postalCode, country } from Opportunity (if available)
   - shipTo { street, city, state, postalCode, country } from Opportunity (if available)
   - items [as above]
   - terms (string from user input)
4. Call Apex cache: QuotePrintCache.createCacheJob({ payloadJson: JSON.stringify(payload) })
5. Open Visualforce: /apex/QuotePrintablePDF?k={key}
6. VF controller loads cached payload and renders PDF.

## Local Development

Prerequisites
- Node.js LTS
- Salesforce CLI (sf)
- VS Code with Salesforce extensions

Install dependencies
- npm install

Run linters/formatters
- npm run lint
- npm run prettier
- npm run prettier:verify

Unit tests (LWC)
- npm test
- npm run test:unit:watch
- npm run test:unit:coverage

## Deployment and Org Tasks

Use MCP tools where available first. Otherwise, examples below show sf CLI equivalents.

Authorize an org
- sf org login web --alias my-org

Deploy metadata
- sf project deploy start --source-dir force-app --target-org my-org

Run Apex tests (examples)
- sf apex test run --test-level RunLocalTests --target-org my-org --wait 20 --result-format human

Open the org
- sf org open --target-org my-org

Data retrieval (SOQL examples)
- sf data query --query "SELECT Id, Name FROM Account LIMIT 5" --target-org my-org

## Testing and Linting

- ESLint with @salesforce/eslint-config-lwc for LWC and plugins for Aura/Lightning.
- Prettier with apex and xml plugins.
- Jest via @salesforce/sfdx-lwc-jest.
- Husky + lint-staged to enforce formatting and tests on commit.

Common scripts (package.json)
- lint: eslint **/{aura,lwc}/**/*.js
- prettier / prettier:verify
- test:unit, test:unit:watch, test:unit:debug, test:unit:coverage

## Repository Structure

- force-app/main/default
  - classes/ (Apex)
  - lwc/ (Lightning Web Components)
  - aura/
  - pages/ (Visualforce)
  - objects/ (Custom objects and fields)
  - flows/, layouts/, tabs/, permissionsets/, staticresources/
  - triggers/
- scripts/ (apex, soql)
- manifest/ (package.xml)
- eslint.config.js, jest.config.js, .prettierrc, .prettierignore

## References

- LWC productCart payload assembly: force-app/main/default/lwc/productCart/productCart.js
- Apex cache: force-app/main/default/classes/QuotePrintCache.cls
- PDF controller: force-app/main/default/classes/QuotePrintablePdfCtrl.cls
- PDF page: force-app/main/default/pages/QuotePrintablePdf.page
- Quote services: force-app/main/default/classes/QuoteService.cls
