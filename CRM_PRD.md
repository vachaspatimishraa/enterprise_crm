# CRM Product Requirements Document

**Version:** Draft 1.1  
**Platforms:** Android and responsive Web using Flutter

## 1. Purpose

This CRM manages customer leads, calling, inventory, dispatch, purchase, HR/Payroll, approvals/notifications, and vendors in one system.

## 2. Requirement status

### Confirmed instructor requirements

The eight modules are Lead Management, Calling, Inventory, Dispatch, Purchase, HR/Payroll, Approval/Notifications, and Vendor Management. The requirements cover lead upload/display/export, calling status and rescheduling, stock and inventory reports, dispatch invoice/vehicle/Builty details, RFQ/quotations/PI/PO and fulfilment, employees/documents/attendance/KPI, approvals and notifications, and vendor registration/KYC/banking documents/order history.

### Final project decisions

- The instructor provides the backend; we do not invent a replacement backend.
- Frontend: Flutter Android and responsive Web from one codebase.
- State management: BLoC/Cubit. REST integration: Dio.
- Leads come only from manual/custom entry and Excel/CSV import. Meta, Google Ads, Facebook lead APIs, webhooks, and other funnel integrations are excluded.
- Excel/CSV export and custom reports are included where appropriate and supported.
- Users cannot create accounts themselves. Only the Administrator can create, activate, disable, and edit accounts and assign access. Users only log in with administrator-provided credentials.
- Permissions support multiple modules and granular view/add/edit/delete/approve/export/upload rights. Administrator sees all modules.

### Proposed or pending

Confirm exact job roles, department names, module fields, statuses, report formats, document rules, notification method, and the backend's support for configurable permissions, uploads, exports, and audit history.

## 3. Goals and scope

Goals are to organize business records, track sales follow-ups, control departmental access, support spreadsheet workflows, and provide useful reports on Android and Web.

In scope: administrator-created accounts, login/session handling, RBAC, dashboards, all eight modules, manual lead entry, Excel/CSV import/export, reports, uploads where supported, search, filters, pagination, validation, and responsive layouts.

Out of scope: Meta/Google/advertising funnel integrations, external lead synchronization, telephony integration, payment gateway, and building a replacement backend. Detailed payroll calculations and offline mode need confirmation.

## 4. Users and access

| User | Access |
|---|---|
| Administrator | All modules, user creation, permissions, reports and settings |
| Sales | Approved Lead Management and Calling access |
| Inventory/Dispatch/Purchase/HR | Approved access to their assigned module(s) |
| Approver/Manager | Approved approval and departmental access |
| Vendor | Vendor access only if confirmed |

## 5. Main workflows

### Account workflow

Administrator creates account → assigns role/modules/permissions → securely gives credentials → user logs in → only approved modules/actions appear. A disabled or invalid account cannot enter the system.

### Lead-to-dispatch workflow

Manual entry or Excel/CSV import → validation → assignment → calling/follow-up → Sales done → inventory or purchase as needed → dispatch → final status/report.

### Purchase workflow

Material requirement → RFQ → vendor quotation → PI/PO → approval → fulfilment tracking → inventory update.

## 6. Module requirements

**Lead Management:** Manual add, Excel/CSV import, validation, duplicate handling, assignment, search/filter, history, customized display, and Excel/CSV export.

**Calling:** Assigned calls, connected-call totals, notes, exact statuses (Follow up, Not connected, Visit scheduled, Irrelevant, Not interested, Lead closed, Sales done, Dispatched), and date/time rescheduling.

**Inventory:** Products/items, current stock, stock movements, minimum/low-stock awareness, and reports.

**Dispatch:** Customer, invoice/receipt, vehicle, Builty, items, dispatch status, and final invoice.

**Purchase:** Material requirement, RFQ, quotation, PI/PO, recurring PO if confirmed, approval, and fulfilment.

**HR/Payroll:** Employee records, documents, attendance, KPI, and payroll view/calculation only as confirmed.

**Approval/Notifications:** Pending approvals, comments, approval history, PI/PO approval, and departmental notifications.

**Vendor:** Registration, KYC/banking documents, vendor orders/PO tracking, and order history. Vendor login is pending confirmation.

## 7. Functional and non-functional requirements

The app must authenticate users, maintain sessions, enforce server-side permissions, validate forms, support search/filter/pagination, show import results, respect permissions during export, and provide loading, empty, success, error, forbidden, and disabled-account states. It should be responsive, secure over HTTPS, readable, accessible, and maintainable.

## 8. Acceptance criteria

The Administrator can create and manage accounts; a created user can log in; only assigned modules/actions are visible; all eight modules have usable planned flows; leads support manual and Excel/CSV input; calling statuses and rescheduling work; reports and permissions behave correctly; Android and Web layouts are usable; and the frontend integrates with the instructor's documented APIs.

## 9. Backend confirmations needed

Obtain API documentation/Swagger, base URL, authentication, user-management endpoints, credential reset/delivery rules, roles and permissions, pagination, uploads/downloads, import/export, reports, notifications, audit history, error format, CORS, and test credentials. This PRD does not invent the actual database or API.
