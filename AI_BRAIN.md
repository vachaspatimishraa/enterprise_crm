# AI BRAIN — ENTERPRISE CRM PRIMARY MEMORY

> Durable compressed memory for `D:\projects\enterprise_crm`.
> This file is intentionally coding-agent neutral.

## Project Identity
**Project:** Enterprise CRM  
**Type:** Flutter CRM for Android + responsive Web  
**Current priority:** Continue Lead Management after freezing the complete Excel/CSV Import phase.  
**Backend:** Instructor-provided/integrated later. Current frontend uses mock repository/data source where backend behavior is not yet defined.

## Tech Stack
- Flutter 3.41.9
- Dart 3.11.5
- BLoC/Cubit (`flutter_bloc`)
- Dio planned for later backend integration
- `file_picker ^13.0.0`
- `csv ^8.0.0`
- `excel ^4.0.6`

Do not introduce Supabase/Firebase/custom backend.
Do not add Riverpod/Provider/GetIt/Injectable/Freezed.

## Architecture
```text
UI
→ Cubit/BLoC
→ Repository
→ Service/Data Source
→ instructor backend (later)
```

## Lead Domain
Lead fields:
- id
- name?
- phone?
- email?
- status?
- source
- assignedUserId?
- assignedUserName?
- createdAt?
- updatedAt?

LeadSource:
- manual
- excel
- csv

LeadStatus is a string value object. Do not invent production statuses.

Calling outcomes are separate from LeadStatus:
- Follow up
- not connected
- visit scheduled
- Irrelevant
- Not interested
- lead closed
- sales done
- dispatched

## Phase Status

### L0 — Preparation & Requirement Freeze
COMPLETE / FROZEN

### L1 — Core Architecture
COMPLETE / FROZEN

### L2 — Lead Interface
COMPLETE / FROZEN
Includes dashboard, list, details, add, edit, responsive layouts.
Delete/archive remains backend/instructor-policy dependent.

### L3 — Search / Filter / Sort / Pagination
COMPLETE / FROZEN

### L4 — Excel / CSV Import
COMPLETE / FROZEN

Subphases:
- L4.1 File Selection — COMPLETE / FROZEN
- L4.2 CSV/XLSX Parsing — COMPLETE / FROZEN
- L4.3 Structure Analysis + Column Discovery — COMPLETE / FROZEN
- L4.4 Column Mapping — COMPLETE / FROZEN
- L4.5 Row Validation + Import Preview — COMPLETE / FROZEN
- L4.6 Exact In-File Duplicate Review — COMPLETE / FROZEN
- L4.7 Structured Import Execution — COMPLETE / FROZEN
- L4.8 End-to-End Workflow Integration — COMPLETE / FROZEN

Final L4 verification:
- commit: `7bc70c0`
- test suite: `524 / 524 PASS`
- analyzer: clean
- shared repository instance verified
- imported Leads visible after workflow success + caller refresh
- system Back blocked during active import execution
- same-filename new-file invalidation verified
- web build verified
- interactive browser file-picker walkthrough was environment-limited, but end-to-end workflow is covered by deterministic automated integration tests

### App Shell Integration Checkpoint
COMPLETE / FROZEN
- App shell connected to `lib/main.dart`
- `main.dart` no longer starter counter (starter counter removed completely)
- Initial screen: `CrmHomeScreen` hosting `LeadDashboardScreen`
- CRM Dashboard/List reachable at runtime
- Navigation between Dashboard, Lead List, Add Lead, Lead Details, Edit Lead, Import Leads
- Single shared `LeadRepository` at app composition root (`MockLeadRepository`)
- Web build verified (`flutter build web` PASS)
- Responsive viewports verified (360x640, 768x1024, 1200x800)
- Checkpoint commit: `54b3b62`
- Test count: `528 / 528 PASS`
- Analyzer: clean (0 issues)

### L5 — Lead Distribution / Assignment
COMPLETE / FROZEN

Subphases:
- L5.1 Assignment State + Reusable Assignee Selector — COMPLETE / FROZEN
  - `LeadAssignmentCubit` & `LeadAssignmentState` implemented
  - Reusable `LeadAssigneeSelector` widget built
  - Constructor injection for `LeadRepository`
  - Safe assignee loading, retry, unknown ID rejection, and empty list handling
  - Single assignment (`assignLead`) and bulk assignment (`assignLeads`) foundation with concurrency guard
  - L5/L6 boundary respected: already-assigned leads rejected
  - Commit: `ddcbc3b`
  - Test suite: `554 / 554 PASS`
  - Analyzer: clean (0 issues)
- L5.2 Single Lead Assignment (Lead Details Integration) — COMPLETE / FROZEN
  - Detail screen assign button for unassigned leads (`!lead.isAssigned`)
  - Modal with short-lived `LeadAssignmentCubit` and `LeadAssigneeSelector`
  - Prevents back/dismiss during submission via `PopScope`
  - Post-assignment detail refresh via `getLeadById`, and caller refresh on return
  - Clean error separation: mutation failure vs reload failure
  - Commit: `b88ebd6`
  - Test suite: `563 / 563 PASS`
  - Analyzer: clean (0 issues)
- L5.3 Bulk Lead Assignment (Lead List Multi-select) — COMPLETE / FROZEN
  - Manual bulk assignment mode on `LeadListScreen` (cards on mobile, table on desktop)
  - Strict eligibility: unassigned leads (`!lead.isAssigned`) only; assigned leads cannot be selected
  - Selection scope: transient presentation state cleared on search, filter, sort, and pagination changes
  - Contextual AppBar showing selection count, Select All / Deselect All for eligible leads, and Assign Leads
  - `BulkAssignLeadsDialog` reuses `LeadAssignmentCubit` and `LeadAssigneeSelector`
  - Concurrency & pop protection: dismissal blocked while mutation pending
  - Mutation success vs refresh failure: dialog closes, selection clears, list refreshes via shared repository
  - Unassigned filter semantics: newly assigned leads naturally filtered out upon repository refresh
  - Commit: `896953c`
  - Test suite: `574 / 574 PASS` (+11 new tests)
  - Analyzer: clean (0 issues)
  - Web build: PASS
- L5.4 Dashboard Lead Distribution Integration — COMPLETE / FROZEN
  - Dashboard `Distribute Leads` quick action connected to manual distribution experience
  - Reuses existing `LeadListScreen`, L5.3 selection mode, `BulkAssignLeadsDialog`, `LeadAssignmentCubit`, `LeadAssigneeSelector`, and `LeadRepository.assignLeads(...)`
  - Strict distribution context: opens `LeadListScreen` in distribution mode (`isDistributionMode: true`)
  - Initialized with `isAssigned = false` query; selection mode active immediately
  - Assignment filter locked to Unassigned in distribution mode (modal hides assignment choices and assignee dropdown, active filter chip delete disabled)
  - Search, sort, and filters preserve `isAssigned = false` invariant
  - Supports multiple distribution batches in one session without closing screen after each batch
  - Route return semantics: tracks `_didAssignAnyLeads` and only reloads Dashboard summary metrics if at least one assignment succeeded
  - Normal Lead List (`Dashboard -> View Leads`) remains completely unaffected (all leads, selection mode inactive initially, ordinary title 'Leads')
  - Commit: `8d6e7a7`
  - Test suite: `587 / 587 PASS` (+13 new tests)
  - Analyzer: clean (0 issues)
  - Web build: PASS
- L5.5 Final End-to-End Verification + L5 Freeze — COMPLETE / FROZEN
  - Comprehensive end-to-end integration regression covering full app lifecycle: Dashboard -> Distribute Leads -> Bulk Assign -> Dashboard summary metric update -> View Leads -> Lead Details -> Single Assign -> caller list refresh -> Dashboard return metric refresh
  - Proved single shared repository instance integrity across all screens
  - Confirmed strict L5/L6 boundary: no reassignment, unassignment, history, auto-distribution, or capacity logic
  - All responsive viewports (320x568, 360x640, 768x1024, 1200x800) and dark theme verified
  - Commit: `1a7d3c6`
  - Test suite: `588 / 588 PASS` (+1 new comprehensive test)
  - Analyzer: clean (0 issues)
  - Web build: PASS (`flutter build web` PASS)

### L6 — Lead Reassignment + History
IN PROGRESS

Strategy Split:
- L6A — Lead Reassignment (Active)
- L6B — Assignment History & Audit Trail (Deferred until instructor/backend contract defines audit schema, persistence, auth identity, and timestamp authority)

Subphases:
- L6A.1 Reassignment State / Cubit Foundation — COMPLETE / FROZEN
  - Dedicated `LeadReassignmentCubit` and `LeadReassignmentState` created
  - Assignable users loading, error handling, reload preservation, and truthful empty state
  - Strict eligibility guard: unassigned leads (`!lead.isAssigned`) rejected from reassignment
  - Client-side same-assignee prevention: selecting current assignee rejected locally as a no-op guard (not a frozen backend policy)
  - Unknown assignee guard: only repository-loaded assignees selectable
  - Reason normalization: trimmed whitespace, blank -> null, optional frontend handling
  - Safe error messages (no raw exceptions leaked)
  - Concurrency protection: duplicate submissions blocked while in-flight
  - State preservation on error for retry
  - No history models, no `changedBy`, no fake timestamps, no unassignment, no bulk reassignment
  - Commit: `6e64c0f`
  - Test suite: `612 / 612 PASS` (+24 new unit tests)
  - Analyzer: clean (0 issues)
- L6A.2 Lead Details Reassign UI — COMPLETE / FROZEN
  - Reassign Lead button added to `LeadDetailsScreen` Assignment section for assigned leads (`lead.isAssigned == true`)
  - Unassigned leads continue to display only `Assign Lead` (never both)
  - Reassignment modal (`_ReassignLeadDialog`) renders current assignee, new assignee selector, and optional reason input
  - Dedicated `LeadReassignmentAssigneeSelector` presentation widget created
  - Current assignee is disabled in dropdown with `(Current)` label (client-side no-op guard, not frozen backend policy)
  - Modal blocks back/barrier dismiss during submission (`PopScope(canPop: !isSubmitting)`)
  - Detail reloaded from repository on success, updating `Assigned To` and preserving `Reassign Lead` action
  - Post-success reload failure distinguished from mutation failure (reassign is not re-executed on retry)
  - Shared repository integration: caller refresh invoked (`onLeadAssigned`), updating Lead List view with new assignee
  - Commit: `8dcd964`
  - Test suite: `624 / 624 PASS` (+12 new tests)
  - Analyzer: clean (0 issues)
  - Web build: PASS (`flutter build web`)
- L6A.3 Reassignment Integration Hardening — COMPLETE / FROZEN
  - Assignee-filtered list regression: reassigning an assigned Lead (Agent One -> Agent Two) drops the Lead from the Agent One filter result and adds it to the Agent Two filter result via repository query semantics
  - Assigned / Unassigned filter invariants: `isAssigned == true` is preserved; reassigned Lead remains visible under Assigned filter (with updated assignee) and never appears under Unassigned filter
  - Dashboard metrics invariant: total assigned and unassigned summary counts are verified identical before and after reassignment
  - Caller refresh failure boundary: when `reassignLead` succeeds but caller `LeadListScreen` refresh throws, reassignment remains committed; list renders load error + retry; retry performs list reload only without repeating reassignment
  - Assignee edge cases: truthful header display when current assignee is missing from `getAssignableUsers()`; Reassign button disabled when replacement choices are empty or only contain current assignee
  - Detail reload not-found handling: subsequent `getLeadById == null` transitions to "Lead not found" without re-running mutation
  - Route cancellation verified: Cancel before submit leaves Lead unchanged with zero repository mutations
  - Shared repository identity verified across routes with persistent route transitions
  - Commit: `d5f3a2c`
  - Test suite: `634 / 634 PASS` (+10 new tests: 5 in widget_test, 5 in details_screen_test)
  - Analyzer: clean (0 issues)
  - Web build: PASS (`flutter build web`)
- L6A.4 Final Verification & Freeze — COMPLETE / FROZEN
  - Final verification of single lead reassignment flow across repository, Cubit, UI, filters, dashboard, and failure boundaries
  - Zero production code modifications required; existing architecture proved robust
  - All 634 tests pass, analyzer clean, Web build pass
  - Final checkpoint commit: `d5f3a2c`
  - L6A Lead Reassignment is fully frozen

### L7 — Lead Export / Reporting
IN PROGRESS

Strategy Split:
- L7A — Lead Export (Active)
- L7B — Advanced Reporting / Analytics (Deferred pending backend/instructor contracts for date-range reporting, conversion metrics, agent KPIs, and PDF generation)

Subphases:
- L7A.1 Lead Export Serialization Foundation — COMPLETE / FROZEN
  - Reusable in-memory `DefaultLeadExportSerializer` implementing `LeadExportSerializer`
  - Strongly typed `LeadExportContent` (bytes, extension, mimeType)
  - Supported formats: CSV (`text/csv`, UTF-8 via `package:csv`) and XLSX (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` via `package:excel`)
  - Frozen frontend column policy:
    1. Name
    2. Phone
    3. Email
    4. Status
    5. Source
    6. Assigned To
    7. Created At
    8. Updated At
  - Strictly excluded internal identifiers: `id`, `assignedUserId`
  - Phone numbers preserved as text (leading zeroes and `+` preserved, never parsed to numeric)
  - Dates formatted as ISO-8601 strings; null values formatted as empty cells (never literal "null" or "N/A")
  - Canonical representations: `lead.status?.value` (raw string), `lead.source.name` (`manual`, `excel`, `csv`)
  - Empty lead list produces valid headers-only file
  - Deterministic row ordering matching input list (no query, filter, sort, or pagination logic in serializer)
  - Zero UI, repository, or file-saving changes
  - Commit: `6473fac`
  - Test suite: `650 / 650 PASS` (+16 new unit tests)
  - Analyzer: clean (0 issues)
- L7A.2 Repository Export Integration — COMPLETE / FROZEN
  - Replaced mock export placeholder in `MockLeadDataSource` with real query-filtered export pipeline
  - Extracted `_resolveMatchingLeads(LeadQuery)` sharing identical L3 search, filter, and sort logic between `getLeads` and `exportLeads`
  - Critical query policy: export ignores pagination and processes ALL matching leads
  - `LeadExportResult` returns typed `LeadExportContent` as opaque `fileReference`
  - Filename conventions: `leads_export.csv` and `leads_export.xlsx`
  - Constructor injection of `LeadExportSerializer` in `MockLeadDataSource` and `MockLeadRepository`
  - Comprehensive coverage: search, sources, status, assignment, assignee, unpaginated export across multi-page datasets, all sort orders, zero matching results, current assignee truthfulness for reassigned leads, serializer error propagation, summary invariance
  - Commit: `50c7fb9`
  - Test suite: `663 / 663 PASS` (+13 new integration tests, 1 updated placeholder test)
  - Analyzer: clean (0 issues)
  - Web build: PASS (`flutter build web`)
- L7A.3 File Delivery / Save — COMPLETE
  - Built cross-platform lead export delivery infrastructure: `LeadExportFileSaver` and `DefaultLeadExportFileSaver`
  - Testable adapter: `ExportSavePicker` with `FilePickerExportSavePicker` calling `FilePicker.saveFile(...)`
  - Strict validation of `result.fileReference is LeadExportContent` with explicit `UnsupportedError` on mismatch
  - Outcome modeling: `LeadExportSaveResult` distinguishing `saved` (with URI) vs `cancelled` (user dismiss) without exceptions
  - Forwards exact unmutated bytes, MIME type, extension, and filename to picker
  - Platform/plugin exceptions bubble up naturally
  - Zero `dart:io`, `dart:html`, `package:web`, or manual anchor/Blob code
  - Test suite: `672 / 672 PASS` (+9 new unit tests)
  - Analyzer: clean (0 issues)
  - Web build: PASS (`flutter build web`)
- L7A.4 Export UI Integration — UPCOMING
- L7A.5 Final Verification / Freeze — UPCOMING

### NEXT
L7A.4 — Export UI Integration

Subsequent milestones:
- L6B Assignment History (Deferred pending backend/instructor contract)
- L8 Instructor Backend Integration + Testing + Final Freeze

## Import Workflow — FROZEN

Visible workflow:

```text
Lead UI
→ Select File
→ Parse
→ Structure
→ Mapping
→ Preview
→ Duplicate Review
→ Execution
→ Result
→ return to Lead UI
→ refresh
```

Frozen rules:
- CSV/XLSX only
- mapping targets only: name, phone, email
- at least one mapping required
- Name/Phone/Email optional
- shared email validator across Add/Edit/Import
- invalid/blank rows remain visible
- exact in-file duplicate detection among valid rows only
- same phone alone != duplicate
- same email alone != duplicate
- no fuzzy/case-normalized duplicate inference
- duplicate rows selected by default
- user controls include/exclude
- no keep-first/keep-last/merge/auto-remove
- selected duplicates import independently
- imported source = CSV/Excel
- imported status = null
- no assignment during import

## Import Contract
`LeadImportRequest` supports:
- legacy file-reference mode
- structured immutable `List<LeadDraft>` mode

Structured rules:
- empty draft requests rejected
- request file type and draft source must agree
- selected rows only
- sourceRowIndex identities must be unique
- source row order preserved
- preparation failure = safe non-retriable
- repository/runtime failure = safe retriable
- negative result counts rejected
- no artificial count-sum reconciliation

Result UI separates:
- Review Summary: valid / selected / excluded / invalid / blank
- Importer Result: total submitted / imported / skipped / failed / reported duplicates

## L4.8 Integration Decisions — FROZEN
- workflow coordinator orchestrates only
- fresh file selection always clears all downstream artifacts
- parse retry reuses the same selected file
- upstream changes invalidate dependent downstream artifacts
- valid upstream state is preserved on Back
- active execution blocks system Back
- successful result is terminal for that workflow instance
- all permitted exits after success return success to caller
- Lead List refreshes after successful import
- Dashboard reloads after successful import
- same repository instance is used for import and caller refresh
- same-filename file replacement cannot reuse stale data
- no new dependencies introduced
- L4.1–L4.7 business rules remained frozen

## Important Import Files
```text
lib/features/leads/domain/entities/
  lead.dart
  lead_source.dart
  lead_status.dart
  lead_draft.dart
  lead_import.dart

lib/features/leads/domain/repositories/
  lead_repository.dart

lib/features/leads/data/datasources/
  mock_lead_data_source.dart

lib/features/leads/data/repositories/
  mock_lead_repository.dart

lib/features/leads/presentation/models/
  lead_import_selected_file.dart
  lead_import_parsed_file.dart
  lead_import_structure_analysis.dart
  lead_import_column_mapping.dart
  lead_import_preview.dart
  lead_import_review.dart

lib/features/leads/presentation/services/
  lead_import_file_picker.dart
  lead_import_parser.dart
  lead_import_structure_analyzer.dart
  lead_import_preview_builder.dart
  lead_import_duplicate_detector.dart
  lead_import_execution_request_builder.dart

lib/features/leads/presentation/bloc/
  lead_import_parse_cubit.dart
  lead_import_structure_cubit.dart
  lead_import_mapping_cubit.dart
  lead_import_preview_cubit.dart
  lead_import_review_cubit.dart
  lead_import_execution_cubit.dart
  lead_import_workflow_cubit.dart
  lead_import_workflow_state.dart

lib/features/leads/presentation/screens/
  lead_import_screen.dart
  lead_import_structure_screen.dart
  lead_import_mapping_screen.dart
  lead_import_preview_screen.dart
  lead_import_review_screen.dart
  lead_import_execution_screen.dart
  lead_import_result_screen.dart
  lead_import_workflow_screen.dart
  lead_list_screen.dart
  lead_dashboard_screen.dart
```

## Lead List / Query Behavior
Mock query pipeline:
```text
source
→ search
→ filters
→ sort
→ pagination
```

Search:
- name / phone / email
- case-insensitive substring

Sorts:
- Default
- Name A-Z
- Name Z-A
- Newest Created
- Oldest Created

Null/blank names last.
Null createdAt last.
Tie-break by ID ascending.

## Important Commits
Recent meaningful checkpoints:
- `0ecb6a0` — Connect lead export UI (L7A.4)
- `ed139e7` — Implement cross-platform lead export file delivery (L7A.3)
- `50c7fb9` — Implement lead repository export integration (L7A.2)
- `6473fac` — Implement lead export serialization foundation (L7A.1)
- `d5f3a2c` — Harden lead reassignment integration (L6A.3)
- `8dcd964` — Add lead details reassignment UI (L6A.2)
- `6e64c0f` — Add lead reassignment foundation cubit and state (L6A.1)
- `1a7d3c6` — Verify full lead distribution and assignment lifecycle (L5.5)
- `8d6e7a7` — Integrate dashboard manual lead distribution (L5.4)
- `896953c` — Implement bulk lead assignment from lead list (L5.3)
- `b88ebd6` — Add single lead assignment (L5.2)
- `ddcbc3b` — Add lead assignment foundation (L5.1)
- `54b3b62` — Integrate CRM application shell to main.dart
- `7bc70c0` — Verify lead import workflow integration

## Git Safety
- Branch: `main`
- Remote: `https://github.com/vachaspatimishraa/enterprise_crm.git`
- `.gitignore` is an unrelated local modification; keep it unstaged and untouched.
- Restore unrelated generated platform changes before commit.
- Do not stage assistant-generated reports/walkthrough files unless intentionally tracked.

## Open Decisions / Known Issues
- Lead delete/archive semantics await instructor/backend policy.
- Existing-CRM duplicate policy is undefined.
- Production Lead status vocabulary is undefined.
- Backend transport/API/auth/schema is undefined.
- L6B assignment history is deferred pending instructor/backend contract.
- L7B advanced reporting/analytics is deferred pending backend/instructor contract.
- Same-assignee prevention is a client-side no-op guard, not a frozen backend policy.

## Current Task Context
Current status:
**UI FIX CHECKPOINT — Bug Fix & Dashboard Navigation Patch (COMPLETE).**
- FIX 1: Import Leads screen freeze fixed (root cause: `maybePop(false)` inside `PopScope(canPop: false)` caused infinite recursive pop loop; corrected to `Navigator.of(context).pop(false)`).
- FIX 2: Lead Details duplicate top-right edit pencil removed; main `Edit Lead` button retained and verified.
- FIX 3: All 6 Dashboard Summary / Overview cards clickable, navigating to Lead List via `initialQuery` (`Total -> LeadQuery()`, `Assigned -> LeadQuery(isAssigned: true)`, `Unassigned -> LeadQuery(isAssigned: false)`, `Manual -> LeadQuery(source: LeadSource.manual)`, `Excel -> LeadQuery(source: LeadSource.excel)`, `CSV -> LeadQuery(source: LeadSource.csv)`), filter UI synchronized, shared repository preserved.
- All 734 tests pass (710 baseline + 24 new), analyzer clean (0 issues), Web build pass.
- L8 remains: WAITING FOR INSTRUCTOR BACKEND CONTRACT.

## Last Session Summary
UI FIX CHECKPOINT completed with zero changes to frozen business rules or backend contract. All three bug fixes verified across unit, widget, integration, responsive viewports, and dark theme. L0-L7A remain FROZEN; L8 remains awaiting instructor backend contract.

## Portability Policy
Do not store durable references to a specific coding assistant.
Any future coding agent should be able to continue using only:
- repository source
- `AI_RULES.md`
- this file
- `SESSION_MEMORY.md`
- git history
