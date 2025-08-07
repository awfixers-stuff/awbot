
import os
import subprocess
import argparse
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(message)s"
)

# Mapping of dependency manifest files to their installation commands
PROJECT_CONFIG = {
    "package.json": "npm install",
    "requirements.txt": "pip install -r requirements.txt",
    "pyproject.toml": "pip install .",
    "Gemfile": "bundle install",
    "go.mod": "go mod download",
}

def install_dependencies(root_dir, dry_run=False, verbose=False):
    """
    Traverses all subdirectories to find and install dependencies.

    Args:
        root_dir (str): The root directory to start traversal from.
        dry_run (bool): If True, simulate without running install commands.
        verbose (bool): If True, enable detailed logging.
    """
    if verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    logging.info(f"Starting dependency scan in '{root_dir}'...")
    if dry_run:
        logging.warning("Dry run mode is enabled. No packages will be installed.")

    for dirpath, _, filenames in os.walk(root_dir):
        # Skip common dependency directories to speed up the process
        if "node_modules" in dirpath or ".venv" in dirpath or ".git" in dirpath:
            continue

        for config_file, command in PROJECT_CONFIG.items():
            if config_file in filenames:
                project_path = os.path.abspath(dirpath)
                logging.info(f"Detected '{config_file}' in '{project_path}'")

                if dry_run:
                    logging.info(f"DRY RUN: Would run '{command}' in '{project_path}'")
                    continue

                try:
                    logging.info(f"Running '{command}' in '{project_path}'...")
                    subprocess.run(
                        command,
                        shell=True,
                        check=True,
                        cwd=project_path,
                        capture_output=True,
                        text=True,
                    )
                    logging.info(f"Successfully installed dependencies for '{project_path}'")
                except subprocess.CalledProcessError as e:
                    logging.error(f"Failed to install dependencies in '{project_path}'.")
                    logging.error(f"Command: {e.cmd}")
                    logging.error(f"Exit Code: {e.returncode}")
                    logging.error(f"Stdout: {e.stdout}")
                    logging.error(f"Stderr: {e.stderr}")
                except Exception as e:
                    logging.error(f"An unexpected error occurred in '{project_path}': {e}")

def main():
    """Main function to parse arguments and run the installer."""
    parser = argparse.ArgumentParser(
        description="Traverse a monorepo and install dependencies for all detected projects."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the process without actually installing dependencies."
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output for detailed logging."
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default=".",
        help="The root directory of the monorepo to scan. Defaults to the current directory."
    )
    args = parser.parse_args()

    install_dependencies(args.directory, args.dry_run, args.verbose)

if __name__ == "__main__":
    main()
