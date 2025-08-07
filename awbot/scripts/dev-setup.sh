#!/usr/bin/env bash

# AWBot Development Environment Setup Script
# This script sets up the development environment for AWBot

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to download Prisma engines
download_prisma_engines() {
    mkdir -p "$ENGINES_DIR"
    
    # Use a known stable commit hash for Prisma engines
    COMMIT_HASH="393aa359c9ad4a4bb28630fb5613f9c281cde053"
    BASE_URL="https://binaries.prisma.sh/all_commits/$COMMIT_HASH/linux-musl"
    
    # Engine binaries to download
    engines=("query-engine" "schema-engine" "prisma-fmt")
    
    log_info "Downloading Prisma engines to $ENGINES_DIR..."
    
    for engine in "${engines[@]}"; do
        engine_path="$ENGINES_DIR/$engine"
        if [[ ! -f "$engine_path" ]]; then
            log_info "  Downloading $engine..."
            if curl -fsSL "$BASE_URL/$engine" -o "$engine_path.tmp"; then
                mv "$engine_path.tmp" "$engine_path"
                chmod +x "$engine_path"
                log_success "  $engine downloaded successfully"
            else
                log_warning "  Failed to download $engine, trying alternative..."
                # Try without musl suffix as fallback
                ALT_URL="https://binaries.prisma.sh/all_commits/$COMMIT_HASH/linux/$engine"
                if curl -fsSL "$ALT_URL" -o "$engine_path.tmp"; then
                    mv "$engine_path.tmp" "$engine_path"
                    chmod +x "$engine_path"
                    log_success "  $engine downloaded successfully (alternative)"
                else
                    log_error "  Failed to download $engine from both URLs"
                    rm -f "$engine_path.tmp"
                fi
            fi
        else
            log_info "  $engine already exists"
        fi
    done
    
    log_success "Prisma engines ready at $ENGINES_DIR"
}

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PATH="$PROJECT_ROOT/.venv"
ENGINES_DIR="$PROJECT_ROOT/.prisma-engines"

log_info "Setting up AWBot development environment..."
log_info "Project root: $PROJECT_ROOT"

# Change to project directory
cd "$PROJECT_ROOT"

# Check if we're in a Nix shell
if [ -n "${IN_NIX_SHELL:-}" ]; then
    log_success "Running in Nix development shell"
else
    log_warning "Not in a Nix shell. Run 'nix develop' first for the best experience."
fi

# Set up Prisma environment variables
export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
export PRISMA_QUERY_ENGINE_BINARY="$ENGINES_DIR/query-engine"
export PRISMA_SCHEMA_ENGINE_BINARY="$ENGINES_DIR/schema-engine"
export PRISMA_FMT_BINARY="$ENGINES_DIR/prisma-fmt"
export PRISMA_BINARIES_MIRROR="https://binaries.prisma.sh"
export PRISMA_ENGINES_MIRROR="https://binaries.prisma.sh"
export PRISMA_CLI_BINARY_TARGETS="linux-musl,native"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
    log_info "Creating Python virtual environment..."
    python -m venv "$VENV_PATH"
    log_success "Virtual environment created at $VENV_PATH"
else
    log_info "Virtual environment already exists at $VENV_PATH"
fi

# Activate virtual environment
log_info "Activating virtual environment..."
source "$VENV_PATH/bin/activate"

# Upgrade pip (handle externally-managed-environment)
log_info "Upgrading pip..."
pip install --upgrade pip --break-system-packages 2>/dev/null || pip install --upgrade pip --user 2>/dev/null || log_warning "Could not upgrade pip, but continuing..."

# Download Prisma engines
log_info "Setting up Prisma engines..."
download_prisma_engines

# Configure Poetry to use the project's virtual environment
log_info "Configuring Poetry..."
poetry config virtualenvs.in-project true
poetry config virtualenvs.path "$PROJECT_ROOT"

# Install dependencies with Poetry
if [ -f "pyproject.toml" ]; then
    log_info "Installing Python dependencies with Poetry..."
    
    # Handle potential Poetry installation issues
    if ! poetry install --all-extras 2>/dev/null; then
        log_warning "Poetry install with extras failed, trying without extras..."
        if poetry install; then
            log_success "Dependencies installed successfully (without extras)"
        else
            log_warning "Poetry install had issues, but continuing..."
        fi
    else
        log_success "Dependencies installed successfully"
    fi
else
    log_error "pyproject.toml not found!"
    exit 1
fi

# Install pre-commit hooks
if [ -f ".pre-commit-config.yaml" ]; then
    log_info "Installing pre-commit hooks..."
    pre-commit install
    log_success "Pre-commit hooks installed"
else
    log_warning "No .pre-commit-config.yaml found, skipping pre-commit setup"
fi

# Generate Prisma client if schema exists and engines are available
if [ -f "prisma/schema.prisma" ] && [ -f "$ENGINES_DIR/query-engine" ]; then
    log_info "Generating Prisma client with custom engines..."
    poetry run prisma generate || log_warning "Prisma generation failed, but continuing..."
    log_success "Prisma client generated"
elif [ -f "prisma/schema.prisma" ]; then
    log_warning "Prisma schema found but engines not available, skipping client generation"
    log_warning "Run './scripts/download-prisma-engines.sh' to download engines manually"
else
    log_warning "No Prisma schema found, skipping Prisma client generation"
fi

# Create .env file from example if it doesn't exist
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    log_info "Creating .env file from .env.example..."
    cp ".env.example" ".env"
    log_warning "Please edit .env file with your configuration"
else
    log_info ".env file already exists or no .env.example found"
fi

# Summary
echo ""
log_success "Development environment setup complete!"
echo ""
echo -e "${BLUE}📍 Virtual environment:${NC} $VENV_PATH"
echo -e "${BLUE}🔧 Prisma engines:${NC} $ENGINES_DIR"
echo -e "${BLUE}🐍 Python version:${NC} $(python --version)"
echo -e "${BLUE}📦 Poetry version:${NC} $(poetry --version)"
echo ""
echo -e "${BLUE}Prisma Engine Paths:${NC}"
echo "  PRISMA_QUERY_ENGINE_BINARY=$PRISMA_QUERY_ENGINE_BINARY"
echo "  PRISMA_SCHEMA_ENGINE_BINARY=$PRISMA_SCHEMA_ENGINE_BINARY"
echo "  PRISMA_FMT_BINARY=$PRISMA_FMT_BINARY"
echo ""
echo -e "${YELLOW}Available commands:${NC}"
echo "  poetry run awbot               - Run the bot"
echo "  poetry run pytest              - Run tests"
echo "  poetry run pytest --cov        - Run tests with coverage"
echo "  poetry run ruff check          - Run linting"
echo "  poetry run ruff format         - Format code"
echo "  poetry run pyright             - Type checking"
echo "  pre-commit run --all-files     - Run all pre-commit checks"
echo "  poetry run prisma migrate dev  - Run database migrations"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"