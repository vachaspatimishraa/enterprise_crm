# CRM Project — Updated Development Flow & Structure

## 1. Purpose of This Document

This document explains the **updated project flow, development priority, architecture, and agent working rules** for the CRM project.

This document should be shared with both **Codex** and **Antigravity** before giving them new implementation tasks.

The most important update is:

> **We will now work module-by-module. The first active business module is Lead Management / Interface, including Lead Distribution. We will not move to another CRM module until Lead Management is fully completed, tested, integrated, and frozen.**

---

# 2. Current Instructor Priority

The current active requirement is:

## Lead Management / Interface

This includes:

- Lead creation
- Lead listing
- Lead details
- Lead update/edit
- Lead import
- Lead distribution
- Lead assignment
- Lead reassignment
- Permission-based lead access
- Lead search/filter/sort
- Lead export/reporting where required

### Important Development Rule

Do **not** start implementation of:

- Calling
- Inventory
- Dispatch
- Purchase
- HR / Payroll
- Approvals & Notifications
- Vendor Management

until the Lead Management / Interface module is complete.

These modules remain part of the overall CRM project, but they are **inactive development scope for now**.

---

# 3. Updated Project Development Strategy

Updated approach:

```text
Project Foundation
        ↓
Lead Management / Interface
        ↓
Lead Distribution
        ↓
Lead Backend Integration
        ↓
Lead Testing
        ↓
Lead Module Complete / Frozen
        ↓
Instructor Review / Approval
        ↓
Next CRM Module
```

We will follow this same pattern for every future CRM module:

```text
Select One Module
      ↓
Plan
      ↓
Build UI
      ↓
Build State / Logic
      ↓
Integrate Backend
      ↓
Test
      ↓
Fix
      ↓
Freeze
      ↓
Move to Next Module
```

---

# 4. Technology and Architecture

## Frontend

Use:

- Flutter
- Android
- Responsive Web
- One Flutter codebase
- BLoC / Cubit
- Dio
- Feature-first architecture
- Repository/service separation
- Responsive reusable UI

## Backend

The backend will be provided/integrated by the instructor through GitHub.

Therefore:

- Do not create a separate Supabase backend.
- Do not create a separate Firebase backend.
- Do not create a separate production backend unless specifically asked.
- Do not invent undocumented API endpoints.
- Do not invent database fields.
- Do not invent authentication behavior.
- Do not tightly couple widgets to backend code.

Preferred flow:

```text
UI
 ↓
BLoC / Cubit
 ↓
Repository
 ↓
Service / Data Source
 ↓
Dio / Instructor Backend
```

If backend APIs are not yet available:

```text
UI
 ↓
BLoC / Cubit
 ↓
Repository
 ↓
Temporary Mock / Local Test Data
```

The mock layer must be replaceable without rewriting the UI.

---

# 5. Lead Source Decision

Lead intake must use only:

- Manual / custom data entry
- Excel import
- CSV import

Do not implement:

- Meta lead integration
- Facebook lead integration
- Google Ads lead integration
- External ad funnels
- Lead webhooks from advertising platforms

Expected lead intake:

```text
Manual Entry ─────┐
                  │
Excel Import ─────┼──→ Lead Management
                  │
CSV Import ───────┘
```

---

# 6. Lead Management Scope

The Lead Management / Interface module should be treated as a complete feature area.

Suggested feature structure:

```text
lib/features/leads/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/
│   ├── entities/
│   └── repositories/
│
└── presentation/
    ├── bloc/
    ├── screens/
    └── widgets/
```

Follow the actual project architecture created in the repository. Do not create unnecessary layers if the foundation uses a simpler approved structure.

---

# 7. Lead Management Functional Areas

## 7.1 Lead Dashboard / Summary

Possible information:

- Total leads
- New leads
- Assigned leads
- Unassigned leads
- Leads by status
- Leads by assigned user
- Recent imports
- Recent assignments

Only implement dashboard fields supported by requirements/backend.

## 7.2 Lead List

The Lead List should support:

- Lead display
- Search
- Filter
- Sort
- Pagination if required
- Select lead
- Multi-select where bulk actions are allowed
- Open lead details
- Permission-aware actions

Web may use a table.

Mobile may use cards/list items.

## 7.3 Add Lead

Manual/custom lead creation.

Requirements:

- Form validation
- Required fields
- Backend-ready structure
- Duplicate handling according to backend rules
- Loading state
- Success state
- Error state

Do not invent final mandatory fields until they are confirmed.

## 7.4 Edit Lead

Allow permitted users to update lead information.

Must support:

- Current data display
- Validation
- Save/update state
- Error handling
- Permission check

## 7.5 Lead Details

The Lead Details area may include:

- Basic lead information
- Assigned user
- Lead source
- Lead status
- Created date
- Last updated date
- Assignment history
- Activity/history if backend supports it

Do not add unsupported business data.

---

# 8. Lead Import

## 8.1 Excel Import

Support:

- File selection
- File validation
- Import preview if possible
- Column mapping if required
- Valid rows
- Invalid rows
- Duplicate rows
- Import result
- Error reporting

## 8.2 CSV Import

Support the same general workflow as Excel:

```text
Select File
   ↓
Validate
   ↓
Preview
   ↓
Import
   ↓
Result
```

Avoid separate duplicated architecture for Excel and CSV if a shared import flow is possible.

---

# 9. Lead Distribution

Lead Distribution is a required part of Lead Management.

It should be treated as a dedicated sub-feature.

Main concept:

```text
New / Imported Leads
        ↓
Unassigned Lead Pool
        ↓
Lead Distribution
        ↓
Select Sales User / Agent
        ↓
Assign Lead(s)
        ↓
Agent's Assigned Leads
```

---

# 10. Lead Assignment

Support:

- Assign one lead
- Assign multiple leads if supported
- Select user/agent
- Confirm assignment
- Assignment success/error state
- Permission check

The final distribution rule depends on backend/instructor requirements.

Possible distribution modes may include:

- Manual assignment
- Bulk manual assignment
- Automatic distribution
- Round-robin

Do not implement automatic/round-robin logic unless confirmed.

---

# 11. Lead Reassignment

Authorized users may need to move a lead from one user to another.

Concept:

```text
Lead
 ↓
Current Agent
 ↓
Reassign
 ↓
New Agent
 ↓
Save
```

If backend supports assignment history, preserve:

- Previous agent
- New agent
- Assigned by
- Date/time
- Reason if required

---

# 12. Assigned Lead Views

Users should only see lead data allowed by their role/permissions.

Example:

```text
Administrator
→ Can view all leads

Sales Manager
→ Depends on assigned permissions

Sales Agent
→ Assigned leads / permitted leads
```

Frontend visibility must follow backend permissions.

Frontend hiding is **not security**. Backend authorization remains authoritative.

---

# 13. Lead Search / Filter / Sort

Possible filters:

- Assigned user
- Assignment status
- Lead status
- Date
- Source
- Created date
- Import batch

Only include filters supported by available data/backend.

Common behavior should be reusable across Web and Android.

---

# 14. Lead Export / Reports

Where required, support:

- Excel export
- CSV export if requested
- Export filtered results if supported
- Permission-aware export

Do not hard-code report columns until confirmed.

---

# 15. Proposed Lead Development Subparts

Use small checkpoints.

## Lead Phase L0 — Preparation

### L0.1
Inspect current repository and project foundation.

### L0.2
Confirm Lead feature architecture and dependencies.

### L0.3
Create Lead feature base structure.

## Lead Phase L1 — Lead Core

### L1.1
Lead models/entities/interfaces.

### L1.2
Lead repository boundary.

### L1.3
Lead state-management foundation.

### L1.4
Lead mock/test data source if backend is not available.

## Lead Phase L2 — Lead Interface

### L2.1
Lead list UI.

### L2.2
Lead details UI.

### L2.3
Add Lead UI.

### L2.4
Edit Lead UI.

### L2.5
Search/filter/sort.

### L2.6
Responsive Lead UI review.

## Lead Phase L3 — Import

### L3.1
Import architecture.

### L3.2
Excel file selection/import UI.

### L3.3
CSV file selection/import UI.

### L3.4
Import preview.

### L3.5
Validation/error rows.

### L3.6
Duplicate-handling UI.

### L3.7
Import result summary.

## Lead Phase L4 — Lead Distribution

### L4.1
Unassigned lead view.

### L4.2
Agent/user selection.

### L4.3
Single lead assignment.

### L4.4
Bulk lead assignment.

### L4.5
Reassignment.

### L4.6
Assigned-lead views.

### L4.7
Distribution/assignment history.

### L4.8
Distribution permissions.

## Lead Phase L5 — Reports & Export

### L5.1
Export foundation.

### L5.2
Excel export.

### L5.3
CSV export if required.

### L5.4
Filter-aware export.

## Lead Phase L6 — Backend Integration

### L6.1
Inspect instructor backend/API.

### L6.2
Map Lead model to backend response.

### L6.3
Connect Lead list.

### L6.4
Connect Add/Edit Lead.

### L6.5
Connect import.

### L6.6
Connect distribution/assignment.

### L6.7
Connect reassignment/history.

### L6.8
Connect search/filter/pagination.

### L6.9
Connect export if backend-controlled.

## Lead Phase L7 — Testing & Freeze

### L7.1
Functional testing.

### L7.2
Permission testing.

### L7.3
Responsive Android testing.

### L7.4
Responsive Web testing.

### L7.5
Import testing.

### L7.6
Distribution testing.

### L7.7
Backend error testing.

### L7.8
Bug fixing.

### L7.9
Final review.

### L7.10
Lead Module Freeze.

---

# 16. Codex + Antigravity Working Model

No agent owns a complete phase.

Tasks are assigned dynamically.

Example:

```text
L1.1 → Antigravity
L1.2 → Codex

Codex finishes first
      ↓
Next safe task → Codex

Antigravity finishes
      ↓
Next safe task → Antigravity
```

The next task should only be assigned if:

1. Its prerequisites are complete, or
2. It is safe to run in parallel, and
3. Its files do not conflict with another active task.

---

# 17. Agent Task Assignment Format

Use this format for every task:

```md
## Agent Task

**Task:** Lx.x — Task Name

**Agent:** Codex / Antigravity

**Status:** In Progress

### Depends On
- completed prerequisite

### Scope
Exact work required.

### Owns
- exact files/folders that may be modified

### Must Not Touch
- files owned by the other active agent
- unrelated modules
- backend files unless specifically assigned

### Before Work
1. Check `git status`.
2. Inspect latest repository state.
3. Read target files.
4. Confirm no active collision.
5. Report planned files.

### After Work
1. Run relevant analyzer/tests.
2. Report created files.
3. Report modified files.
4. Report unresolved errors.
5. Report collision risks.
6. Check `git status`.
7. Mark task complete.
8. STOP and wait for the next task.
```

---

# 18. File Collision Rules

Both agents use the same repository.

Before every task:

- Check `git status`.
- Inspect current files.
- Do not assume the repository is unchanged.
- Do not overwrite another agent's work.
- Do not refactor unrelated code.
- Do not delete files without approval.
- Do not rename shared files without approval.
- Prefer small/surgical changes.

Shared files need special care, including:

- `pubspec.yaml`
- `main.dart`
- app/router files
- shared theme
- dependency configuration
- shared constants
- shared navigation
- common network configuration

If a shared file is being modified by another agent, report the needed change instead of editing it concurrently.

---

# 19. Important Architecture Rules

## Do

- Follow existing project structure.
- Use shared components.
- Use BLoC/Cubit.
- Use repositories/services.
- Keep responsive layouts reusable.
- Respect role/permission visibility.
- Keep backend integration replaceable.
- Handle loading, empty, error and permission states.
- Keep Android and Web behavior consistent.

## Do Not

- Start another CRM module.
- Add Meta/Facebook lead integrations.
- Add Google Ads lead integrations.
- Create a separate Supabase backend.
- Create a separate Firebase backend.
- Invent API contracts.
- Call Dio directly from UI widgets.
- Mix Lead logic into unrelated modules.
- Add large unrelated refactors.

---

# 20. Current Active Scope

```text
ACTIVE:
Lead Management / Interface
Lead Distribution
Lead Import
Lead Assignment / Reassignment
Lead Search / Filter / Sort
Lead Export
Lead Backend Integration
Lead Testing
```

```text
NOT ACTIVE YET:
Calling
Inventory
Dispatch
Purchase
HR / Payroll
Approvals & Notifications
Vendor Management
```

---

# 21. Definition of Lead Module Complete

Lead Management is not complete only because screens exist.

It is complete when:

- Lead list works.
- Lead details work.
- Manual lead creation works.
- Lead editing works.
- Excel import works.
- CSV import works.
- Import validation works.
- Duplicate handling works according to backend rules.
- Lead distribution works.
- Single assignment works.
- Bulk assignment works if required.
- Reassignment works.
- Permission-based lead access works.
- Search/filter/sort works.
- Export works where required.
- Android layout works.
- Web layout works.
- Backend integration works.
- Error states work.
- Loading states work.
- Empty states work.
- Permission states work.
- Main workflows are tested.
- Critical bugs are fixed.
- Instructor accepts/reviews the module if required.

Only after that:

```text
Lead Management
      ↓
COMPLETE / FROZEN
      ↓
Next CRM Module
```

---

# 22. Current Project Rule

> Work on one CRM business module at a time.

> The current module is Lead Management / Interface, including Lead Distribution.

> Do not begin another CRM business module until the current module is complete and frozen.

> Codex and Antigravity may work simultaneously, but task ownership is temporary and assigned per subpart, not per phase.

> Always protect the shared repository from file collisions.
