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

---

## 11. INVENTORY-4 — CSV / XLSX INVENTORY IMPORT
**Status: FROZEN**

### 11.1 Overview & Scope
INVENTORY-4 implements the CSV and XLSX inventory bulk import workflow for administrative users while strictly preserving the frozen Inventory architecture, ledger integrity, and access controls.

### 11.2 Core Specifications & Invariants
- **Formats:**
  - Supported: Exactly `.csv` and `.xlsx`
  - Unsupported: `.xls`, `.json`, `.xml`, `.txt`, `.pdf`, Google Sheets
  - Web-safe byte-based parsing (no platform-specific `dart:io` file path dependency)
- **Authorization:**
  - Admin only (`InventoryImportPolicy` / `user.isAdmin`)
  - Standard User denied
  - Direct route guard: Evaluates authorization before Cubit initialization; unauthorized navigation routes to `AccessRestrictedScreen` with zero parser/repository calls
  - No new permission strings (do NOT introduce `inventory.import` or `inventory.bulk_create`)
- **Supported Fields:**
  - Required: `Name`, `SKU`
  - Optional: `Opening Stock`
  - Strictly outside scope: Category, UOM, Description, Warehouse, Location, Rack, Bin, Vendor, Purchase Price, Selling Price, MRP, Cost, GST, Tax, HSN, Adjustment Reason, Performed By, Movement Type
- **Header & Column Mapping:**
  - Source headers may be blank, duplicated, or whitespace-only; columns identified by position/index
  - Explicit header row selection supported (not assumed to be row 1)
  - No fuzzy or automated similarity mapping; manual selection is authoritative
  - Destination field rules:
    - `Name`: exactly one source column
    - `SKU`: exactly one source column
    - `Opening Stock`: zero or one source column
  - Same source column cannot be mapped to multiple destination fields
- **Blank Rows:**
  - Completely blank rows are ignored and neither count as failures nor inflate totals
- **Validation & Duplicate Rules:**
  - `Name`: Trimmed, non-blank required ("Name is required.")
  - `SKU`: Trimmed, non-blank required ("SKU is required.")
  - Duplicate comparison: Trimmed + case-insensitive (`INV-001` == `inv-001` == ` Inv-001`), preserving source casing upon creation
  - Same-file duplicates: If multiple valid rows in the import file share the same normalized SKU, ALL matching occurrences are marked duplicate and rejected from selection
  - Existing repository SKU duplicate: Row is invalid ("An inventory item with this SKU already exists."); no upsert, merge, or overwrite
  - Revalidation: Freshness enforced by re-checking SKU uniqueness at repository import execution time
- **Opening Stock Semantics:**
  - Blank / unmapped: Valid, item created with 0 movements and derived quantity 0.0; item remains eligible for later `Set Opening Stock`
  - Explicit zero (`0`, `0.0`): Invalid ("Opening stock must be greater than zero.")
  - Positive numeric: Valid finite `double > 0`, creates exactly one `StockMovementType.openingStock`
  - Invalid values: Negative numbers, non-numeric strings, NaN, Infinity rejected
- **Stock Ledger Integrity:**
  - Opening stock NEVER directly sets quantity on `InventoryItem`
  - Derived balance strictly calculated as `SUM(StockMovement.quantityDelta)`
  - Ledger movement properties:
    - `type`: `StockMovementType.openingStock`
    - `quantityDelta`: imported opening stock value
    - `performedByUserId`: Current authenticated Admin `CurrentUser.id` (never mapped from file)
    - `reason`: `null` (no artificial strings like "CSV Import")
    - `createdAt`: Injected deterministic repository/service clock
- **Atomicity & Batch Execution:**
  - Row atomicity: For rows with opening stock, item creation + opening stock movement are atomic. If movement creation fails, the item is rolled back / not persisted
  - Batch semantics: Partial success is supported (independent valid rows succeed even if others fail)
  - Intra-request duplicate defense: Repository independently enforces SKU uniqueness within the request batch
- **Workflow & UI:**
  - Workflow: Select File -> Parse -> Select Sheet (XLSX) -> Select Header Row -> Map Columns -> Build Preview -> Validate Rows -> Select Valid Rows -> Confirm Import -> Repository Import -> Result Summary -> Return to Workspace
  - Workspace entry point: Admin workspace includes `[Add Item]` and `[Import]` button (`inventory_workspace_import_button`); hidden for Standard Users
  - Double-submit protection: Submit action disabled during active import
  - Result view: Shows summary counts (imported, failed) with source row numbers and safe error messages; Done button returns to workspace and triggers fresh reload
  - Responsive layout: Adapts cleanly across mobile (320x568, 360x640), tablet (768x1024), and desktop (1200x800)
  - Dark theme & Accessibility: Proper contrast via theme colors, text-based error feedback, accessible labels
- **Deferred Areas:**
  - Stock Movement History UI
  - Inventory Export (CSV/XLSX)
  - Update / Upsert / Merge Import
  - Delete / Archive
  - Purchase integration
  - Dispatch integration
  - Return / Transfer / Reservation workflows
  - Multiple warehouses / locations / rack / bin
  - Category / UOM / Description / Pricing / Tax / GST / HSN / Vendor
  - New Inventory User write permissions
  - Backend integration (future backend invariant: item + opening stock movement must be atomic server-side)

---

## 12. INVENTORY-ACCESS-1 — Granular Permissions, Opening Stock on Create & Safe Permanent Deletion

**Status:** FROZEN  
**Date:** 2026-09-27  

### 12.1 Objective & Scope
INVENTORY-ACCESS-1 extends the Inventory module with:
1. Admin-controlled granular Inventory permissions replacing the previous permanently read-only Standard User experience.
2. Optional opening stock entry during Inventory item creation, executed atomically.
3. Safe permanent Inventory item deletion featuring exact SKU confirmation, a 60-second pending-deletion Undo window, authoritative expiration, atomic ledger deletion, and cross-module reference protection.
4. Format-specific Inventory import permissions (`inventory.import.csv` and `inventory.import.xlsx`).

---

### 12.2 Granular Permission Model & Users & Access Integration
1. **Catalog Permissions:**
   - `inventory.view`: View Inventory workspace and item details.
   - `inventory.create`: Create new Inventory items (including optional opening stock).
   - `inventory.edit`: Edit Inventory item Name and SKU.
   - `inventory.delete`: Initiate and manage permanent Inventory deletion.
   - `inventory.import.csv`: Import Inventory items from `.csv` files.
   - `inventory.import.xlsx`: Import Inventory items from `.xlsx` workbooks.
2. **Account Types & Role Invariants:**
   - Account types remain strictly `Admin` and `User`. No new roles or account types.
   - **Admin Access:** Administrators automatically possess all Inventory capabilities across the module without requiring individual permission assignments.
   - **Standard User Access:** A Standard User requires:
     `CrmModule.inventory` assigned
     `+` `inventory.view`
     `+` the specific operational permission (`inventory.create`, `inventory.edit`, `inventory.delete`, `inventory.import.csv`, `inventory.import.xlsx`).
   - Standard Users lacking `CrmModule.inventory` or `inventory.view` are denied all Inventory access.
   - Specific permissions are independent: `inventory.create` does not grant edit, delete, or import; `inventory.import.csv` does not grant `inventory.import.xlsx`.
3. **Existing Stock Operations:**
   - Standalone `Set Opening Stock` and `Adjust Stock` remain **Admin-only** for this phase. Standard users with `inventory.create` cannot perform standalone opening stock or manual adjustments on existing items.
4. **Users & Access Management:**
   - Integrated into the existing Admin-controlled Users & Access module (`MockPermissionCatalog`, `CrmPermissions`, and `CrmPermissionPresentation`).
   - Admin can assign/revoke permissions dynamically, instantly updating effective access.

---

### 12.3 Centralized Inventory Authorization
- All permission checks are centralized through dedicated policy classes (`InventoryItemAdministrationPolicy`, `InventoryImportPolicy`, `InventoryStockManagementPolicy`, and `InventoryDeletionPolicy`).
- Route guards enforce pre-Cubit authorization before Cubits or state machines initialize.
- UI elements (buttons, menus, actions) are conditionally rendered based on effective permissions.
- Button hiding alone is never considered authorization; direct unauthorized routes render `AccessRestrictedScreen` and invoke 0 repository methods.

---

### 12.4 Opening Stock on Item Creation
1. **Fields on Create Screen:**
   - `Item Name` (Required, trimmed, non-blank)
   - `SKU` (Required, unique, trimmed, case-insensitive comparison, non-blank)
   - `Opening Stock` (Optional, numeric)
2. **Validation & Semantics:**
   - **Blank / Empty:** Creates `InventoryItem` with 0 stock movements; derived quantity is `0.0`. Item remains eligible for standalone `Set Opening Stock` by Admin.
   - **Positive Finite Value (`> 0`):** Creates `InventoryItem` and exactly one `StockMovementType.openingStock` movement atomically.
     - `quantityDelta`: entered positive value (`double > 0`).
     - `performedByUserId`: authenticated `CurrentUser.id` (including authorized Standard User creators).
     - `reason`: `null`.
     - `createdAt`: deterministic injected clock.
     - Derived quantity: matches the initial stock value.
   - **Invalid Values:** `0`, `0.0`, negative numbers, non-numeric strings, NaN, Infinity are rejected with validation error ("Opening stock must be greater than zero.").
3. **Atomicity Guarantee:**
   - Item creation and its optional opening stock movement are atomic at the repository/service boundary. If movement creation fails, the item is rolled back / not persisted.

---

### 12.5 Permanent Deletion Lifecycle & Business Rules
1. **Authorization:**
   - Admin or Standard User with assigned Inventory module + `inventory.view` + `inventory.delete`.
2. **Step 1: Exact SKU Confirmation Dialog:**
   - Displays Item Name, SKU, and current derived quantity.
   - Explains: *"This item and its complete stock history will be permanently deleted after the Undo period expires."*
   - Requires user to type the item's exact SKU (case-sensitive match to displayed SKU) to enable the `Confirm Delete` action.
   - Cancel action leaves all records completely untouched.
   - Double-submit protection prevents duplicate deletion requests.
3. **Step 2: 60-Second Pending Deletion State:**
   - Item is marked pending deletion with metadata: `itemId`, `initiatedByUserId`, `requestedAt`, `undoDeadline = requestedAt + 60s`, `status = pending`.
   - **Active Listing Exclusion:** Pending items are hidden from standard active inventory workspace queries (`getItems`).
   - **Discoverability:** Pending deletions are exposed via a dedicated UI view/banner in the Inventory workspace with remaining countdown.
   - **Mutation Prohibition:** While pending deletion, the item cannot be edited, adjusted, given opening stock, deleted again, or updated via import.
   - **Integrity Preservation:** Item entity and all associated stock movements remain completely intact during the pending window.
4. **Step 3: 60-Second Undo Window:**
   - Undo is accessible throughout the 60-second window even if the user navigates away.
   - Undo deadline is authoritative (based on injected clock / server timestamp; UI countdown is display-only).
   - Who can undo: The original initiating user (if still authorized) or an Admin.
   - When Undo is executed:
     - Pending deletion is cancelled.
     - Item is restored to the active inventory listing.
     - Original item ID, SKU, movement history, and derived quantity are completely preserved without recreating or appending records.
     - Repeated undo calls are safe / idempotent.
5. **Step 4: Permanent Finalization:**
   - After the 60-second deadline expires, permanent deletion becomes eligible for finalization.
   - Repository/backend verifies that pending state is valid, deadline has passed, and undo was not executed.
   - Atomically deletes the `InventoryItem` and all associated `StockMovement` records (opening stock, adjustments).
   - Leaves NO orphan movements or partial records.
   - Deleted item ID is permanently retired and never reused.
   - Undo attempted after finalization fails cleanly.
6. **Step 5: Cross-Module Reference Protection:**
   - Before entering pending deletion and before finalization, repository checks for external business references (e.g., Purchase orders, Dispatch records).
   - If active external references exist, deletion is blocked with a safe explanation, and the item and movements are fully preserved.

---

### 12.6 Import Format-Specific Permissions
- CSV Import requires: `CrmModule.inventory` + `inventory.view` + `inventory.import.csv` (or Admin).
- XLSX Import requires: `CrmModule.inventory` + `inventory.view` + `inventory.import.xlsx` (or Admin).
- A CSV-only user attempting XLSX import or direct route navigation is blocked at both UI and file-picker/parser boundaries.
- A user with import permission but without `inventory.create` can perform import of their authorized format (import and create permissions are decoupled).
- Existing INVENTORY-4 import invariants remain strictly intact (create-only, row atomicity, SKU duplicate rejection, opening stock creates `openingStock` movement with `reason = null` and `CurrentUser.id` actor).

---

### 12.7 Mock Architecture & Backend Reliability Boundary
- **Mock Implementation:**
  - Uses an injected deterministic clock (`_nowProvider`) for deadline calculation and movement timestamps.
  - Stores pending deletion records separately from active items.
  - Supports manual/testable finalization reconciliation (`finalizeExpiredDeletions`).
  - Enforces atomic removal of item and movements on finalization.
- **Production Backend Invariant (Future):**
  - Durable scheduling, background worker expiration, cross-process concurrency safety, and transaction atomicity are server-side responsibilities.
  - Audit receipt on deletion: Minimal event receipt (`deletedItemId`, `initiatedByUserId`, `finalizedAt`, `numberOfMovementsDeleted`) recommended; no movement ledger contents retained.

---

### 12.8 Explicitly Deferred Features
- Stock Movement History / Audit UI (scheduled for INVENTORY-5).
- Inventory Export (CSV / XLSX).
- Multiple warehouses / locations / rack / bin tracking.
- Category / UOM / Description / Pricing / Tax / GST / HSN / Vendor relationships.
- Purchase and Dispatch transaction integration.
- Production backend API integration.

---

# 13. INVENTORY-ACCESS-2 — Stock Quantity Permissions & Atomic Target-Based Adjustment

**Date:** 2026-09-27  
**Status:** REQUIREMENTS FROZEN

## 13.1 Canonical Stock Management Permission
- **Permission Identifier:** `inventory.stock.manage`
- **Constant:** `CrmPermissions.inventoryStockManage`
- **Owning Module:** `CrmModule.inventory`
- **Presentation Display Name:** `Manage Stock Quantity`
- **Description:** `Allows setting opening stock and adjusting the quantity of existing Inventory items.`
- **Users & Access Integration:**
  - Admin navigates to `Admin` -> `Users & Access` -> `Edit User` -> `Inventory Permissions`.
  - Displays checkbox: `[ ] Manage Stock Quantity`.
  - Persisted through standard `UpdateManagedUserInput` and validated via `MockPermissionCatalog`.
  - Master Administrator retains full access automatically.
  - Effective authorization must be rechecked at mutation time; revoking permission blocks subsequent writes immediately even if screen remains open.

## 13.2 Updated Inventory Permission Matrix
| Permission | Scope & Capability |
|---|---|
| `inventory.view` | View Inventory workspace, item list, item details, and derived stock quantities. |
| `inventory.create` | Create new Inventory items (Item Name, SKU). Does NOT authorize setting initial stock unless combined with `inventory.stock.manage`. |
| `inventory.edit` | Edit Item Name and SKU of existing items. Does NOT authorize quantity changes. |
| `inventory.stock.manage` | Set Opening Stock on uninitialized items and adjust quantity on existing items. Authorizes nonblank opening stock on item creation and file import. |
| `inventory.delete` | Initiate confirmed deletion dialog with exact SKU entry and 60-second Undo window. |
| `inventory.import.csv` | Import inventory items from CSV files. |
| `inventory.import.xlsx` | Import inventory items from Excel (XLSX) files. |

- **Admin Account:** Possesses full, unrestricted access to all operations automatically.
- **Standard Users:** Must have module assignment `CrmModule.inventory` + `inventory.view` + specific operational permission for each action.

## 13.3 Opening Stock on Create Item (Authorization Rules)
- **Admin:** May supply optional positive opening stock.
- **Standard User with Create Only (`inventory.create` without `inventory.stock.manage`):**
  - May create Item Name and SKU.
  - Opening stock input field is hidden or disabled in UI.
  - Repository strictly rejects any non-null `openingStock` input if the actor lacks `inventory.stock.manage`, throwing `InventoryAuthorizationException`.
- **Standard User with Create + Stock Management (`inventory.create` + `inventory.stock.manage`):**
  - May enter optional positive opening stock.
- **Atomicity & History:**
  - Blank input creates item with 0 movements (derived quantity `0.0`).
  - Positive finite value creates item and 1 `openingStock` movement atomically.

## 13.4 Target-Based Quantity Adjustment Workflow
- **Screen Access:** `AdjustInventoryStockScreen` is accessible to Admin and Standard Users with `CrmModule.inventory` + `inventory.view` + `inventory.stock.manage`.
- **Ledger Invariant:** Inventory quantities are NEVER directly overwritten. All balance changes are computed via `SUM(StockMovement.quantityDelta)`.
- **Target Quantity Semantics:**
  - Authorized user inputs `targetQuantity` and a mandatory trimmed `reason`.
  - Target quantity must be numeric, finite, and `>= 0`. Negative target quantities are prohibited.
  - If `targetQuantity == currentDerivedBalance`, no movement is appended. A user-friendly message is returned: `"The stock quantity is already at this value."`
- **Write-Time Atomic Delta Calculation (Concurrency / Stale Balance Protection):**
  - Client UI displays current quantity and pre-calculates an adjustment preview delta (`target - displayedQuantity`).
  - Repository/service method executes an atomic mutation:
    1. Fetches authoritative latest movement history and calculates latest derived balance.
    2. Calculates write-time delta: `delta = targetQuantity - latestBalance`.
    3. If `latestBalance + delta < 0`, operation is rejected.
    4. If `delta == 0.0`, returns current derived quantity without appending a movement.
    5. Appends a single signed `StockMovementType.adjustment` movement with `quantityDelta = delta`, `reason`, `performedByUserId = CurrentUser.id`, and injected timestamp.
    6. Returns the updated authoritative balance.
- **Uninitialized vs Initialized Items:**
  - Uninitialized items (0 movements) require `Set Opening Stock` (`quantity > 0`).
  - Initialized items (1+ movements, even if balance is `0.0`) must use `Adjust Stock`.

## 13.5 Inventory File Import Authorization Update
- CSV Import requires: `inventory.import.csv` + `inventory.view` + `CrmModule.inventory`.
- XLSX Import requires: `inventory.import.xlsx` + `inventory.view` + `CrmModule.inventory`.
- Importing nonblank Opening Stock additionally requires: `inventory.stock.manage`.
- **User Without Stock Management:**
  - Name and SKU are parsed and imported normally.
  - Blank or unmapped Opening Stock is permitted.
  - Rows with nonblank supplied opening stock are rejected with row-level error: `"Stock Management permission (inventory.stock.manage) required to import initial quantity."`
  - Values are never silently discarded.
- **User With Stock Management (or Admin):**
  - Authorized to import positive opening stock rows, creating atomic `openingStock` movements.


