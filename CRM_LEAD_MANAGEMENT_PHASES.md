# CRM Lead Management / Interface — Development Phases

## 1. Purpose

This document defines the complete development roadmap for the **Lead Management / Interface** module.

The current project rule is:

> **Lead Management / Interface, including Lead Distribution, is the only active CRM business module. We will not move to Calling, Inventory, Dispatch, Purchase, HR/Payroll, Approvals & Notifications, or Vendor Management until Lead Management is fully completed, integrated, tested, reviewed, and frozen.**

---

# 2. Current Project Decisions

## Frontend

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

- Backend will be provided/integrated by the instructor through GitHub.
- Do not create a separate Supabase backend.
- Do not create a separate Firebase backend.
- Do not invent undocumented API endpoints or backend fields.
- Backend logic must not be called directly from UI widgets.

Preferred structure:

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

Before backend is available:

```text
UI
 ↓
BLoC / Cubit
 ↓
Repository
 ↓
Temporary Mock / Test Data Source
```

The mock layer must be replaceable without rewriting the UI.

## Lead Sources

Use only:

- Manual/custom lead entry
- Excel import
- CSV import

Do not implement:

- Meta/Facebook lead integration
- Google Ads lead integration
- External advertising funnels
- Lead webhooks from ad platforms

---

# 3. Lead Management Module Roadmap

```text
L0 — Preparation & Requirement Freeze
 ↓
L1 — Lead Core Architecture
 ↓
L2 — Lead Interface
 ↓
L3 — Search / Filter / Sort
 ↓
L4 — Excel / CSV Import
 ↓
L5 — Lead Distribution
 ↓
L6 — Reassignment / Distribution History
 ↓
L7 — Export / Reporting
 ↓
L8 — Backend Integration / Testing / Freeze
```

---

# Phase L0 — Preparation & Requirement Freeze

## Goal

Make sure both agents understand the current repository, project foundation, exact Lead Management scope, and architectural boundaries before implementation starts.

---

## L0.1 — Repository Audit

### Tasks

- Check `git status`
- Inspect the current Flutter project structure
- Inspect `pubspec.yaml`
- Inspect existing:
  - theme
  - routing
  - shared widgets
  - responsive helpers
  - BLoC/Cubit conventions
  - repository/network layers
  - feature structure
- Identify files already modified
- Identify active work from the other agent
- Identify possible collision risks

### Deliverable

A short repository audit report containing:

1. Current architecture
2. Relevant existing files
3. Shared components available
4. Existing routing/state/network setup
5. Files Lead Management may need
6. Current risks/conflicts

### Exit Criteria

- Repository state is understood
- No file collision risk is ignored
- No implementation starts before the audit is complete

---

## L0.2 — Lead Requirement Freeze

### Confirmed Current Scope

```text
Manual Lead Entry
Excel Import
CSV Import
Lead List
Lead Details
Lead Edit
Lead Distribution
Lead Assignment
Lead Reassignment
Search
Filter
Sort
Export
Permission-based Lead Access
Responsive Android + Web
```

### Explicitly Out of Current Scope

```text
Meta Leads
Google Ads
External Lead Funnels
Calling Module
Inventory
Dispatch
Purchase
HR / Payroll
Approvals & Notifications
Vendor Management
```

### Exit Criteria

- Current Lead scope is agreed
- No other CRM module is mixed into Lead work

---

## L0.3 — Lead Architecture Plan

### Define

```text
Lead Entity / Model
Lead Repository
Lead Data Source
Lead Cubit / Bloc
Lead Screens
Lead Widgets
Lead Import
Lead Distribution
```

### Suggested Feature Area

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

Follow the actual approved project structure. Do not create unnecessary layers just to match this example.

### Exit Criteria

- Feature boundaries are clear
- Both agents follow the same architecture
- No duplicate parallel architecture is created

---

# Phase L1 — Lead Core Architecture

## Goal

Create the reusable Lead domain/data/state foundation before building the full UI.

---

## L1.1 — Lead Entity / Model

### Prepare Frontend Representation

Possible frontend fields may include:

```text
id
name
phone
email
status
source
assignedUser
createdAt
updatedAt
```

### Important Rule

Do not invent final backend JSON names or mandatory backend fields.

### Exit Criteria

- Frontend Lead representation exists
- Field naming is isolated from backend mapping
- Model/entity structure follows current architecture

---

## L1.2 — Lead Repository Contract

### Conceptual Capabilities

```text
getLeads()
getLead()
createLead()
updateLead()
assignLead()
reassignLead()
importLeads()
exportLeads()
```

These are **frontend capabilities**, not API URLs.

### Important Rule

Do not invent endpoints such as:

```text
/api/leads
/api/leads/assign
```

unless the instructor backend actually defines them.

### Exit Criteria

- UI/state layer can depend on an abstract repository
- Backend implementation can be swapped later

---

## L1.3 — Data Source Boundary

### Expected Flow

```text
LeadRepository
      ↓
LeadRemoteDataSource
      ↓
Instructor Backend
```

Before backend integration:

```text
LeadRepository
      ↓
MockLeadDataSource
```

### Exit Criteria

- Backend-specific logic is isolated
- UI does not know whether data is mock or real

---

## L1.4 — Lead State Management

### Prepare States for

```text
initial
loading
loaded
empty
failure
creating
updating
assigning
importing
exporting
```

Use the project’s established BLoC/Cubit conventions.

### Exit Criteria

- State flow is reusable across Lead screens
- Loading/error/empty states are standardized

---

## L1.5 — Mock / Test Dataset

### Tasks

Create only enough temporary data to support:

- list
- details
- create/edit simulation
- assignment simulation
- filter/search UI
- responsive testing

### Important Rule

Mock data must not become production logic.

### Exit Criteria

- Lead UI can be developed before backend integration
- Mock layer can later be removed or replaced cleanly

---

# Phase L2 — Lead Interface

## Goal

Build the main Lead Management screens.

---

## L2.1 — Lead Dashboard / Summary

### Possible Metrics

```text
Total Leads
Assigned
Unassigned
New
```

Only implement metrics supported by requirements/backend.

### Exit Criteria

- Summary layout works on Web and Android
- Metrics are not hard-coded into permanent business logic

---

## L2.2 — Lead List

### Requirements

- Lead display
- Search entry point
- Filter entry point
- Sort entry point
- Pagination if required
- Select lead
- Multi-select where bulk actions are allowed
- Open lead details
- Permission-aware actions

### Responsive Behavior

Web:

```text
Table / Data Grid
```

Mobile:

```text
Card / List
```

### Exit Criteria

- Lead list works with current repository
- Web and mobile presentations are usable

---

## L2.3 — Lead Details

### Possible Sections

```text
Lead Information
Assignment
Status
Created / Updated Info
History if supported
```

### Important Rule

Do not add unsupported business data.

### Exit Criteria

- Lead details open correctly from list
- Data and actions are permission-aware

---

## L2.4 — Add Lead

### Requirements

- Manual/custom lead entry form
- Validation
- Required fields
- Loading state
- Success state
- Error state
- Duplicate result handling according to backend rules

### Important Rule

Do not invent final mandatory fields before confirmation.

### Exit Criteria

- Manual lead creation flow works through repository/mock layer

---

## L2.5 — Edit Lead

### Requirements

- Existing values shown
- Validation
- Save/update state
- Error handling
- Permission check

Reuse Add Lead form components where practical.

### Exit Criteria

- Lead update flow works
- No unnecessary duplicate form architecture

---

## L2.6 — Delete / Archive Behavior

Implement only if the instructor/backend allows it.

Do not assume hard delete is supported.

### Exit Criteria

- No unsupported delete behavior is added

---

## L2.7 — Responsive Review

Check:

```text
Mobile
Tablet
Desktop Web
Large Web
```

### Exit Criteria

- Core Lead UI remains usable across supported widths

---

# Phase L3 — Search, Filter & Sort

## Goal

Make Lead Management usable for larger datasets.

---

## L3.1 — Search

Possible searchable values:

```text
Name
Phone
Lead ID
```

Only support fields available from backend/data.

### Exit Criteria

- Search UX is clear
- Search state is separated from raw UI widgets

---

## L3.2 — Filters

Possible filters:

```text
Status
Assigned User
Assigned / Unassigned
Source
Date Range
Import Batch
```

Only include supported filters.

### Exit Criteria

- Filters can be combined cleanly
- Active filters are visible to the user

---

## L3.3 — Sorting

Possible sorting:

```text
Newest
Oldest
Name
Updated Date
```

### Exit Criteria

- Sort selection affects current list state predictably

---

## L3.4 — Pagination

Prepare UI/repository support only if backend/data volume requires it.

### Exit Criteria

- Pagination logic is not hard-coded into widgets

---

## L3.5 — Filter State Persistence

If useful, keep current filters when returning from Lead Details.

### Exit Criteria

- Navigation does not unnecessarily reset the working list state

---

# Phase L4 — Excel & CSV Import

## Goal

Implement bulk lead input.

---

## L4.1 — Import Entry UI

```text
Import Leads
   ↓
Choose Excel / CSV
```

### Exit Criteria

- Import entry point is clear and permission-aware

---

## L4.2 — File Selection

Support accepted formats only.

### Exit Criteria

- Unsupported file types are rejected cleanly

---

## L4.3 — File Validation

Validate:

```text
File Type
Empty File
Required Columns
Invalid Format
```

### Exit Criteria

- User receives understandable validation feedback

---

## L4.4 — Import Preview

Example:

```text
150 Rows Found

Valid: 142
Invalid: 5
Duplicate: 3
```

### Exit Criteria

- User can review the import before final submission where supported

---

## L4.5 — Column Mapping

Only if required.

Example:

```text
Excel Column       CRM Field

Customer Name  →   Lead Name
Mobile No      →   Phone
```

### Exit Criteria

- Mapping UI is reusable for Excel/CSV where possible

---

## L4.6 — Invalid Row Handling

Display:

- row number
- field
- reason
- correction guidance where possible

### Exit Criteria

- Invalid rows do not fail silently

---

## L4.7 — Duplicate Handling

Must follow backend/business rules.

Possible actions may include:

```text
Skip
Update Existing
Reject
```

Do not choose one as final without confirmation.

### Exit Criteria

- Duplicate handling is explicit and backend-compatible

---

## L4.8 — Import Execution

### Exit Criteria

- Import runs through repository/service boundary
- UI prevents accidental duplicate submission

---

## L4.9 — Import Result

Show:

```text
Imported
Skipped
Failed
Duplicates
```

### Exit Criteria

- Final result is understandable and actionable

---

## L4.10 — Import History

Only if backend supports it.

### Exit Criteria

- No unsupported history feature is invented

---

# Phase L5 — Lead Distribution

## Goal

Distribute unassigned leads to authorized users/agents.

Lead Distribution is a **core part of the current module**, not an optional feature.

---

## L5.1 — Unassigned Lead Pool

Dedicated view/filter for unassigned leads.

### Exit Criteria

- Authorized users can clearly identify unassigned leads

---

## L5.2 — Agent / User List

Show only users provided/allowed by backend.

### Exit Criteria

- No hard-coded permanent agent list
- Selection respects access rules

---

## L5.3 — Single Lead Assignment

Workflow:

```text
Lead
 ↓
Assign
 ↓
Select User
 ↓
Confirm
```

### Exit Criteria

- One lead can be assigned safely

---

## L5.4 — Bulk Lead Selection

Support multi-select where required.

### Exit Criteria

- Bulk selection is usable on Web and Android

---

## L5.5 — Bulk Assignment

Example:

```text
25 Leads Selected

Assign To:
Sales Agent A

[Confirm]
```

### Exit Criteria

- Multiple leads can be assigned in one operation if backend supports it

---

## L5.6 — Assignment Confirmation

Prevent accidental distribution.

### Exit Criteria

- User confirms assignment before final action

---

## L5.7 — Assigned Lead Views

For Admin/Manager:

```text
Agent A → 35 Leads
Agent B → 42 Leads
```

For Sales Agent:

```text
My Leads
```

### Exit Criteria

- Assigned users can access only appropriate lead views

---

## L5.8 — Distribution Result State

Handle:

```text
success
partial success
failure
```

### Exit Criteria

- Partial assignment failures are visible and recoverable

---

## L5.9 — Distribution Permission Enforcement

Only authorized users should see assignment/distribution controls.

### Important Rule

Frontend visibility is not security. Backend authorization remains authoritative.

### Exit Criteria

- Unauthorized users cannot perform distribution through normal UI
- Backend restrictions are respected once integrated

---

# Phase L6 — Reassignment & Distribution History

## Goal

Allow authorized users to correct and track lead ownership after initial distribution.

---

## L6.1 — Reassign One Lead

```text
Current Agent
      ↓
Reassign
      ↓
New Agent
```

### Exit Criteria

- One lead can be reassigned safely

---

## L6.2 — Bulk Reassignment

Only if required.

### Exit Criteria

- No unsupported bulk behavior is introduced

---

## L6.3 — Reassignment Confirmation

### Exit Criteria

- Accidental reassignment is prevented

---

## L6.4 — Assignment History

If backend supports it, possible fields:

```text
Previous User
New User
Assigned By
Date / Time
Reason
```

### Exit Criteria

- History is backend-driven and traceable

---

## L6.5 — Distribution History Screen

Authorized users only.

### Exit Criteria

- Distribution history is visible without exposing unauthorized data

---

## L6.6 — Agent Workload View

Optional if instructor wants distribution visibility.

Example:

```text
Agent A   45 Leads
Agent B   31 Leads
Agent C   52 Leads
```

Do not build automatic balancing unless requested.

### Exit Criteria

- Workload view exists only if supported/approved

---

# Phase L7 — Export & Reporting

## Goal

Provide required Lead Management export/reporting capability.

---

## L7.1 — Export Action

### Exit Criteria

- Export entry point exists for authorized users

---

## L7.2 — Excel Export

Required for Lead Management.

### Exit Criteria

- Lead data can be exported to Excel according to backend/project rules

---

## L7.3 — CSV Export

Use if included in the agreed scope.

### Exit Criteria

- CSV export follows the same permission/filter behavior as Excel where applicable

---

## L7.4 — Filtered Export

Example:

```text
Filter:
Assigned Agent = Rahul
Status = New

Export Current Results
```

### Exit Criteria

- Export respects active filter state if supported

---

## L7.5 — Export Permission

Not every user automatically receives export permission.

### Exit Criteria

- Export action follows permission rules

---

## L7.6 — Export Loading / Error State

### Exit Criteria

- Large/failed exports do not leave the UI in an unclear state

---

# Phase L8 — Backend Integration, Testing & Freeze

## Goal

Convert the module from frontend/mock implementation into a complete working Lead Management module.

---

## L8.1 — Backend Inspection

Inspect the instructor backend/API first.

Do not guess.

### Exit Criteria

- Real backend behavior is understood before mapping

---

## L8.2 — Map Lead Models

Map actual backend responses to frontend models/entities.

### Exit Criteria

- Backend field names remain isolated from UI where possible

---

## L8.3 — Connect Lead List

### Exit Criteria

- Lead list uses real backend data

---

## L8.4 — Connect Lead Details

### Exit Criteria

- Lead details use real backend data

---

## L8.5 — Connect Create / Edit

### Exit Criteria

- Add/Edit operations work against real backend

---

## L8.6 — Connect Search / Filter / Pagination

### Exit Criteria

- Query behavior matches backend capabilities

---

## L8.7 — Connect Excel / CSV Import

### Exit Criteria

- Import follows real backend validation/business rules

---

## L8.8 — Connect Lead Distribution

### Exit Criteria

- Assignment uses real backend authorization and data

---

## L8.9 — Connect Reassignment

### Exit Criteria

- Reassignment is persisted correctly

---

## L8.10 — Connect History

Only if backend supports it.

### Exit Criteria

- No fake history remains in production path

---

## L8.11 — Connect Export

### Exit Criteria

- Export is connected to the correct implementation

---

## L8.12 — Permission Testing

Test at minimum:

```text
Administrator
Manager / Authorized Distributor
Sales Agent
Unauthorized User
```

Use actual role names once backend defines them.

### Exit Criteria

- Permission behavior is verified

---

## L8.13 — Android Testing

### Exit Criteria

- Main Lead workflows work on Android

---

## L8.14 — Web Testing

### Exit Criteria

- Main Lead workflows work on responsive Web

---

## L8.15 — Error Testing

Test:

```text
No Internet
Timeout
Server Error
Validation Error
Unauthorized
Forbidden
Bad File
Partial Import
Assignment Failure
```

### Exit Criteria

- Failure states are understandable and recoverable

---

## L8.16 — Bug Fixing

### Exit Criteria

- Critical/high-priority issues are resolved

---

## L8.17 — Final Lead Review

Review:

- architecture
- UI consistency
- permissions
- responsive behavior
- backend integration
- import
- distribution
- export
- error handling
- analyzer/tests

### Exit Criteria

- No known blocker remains

---

## L8.18 — Lead Module Freeze

Mark:

```text
Lead Management / Interface
Status: COMPLETE / FROZEN
```

Only after this should the project move to the next CRM module.

---

# 4. Codex + Antigravity Working Model

No agent permanently owns a complete phase.

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

A task may be assigned only if:

1. Its prerequisites are complete, or it is explicitly safe in parallel
2. It is not already assigned
3. Its files do not conflict with the other active task
4. The agent has inspected the latest repository state

---

# 5. File Collision Rules

Before every task:

- Check `git status`
- Inspect current target files
- Do not assume repository state is unchanged
- Do not overwrite another agent's work
- Do not perform unrelated refactors
- Do not delete or rename shared files without approval
- Prefer small/surgical changes

Shared files require special care:

```text
pubspec.yaml
main.dart
app/router files
theme
shared widgets
dependency configuration
shared constants
network configuration
```

If another agent is currently editing a required shared file, report the needed change instead of editing it concurrently.

---

# 6. Reusable Agent Task Template

```md
## Agent Task

**Task:** Lx.x — Task Name

**Agent:** Codex / Antigravity

**Status:** In Progress

### Depends On
- completed prerequisite(s)

### Scope
Exact work required.

### Owns
- exact files/folders that may be modified

### Must Not Touch
- files owned by the other active agent
- unrelated CRM modules
- backend files unless explicitly assigned

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

# 7. Definition of Lead Module Complete

Lead Management is complete only when:

- Lead list works
- Lead details work
- Manual lead creation works
- Lead editing works
- Search/filter/sort works
- Excel import works
- CSV import works
- Import validation works
- Duplicate handling follows backend rules
- Lead distribution works
- Single assignment works
- Bulk assignment works if required
- Reassignment works
- Distribution history works if supported
- Permission-based access works
- Excel export works
- CSV export works if required
- Android layout works
- Web layout works
- Backend integration works
- Loading states work
- Empty states work
- Error states work
- Permission states work
- Import edge cases are tested
- Distribution edge cases are tested
- Critical bugs are fixed
- Final review is complete

Then:

```text
Lead Management / Interface
        ↓
COMPLETE / FROZEN
        ↓
Next CRM Module
```
