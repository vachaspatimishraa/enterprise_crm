# CRM Project Master Phases

## Purpose

This document is the master development roadmap for the CRM project.

It is intended to be shared with both **Codex** and **Antigravity** so both agents follow the same project order, architecture, feature boundaries, and implementation rules.

---

# Project Decisions to Follow

## Frontend

- Flutter
- Android + responsive Web from the same Flutter project
- BLoC / Cubit for state management
- Dio for backend/API integration
- Feature-first architecture
- Reusable responsive components
- Role/permission based navigation

## Backend

- Backend will be provided and integrated by the instructor through GitHub.
- Do not create a separate Supabase/Firebase/custom backend unless specifically requested.
- Frontend code must remain separated from backend-specific implementation through repositories/services.
- Do not invent API endpoints, database fields, request/response formats, or authentication behavior unless they are documented by the instructor/backend.
- Temporary/mock repositories may be used before backend integration if needed.

## Lead Sources

Lead intake will use only:

- Manual/custom data entry
- Excel import
- CSV import

Do **not** implement:

- Meta/Facebook lead integration
- Google Ads integration
- External advertising funnels
- External lead funnel webhooks

## Access Control

Proposed account flow:

```text
Register
   ↓
Select / Request Department or Role
   ↓
Submit Registration
   ↓
Account Status = Pending
   ↓
Administrator Reviews
   ↓
Approve / Reject
   ↓
Role + Module Permissions Assigned
   ↓
User Can Access Only Authorized Modules
```

The Administrator can access all modules.

The permission system should support flexible access rather than hard-coding one user to one module.

Possible permissions:

- View
- Add
- Edit
- Delete
- Approve
- Upload
- Export

A user may receive access to more than one module if allowed by the Administrator/backend.

---

# Main CRM Modules

1. Lead Management
2. Calling
3. Inventory
4. Dispatch
5. Purchase
6. HR / Payroll
7. Approvals & Notifications
8. Vendor Management

Common functionality includes authentication, role/module access, dashboard, search/filter/sort, file/document handling, Excel/CSV import and export, customized reports, notifications, audit/history where supported, and responsive Android/Web UI.

---

# Phase 0 — Requirements and Documentation

## Goal

Freeze the project scope before major implementation begins.

## Documents

- `CRM_PRD.md`
- `CRM_TRD.md`
- `CRM_UI_UX.md`
- `CRM_Backend_Schema.md`
- `AI_CO_DEVELOPMENT_RULES.md`
- `CRM_PROJECT_PHASES.md`

## Tasks

- Separate instructor-provided requirements from our proposed implementation decisions.
- Confirm project modules.
- Confirm lead intake through manual/custom + Excel/CSV only.
- Document the proposed user registration and Admin approval flow.
- Document role/module permissions.
- Document responsive Android/Web requirement.
- Document instructor-provided backend constraint.
- Identify unresolved instructor/backend questions.

## Expected Result

A frozen project foundation that both coding agents can follow.

## Completion Rule

Do not start large feature implementation while core requirements and architecture are still changing.

---

# Phase 1 — Flutter Project Foundation

## Goal

Create a stable technical foundation before CRM features are implemented.

## Suggested Structure

```text
lib/
├── app/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   ├── routing/
│   ├── theme/
│   └── utils/
├── shared/
│   ├── responsive/
│   └── widgets/
└── features/
```

## Tasks

- Establish folder architecture.
- Configure Flutter project for Android and Web.
- Create app theme.
- Create responsive layout helpers.
- Create routing/navigation foundation.
- Create BLoC/Cubit conventions.
- Create error/result handling conventions.
- Create Dio/client foundation if backend details are known.
- Create reusable form, button, dialog, loading, error and empty-state components.
- Add common constants and utilities.
- Ensure no feature contains direct backend calls from widgets.

## Expected Result

The app opens successfully on Android and Web and supports placeholder routes/screens without architecture conflicts.

## Exit Criteria

- Android build works.
- Web build works.
- `flutter analyze` has no critical errors.
- Shared architecture is ready for Auth and CRM modules.

---

# Phase 2 — Authentication and Account Request

## Goal

Build the frontend account flow.

## Main Screens

- Splash
- Login
- Register
- Request Department / Role
- Registration Submitted
- Pending Approval
- Rejected Account
- Disabled Account

## Proposed Account Statuses

```text
pending
active
rejected
disabled
```

## Tasks

- Build login UI.
- Build registration UI.
- Add validation.
- Add requested role/department selection.
- Add pending approval state.
- Add rejected/disabled states.
- Prepare state management.
- Keep backend calls behind repository/service interfaces.
- Use mock state only if backend is not yet available.

## Expected Result

A complete authentication UI flow that can later be connected to the instructor backend.

---

# Phase 3 — Admin, Roles and Permissions

## Goal

Create the frontend for user approval and role/module access.

## Proposed Admin Flow

```text
Pending User
     ↓
Admin Opens Request
     ↓
Approve / Reject
     ↓
Assign Role
     ↓
Assign Modules
     ↓
Assign Permissions
     ↓
Activate User
```

## Tasks

- Pending user list.
- User request details.
- Approve registration.
- Reject registration.
- Disable/enable account if supported.
- Assign role/department.
- Assign module access.
- Assign granular permissions where backend supports them.
- View existing users.
- Edit access/permissions.
- Hide unauthorized modules in frontend navigation.

## Important Rule

Frontend visibility is **not** a substitute for backend authorization. The backend must still enforce access rules.

## Expected Result

Users see only modules they are allowed to access. Administrator sees all modules.

---

# Phase 4 — Dashboard and Main CRM Shell

## Goal

Build the main role-aware CRM shell.

## Web Layout

```text
┌──────────────┬────────────────────────────┐
│ Sidebar      │                            │
│ Dashboard    │        Main Content        │
│ Leads        │                            │
│ Calling      │                            │
│ Inventory    │                            │
│ ...          │                            │
└──────────────┴────────────────────────────┘
```

## Android Layout

```text
App Bar
────────────
Main Content
────────────
Bottom Navigation / Drawer
```

## Tasks

- Main app shell.
- Role/module based menu.
- Administrator dashboard.
- Role-specific dashboard placeholders.
- Profile.
- Logout.
- Settings if needed.
- Notifications entry point.
- Responsive navigation behavior.
- Permission-denied state.

## Expected Result

The application shell is stable and modules can be plugged into it without rewriting navigation.

---

# Phase 5 — Lead Management

## Goal

Implement the first main business module.

## Lead Intake

Supported:

```text
Manual Entry
Excel Import
CSV Import
```

Not supported:

```text
Meta Ads
Google Ads
External Lead Funnels
```

## Main Screens / Areas

- Lead Dashboard
- Lead List
- Lead Details
- Add Lead
- Edit Lead
- Assign Lead
- Reassign Lead
- Excel/CSV Import
- Search and Filters
- Lead History
- Export

## Tasks

- Manual lead creation.
- Edit lead.
- Lead list.
- Lead details.
- Assignment/reassignment.
- Excel import UI.
- CSV import UI.
- Import validation/results.
- Duplicate-handling UI according to backend rules.
- Search/filter/sort.
- Export.
- Role/permission checks.
- Lead history if backend supports it.

## Expected Result

Sales/Admin users can manage leads according to their permissions.

---

# Phase 6 — Calling and Follow-Up

## Goal

Connect leads to the sales calling/follow-up workflow.

## Required Call Statuses

- Follow up
- Not connected
- Visit scheduled
- Irrelevant
- Not interested
- Lead closed
- Sales done
- Dispatched

## Main Screens / Areas

- Calling Dashboard
- Assigned Calls / Leads
- Connected Calls
- Call Details
- Update Call Status
- Follow-Up
- Reschedule Call
- Call History

## Workflow

```text
Lead
 ↓
Assigned Agent
 ↓
Call
 ↓
Result / Status
 ↓
Follow-Up / Visit / Closed / Sale
```

## Tasks

- Total assigned calls/leads.
- Connected-call count.
- Update call status.
- Add date/time for rescheduled calls.
- Follow-up UI.
- Call notes/history if supported.
- Reminder UI if supported by backend.
- Link calling records to lead details.

## Expected Result

Sales users can track calling activity and lead progression.

---

# Phase 7 — Inventory

## Goal

Implement live stock and inventory management.

## Main Screens / Areas

- Inventory Dashboard
- Stock List
- Item Details
- Add Item
- Edit Item
- Stock Adjustment
- Low Stock
- Inventory History
- Reports

## Workflow

```text
Inventory Item
      ↓
Current Stock
      ↓
Stock Movement
      ↓
Minimum Stock Check
      ↓
Low Stock Alert
```

## Tasks

- Display live stock.
- Add/update/delete inventory where permitted.
- Minimum-stock configuration if backend supports it.
- Low-stock alert UI.
- Stock history.
- Search/filter/sort.
- Reports: Daily, Weekly, Monthly, Quarterly, Half-yearly, Yearly.
- Excel/CSV export where required.

## Expected Result

Authorized users can manage stock and monitor low-stock conditions.

---

# Phase 8 — Dispatch

## Goal

Build the product/order dispatch workflow.

## Main Screens / Areas

- Dispatch Dashboard
- Dispatch List
- Dispatch Details
- Invoice Receiving
- Customer Details
- Vehicle Details
- Builty Details
- Final Invoice Upload
- Dispatch Status

## Workflow

```text
Sale / Order
      ↓
Invoice Received
      ↓
Customer Details
      ↓
Vehicle Details
      ↓
Builty Details
      ↓
Dispatch
      ↓
Final Invoice
```

## Tasks

- Invoice receiving UI.
- Customer information.
- Vehicle information.
- Builty information.
- Final invoice upload.
- Dispatch details/status.
- Link dispatch to related order/sale/inventory if backend supports it.
- File upload states.
- Permission checks.

## Expected Result

Dispatch users can manage the required dispatch information and final invoice process.

---

# Phase 9 — Purchase

## Goal

Implement purchase, RFQ, quotations and PO workflows.

## Main Screens / Areas

- Purchase Dashboard
- Material Requirements
- RFQ List
- RFQ Details
- Quotations
- Quotation Comparison
- PO List
- PO Details
- Create/Edit PO
- Recurring PO
- Fulfillment Status

## Main Workflow

```text
Material Requirement
        ↓
       RFQ
        ↓
Quotation 1
Quotation 2
Quotation 3
        ↓
Comparison
        ↓
Vendor Selection
        ↓
PO
        ↓
Approval
        ↓
Fulfillment
```

## Tasks

- Material Requirement display.
- RFQ workflow.
- Quotation uploads.
- Minimum-three-quotation rule if confirmed by backend/business rules.
- Quotation comparison UI.
- New PO.
- Recurring PO.
- PO update/delete if allowed.
- Fulfillment status.
- Export/reporting.

## Expected Result

Purchase users can follow the complete material requirement → quotation → PO workflow.

---

# Phase 10 — HR / Payroll

## Goal

Implement the employee lifecycle and confirmed HR functionality.

## Main Screens / Areas

- HR Dashboard
- Employee List
- Employee Details
- Add/Edit Employee
- Employee Documents
- Attendance
- Attendance Import/Upload
- KPI
- Employee Exit
- Payroll screens only if confirmed

## Main Workflow

```text
Employee Enrollment
       ↓
Employee Profile
       ↓
Documents
       ↓
Attendance
       ↓
KPI
       ↓
Employee Lifecycle
       ↓
Exit Formalities
```

## Tasks

- Employee enrollment.
- Employee profile.
- Employee add/update/delete where allowed.
- Employee document upload/display.
- Attendance capture/upload.
- KPI display/management.
- Exit formalities.
- Payroll features only after exact requirements are confirmed.
- Permission rules for sensitive HR data.

## Expected Result

HR users can manage employee lifecycle features required by the project.

---

# Phase 11 — Approvals and Notifications

## Goal

Build cross-department approval and notification workflows.

## Main Areas

- Approval Inbox
- Approval Details
- PI Approval
- PO Approval
- Other Approval Types
- General Announcements
- Department Notifications
- Notification History

## Example Workflow

```text
Purchase Creates PO
       ↓
Approval Request
       ↓
Approver / Admin
       ↓
Approve / Reject
       ↓
Purchase Receives Result
```

## Tasks

- PI approval.
- PO approval.
- Other necessary approvals.
- Approve/reject/request-changes UI if backend supports it.
- Approval comments/reasons.
- General announcements.
- Department-specific notifications.
- Payment notifications.
- Material-received notifications.
- Read/unread states.
- Android/Web approval access.

## Expected Result

Users receive and act on approval/notification workflows according to permissions.

---

# Phase 12 — Vendor Management

## Goal

Implement vendor registration, verification and order tracking.

## Main Screens / Areas

- Vendor Registration
- Vendor Profile
- KYC
- Banking Details
- Vendor Approval/Verification
- Vendor PO
- Vendor Orders
- Order Tracking
- Previous Orders
- Vendor Reports

## Workflow

```text
Vendor Registration
        ↓
KYC
        ↓
Banking Details
        ↓
Verification
        ↓
Vendor Active
        ↓
PO / Orders
        ↓
Tracking
        ↓
Previous Orders
```

## Tasks

- Vendor account flow if backend supports separate vendor login.
- KYC upload/display.
- Banking details.
- Verification status.
- Vendor-side PO workflow according to backend/business rules.
- Order tracking.
- Previous orders.
- Excel export.
- Customized reports.
- Vendor-only permission boundaries.

## Expected Result

Vendor users can access only their authorized vendor workflows and data.

---

# Phase 13 — Reports, Excel and CSV

## Goal

Standardize reporting/import/export behavior across modules.

## Common Features

- Search
- Filters
- Date Range
- Sort
- Pagination
- Column Selection if supported
- Excel Export
- CSV Export
- Customized Reports

## Tasks

- Standardize export actions.
- Standardize report filters.
- Reusable report UI.
- Reusable date-range selection.
- Permission checks for export.
- Filtered-data export if supported.
- Module-specific report formatting.
- Error handling for large exports/imports.

## Expected Result

Reporting/export behavior is consistent across the CRM.

---

# Phase 14 — Instructor Backend Integration

## Goal

Connect the frontend to the instructor-provided backend integrated through GitHub.

## Before Backend Integration

```text
Screen
 ↓
BLoC / Cubit
 ↓
Repository
 ↓
Mock / Temporary Data Source
```

## After Backend Integration

```text
Screen
 ↓
BLoC / Cubit
 ↓
Repository
 ↓
Dio / Backend Service
 ↓
Instructor Backend
 ↓
Database
```

## Tasks

- Inspect backend code/documentation before integration.
- Identify authentication method.
- Map backend models.
- Map backend errors.
- Connect login/registration.
- Connect user/role/permission APIs.
- Connect all module APIs.
- Connect uploads/downloads.
- Connect pagination/filter/search.
- Remove or isolate mock data.
- Validate backend authorization behavior.
- Handle backend-specific error responses.
- Avoid rewriting UI architecture to fit backend implementation details.

## Important Rules

- Do not call backend directly from widgets.
- Do not invent endpoints.
- Do not hard-code undocumented response fields.
- Do not store sensitive tokens insecurely.
- Backend authorization is authoritative.

## Expected Result

All frontend modules use real backend data and behavior.

---

# Phase 15 — Full Integration and Workflow Testing

## Goal

Test the CRM as one connected system instead of isolated modules.

## Workflow 1 — User Access

```text
New User
 ↓
Registration
 ↓
Pending
 ↓
Admin Approval
 ↓
Role / Permissions
 ↓
Authorized Dashboard
```

## Workflow 2 — Sales

```text
Lead Added / Imported
 ↓
Lead Assigned
 ↓
Call
 ↓
Follow-Up
 ↓
Sales Done
 ↓
Dispatch
```

## Workflow 3 — Purchase

```text
Low Stock / Material Requirement
 ↓
RFQ
 ↓
Quotations
 ↓
PO
 ↓
Approval
 ↓
Vendor
 ↓
Material Received
 ↓
Inventory Update
```

## Workflow 4 — Vendor

```text
Vendor Registration
 ↓
KYC / Banking
 ↓
Approval
 ↓
PO / Order
 ↓
Tracking
 ↓
Previous Orders
```

## Tasks

- Test all role restrictions.
- Test unauthorized routes.
- Test module-to-module navigation.
- Test API failures.
- Test form validation.
- Test duplicate submissions.
- Test file uploads.
- Test Excel/CSV import/export.
- Test Android.
- Test Web.
- Test backend data consistency.

## Expected Result

Main CRM workflows operate correctly end-to-end.

---

# Phase 16 — UI Polish, Validation and Optimization

## Goal

Improve quality without adding unnecessary new features.

## Tasks

- Responsive layout fixes.
- Loading states.
- Empty states.
- Error states.
- Offline/network failure states if required.
- Permission-denied states.
- Form validation consistency.
- Duplicate submission protection.
- Visual consistency.
- Accessibility basics.
- Keyboard navigation on Web.
- Performance optimization.
- Pagination optimization.
- Reduce unnecessary rebuilds.
- Remove dead code.
- Resolve analyzer warnings.
- Verify theme consistency.

## Expected Result

A stable release candidate for both Android and Web.

---

# Phase 17 — Final Build and Delivery

## Goal

Prepare the project for final submission/demo.

## Tasks

- Run `flutter analyze`.
- Run tests.
- Test all supported user roles.
- Test permissions.
- Prepare Android build.
- Prepare Web build.
- Verify backend environment/configuration.
- Prepare demo accounts.
- Prepare sample data.
- Verify Excel/CSV workflow.
- Verify document uploads.
- Clean Git working tree.
- Remove test/debug-only code.
- Update documentation.
- Prepare presentation/demo steps.
- Create final release/tag if required.

## Suggested Demo Flow

```text
Admin Login
   ↓
Approve New Sales User
   ↓
Assign Sales Permissions
   ↓
Sales User Login
   ↓
Create / Import Leads
   ↓
Assign Lead
   ↓
Calling / Follow-Up
   ↓
Sales Done
   ↓
Inventory / Purchase
   ↓
Approval
   ↓
Vendor
   ↓
Dispatch
   ↓
Reports / Export
```

## Expected Result

Final project ready for instructor evaluation.

---

# Master Progression

```text
PHASE 0  — Documentation
      ↓
PHASE 1  — Foundation
      ↓
PHASE 2  — Authentication
      ↓
PHASE 3  — Admin / RBAC
      ↓
PHASE 4  — Dashboard / Shell
      ↓
PHASE 5  — Lead Management
      ↓
PHASE 6  — Calling
      ↓
PHASE 7  — Inventory
      ↓
PHASE 8  — Dispatch
      ↓
PHASE 9  — Purchase
      ↓
PHASE 10 — HR / Payroll
      ↓
PHASE 11 — Approvals / Notifications
      ↓
PHASE 12 — Vendor
      ↓
PHASE 13 — Reports / Excel / CSV
      ↓
PHASE 14 — Backend Integration
      ↓
PHASE 15 — Workflow Testing
      ↓
PHASE 16 — Polish
      ↓
PHASE 17 — Final Delivery
```

---

# Codex + Antigravity Collaboration Rules

Both agents may be used throughout the project, but they must never blindly work on the same files.

## Before Starting Any Task

Each agent must:

1. Check `git status`.
2. Inspect the current project structure.
3. Read the target files before modifying them.
4. Check current task/file ownership.
5. Report which files it plans to read, create, and modify.
6. Avoid files owned by the other agent.
7. Avoid unrelated refactoring.

## During Work

- Keep edits small and scoped.
- Prefer surgical changes over whole-file replacement.
- Preserve existing architecture and naming.
- Do not delete/rename shared files without explicit approval.
- Do not alter another agent's in-progress feature.
- If a cross-owned change is necessary, report it instead of making it.
- Do not invent backend behavior.

## After Work

Each agent must report:

- Files created.
- Files modified.
- Files deleted, if explicitly approved.
- Main implementation completed.
- Tests/analyzer run.
- Any unresolved errors.
- Any collision risk.
- Any change required from the other agent.

Then re-check `git status`.

---

# Recommended Per-Phase Ownership Pattern

Avoid giving both agents the same feature files.

Example:

```text
PHASE 5 — LEAD MANAGEMENT

Codex
Task:
- Lead domain/data/state implementation

Owns:
- lib/features/leads/data/
- lib/features/leads/domain/
- lib/features/leads/bloc/

Antigravity
Task:
- Lead screens and responsive UI

Owns:
- lib/features/leads/presentation/
- explicitly assigned shared widgets only

Shared Files:
- Locked unless explicitly assigned
```

Another valid split is by complete feature:

```text
Codex:
- Lead Management
- Calling

Antigravity:
- Inventory
- Dispatch
```

Use whichever ownership strategy minimizes shared-file edits.

---

# Reusable Agent Assignment Template

Use this before assigning work to either agent:

```md
## Agent Assignment

**Agent:** Codex / Antigravity

**Phase:** Phase X — Name

**Task:**
Describe the exact task.

**Owns:**
- path/to/folder/
- path/to/file.dart

**Must Not Touch:**
- path owned by the other agent
- shared files not explicitly assigned

**Files Planned:**
- Read:
- Create:
- Modify:

**Required Checks Before Work:**
- `git status`
- Inspect current implementation
- Confirm no conflicting edits

**Status:**
Not Started / In Progress / Blocked / Complete

**Notes:**
Any important constraints or backend/UI requirements.
```

---

# Phase Completion Rule

Do not consider a phase complete only because its screens exist.

A phase is complete when:

- Required UI is implemented.
- State management works.
- Navigation works.
- Permissions are respected.
- Responsive behavior is checked.
- Errors/loading/empty states are handled.
- Analyzer/tests relevant to the phase pass.
- No unresolved file collisions exist.
- Changes are documented.
- The phase is stable enough for the next phase to depend on it.

---

# Final Rule

Follow the project phases in order unless there is a clear dependency reason to work ahead.

Do not make major architectural changes in later phases without reviewing how they affect completed phases.

The goal is to keep the CRM modular so the instructor-provided backend can be integrated without rewriting the entire Flutter frontend.
