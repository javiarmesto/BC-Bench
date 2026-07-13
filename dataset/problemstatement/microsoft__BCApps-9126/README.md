# [Shopify] Base price-sync bulk threshold on changed price count

Fixes [AB#640288](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/640288)

## Problem
`Shpfy Product Export` chose between an asynchronous **bulk operation** and **synchronous** price updates based on the *total number of Shopify products mapped to items* for the shop. A shop with 100+ mapped products therefore spawned a bulk operation even when only a single price actually changed.

## Change
Decide based on the **actual number of changed variants** instead:
- `UpdateProductPrice` now always accumulates the per-variant mutation; `GraphQueryList.Count()` is the real change count.
- After the export loop, `OnRun` sends a bulk operation only when the change count reaches `GetBulkOperationThreshold()` (100); below that it sends individual synchronous mutations (with revert-on-failure).
- The synchronous send is no longer a `[TryFunction]`, so `ExecuteGraphQL`'s request-logging `INSERT` is permitted; it reports success/failure via a Boolean and writes back Shopify's authoritative `updatedAt`.

## Tests
- Added `UnitTestPriceUpdateBelowThresholdUsesIndividualSyncNotBulk`: a few changed prices are sent as individual synchronous mutations and no bulk operation is created.
- Updated the existing bulk price-update tests for the new `UpdateProductPrice` signature.


