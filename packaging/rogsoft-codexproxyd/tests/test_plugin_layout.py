import unittest
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
MODULE_ROOT = PACKAGE_ROOT / "codexproxyd"


class RogsoftCodexProxydLayoutTests(unittest.TestCase):
    def test_expected_plugin_files_exist(self):
        expected_paths = [
            PACKAGE_ROOT / "README.md",
            PACKAGE_ROOT / "build.py",
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
        self.assertIn('id="codexproxyd_enable"', page)
        self.assertIn('id="codexproxyd_image_ref"', page)
        self.assertIn('id="codexproxyd_default_model"', page)
        self.assertIn('id="codexproxyd_default_effort"', page)
        self.assertIn('id="codexproxyd_audit_log_level"', page)
        self.assertIn('id="codexproxyd_payload_kind"', page)
        self.assertIn('id="codexproxyd_payload_text"', page)
        self.assertIn('id="audit_log"', page)
        self.assertIn('id="error_log"', page)
        self.assertIn("copyLocalUrl", page)
        self.assertIn("copyLanUrl", page)
        self.assertIn("formatLastImportText", page)
        self.assertIn("scheduleRuntimeLogRefresh", page)
        self.assertIn("actionNeedsLogPolling", page)
        self.assertIn("finishQuickAction", page)
        self.assertIn("refreshAuditLog", page)
        self.assertIn("refreshErrorLog", page)

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
            "remove_container",
            "regenerate_key",
            "import_accounts",
            "import_auth",
        ]:
            self.assertIn(action_name, script)
        self.assertIn("codexproxyd_default_model", script)
        self.assertIn("codexproxyd_default_effort", script)
        self.assertIn("codexproxyd_audit_log_level", script)
        self.assertIn("proxy-settings.json", script)
        self.assertIn('chmod 755 "${DOCKROOT_BIN}"', script)
        self.assertIn('version_output="$(${DOCKROOT_BIN} -v 2>&1)"', script)
        self.assertIn("continuing because the binary exists", script)

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
        self.assertIn("defaultModel", script)
        self.assertIn("defaultEffort", script)
        self.assertIn("auditLogLevel", script)
        self.assertIn('chmod 755 "${DOCKROOT_BIN}"', script)
        self.assertIn('DOCKROOT_VERSION="$(${DOCKROOT_BIN} -v 2>&1)"', script)
        self.assertIn("DOCKROOT_INSTALLED=1", script)
        self.assertIn('http_response "${RESP}"', script)

    def test_install_script_preserves_existing_settings(self):
        script = (MODULE_ROOT / "install.sh").read_text(encoding="utf-8")

        self.assertIn(
            'current_disk_path=$(dbus get ${module}_disk_path_selected)', script
        )
        self.assertIn(
            'dbus set ${module}_disk_path_selected="${current_disk_path}"', script
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


if __name__ == "__main__":
    unittest.main()
