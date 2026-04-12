import unittest
from pathlib import Path
import subprocess
import tempfile


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
MODULE_ROOT = PACKAGE_ROOT / "codexproxyd"


class RogsoftCodexProxydLayoutTests(unittest.TestCase):
    def test_expected_plugin_files_exist(self):
        expected_paths = [
            PACKAGE_ROOT / "README.md",
            PACKAGE_ROOT / "build.py",
            PACKAGE_ROOT / "build-plugin.ps1",
            PACKAGE_ROOT / "config.json.js",
            PACKAGE_ROOT / "version",
            MODULE_ROOT / ".valid",
            MODULE_ROOT / "install.sh",
            MODULE_ROOT / "uninstall.sh",
            MODULE_ROOT / "version",
            MODULE_ROOT / "res" / "icon-codexproxyd.png",
            MODULE_ROOT / "webs" / "Module_codexproxyd.asp",
            MODULE_ROOT / "scripts" / "codexproxyd_action.sh",
            MODULE_ROOT / "scripts" / "codexproxyd_status.sh",
            MODULE_ROOT / "scripts" / "codexproxyd_log.sh",
        ]

        missing = [str(path) for path in expected_paths if not path.exists()]
        self.assertEqual(missing, [])

    def test_plugin_readme_marks_package_as_optional_extension(self):
        readme = (PACKAGE_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("可选扩展包", readme)
        self.assertIn("不是方案 2 主线交付物", readme)
        self.assertIn("../dockroot-proxyd/README-dockroot.md", readme)

    def test_control_panel_page_has_core_sections(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("codexproxyd", page)
        self.assertIn('id="status"', page)
        self.assertIn('id="status_badge"', page)
        self.assertIn('id="image_status"', page)
        self.assertIn('id="codexproxyd_enable"', page)
        self.assertIn('id="codexproxyd_image_ref"', page)
        self.assertIn('id="codexproxyd_default_model"', page)
        self.assertIn('id="codexproxyd_default_effort"', page)
        self.assertIn('id="codexproxyd_audit_log_level"', page)
        self.assertIn('id="codexproxyd_payload_kind"', page)
        self.assertIn('id="codexproxyd_payload_text"', page)
        self.assertIn('id="api_key_input"', page)
        self.assertIn('id="recovery_hint"', page)
        self.assertNotIn(
            'id="api_key_input" class="input_ss_table readonly_field" type="password" readonly="readonly" value=""',
            page,
        )
        self.assertIn('id="audit_log"', page)
        self.assertIn('id="error_log"', page)
        self.assertIn("copyLocalUrl", page)
        self.assertIn("copyLanUrl", page)
        self.assertIn("formatLastImportText", page)
        self.assertIn("scheduleRuntimeLogRefresh", page)
        self.assertIn("ensureDiskPathOption", page)
        self.assertIn("deriveDiskPathFromDockrootBin", page)
        self.assertIn("syncDiskPathSelection", page)
        self.assertIn("maybeUpdateApiKeyInput", page)
        self.assertIn("rememberPendingApiKeyValue", page)
        self.assertIn("submitActionRequest", page)
        self.assertIn("runStagedImportAction", page)
        self.assertIn("usageSummaryTimestamp", page)
        self.assertIn("actionNeedsLogPolling", page)
        self.assertIn("finishQuickAction", page)
        self.assertIn("finishActionWithError", page)
        self.assertIn("current_action_request_id", page)
        self.assertIn("restoreTrackedActionFromStatus", page)
        self.assertIn("beginTrackedAction", page)
        self.assertIn("isTrackedActionName", page)
        self.assertIn("buildImportedUsageSummary", page)
        self.assertIn("summaryFromImportedAccount", page)
        self.assertIn("attachChunkedField", page)
        self.assertIn("currentDataDirValue", page)
        self.assertIn("refreshAuditLog", page)
        self.assertIn("refreshErrorLog", page)
        self.assertIn("renderAccountsUsage", page)
        self.assertIn("parseAccountsUsage", page)
        self.assertIn("renderAccountsUsage(parseAccountsUsage(r.accountsUsage))", page)
        self.assertIn("renderImageStatus", page)
        self.assertIn("buildRecoveryHint", page)
        self.assertIn("pending_api_key_value", page)
        self.assertIn('id="accounts_usage_summary"', page)
        self.assertIn('id="accounts_usage_panel"', page)
        self.assertIn("一键刷新额度", page)
        self.assertIn("5h 已用", page)
        self.assertIn("1周 已用", page)
        self.assertIn("document.hidden", page)
        self.assertIn("visibilitychange", page)
        self.assertIn("status_request_inflight", page)
        self.assertIn("log_request_inflight", page)
        self.assertNotIn('params:["action"]', page)
        self.assertIn("JSON.parse(rawResult||\"{}\")", page)
        self.assertNotIn("/tmp/upload/codexproxyd_log.txt", page)
        self.assertIn(
            '<option value="gpt-5-4" selected="selected">gpt-5-4</option>', page
        )
        self.assertNotIn('<option value="gpt-5">gpt-5</option>', page)
        self.assertIn('<option value="low">low</option>', page)
        self.assertIn('<option value="medium">medium</option>', page)
        self.assertIn('<option value="high" selected="selected">high</option>', page)
        self.assertIn('<option value="xhigh">xhigh</option>', page)
        self.assertNotIn('<option value="minimal">minimal</option>', page)

    def test_page_uses_dashboard_first_layout(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="dashboard_shell"', page)
        self.assertIn('id="status_hero"', page)
        self.assertIn('id="summary_cards"', page)
        self.assertIn('id="primary_action_card"', page)
        self.assertIn('id="compact_config_card"', page)
        self.assertIn('id="advanced_sections"', page)

    def test_page_contains_dashboard_ui_helpers(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function buildPrimaryActionModel", page)
        self.assertIn("function renderPrimaryAction", page)
        self.assertIn("function buildApiKeySummary", page)
        self.assertIn("function buildAccountsUsageSummary", page)
        self.assertIn("function toggleAdvancedSection", page)
        self.assertIn('id="primary_action_label"', page)
        self.assertIn('id="primary_action_hint"', page)
        self.assertIn('id="api_key_summary"', page)
        self.assertIn('id="accounts_usage_compact_summary"', page)

    def test_page_groups_advanced_sections(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="advanced_account_panel"', page)
        self.assertIn('id="advanced_usage_panel"', page)
        self.assertIn('id="advanced_logs_panel"', page)
        self.assertIn('id="advanced_diagnostics_panel"', page)
        self.assertIn('id="advanced_paths_panel"', page)
        self.assertIn('data-panel="account"', page)
        self.assertIn('data-panel="logs"', page)
        self.assertIn('data-panel="diagnostics"', page)

    def test_page_uses_compact_configuration_card(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="compact_config_card"', page)
        self.assertIn('id="config_primary_actions"', page)
        self.assertIn('id="path_details_panel"', page)
        self.assertIn('id="log_details_panel"', page)

    def test_page_keeps_api_key_editing_in_advanced_account_panel(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="api_key_quick_copy_button"', page)
        self.assertIn('id="api_key_editor_panel"', page)
        self.assertIn('id="api_key_editor_hint"', page)
        self.assertLess(
            page.index('id="summary_cards"'),
            page.index('id="api_key_quick_copy_button"'),
        )
        self.assertLess(
            page.index('id="advanced_account_panel"'),
            page.index('id="api_key_editor_panel"'),
        )

    def test_page_persists_advanced_section_state_and_uses_compact_microcopy(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function persistAdvancedSectionState", page)
        self.assertIn("function restoreAdvancedSectionState", page)
        self.assertIn("window.localStorage", page)
        self.assertIn('id="dashboard_guidance"', page)
        self.assertIn('id="status_microcopy"', page)
        self.assertIn('id="image_microcopy"', page)

    def test_page_separates_safe_and_dangerous_actions(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="config_secondary_actions"', page)
        self.assertIn('id="danger_actions_panel"', page)
        self.assertIn('id="danger_action_summary"', page)
        self.assertIn('id="remove_container_button"', page)
        self.assertIn("function renderDangerActions", page)
        self.assertLess(
            page.index('id="config_primary_actions"'),
            page.index('id="danger_actions_panel"'),
        )
        self.assertLess(
            page.index('id="danger_actions_panel"'),
            page.index('id="advanced_sections"'),
        )

    def test_page_summarizes_usage_hotspots_and_marks_severity(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="accounts_usage_issue_summary"', page)
        self.assertIn('id="accounts_usage_hotspot_summary"', page)
        self.assertIn("function buildUsageAlertSummary", page)
        self.assertIn("function usageSeverityClass", page)
        self.assertIn("ks_usage_row_warn", page)
        self.assertIn("ks_usage_row_error", page)
        self.assertIn("ks_usage_summary_chip", page)

    def test_page_adds_stage_progress_recovery_banner_and_audit_summary(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="action_phase_banner"', page)
        self.assertIn('id="recovery_banner"', page)
        self.assertIn('id="audit_summary_card"', page)
        self.assertIn('id="audit_requests_summary"', page)
        self.assertIn('id="audit_errors_summary"', page)
        self.assertIn("function buildActionPhaseSummary", page)
        self.assertIn("function renderActionPhaseSummary", page)
        self.assertIn("function summarizeAuditLog", page)

    def test_page_supports_usage_filtering_and_deeper_diagnostics_fold(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn('id="accounts_usage_filter"', page)
        self.assertIn('id="accounts_usage_sort"', page)
        self.assertIn('id="diagnostic_raw_toggle"', page)
        self.assertIn('id="diagnostic_raw_panel"', page)
        self.assertIn("function currentUsageFilterValue", page)
        self.assertIn("function currentUsageSortValue", page)
        self.assertIn("function sortAccountsByUsageRisk", page)
        self.assertIn("function filterAccountsByUsageRisk", page)
        self.assertIn("function toggleDiagnosticRawPanel", page)

    def test_control_panel_script_has_no_duplicate_core_functions_and_parses(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        for function_name in [
            "renderAccountsUsage",
            "buildFields",
            "submitAction",
            "beginTrackedAction",
        ]:
            self.assertEqual(page.count(f"function {function_name}("), 1)
        self.assertEqual(page.count("function pollActionLog("), 0)
        self.assertEqual(page.count("function startActionStatusRefresh("), 0)

        script_start = page.index("<script>") + len("<script>")
        script_end = page.index("</script></head>")
        script = page[script_start:script_end]

        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", suffix=".js", delete=False
        ) as handle:
            handle.write(script)
            temp_script_path = Path(handle.name)

        try:
            subprocess.run(
                ["node", "--check", str(temp_script_path)],
                check=True,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
        finally:
            temp_script_path.unlink(missing_ok=True)

    def test_action_script_declares_required_actions(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("codexproxyd", script)
        for action_name in [
            "save_settings",
            "pull_image",
            "start",
            "stop",
            "restart",
            "cleanup_conflict",
            "remove_container",
            "regenerate_key",
            "refresh_usage",
            "import_accounts",
            "import_auth",
            "import_stage_begin",
            "import_stage_chunk",
            "import_stage_commit",
            "import_stage_abort",
        ]:
            self.assertIn(action_name, script)
        self.assertIn("codexproxyd_default_model", script)
        self.assertIn("codexproxyd_default_effort", script)
        self.assertIn("codexproxyd_audit_log_level", script)
        self.assertIn('CUSTOM_API_KEY_VALUE="${codexproxyd_api_key_value}"', script)
        self.assertIn("proxy-settings.json", script)
        self.assertIn("read_proxy_settings_field()", script)
        self.assertIn("restore_saved_settings_from_proxy_settings()", script)
        self.assertIn("normalize_api_key_value()", script)
        self.assertIn("write_api_key_file()", script)
        self.assertIn('echo_date "Saved custom API key into ${API_KEY_FILE}"', script)
        self.assertIn(
            'echo_date "Restarting container so the updated api-proxy.key takes effect."',
            script,
        )
        self.assertIn("accounts-usage-summary.json", script)
        self.assertIn("codexproxyd_usage_summary_b64", script)
        self.assertIn("codexproxyd_usage_summary_text", script)
        self.assertIn('IMPORT_STAGE_ROOT="/tmp/codexproxyd-import"', script)
        self.assertIn("find_existing_disk_path()", script)
        self.assertIn("refresh_runtime_paths()", script)
        self.assertIn("coalesce_setting_value()", script)
        self.assertIn(
            'DATA_DIR_OVERRIDE="$(coalesce_setting_value "${codexproxyd_data_dir_value}" "$(dbus get codexproxyd_data_dir_value)")"',
            script,
        )
        self.assertIn('dbus set codexproxyd_image_ref="${IMAGE_REF}"', script)
        self.assertIn("resolve_runtime_data_dir()", script)
        self.assertIn("extract_runtime_data_dir_from_file()", script)
        self.assertIn("read_chunked_field_value()", script)
        self.assertIn('IMAGE_REF="$(coalesce_setting_value "${codexproxyd_image_ref}" "$(dbus get codexproxyd_image_ref)")"', script)
        self.assertIn("Recovered disk path automatically", script)
        self.assertIn("__codex_tools/accounts/usage/refresh", script)
        self.assertIn("low|medium|high|xhigh", script)
        self.assertNotIn("minimal|low|medium|high", script)
        self.assertIn('chmod 755 "${DOCKROOT_BIN}"', script)
        self.assertIn('version_output="$(${DOCKROOT_BIN} -v 2>&1)"', script)
        self.assertIn("continuing because the binary exists", script)
        self.assertIn('ACTION_PID_FILE="/tmp/codexproxyd_action.pid"', script)
        self.assertIn("is_action_running()", script)
        self.assertIn("start_async_action()", script)
        self.assertIn("run_action_by_name()", script)
        self.assertIn('echo "${action_pid}" > "${ACTION_PID_FILE}"', script)
        self.assertIn("wait_for_action_slot()", script)
        self.assertIn('ACTION_NAME="${codexproxyd_action:-${2:-$1}}"', script)

    def test_action_script_makes_pull_idempotent_and_keeps_start_async(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("cleanup_container_bundle_for_pull()", script)
        self.assertIn("cleanup_conflict()", script)
        self.assertIn("normalize_dockroot_image_ref()", script)
        self.assertIn('PULL_IMAGE_REF="$(normalize_dockroot_image_ref "${IMAGE_REF}")"', script)
        self.assertIn('ttl.sh/*:*', script)
        self.assertIn('printf "%s:latest" "${repository}"', script)
        self.assertIn('rm -rf "${DOCKROOT_DATA_DIR}"', script)
        self.assertIn('echo_date "Cleaning existing runtime bundle before pull."', script)
        self.assertIn("cleanup_container_bundle_for_pull || return 1", script)
        self.assertIn("kill_conflicting_proxyd_processes()", script)
        self.assertIn('kill -TERM "${pid}" >> "${LOG_FILE}" 2>&1', script)
        self.assertIn('kill -KILL "${pid}" >> "${LOG_FILE}" 2>&1', script)
        self.assertIn(
            "pull_image|start|stop|restart|cleanup_conflict|remove_container|regenerate_key", script
        )
        self.assertIn('echo_date "Action ${ACTION_NAME} is running in background', script)
        self.assertIn("is_runtime_running()", script)
        self.assertIn("get_proxyd_pid_count()", script)
        self.assertIn("assert_single_proxyd_process()", script)
        self.assertIn("run_mount_refresh()", script)
        self.assertIn("wait_for_runtime_running()", script)
        self.assertIn('DOCKROOT_RENEW_TIMEOUT_SECONDS="12"', script)
        self.assertIn('DOCKROOT_START_TIMEOUT_SECONDS="15"', script)
        self.assertIn('timeout "${DOCKROOT_RENEW_TIMEOUT_SECONDS}"', script)
        self.assertIn('grep -q "upstream=codex" "${LOG_FILE}"', script)
        self.assertNotIn(
            '"${DOCKROOT_BIN}" stop "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true',
            script,
        )
        self.assertNotIn(
            '"${DOCKROOT_BIN}" rm "${CONTAINER_NAME}" >> "${LOG_FILE}" 2>&1 || true',
            script,
        )

    def test_action_script_runs_refresh_usage_in_background(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "pull_image|start|stop|restart|cleanup_conflict|remove_container|regenerate_key|refresh_usage",
            script,
        )

    def test_action_script_finalizes_state_before_async_log_end_marker(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertRegex(
            script,
            r'if \[ "\$\{ACTION_RESULT\}" = "0" \]; then\s+write_action_state "success" "\$\(last_meaningful_log_line\)" "" "completed"\s+else\s+write_action_state "error" "\$\(last_meaningful_log_line\)" "" "failed"\s+fi\s+rm -f "\$\{ACTION_PID_FILE\}"\s+finish_log',
        )

    def test_action_script_records_request_id_phase_and_pull_metadata(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('"requestId": "$(json_escape "${REQUEST_ID}")"', script)
        self.assertIn('"phase": "$(json_escape "${phase}")"', script)
        self.assertIn('"startedAt": "$(json_escape "${started_at}")"', script)
        self.assertIn('write_action_state "running" "" "${action_pid}" "accepted"', script)
        self.assertIn('dbus set codexproxyd_last_pulled_image_ref="${IMAGE_REF}"', script)
        self.assertIn('dbus set codexproxyd_last_pull_at="$(current_epoch)"', script)

    def test_action_script_refresh_usage_supports_wget_fallback(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("ensure_http_client()", script)
        self.assertIn('command -v wget >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="wget"', script)
        self.assertIn('command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="busybox_wget"', script)
        self.assertIn('command -v nc >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="nc"', script)
        self.assertIn('busybox nc --help >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="busybox_nc"', script)
        self.assertIn("extract_http_body_to_file()", script)
        self.assertIn("run_http_post_to_file()", script)
        self.assertIn('wget -q -O "${output_path}"', script)
        self.assertIn('busybox wget -q -O "${output_path}"', script)
        self.assertIn('printf "POST %s HTTP/1.1\\r\\nHost: 127.0.0.1:%s\\r\\nConnection: close\\r\\nContent-Length: 0\\r\\n\\r\\n"', script)
        self.assertIn('nc -w 180 127.0.0.1 "${PORT}"', script)
        self.assertIn('busybox nc -w 180 127.0.0.1 "${PORT}"', script)

    def test_status_script_live_usage_supports_nc_fallback(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("ensure_http_client()", script)
        self.assertIn('command -v nc >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="nc"', script)
        self.assertIn('busybox nc --help >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="busybox_nc"', script)
        self.assertIn("extract_http_body_to_file()", script)
        self.assertIn("run_http_get_to_file()", script)
        self.assertIn('printf "GET %s HTTP/1.1\\r\\nHost: 127.0.0.1:%s\\r\\nConnection: close\\r\\n\\r\\n"', script)
        self.assertIn('nc -w 30 127.0.0.1 "${PORT}"', script)
        self.assertIn('busybox nc -w 30 127.0.0.1 "${PORT}"', script)

    def test_action_and_status_scripts_validate_live_usage_freshness(self):
        action_script = (
            MODULE_ROOT / "scripts" / "codexproxyd_action.sh"
        ).read_text(encoding="utf-8")
        status_script = (
            MODULE_ROOT / "scripts" / "codexproxyd_status.sh"
        ).read_text(encoding="utf-8")

        self.assertIn("/__codex_tools/accounts/usage/refresh", action_script)
        self.assertIn("extract_accounts_usage_timestamp()", action_script)
        self.assertIn("Usage refresh returned a stale summary payload.", action_script)
        self.assertIn("/__codex_tools/accounts/usage", status_script)
        self.assertIn("load_live_accounts_usage_json()", status_script)
        self.assertIn("extract_accounts_usage_timestamp()", status_script)
        self.assertIn('ACCOUNTS_USAGE_SOURCE="live_endpoint"', status_script)

    def test_action_script_save_settings_preserves_existing_image_ref_when_request_is_blank(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            'current_disk_path="$(coalesce_setting_value "${codexproxyd_disk_path_selected}" "${DISK_PATH}")"',
            script,
        )
        self.assertIn(
            'current_image_ref="$(coalesce_setting_value "${codexproxyd_image_ref}" "${IMAGE_REF}")"',
            script,
        )
        self.assertIn('dbus set codexproxyd_disk_path_selected="${current_disk_path}"', script)
        self.assertIn('dbus set codexproxyd_image_ref="${current_image_ref}"', script)
        self.assertNotIn('dbus set codexproxyd_image_ref="${codexproxyd_image_ref}"', script)

    def test_action_script_persists_request_disk_path_when_valid(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertRegex(
            script,
            r'if \[ -n "\$\{DISK_PATH\}" \] && \[ -d "\$\{DISK_PATH\}" \]; then\s+codexproxyd_disk_path_selected="\$\{DISK_PATH\}"\s+dbus set codexproxyd_disk_path_selected="\$\{DISK_PATH\}"',
        )
        self.assertIn('dbus set codexproxyd_data_dir_value="${DATA_DIR}"', script)

    def test_action_script_can_recover_data_dir_from_existing_accounts_file(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("find_existing_data_dir()", script)
        self.assertIn("resolve_runtime_data_dir()", script)
        self.assertIn('DATA_DIR="${resolved_data_dir:-${default_data_dir}}"', script)
        self.assertIn('Recovered data dir from existing account data: ${DATA_DIR}', script)
        self.assertIn('candidate="${candidate}/codex-proxyd-data"', script)

    def test_action_script_reassembles_large_import_payloads_from_chunks(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("read_chunked_field_value()", script)
        self.assertIn('read_chunked_field_value "codexproxyd_payload_text"', script)
        self.assertIn('read_chunked_field_value "codexproxyd_usage_summary_text"', script)
        self.assertIn('read_chunked_field_value "codexproxyd_payload_b64"', script)
        self.assertIn('read_chunked_field_value "codexproxyd_usage_summary_b64"', script)
        self.assertIn('chunk_count_var="${field_name}_chunks"', script)
        self.assertIn('chunk_var=$(printf "%s_%04d" "${field_name}" "${chunk_index}")', script)

    def test_action_script_supports_staged_import_protocol(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("sanitize_stage_id()", script)
        self.assertIn("cleanup_import_stage_dir()", script)
        self.assertIn("import_stage_begin()", script)
        self.assertIn("import_stage_chunk()", script)
        self.assertIn("import_stage_commit()", script)
        self.assertIn("import_stage_abort()", script)
        self.assertIn("/tmp/codexproxyd-import/${stage_id}", script)
        self.assertIn('codexproxyd_stage_target', script)
        self.assertIn('codexproxyd_stage_chunk_text', script)
        self.assertIn('codexproxyd_stage_chunk_index', script)
        self.assertIn('codexproxyd_stage_total_chunks', script)

    def test_valid_declares_supported_platforms(self):
        valid_lines = [
            line.strip()
            for line in (MODULE_ROOT / ".valid").read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]

        self.assertIn("hnd", valid_lines)

    def test_status_script_returns_escaped_json_string(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('RESP="{\\\\\\"dockrootInstalled\\\\\\":', script)
        self.assertIn("dockrootVersion", script)
        self.assertIn("bundleReady", script)
        self.assertIn("imageStatus", script)
        self.assertIn("imageStatusText", script)
        self.assertIn("recoveryState", script)
        self.assertIn("recoveryHint", script)
        self.assertIn("defaultModel", script)
        self.assertIn("defaultEffort", script)
        self.assertIn("auditLogLevel", script)
        self.assertIn("read_proxy_settings_field()", script)
        self.assertIn("coalesce_saved_proxy_setting()", script)
        self.assertIn("accountsUsage", script)
        self.assertIn("accountsCount", script)
        self.assertIn("accountsSource", script)
        self.assertIn("usageSummaryUpdatedAt", script)
        self.assertIn("dataDirResolvedFrom", script)
        self.assertIn("ACTION_PID_FILE", script)
        self.assertIn("ACTION_LOG_PATH", script)
        self.assertIn("ACTION_STATE_FILE", script)
        self.assertIn("actionRequestId", script)
        self.assertIn("actionRunning", script)
        self.assertIn("actionStatus", script)
        self.assertIn("actionPhase", script)
        self.assertIn("actionMessage", script)
        self.assertIn("actionUpdatedAt", script)
        self.assertIn("actionLastLine", script)
        self.assertIn("processConflict", script)
        self.assertIn("processConflictText", script)
        self.assertIn("proxydPidCount", script)
        self.assertIn("lastPulledImageRef", script)
        self.assertIn("lastPullAt", script)
        self.assertIn("read_proxyd_pid_list()", script)
        self.assertIn("count_proxyd_pids()", script)
        self.assertIn("count_accounts_usage_rows()", script)
        self.assertIn("file_mtime_epoch()", script)
        self.assertIn("ACCOUNTS_USAGE_ESCAPED", script)
        self.assertIn('accountsUsage\\\\\\":\\\\\\"${ACCOUNTS_USAGE_ESCAPED}', script)
        self.assertIn("load_accounts_usage_json", script)
        self.assertIn("load_accounts_usage_from_accounts_file", script)
        self.assertIn("select_runtime_disk_path()", script)
        self.assertIn("find_preferred_disk_path()", script)
        self.assertIn("resolve_runtime_data_dir()", script)
        self.assertIn("extract_runtime_data_dir_from_file()", script)
        self.assertIn("find_existing_data_dir()", script)
        self.assertIn('dbus set codexproxyd_data_dir_value="${DATA_DIR}"', script)
        self.assertNotIn("ACTION_LOG_DONE", script)
        self.assertNotIn("extract_action_name_from_log()", script)
        self.assertIn('"email"', script)
        self.assertIn('"planType"', script)
        self.assertIn('chmod 755 "${DOCKROOT_BIN}"', script)
        self.assertIn('DOCKROOT_VERSION="$(${DOCKROOT_BIN} -v 2>&1)"', script)
        self.assertIn("DOCKROOT_INSTALLED=1", script)
        self.assertNotIn("if pidof codex-tools-proxyd >/dev/null 2>&1; then", script)
        self.assertIn('http_response "${RESP}"', script)

    def test_status_script_wraps_accounts_usage_as_string_for_api_wrapper(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertNotIn("json_fragment_normalize()", script)
        self.assertIn('json_escape_for_api_result() {', script)
        self.assertIn('ACCOUNTS_USAGE_ESCAPED="$(json_escape_for_api_result "${ACCOUNTS_USAGE_JSON}")"', script)
        self.assertIn('accountsUsage\\\\\\":\\\\\\"${ACCOUNTS_USAGE_ESCAPED}', script)
        self.assertIn('actionMessage\\\\\\":\\\\\\"$(json_escape_for_api_result "${ACTION_MESSAGE}")', script)
        self.assertIn('actionLastLine\\\\\\":\\\\\\"$(json_escape_for_api_result "${ACTION_LAST_LINE}")', script)

    def test_status_script_json_escape_uses_printf_and_escapes_tabs(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('json_escape() {', script)
        self.assertIn("""printf "%s" "$1" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g; s/\\t/\\\\t/g; s/\\r//g; :a;N;$!ba;s/\\n/\\\\n/g'""", script)
        self.assertNotIn('echo -n "$1" | sed', script)

    def test_status_script_reports_recovery_hint_for_reinstall_recovery(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('RECOVERY_STATE="unknown"', script)
        self.assertIn('RECOVERY_HINT=""', script)
        self.assertIn('RECOVERY_STATE="needs_image_pull"', script)
        self.assertIn('RECOVERY_STATE="ready_to_start"', script)
        self.assertIn('RECOVERY_STATE="needs_accounts_import"', script)
        self.assertIn('RECOVERY_STATE="needs_full_setup"', script)

    def test_action_script_persists_image_ref_in_proxy_settings_file(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('"imageRef": "$(json_escape "${IMAGE_REF}")"', script)
        self.assertIn('DEFAULT_MODEL="gpt-5-4"', script)
        self.assertIn('"defaultModel": "$(json_escape "${normalized_model}")"', script)

    def test_status_script_can_restore_image_ref_from_proxy_settings(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('IMAGE_REF="$(coalesce_saved_proxy_setting "${codexproxyd_image_ref}" "imageRef")"', script)
        self.assertIn('DEFAULT_EFFORT_VALUE="$(coalesce_saved_proxy_setting "${codexproxyd_default_effort}" "defaultEffort")"', script)
        self.assertIn('AUDIT_LOG_LEVEL_VALUE="$(coalesce_saved_proxy_setting "${codexproxyd_audit_log_level}" "auditLogLevel")"', script)

    def test_status_script_decouples_image_status_from_bundle_ready(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('LAST_PULLED_IMAGE_REF="${codexproxyd_last_pulled_image_ref}"', script)
        self.assertIn('LAST_PULL_AT="${codexproxyd_last_pull_at}"', script)
        self.assertIn('if [ "${ACTION_NAME}" = "pull_image" ] && [ "${ACTION_STATUS}" = "running" ]; then', script)
        self.assertIn('elif [ "${RUNNING}" = "1" ] || [ "${BUNDLE_READY}" = "1" ]; then', script)
        self.assertIn('elif [ -n "${IMAGE_REF}" ] && [ -n "${LAST_PULLED_IMAGE_REF}" ] && [ "${IMAGE_REF}" != "${LAST_PULLED_IMAGE_REF}" ]; then', script)
        self.assertIn('IMAGE_STATUS="ready"', script)
        self.assertIn('IMAGE_STATUS="stale"', script)
        self.assertIn('IMAGE_STATUS="missing"', script)
        self.assertIn('IMAGE_STATUS="error"', script)
        self.assertNotIn('elif [ -n "${IMAGE_REF}" ] && [ "${IMAGE_REF}" = "${LAST_PULLED_IMAGE_REF}" ]; then', script)

    def test_status_script_sets_basic_audit_log_path_from_access_log(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('ACCESS_LOG_PATH="${DATA_DIR}/logs/access.jsonl"', script)
        self.assertIn('AUDIT_LOG_PATH="${ACCESS_LOG_PATH}"', script)
        self.assertIn('if [ "${AUDIT_LOG_LEVEL_VALUE}" = "debug" ] && [ -f "${DEBUG_LOG_PATH}" ]; then', script)

    def test_action_script_waits_for_runtime_after_detached_start(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('DOCKROOT_START_TIMEOUT_SECONDS="15"', script)
        self.assertIn('wait_for_runtime_running()', script)
        self.assertIn('while [ "${waited}" -lt "${DOCKROOT_START_TIMEOUT_SECONDS}" ]; do', script)
        self.assertIn('echo_date "Container entered running state after detached start."', script)
        self.assertIn('wait_for_runtime_running || {', script)

    def test_status_script_image_status_text_assignments_are_terminated(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        lines = [line for line in script.splitlines() if 'IMAGE_STATUS_TEXT="' in line]
        self.assertGreaterEqual(len(lines), 5)
        for line in lines:
            self.assertTrue(
                line.rstrip().endswith('"'),
                msg=f"unterminated IMAGE_STATUS_TEXT assignment: {line}",
            )

    def test_status_script_returns_single_escaped_layer_for_api_wrapper(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('RESP="{\\\\\\"dockrootInstalled\\\\\\":', script)
        self.assertNotIn('RESP="{\\\\\\\\\\\\\\"dockrootInstalled\\\\\\\\\\\\\\":', script)

    def test_action_script_prefers_dockroot_exec_for_usage_refresh(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("run_usage_command_via_dockroot()", script)
        self.assertIn("run_usage_refresh_via_dockroot()", script)
        self.assertIn(
            '"${DOCKROOT_BIN}" run "${CONTAINER_NAME}" /usr/local/bin/codex-tools-proxyd accounts-usage refresh --data-dir /data',
            script,
        )
        self.assertIn(
            'run_usage_refresh_via_dockroot "${TMP_USAGE_SUMMARY}" || {',
            script,
        )
        refresh_usage_start = script.index("refresh_usage() {")
        refresh_usage_end = script.index("\n}\n\nrun_action_by_name()", refresh_usage_start)
        refresh_usage_body = script[refresh_usage_start:refresh_usage_end]
        self.assertLess(
            refresh_usage_body.index('run_usage_refresh_via_dockroot "${TMP_USAGE_SUMMARY}"'),
            refresh_usage_body.index("ensure_http_client || return 1"),
        )

    def test_status_script_prefers_dockroot_exec_for_live_usage_export(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_status.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("run_usage_export_via_dockroot()", script)
        self.assertIn(
            '"${DOCKROOT_BIN}" run "${CONTAINER_NAME}" /usr/local/bin/codex-tools-proxyd accounts-usage export --data-dir /data',
            script,
        )
        self.assertIn(
            'run_usage_export_via_dockroot "${TMP_LIVE_USAGE_SUMMARY}" || {',
            script,
        )
        load_usage_start = script.index("load_live_accounts_usage_json() {")
        load_usage_end = script.index("\n}\n\nload_accounts_usage_from_file()", load_usage_start)
        load_usage_body = script[load_usage_start:load_usage_end]
        self.assertLess(
            load_usage_body.index('run_usage_export_via_dockroot "${TMP_LIVE_USAGE_SUMMARY}"'),
            load_usage_body.index("ensure_http_client || return 1"),
        )

    def test_log_script_supports_action_log_and_request_params(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_log.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('LOG_KIND="$2"', script)
        self.assertIn('ACTION_LOG_PATH="/tmp/upload/codexproxyd_log.txt"', script)
        self.assertIn("action)", script)
        self.assertIn("json_escape_text", script)
        self.assertIn("resolve_runtime_data_dir()", script)
        self.assertIn("extract_runtime_data_dir_from_file()", script)
        self.assertIn('DATA_DIR="${resolved_data_dir:-${DISK_PATH}/codex-proxyd-data}"', script)

    def test_control_panel_uses_single_status_polling_for_tracked_actions(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("current_action_request_id", page)
        self.assertIn("beginTrackedAction", page)
        self.assertIn("restoreTrackedActionFromStatus", page)
        self.assertIn("isTrackedActionName", page)
        self.assertIn("closeLoadingBarSoon", page)
        self.assertIn("updateLoadingMessage", page)
        self.assertIn("scheduleStatusPoll(1000)", page)
        self.assertNotIn("action_status_refresh_timer", page)
        self.assertNotIn("scheduleActionLogPoll", page)
        self.assertNotIn("handOffActionToStatusPolling", page)

    def test_control_panel_uses_action_specific_progress_copy(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function actionDisplayName", page)
        self.assertIn("function trackedActionProgressMessage", page)
        self.assertIn('state.actionLastLine', page)
        self.assertIn('if(actionName=="pull_image")', page)
        self.assertIn("正在拉取镜像", page)
        self.assertIn("DockRoot", page)
        self.assertIn('actionDisplayName(actionName)+"任务已提交', page)
        self.assertIn('actionDisplayName(actionName)+"进行中', page)
        self.assertIn('updateLoadingMessage(trackedActionProgressMessage({actionName:actionName,actionPhase:"accepted"}));', page)

    def test_control_panel_can_finish_actions_from_status_without_action_log(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("current_action_name", page)
        self.assertIn("current_action_request_id", page)
        self.assertIn("current_action_success_message", page)
        self.assertIn("current_action_started_at", page)
        self.assertIn("actionStateMatchesTracking", page)
        self.assertIn("maybeFinishActionFromStatus", page)
        self.assertIn("usageSummaryTimestamp", page)
        self.assertIn("state.processConflict", page)
        self.assertIn("state.processConflictText", page)
        self.assertIn("matchedAction=actionStateMatchesTracking(state)", page)
        self.assertIn('state.actionStatus=="success"', page)
        self.assertIn('state.actionStatus=="error"', page)
        self.assertIn('current_action_name=="refresh_usage"', page)
        self.assertIn("state.actionUpdatedAt", page)
        self.assertIn("state.usageSummaryUpdatedAt", page)
        self.assertIn("if(maybeFinishActionFromStatus(result)){return;}", page)
        self.assertIn('E("Loading").style.display="none"', page)
        self.assertIn('E("LoadingBar").style.display="none"', page)
        self.assertNotIn('E("Loading").style.display="block"', page)
        self.assertIn('E("LoadingBar").style.display="block"', page)

    def test_control_panel_exposes_action_and_status_diagnostics(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("last_action_submit_raw", page)
        self.assertIn("last_status_raw_json", page)
        self.assertIn("last_status_received_at", page)
        self.assertIn("function renderDiagnostics", page)
        self.assertIn('E("diag_action_response").value', page)
        self.assertIn('E("diag_status_json").value', page)
        self.assertIn('E("diag_tracking").innerHTML', page)
        self.assertIn("renderDiagnostics();", page)

    def test_control_panel_records_raw_action_response_and_status_json(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("last_action_submit_raw=JSON.stringify(r);", page)
        self.assertIn("last_action_submit_raw=String(error);", page)
        self.assertIn("last_status_raw_json=typeof r.result==\"string\"?r.result:JSON.stringify(result||{});", page)
        self.assertIn("last_status_received_at", page)
        self.assertIn("renderDiagnostics();", page)

    def test_control_panel_normalizes_action_result_before_request_id_compare(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function normalizeActionResult", page)
        self.assertIn("function acceptedRequestId", page)
        self.assertIn("var expectedResult=String(id);", page)
        self.assertIn(
            'fields["codexproxyd_request_id"]=expectedResult;',
            page,
        )
        self.assertIn(
            "if(normalizedResult===expectedResult||isAcceptedActionReceipt(normalizedResult))",
            page,
        )
        self.assertIn(
            "trackedRequestId=acceptedRequestId(normalizedResult,expectedResult);",
            page,
        )
        self.assertIn(
            "beginTrackedAction(actionName,trackedRequestId,successMessage);",
            page,
        )
        self.assertIn('params:[actionName]', page)
        self.assertIn(
            "if(status_request_inflight){scheduleStatusPoll(current_action_request_id?1000:5000);return;}",
            page,
        )

    def test_control_panel_resolves_disk_path_before_submit(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function deriveDiskPathFromDataDir", page)
        self.assertIn("function deriveDiskPathFromDockrootBin", page)
        self.assertIn("function resolveDiskPathSelected", page)
        self.assertIn("function syncDiskPathSelection", page)
        self.assertIn("function currentDataDirValue", page)
        self.assertIn("function attachChunkedField", page)
        self.assertIn("function currentImageRefValue", page)
        self.assertIn(
            '"codexproxyd_disk_path_selected":resolveDiskPathSelected()',
            page,
        )
        self.assertIn('"codexproxyd_data_dir_value":currentDataDirValue()', page)
        self.assertIn('"codexproxyd_image_ref":currentImageRefValue()', page)
        self.assertIn('return directValue||statusValue||savedValue||"";', page)
        self.assertIn('"codexproxyd_api_key_value":E("api_key_input").value', page)
        self.assertIn(
            'if(actionName=="save_settings"){rememberPendingApiKeyValue(fields["codexproxyd_api_key_value"]);}',
            page,
        )
        self.assertIn('"codexproxyd_payload_text":"","codexproxyd_payload_text_chunks":"0"', page)
        self.assertIn('"codexproxyd_usage_summary_text":"","codexproxyd_usage_summary_text_chunks":"0"', page)
        self.assertIn('ensureDiskPathOption(resolved,resolved+" (saved)")', page)
        self.assertIn("if(s.options.length==1&&s.options[0].value)", page)
        self.assertIn("var d=syncDiskPathSelection();", page)
        self.assertIn('deriveDiskPathFromDataDir(savedValue)!=resolvedDisk', page)
        self.assertIn('deriveDiskPathFromDataDir(statusValue)!=resolvedDisk', page)
        self.assertIn('finishActionWithError("请先选择可用的磁盘挂载点。")', page)

    def test_control_panel_uses_staged_import_protocol(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "runStagedImportAction(actionName,fields,successMessage,importPayload,buildImportedUsageSummary(importPayload));",
            page,
        )
        self.assertIn('submitActionRequest("import_stage_begin"', page)
        self.assertIn('submitActionRequest("import_stage_chunk"', page)
        self.assertIn('submitActionRequest("import_stage_commit"', page)
        self.assertIn('submitActionRequest("import_stage_abort"', page)
        self.assertIn("splitTextIntoChunks", page)
        self.assertIn("codexproxyd_stage_target", page)
        self.assertIn("codexproxyd_stage_chunk_text", page)
        self.assertIn("codexproxyd_stage_chunk_index", page)
        self.assertIn("codexproxyd_stage_total_chunks", page)

    def test_control_panel_accepts_numeric_action_receipts(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function isAcceptedActionReceipt", page)
        self.assertIn("return /^[0-9]+$/.test(normalizedResult);", page)
        self.assertIn(
            "if(normalizedResult===expectedResult||isAcceptedActionReceipt(normalizedResult))",
            page,
        )

    def test_control_panel_treats_refresh_usage_as_tracked_long_action(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("current_action_usage_summary_updated_at", page)
        self.assertIn(
            'current_action_usage_summary_updated_at=usageSummaryTimestamp(status_cache&&status_cache.usageSummaryUpdatedAt);',
            page,
        )
        self.assertIn('if(current_action_name=="refresh_usage")', page)
        self.assertIn("summaryUpdatedAt<=current_action_usage_summary_updated_at", page)
        self.assertNotIn("function actionNeedsLogPolling", page)

    def test_control_panel_surfaces_usage_summary_freshness_details(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function formatUsageSnapshotTime", page)
        self.assertIn("function formatAccountsUsageSource", page)
        self.assertIn("function buildUsageSummaryMeta", page)
        self.assertIn("function buildUsageRowMeta", page)
        self.assertIn('summaryMeta=buildUsageSummaryMeta(summaryUpdatedAt,summarySource)', page)
        self.assertIn('item.fetchedAt||item.updatedAt', page)
        self.assertIn('renderAccountsUsage(accountsUsage,r);', page)
        self.assertIn('buildAccountsUsageSummary(accountsUsage,r)', page)

    def test_control_panel_mentions_summary_time_after_refresh_usage_success(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function buildRefreshUsageSuccessMessage", page)
        self.assertIn(
            'finishQuickAction(buildRefreshUsageSuccessMessage(summaryUpdatedAt,state.accountsSource));',
            page,
        )

    def test_control_panel_exposes_cleanup_conflict_action(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function shouldShowCleanupConflictButton", page)
        self.assertIn('id="cleanup_conflict_button"', page)
        self.assertIn("shouldShowCleanupConflictButton(r)", page)
        self.assertIn('cleanupButton.style.display=shouldShowCleanupConflictButton(r)?"":"none";', page)
        self.assertIn("onAction('cleanup_conflict');", page)

    def test_control_panel_resets_previous_tracked_action_before_new_submit(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("clearActionCloseTimer();resetTrackedAction();", page)

    def test_install_script_preserves_existing_settings(self):
        script = (MODULE_ROOT / "install.sh").read_text(encoding="utf-8")

        self.assertIn(
            'current_disk_path=$(dbus get ${module}_disk_path_selected)', script
        )
        self.assertIn(
            'current_data_dir=$(dbus get ${module}_data_dir_value)', script
        )
        self.assertIn(
            'current_last_pulled_image_ref=$(dbus get ${module}_last_pulled_image_ref)',
            script,
        )
        self.assertIn(
            'current_last_pull_at=$(dbus get ${module}_last_pull_at)', script
        )
        self.assertIn(
            'dbus set ${module}_disk_path_selected="${current_disk_path}"', script
        )
        self.assertIn(
            'dbus set ${module}_data_dir_value="${current_data_dir}"', script
        )
        self.assertIn('dbus set ${module}_image_ref="${current_image_ref}"', script)
        self.assertIn(
            'dbus set ${module}_last_pulled_image_ref="${current_last_pulled_image_ref}"',
            script,
        )
        self.assertIn('dbus set ${module}_last_pull_at="${current_last_pull_at}"', script)
        self.assertIn(
            'dbus set ${module}_default_model="${current_default_model}"', script
        )
        self.assertIn(
            'dbus set ${module}_default_effort="${current_default_effort}"', script
        )
        self.assertIn(
            'dbus set ${module}_audit_log_level="${current_audit_log_level}"', script
        )
        self.assertIn('dbus set ${module}_enable="${current_enable}"', script)

    def test_build_helper_script_runs_python_builder_and_surfaces_output_path(self):
        script = (PACKAGE_ROOT / "build-plugin.ps1").read_text(encoding="utf-8")

        self.assertIn('Set-Location $PSScriptRoot', script)
        self.assertIn('python .\\build.py', script)
        self.assertIn('codexproxyd.tar.gz', script)
        self.assertIn('Read-Host', script)

    def test_control_panel_restores_inflight_tracked_action_from_status(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function restoreTrackedActionFromStatus", page)
        self.assertIn("showSSLoadingBar();", page)
        self.assertIn("beginTrackedAction(state.actionName,state.actionRequestId", page)


if __name__ == "__main__":
    unittest.main()
