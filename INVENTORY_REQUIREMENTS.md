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

