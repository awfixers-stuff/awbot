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

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PATH="$PROJECT_ROOT/.venv"

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

# Upgrade pip
log_info "Upgrading pip..."
pip install --upgrade pip

# Configure Poetry to use the project's virtual environment
log_info "Configuring Poetry..."
poetry config virtualenvs.in-project true
poetry config virtualenvs.path "$PROJECT_ROOT"

# Install dependencies with Poetry
if [ -f "pyproject.toml" ]; then
    log_info "Installing Python dependencies with Poetry..."
    poetry install --all-extras
    log_success "Dependencies installed successfully"
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

# Generate Prisma client if schema exists
if [ -f "prisma/schema.prisma" ]; then
    log_info "Generating Prisma client..."
    poetry run prisma generate
    log_success "Prisma client generated"
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
echo -e "${BLUE}🐍 Python version:${NC} $(python --version)"
echo -e "${BLUE}📦 Poetry version:${NC} $(poetry --version)"
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