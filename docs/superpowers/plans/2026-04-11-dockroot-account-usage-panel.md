# DockRoot Account Usage Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a true-refresh account usage panel to the DockRoot `codexproxyd` plugin page, immediately after runtime configuration, showing account email, plan marker, 5-hour usage, 1-week usage, reset times, and row-level refresh errors.

**Architecture:** Extend the running `codex-tools-proxyd` service with loopback-only management endpoints that can export current account usage summaries and trigger a real refresh against `/data/accounts.json`. Then update the DockRoot shell scripts to call those local endpoints from the router and expose the returned account usage summary through the existing status payload consumed by the ASP page.

**Tech Stack:** Rust (`src-tauri/proxyd` CLI), shell scripts for Merlin/DockRoot integration, classic ASP page with inline JavaScript, Python `unittest` packaging tests

---

### Task 1: Add proxyd management endpoints for usage refresh/export

**Files:**
- Modify: `src-tauri/src/proxy_service.rs`
- Modify: `src-tauri/src/models.rs` (only if a shared summary struct is justified)
- Modify: `src-tauri/src/store.rs`
- Modify: `src-tauri/src/auth.rs` (only if refresh helpers need shared extraction)
- Modify: `src-tauri/src/usage.rs`
- Test: `src-tauri/src/proxy_service.rs`

- [ ] **Step 1: Write the failing test**

Add Rust tests for loopback-only management endpoints that:
- export the current account usage summary from the store
- refresh usage snapshots
- emit a normalized JSON summary with email, plan type, 5h/1w used percentages, reset times, and usage errors

- [ ] **Step 2: Run the failing test**

Run: `cargo test --manifest-path src-tauri/proxyd/Cargo.toml proxy_service`
Expected: FAIL because the management endpoints and summary export do not exist yet.

- [ ] **Step 3: Implement the minimal container-side management interface**

Add loopback-only endpoints to the proxyd router, for example:

```text
GET  /__codex_tools/accounts/usage
POST /__codex_tools/accounts/usage/refresh
```

Implementation must:
- read `/data/accounts.json`
- iterate accounts and refresh usage using the existing auth/usage helpers
- persist the updated store
- return normalized JSON to the caller

- [ ] **Step 4: Run the Rust tests again**

Run: `cargo test --manifest-path src-tauri/proxyd/Cargo.toml proxy_service`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/proxy_service.rs src-tauri/src/models.rs src-tauri/src/store.rs src-tauri/src/usage.rs
git commit -m "feat: add proxyd usage refresh endpoints"
```

### Task 2: Wire DockRoot scripts to the new refresh/export command

**Files:**
- Modify: `packaging/rogsoft-codexproxyd/codexproxyd/scripts/codexproxyd_action.sh`
- Modify: `packaging/rogsoft-codexproxyd/codexproxyd/scripts/codexproxyd_status.sh`
- Test: `packaging/rogsoft-codexproxyd/tests/test_plugin_layout.py`

- [ ] **Step 1: Write the failing test**

Extend the plugin layout tests to assert:
- `refresh_usage` is present in the action script
- the status script exposes account usage payload keys
- the ASP page can reference the new account usage section ids/functions

- [ ] **Step 2: Run the plugin layout test and watch it fail**

Run: `python -m unittest packaging.rogsoft-codexproxyd.tests.test_plugin_layout`
Expected: FAIL because the new action and payload keys are not present.

- [ ] **Step 3: Implement the shell-side integration**

Update `codexproxyd_action.sh` to:
- add a `refresh_usage` action
- verify the container/runtime prerequisites
- call the new loopback refresh endpoint with `curl`
- capture the JSON summary to a stable file under the data dir or plugin cache

Update `codexproxyd_status.sh` to:
- call the loopback export endpoint when available, with fallback to the last known usage summary file
- include it in the returned JSON payload as `accountsUsage`

- [ ] **Step 4: Re-run the plugin layout test**

Run: `python -m unittest packaging.rogsoft-codexproxyd.tests.test_plugin_layout`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packaging/rogsoft-codexproxyd/codexproxyd/scripts/codexproxyd_action.sh packaging/rogsoft-codexproxyd/codexproxyd/scripts/codexproxyd_status.sh packaging/rogsoft-codexproxyd/tests/test_plugin_layout.py
git commit -m "feat: expose DockRoot account usage refresh"
```

### Task 3: Render the account usage panel in the ASP page

**Files:**
- Modify: `packaging/rogsoft-codexproxyd/codexproxyd/webs/Module_codexproxyd.asp`
- Test: `packaging/rogsoft-codexproxyd/tests/test_plugin_layout.py`

- [ ] **Step 1: Write the failing test**

Add test assertions for:
- account usage section markup after runtime configuration
- refresh button presence
- account usage render helper functions or ids used by the table

- [ ] **Step 2: Run the plugin layout test**

Run: `python -m unittest packaging.rogsoft-codexproxyd.tests.test_plugin_layout`
Expected: FAIL because the page does not contain the new panel yet.

- [ ] **Step 3: Implement the minimal page changes**

Update the ASP page to:
- add a new table after the runtime configuration section
- add a refresh button that triggers `refresh_usage`
- render rows from the `accountsUsage` status payload
- show `--` for missing values
- show row-level usage errors
- preserve current polling and action-log behavior

- [ ] **Step 4: Re-run the plugin layout test**

Run: `python -m unittest packaging.rogsoft-codexproxyd.tests.test_plugin_layout`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packaging/rogsoft-codexproxyd/codexproxyd/webs/Module_codexproxyd.asp packaging/rogsoft-codexproxyd/tests/test_plugin_layout.py
git commit -m "feat: add DockRoot account usage panel"
```

### Task 4: Build and package verification

**Files:**
- Review only: all files changed in Tasks 1-3
- Run: `packaging/rogsoft-codexproxyd/build.py`

- [ ] **Step 1: Run targeted Rust verification**

Run: `cargo test --manifest-path src-tauri/proxyd/Cargo.toml`
Expected: PASS

- [ ] **Step 2: Run plugin packaging tests**

Run: `python -m unittest packaging.rogsoft-codexproxyd.tests.test_build_script packaging.rogsoft-codexproxyd.tests.test_plugin_layout`
Expected: PASS

- [ ] **Step 3: Rebuild the rogsoft package**

Run: `python packaging/rogsoft-codexproxyd/build.py`
Expected: updated `codexproxyd.tar.gz`, `config.json.js`, and `version`

- [ ] **Step 4: Summarize fresh evidence**

Record the exact verification commands and whether they passed before claiming the work is ready.
