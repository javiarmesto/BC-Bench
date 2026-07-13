# [Shopify] Fix GraphQL rate limiter under-waiting after elapsed time

## Summary

The Shopify connector's cost-based rate limiter (`Shpfy GraphQL Rate Limit`, codeunit 30153) under-waits when time has elapsed between the previous Shopify response and the next request, so it re-issues requests before enough throttle budget has restored. On high-volume shops this produces avoidable GraphQL throttling (telemetry tag `0000QWH`).

In `WaitForRequestAvailable(ExpectedCost)`:

- `CalcWaitTime` / `TryCalcWaitTime` already returns the **remaining** wait from now — it subtracts `(CurrentDateTime - LastRequestedOn)`.
- The result was then anchored as `NextRequestAfter := LastRequestedOn + WaitTime`, subtracting the elapsed gap a **second** time. The wake time lands earlier than the true target (`LastRequestedOn + deficit/restoreRate`), so the limiter fires early into the throttle.

### Fix

Anchor at `CurrentDateTime + WaitTime` and drop the redundant preceding `NextRequestAfter := CurrentDateTime;` assignment.

### Customer impact

Observed on a high-volume production shop running many parallel Task Scheduler sync jobs: sustained throttling on heavy sync days (tens of thousands of `0000QWH`/day). No data loss and no failed syncs — all throttled requests auto-recover via the retry loop in `Shpfy Communication Mgt.` (millions of requests returned HTTP 200 with only a handful of non-200s over the observed period) — but sync throughput is degraded because the connector churns through the throttle instead of pacing correctly. ExpectedCost equals RequestedCost, so the cost predictor is correct; the defect is purely in the wait timing.

## Test plan

- Added `Shpfy GraphQL Rate Limit Test`.`UnitTestWaitForRequestAvailableAfterElapsedTime`: sets availability low (3 s restore needed), lets 2 s elapse, then asserts the wait is ~1 s (the remaining time) rather than 0. This case is indistinguishable between old and new behavior without the elapsed delay, which is why the original test did not catch the defect:
  - **Before:** `NextRequestAfter` lands in the past → sleep clamps to ~0 ms (assert fails).
  - **After:** waits ~1000 ms (assert passes). The `AreNearlyEqual(1000, WaitTime, 400)` bound also rejects a naive full-restart (~3000 ms).
- Existing `UnitTestWaitForRequestAvailable` scenarios are unchanged and still pass.

Fixes [AB#641550](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/641550)

