#!/usr/bin/env bash

set -e

echo "Starting global dependency installation..."

# Find and install Python dependencies
find . -type f \( -name "requirements.txt" -o -name "pyproject.toml" \) | while read -r file; do
    dir=$(dirname "$file")
    echo "Installing Python dependencies in $dir"
    if [[ $(basename "$file") == "requirements.txt" ]]; then
        (cd "$dir" && uv pip install -r requirements.txt)
    elif [[ $(basename "$file") == "pyproject.toml" ]]; then
        (cd "$dir" && uv sync)
    fi
done

# Find and install Node.js dependencies
find . -type f -name "package.json" | while read -r file; do
    dir=$(dirname "$file")
    echo "Installing Node.js dependencies in $dir"
    (cd "$dir" && npm install)
done

# Find and install Go dependencies
find . -type f -name "go.mod" | while read -r file; do
    dir=$(dirname "$file")
    echo "Installing Go dependencies in $dir"
    (cd "$dir" && go mod tidy)
done

echo "All dependencies installed!"
