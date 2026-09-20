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

**AUTH-2B.1 — Shared Mock Account Store + User Administration Mutation Foundation (COMPLETE)**.
- Unified data layer: `MockAccountStore` created as the single in-memory source of truth for both `MockAuthRepository` and `MockUserManagementRepository`.
- Credential isolation: Passwords stored privately inside `MockAccountStore`; `ManagedUser` strictly contains 0 credential/secret fields.
- Dynamic session mapping: `CurrentUser` derived dynamically on login from latest managed store state.
- Distinct lookups: `getUserById(id)` queries internal record ID (`usr_...`); `findUserByUserId(userId)` queries normalized login identifier.
- Mutation foundation: `createUser`, `updateUser`, `setUserStatus` (enable/disable), and `resetPassword` fully implemented on repository contract.
- Module & permission integrity: Strict permission validation on create (rejects unknown or orphan permissions); automatic pruning of removed-module permissions on update; `MockPermissionCatalog` introduced.
- Master Administrator safety: Master Admin cannot be disabled, downgraded, or have modules/permissions altered.
- Defensive immutability: `getUsers()` returns unmodifiable list; `ManagedUser.modules` and `permissions` are unmodifiable sets.

Current project checkpoint:
```text
branch: main
tests: 848 / 848 PASS (734 baseline + 41 AUTH-1 + 27 AUTH-2A + 7 UI-P1.1 + 39 AUTH-2B.1 tests)
analyzer: clean (0 issues)
web build: pass (flutter build web)
```

## Credentials & Access Rules

- **Mock Admin Account:** `admin` / `admin123` (AccountType: `admin`, access to all 8 modules + Administration / Users & Access).
- **Mock Standard User Account:** `user` / `user123` (AccountType: `user`, access to `leadManagement` and `calling`).
- **Real backend auth:** Pending instructor backend contract.
- **Fine-grained permissions:** Local mock catalog defined; mutations enforce module-subset rules and automatic pruning on update.
- **Password reset:** Admin-only requirement frozen. No self-service reset or forgot password in system.

## Remaining Milestones

- L0–L7A: Lead Management — COMPLETE / FROZEN
- L6B: Assignment History — DEFERRED pending backend/instructor contract
- L7B: Advanced Reporting — DEFERRED pending backend/instructor contract
- L8: Instructor Backend Integration — AUDIT COMPLETE / AWAITING INSTRUCTOR BACKEND CONTRACT
- AUTH-1: Login + Mock Auth + Admin/User Shell — COMPLETE
- AUTH-2A: Users & Access Foundation + User Directory — COMPLETE
- UI-P1.1: Align Authenticated App Header Layout ([A] Administrator ... [Logout]) — COMPLETE
- AUTH-2B.1: Shared Mock Account Store + User Administration Mutation Foundation — COMPLETE
- AUTH-2B.2 (Upcoming): User Administration UI (Create User screen/modal, Edit User screen/modal, Enable/Disable action, Admin Password Reset dialog)

