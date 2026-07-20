# [Shopify] Fix Sync Prices using stale WorkDate from SingleInstance cache

## Summary

Codeunit `Shpfy Product Price Calc.` (30182) is `SingleInstance` and caches a temporary Sales Header whose `Document Date`/`Order Date` is captured from `WorkDate()` in `CreateTempSalesHeader()`. The `SetShop()` guard only rebuilt the cached header when the shop code or `SystemModifiedAt` changed, so changing the Work Date mid-session had no effect on price calculation until the Shop record was modified (e.g. toggling an unrelated setting) or the session was restarted.

As a result, running **Sync Prices** after changing the Work Date could apply the discount valid for the *previous* Work Date.

## Fix

- Add a `WorkDate()` check to the `SetShop()` guard so the cached temp Sales Header is rebuilt whenever the Work Date changes.
- `SetShopAndCatalog()` already recreates the header unconditionally on every call, so it is unaffected and left as-is.

## Test plan

- Added regression test `UnitTestCalcPriceUsesCurrentWorkDate` (with helper `CreateDatedAllCustDiscPriceList`) that sets up two date-bounded "All Customers" discount price list lines (50% up to the boundary date, 20% after), calculates the price at a Work Date after the boundary, then moves the Work Date before the boundary and recalculates **without** modifying the Shop record. It asserts the correct (50%) discount is applied for the new Work Date; before the fix the stale cache would keep applying the 20% discount.
- Shopify App and Test projects build with 0 errors.

Fixes [AB#642194](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/642194)



