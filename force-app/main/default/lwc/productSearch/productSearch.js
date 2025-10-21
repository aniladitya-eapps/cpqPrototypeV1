import { LightningElement, track } from 'lwc';
import searchProducts from '@salesforce/apex/ProductSearchController.searchProducts';

export default class ProductSearch extends LightningElement {
  @track searchKey = '';
  @track products = [];
  @track rows = [];           // full data set (used for sort/paging)
  @track pagedRows = [];      // current page slice
  @track error;
  @track isLoading = false;

  // inline edit drafts (datatable also keeps its own; we’ll read from DOM when needed)
  draftValues = [];

  // Pagination/sort
  pageSize = 10;
  @track page = 1;
  @track totalPages = 1;
  sortedBy = 'Name';
  sortedDirection = 'asc';
  delayTimeout;

  // Columns (Quantity__c is the editable field shown in the UI)
  columns = [
    { label: 'ProductCode', fieldName: 'ProductCode', type: 'text', sortable: true },
    { label: 'Unit Cost', fieldName: 'UnitPrice', type: 'currency', sortable: true },
    { label: 'Quantity', fieldName: 'Quantity__c', type: 'number', editable: true, sortable: true },
    { label: 'Total', fieldName: 'Total', type: 'currency', sortable: true },
    {
      type: 'button',
      fixedWidth: 140,
      typeAttributes: { label: 'Add', name: 'addtocart', variant: 'brand' }
    }
  ];

  handleSearchKeyChange(e) {
    this.searchKey = e.target.value;
    this.debouncedSearch();
  }

  debouncedSearch() {
    clearTimeout(this.delayTimeout);
    this.delayTimeout = setTimeout(() => this.searchProducts(), 400);
  }

  searchProducts() {
    if (!this.searchKey || !this.searchKey.trim()) {
      this.products = [];
      this.rows = [];
      this.computePagination();
      return;
    }
    this.isLoading = true;
    searchProducts({ searchKey: this.searchKey })
      .then(result => {
        this.products = result || [];
        // Map server data → table rows; seed Quantity__c to 1 if missing
        this.rows = (this.products || []).map(r => {
          const quantity = r.Quantity ?? 1;
          const total = r.UnitPrice ? r.UnitPrice * quantity : 0;
          return {
            Id: r.Id,
            Name: r.Name,
            ProductCode: r.ProductCode,
            UnitPrice: r.UnitPrice,
            Quantity__c: quantity,
            Total: total
          };
        });
        // Debug log - show that quantity is in-memory with default value
        // console.log('Product rows loaded with quantity defaults:', this.rows);
        this.error = undefined;
        this.applySort(this.sortedBy, this.sortedDirection);
        this.page = 1;
        this.computePagination();
      })
      .catch(err => {
        this.error = err?.body?.message || err?.message;
        this.products = [];
        this.rows = [];
        this.computePagination();
      })
      .finally(() => { this.isLoading = false; });
  }

  /**
   * Ensure the row we use for the Add action includes any unsaved inline edits.
   * We read the live draft values from the datatable DOM (so the user doesn't have to click Save).
   */
  getEffectiveRowForAction(rawRow) {
    const dt = this.template.querySelector('lightning-datatable');
    const liveDrafts = dt?.draftValues || [];
    const localDrafts = this.draftValues || [];
    const drafts = liveDrafts.length ? liveDrafts : localDrafts;

    const patch = drafts.find(d => d.Id === rawRow.Id);
    return patch ? { ...rawRow, ...patch } : rawRow;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    if (actionName !== 'addtocart') return;

    // Merge unsaved draft changes into the clicked row
    const rowWithDrafts = this.getEffectiveRowForAction(event.detail.row);

    // Normalize quantity: prefer Quantity__c (editable col), fallback to Quantity, default 1
    const quantity = Number(rowWithDrafts.Quantity__c ?? rowWithDrafts.Quantity ?? 1) || 1;

    const payload = {
      Id: rowWithDrafts.Id,
      Name: rowWithDrafts.Name,
      ProductCode: rowWithDrafts.ProductCode,
      UnitPrice: Number(rowWithDrafts.UnitPrice ?? 0),
      Quantity: quantity,
      Total: Number(rowWithDrafts.Total ?? 0)
    };

    // Debug (unproxied)
    // eslint-disable-next-line no-console
    console.log('Sending to cart:', JSON.parse(JSON.stringify(payload)));

    // Bubble up to productPage → cart.addItem(...)
    this.dispatchEvent(new CustomEvent('addtocart', {
      detail: payload, bubbles: true, composed: true
    }));
  }

  handleSort(event) {
    this.sortedBy = event.detail.fieldName;
    this.sortedDirection = event.detail.sortDirection;
    this.applySort(this.sortedBy, this.sortedDirection);
  }

  // Inline edit save (when user explicitly clicks Save)
  handleSave(event) {
    const updates = event.detail.draftValues || [];
    const clone = this.rows.map(r => ({ ...r }));
    updates.forEach(d => {
      const i = clone.findIndex(x => x.Id === d.Id);
      if (i > -1) {
        // Always recalculate total when row is updated
        const updatedRow = { ...clone[i], ...d };
        // Recalculate total using available values
        if (updatedRow.UnitPrice !== undefined && updatedRow.Quantity__c !== undefined) {
          updatedRow.Total = updatedRow.UnitPrice * updatedRow.Quantity__c;
        } else if (clone[i].UnitPrice !== undefined && clone[i].Quantity__c !== undefined) {
          // Fallback to original values if new values aren't available
          updatedRow.Total = clone[i].UnitPrice * clone[i].Quantity__c;
        }
        clone[i] = updatedRow;
      }
    });
    this.rows = clone;
    this.draftValues = [];
    this.computePagination();
  }

  applySort(field, direction) {
    const isAsc = direction === 'asc';
    const data = [...this.rows];
    data.sort((a, b) => {
      const av = a[field], bv = b[field];
      const numeric = new Set(['UnitPrice', 'Quantity__c', 'Total']);
      if (numeric.has(field)) {
        const na = Number(av ?? 0), nb = Number(bv ?? 0);
        return (na === nb ? 0 : (na > nb ? 1 : -1)) * (isAsc ? 1 : -1);
      }
      const sa = (av ?? '').toString().toLowerCase();
      const sb = (bv ?? '').toString().toLowerCase();
      return (sa === sb ? 0 : (sa > sb ? 1 : -1)) * (isAsc ? 1 : -1);
    });
    this.rows = data;
    this.computePagination();
  }

  // Pagination helpers
  computePagination() {
    const total = this.rows.length;
    this.totalPages = Math.max(1, Math.ceil(total / this.pageSize));
    if (this.page > this.totalPages) this.page = this.totalPages;
    const start = (this.page - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedRows = this.rows.slice(start, end);
  }

  get isFirstPage() { return this.page <= 1; }
  get isLastPage() { return this.page >= this.totalPages; }

  goFirst() { if (!this.isFirstPage) { this.page = 1; this.computePagination(); } }
  goPrev()  { if (!this.isFirstPage) { this.page -= 1; this.computePagination(); } }
  goNext()  { if (!this.isLastPage)  { this.page += 1; this.computePagination(); } }
  goLast()  { if (!this.isLastPage)  { this.page = this.totalPages; this.computePagination(); } }
}
