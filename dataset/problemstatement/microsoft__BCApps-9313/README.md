# [Shopify] Fix Product Sync deleting mapped variants on stale Updated At timestamp

Fixes [AB#641922](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/641922)

## Summary

Product Sync (Shopify → BC) could incorrectly **delete** a mapped variant when a bulk price export had stamped the local "Updated At" with CurrentDateTime() before Shopify's asynchronous bulk operation completed.

The root cause is a conflation of two meanings in `RetrieveShopifyVariant`:

- The timestamp guard in `UpdateShopifyVariantFields` returns `false` to mean *"skip — the local record is already up to date"*.
- `RetrieveShopifyVariant` passed that `false` straight through, and its caller `ShpfyProductImport.SetProduct` interpreted `false` as *"variant no longer exists"* and called `ShopifyVariant.Delete()`.

During the window between a bulk price export stamping the local timestamp (`CurrentDateTime()`) and Shopify actually processing the queued mutation, a Shopify→BC sync sees `Shopify updatedAt < local Updated At`, the guard trips, and the variant is deleted. On the next sync it is re-created with a null `Item SystemId`, so for Default Title products the `Item No.` FlowField becomes blank.

## Fix

- `RetrieveShopifyVariant` now returns `true` whenever the `productVariant` node is present in the response (the variant still exists on Shopify), and `false` only when the node is genuinely absent (variant deleted on Shopify). The timestamp guard still skips the field update, but that skip no longer signals a deletion.
- `UpdateShopifyVariantFields` no longer returns a `Boolean` — its only caller ignored the value after the change.

## Test plan

Added `Shpfy Variant API Test` (codeunit 139613) with `[HttpClientHandler]`-based mocking:

- `UnitTestRetrieveShopifyVariantKeepsVariantWhenLocalUpdatedAtIsAhead` — local `Updated At` set ahead of Shopify's `updatedAt`; asserts the variant is reported as existing (not deleted) and the local timestamp is preserved (guard skipped the update).
- `UnitTestRetrieveShopifyVariantReportsMissingWhenDeletedOnShopify` — Shopify returns a null `productVariant` node; asserts the variant is reported as missing so the caller may delete it.



