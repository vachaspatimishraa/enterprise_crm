# SESSION MEMORY
 
> Short-lived active-task memory. Coding-agent neutral.

## Current Goal
 
**AUTH-1 — Login + Mock Authentication + Admin/User Shell (COMPLETE)**.
- Implemented clean mock authentication architecture (`AuthRepository`, `MockAuthRepository`, `AuthCubit`, `AuthState`).
- Pure, Flutter-independent domain models: `AccountType`, `CrmModule` enum, and `CurrentUser` entity.
- UI metadata and presentation mappers located in presentation layer (`CrmModulePresentation`).
- Login screen with User ID, password with show/hide toggle, input validation, progress/disabled states, safe error messaging, and strict absence of sign-up/forgot-password.
- Global Admin Dashboard featuring all 8 CRM business modules:
  1. Lead Management (navigates to existing full Lead Dashboard via shared `LeadRepository`)
  2. Calling (clean module placeholder)
  3. Inventory (clean module placeholder)
  4. Dispatch (clean module placeholder)
  5. Purchase (clean module placeholder)
  6. HR / Payroll (clean module placeholder)
  7. Approvals & Notifications (clean module placeholder)
  8. Vendor Management (clean module placeholder)
- Administration section on Admin Dashboard with Users & Access shell placeholder.
- Dynamic User Dashboard rendering only assigned modules (`leadManagement` and `calling` for standard mock user). Administration section and unassigned modules are strictly excluded.
- User Lead Management boundary: standard mock user taps Lead Management to see a user-scoped module placeholder ("Lead Management access assigned. Permission-specific workspace will be enabled in the next access-control phase.") rather than inheriting unrestricted admin capabilities.
- Robust root session routing and logout safety: logging out clears user session and purges navigator stack so system Back cannot return to authenticated routes.
- Nested-route logout regression: logging out from within the Lead Dashboard immediately returns to Login and cannot be restored via system Back.
- Backward compatibility: tests instantiating `CrmApp` without an `authRepository` fallback directly to the Lead module, keeping 100% of the 734 baseline tests green. Real app execution (`main.dart`) injects `MockAuthRepository()`.

Current project checkpoint:
```text
branch: main
tests: 775 / 775 PASS (734 baseline + 41 new AUTH-1 tests)
analyzer: clean (0 issues)
web build: pass (flutter build web)
```

## Credentials & Access Rules

- **Mock Admin Account:** `admin` / `admin123` (AccountType: `admin`, access to all 8 modules + Administration).
- **Mock Standard User Account:** `user` / `user123` (AccountType: `user`, access to `leadManagement` and `calling`).
- **Real backend auth:** Pending instructor backend contract.
- **Fine-grained permissions:** Not yet enforced; foundation established with `Set<String> permissions`.
- **Password reset:** Admin-only requirement frozen. No self-service reset or forgot password in system.

## Remaining Milestones

- L0–L7A: Lead Management — COMPLETE / FROZEN
- L6B: Assignment History — DEFERRED pending backend/instructor contract
- L7B: Advanced Reporting — DEFERRED pending backend/instructor contract
- L8: Instructor Backend Integration — AUDIT COMPLETE / AWAITING INSTRUCTOR BACKEND CONTRACT
- AUTH-1: Login + Mock Auth + Admin/User Shell — COMPLETE
- AUTH-2 (Upcoming): Users & Access, Admin-created users, module assignment, and permission assignment
