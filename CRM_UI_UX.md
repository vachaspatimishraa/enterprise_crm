# CRM UI/UX Specification

**Version:** Draft 1.1  
**Platforms:** Flutter Android and responsive Web

## 1. Design principles

The interface should feel like a practical office system: clear navigation, readable tables, short forms, visible text-based statuses, and confirmation before important changes. Use consistent labels, accessible contrast, touch-friendly controls, inline validation, and useful success/error messages.

## 2. Responsive behaviour

Phone: one-column forms, cards, compact lists, drawer/bottom navigation, and bottom sheets. Tablet: two-column forms where possible. Desktop Web: sidebar, dashboard grids, full tables, split details, dialogs, and permission matrices. Tables become cards or horizontal scroll sections on narrow screens.

## 3. Access and navigation

There is no Register, department-request, or self-approval screen. The public flow is Splash → Login → authorized Dashboard. Only the Administrator sees User Management and Create User.

Navigation is generated from returned permissions. Common items are Dashboard, Notifications, Profile, and Logout. The Administrator sees every module plus user management, roles/permissions, reports, and settings. Direct URLs must still be protected.

## 4. Screen inventory

| Area | Proposed screens |
|---|---|
| Auth | Splash, Login, Forgot Password if supported, Disabled Account/Help |
| Common | Dashboard, Notifications, Profile, Settings |
| Leads | Lead List, Add/Edit Lead, Import Preview, Lead Details/History, Assignment |
| Calling | Calling Dashboard, Assigned Calls, Call Update, Reschedule/Follow-up |
| Inventory | Inventory Dashboard, Product List, Product Form, Stock Movement, Reports |
| Dispatch | Dispatch List, Dispatch Details, Create Dispatch, Invoice/Builty Details |
| Purchase | Purchase Dashboard, Material Requirement, RFQ/Quotation, PI/PO, Recurring PO/Fulfilment |
| HR/Payroll | Employee List, Employee Details/Form, Documents, Attendance, KPI/Payroll |
| Approvals | Approval Inbox, Approval Details, Approval History, Notification Centre |
| Vendor | Vendor List, Registration/Edit, Details/KYC, Documents, Orders/History |
| Admin | User List, Create/Edit User, User Details, Roles/Modules, Permission Matrix, Reports |

Some items can be tabs, dialogs, or side panels rather than separate routes.

## 5. Account creation flow

```text
Administrator → User Management → Create User
→ enter details → assign role/modules/permissions → save account
→ securely share credentials

User → Login → authorized Dashboard
```

The Create User screen should allow the Administrator to assign one or more modules and view/add/edit/delete/approve/export/upload permissions. The Administrator can later edit, disable, reset, or change access. Credentials must not be publicly displayed. The exact delivery/reset method depends on the backend.

## 6. Module screens and key components

**Lead Management:** Lead table/cards, search, status/source/assignee filters, Add Lead, Import, Export, bulk assignment, lead form, import column mapping, row validation, duplicate warnings, detail history, and calling actions. Sources are Manual, Excel, or CSV.

**Calling:** Assigned-call list, assigned/connected summary cards, status selector, notes, next follow-up date/time, and reschedule form. Use the exact instructor statuses: Follow up, Not connected, Visit scheduled, Irrelevant, Not interested, Lead closed, Sales done, Dispatched.

**Inventory:** Item list, stock cards, low-stock indicator, product form, stock in/out/adjustment form, movement history, and report filters.

**Dispatch:** Dispatch list, create form, customer/invoice/receipt section, vehicle details, items, Builty, dispatch date/status, documents, and final invoice.

**Purchase:** Purchase dashboard and a visible sequence of material requirement → RFQ → quotation → PI/PO → approval → fulfilment. Recurring PO appears only if confirmed.

**HR/Payroll:** Employee list/details, employee form, document section, attendance list/calendar, KPI view, and payroll summary. Payroll calculation is labelled pending until rules are confirmed.

**Approvals/Notifications:** Approval inbox with pending/approved/rejected tabs, detail with comments/attachments, history, unread notifications, timestamps, and deep links when supported.

**Vendor:** Vendor list, registration/edit, details, KYC/banking documents, orders, tracking, and order history. Vendor login is pending confirmation.

**Admin:** User list, Create User form, account status, assigned modules, permission matrix, edit/disable/reset actions, and audit/report views if supported.

## 7. Common states and interactions

Every list and form needs loading, empty, error/retry, success, validation, forbidden, and disabled-account states. Forms should show required fields, preserve entered data on recoverable errors, warn about unsaved changes, and confirm delete/disable actions. Filters should be visible and preserved when returning from details.

## 8. Key flows

**Sales:** Dashboard → Leads → lead details → call/update status → schedule follow-up → Sales done → dispatch hand-off.

**Import:** Leads → Import → choose Excel/CSV → map/check columns → review errors/duplicates → submit → summary → lead list.

**Administrator:** User Management → Create User → details → permissions → save → securely share credentials; later edit, disable, reset, or change access.

**Purchase:** Purchase → requirement → RFQ → vendor quotation → PI/PO → approval → fulfilment.

## 9. Accessibility and open decisions

Use readable text, contrast, visible Web focus, keyboard support, large touch targets, labels, and status text/icons rather than colour alone. Confirm final roles, user fields, credential delivery/reset, report layouts, vendor login, document preview, language, and whether calling opens the device dialler or only records activity.
