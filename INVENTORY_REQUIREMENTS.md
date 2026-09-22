# INVENTORY-0 — Inventory Requirements Audit & Architecture Preparation Report (Corrected)

**Date:** 2026-09-21  
**Project:** Enterprise CRM (`d:\projects\enterprise_crm`)  
**Status:** AUDIT COMPLETE / AWAITING BUSINESS FREEZE  

---

## 1. Executive Summary

`INVENTORY-0` is an architectural and requirements audit checkpoint conducted prior to writing any production domain entities, state management, or UI screens for the Inventory module.

This corrected report strictly distinguishes between **evidence-backed repository facts** and **unconfirmed business requirements**. Generic inventory concepts (such as an item master, SKU, quantity tracking, or warehouses) are not treated as established business requirements merely because the CRM module is named "Inventory."

The purpose of this document is to record verified codebase invariants, enumerate all unanswered business decisions, outline architectural options with their prerequisites, and provide a clean decision freeze template.

---

## 2. Baseline Verification (Starting State)

- **Branch:** `main`
- **Git HEAD:** `02b41a83302a96e29b2206a9e6737a34eafb45ed`
- **Working Tree:** `INVENTORY_REQUIREMENTS.md` is currently untracked in repository root (`d:\projects\enterprise_crm\INVENTORY_REQUIREMENTS.md`). `.gitignore` is completely untouched.
- **Flutter Analyzer:** Clean (0 issues found).
- **Flutter Test Suite:** **1,132 / 1,132 PASS** (0 failures).
- **Flutter Web Build:** **PASS** (`flutter build web` successful).

---

## 3. Confirmed Repository State (Implementation Facts)

The following statements represent verified code-level facts from the current repository:

1. **`CrmModule.inventory` exists:**
   Defined in `lib/features/auth/domain/entities/crm_module.dart`.
2. **`CrmPermissions.inventoryView` exists:**
   Defined as `'inventory.view'` in `lib/features/auth/domain/policies/crm_permissions.dart`.
3. **`inventory.view` canonically belongs to `CrmModule.inventory`:**
   Mapped in `CrmPermissions._moduleByPermission` and registered in `MockPermissionCatalog` with display name `'View Inventory'`.
4. **Admin receives frontend module access via `AccountType.admin`:**
   Evaluated through `AccessPolicy.canAccessModule` and `user.isAdmin`. Admin accounts are not restricted by module assignment lists or individual permission strings.
5. **A standard User needs `CrmModule.inventory` assigned to access the module:**
   Enforced by `AccessPolicy.canAccessModule(user, CrmModule.inventory)`. Direct navigation without assignment returns `AccessRestrictedScreen`.
6. **Current User placeholder interprets `inventory.view` as the operational permission:**
   In `ModulePlaceholderScreen`, an assigned standard user possessing `inventory.view` sees `"Access granted. Coming in a later module phase."` and `"ASSIGNED CAPABILITIES: View inventory"`. If `inventory.view` is absent, the placeholder renders `module_no_operational_permission` ("You do not currently have an operational permission for this module. Contact an administrator to request operational permissions.").
7. **Admin and User currently route Inventory to `ModulePlaceholderScreen`:**
   `AdminDashboardScreen` and `UserDashboardScreen` push `ModulePlaceholderScreen(module: CrmModule.inventory, user: user)`.
8. **No Inventory domain entity exists:**
   There is no `InventoryItem`, `Product`, `Stock`, `SKU`, or related domain model anywhere in `lib/`.
9. **No Inventory repository exists:**
   There is no `InventoryRepository` interface or mock implementation in the codebase.
10. **No Inventory Cubit or BLoC exists:**
    State management for Inventory has not been implemented.
11. **No Inventory business screen exists:**
    There is no Item List, Item Details, or Inventory Dashboard screen.
12. **No Purchase $\rightarrow$ Inventory integration exists:**
    `CrmModule.purchase` exists solely as an enum value, placeholder screen, and `purchase.view` permission. No purchase models, orders, or receiving workflows exist.
13. **No Dispatch $\rightarrow$ Inventory integration exists:**
    `CrmModule.dispatch` exists solely as an enum value, placeholder screen, and `CallOutcome.dispatched` lead call outcome. No dispatch models or stock deduction workflows exist.
14. **No Vendor $\rightarrow$ Inventory integration exists:**
    `CrmModule.vendorManagement` exists solely as an enum value, placeholder screen, and `vendor.view` permission. No vendor models or vendor-item relationships exist.

### 3.1 Note on Existing Presentation Copy
In `lib/features/dashboard/presentation/mappers/crm_module_presentation.dart`, the subtitle for `CrmModule.inventory` is:
```text
'Stock levels, warehouses, and items'
```
**Fact:** This string is **legacy placeholder presentation copy only**. It does NOT constitute a confirmed technical specification or business requirement for warehouse support, an item entity, or a stock model.

---

## 4. Corrected Requirements Matrix

All domain and business concepts are classified below. Every item lacking an explicit, user-approved requirement is strictly marked **UNCONFIRMED**.

| Category | Item / Question | Status | Classification Details |
|---|---|---|---|
| **Item Identity** | Product / Item Master | **UNCONFIRMED** | Generic inventory concept; exact entity definition not yet established. |
| **Item Identity** | Item Name required | **UNCONFIRMED** | Unconfirmed field requirement on the tracked entity. |
| **Item Identity** | SKU (Stock Keeping Unit) | **UNCONFIRMED** | Whether SKU is mandatory, optional, auto-generated, or needed is unconfirmed. |
| **Item Identity** | Barcode / QR Code | **UNCONFIRMED** | Unconfirmed; no requirement states whether barcode scanning or storage is required. |
| **Item Identity** | Category / Tagging | **UNCONFIRMED** | Taxonomy, flat enum, or tag system unconfirmed. |
| **Item Identity** | Unit of Measure (UOM) | **UNCONFIRMED** | Discrete units (PCS, BOX) vs continuous (KG, LTR) vs free text unconfirmed. |
| **Item Identity** | Item Description | **UNCONFIRMED** | Spec/note field unconfirmed. |
| **Stock Tracking** | Quantity tracked | **UNCONFIRMED** | Whether items track numeric quantities or serialized assets is unconfirmed. |
| **Stock Tracking** | Global vs Location-specific | **UNCONFIRMED** | Single aggregate count vs multi-location breakdown unconfirmed. |
| **Stock Tracking** | Negative stock allowed | **UNCONFIRMED** | Backorders / negative stock balance behavior unconfirmed. |
| **Stock Tracking** | Stock adjustments allowed | **UNCONFIRMED** | Direct quantity edit vs adjustment delta with reason codes unconfirmed. |
| **Stock Tracking** | Opening stock supported | **UNCONFIRMED** | Initial stock entry on item creation vs inward movement unconfirmed. |
| **Stock Tracking** | Reserved quantity needed | **UNCONFIRMED** | Distinction between physical stock and available stock unconfirmed. |
| **Stock Tracking** | Available vs Physical stock | **UNCONFIRMED** | Allocation formulas unconfirmed. |
| **Location** | Single inventory location | **UNCONFIRMED** | Unconfirmed. |
| **Location** | Multiple warehouses | **UNCONFIRMED** | Unconfirmed; presentation copy mentions warehouses, but domain does not. |
| **Location** | Branch-level stock | **UNCONFIRMED** | Unconfirmed. |
| **Location** | Rack / Bin tracking | **UNCONFIRMED** | Unconfirmed; neither required nor explicitly rejected by business. |
| **Pricing & Cost** | Purchase price (Unit Cost) | **UNCONFIRMED** | Procurement cost tracking unconfirmed. |
| **Pricing & Cost** | Selling price (List Price) | **UNCONFIRMED** | Sales price tracking unconfirmed. |
| **Pricing & Cost** | MRP (Maximum Retail Price) | **UNCONFIRMED** | Consumer pricing unconfirmed. |
| **Pricing & Cost** | Valuation Method (FIFO / WAC) | **UNCONFIRMED** | Inventory valuation unconfirmed. |
| **Pricing & Cost** | Indian Tax / GST (CGST/SGST/IGST/HSN) | **UNCONFIRMED** | **Do not implement or assume jurisdiction-specific tax behavior without explicit requirements.** |
| **Pricing & Cost** | Currency | **UNCONFIRMED** | Currency field and denomination unconfirmed. |
| **Lifecycle** | Active / Inactive status | **UNCONFIRMED** | Soft archiving without deletion unconfirmed. |
| **Lifecycle** | Delete vs Archive | **UNCONFIRMED** | Hard deletion vs archiving unconfirmed. |
| **Lifecycle** | Stock adjustment history | **UNCONFIRMED** | Adjustment logging requirements unconfirmed. |
| **Lifecycle** | Stock movement ledger | **UNCONFIRMED** | Double-entry / event-sourced ledger unconfirmed. |
| **Purchase Int.** | Purchase creates inward stock | **UNCONFIRMED** | Cross-module inward flow unconfirmed. |
| **Purchase Int.** | Purchase approval affects stock | **UNCONFIRMED** | Cross-module approval workflow unconfirmed. |
| **Purchase Int.** | Partial goods receipt | **UNCONFIRMED** | Partial receiving unconfirmed. |
| **Purchase Int.** | Goods Receipt Note (GRN) | **UNCONFIRMED** | Inward document entity unconfirmed. |
| **Dispatch Int.** | Dispatch consumes stock | **UNCONFIRMED** | Cross-module deduction flow unconfirmed. |
| **Dispatch Int.** | Stock reservation before dispatch | **UNCONFIRMED** | Reservation mechanisms unconfirmed. |
| **Dispatch Int.** | Partial dispatch supported | **UNCONFIRMED** | Multi-shipment fulfillment unconfirmed. |
| **Dispatch Int.** | Return-to-stock (RMA) | **UNCONFIRMED** | Customer returns workflow unconfirmed. |
| **Vendor Int.** | Item linked to vendor(s) | **UNCONFIRMED** | 1:1, 1:N, or M:N mapping unconfirmed. |
| **Vendor Int.** | Preferred vendor | **UNCONFIRMED** | Primary supplier designation unconfirmed. |
| **Vendor Int.** | Vendor-specific prices | **UNCONFIRMED** | Vendor price lists unconfirmed. |

---

## 5. Summary of Removed Assumptions

The following items from the initial draft have been explicitly corrected:

1. **Product / Item Master:** Changed from `CONFIRMED` $\rightarrow$ `UNCONFIRMED`.
2. **Item Name:** Changed from `CONFIRMED` $\rightarrow$ `UNCONFIRMED`.
3. **Quantity Tracked:** Changed from `CONFIRMED` $\rightarrow$ `UNCONFIRMED`.
4. **Rack / Bin Tracking:** Changed from `NOT REQUIRED` $\rightarrow$ `UNCONFIRMED`.
5. **GST / HSN / Tax:** Changed from `NOT REQUIRED` $\rightarrow$ `UNCONFIRMED — do not implement or assume jurisdiction-specific tax behavior without explicit requirements`.
6. **Barcode / QR:** Removed the speculative assumption *"not needed for phase 1"*; changed to `UNCONFIRMED`.
7. **INVENTORY-1 Scope:** Removed the premature declaration that INVENTORY-1 equals a *"Read-Only Item List"*. Stated that INVENTORY-1 cannot be scoped until the core business model is approved.

---

## 6. Architecture Options Analysis

Three primary architectural alternatives exist for the Inventory domain. No option is selected at this stage; selection depends on which business requirements are approved.

### Option A — Simple Quantity Model
```text
InventoryItem
├── id: String
├── name: String
├── sku: String?
└── quantityOnHand: int
```
- **Business Justification:** Appropriate if:
  - Inventory is managed at a single global location.
  - No audit log or historical traceability of stock changes is required.
  - Direct quantity editing (simple CRUD) is acceptable.
  - Strict YAGNI is prioritized over audit compliance.

### Option B — Item Master + Stock Movement Ledger
```text
InventoryItem
└── StockMovement (id, itemId, type, delta, balanceAfter, reason, userId, timestamp)
```
- **Business Justification:** Appropriate if:
  - Historical audit trails are required (who changed stock, when, and why).
  - Traceability is needed for future Purchase (inward) and Dispatch (outward) events.
  - Stock changes must be immutable events rather than overwrites.
  - Single location or centralized stock is sufficient.

### Option C — Item + Warehouse Stock + Movement Ledger
```text
InventoryItem
└── ItemWarehouseStock (itemId, warehouseId, quantityOnHand, reservedQuantity)
    └── WarehouseStockMovement
```
- **Business Justification:** Appropriate ONLY if:
  - Multi-warehouse, multi-facility, or branch-level stock tracking is an approved requirement.
  - Inter-warehouse transfers are needed.
  - Stock allocation per location is necessary.

---

## 7. Minimum Business Decisions Required for INVENTORY-1

`INVENTORY-1` cannot be scoped or implemented until the user approves the minimum Inventory business model. The 7 essential questions that must be answered are:

1. **What exactly is being inventoried?** (Physical products, equipment, parts, materials, or digital goods?)
2. **Which fields identify an item?** (Name, SKU, code, category, UOM, description?)
3. **Is stock quantity tracked?** (Yes/No, numeric counts, serial numbers?)
4. **If yes, is stock aggregate (single location) or location-specific (multi-warehouse)?**
5. **Is quantity directly editable, or must it change only through stock movements/adjustments?**
6. **Are Purchase and Dispatch responsible for stock movement now, or in a later phase?**
7. **Which operational actions should standard Users be allowed to perform vs Admin?** (View only, create items, adjust stock?)

---

## 8. INVENTORY-BF — BUSINESS FREEZE
**Status: FROZEN**

The following business requirements have been explicitly approved and frozen by the user:

```text
Entity:
Physical products / stock items

Required:
Name
Unique SKU

Quantity:
Tracked

Source of stock truth:
Movement ledger

Direct quantity editing:
No

Location:
Single aggregate location

Opening stock:
Opening-stock movement

Current User permission:
inventory.view

Deferred:
warehouses
rack/bin
category
UOM
description
pricing
tax
purchase integration
dispatch integration
vendor integration
negative-stock policy
stock mutation UI
delete/archive
```

The approved business-freeze overrides earlier UNCONFIRMED entries for these specific decisions. `INVENTORY_REQUIREMENTS.md` is now an intentional project requirements artifact tracked with INVENTORY-1.

---

## 9. INVENTORY-2 — ADMIN ITEM ADMINISTRATION
**Status: IMPLEMENTED**

### Summary
INVENTORY-2 adds the first Inventory write workflow while strictly preserving the completed INVENTORY-1 architecture and frozen business model.

### Record
- **Admin item creation:** Implemented
- **Admin identity editing:** Implemented
- **Editable fields:**
  - `name`
  - `sku`
- **New item derived quantity:** `0`
- **Zero opening movement on creation:** Yes (no artificial 0.0 movement created; derived dynamically as `SUM(StockMovement.quantityDelta) = 0.0`)
- **Standard Users:** Read-only (`inventory.view` operational permission; direct navigation blocked by pre-Cubit guard)
- **Direct quantity editing:** Still prohibited
- **Stock preservation on edit:** Editing item identity (`name`, `sku`) leaves movement ledger untouched and derived quantity strictly unchanged

### Still Deferred
- Delete / Archive
- Opening-stock entry UI
- Stock Adjustment
- Stock Movement History UI
- Negative-stock policy
- Purchase integration
- Dispatch integration
- Vendor integration
- Multiple warehouses / locations
- Rack / Bin
- Category
- UOM
- Description
- Pricing
- Tax / GST / HSN
- Backend integration

---

## 10. INVENTORY-3 — STOCK MOVEMENT CORE
**Status: FROZEN AND IMPLEMENTED**

### 10.1 Overview & Scope
INVENTORY-3 implements the first operational stock-changing workflows:
- **Opening Stock:**
  - Admin only
  - separate post-create operation
  - only with zero previous movements (`hasStockMovements == false`)
  - finite quantity > 0
  - reason null
  - actor recorded (`performedByUserId` from `CurrentUser.id`)
- **Adjustment:**
  - Admin only
  - initialized items only (`hasStockMovements == true`)
  - Increase / Decrease UI
  - signed quantityDelta in domain
  - finite nonzero delta
  - required trimmed nonblank free-text reason
  - actor recorded (`performedByUserId` from `CurrentUser.id`)
- **Negative final stock:**
  - prohibited (`currentQuantity + quantityDelta >= 0` enforced atomically at repository boundary)
- **Quantity:**
  - movement-derived (`SUM(StockMovement.quantityDelta)`)
  - direct edits prohibited
- **History UI:**
  - deferred to INVENTORY-4
- **Permissions:**
  - no new Inventory permissions (`InventoryStockManagementPolicy.canManageStock(CurrentUser)`)
- **Legacy seed compatibility:**
  - existing movements may have null actor/reason
  - new movements must obey current mutation rules

### 10.2 Decision Matrix (Approved & Frozen)

| Decision | Status | Frozen Rule |
|---|---|---|
| Current stock source of truth | **FROZEN** | `SUM(StockMovement.quantityDelta)` — derived dynamically, never stored on `InventoryItem`. |
| Direct quantity editing | **FROZEN** | Strictly prohibited. No `setQuantity` or inline quantity field on item master. |
| Location model | **FROZEN** | Single aggregate inventory location. No warehouse, room, or bin models. |
| Opening stock supported | **FROZEN** | Supported. Admin can record an initial opening stock movement for items. |
| Opening stock allowed once | **FROZEN** | Allowed ONCE per item. Prohibited if item already has any movements in ledger. (Eligibility uses movement history, NOT quantity == 0). |
| Opening stock zero allowed | **FROZEN** | Rejected (quantity must be finite and > 0). New items already default to 0.0 with 0 movements. |
| Negative opening stock | **FROZEN** | Strictly rejected (quantity must be finite and > 0). |
| Manual adjustment supported | **FROZEN** | Supported. Admin only. Available only on initialized items (1+ existing movements). |
| Positive adjustment | **FROZEN** | Supported (increases physical stock on hand). |
| Negative adjustment | **FROZEN** | Supported (decreases physical stock on hand). |
| Negative final stock policy | **FROZEN** | Strictly prohibited. `currentQuantity + quantityDelta >= 0` required. Rejected without clamping or partial application. |
| Zero adjustment | **FROZEN** | Rejected (delta must be finite and != 0). Zero delta is a no-op. |
| Decimal quantity | **FROZEN** | Supported using standard `double`. No external decimal dependencies. |
| Adjustment direction UI | **FROZEN** | Direction selector (Increase / Decrease) + positive quantity in UI; mapped to signed delta in domain input. |
| Reason required | **FROZEN** | Required trimmed non-blank free-text string for manual adjustments. Not required for opening stock (`reason = null`). |
| Reason type | **FROZEN** | Free text. No predefined reason enums in this phase. |
| Actor recorded (`performedByUserId`) | **FROZEN** | Required on new movements; populated automatically from authenticated `CurrentUser.id`. Legacy seed movements have null actor. |
| Timestamp recorded (`createdAt`) | **FROZEN** | Injected via deterministic `DateTime Function()`. Legacy seed movements preserved. |
| History UI in INVENTORY-3 | **FROZEN** | Deferred to INVENTORY-4. INVENTORY-3 does not implement movement history UI. |
| Stock mutations Admin-only | **FROZEN** | Admin only. Standard Users remain strictly read-only. Pre-Cubit guards on direct routes. |
| New Inventory permissions | **FROZEN** | None. Do NOT invent `inventory.adjust` or `inventory.create`. Managed via centralized `InventoryStockManagementPolicy`. |
| Warehouse dimension | **DEFERRED** | Preserved deferred. Single aggregate stock only. |
| Purchase & Dispatch integration | **DEFERRED** | Preserved deferred. No purchase receipt or dispatch movement types. |
| Pricing / Cost / Tax / Currency | **DEFERRED** | Preserved deferred. Movements track unit quantities only. |
| Delete / Archive items | **DEFERRED** | Preserved deferred. Items cannot be deleted or archived. |

### 10.3 Invariants & Operational Rules

#### 1. Opening Stock Rules
- Admin only.
- Separate post-creation operation (not part of Create Item screen).
- Eligibility check: Item has ZERO existing `StockMovement` records (`hasStockMovements == false`).
- Must NOT use `quantityOnHand == 0` as eligibility test (e.g. an item adjusted to 0 has movements, so opening stock is unavailable).
- Finite quantity > 0 required.
- Appends exactly one `StockMovementType.openingStock` movement with `performedByUserId = currentUser.id`, `reason = null`.

#### 2. Manual Stock Adjustment Rules
- Admin only.
- Available ONLY on items that already have stock movement history (1+ existing movements).
- UI presents Direction (Increase / Decrease) and positive numeric magnitude.
- Mapped to signed `quantityDelta` in domain input (+magnitude for Increase, -magnitude for Decrease).
- Finite, non-zero magnitude required.
- Free-text reason mandatory: trimmed, non-blank.
- Appends exactly one `StockMovementType.adjustment` movement with `performedByUserId = currentUser.id`, `reason = trimmed reason`.

#### 3. Strict Non-Negative Stock & Concurrency Invariant
- Repository invariant: `currentQuantity + quantityDelta >= 0`.
- The repository mutation operation must atomically:
  1. Re-derive current quantity from movement ledger.
  2. Validate requested operation against current balance.
  3. Append exactly one movement record.
  4. Re-derive updated summary and return mutation result.
- Client-side validation is non-authoritative; repository independently enforces balance at the write boundary.

#### 4. Legacy Seed Compatibility
- Existing seed movements created before actor/reason auditing remain valid with `performedByUserId = null` and `reason = null`.
- Seed items with opening movements are treated as initialized (`hasStockMovements == true`), so `[Set Opening Stock]` is unavailable and `[Adjust Stock]` is available.
- New operational movements require `performedByUserId` and follow the frozen rules.
