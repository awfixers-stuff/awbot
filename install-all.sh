#!/usr/bin/env bash

set -e

echo "Starting global dependency installation..."

# Find and install Python dependencies using venvs
find . -type f \( -name "requirements.txt" -o -name "pyproject.toml" \) | while read -r file; do
    dir=$(dirname "$file")
    venv_dir="$dir/.venv"
    echo "Setting up Python venv in $dir"
    # Remove old venv if exists
    if [ -d "$venv_dir" ]; then
        echo "Removing old venv in $dir"
        rm -rf "$venv_dir"
    fi
    # Create new venv
    python3 -m venv "$venv_dir"
    # Activate venv and install dependencies
    if [[ $(basename "$file") == "requirements.txt" ]]; then
        echo "Installing Python dependencies from requirements.txt in $dir"
        "$venv_dir/bin/pip" install --upgrade pip
        "$venv_dir/bin/pip" install -r "$dir/requirements.txt"
    elif [[ $(basename "$file") == "pyproject.toml" ]]; then
        echo "Installing Python dependencies from pyproject.toml in $dir"
        "$venv_dir/bin/pip" install --upgrade pip
        if command -v uv &> /dev/null; then
            (cd "$dir" && "$venv_dir/bin/python" -m uv sync)
        else
            (cd "$dir" && "$venv_dir/bin/pip" install .)
        fi
    fi
done

# Find and install Node.js dependencies
find . -type f -name "package.json" | while read -r file; do
    dir=$(dirname "$file")
    node_modules_dir="$dir/node_modules"
    echo "Installing Node.js dependencies in $dir"
    # Remove old node_modules if exists
    if [ -d "$node_modules_dir" ]; then
        echo "Removing old node_modules in $dir"
        rm -rf "$node_modules_dir"
    fi
    (cd "$dir" && npm install)
done

# Find and install Go dependencies
find . -type f -name "go.mod" | while read -r file; do
    dir=$(dirname "$file")
    vendor_dir="$dir/vendor"
    echo "Installing Go dependencies in $dir"
    # Remove old vendor if exists
    if [ -d "$vendor_dir" ]; then
        echo "Removing old vendor in $dir"
        rm -rf "$vendor_dir"
    fi
    (cd "$dir" && go mod tidy)
done

echo "All dependencies installed!"
