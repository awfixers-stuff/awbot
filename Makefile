# AWBot Development Makefile
# Provides convenient commands for common development tasks

.PHONY: help dev setup clean test lint format type-check pre-commit install update run build docker docs

# Default target
help: ## Show this help message
	@echo "AWBot Development Commands"
	@echo "========================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development environment setup
dev: ## Enter Nix development shell
	@echo "🚀 Starting development environment..."
	nix develop

setup: ## Set up development environment (run after 'make dev')
	@echo "🔧 Setting up development environment..."
	./scripts/dev-setup.sh

# Dependency management
install: ## Install all dependencies
	@echo "📦 Installing dependencies..."
	poetry install --all-extras

update: ## Update dependencies
	@echo "🔄 Updating dependencies..."
	poetry update

# Code quality
lint: ## Run linting with ruff
	@echo "🔍 Running linter..."
	poetry run ruff check .

format: ## Format code with ruff
	@echo "✨ Formatting code..."
	poetry run ruff format .

type-check: ## Run type checking with pyright
	@echo "🔬 Running type checker..."
	poetry run pyright

pre-commit: ## Run all pre-commit hooks
	@echo "🪝 Running pre-commit hooks..."
	pre-commit run --all-files

# Testing
test: ## Run tests
	@echo "🧪 Running tests..."
	poetry run pytest

test-cov: ## Run tests with coverage
	@echo "🧪 Running tests with coverage..."
	poetry run pytest --cov=awbot --cov-report=html --cov-report=term

test-fast: ## Run tests in parallel
	@echo "🧪 Running tests in parallel..."
	poetry run pytest -n auto

# Application
run: ## Run the bot
	@echo "🤖 Starting AWBot..."
	poetry run awbot

run-dev: ## Run the bot in development mode
	@echo "🤖 Starting AWBot in development mode..."
	poetry run python -m awbot

# Database
db-generate: ## Generate Prisma client
	@echo "🗄️  Generating Prisma client..."
	poetry run prisma generate

db-migrate: ## Run database migrations
	@echo "🗄️  Running database migrations..."
	poetry run prisma migrate dev

db-deploy: ## Deploy database migrations
	@echo "🗄️  Deploying database migrations..."
	poetry run prisma migrate deploy

db-studio: ## Open Prisma Studio
	@echo "🗄️  Opening Prisma Studio..."
	poetry run prisma studio

db-reset: ## Reset database
	@echo "🗄️  Resetting database..."
	poetry run prisma migrate reset

# Docker
docker-build: ## Build Docker image
	@echo "🐳 Building Docker image..."
	docker build -t awbot .

docker-run: ## Run Docker container
	@echo "🐳 Running Docker container..."
	docker run -it --env-file .env awbot

docker-dev: ## Run development Docker environment
	@echo "🐳 Starting development Docker environment..."
	docker-compose -f docker-compose.dev.yml up

# Documentation
docs-serve: ## Serve documentation locally
	@echo "📚 Serving documentation..."
	poetry run mkdocs serve

docs-build: ## Build documentation
	@echo "📚 Building documentation..."
	poetry run mkdocs build

# Cleanup
clean: ## Clean up generated files
	@echo "🧹 Cleaning up..."
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	rm -rf site/
	rm -rf dist/
	rm -rf *.egg-info/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

clean-venv: ## Remove virtual environment
	@echo "🧹 Removing virtual environment..."
	rm -rf .venv/

# Git hooks
hooks-install: ## Install git hooks
	@echo "🪝 Installing git hooks..."
	pre-commit install

hooks-update: ## Update git hooks
	@echo "🪝 Updating git hooks..."
	pre-commit autoupdate

# All-in-one commands
check: lint type-check test ## Run all checks (lint, type-check, test)

ci: check ## Run CI pipeline locally

fresh-start: clean-venv setup install ## Fresh start (clean venv, setup, install)

# Release
version: ## Show current version
	@echo "📋 Current version:"
	@poetry version

version-patch: ## Bump patch version
	@echo "📋 Bumping patch version..."
	poetry version patch

version-minor: ## Bump minor version
	@echo "📋 Bumping minor version..."
	poetry version minor

version-major: ## Bump major version
	@echo "📋 Bumping major version..."
	poetry version major