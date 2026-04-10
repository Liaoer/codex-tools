import hashlib
import json
import tarfile
from datetime import datetime
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
MODULE_NAME = "codexproxyd"
MODULE_DIR = PROJECT_ROOT / MODULE_NAME
ARCHIVE_PATH = PROJECT_ROOT / f"{MODULE_NAME}.tar.gz"
CONFIG_PATH = PROJECT_ROOT / "config.json.js"
ROOT_VERSION_PATH = PROJECT_ROOT / "version"
MODULE_VERSION_PATH = MODULE_DIR / "version"


def load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8", newline="\n")


def build_archive() -> None:
    if not MODULE_DIR.is_dir():
        raise FileNotFoundError(f"Missing module directory: {MODULE_DIR}")

    config = load_config()
    version = config["version"]
    write_text(MODULE_VERSION_PATH, f"{version}\n")

    if ARCHIVE_PATH.exists():
        ARCHIVE_PATH.unlink()

    with tarfile.open(ARCHIVE_PATH, "w:gz") as archive:
        archive.add(MODULE_DIR, arcname=MODULE_NAME)

    md5 = hashlib.md5(ARCHIVE_PATH.read_bytes()).hexdigest()
    build_date = datetime.now().strftime("%Y-%m-%d_%H:%M:%S")

    config["md5"] = md5
    config["build_date"] = build_date
    write_text(CONFIG_PATH, json.dumps(config, indent=4, ensure_ascii=False) + "\n")
    write_text(ROOT_VERSION_PATH, f"{version}\n{md5}\n")


if __name__ == "__main__":
    build_archive()
