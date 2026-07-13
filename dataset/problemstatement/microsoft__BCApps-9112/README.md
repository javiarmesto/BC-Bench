# [Shopify] Skip refund credit memo while transaction is pending

Fixes [AB#640432](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/640432)

## Summary

When a Shopify refund is synced while its payment transaction is still **pending**, Shopify's `totalRefundedSet` returns 0 (it only counts `SUCCESS` transactions). If a credit memo is created at that moment, the balancing line in `CreateSalesLinesFromRemainingAmount` calculates `Unit Price = 0 - <item total>`, producing a credit memo whose total is 0 — a financially useless document.

## Root cause

`ShpfyCreateSalesDocRefund.Codeunit.al` balances the document against `RefundHeader."Total Refunded Amount"`, which is 0 while the refund transaction is still pending, even though the item/return lines already sum to the real amount.

## Fix

Block credit memo / return order creation while the refund still has a pending transaction, mirroring the existing `"Can Create Credit Memo"` dual-guard pattern:

- **`ShpfyRefundsAPI.Codeunit.al`** — new internal helper `HasPendingRefundTransactions(RefundId)` that checks for refund transactions with `Type = Refund` and `Status = Pending`. `VerifyRefundCanCreateCreditMemo` now throws a clear error when a pending transaction exists (manual **Create Sales Document** path).
- **`ShpfyRetRefProcCrMemo.Codeunit.al`** — `CreateSalesDocument` now exits early (silent skip) when the refund still has a pending transaction (auto-sync path). The refund stays unprocessed and is retried on the next sync; once the transaction reaches `SUCCESS`, `totalRefundedSet` is final and the credit memo is created correctly.

This is safe because the auto-processing loop (`ProcessShopifyRefunds`) retries all unprocessed refunds on every sync, and no data is guessed or approximated.

## Test plan

Added to `ShpfyOrderRefundTest.Codeunit.al` (with a `CreateRefundTransaction` helper in `ShpfyOrderRefundsHelper.Codeunit.al`):

- `UnitTestDoesNotCreateCrMemoFromRefundWithPendingTransaction` — no credit memo is created while the refund has a pending transaction.
- `UnitTestCreatesCrMemoFromRefundWithSucceededTransaction` — the guard is specific to pending; a succeeded transaction still creates the credit memo.
- `UnitTestVerifyRefundCanCreateCreditMemoErrorsWithPendingTransaction` — the manual path throws the pending-transaction error.



