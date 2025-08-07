#!/usr/bin/env python3
"""
Global Monorepo Orchestration Script

This script detects and manages projects in multiple languages within a monorepo.
It provides a unified interface for common tasks like installing dependencies,
running tests, building, and cleaning projects.
"""

import os
import sys
import subprocess
import argparse
import logging
from typing import Dict, List, Tuple

# --- Configuration ---

# Define commands for each language and task. This is easily extensible.
COMMANDS: Dict[str, Dict[str, str]] = {
    "js": {
        "install": "npm install",
        "test": "npm test",
        "coverage": "npm test -- --coverage",
        "build": "npm run build",
        "clean": "rm -rf node_modules build dist",
    },
    "python": {
        "install": "pip install -r requirements.txt",
        "test": "pytest",
        "coverage": "pytest --cov=.",
        "build": "echo 'No build step for this Python project'",
        "clean": "rm -rf .venv .pytest_cache .coverage __pycache__ *.egg-info build dist",
    },
    "go": {
        "install": "go mod download",
        "test": "go test ./...",
        "coverage": "go test -coverprofile=coverage.out ./...",
        "build": "go build ./...",
        "clean": "go clean -cache -modcache",
    },
    "rust": {
        "install": "cargo fetch",
        "test": "cargo test",
        "coverage": "cargo test",  # Coverage often needs a tool like `grcov`
        "build": "cargo build --release",
        "clean": "cargo clean",
    },
    "ruby": {
        "install": "bundle install",
        "test": "bundle exec rake test",
        "coverage": "bundle exec rake test",  # Assumes test task generates coverage
        "clean": "rm -rf vendor Gemfile.lock .bundle",
    },
}

# Mapping of marker files to language names
LANGUAGE_MARKERS: Dict[str, str] = {
    "package.json": "js",
    "requirements.txt": "python",
    "pyproject.toml": "python",
    "go.mod": "go",
    "Cargo.toml": "rust",
    "Gemfile": "ruby",
}

# --- Core Functions ---

def setup_logging(verbose: bool):
    """Configures the logging format and level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="[%(levelname)s] %(message)s",
        stream=sys.stdout,
    )

def find_projects(root_dir: str) -> List[Tuple[str, str]]:
    """
    Finds all project directories using `git ls-files` for efficiency.
    Returns a list of tuples, where each tuple contains (project_path, language).
    """
    logging.info("Scanning for projects using 'git ls-files'...")
    try:
        # Use git to list all tracked files, which is fast and respects .gitignore
        cmd = ["git", "-C", root_dir, "ls-files", "--full-name"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        all_files = result.stdout.strip().split('\n')
    except (subprocess.CalledProcessError, FileNotFoundError):
        logging.warning(
            "'git ls-files' failed. Falling back to 'os.walk'. "
            "This will be slower and may not respect .gitignore."
        )
        all_files = []
        for dirpath, _, filenames in os.walk(root_dir):
            for filename in filenames:
                all_files.append(os.path.relpath(os.path.join(dirpath, filename), root_dir))

    project_dirs: Dict[str, str] = {}
    for file_path in all_files:
        filename = os.path.basename(file_path)
        if filename in LANGUAGE_MARKERS:
            lang = LANGUAGE_MARKERS[filename]
            proj_dir = os.path.dirname(file_path)
            # Store the language, preventing duplicates. A directory is one project.
            if proj_dir not in project_dirs:
                project_dirs[proj_dir] = lang

    # Sort for deterministic order
    sorted_projects = sorted(project_dirs.items(), key=lambda item: item[0])
    logging.debug(f"Found projects: {sorted_projects}")
    return sorted_projects

def run_command(
    project_path: str, language: str, command: str, dry_run: bool
) -> bool:
    """
    Executes a predefined command for a given project.
    Returns True on success, False on failure.
    """
    logging.info(f"Running '{command}' for {language} project in '{project_path}'...")

    # Special case for Python: prefer pyproject.toml for installation
    cmd_str = COMMANDS.get(language, {}).get(command)
    if language == "python" and command == "install" and os.path.exists(os.path.join(project_path, "pyproject.toml")):
        cmd_str = "pip install ."
        logging.debug("Using 'pip install .' for pyproject.toml based project.")

    if not cmd_str:
        logging.warning(f"No command '{command}' defined for language '{language}'. Skipping.")
        return True  # Not a failure, just a skip

    logging.debug(f"Executing command: {cmd_str}")

    if dry_run:
        logging.warning("DRY RUN: Skipping execution.")
        return True

    try:
        subprocess.run(
            cmd_str,
            shell=True,
            check=True,
            cwd=project_path,
            stdout=sys.stdout if logging.getLogger().level == logging.DEBUG else subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed in '{project_path}' with exit code {e.returncode}.")
        if e.stdout:
            logging.error(f"Output:\n{e.stdout}")
        return False

    # Upload coverage to Codecov if applicable
    if command == "coverage" and os.getenv("CODECOV_TOKEN"):
        logging.info(f"Uploading coverage report from '{project_path}' to Codecov...")
        try:
            codecov_cmd = f"bash <(curl -s https://codecov.io/bash) -t {os.getenv('CODECOV_TOKEN')} -F {language}"
            subprocess.run(codecov_cmd, shell=True, check=True, cwd=project_path, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            logging.error(f"Codecov upload failed for '{project_path}'.\n{e.stdout}")
            # Do not fail the entire script for a failed upload

    return True

# --- Main Execution ---

def main():
    """Parses arguments and orchestrates tasks across the monorepo."""
    parser = argparse.ArgumentParser(
        description="A global orchestration script for multi-language monorepos.",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "command",
        choices=["install", "test", "coverage", "build", "clean"],
        help="The task to run across all projects.",
    )
    parser.add_argument(
        "--root",
        default=".",
        help="The root directory to scan (default: current directory).",
    )
    parser.add_argument(
        "--languages",
        type=str,
        help="Filter by comma-separated languages (e.g., python,js).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate actions without executing them.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable detailed logging.",
    )
    args = parser.parse_args()

    setup_logging(args.verbose)

    root_dir = os.path.abspath(args.root)
    lang_filter = args.languages.split(',') if args.languages else []

    logging.info(f"Starting orchestration task: '{args.command}'")
    logging.info(f"Root directory: '{root_dir}'")
    if lang_filter:
        logging.info(f"Language filter: {lang_filter}")
    if args.dry_run:
        logging.warning("DRY RUN mode is enabled.")

    all_projects = find_projects(root_dir)
    
    if not all_projects:
        logging.warning("No projects found. Nothing to do.")
        sys.exit(0)

    success_count = 0
    failed_projects = []

    for project_dir, lang in all_projects:
        # Apply language filter
        if lang_filter and lang not in lang_filter:
            logging.debug(f"Skipping '{project_dir}' due to language filter.")
            continue

        project_path = os.path.join(root_dir, project_dir)
        if run_command(project_path, lang, args.command, args.dry_run):
            success_count += 1
        else:
            failed_projects.append(f"{project_dir} ({lang})")
        print("-" * 20)

    # Final Summary
    logging.info("Orchestration Summary")
    logging.info(f"Successfully processed: {success_count} project(s).")
    if failed_projects:
        logging.error(f"Failed to process: {len(failed_projects)} project(s).")
        for failed in failed_projects:
            logging.error(f"  - {failed}")
        sys.exit(1)
    else:
        logging.info("All projects processed successfully.")

if __name__ == "__main__":
    main()
