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


if __name__ == "__main__":
    unittest.main()
