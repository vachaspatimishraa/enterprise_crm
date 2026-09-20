# CRM Technical Requirements Document

**Version:** Draft 1.1  
**Frontend:** Flutter Android + responsive Web  
**Backend:** Instructor-provided REST API

## 1. Architecture

```text
Flutter UI → BLoC/Cubit → Repository → Dio data source → Instructor API
```

Use a feature-first structure:

```text
lib/core/{theme,routing,network,storage,permissions,widgets}
lib/features/{auth,dashboard,leads,calling,inventory,dispatch,purchase,hr,approvals,notifications,vendor}
```

Each feature can contain presentation, bloc/cubit, models, repository, and remote data-source code. UI widgets must not call Dio directly.

## 2. State and networking

Use Cubit for simple screens and BLoC for event-heavy workflows. States should include initial, loading, success, empty, validation failure, forbidden, unauthenticated, and error. Configure Dio with base URL, timeouts, JSON handling, authentication interceptors, refresh/logout handling if supported, and development-only logging. Never log passwords, tokens, or sensitive documents.

## 3. Authentication and permissions

There is no public registration flow. Only the Administrator creates, activates, edits, disables, and resets users through the admin interface. Users log in with credentials supplied by the Administrator. Support session restoration, logout, disabled-account handling, and password change/reset if the backend provides it.

The backend should return user status, roles/modules, and granular permissions such as `leads.view`, `leads.create`, `leads.edit`, `leads.delete`, `leads.approve`, `leads.export`, and `leads.upload`. The frontend hides unauthorized navigation and handles server-side 401/403 responses. The backend remains the authority.

## 4. Responsive strategy

Use the same widgets, routes, repositories, and state logic on both platforms. Phone layouts use cards, compact forms, drawers/bottom sheets, and quick updates. Web layouts use a sidebar, wider tables, split details, dashboards, and permission matrices. Test phone, tablet, and desktop widths.

## 5. Features

Implement the eight PRD modules with permission-aware list/detail/form screens. Calling must support the instructor's statuses and rescheduling. Purchase must represent RFQ, quotations, PI/PO, approval, and fulfilment. Dispatch must represent invoice, customer, vehicle, Builty, and final invoice. HR, vendor, inventory, approvals, notifications, and leads follow the PRD.

## 6. Excel/CSV and files

Lead import: choose file → check extension/size → map columns if required → validate rows → show valid/invalid/duplicate results → submit → show summary. Export should respect filters and permissions. No Meta, Google Ads, Facebook API, webhook, or funnel-sync code is required. Confirm backend upload formats, limits, storage, download URLs, document preview, and scanning for KYC, banking, employee, invoice, quotation, and other files.

## 7. Errors, security, and testing

Map timeout, offline, validation, authentication expiry, forbidden, server, and malformed-response errors to readable messages with retry where useful. Use HTTPS, secure token storage, least privilege, server-side authorization, safe file handling, and no embedded secrets.

Test models, validators, permissions, Cubits/BLoCs, repositories with mocked Dio, forms, responsive layouts, imports with bad rows, empty/error states, disabled login, and unauthorized actions. Add integration/manual tests against the instructor's test API.

## 8. Environments and backend dependency

Keep separate development/test/production API configuration. The instructor must provide base URLs, API documentation, credentials, CORS/Web support, authentication and refresh rules, user creation/management endpoints, permission payloads, all module endpoints, pagination/filter format, import/export, uploads, reports, notifications, audit history, and error schema. Final deployment may produce an Android APK/AAB and Flutter Web build; CI/CD is proposed only.
