# CRM Backend Schema / Integration Contract

## 1. Purpose of this document

This is a proposed backend schema and integration contract for the CRM project. It is written to explain what data and APIs the Flutter frontend will need when the instructor integrates the backend into the GitHub project.

It is **not** the instructor's actual database schema. The final table names, database technology, authentication method, API URLs, and exact fields must be matched with the backend that the instructor provides.

The frontend plan is:

```text
Flutter UI
   ↓
BLoC / Cubit
   ↓
Repository layer
   ↓
Dio API client
   ↓
Instructor-integrated backend
```

## 2. Scope and confirmed project direction

The backend should support these CRM areas:

- Authentication and User Access
- Lead Management
- Calling
- Inventory
- Dispatch
- Purchase
- HR / Payroll
- Approvals and Notifications
- Vendor Management
- Reports and Exports

The agreed lead-input approach is:

- Manual/custom lead entry
- Excel import
- CSV import
- Excel/CSV export

Meta, Google Ads, Facebook lead APIs, webhooks, and other automatic data-funnel integrations are excluded from this version.

## 3. Access and account flow

The proposed access flow is:

```text
Registration
    ↓
Request department/module and role
    ↓
Account status = pending
    ↓
Administrator reviews request
    ├── Approve → assign role and permissions → active account
    └── Reject  → rejected account with reason
```

A pending account may exist in the system, but it must not access CRM modules. The user should see a clear pending message. The administrator can see all modules and manage users, roles, permissions, approvals, and settings.

The database should not permanently assume that one user can belong to only one module. A user may later need multiple modules with different permissions, for example Sales plus Calling, or Inventory view access plus Purchase edit access.

## 4. Common conventions

These are proposed conventions only:

- Primary keys: UUID or backend-generated string IDs
- Dates: ISO 8601 timestamps in UTC
- Money: decimal value plus currency code
- Lists: paginated responses with `page`, `page_size`, `total`, and `items`
- Soft deletion: use `deleted_at` where recovery/history is important
- Files: store metadata in the database and the actual file in backend-managed storage
- API responses: consistent success, validation-error, unauthorized, forbidden, not-found, and server-error formats

## 5. Common audit fields

Most business tables should include these fields, where applicable:

```text
id
created_at
created_by
updated_at
updated_by
deleted_at              optional
version                 optional optimistic-locking field
```

`created_by` and `updated_by` should refer to the user who performed the action. Important status changes should also create an entry in `audit_logs`.

## 6. Proposed entities and tables

### 6.1 Authentication and User Access

#### `users`

| Field | Purpose |
|---|---|
| id | User identifier |
| full_name | Display name |
| email | Login/contact email |
| phone | Contact number |
| password_hash | Stored only by the backend; never returned to Flutter |
| account_status | Pending, active, rejected, disabled |
| requested_department_id | Department requested during registration, if only one initial request is allowed |
| last_login_at | Last successful login |
| profile_file_id | Optional profile image/document reference |
| audit fields | Common audit fields |

#### `departments`

`id`, `name`, `code`, `description`, `is_active`, and audit fields.

Suggested departments include Sales, Calling, Inventory, Dispatch, Purchase, HR, Finance/Accounts, Vendor, and Admin. The instructor should confirm the final list.

#### `roles`

`id`, `name`, `code`, `description`, `is_system_role`, `is_active`, and audit fields.

Possible roles are Admin, Sales User, Calling User, Inventory User, Dispatch User, Purchase User, HR User, Approver, and Vendor User. These are proposed names, not fixed requirements.

#### `user_roles`

Connects users to roles. Suggested fields: `id`, `user_id`, `role_id`, `department_id`, `assigned_by`, `assigned_at`, `is_active`, and audit fields.

#### `modules`

Stores module keys such as `leads`, `calling`, `inventory`, `dispatch`, `purchase`, `hr`, `approvals`, `notifications`, `vendors`, and `reports`.

#### `permissions`

Suggested fields: `id`, `module_id`, `permission_key`, `permission_name`, and `description`.

Permission keys could follow this pattern:

```text
leads.view, leads.create, leads.edit, leads.assign, leads.import, leads.export
calling.view, calling.update, calling.reschedule
inventory.view, inventory.create, inventory.edit, inventory.stock_adjust
purchase.view, purchase.create, purchase.approve, purchase.export
reports.view, reports.customize, reports.export
```

The final permission list should come from the instructor.

#### `role_permissions` and `user_permissions`

`role_permissions` assigns standard permissions to roles. `user_permissions` allows a specific user to receive an additional permission or have a permission removed. This supports flexible multi-module granular access.

#### `access_requests`

Stores the registration request and admin decision: `id`, `user_id`, `requested_department_id`, `requested_role_id`, `reason`, `status`, `reviewed_by`, `reviewed_at`, `rejection_reason`, and audit fields.

### 6.2 Lead Management

#### `leads`

| Field | Purpose |
|---|---|
| id | Lead identifier |
| lead_code | Human-readable reference |
| name | Potential customer's name |
| phone | Main contact number |
| alternate_phone | Optional second number |
| email | Optional email |
| address, city, state, pincode | Contact/location information |
| interested_product | Product or service of interest |
| source_type | Manual, Excel, or CSV |
| source_reference | Optional file/import reference |
| assigned_to | Assigned sales/calling user |
| status | New, follow up, interested, not interested, irrelevant, closed, sales done, dispatched |
| notes | Additional details |
| next_follow_up_at | Planned follow-up |
| created_from_import_id | Optional import batch reference |
| audit fields | Common audit fields |

#### `lead_import_batches`

Stores `file_id`, `file_type`, `uploaded_by`, `uploaded_at`, `total_rows`, `successful_rows`, `failed_rows`, `duplicate_rows`, `status`, and an error-summary reference.

#### `lead_import_rows`

Optional row-level tracking: `batch_id`, `row_number`, `raw_data`, `validation_status`, `error_message`, `lead_id`.

#### `lead_assignments` and `lead_history`

Assignment history should record previous and new assignees, who changed the assignment, and when. Lead history should record status, notes, follow-up, and other important changes.

### 6.3 Calling

#### `call_records`

Suggested fields: `id`, `lead_id`, `caller_id`, `call_started_at`, `call_ended_at`, `duration_seconds`, `call_status`, `remarks`, `next_follow_up_at`, `rescheduled_from_id`, and audit fields.

Required business statuses from the instructor requirements should be supported:

```text
Follow up
Not connected
Visit scheduled
Irrelevant
Not interested
Lead closed
Sales done
Dispatched
```

The backend should return totals for assigned calls/leads, connected calls, pending follow-ups, and overdue follow-ups.

### 6.4 Inventory

#### `products` / `inventory_items`

Suggested fields: `id`, `sku`, `name`, `category`, `unit`, `description`, `current_quantity`, `minimum_quantity`, `maximum_quantity`, `unit_cost`, `sale_price`, `is_active`, and audit fields.

#### `stock_movements`

Records stock in/out/adjustment: `id`, `item_id`, `movement_type`, `quantity`, `reference_type`, `reference_id`, `remarks`, `performed_by`, and audit fields.

The backend should support stock list, low-stock alerts, item CRUD according to permissions, stock movement, and inventory reports.

### 6.5 Dispatch

#### `dispatches`

Suggested fields: `id`, `dispatch_code`, `customer_id` or `lead_id`, `invoice_id`, `dispatch_date`, `vehicle_number`, `driver_name`, `builty_number`, `builty_date`, `delivery_address`, `dispatch_status`, `proof_file_id`, and audit fields.

“Builty” is kept as the project term for the transport/delivery document reference.

#### `invoices`

Suggested fields: `id`, `invoice_number`, `customer_name`, `customer_contact`, `invoice_date`, `subtotal`, `tax_amount`, `discount_amount`, `total_amount`, `payment_status`, `invoice_file_id`, and audit fields.

The instructor should confirm whether invoices are created in this CRM or only referenced from another system.

### 6.6 Purchase

#### `purchase_requests`

Stores material requirements: `id`, `request_number`, `requested_by`, `department_id`, `required_date`, `priority`, `status`, `justification`, and audit fields.

#### `rfqs`

Stores Requests for Quotation: `id`, `rfq_number`, `purchase_request_id`, `issue_date`, `closing_date`, `status`, `created_by`, and audit fields.

#### `vendors` and `rfq_vendors`

Vendors are linked to RFQs through `rfq_vendors`, which stores invitation status, response date, and quotation reference.

#### `quotations`

Suggested fields: `id`, `quotation_number`, `rfq_id`, `vendor_id`, `quotation_date`, `valid_until`, `subtotal`, `tax_amount`, `total_amount`, `attachment_file_id`, `status`, and audit fields.

#### `purchase_orders`

Suggested fields: `id`, `po_number`, `vendor_id`, `quotation_id`, `purchase_request_id`, `order_date`, `expected_delivery_date`, `total_amount`, `payment_terms`, `po_type`, `status`, `approval_status`, and audit fields.

`po_type` can distinguish one-time and recurring PO if that is required. PO line items should be stored separately in `purchase_order_items` with item, quantity, rate, tax, and total.

PI/PO terminology should be confirmed with the instructor. If PI means Proforma Invoice in this project, it can be represented by a `proforma_invoices` table linked to the PO or quotation.

### 6.7 HR / Payroll

#### `employees`

Suggested fields: `id`, `employee_code`, `user_id`, `full_name`, `department_id`, `designation`, `joining_date`, `employment_status`, `manager_id`, `salary_reference`, and audit fields.

#### `employee_documents`

Links employees to document records, with `employee_id`, `document_type`, `file_id`, `expiry_date`, `verification_status`, and audit fields.

#### `attendance_records`

Suggested fields: `id`, `employee_id`, `attendance_date`, `check_in`, `check_out`, `attendance_status`, `remarks`, and audit fields.

#### `employee_kpis`

Suggested fields: `id`, `employee_id`, `period_start`, `period_end`, `metric_name`, `target_value`, `actual_value`, `score`, `remarks`, and audit fields.

#### Payroll

Payroll may need `payroll_periods`, `payroll_records`, allowances, deductions, and payslip file references. Payroll details are not fully defined in the available requirements, so this area must be confirmed before implementation.

### 6.8 Approvals and Notifications

#### `approval_requests`

Generic approval record: `id`, `request_type`, `reference_type`, `reference_id`, `requested_by`, `current_approver_id` or approval level, `status`, `comments`, `decided_by`, `decided_at`, and audit fields.

This can support access requests, PI/PO approvals, purchase requests, vendor verification, and other approval workflows.

#### `approval_steps`

For multi-step approval: `id`, `approval_request_id`, `step_number`, `approver_role` or `approver_id`, `status`, `comments`, `decided_at`.

#### `notifications`

Suggested fields: `id`, `recipient_user_id`, `notification_type`, `title`, `message`, `reference_type`, `reference_id`, `is_read`, `read_at`, and `created_at`.

#### `announcements`

Suggested fields: `id`, `title`, `message`, `audience_type`, `department_id`, `published_by`, `published_at`, `expires_at`, and audit fields.

### 6.9 Vendor Management

#### `vendors`

Suggested fields: `id`, `vendor_code`, `legal_name`, `contact_person`, `email`, `phone`, `address`, `tax_identifier`, `registration_status`, `approval_status`, `created_by_user_id`, and audit fields.

#### `vendor_kyc`

Suggested fields: `id`, `vendor_id`, `kyc_status`, `submitted_at`, `verified_by`, `verified_at`, `rejection_reason`, and audit fields.

#### `vendor_bank_accounts`

Suggested fields: `id`, `vendor_id`, `account_name`, `bank_name`, `account_number_reference`, `ifsc_or_swift`, `verification_status`, and audit fields. Sensitive values should be protected by the backend.

#### `vendor_documents`

Links KYC, registration, tax, banking, and other documents to the vendor. It should use the common file reference model.

#### Vendor order tracking

Vendor-facing or internal views can use `purchase_orders`, `purchase_order_items`, `vendor_order_status_history`, and delivery/receipt references. The instructor should confirm whether vendors log in directly or are managed only by internal employees.

### 6.10 Reports and Exports

#### `report_definitions`

Optional saved report configuration: `id`, `name`, `module`, `filters_json`, `columns_json`, `created_by`, `visibility`, and audit fields.

#### `export_jobs`

For larger exports: `id`, `requested_by`, `module`, `format`, `filters_json`, `status`, `file_id`, `started_at`, `completed_at`, and error message.

Reports should support customized reports where permitted, filtering, date ranges, totals, and Excel/CSV export. Possible reports include lead status, calling performance, inventory/low stock, dispatch, purchase, HR attendance/KPI, vendor orders, and approval history.

## 7. Relationships overview

```text
users ──< user_roles >── roles ──< role_permissions >── permissions ──> modules
  │                          │
  └──< access_requests       └── departments

leads ──< call_records
  │
  ├──< lead_assignments
  └──< lead_history

purchase_requests ──< rfqs ──< quotations ──< purchase_orders
                          │                 │
                          └── vendors       └── purchase_order_items

employees ──< attendance_records
    │       ├──< employee_documents
    │       └──< employee_kpis

vendors ──< vendor_kyc
   ├──< vendor_bank_accounts
   └──< vendor_documents

approval_requests ──< approval_steps
notifications ──> users
all important entities ──< audit_logs
```

## 8. File and document references

### `files`

Suggested fields: `id`, `original_name`, `storage_key` or backend URL, `mime_type`, `size_bytes`, `checksum`, `uploaded_by`, `uploaded_at`, `file_category`, and audit fields.

Business tables should store a `file_id` or use a join table such as `entity_files` with `entity_type`, `entity_id`, `file_id`, and `document_type`.

The backend should define whether Flutter receives a direct download URL, a temporary signed URL, or an authenticated download endpoint. Files should be checked for type, size, and authorization.

## 9. Audit and history

### `audit_logs`

Suggested fields:

```text
id
actor_user_id
action                 create, update, delete, approve, reject, login, export, import
entity_type
entity_id
old_values_json
new_values_json
ip_or_device_reference optional
created_at
```

At minimum, audit access approval/rejection, permission changes, lead assignment/status changes, stock adjustments, PO/PI decisions, vendor KYC decisions, exports, imports, and user disabling.

## 10. Suggested API contract

The exact routes depend on the instructor's backend. The frontend will need equivalent operations such as:

```text
POST   /auth/register
POST   /auth/login
POST   /auth/logout
GET    /auth/me
GET    /auth/me/permissions

GET    /users
PATCH  /users/{id}/status
GET    /access-requests
POST   /access-requests/{id}/approve
POST   /access-requests/{id}/reject

GET    /leads
POST   /leads
PATCH  /leads/{id}
POST   /leads/{id}/assign
POST   /leads/import
GET    /leads/import/{id}
GET    /leads/export

GET    /calls
POST   /calls
PATCH  /calls/{id}
POST   /calls/{id}/reschedule

GET    /inventory/items
POST   /inventory/items
PATCH  /inventory/items/{id}
POST   /inventory/stock-movements

GET    /dispatches
POST   /dispatches
PATCH  /dispatches/{id}

GET    /purchase-requests
POST   /purchase-requests
GET    /rfqs
POST   /rfqs
GET    /quotations
GET    /purchase-orders
POST   /purchase-orders

GET    /employees
GET    /attendance
POST   /attendance
GET    /kpis

GET    /approvals
POST   /approvals/{id}/approve
POST   /approvals/{id}/reject
GET    /notifications
PATCH  /notifications/{id}/read

GET    /vendors
POST   /vendors
GET    /vendors/{id}/kyc
POST   /vendors/{id}/documents

GET    /reports/{report_key}
POST   /exports
GET    /exports/{id}
```

These are examples for frontend planning, not a demand that the instructor use these exact URLs.

## 11. Minimum response data needed by Flutter

After login, the frontend should receive enough information to build authorized navigation:

```json
{
  "user": {
    "id": "user-id",
    "name": "Example User",
    "account_status": "active",
    "roles": ["sales_user"],
    "departments": ["sales"]
  },
  "permissions": [
    "leads.view",
    "leads.create",
    "leads.import",
    "calling.view",
    "calling.reschedule"
  ]
}
```

The backend must enforce permissions itself. Hiding a menu item in Flutter is only for user experience and is not a security control.

## 12. Import and export rules

For Excel/CSV lead import, the backend should ideally provide:

1. Upload file endpoint.
2. Accepted column/template information.
3. Validation preview before final save.
4. Required-field and invalid-format errors by row.
5. Duplicate handling rules.
6. Import summary and downloadable error report.
7. Import history for authorized users.

Manual entry and imported leads should use the same `leads` table and lifecycle. The `source_type` field should identify Manual, Excel, or CSV.

For exports, the backend should apply the user's permissions and filters. Exported files must not include fields the user is not allowed to view.

## 13. Items to confirm with the instructor

Before connecting the real backend, confirm:

- Database technology and final table/schema names
- API base URL, environments, and authentication method
- Exact registration fields and whether email/phone verification is needed
- Whether registration creates a pending user or only an access request
- Final department and role list
- Whether users can have multiple roles/modules
- Exact permission actions: view, create, edit, delete, assign, approve, import, export
- Whether Admin is one role or several administrator levels
- Exact lead fields, duplicate rules, import template, and customized lead format
- Whether calling is only a record of calls or connects to a phone service
- Exact inventory item fields and stock adjustment rules
- Invoice ownership and the meaning/workflow of PI
- Purchase approval levels, RFQ process, quotation comparison, and recurring PO rules
- Meaning of Builty fields and dispatch/invoice workflow
- Payroll scope, salary privacy, attendance rules, and payslip requirements
- Approval types and whether approvals are single-step or multi-step
- Vendor login requirements and exact KYC/banking documents
- File storage, file size/type limits, and download authorization
- Report list, custom-report builder needs, and export formats
- Pagination, sorting, filtering, search, and date/time conventions
- Notification method: in-app only, email, SMS, or push notification
- Soft-delete, retention, audit-log, and data privacy requirements

## 14. Working assumption for frontend development

Until the instructor supplies the backend contract, the Flutter project can use mock repositories with these same model concepts and statuses. Once the backend is integrated through GitHub, the repository/Dio layer can be updated to the real endpoints without redesigning the screens and BLoC/Cubit flows.

The final version of this document should be updated after the instructor provides the actual backend schema or API documentation.
