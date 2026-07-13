# [Shopify] Surface skipped records and sent JSONL for bulk price sync

Fixes [AB#641615](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/641615)

## Problem

When a bulk price sync (`productVariantsBulkUpdate`) completes but Shopify returns a per-variant error — for example a product that was deleted on the Shopify side (`"Product does not exist"`) — the connector's `RevertFailedRequests` logic reverted the affected variant back to its old price **silently**. On the next Sync Prices run the same item is picked up again, producing an invisible infinite retry loop with no skipped-record entry, no log, and nothing in the UI to tell the user what failed.

## Changes

1. **Skipped record feedback on revert.** `Shpfy Bulk UpdateProductPrice.RevertFailedRequests` now parses the per-line `userErrors`/`errors` from the result JSONL and maps each result line back to its request-data entry via `__lineNumber` (base-agnostic: derived from the minimum observed line number, so it works whether Shopify numbers from 0 or 1). Every reverted variant gets a **Shopify Skipped Record** with the Shopify error message. The entry references the linked BC **Item Variant** (preferred) or **Item** — resolved from the Shopify variant's SystemIds — matching the existing `LogSkippedRecord` convention in `Shpfy Product Export`, so the user sees exactly which product failed and why. Logging respects the shop's Logging Mode (suppressed only when Disabled).

2. **Downloadable sent JSONL.** Added a `Sent JSONL` blob field (13) to table `Shpfy Bulk Operation` with `Set`/`GetSentJsonl` helpers. `Shpfy Bulk Operation Mgt.SendBulkMutation` now stores the JSONL request that was sent to Shopify — **only when Logging Mode = All**, to avoid growing the table with a payload blob on every price sync — and a new **Download Sent Data** action on the `Shopify Bulk Operations` page exposes it for troubleshooting.

## Test plan

Added to `Shpfy Bulk Operations Test`:

- `TestBulkOperationRevertFailedLogsSkippedRecords` — completes a bulk op where two of four variants fail; asserts a skipped record is logged for each failed variant with the correct Shopify error message, and that the entry's `Table ID`/`Record ID` resolve to the linked BC Item (item-level) and Item Variant (variant-level); asserts no skipped record for the successful variants.
- `TestSendBulkOperationStoresSentJsonl` — with Logging Mode = All, asserts the sent JSONL is stored on the bulk operation record.
- `TestSendBulkOperationDoesNotStoreSentJsonlWhenNotLoggingAll` — with Logging Mode = Error Only, asserts nothing is stored.



