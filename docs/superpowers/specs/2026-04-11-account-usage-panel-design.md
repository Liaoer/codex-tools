# Account Usage Panel Design

**Date:** 2026-04-11

**Goal**

Add a dedicated account usage panel to the Settings page, placed immediately after the runtime configuration section. The panel should list each account's email, plan badge, 5-hour usage, 1-week usage, reset times, and provide a one-click refresh usage action.

**Context**

The current app already fetches account usage through the existing `refresh_all_usage` flow and exposes usage data on each `AccountSummary`. The accounts page shows usage for one selected account per grouped card, but the Settings page does not provide an all-accounts usage overview.

This change should avoid introducing new backend APIs. It should reuse the current account data model, existing refresh action, and current usage formatting helpers where practical.

## Requirements

1. Add a new Settings-page section directly after the runtime configuration section.
2. Show one row per account.
3. The primary account identifier must be `email`.
4. Show the account plan marker (`plus`, `pro`, `team`, `free`, etc.).
5. Show 5-hour used percentage and its reset time.
6. Show 1-week used percentage and its reset time.
7. Add a one-click refresh usage button for the whole list.
8. Preserve existing refresh behavior, loading states, and notice/error handling.

## Proposed Approach

### UI Structure

Insert a new settings group after the runtime-configuration-related controls in `SettingsPanel`.

The new group contains:

1. A compact header area with:
   - section title
   - account count summary
   - one-click refresh usage button
2. A dense list/table-like panel with a sticky or visually distinct header row
3. One row per account with the following columns:
   - email
   - plan
   - 5h used
   - 5h reset time
   - 1w used
   - 1w reset time
4. Optional per-row error text when `usageError` exists

### Data Flow

Reuse current controller state instead of adding a new backend command:

1. `useCodexController` already exposes:
   - `accounts`
   - `refreshUsage`
   - `refreshing`
2. `App.tsx` will pass these values down to `SettingsPanel`.
3. `SettingsPanel` will render a new dedicated component for the account usage panel.
4. The refresh button will call `refreshUsage(false)` so it uses the same full refresh behavior as the top-bar refresh.

### Component Boundaries

Add a new focused component for the usage panel rather than reusing `AccountCard`.

Recommended structure:

- `src/components/AccountUsagePanel.tsx`
  - owns rendering of the settings-side usage overview
  - receives accounts, refreshing state, and refresh handler
- `src/components/SettingsPanel.tsx`
  - inserts the panel in the correct position
- `src/App.tsx`
  - passes through required props

This keeps the existing accounts-page card interactions untouched.

### Display Rules

- Primary identifier: `account.email`
- If `email` is missing, show `--`
- Plan badge text comes from the existing plan formatting helpers
- Percentages use existing usage helpers where possible
- Reset times use localized formatting consistent with current account usage display
- Missing usage data shows `--`
- Accounts with `usageError` remain visible; the error is shown inline for that row

### Sorting

Do not introduce extra sorting controls in this change. Keep the list order aligned with the current sorted `accounts` collection coming from the controller.

This preserves existing account prioritization while keeping the scope focused.

## Error Handling

- No accounts: show a compact empty state inside the panel
- Missing `usage`: render placeholders instead of hiding the row
- Row-level `usageError`: display a muted error message under the row
- Refresh failure: rely on the existing global notice flow from `refreshUsage`

## Styling

The new panel should visually match the Settings page, not the account-card wall.

Styling goals:

- compact table/list density
- readable column alignment
- plan badge styling consistent with existing plan colors
- responsive fallback for narrower widths, likely by stacking row cells into a two-line grid on smaller screens
- localized text should not break the layout

Prefer implementing the styles in the existing settings or account stylesheets only where the selectors stay isolated and do not affect account cards.

## Testing Strategy

No backend behavior change is expected, so verification should focus on frontend integration:

1. Type-check the new props and component wiring
2. Build the app to catch TypeScript and bundling issues
3. Run lint if the repository is already lint-clean enough for signal
4. Manually verify:
   - section placement after runtime configuration
   - one-click refresh button disabled/loading state
   - rows render for multiple accounts
   - placeholders render for missing usage
   - inline row error renders for `usageError`
   - no-account empty state

## Risks

1. `SettingsPanel` currently does not receive account state, so prop expansion must remain tidy
2. Existing CSS may be tightly coupled to current layouts, so selectors should be narrowly scoped
3. Locale files may need new copy keys; missing keys would degrade labels

## Out of Scope

- adding a new backend usage endpoint
- adding per-row refresh
- adding filters, search, or user-configurable sorting
- altering the existing accounts page card behavior
