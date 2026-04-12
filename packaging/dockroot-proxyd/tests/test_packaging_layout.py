import unittest
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]


class PackagingLayoutTests(unittest.TestCase):
    def test_expected_packaging_files_exist(self):
        expected_paths = [
            PACKAGE_ROOT / "Dockerfile",
            PACKAGE_ROOT / "README.md",
            PACKAGE_ROOT / "docker-entrypoint.sh",
            PACKAGE_ROOT / "README-dockroot.md",
            PACKAGE_ROOT / "scripts" / "import_auth_to_accounts.py",
        ]

        missing = [str(path) for path in expected_paths if not path.exists()]
        self.assertEqual(missing, [])

    def test_dockerfile_sets_router_safe_resource_limits(self):
        dockerfile = (PACKAGE_ROOT / "Dockerfile").read_text(encoding="utf-8")

        self.assertIn("CODEX_TOOLS_PROXY_MAX_BODY_MIB", dockerfile)
        self.assertIn("CODEX_TOOLS_PROXY_MAX_CONCURRENT_REQUESTS", dockerfile)
        self.assertIn("CODEX_TOOLS_PROXY_LOG_MAX_BYTES", dockerfile)
        self.assertIn("CODEX_TOOLS_PROXY_MAX_UPSTREAM_BYTES", dockerfile)


if __name__ == "__main__":
    unittest.main()
