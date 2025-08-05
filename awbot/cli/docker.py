import os
import subprocess
from importlib import metadata
from pathlib import Path

def _get_version() -> str:
    root = Path(__file__).parent.parent

    def from_env() -> str:
        return os.environ.get("awbot_VERSION", "").strip()

    def from_file() -> str:
        version_file = root / "VERSION"
        return version_file.read_text().strip() if version_file.exists() else ""

    def from_git() -> str:
        if not (root / ".git").exists():
            return ""
        result = subprocess.run(
            ["git", "describe", "--tags", "--always", "--dirty"],
            capture_output=True,
            text=True,
            cwd=root,
            timeout=5,
            check=False,
        )
        if result.returncode != 0 or not result.stdout.strip():
            return ""
        version = result.stdout.strip()
        return version.removeprefix("v")

    def from_metadata() -> str:
        return metadata.version("awbot")

    for getter in (from_env, from_file, from_git, from_metadata):
        try:
            version = getter()
        except Exception as e:
            import logging
            logging.getLogger(__name__).debug(f"Version detection method {getter.__name__} failed: {e}")
            continue
        if version and version not in ("0.0.0", "0.0", "unknown"):
            return version
    return "dev"

__version__: str = _get_version()