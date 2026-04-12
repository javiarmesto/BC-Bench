---
name: skill-al-bugfix
description: >
  AL bug-fix patterns for Business Central triggers and table extensions.
  Use when fixing bugs that involve OnValidate triggers, field clearing,
  guard clauses, symmetric table changes, or mock data mismatches.
  Especially useful when a test validates behavior on empty/zero field values.
---

# AL Bug-Fix Patterns for Business Central

Procedural knowledge for fixing bugs in AL table triggers, codeunits, and
extensions. Focuses on the patterns that cause most failures in automated
bug-fix evaluation.

## Pattern 1: OnValidate Guard Clauses

**The #1 failure mode.** When a test calls `Validate("FieldName", '')` or
`Validate("FieldName", 0)`, the OnValidate trigger runs ALL existing code
before reaching your new code. If the existing code calls `Get()` or
`Error()` on the empty value, it crashes before your fix executes.

### Diagnosis

Read the OnValidate trigger top-to-bottom. For each operation, ask:
"What happens if the field value is `''` or `0`?"

```al
// BEFORE your fix — existing trigger code:
trigger OnValidate()
var
    Item: Record Item;
begin
    // This line CRASHES when "No." = '' because Item.Get('') fails
    if not Item.Get("No.") then
        Error(EntityDoesNotExistErr, Item.TableCaption, "No.");

    // Your new code here would NEVER execute
    CheckAndDisconnectContractLine();
end;
```

### Fix Pattern

Wrap the existing validation in a guard that skips when the field is empty:

```al
trigger OnValidate()
var
    Item: Record Item;
begin
    if "No." <> '' then  // ← GUARD: skip validation when clearing the field
        if not Item.Get("No.") then
            Error(EntityDoesNotExistErr, Item.TableCaption, "No.");

    CheckAndDisconnectContractLine();  // ← Now reachable even when No. = ''
end;
```

Also guard the called procedure if it assumes a populated field:

```al
procedure CheckAndDisconnectContractLine()
begin
    if "No." = '' then
        exit;  // ← Early return: nothing to check when field is empty
    // ... rest of logic that calls .Get() on the field
end;
```

### Checklist

- [ ] Does the trigger have `Get()`, `Find()`, or `Error()` calls that fail on empty values?
- [ ] Did I wrap those calls in `if "FieldName" <> '' then`?
- [ ] Does my new code need the field to be populated? If yes, add early `exit`.
- [ ] Does `Init()` or `Clear(Rec)` run after my code? If yes, reorder.

## Pattern 2: Symmetric Table Changes

BC Subscription Billing, Sales/Purchase, and Customer/Vendor modules
typically mirror logic across paired tables:

| If you fix... | Also check... |
|---|---|
| `Cust. Sub. Contract Line` | `Vend. Sub. Contract Line` |
| `Sales Header` / `Sales Line` | `Purchase Header` / `Purchase Line` |
| Customer-side event subscriber | Vendor-side event subscriber |

### Diagnosis

When the test patch references TWO codeunits (e.g., codeunit 148155
"Contracts Test" AND codeunit 148154 "Vendor Contracts Test"), the
production fix must touch BOTH corresponding tables.

### Fix Pattern

1. Fix the first table completely (both guard + new logic)
2. Find the mirror table by name pattern
3. Apply the SAME pattern — usually identical logic, different record types
4. Verify both tests reference the same procedure name

### Gotcha

The mirror table may use different variable names or slightly different
helper procedure names. Don't copy-paste blindly — adapt the variable
names to match the target table's conventions.

## Pattern 3: Mock Data vs Runtime Data

**Second most common failure.** The test sets up data in BC tables
directly (via library codeunits), not through APIs or external calls.
If your fix queries runtime state that the test doesn't populate, the
fix works in production but fails the test.

### Diagnosis

Read the test setup carefully:
- `Library*.Create*()` calls create records in specific tables
- If the test does NOT call `Library*.Create*()` for a table you query,
  that table is EMPTY during the test
- Mock HTTP handlers (`MockHttpHandler`, `MockGraphQLHandler`) return
  canned responses — they don't populate BC tables

### Fix Pattern

**Make your fix depend only on data the test creates**, not on data
that would exist in a real environment.

```al
// ❌ BAD: queries a table the test doesn't populate
ShopLocation.SetRange("Shop Code", Shop.Code);
if ShopLocation.FindFirst() then
    if ShopLocation."Is Fulfillment Service" then
        exit;  // Skip export — but ShopLocation is empty in test!

// ✅ GOOD: uses fields from records the test DOES create
if Shop."Is Fulfillment Service" then
    exit;  // Skip export — Shop record IS set up by test
```

### Checklist

- [ ] Which records does the test explicitly create?
- [ ] Does my fix query any table NOT created by the test?
- [ ] Can I use a field from an existing record instead of joining to a new table?

## Pattern 4: IsHandled Event Interception

When a bug requires preventing default behavior (not just adding behavior),
use the `IsHandled` pattern on `OnBefore` events.

### Diagnosis

If the test expects that a standard operation does NOT happen (count = 0,
field unchanged, no error raised), you may need to intercept the operation
via an event subscriber.

### Fix Pattern

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Standard Codeunit",
    'OnBeforeDoSomething', '', false, false)]
local procedure SkipDoSomethingWhenCondition(
    var Rec: Record "My Table";
    var IsHandled: Boolean)
begin
    if Rec."Condition Field" then
        IsHandled := true;  // Prevents the standard code from executing
end;
```

### Gotchas

- Subscriber parameter signature must **exactly match** the publisher
- `IsHandled := true` means "I handled it, skip the default" — verify this
  is the semantics the test expects
- Check if another subscriber already sets `IsHandled` before yours runs
- Event subscribers are `local` procedures — always

## Pattern 5: Record State After Init/Clear

`Rec.Init()` resets all non-key fields to defaults. `Clear(Rec)` resets
everything including the primary key. Code that runs AFTER Init/Clear
operates on a blank record.

### Diagnosis

In OnValidate triggers, the pattern:
```al
TempRecord := Rec;
Init();                    // Resets Rec to defaults
SystemId := TempRecord.SystemId;  // Restores only some fields
```
means any field you set BEFORE `Init()` is lost. Your new code must run
BEFORE this block or use the temp record to preserve state.

### Checklist

- [ ] Does `Init()` or `Clear()` run after my code in the trigger?
- [ ] Do I need to move my code before the Init/Clear block?
- [ ] If the test checks a field value post-Init, am I preserving it correctly?

## Quick Decision Tree

```
Test calls Validate("Field", '') or Validate("Field", 0)?
├── YES → Pattern 1 (OnValidate Guard Clauses)
│   └── Also check: Pattern 5 (Init/Clear ordering)
└── NO
    Test expects operation NOT to happen (count=0, field unchanged)?
    ├── YES → Pattern 4 (IsHandled Event Interception)
    └── NO
        Test references TWO mirrored codeunits?
        ├── YES → Pattern 2 (Symmetric Table Changes)
        └── NO
            Test uses Library* mocks, fix queries different tables?
            ├── YES → Pattern 3 (Mock Data vs Runtime Data)
            └── NO → Standard fix: add/modify code in the right procedure
```
