# Account Usage Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated account usage panel to the Settings page, immediately after the runtime configuration section, showing all accounts' usage details and a one-click refresh button.

**Architecture:** Reuse the existing `AccountSummary` usage data and `refreshUsage` controller action instead of adding a new backend API. Wire the account list and refresh handler from `App.tsx` into `SettingsPanel`, then render a new focused `AccountUsagePanel` component that owns the dense list UI and empty/error states.

**Tech Stack:** React 19, TypeScript, Vite, Tauri, existing i18n JSON catalogs, CSS modules via project stylesheet files

---

### Task 1: Plan Prop Wiring And View Contract

**Files:**
- Modify: `src/App.tsx`
- Modify: `src/components/SettingsPanel.tsx`
- Modify: `src/types/app.ts` (only if new prop-facing helper types are needed)

- [ ] **Step 1: Define the failing expectation**

The Settings page currently cannot render an all-accounts usage section because it does not receive `accounts`, `refreshing`, or `refreshUsage`.

- [ ] **Step 2: Confirm the current component contract**

Run: `Get-Content src/App.tsx`
Run: `Get-Content src/components/SettingsPanel.tsx`
Expected: `SettingsPanel` props do not include account usage inputs yet.

- [ ] **Step 3: Write the minimal prop wiring**

Update `App.tsx` so the Settings tab passes:
- `accounts`
- `refreshing`
- `onRefreshUsage`

Update `SettingsPanel.tsx` prop types to accept those values.

- [ ] **Step 4: Verify the wiring compiles conceptually**

Run: `npm run build`
Expected: Type errors, if any, should now point only to the missing new panel component or missing UI references.

- [ ] **Step 5: Commit checkpoint**

```bash
git add src/App.tsx src/components/SettingsPanel.tsx
git commit -m "feat: wire settings usage panel props"
```

### Task 2: Implement Account Usage Panel UI

**Files:**
- Create: `src/components/AccountUsagePanel.tsx`
- Modify: `src/components/SettingsPanel.tsx`
- Modify: `src/utils/usage.ts` (only if a shared formatting helper is justified)

- [ ] **Step 1: Define the failing expectation**

The Settings page needs a dedicated usage panel that lists:
- email
- plan badge
- 5-hour used percentage
- 5-hour reset time
- 1-week used percentage
- 1-week reset time
- inline row-level usage errors
- one-click refresh button

- [ ] **Step 2: Implement the component with existing helpers**

Create `src/components/AccountUsagePanel.tsx` with:
- header/title/count/refresh button
- empty state
- column header row
- row rendering for each account using `email` as the primary identifier
- existing plan formatting and percent/reset formatting where possible

- [ ] **Step 3: Insert the panel after runtime configuration**

Render the new component inside `SettingsPanel.tsx` immediately after the runtime-configuration-related settings block and before project-info content.

- [ ] **Step 4: Verify the UI compiles**

Run: `npm run build`
Expected: Build succeeds with the new component imported and rendered.

- [ ] **Step 5: Commit checkpoint**

```bash
git add src/components/AccountUsagePanel.tsx src/components/SettingsPanel.tsx src/utils/usage.ts
git commit -m "feat: add settings account usage panel"
```

### Task 3: Add Copy And Styling

**Files:**
- Modify: `src/i18n/locales/en-US.json`
- Modify: `src/i18n/locales/zh-CN.json`
- Modify: `src/i18n/locales/ja-JP.json`
- Modify: `src/i18n/locales/ko-KR.json`
- Modify: `src/i18n/locales/ru-RU.json`
- Modify: `src/styles/accounts.css` or `src/App.css` / other existing settings stylesheet with isolated selectors

- [ ] **Step 1: Define the failing expectation**

The panel needs localized labels and isolated styles for:
- title
- refresh button text
- account count
- column labels
- empty state copy

- [ ] **Step 2: Add copy keys**

Add localized keys for the new panel in each locale JSON file, following the existing settings/i18n structure.

- [ ] **Step 3: Add isolated styling**

Style the panel so it matches the Settings page:
- compact section shell
- list/table header
- aligned columns
- responsive row layout
- plan badge presentation
- row error styling

- [ ] **Step 4: Verify lint/build**

Run: `npm run build`
Run: `npm run lint`
Expected: build passes; lint passes or exposes only pre-existing unrelated issues that should be reported explicitly.

- [ ] **Step 5: Commit checkpoint**

```bash
git add src/i18n/locales/*.json src/styles/*.css
git commit -m "feat: style and localize account usage panel"
```

### Task 4: Final Verification

**Files:**
- Review only: changed files from Tasks 1-3

- [ ] **Step 1: Re-read changed files for regressions**

Check:
- settings panel ordering is correct
- refresh button uses existing loading state
- account identifier is email, not label
- missing usage shows `--`
- row-level `usageError` remains visible

- [ ] **Step 2: Run final verification**

Run: `npm run build`
Run: `npm run lint`
Expected: Commands succeed, or any failures are captured precisely in the final report.

- [ ] **Step 3: Summarize verification evidence**

Record the exact commands and whether they passed so completion claims are backed by fresh output.
