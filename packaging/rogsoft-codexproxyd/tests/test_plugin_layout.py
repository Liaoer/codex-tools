import unittest
from pathlib import Path


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
        self.assertIn("actionNeedsLogPolling", page)
        self.assertIn("finishQuickAction", page)
        self.assertIn("finishActionWithError", page)
        self.assertIn("startActionLogPolling", page)
        self.assertIn("actionPollingTimedOut", page)
        self.assertIn("pollActionLog", page)
        self.assertIn("buildImportedUsageSummary", page)
        self.assertIn("summaryFromImportedAccount", page)
        self.assertIn("attachChunkedField", page)
        self.assertIn("currentDataDirValue", page)
        self.assertIn("refreshAuditLog", page)
        self.assertIn("refreshErrorLog", page)
        self.assertIn("renderAccountsUsage", page)
        self.assertIn("renderImageStatus", page)
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
        self.assertIn('params:["action"]', page)
        self.assertIn("JSON.parse(rawResult||\"{}\")", page)
        self.assertNotIn("/tmp/upload/codexproxyd_log.txt", page)
        self.assertIn(
            '<option value="gpt-5.4" selected="selected">gpt-5.4</option>', page
        )
        self.assertNotIn('<option value="gpt-5">gpt-5</option>', page)
        self.assertIn('<option value="low">low</option>', page)
        self.assertIn('<option value="medium">medium</option>', page)
        self.assertIn('<option value="high" selected="selected">high</option>', page)
        self.assertIn('<option value="xhigh">xhigh</option>', page)
        self.assertNotIn('<option value="minimal">minimal</option>', page)

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
        ]:
            self.assertIn(action_name, script)
        self.assertIn("codexproxyd_default_model", script)
        self.assertIn("codexproxyd_default_effort", script)
        self.assertIn("codexproxyd_audit_log_level", script)
        self.assertIn('CUSTOM_API_KEY_VALUE="${codexproxyd_api_key_value}"', script)
        self.assertIn("proxy-settings.json", script)
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
        self.assertIn("find_existing_disk_path()", script)
        self.assertIn("refresh_runtime_paths()", script)
        self.assertIn("coalesce_setting_value()", script)
        self.assertIn(
            'DATA_DIR_OVERRIDE="$(coalesce_setting_value "${codexproxyd_data_dir_value}" "$(dbus get codexproxyd_data_dir_value)")"',
            script,
        )
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

    def test_action_script_refresh_usage_supports_wget_fallback(self):
        script = (MODULE_ROOT / "scripts" / "codexproxyd_action.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("ensure_http_client()", script)
        self.assertIn('command -v wget >/dev/null 2>&1', script)
        self.assertIn('HTTP_CLIENT="wget"', script)
        self.assertIn("run_http_post_to_file()", script)
        self.assertIn('wget -q -O "${output_path}"', script)

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
        self.assertIn("defaultModel", script)
        self.assertIn("defaultEffort", script)
        self.assertIn("auditLogLevel", script)
        self.assertIn("accountsUsage", script)
        self.assertIn("ACTION_PID_FILE", script)
        self.assertIn("ACTION_LOG_PATH", script)
        self.assertIn("ACTION_STATE_FILE", script)
        self.assertIn("actionRunning", script)
        self.assertIn("actionStatus", script)
        self.assertIn("actionMessage", script)
        self.assertIn("actionLogDone", script)
        self.assertIn("actionLastLine", script)
        self.assertIn("processConflict", script)
        self.assertIn("processConflictText", script)
        self.assertIn("proxydPidCount", script)
        self.assertIn("read_proxyd_pid_list()", script)
        self.assertIn("count_proxyd_pids()", script)
        self.assertIn("json_fragment_normalize", script)
        self.assertNotIn("json_fragment_escape", script)
        self.assertIn("ACCOUNTS_USAGE_ESCAPED", script)
        self.assertIn("__codex_tools/accounts/usage", script)
        self.assertIn("load_accounts_usage_json", script)
        self.assertIn("load_accounts_usage_from_accounts_file", script)
        self.assertIn("select_runtime_disk_path()", script)
        self.assertIn("find_preferred_disk_path()", script)
        self.assertIn("resolve_runtime_data_dir()", script)
        self.assertIn("extract_runtime_data_dir_from_file()", script)
        self.assertIn("find_existing_data_dir()", script)
        self.assertIn('dbus set codexproxyd_data_dir_value="${DATA_DIR}"', script)
        self.assertIn('"email"', script)
        self.assertIn('"planType"', script)
        self.assertIn('chmod 755 "${DOCKROOT_BIN}"', script)
        self.assertIn('DOCKROOT_VERSION="$(${DOCKROOT_BIN} -v 2>&1)"', script)
        self.assertIn("DOCKROOT_INSTALLED=1", script)
        self.assertNotIn("if pidof codex-tools-proxyd >/dev/null 2>&1; then", script)
        self.assertIn('http_response "${RESP}"', script)

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

    def test_control_panel_action_polling_has_auto_close_and_status_refresh_hooks(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("action_status_refresh_timer", page)
        self.assertIn("startActionStatusRefresh", page)
        self.assertIn("stopActionStatusRefresh", page)
        self.assertIn("scheduleActionLogPoll", page)
        self.assertIn("closeLoadingBarSoon", page)
        self.assertIn("handOffActionToStatusPolling", page)
        self.assertIn("updateLoadingMessage", page)
        self.assertIn("refresh_runtime_log(true)", page)

    def test_control_panel_can_finish_actions_from_status_without_action_log(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("current_action_name", page)
        self.assertIn("current_action_success_message", page)
        self.assertIn("inferActionCompletedFromStatus", page)
        self.assertIn("maybeFinishActionFromStatus", page)
        self.assertIn("state.processConflict", page)
        self.assertIn("state.processConflictText", page)
        self.assertIn('case "cleanup_conflict":return !result.actionRunning&&!result.processConflict;', page)
        self.assertNotIn("bundleReady||result.containerExists", page)
        self.assertIn('state.actionStatus=="success"', page)
        self.assertIn('state.actionStatus=="error"', page)
        self.assertIn("state.actionLogDone&&!state.actionRunning&&actionMatches", page)
        self.assertIn("操作已结束，但状态未达到预期，请检查运行日志。", page)
        self.assertIn("if(maybeFinishActionFromStatus(result)){return;}", page)
        self.assertIn(
            'updateLoadingMessage("操作日志暂时不可读，正在改用状态确认结果...");',
            page,
        )
        self.assertIn(
            "stopActionStatusRefresh();scheduleStatusPoll(3000);closeLoadingBarSoon(1200,function(){hideSSLoadingBar();});",
            page,
        )
        self.assertIn('E("Loading").style.display="none"', page)
        self.assertIn('E("LoadingBar").style.display="none"', page)
        self.assertNotIn('E("Loading").style.display="block"', page)
        self.assertIn('E("LoadingBar").style.display="block"', page)

    def test_control_panel_normalizes_action_result_before_request_id_compare(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function normalizeActionResult", page)
        self.assertIn("var expectedResult=String(id);", page)
        self.assertIn(
            'fields["codexproxyd_request_id"]=expectedResult;',
            page,
        )
        self.assertIn(
            "if(normalizedResult===expectedResult||isAcceptedActionReceipt(normalizedResult))",
            page,
        )
        self.assertIn('params:[actionName]', page)

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
        self.assertIn('attachChunkedField(fields,"codexproxyd_payload_text",importPayload);', page)
        self.assertIn('attachChunkedField(fields,"codexproxyd_usage_summary_text",buildImportedUsageSummary(importPayload));', page)
        self.assertIn('"codexproxyd_payload_text":"","codexproxyd_payload_text_chunks":"0"', page)
        self.assertIn('"codexproxyd_usage_summary_text":"","codexproxyd_usage_summary_text_chunks":"0"', page)
        self.assertIn('ensureDiskPathOption(resolved,resolved+" (saved)")', page)
        self.assertIn("if(s.options.length==1&&s.options[0].value)", page)
        self.assertIn("var d=syncDiskPathSelection();", page)
        self.assertIn('deriveDiskPathFromDataDir(savedValue)!=resolvedDisk', page)
        self.assertIn('deriveDiskPathFromDataDir(statusValue)!=resolvedDisk', page)
        self.assertIn('finishActionWithError("请先选择可用的磁盘挂载点。")', page)

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

        self.assertIn(
            'function actionNeedsLogPolling(name){return name!="save_settings"&&name!="import_accounts"&&name!="import_auth";}',
            page,
        )
        self.assertIn('updateLoadingMessage("操作日志已结束，正在确认最终状态...");', page)
        self.assertIn("get_run_status();return;}", page)

    def test_control_panel_exposes_cleanup_conflict_action(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("function shouldShowCleanupConflictButton", page)
        self.assertIn('id="cleanup_conflict_button"', page)
        self.assertIn("shouldShowCleanupConflictButton(r)", page)
        self.assertIn('cleanupButton.style.display=shouldShowCleanupConflictButton(r)?"":"none";', page)
        self.assertIn("onAction('cleanup_conflict');", page)

    def test_control_panel_resets_previous_action_timers_before_new_submit(self):
        page = (MODULE_ROOT / "webs" / "Module_codexproxyd.asp").read_text(
            encoding="utf-8"
        )

        self.assertIn("clearActionCloseTimer();resetActionLogPolling();", page)

    def test_install_script_preserves_existing_settings(self):
        script = (MODULE_ROOT / "install.sh").read_text(encoding="utf-8")

        self.assertIn(
            'current_disk_path=$(dbus get ${module}_disk_path_selected)', script
        )
        self.assertIn(
            'current_data_dir=$(dbus get ${module}_data_dir_value)', script
        )
        self.assertIn(
            'dbus set ${module}_disk_path_selected="${current_disk_path}"', script
        )
        self.assertIn(
            'dbus set ${module}_data_dir_value="${current_data_dir}"', script
        )
        self.assertIn('dbus set ${module}_image_ref="${current_image_ref}"', script)
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


if __name__ == "__main__":
    unittest.main()
