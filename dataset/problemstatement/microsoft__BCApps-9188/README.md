# [Shopify] Create BC customer on order import when Shopify customer has no default address

## What & why

During Shopify order import and customer sync, the connector handled a Shopify customer with **no default address** (Shopify `defaultAddress = null` — e.g. an address with Company populated but not flagged default) inconsistently across three code paths that all filter on `SetRange(Default, true)`:

| Codeunit | Old behavior on no default address |
|---|---|
| 30117 `Shpfy Customer Import` | ✅ already fell back to any available address |
| 30113 `Shpfy Cust. By Email/Phone` | ❌ returned blank → order silently mapped to the shop's **Default Customer** (no BC customer created) |
| 30124 `Shpfy Update Customer` | ❌ hard `Error("No default address found...")` → aborted sync / order import for an already-linked customer |

The 30113 gap is the direct cause of ICM 51000001096512 (customer not created on order import). The 30124 gap is a latent, related failure of the same root cause. When Shopify returns `defaultAddress = null`, `ShpfyCustomerAPI` flags every address `Default = false`, so the default-only lookups find nothing.

This change makes all three paths consistent:
- **CU 30113** – fall back to the first available address when no default exists; re-read the Shopify customer (`Get(CustomerId)`) before returning so the `Customer No.` FlowField reflects the newly linked customer (otherwise the customer is created but `DoMapping` still returns blank and the order maps to the default customer).
- **CU 30124** – fall back to the first available address instead of erroring; only error when the customer has **no address at all**. The misspelled label `NoDefaltAddressErr` ("No default address found") is renamed to `NoAddressErr` ("No address found") to match the corrected semantics.

## Linked work

Fixes [AB#641625](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/641625)

<!-- Internal ADO work item; originates from ICM 51000001096512. -->

## How I validated this

- [x] I read the full diff and it contains only changes I intended.
- [x] I built the affected app(s) locally with no new analyzer warnings.
- [x] I ran the change in Business Central and confirmed it behaves as expected.
- [x] I added or updated tests for the new behavior, or explained below why none are needed.

**What I tested and the outcome**

Built the Shopify Connector (App) and Test apps locally via AL — 0 errors, no new warnings. Added two regression tests in codeunit 139565:
- `UnitTestMapCustomerWithoutDefaultAddressStillCreatesCustomer` — stages a Shopify customer with a non-default address, maps `By EMail/Phone` with `AllowCreate = true`, asserts a BC customer is created **and** linked (`Customer No.` = result).
- `UnitTestUpdateCustomerWithoutDefaultAddressDoesNotError` — links a BC customer to a Shopify customer with a non-default address, runs `Shpfy Update Customer`, asserts it no longer errors and fills fields from that address.

Both tests **pass with the fix** and **fail without it** (30113 returns blank; 30124 errors with "No default address found..."), confirming they are genuine regression guards. All 4 tests in codeunit 139565 pass.

## Risk & compatibility

Low. Behavior is unchanged when a default address exists. The new paths only affect the previously-broken no-default-address case: CU 30113 now creates/links a customer instead of returning blank; CU 30124 now updates from an available address instead of erroring. The renamed label (`NoAddressErr`) is user-facing and translatable — translations regenerate on build. No schema, permission, or upgrade impact.




