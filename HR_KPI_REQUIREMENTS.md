# HR-5.1 — Employee KPI Requirements Audit & Business Freeze Report

**Date:** 2026-09-27  
**Project:** Enterprise CRM (`d:\projects\enterprise_crm` / `c:\Users\vkcha\Desktop\Assets\project\enterpr
ise_crm`)  
**Feature Branch:** `feature/hr-5-kpi`  
**Git HEAD:** `b31761d15776547b52163031fc46593323aa7bce`  
**Status:** HR-5.1 AUDIT COMPLETE / REQUIREMENTS FROZEN FOR HR-5.2  

---

## 1. Purpose and Scope

This document establishes the verified requirements, architectural boundaries, and frozen domain specifications for **Employee Key Performance Indicator (KPI) Management** in the Enterprise CRM HR / Payroll module.

Following the mandatory governance rules established in `MASTER_DEVELOPMENT_RULES.md`, `CRM_PRD.md`, and `CRM_TRD.md`, this checkpoint (**HR-5.1**) audits the codebase, classifies all proposed and unconfirmed KPI concepts, evaluates existing patterns from HR-1 through HR-4, and freezes the minimal non-speculative contract required for the core KPI architecture checkpoint (**HR-5.2**).

No UI screens, speculative formulas, or external backend services are created during HR-5.1.

---

## 2. Starting Git Baseline

- **Current Branch:** `feature/hr-5-kpi` (branched from `feature/hr-1-core` at commit `b31761d`)
- **Baseline Git HEAD:** `b31761d15776547b52163031fc46593323aa7bce` (`init hr feature`)
- **Working Tree:** Clean
- **Flutter Analyzer:** Clean (0 issues)
- **HR Targeted Tests:** 147 / 147 PASS
- **Verified Submodules in Baseline:**
  - HR-1: Core Employee domain, `EmployeeRepository`, `MockEmployeeRepository`, `MockEmployeeStore` (seeds `emp_1` through `emp_5`)
  - HR-2: Employee Documents domain, repository, mock store, screens, navigation
  - HR-3: Employee Directory, Employee Details, Add Employee, Edit Employee
  - HR-4: Attendance Management (`AttendanceRecord`, `AttendanceRepository`, `MockAttendanceRepository`, `MockAttendanceStore`, `AttendanceListScreen`, `EmployeeAttendanceHistoryScreen`)

---

## 3. Existing HR Architecture

The HR module in Enterprise CRM adheres to a strict feature-first, layered architecture:

```text
Flutter Presentation (Screens, Widgets, Dialogs)
     ↓
BLoC / Cubit (State Management, View State)
     ↓
Domain Layer (Entities, Value Objects, Inputs, Policies, Repository Interfaces)
     ↓
Data Layer (Repositories, In-Memory Mock Stores with Copy Isolation)
     ↓
Backend Integration Layer (Future Dio / REST integration with Instructor backend)
```

Key Architectural Patterns:
1. **Domain Entities:** Immutable classes with `final` fields, null-safe typing, `copyWith`, value-based `operator ==`, `hashCode`, and no UI or networking imports.
2. **Repository Interfaces:** Pure abstract interface classes with specific, strongly-typed query methods returning immutable entities and throwing typed domain exceptions (`EmployeeException`, `AttendanceException`).
3. **Mock Data Layer:** Dedicated thread-safe mock stores (`MockEmployeeStore`, `MockAttendanceStore`) with deterministic seed fixtures keyed by stable IDs (`emp_1`, `att_101`), defensive cloning on reads and writes, and no dependency on `DateTime.now()` for deterministic seeds.
4. **State Management:** Fine-grained `Cubit` classes (`EmployeeDirectoryCubit`, `EmployeeDetailsCubit`, `AttendanceListCubit`) with structured state classes (`status`, data collections, error messages, and search/filter parameters).
5. **Authorization:** Centralized evaluation via `HrAccessPolicy` delegating to `AccessPolicy`, `CurrentUser`, `CrmModule.hrPayroll`, and canonical permission `CrmPermissions.hrView`. Administrators enjoy unrestricted access via `user.isAdmin`.
6. **Dependency Composition:** Top-level constructor injection in `CrmApp` with fallback to default mock repository instances, passed down to screens without global service locators (`GetIt`) or third-party containers.

---

## 4. Confirmed KPI Requirements

The following requirements have been confirmed through the PRD, TRD, and existing HR domain conventions:

1. **Module Membership:** KPI is an integral sub-feature of `CrmModule.hrPayroll`.
2. **Entity Association:** Every KPI record belongs to an `Employee` and is foreign-keyed to `Employee.id` via a non-nullable `employeeId`.
3. **Stable Identity:** Every KPI record possesses a unique, stable string identifier `id` (`kpi_...` in mock data, UUID or backend ID in production).
4. **Periodic Measurement:** KPIs are evaluated across a distinct time period demarcated by a start date (`periodStart`) and an end date (`periodEnd`).
5. **Metric Identification:** Each KPI record tracks a specific metric described by a descriptive `metricName` (e.g., 'Lead Conversion Rate', 'Customer Satisfaction', 'Tickets Resolved').
6. **Target & Actual Tracking:** Each KPI record captures a numeric `targetValue` and an achieved `actualValue` represented as `double`.
7. **Read Authorization:** Viewing KPI records requires either `AccountType.admin` or `CurrentUser` having `CrmModule.hrPayroll` and `CrmPermissions.hrView`.
8. **Multiple KPIs Per Employee:** An employee can have multiple KPI records across different periods or multiple distinct metrics within the same period.

---

## 5. Proposed KPI Fields (Evaluation & Audit)

The proposed backend schema (`CRM_Backend_Schema.md` §6.7) suggests:
```text
employee_kpis:
  id
  employee_id
  period_start
  period_end
  metric_name
  target_value
  actual_value
  score
  remarks
  audit fields (created_at, updated_at)
```

### Field Classification Table:

| Field Name | Proposed Type | Classification | Decision & Rationale |
|---|---|---|---|
| `id` | `String` | **CONFIRMED** | Primary key. Unique stable identifier. Required. |
| `employeeId` | `String` | **CONFIRMED** | Foreign key to `Employee.id`. Required. Orphan KPIs strictly prohibited. |
| `periodStart` | `DateTime` | **CONFIRMED** | Start boundary of evaluation period. Normalized calendar date (UTC). Required. |
| `periodEnd` | `DateTime` | **CONFIRMED** | End boundary of evaluation period. Normalized calendar date (UTC). Required. |
| `metricName` | `String` | **CONFIRMED** | Descriptive name of the metric. Non-empty string. Required. |
| `targetValue` | `double` | **CONFIRMED** | Quantitative target goal. Required. |
| `actualValue` | `double` | **CONFIRMED** | Quantitative achieved value. Required. |
| `score` | `double?` | **CONFIRMED (OPTIONAL)** | Computed or assigned rating/score. Nullable. May be supplied by backend or reviewer. |
| `remarks` | `String?` | **CONFIRMED (OPTIONAL)
** | Qualitative notes, reviewer observations, or justification. Nullable string. |
| `createdAt` | `DateTime?` | **CONFIRMED (OPTIONAL)** | Standard audit timestamp. |
| `updatedAt` | `DateTime?` | **CONFIRMED (OPTIONAL)** | Standard audit timestamp. |

---

## 6. Unconfirmed Business Rules

The following rules have **NOT** been approved and must not be implemented:

1. **Automatic Score Calculation Formula:**  
   *Unconfirmed:* Formulas such as `(actual / target) * 100` or weighted metric sums are NOT frozen. The entity must store `score` as given, without computing it internally.
2. **Performance Grades & Tier Bands:**  
   *Unconfirmed:* Categories like 'Exceeds Expectations', 'Grade A', 'Needs Improvement' or 1-to-5 star ratings have no agreed schema or vocabulary.
3. **Weighting of Multiple Metrics:**  
   *Unconfirmed:* Metric weights (e.g., Metric A = 40%, Metric B = 60%) are undefined in requirements.
4. **Duplicate Record Rules:**  
   *Unconfirmed:* Whether an employee can have duplicate records for the exact same metric and period is backend-dependent. The client will not invent rejection policies.
5. **Period Overlap Validation:**  
   *Unconfirmed:* System will not artificially prevent overlapping evaluation periods.
6. **KPI Approval / Finalization Lifecycle:**  
   *Unconfirmed:* Draft/Submitted/Approved/Locked statuses are deferred.
7. **Custom Measurement Units:**  
   *Unconfirmed:* Dedicated unit enum/table (%, currency, hours, units) is unconfirmed. Unit is either implicit or documented in remarks.

---

## 7. KPI Identity and Employee Relationship

- **Relationship Cardinality:** One-to-Many (`Employee 1 ──< * EmployeeKpi`).
- **Identity Invariant:** KPI records reference the workforce record `Employee.id` (`emp_1`, `emp_2`, etc.).
- **User Linkage Guard:** KPI records do NOT link directly to `ManagedUser.id` or `CurrentUser.id`. CRM Users who are not Employees cannot have KPIs.
- **Orphan Guard:** Every KPI record must reference a valid `employeeId`. In-memory seeds must strictly reference valid seeds from `MockEmployeeStore`.

---

## 8. KPI Period Rules

1. `periodStart` and `periodEnd` are normalized to UTC calendar dates (midnight UTC, `DateTime.utc(y, m, d)`), eliminating timezone jitter across web and mobile.
2. `periodStart` must be less than or equal to `periodEnd` (`!periodStart.isAfter(periodEnd)`).
3. The repository contract will support query filtering by date range: records overlapping or falling within the specified boundaries.

---

## 9. KPI Score / Calculation Status

- **DECISION:** **EXPLICITLY DEFERRED / NO CLIENT FORMULA.**
- The `score` field is an optional `double?`.
- If present, it reflects the recorded score provided by the backend or assessor.
- The domain layer will not calculate scores, assign bonuses, or infer performance rankings.

---

## 10. KPI Authorization Boundaries

- **Module Boundary:** `CrmModule.hrPayroll`.
- **View Permission:** Governed by `HrAccessPolicy.canViewHrRecords(user)` which checks `CrmPermissions.hrView` for standard users and grants unrestricted access for `AccountType.admin`.
- **Dedicated KPI Permissions:** There is NO `'kpi.view'` or `'kpi.edit'` in `CrmPermissions`. Do NOT invent new permission keys or account types (`KpiAdmin`, `PerformanceManager`).
- **Mutation Boundary:** KPI creation and editing are scheduled for HR-5.6. In HR-5.2, repository contracts are read-only.

---

## 11. Repository Contract Proposal

Repository Interface: `EmployeeKpiRepository`

```dart
abstract interface class EmployeeKpiRepository {
  /// Retrieves all KPI records, optionally filtered by [employeeId],
  /// [startDate], and [endDate].
  Future<List<EmployeeKpi>> getKpis({
    String? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves all KPI records for a specific [employeeId].
  Future<List<EmployeeKpi>> getKpisForEmployee(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Retrieves an individual KPI record by its unique [id], or null if not found.
  Future<EmployeeKpi?> getKpiById(String id);
}
```

Domain Exception: `EmployeeKpiException`

Mock Implementation: `MockEmployeeKpiRepository` backed by `MockEmployeeKpiStore` with deterministic seeds for `emp_1`, `emp_2`, `emp_3`.

---

## 12. State Management Proposal

Primary List Cubit: `EmployeeKpiListCubit` & `EmployeeKpiListState`
- Constructor injection: `EmployeeKpiRepository`, optional `initialEmployeeId`.
- State fields: `status` (initial, loading, loaded, failure), `records`, `filteredRecords`, `selectedEmployeeId`, `errorMessage`.
- Methods: `loadKpis()`, `setEmployeeFilter()`, `reload()`.

Secondary Details Cubit: `EmployeeKpiDetailsCubit` & `EmployeeKpiDetailsState`
- Constructor injection: `EmployeeKpiRepository`.
- State fields: `status` (initial, loading, loaded, notFound, failure), `kpi`, `searchedId`, `errorMessage`.
- Methods: `loadKpi(String id)`, `reload()`.

---

## 13. HR-5.2 File Plan

The following minimal files will be created in HR-5.2:

```text
Domain:
- lib/features/hr/domain/entities/employee_kpi.dart
- lib/features/hr/domain/repositories/employee_kpi_repository.dart

Data:
- lib/features/hr/data/mock/mock_employee_kpi_store.dart
- lib/features/hr/data/repositories/mock_employee_kpi_repository.dart

Presentation / State Management:
- lib/features/hr/presentation/bloc/employee_kpi_list_cubit.dart
- lib/features/hr/presentation/bloc/employee_kpi_list_state.dart
- lib/features/hr/presentation/bloc/employee_kpi_details_cubit.dart
- lib/features/hr/presentation/bloc/employee_kpi_details_state.dart

Composition:
- Wire EmployeeKpiRepository into lib/app/crm_app.dart

Tests:
- test/features/hr/domain/entities/employee_kpi_test.dart
- test/features/hr/data/repositories/mock_employee_kpi_repository_test.dart
- test/features/hr/presentation/bloc/employee_kpi_list_cubit_test.dart
- test/features/hr/presentation/bloc/employee_kpi_details_cubit_test.dart
```

---

## 14. Backend Dependencies

When the instructor connects the real backend, the following endpoints are expected:
- `GET /employees/{id}/kpis` or `GET /kpis?employee_id={id}`
- `GET /kpis/{id}`
- Standard pagination/filtering if dataset is large

The `MockEmployeeKpiRepository` adheres strictly to this contract so it can be swapped with a `DioEmployeeKpiRepository` without touching domain or state management code.

---

## 15. Explicitly Deferred Functionality

The following items are strictly deferred to future checkpoints:
- **HR-5.3:** KPI List & Directory UI Screen
- **HR-5.4:** KPI Period Filtering & Date Range Picker UI
- **HR-5.5:** KPI Details UI Screen / Modal
- **HR-5.6:** KPI Add / Edit Mutation UI & Repository methods
- **HR-5.7:** KPI Performance Summary & Visualization
- **HR-5.8:** Employee Details KPI Integration Tab / Tile
- **Cross-module:** Payroll calculation links, incentive calculation, attendance penalties, appraisal workflows, CSV/Excel export.

---

## 16. HR-5.1 Exit Criteria Verification

| Exit Criterion | Status | Verification Summary |
|---|---|---|
| Existing HR architecture inspected | **PASS** | HR-1 through HR-4 patterns inspected and cataloged. |
| Previous HR checkpoints verified | **PASS** | 147 / 147 HR tests passing; analyzer clean. |
| KPI requirements classified | **PASS** | 4-tier classification completed in Section 5. |
| Employee/KPI identity relationship understood | **PASS** | One-to-Many via `employeeId`, orphan guard enforced. |
| Minimum KPI entity contract defined | **PASS** | 11 approved fields; zero guessed attributes. |
| Repository responsibilities established | **PASS** | Read contract defined; mutations deferred to HR-5.6. |
| State-management responsibilities established | **PASS** | `EmployeeKpiListCubit` and `EmployeeKpiDetailsCubit` specified. |
| Scoring rules confirmed or deferred | **PASS** | Score formula explicitly deferred; no client calculation. |
| Permissions identified without guessing | **PASS** | Governed by `CrmPermissions.hrView` and `HrAccessPolicy`. |
| Backend dependencies documented | **PASS** | Documented in Section 14. |
| `HR_KPI_REQUIREMENTS.md` accurate | **PASS** | Fully documented. |
| No speculative production implementation introduced | **PASS** | Zero production code added during HR-5.1. |

### Business Freeze Gate
All required information for KPI identity, Employee association, and the minimum approved fields is frozen and verified. **HR-5.1 is APPROVED. Gate to HR-5.2 is OPEN.**
