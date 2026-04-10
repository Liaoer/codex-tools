import importlib.util
import unittest
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]


class RogsoftCodexProxydBuildScriptTests(unittest.TestCase):
    def test_build_script_exports_codexproxyd_metadata(self):
        build_script_path = PACKAGE_ROOT / "build.py"
        spec = importlib.util.spec_from_file_location(
            "rogsoft_codexproxyd_build", build_script_path
        )
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)

        self.assertEqual(module.MODULE_NAME, "codexproxyd")
        self.assertEqual(module.MODULE_DIR, PACKAGE_ROOT / "codexproxyd")
        self.assertEqual(module.ARCHIVE_PATH.name, "codexproxyd.tar.gz")


if __name__ == "__main__":
    unittest.main()
