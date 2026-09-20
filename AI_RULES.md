# AI RULES — ENTERPRISE CRM

## 1. Project Root
`D:\projects\enterprise_crm`

## 2. Agent Independence
These rules are coding-agent neutral.

They must work with:
- Codex
- Antigravity
- ChatGPT/Work
- IDE coding agents
- future coding assistants

Do not depend on:
- agent-specific memory
- agent-specific artifact folders
- proprietary task managers
- proprietary command wrappers

Use one coding agent at a time unless the user explicitly approves parallel work.

## 3. Architecture
- Flutter Android + responsive Web.
- BLoC/Cubit.
- Dependency direction:
  `UI -> Cubit/BLoC -> Repository -> Service/Data Source -> backend`
- Mock repository/data source is acceptable until instructor backend exists.
- Do not introduce Riverpod, Provider, GetIt, Injectable, Freezed, Supabase, Firebase, or a custom backend unless explicitly approved.

## 4. Backend Boundary
Instructor backend comes later. Do not invent:
- API URLs/endpoints
- JSON contracts
- authentication
- server IDs
- error codes
- database schema

## 5. Lead Intake Scope
Allowed:
- Manual/custom Lead entry
- CSV import
- XLSX/Excel import

Not allowed:
- Meta funnels
- Google funnels
- external marketing funnels

## 6. Lead Status Rule
Do not invent production Lead statuses.

Calling outcomes are separate:
- Follow up
- not connected
- visit scheduled
- Irrelevant
- Not interested
- lead closed
- sales done
- dispatched

## 7. Import Rules
- CSV/XLSX only.
- Mapping targets only: name, phone, email.
- No fuzzy/automatic mapping.
- At least one mapped field.
- Name/phone/email optional.
- Shared email validator for Add/Edit/Import.
- Invalid/blank rows remain visible.
- Exact in-file duplicate detection only.
- Same phone alone != duplicate.
- Same email alone != duplicate.
- Case-insensitive/fuzzy matching not used.
- Duplicate rows remain selected by default.
- No keep-first/keep-last/merge/auto-remove.
- Selected duplicates are imported independently.
- Imported source is CSV/Excel.
- Imported status is null.
- Assignment is not part of import.

## 8. Git Safety
- Keep `.gitignore` unstaged/untouched.
- Restore unrelated generated platform files before commit.
- Do not stage assistant-generated walkthrough/report files unless they are intentionally part of the repository.
- Before commit:
  - `dart format .`
  - `flutter analyze`
  - `flutter test`
  - `git diff --check`
  - `git status`
  - inspect staged diff

## 9. Testing
- Preserve all passing tests.
- Add regression tests for changed invariants.
- Use deterministic mocks/in-memory file content.
- Do not automate native file-picker dialogs.

## 10. Source of Truth
1. Source code
2. Current accepted task instructions
3. `AI_BRAIN.md`
4. `SESSION_MEMORY.md`
5. Older reports

## 11. Change Discipline
- Make the smallest necessary change.
- Do not refactor frozen modules casually.
- Do not change business rules during orchestration tasks.
- Reuse existing utilities/components.
- Keep user-visible counts semantically truthful.

## 12. Handoff Discipline
After a meaningful task:
- commit a clean checkpoint
- update `AI_BRAIN.md`
- update or clear `SESSION_MEMORY.md`
- record only project facts, not assistant-platform details

This allows any future coding agent to continue safely.
