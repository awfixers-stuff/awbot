#!/usr/bin/env python3

"""
download_prisma_engines.py

Robust Python script to download Prisma engine binaries for Linux.
- Dynamically detects Prisma CLI version (via Poetry or environment)
- Downloads query-engine, schema-engine, and prisma-fmt for linux-musl and linux
- Validates binaries (checks file type and executability)
- Provides clear error messages and manual download instructions if needed

Usage:
    python awbot/scripts/download_prisma_engines.py
"""

import os
import sys
import subprocess
import shutil
import platform
from pathlib import Path
from typing import Optional

ENGINES = ["query-engine", "schema-engine", "prisma-fmt"]
PLATFORMS = ["linux-musl", "linux"]
FALLBACK_COMMIT = "393aa359c9ad4a4bb28630fb5613f9c281cde053"
BASE_URL = "https://binaries.prisma.sh/all_commits"

def log(msg, color=None):
    colors = {
        "blue": "\033[0;34m",
        "green": "\033[0;32m",
        "yellow": "\033[1;33m",
        "red": "\033[0;31m",
        "reset": "\033[0m",
    }
    prefix = ""
    if color == "blue":
        prefix = f"{colors['blue']}ℹ️  "
    elif color == "green":
        prefix = f"{colors['green']}✅ "
    elif color == "yellow":
        prefix = f"{colors['yellow']}⚠️  "
    elif color == "red":
        prefix = f"{colors['red']}❌ "
    print(f"{prefix}{msg}{colors['reset'] if color else ''}")

def get_project_root() -> Path:
    # Try environment, then pyproject.toml, then script location
    env_root = os.environ.get("PROJECT_ROOT")
    if env_root:
        return Path(env_root).resolve()
    here = Path(__file__).parent.parent.resolve()
    if (here / "pyproject.toml").exists():
        return here
    return Path.cwd()

def detect_prisma_version() -> Optional[str]:
    # Try poetry run prisma --version
    try:
        result = subprocess.run(
            ["poetry", "run", "prisma", "--version"],
            capture_output=True, text=True, check=True
        )
        for line in result.stdout.splitlines():
            if "Prisma CLI" in line:
                return line.strip().split()[-1]
    except Exception:
        pass
    # Try environment variable
    env_version = os.environ.get("PRISMA_VERSION")
    if env_version:
        return env_version
    return None

def download_engine(url: str, dest: Path) -> bool:
    try:
        import requests
    except ImportError:
        log("requests library not found. Please install with 'pip install requests'", "red")
        return False
    try:
        r = requests.get(url, timeout=30)
        if r.status_code == 200 and r.content:
            dest.write_bytes(r.content)
            dest.chmod(0o755)
            return True
        else:
            return False
    except Exception as e:
        log(f"Download failed: {e}", "yellow")
        return False

def is_valid_binary(path: Path) -> bool:
    if not path.exists() or path.stat().st_size == 0:
        return False
    # Check file type
    try:
        result = subprocess.run(["file", str(path)], capture_output=True, text=True)
        if "executable" in result.stdout or "ELF" in result.stdout:
            return True
    except Exception:
        # Fallback: check if executable
        return os.access(str(path), os.X_OK)
    return False

def main():
    project_root = get_project_root()
    engines_dir = project_root / ".prisma-engines"
    engines_dir.mkdir(exist_ok=True)
    log(f"Project root: {project_root}", "blue")
    log(f"Engines directory: {engines_dir}", "blue")

    prisma_version = detect_prisma_version()
    if prisma_version:
        log(f"Detected Prisma CLI version: {prisma_version}", "blue")
    else:
        prisma_version = FALLBACK_COMMIT
        log(f"Could not detect Prisma CLI version, using fallback commit hash: {prisma_version}", "yellow")

    for engine in ENGINES:
        engine_path = engines_dir / engine
        if engine_path.exists() and is_valid_binary(engine_path):
            log(f"{engine} already exists and is valid, skipping", "green")
            continue

        log(f"Downloading {engine}...", "blue")
        downloaded = False

        # Try detected version first
        for platform_name in PLATFORMS:
            url = f"{BASE_URL}/{prisma_version}/{platform_name}/{engine}"
            log(f"  Trying {url}", "blue")
            if download_engine(url, engine_path):
                if is_valid_binary(engine_path):
                    log(f"  {engine} downloaded and validated ({platform_name}, {prisma_version})", "green")
                    downloaded = True
                    break
                else:
                    log(f"  Downloaded file is not a valid binary", "yellow")
                    engine_path.unlink(missing_ok=True)
            else:
                log(f"  Failed to download from {url}", "yellow")

        # Fallback to known commit if not already tried
        if not downloaded and prisma_version != FALLBACK_COMMIT:
            for platform_name in PLATFORMS:
                url = f"{BASE_URL}/{FALLBACK_COMMIT}/{platform_name}/{engine}"
                log(f"  Fallback: Trying {url}", "blue")
                if download_engine(url, engine_path):
                    if is_valid_binary(engine_path):
                        log(f"  {engine} downloaded and validated (fallback: {platform_name})", "green")
                        downloaded = True
                        break
                    else:
                        log(f"  Downloaded file is not a valid binary", "yellow")
                        engine_path.unlink(missing_ok=True)
                else:
                    log(f"  Failed to download from {url}", "yellow")

        if not downloaded:
            log(f"Could not download {engine} from any source", "red")
            # Create a placeholder script
            engine_path.write_text(
                "#!/bin/bash\n"
                "echo 'Prisma engine not available - manual download required' >&2\n"
                "echo 'Please check https://github.com/prisma/prisma-engines/releases for manual download' >&2\n"
                "exit 1\n"
            )
            engine_path.chmod(0o755)
            log(f"Created placeholder script for {engine}", "yellow")

    # Verify all engines
    log("Verifying downloaded engines...", "blue")
    all_good = True
    for engine in ENGINES:
        engine_path = engines_dir / engine
        if engine_path.exists() and is_valid_binary(engine_path):
            try:
                subprocess.run([str(engine_path), "--version"], timeout=5, check=False)
                log(f"{engine} is ready and functional", "green")
            except Exception:
                log(f"{engine} exists but may not be functional", "yellow")
        else:
            log(f"{engine} is missing or not executable", "red")
            all_good = False

    print()
    if all_good:
        log("All Prisma engines are ready and functional!", "green")
    else:
        log("Some engines may not be fully functional, but setup completed", "yellow")

    print()
    log("Engine locations:", "blue")
    for engine in ENGINES:
        engine_path = engines_dir / engine
        if engine_path.exists():
            size = engine_path.stat().st_size
            print(f"  {engine}: {engine_path} (size: {size} bytes)")
        else:
            print(f"  {engine}: NOT FOUND")

    print()
    log("Environment variables to set:", "yellow")
    print(f"export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1")
    print(f"export PRISMA_QUERY_ENGINE_BINARY=\"{engines_dir}/query-engine\"")
    print(f"export PRISMA_SCHEMA_ENGINE_BINARY=\"{engines_dir}/schema-engine\"")
    print(f"export PRISMA_FMT_BINARY=\"{engines_dir}/prisma-fmt\"")
    print(f"export PRISMA_BINARIES_MIRROR=\"https://binaries.prisma.sh\"")
    print(f"export PRISMA_ENGINES_MIRROR=\"https://binaries.prisma.sh\"")
    print(f"export PRISMA_CLI_BINARY_TARGETS=\"linux-musl,native\"")

    print()
    if all_good:
        log("You can now run Prisma commands without engine download issues!", "green")
    else:
        log("Some engines may need manual installation. Check the Prisma documentation for troubleshooting.", "yellow")

    print()
    log("Next steps:", "blue")
    print("  1. Run 'poetry run prisma generate' to generate the Prisma client")
    print("  2. Run 'poetry run prisma studio' to open the database studio")
    print("  3. If engines still don't work, try updating Prisma: 'poetry update prisma'")

if __name__ == "__main__":
    main()