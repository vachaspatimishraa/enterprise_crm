# Enterprise CRM — HR & Payroll Module Development Handoff

> **Target Audience:** Colleague developer and their Antigravity AI assistant.  
> **Purpose:** Provide 100% complete context, architecture blueprint, user/admin authorization model, current implementation inventory, pending requirements, implementation plan, and exhaustive test case catalog to seamlessly continue development on the **HR and Payroll** module.

---

## 1. Project Context & Architecture Guidelines

### 1.1 Repository & Branching Rules
* **Repository:** `https://github.com/vachaspatimishraa/enterprise_crm.git`
* **Base Integration Branch:** `frontend-development`
* **DO NOT TOUCH `main`:** All work must be conducted on feature branches (e.g., `feature/hr-attendance-upload`, `feature/payroll-foundation`) and merged strictly into `frontend-development` via pull request.
* **Analysis & Verification:** Every change must maintain `flutter analyze` with **0 issues** and `flutter test` at **100% pass rate** before merging.

### 1.2 Architectural Principles (Ponytail Mode)
1. **Strict YAGNI:** Implement only immediate, confirmed business requirements. Do not build speculative abstractions or future-proofing wrappers.
2. **Native First:** Rely on Flutter and Dart built-in features (`Material 3`, `ChangeNotifier`/`Bloc`/`Cubit`, `SegmentedButton`, `DataTable`, etc.). Avoid adding unneeded third-party packages.
3. **Clean Architecture Separation:**
   * `domain/entities/`: Pure Dart, immutable data structures with `==`, `hashCode`, `copyWith`. Zero UI or Flutter framework dependencies.
   * `domain/repositories/`: Abstract interface contracts defining `Future<T>` methods.
   * `domain/policies/`: Pure business logic and authorization rule functions.
   * `data/mock/`: In-memory thread-safe mock stores with deterministic seed data for offline and decoupled frontend testing.
   * `data/repositories/`: Concrete implementations of domain interfaces backed by mock stores (easily swappable later for REST/Dio without UI rewrite).
   * `presentation/bloc/`: Single-responsibility Cubits using immutable state classes.
   * `presentation/screens/`: Stateful/Stateless UI widgets. Responsive design supporting desktop (`>= 600px`, table layouts) and mobile (`< 600px`, card layouts).
   * `presentation/widgets/`: Reusable presentation components.

---

## 2. User & Admin Roles, Context & Authorization Architecture

### 2.1 Role Matrix & Operational Boundaries

The Enterprise CRM supports two primary account tiers via `CurrentUser.accountType`: **Administrator** (`AccountType.admin`) and **Standard User** (`AccountType.user`).

```
                              ┌──────────────────────────────────┐
                              │           CurrentUser            │
                              └────────────────┬─────────────────┘
                                               │
                       ┌───────────────────────┴───────────────────────┐
                       ▼                                               ▼
         ┌───────────────────────────┐                   ┌───────────────────────────┐
         │       Administrator       │                   │       Standard User       │
         │   (AccountType.admin)     │                   │    (AccountType.user)     │
         └─────────────┬─────────────┘                   └─────────────┬─────────────┘
                       │                                               │
       ┌───────────────┴───────────────┐               ┌───────────────┴───────────────┐
       ▼                               ▼               ▼                               ▼
┌──────────────┐               ┌──────────────┐ ┌──────────────┐               ┌──────────────┐
│  Full Admin  │               │ Full Payroll │ │  HR Staff /  │               │  Individual  │
│ HR Operation │               │ Disbursement │ │  Specialist  │               │   Employee   │
└──────────────┘               └──────────────┘ └──────────────┘               └──────────────┘
(All Employees,                 (All Salaried    (Module + hr.view              (Self-Service:
 Records, Files,                 Cycles, Slips,   can view all                   Only own info
 Attendance, KPIs)               Audit Reports)   directory data)                via linkedId)
```

#### A. Administrator (`user.isAdmin == true` / `AccountType.admin`)
* **Global Unrestricted Access:** Bypasses all operational permission checks automatically via `AccessPolicy.hasPermission()` and `HrAccessPolicy`.
* **Workforce Administration:**
  * Enroll new employees via `AddEmployeeScreen`.
  * Edit any employee profile (name, department, designation, email, phone, joining date, status).
  * Change status between `Active`, `Probation`, and `Inactive`.
  * Initiate and finalize Employee Exit formalities.
* **Document Management:**
  * Upload agreements, KYC, identity, and certificates for any employee.
  * View and download documents across all employees.
* **Attendance Management & Regularization:**
  * Access full organization attendance in both **List** and **Calendar** views.
  * Inspect individual check-in/out timestamps, hours, and remarks.
  * **Manual Attendance for Any Employee on Any Day:** Can manually create, override, or regularize attendance records for **any user/employee** on **any calendar date** (backdated past days for biometric punch regularization, present day, or future approved leaves).
  * Bulk upload attendance logs (CSV/Excel biometric data).
* **KPI & Performance:**
  * View KPI targets, actuals, and scores organization-wide.
  * Add new KPI goals and evaluate existing records with assessor scores and remarks.
* **Payroll & Compensation:**
  * Full access to configure base salaries, allowances (HRA, conveyance), and deduction rates.
  * Initiate and process monthly payroll generation.
  * Finalize cycles and mark payments as disbursed.
  * View, print, and export payslips for any employee.

#### B. Standard User: HR Staff / Specialist (`AccountType.user` with `CrmPermissions.hrView`)
* Must have `CrmModule.hrPayroll` assigned in `user.modules`.
* Must have `CrmPermissions.hrView` to enter `EmployeeDirectoryScreen`, view documents, inspect attendance logs, and browse KPIs.
* **Manual Attendance Authority:** With `CrmPermissions.attendanceMark` (or `hrView` / `hrManage`), HR staff can manually add or regularize attendance for **any employee for any day** (past, present, or future) to correct missed punches, record off-site duty, or log approved leaves.
* Can view all employees but **cannot** add or edit employee profile records unless granted specific management permissions (`hrManage`).
* Protected by route guards: Unauthorized standard users receive `AccessRestrictedScreen`.

#### C. Standard User: Individual Employee / Self-Service (`Employee.userId == user.id`)
* Every workforce record has an optional linkage: `Employee.userId` matches `CurrentUser.id`.
* Standard employees who are **not** HR staff do not have `CrmPermissions.hrView` and are blocked from browsing colleagues' records.
* **Self-Service Scope (Strict Privacy & YAGNI):**
  * An employee should only see **their own** profile details.
  * An employee should only see **their own** attendance calendar and history.
  * An employee should only see **their own** uploaded KYC/agreements.
  * An employee should only see **their own** assigned KPIs and goals.
  * An employee should only see **their own** monthly payslips.
  * **Strict Data Isolation:** Employees must **never** be allowed to view salary structures, appraisal remarks, KYC documents, or attendance logs of other employees.

---

### 2.2 Explicit Authority to Edit Auth & Permission Files

> ⚠️ **Official Authorization:** The colleague developer and their Antigravity assistant are hereby granted **full authority and permission** by the project lead to modify, extend, and refactor the authentication and permissions files whenever required for the HR & Payroll module.

#### Authorized Files to Edit:
1. **[`lib/features/auth/domain/policies/crm_permissions.dart`](file:///D:/projects/enterprise_crm/lib/features/auth/domain/policies/crm_permissions.dart)**
2. **[`lib/features/auth/presentation/mappers/crm_permission_presentation.dart`](file:///D:/projects/enterprise_crm/lib/features/auth/presentation/mappers/crm_permission_presentation.dart)**
3. **[`lib/features/hr/domain/policies/hr_access_policy.dart`](file:///D:/projects/enterprise_crm/lib/features/hr/domain/policies/hr_access_policy.dart)**
4. **[`test/features/auth/domain/policies/access_policy_test.dart`](file:///D:/projects/enterprise_crm/test/features/auth/domain/policies/access_policy_test.dart)**
5. **[`test/features/hr/domain/policies/hr_access_policy_test.dart`](file:///D:/projects/enterprise_crm/test/features/hr/domain/policies/hr_access_policy_test.dart)**

#### Recommended New Permissions for HR & Payroll:
If you need more granular control beyond `hrView` and `payrollView`, add these canonical constants:

```dart
// In lib/features/auth/domain/policies/crm_permissions.dart:
abstract final class CrmPermissions {
  // Existing:
  static const String hrView = 'hr.view';
  static const String payrollView = 'payroll.view';

  // NEW Permissions you have permission to add:
  static const String hrManage = 'hr.manage';                 // Add/Edit employees, change status, exit
  static const String attendanceMark = 'attendance.mark';     // Mark/adjust daily attendance
  static const String attendanceImport = 'attendance.import'; // Bulk import biometric CSV/Excel
  static const String kpiManage = 'kpi.manage';               // Create, edit, and score KPIs
  static const String payrollManage = 'payroll.manage';       // Run payroll cycles, configure salaries
}
```

#### Step-by-Step Procedure to Add a New Permission:
1. **Declare Constant & Mapping:** In `crm_permissions.dart`, declare the constant and map it inside `_moduleByPermission` under `CrmModule.hrPayroll`.
2. **Add Display Label:** In `crm_permission_presentation.dart`, add human-readable description in `_displayNames` (e.g. `'attendance.mark': 'Mark Attendance'`).
3. **Add Policy Helper:** In `hr_access_policy.dart`, add a static evaluation method:
   ```dart
   static bool canMarkAttendance(CurrentUser user) {
     return AccessPolicy.hasPermission(user, CrmPermissions.attendanceMark);
   }
   ```
4. **Update Test Expectations:** In `test/features/auth/domain/policies/access_policy_test.dart`, add the mapping check:
   ```dart
   expect(CrmPermissions.moduleFor(CrmPermissions.attendanceMark), CrmModule.hrPayroll);
   ```
5. **Verify:** Run `flutter test test/features/auth/domain/policies/access_policy_test.dart` to verify that 100% of tests stay green.

---

## 3. Where Are We Today? (Current Status)

### 3.1 Overall Module Health
* **Compilation Status:** Clean compilation (`flutter build web` succeeds; runs on Edge/Desktop/Mobile).
* **Static Analysis:** `flutter analyze` reports **0 issues**.
* **Automated Tests:** **250 / 250 tests passed (100% green)** in `test/features/hr/`.
* **Cross-Feature Coexistence:** Cleanly wired into `CrmApp` alongside Lead Management, Calling, and Inventory.

### 3.2 Wireframe / Application Wiring
In `lib/app/crm_app.dart`:
```dart
// Repositories provided globally to the widget tree:
RepositoryProvider<EmployeeRepository>.value(value: _employeeRepository)
RepositoryProvider<EmployeeDocumentRepository>.value(value: _employeeDocumentRepository)
RepositoryProvider<AttendanceRepository>.value(value: _attendanceRepository)
RepositoryProvider<EmployeeKpiRepository>.value(value: _employeeKpiRepository)
```

In `AdminDashboardScreen` and `UserDashboardScreen`:
* Access to `CrmModule.hrPayroll` opens `EmployeeDirectoryScreen`.
* Protected by `HrAccessPolicy.canAccessModule(user)` and `HrAccessPolicy.canViewHrRecords(user)`.

---

## 4. What Has Been Done (Detailed Inventory)

The HR module is located under `lib/features/hr/` and consists of 4 mature sub-domains:

```
lib/features/hr/
├── data/
│   ├── mock/
│   │   ├── mock_attendance_store.dart         # Seeded attendance records
│   │   ├── mock_employee_document_store.dart  # Seeded KYC & document files
│   │   ├── mock_employee_kpi_store.dart       # Seeded quarterly KPI records
│   │   └── mock_employee_store.dart           # Seeded workforce directory
│   └── repositories/
│       ├── mock_attendance_repository.dart
│       ├── mock_employee_document_repository.dart
│       ├── mock_employee_kpi_repository.dart
│       └── mock_employee_repository.dart
├── domain/
│   ├── entities/
│   │   ├── attendance_record.dart             # Normalized UTC date, status, check-in/out
│   │   ├── employee.dart                      # Core workforce entity, code, department, etc.
│   │   ├── employee_document.dart             # Title, file metadata, size, expiry
│   │   ├── employee_kpi.dart                  # Metric name, target, actual, score, period
│   │   └── employment_status.dart             # Value-object ('Active', 'Probation', 'Inactive')
│   ├── inputs/
│   │   ├── create_employee_input.dart
│   │   ├── update_employee_input.dart
│   │   └── upload_document_input.dart
│   ├── policies/
│   │   └── hr_access_policy.dart              # Module, view, and payroll permission guards
│   └── repositories/
│       ├── attendance_repository.dart
│       ├── employee_document_repository.dart
│       ├── employee_kpi_repository.dart
│       └── employee_repository.dart
└── presentation/
    ├── bloc/
    │   ├── attendance_list_cubit.dart & state.dart
    │   ├── employee_details_cubit.dart & state.dart
    │   ├── employee_directory_cubit.dart & state.dart
    │   ├── employee_documents_cubit.dart & state.dart
    │   ├── employee_kpi_details_cubit.dart & state.dart
    │   ├── employee_kpi_form_cubit.dart & state.dart
    │   └── employee_kpi_list_cubit.dart & state.dart
    ├── screens/
    │   ├── add_employee_kpi_screen.dart
    │   ├── add_employee_screen.dart
    │   ├── attendance_details_dialog.dart
    │   ├── attendance_list_screen.dart
    │   ├── edit_employee_kpi_screen.dart
    │   ├── edit_employee_screen.dart
    │   ├── employee_attendance_history_screen.dart
    │   ├── employee_details_screen.dart
    │   ├── employee_directory_screen.dart
    │   ├── employee_document_details_screen.dart
    │   ├── employee_documents_screen.dart
    │   ├── employee_kpi_details_screen.dart
    │   ├── employee_kpi_list_screen.dart
    │   └── upload_document_screen.dart
    ├── services/
    │   └── employee_document_file_picker.dart
    └── widgets/
        └── attendance_status_badge.dart
```

### Feature-by-Feature Summary

| Sub-Module | Features Completed |
|---|---|
| **Employee Directory** | • Full listing with desktop `DataTable` and mobile `Card` layout.<br>• Real-time search by name, employee code, department, and designation.<br>• Department dropdown filter and Employment Status filter (`Active`, `Probation`, `Inactive`).<br>• Sort by Name, Code, and Joining Date.<br>• Authorization gates for viewing directory and adding employees. |
| **Employee Profile** | • Full profile summary with personal, job, and linked user metadata.<br>• Edit employee screen with email format and uniqueness validation.<br>• Deep-links to Employee Documents and Attendance History. |
| **Employee Documents** | • Document categorized under `Agreements`, `KYC`, `Identity`, `Certificates`.<br>• Formatted file sizes (`KB`, `MB`) and expiry detection.<br>• Binary file download simulation via `downloadDocumentFile`.<br>• `UploadDocumentScreen` with file picker integration and validations. |
| **Attendance Management** | • Toggleable **List View** and **Calendar View** (`SegmentedButton`).<br>• Date selection filter and status filtering (`Present`, `Absent`, `Half-day`, `On Leave`).<br>• Attendance status count badges.<br>• Detailed inspection modal (`AttendanceDetailsDialog`).<br>• Individual employee history view (`EmployeeAttendanceHistoryScreen`). |
| **KPI & Performance** | • Quantitative targets vs actuals tracking with optional evaluator score.<br>• Period filtering (Q1, Q2, Q3, Q4, or custom date range).<br>• Employee selector filter dropdown.<br>• Form validation ensuring `periodStart <= periodEnd` and positive target values.<br>• Add and Edit KPI screens with full round-trip updates. |
| **Authorization** | • `HrAccessPolicy` evaluating `CrmPermissions.hrView` and `CrmPermissions.payrollView`.<br>• Full admin bypass via `user.isAdmin`.<br>• Route guards on all screens redirecting unauthorized users to `AccessRestrictedScreen`. |

---

## 5. What Needs to Be Done & How to Achieve It

### Track 1: Remaining HR Gaps (High Priority)

#### Task 1.1: Manual Attendance Entry & Regularization UI (Any Employee, Any Day)
* **Requirement:** HR and Admin must be able to **manually add or regularize attendance for any user/employee on any calendar day** (supporting past backdated entries for biometric missed punch regularizations, today, or future approved leaves/on-duty logs).
* **Current Gap:** `AttendanceRepository.recordAttendance()` is implemented in the domain and data layer, but there is no interactive button on `AttendanceListScreen` to invoke manual attendance entry.
* **Detailed Implementation Plan:**
  1. **UI Triggers:**
     * Add a floating action button or AppBar action on `AttendanceListScreen` labeled **"Record Attendance"** (visible to Admin and users with HR management/attendance permissions).
     * Add a quick action button on `EmployeeAttendanceHistoryScreen` to record/regularize attendance with that specific employee pre-selected.
  2. **Create `RecordAttendanceDialog` (or Screen):**
     * **Employee Selector:** Searchable dropdown allowing selection of **any employee** in the workforce directory.
     * **Calendar Date Picker:** Allows picking **any calendar date** (past date for retrospective corrections/backdated punches, current date, or future dates for planned leaves).
     * **Status Selector:** `Present`, `Absent`, `Half-day`, `On Leave`.
     * **Check-In / Check-Out Time Pickers:** Material `TimeOfDay` pickers (optional if status is 'Absent' or 'On Leave').
     * **Reason / Remarks Field:** Mandatory or optional text input documenting the context (e.g. *"Manual punch by HR - Biometric device malfunction"*, *"On-site client meeting"*, *"Regularized half-day"*).
     * **Recorded By:** Automatically sets `CurrentUser.displayName` or `user.id`.
  3. **Repository & State Execution:**
     * Construct an `AttendanceRecord` normalized to UTC midnight date.
     * Call `AttendanceRepository.recordAttendance(record)`.
     * If an attendance entry already exists for that employee on that selected date, `recordAttendance` updates/overwrites it seamlessly.
     * If no entry exists, a new record is generated and persisted.
     * Refresh `AttendanceListCubit` so both **List View** and **Calendar View** update immediately.
  4. **Automated Test Cases to Add:**
     * In `test/features/hr/presentation/screens/attendance_list_screen_test.dart`:
       * Verify tapping "Record Attendance" opens dialog.
       * Verify submitting creates record for the chosen employee and date.
       * Verify date picker allows selecting a backdated past day.
       * Verify successful submission updates attendance list and calendar chips.

#### Task 1.2: Attendance CSV/Excel Bulk Import
* **Problem:** Phase 10 specifies "Attendance Import/Upload" for uploading biometric punch logs.
* **Implementation Plan:**
  1. Create `AttendanceImportParser` supporting CSV rows: `Employee Code`, `Date (YYYY-MM-DD)`, `Status`, `Check In`, `Check Out`, `Remarks`.
  2. Create `AttendanceImportScreen` (analogous to `InventoryImportScreen`):
     * File upload button via file picker.
     * Preview table with valid vs invalid row count.
     * Validation checks: verify employee code exists in `EmployeeRepository`.
     * "Confirm Import" button that commits entries via `recordAttendance()`.
  3. Add test suite in `test/features/hr/presentation/screens/attendance_import_screen_test.dart`.

#### Task 1.3: Employee Details KPI Quick Link
* **Problem:** `EmployeeDetailsScreen` currently links to Documents and Attendance History, but lacks a KPI navigation tile.
* **Implementation Plan:**
  1. In `EmployeeDetailsScreen`, add a third tile: **"KPI & Performance"** with icon `Icons.assessment_outlined`.
  2. On tap, navigate to `EmployeeKpiListScreen(initialEmployeeId: employee.id)`.
  3. Update `employee_details_screen_test.dart`.

#### Task 1.4: Employee Exit Formalities Workflow
* **Problem:** Phase 10 specifies "Employee Exit Formalities".
* **Implementation Plan:**
  1. Add entity `EmployeeExitDetails` (resignation date, last working day, reason, asset clearance status, exit interview remarks).
  2. Add `initiateExitFormalities()` method to `EmployeeRepository`.
  3. Create `EmployeeExitScreen` accessible from `EmployeeDetailsScreen` for employees transitioning to `Inactive`.

---

### Track 2: Payroll Module (To Be Implemented)

The Payroll module was explicitly marked pending confirmation in the PRD. Follow this standard architecture pattern to implement it:

#### Architecture Design for Payroll:
```
lib/features/hr/
├── domain/
│   ├── entities/
│   │   ├── payroll_period.dart        # e.g., 'October 2026', startDate, endDate, status: draft/finalized/paid
│   │   ├── salary_structure.dart      # employeeId, basicSalary, hra, conveyance, allowances
│   │   ├── payroll_record.dart        # employeeId, periodId, grossSalary, deductions, netSalary, status
│   │   └── payslip_artifact.dart      # generated payslip summary for download/print
│   └── repositories/
│       └── payroll_repository.dart    # getPayrollPeriods(), generatePayroll(), getPayslip(), markAsPaid()
├── data/
│   ├── mock/
│   │   └── mock_payroll_store.dart    # Seeded salary structures & previous month's payroll
│   └── repositories/
│       └── mock_payroll_repository.dart
└── presentation/
    ├── bloc/
    │   ├── payroll_dashboard_cubit.dart
    │   └── payslip_cubit.dart
    ├── screens/
    │   ├── payroll_dashboard_screen.dart   # Monthly payroll summary, total disbursement, generate button
    │   ├── payroll_period_details_screen.dart # List of employee payslips in that cycle
    │   └── employee_payslip_screen.dart    # Formatted printable payslip (Basic, HRA, PF, Tax, Net Pay)
    └── widgets/
        └── salary_breakdown_card.dart
```

#### Step-by-Step Execution Plan for Payroll:
1. **Define Domain Entities:**
   * Create `SalaryStructure` (base pay + allowances).
   * Create `PayrollRecord` (gross, statutory deductions like PF/ESI/TDS, attendance adjustments, net pay).
   * Create `PayrollPeriod` (monthly cycle, status).
2. **Implement `PayrollRepository` Contract & Mock:**
   * Provide deterministic mock data for existing employees (`emp_1`, `emp_2`, `emp_3`).
   * Calculate Net Pay = Gross Pay - Deductions.
3. **Build UI Screens:**
   * Add a **"Payroll"** navigation tab or top-bar button on `EmployeeDirectoryScreen` or dashboard.
   * Guard with `HrAccessPolicy.canViewPayroll(user)`.
   * Create `PayrollDashboardScreen` with monthly summary card (Total Payroll, Paid, Pending).
   * Create `EmployeePayslipScreen` with formatted breakdown table and "Print / Export PDF" option.
4. **Wire into `crm_app.dart`:**
   * Register `PayrollRepository` in `CrmApp`'s `RepositoryProvider`.

---

## 6. Complete Catalog of Existing HR Tests (250 Tests)

The entire suite of 250 tests is located in `test/features/hr/`. Here is the exhaustive catalog:

### 6.1 Data Layer & Repository Tests (50 Tests)
* **`test/features/hr/data/repositories/mock_attendance_repository_test.dart`**
  1. `getAttendanceRecords retrieves seeded records`
  2. `getAttendanceRecords filters by employeeId`
  3. `getAttendanceRecords filters by date range`
  4. `getAttendanceRecords filters by status`
  5. `getAttendanceById returns record if found and null if not`
  6. `getAttendanceForDate returns records for specific date`
  7. `recordAttendance adds a new record with copy isolation`
* **`test/features/hr/data/repositories/mock_employee_document_repository_test.dart`**
  8. `retrieves all seeded documents for employee`
  9. `retrieves document by id`
  10. `uploadDocument adds new document with correct metadata`
  11. `downloadDocumentFile returns valid binary stream`
  12. `cross-employee data isolation is maintained`
* **`test/features/hr/data/repositories/mock_employee_kpi_repository_test.dart`**
  13. `retrieves all seeded KPI records in deterministic order`
  14. `retrieves KPI records filtered by employeeId`
  15. `getKpisForEmployee delegates with correct employeeId`
  16. `returns empty list for employee with no KPI records`
  17. `retrieves an individual KPI by stable id`
  18. `returns null for unknown KPI id`
  19. `filters KPI records by date boundaries`
  20. `store reset restores initial deterministic seed state`
  21. `createKpi creates and persists valid record`
  22. `updateKpi modifies existing record`
  23. `update allows clearing score and remarks`
  24. `update throws EmployeeKpiException for nonexistent ID`
* **`test/features/hr/data/repositories/mock_employee_repository_test.dart`**
  25. `getEmployees returns deterministic seeded employees`
  26. `getEmployeeById returns matching record when exists`
  27. `getEmployeeById returns null when ID is not found`
  28. `createEmployee creates record and updates list`
  29. `createEmployee rejects empty full name`
  30. `createEmployee rejects invalid email format without @`
  31. `createEmployee rejects duplicate employee code`
  32. `updateEmployee updates existing record successfully`
  33. `updateEmployee throws when employee does not exist`

### 6.2 Domain Layer & Policy Tests (35 Tests)
* **`test/features/hr/domain/entities/attendance_record_test.dart`**
  34. `normalizes date to UTC midnight`
  35. `formattedDate returns YYYY-MM-DD string`
  36. `formattedCheckIn and formattedCheckOut format properly`
  37. `isSameDay matches correct calendar day`
  38. `copyWith preserves fields when null and overrides when provided`
* **`test/features/hr/domain/entities/employee_document_test.dart`**
  39. `correctly formats file sizes (B, KB, MB)`
  40. `isExpired calculates expiration correctly against current time`
  41. `copyWith creates exact replica with specified updates`
  42. `equality and hashcode are consistent`
* **`test/features/hr/domain/entities/employee_kpi_test.dart`**
  43. `normalizes periodStart and periodEnd to UTC midnight`
  44. `preserves all approved fields correctly`
  45. `formattedPeriod returns YYYY-MM-DD – YYYY-MM-DD`
  46. `value-based equality and hashCode work correctly`
  47. `toString includes key identifying information`
* **`test/features/hr/domain/entities/employee_test.dart`**
  48. `supports string value and case-insensitive equality for EmploymentStatus`
  49. `predefined statuses have expected values`
  50. `retains all properties correctly`
  51. `copyWith updates specified fields and preserves others`
  52. `copyWith clearUserId clears linked user`
  53. `equality and hashCode adhere to value equality`
* **`test/features/hr/domain/policies/hr_access_policy_test.dart`**
  54. `grants access unconditionally to Administrator`
  55. `grants access to standard user when hrPayroll is assigned`
  56. `denies access to standard user when hrPayroll is not assigned`
  57. `grants view access unconditionally to Administrator`
  58. `denies view access when hr.view permission is absent`
  59. `grants payroll view access unconditionally to Administrator`
  60. `denies payroll view access when payroll.view permission is absent`

### 6.3 Presentation Cubit State-Management Tests (55 Tests)
* **`test/features/hr/presentation/bloc/attendance_list_cubit_test.dart`**
  61. `initial state has initial status and empty records`
  62. `loadAttendance loads records from repository`
  63. `setSearchQuery filters records by query string`
  64. `setStatusFilter filters records by attendance status`
  65. `setSelectedDate filters records to specific calendar date`
  66. `setSelectedEmployeeId filters records to target employee`
  67. `setViewMode switches view mode between list and calendar`
  68. `resetFilters clears query, status, and date filters`
* **`test/features/hr/presentation/bloc/employee_details_cubit_test.dart`**
  69. `initial state has initial status`
  70. `loadEmployee loads employee when found`
  71. `loadEmployee emits notFound when ID does not exist`
  72. `reload reloads current employee record`
* **`test/features/hr/presentation/bloc/employee_directory_cubit_test.dart`**
  73. `initial state has initial status and empty lists`
  74. `loadEmployees loads records and emits loaded state`
  75. `setSearchQuery filters by name, code, department`
  76. `setDepartmentFilter filters strictly by department`
  77. `setStatusFilter filters strictly by employment status`
  78. `setSortOption sorts employees predictably`
  79. `refresh preserves active filters while updating dataset`
* **`test/features/hr/presentation/bloc/employee_documents_cubit_test.dart`**
  80. `initial state has initial status and empty list`
  81. `loadDocuments loads employee documents`
  82. `setFilterType filters documents strictly by type`
  83. `resetFilters clears query and active type filter`
* **`test/features/hr/presentation/bloc/employee_kpi_details_cubit_test.dart`**
  84. `initial state has correct default values`
  85. `loadKpi loads KPI record when found`
  86. `loadKpi emits notFound when KPI does not exist`
  87. `loadKpi emits failure on EmployeeKpiException`
  88. `reload re-fetches the current KPI record`
  89. `does not emit updates if closed during operation`
* **`test/features/hr/presentation/bloc/employee_kpi_form_cubit_test.dart`**
  90. `initial state has initial status and no error or record`
  91. `rejects empty employeeId without calling repository`
  92. `rejects empty metricName without calling repository`
  93. `rejects periodEnd preceding periodStart`
  94. `rejects negative target value`
  95. `prevents duplicate submissions when isSubmitting is true`
  96. `createKpi succeeds with valid inputs`
  97. `updateKpi succeeds with valid inputs`
  98. `handles unexpected exception with user-friendly message`
* **`test/features/hr/presentation/bloc/employee_kpi_list_cubit_test.dart`**
  99. `initial state has correct default values`
  100. `initial state preserves initialEmployeeId if provided`
  101. `loadKpis loads seeded KPI records successfully`
  102. `loadKpis emits failure on EmployeeKpiException`
  103. `setEmployeeFilter updates employee and triggers reload`
  104. `setSearchQuery filters records locally by metric name`
  105. `setSearchQuery filters records by resolved employee name`
  106. `setSelectedMetric filters records by exact metric name`
  107. `reload re-fetches records using current filters`

### 6.4 Screen Widget, Navigation & Integration Tests (110 Tests)
* **`test/features/hr/presentation/screens/employee_directory_screen_test.dart`**
  108. `unauthorized user sees AccessRestrictedScreen`
  109. `authorized standard user sees directory without Add Employee button`
  110. `admin user sees Add Employee floating action button`
  111. `desktop layout renders DataTable (>= 600px width)`
  112. `mobile layout renders cards (< 600px width)`
  113. `search field updates directory results`
  114. `department filter updates directory results`
  115. `status filter updates directory results`
* **`test/features/hr/presentation/screens/employee_details_screen_test.dart`**
  116. `displays loading spinner while fetching`
  117. `displays not found state for unknown employee id`
  118. `renders full employee details (name, code, dept, status, user link)`
  119. `edit button hidden for standard users`
  120. `edit button visible for admin users`
  121. `tapping Documents tile navigates to EmployeeDocumentsScreen`
  122. `tapping Attendance tile navigates to EmployeeAttendanceHistoryScreen`
* **`test/features/hr/presentation/screens/add_employee_screen_test.dart`**
  123. `form validation rejects empty name`
  124. `form validation rejects invalid email`
  125. `valid form creates employee and pops with true`
* **`test/features/hr/presentation/screens/edit_employee_screen_test.dart`**
  126. `pre-populates existing employee fields`
  127. `submitting updates employee and pops with true`
* **`test/features/hr/presentation/screens/employee_documents_screen_test.dart`**
  128. `renders document list for employee`
  129. `filters documents by category chip`
  130. `shows expired badge on expired documents`
  131. `upload button opens UploadDocumentScreen`
* **`test/features/hr/presentation/screens/upload_document_screen_test.dart`**
  132. `validation rejects submission without selecting a file`
  133. `validation rejects submission without title`
  134. `selecting file and submitting triggers repository upload`
* **`test/features/hr/presentation/screens/attendance_list_screen_test.dart`**
  135. `renders search and header controls`
  136. `toggles between List view and Calendar view`
  137. `filters records by status chip`
  138. `calendar view renders monthly grid`
  139. `tapping record row opens AttendanceDetailsDialog`
* **`test/features/hr/presentation/screens/employee_attendance_history_screen_test.dart`**
  140. `renders attendance logs specifically for target employee`
  141. `shows summary stats (Present, Absent, Leaves count)`
* **`test/features/hr/presentation/screens/employee_kpi_list_screen_test.dart`**
  142. `desktop layout (>=600px) renders DataTable with structured columns`
  143. `mobile layout renders cards`
  144. `search query filters records by metric name`
  145. `search query filters records by resolved employee name`
  146. `search clear button restores full record list`
  147. `search matching nothing displays no-results state with Clear Filters button`
  148. `employee dropdown filters records to selected employee`
  149. `period filter modal allows selecting Q3 2026`
  150. `Reset button clears all active filters and reloads`
  151. `renders cleanly without overflow across screen sizes`
  152. `dark theme renders cleanly`
* **`test/features/hr/presentation/screens/employee_kpi_details_screen_test.dart`**
  153. `renders target, actual, score, and remarks`
  154. `tapping desktop table row navigates to KPI Details screen`
* **`test/features/hr/presentation/screens/add_employee_kpi_screen_test.dart` & `edit_employee_kpi_screen_test.dart`**
  155. `validates required metric name`
  156. `validates target value is positive number`
  157. `validates date range order`
  158. `saves new KPI and refreshes list`
* **`test/features/hr/presentation/screens/employee_kpi_integration_test.dart`**
  159. `Roundtrip Flow 1: KPI List -> Add KPI -> Save -> KPI List displays new record`
  160. `Roundtrip Flow 2: KPI Details -> Edit KPI -> Save -> Details refreshed with updated values`
* **Navigation Route Tests (`hr_navigation_test.dart`, `hr_documents_navigation_test.dart`, `hr_attendance_navigation_test.dart`, `hr_kpi_navigation_test.dart`)**
  161–250. Complete route transition tests, PopScope state returns, parameter passing, and unauthorized redirect validations.

---

## 7. How Your Antigravity Assistant Should Work

When you share this document with your Antigravity agent, paste this prompt:

> *"Read `HR_PAYROLL_DEVELOPMENT_HANDOFF.md`. We are working on the Enterprise CRM HR/Payroll module. Follow strict Ponytail mode (Native first, strict YAGNI, no unnecessary dependencies). Review Section 2 for Admin vs Standard User boundaries and note that we have official authority to add/edit auth permissions as outlined in Section 2.2. Ensure all 250 existing tests continue to pass with 0 analyze warnings. Let's start by implementing [Task Name]."*

### Verification Commands
```powershell
# 1. Run all HR tests:
flutter test test/features/hr

# 2. Check static analysis:
flutter analyze

# 3. Test compilation:
flutter build web
```
