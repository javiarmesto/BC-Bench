# [Shopify] Uptake Admin GraphQL API to version 2026-07

Uptakes the Shopify Admin GraphQL API from **2026-01** to **2026-07** (two hops: 2026-04 + 2026-07) and handles the one 2026-07 deprecation that would otherwise silently break merchants: market-driven shipping.

## 1. Version bump
- Bumped the pinned API version in `ShpfyCommunicationMgt.Codeunit.al` (`VersionTok`) from `2026-01` to `2026-07`, and updated the doc references.

A full review of the 2026-04 and 2026-07 Admin GraphQL / Webhook changelog entries (76 relevant entries) found no other required query changes: the largest breaking change - inventory compare-and-swap `changeFromQuantity` + mandatory `@idempotent` (required in 2026-04) - was already implemented during the 2026-01 uptake, and every other breaking change either does not touch the connector surface or was already handled.

## 2. Market-driven shipping reader (Shopify upgrade guide, readers Option B)
Shopify is deprecating the merchant-owned `deliveryProfile(s)` APIs for shops that move to market-driven shipping (rollout Oct 1 2026; all merchants by Jul 1 2027). For those shops the legacy `deliveryProfiles` query the connector uses to discover shipping-method names returns stale/incomplete data, silently breaking the `Shpfy Shipment Method Mapping`.

- `ShpfyShippingMethods` now detects the model via `ShopFeatures.marketDrivenShipping`.
- Market-driven shops: reads active shipping option names from `markets -> delivery.shipping.optionDefinitions` (inline fragments for the concrete option types).
- Legacy shops: unchanged `deliveryProfiles` path.
- The `read_markets` scope is already requested by the connector - no scope change needed.
- Adds `GetMarketShippingMethods` / `GetNextMarketShippingMethods` resources, two `Shpfy GraphQL Type` enum values, and a test covering the market-driven path.

## Validation
- Shopify **App project builds clean (0 errors)** via AL.
- The new test file compiles clean (per-file diagnostics 0 errors). The test-project full build hits a pre-existing, unrelated environmental symbol gap (`MockAzureKeyVaultSecretProvider` in the untouched `ShpfyTestShopify.Codeunit.al`); CI compiles the test project properly.

Fixes [AB#625461](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/625461)







