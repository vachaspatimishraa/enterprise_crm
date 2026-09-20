# SESSION MEMORY
 
> Short-lived active-task memory. Coding-agent neutral.

## Current Goal
 
**AUTH-2A — Users & Access Foundation + User Directory (COMPLETE)**.
- Established clean managed-user domain model: `ManagedUser` and `UserAccountStatus` (`active`, `disabled`).
- Plaintext passwords and credential secrets are strictly excluded from `ManagedUser`.
- Pure repository interface: `UserManagementRepository` with `getUsers()` and `getUserById(id)`.
- Mock repository: `MockUserManagementRepository` with deterministic seeding (Admin, Standard User, HR User, Inventory User, Disabled User) sorted Admin-first, then displayName A-Z, then id.
- Approved Correction 1: No fake wildcard permissions (`{'*'}`). Admin has `permissions: const {}`, authorized via `accountType == AccountType.admin`. Truthful UI copy: "Administrative access — Full frontend access in the current mock environment."
- Approved Correction 2: Explicit dependency injection in `CrmApp`. `userManagementRepository` is explicitly supplied whenever `authRepository != null`, enforced via constructor assertion.
- Approved Correction 3: Strict pre-cubit route guard. Non-Admin users are blocked before creating `UserDirectoryCubit` or calling `getUsers()` (verified with repository spy: exactly 0 `getUsers()` calls).
- State management: `UserDirectoryCubit` and `UserDirectoryState` handling loading, failure with retry, and loaded states with computed `filteredUsers`.
- Search & Filter: Local case-insensitive substring search (matching `displayName` or `userId`), status filter chips (`All`, `Active`, `Disabled`), and clear/reset actions.
- Read-only User Details screen: Role/status badges, module access chips using `CrmModulePresentation`, permission entitlements, and mutation deferral notice.
- Responsive presentation: Mobile cards (< 600px width) vs structured desktop rows (>= 600px width).
- Dark mode theme-aware styling verified across all screens.
- Retired and replaced `UsersAndAccessPlaceholderScreen`.
- Backward compatibility: Legacy tests without `authRepository` continue to function untouched.

Current project checkpoint:
```text
branch: main
tests: 808 / 808 PASS (734 baseline + 41 AUTH-1 + 27 AUTH-2A + 6 UI-P1 tests)
analyzer: clean (0 issues)
web build: pass (flutter build web)
```

## Credentials & Access Rules

- **Mock Admin Account:** `admin` / `admin123` (AccountType: `admin`, access to all 8 modules + Administration / Users & Access).
- **Mock Standard User Account:** `user` / `user123` (AccountType: `user`, access to `leadManagement` and `calling`).
- **Real backend auth:** Pending instructor backend contract.
- **Fine-grained permissions:** Foundation established; full enforcement & mutation deferred to AUTH-2B.
- **Password reset:** Admin-only requirement frozen. No self-service reset or forgot password in system.

## Remaining Milestones

- L0–L7A: Lead Management — COMPLETE / FROZEN
- L6B: Assignment History — DEFERRED pending backend/instructor contract
- L7B: Advanced Reporting — DEFERRED pending backend/instructor contract
- L8: Instructor Backend Integration — AUDIT COMPLETE / AWAITING INSTRUCTOR BACKEND CONTRACT
- AUTH-1: Login + Mock Auth + Admin/User Shell — COMPLETE
- AUTH-2A: Users & Access Foundation + User Directory — COMPLETE
- UI-P1: Simplify Authenticated App Header — COMPLETE
- AUTH-2B (Upcoming): User Administration Mutations (Create user, edit user, module assignment, permissions, active/disabled toggle, admin password reset)

