# AWBot Development Environment Setup

This document provides comprehensive instructions for setting up the AWBot development environment using Nix, Python virtual environments, and Poetry.

## Prerequisites

Before setting up the development environment, ensure you have the following installed:

- [Nix](https://nixos.org/download.html) (with flakes enabled)
- [Git](https://git-scm.com/downloads)
- [direnv](https://direnv.net/docs/installation.html) (optional but recommended)

### Enabling Nix Flakes

If you haven't enabled Nix flakes yet, add the following to your `~/.config/nix/nix.conf` (create the file if it doesn't exist):

```
experimental-features = nix-command flakes
```

## Quick Start

### Method 1: Using Nix Develop (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/allthingslinux/awbot.git
   cd awbot
   ```

2. Enter the Nix development shell:
   ```bash
   nix develop
   ```

   This will automatically:
   - Set up the Nix development environment
   - Create a Python virtual environment in `.venv/`
   - Install all Python dependencies using Poetry
   - Install pre-commit hooks
   - Generate the Prisma client
   - Provide helpful information about available commands

3. Start developing! The environment is now ready.

### Method 2: Using Makefile

1. Clone the repository and enter the Nix shell:
   ```bash
   git clone https://github.com/allthingslinux/awbot.git
   cd awbot
   make dev
   ```

2. In the Nix shell, run the setup:
   ```bash
   make setup
   ```

### Method 3: Using direnv (Automatic)

1. Install and configure direnv following the [official instructions](https://direnv.net/docs/installation.html)

2. Clone the repository:
   ```bash
   git clone https://github.com/allthingslinux/awbot.git
   cd awbot
   ```

3. Allow direnv to activate:
   ```bash
   direnv allow
   ```

4. The environment will automatically activate whenever you enter the directory!

## Development Environment Features

The development environment provides:

- **Python 3.13.5** with virtual environment management
- **Poetry** for dependency management
- **Node.js 20** and **Prisma** for database operations
- **Pre-commit hooks** for code quality
- **Ruff** for linting and formatting
- **Pyright** for type checking
- **pytest** for testing
- All project dependencies automatically installed

## Available Commands

### Using Poetry (Primary Method)

```bash
# Run the bot
poetry run awbot

# Run tests
poetry run pytest
poetry run pytest --cov  # with coverage

# Code quality
poetry run ruff check    # linting
poetry run ruff format   # formatting
poetry run pyright       # type checking

# Database operations
poetry run prisma generate      # generate client
poetry run prisma migrate dev   # run migrations
poetry run prisma studio        # open database studio
```

### Using Make Commands

```bash
# Show all available commands
make help

# Environment setup
make dev        # Enter Nix development shell
make setup      # Set up development environment

# Development
make run        # Run the bot
make test       # Run tests
make test-cov   # Run tests with coverage
make lint       # Run linting
make format     # Format code
make type-check # Type checking
make check      # Run all checks (lint + type + test)

# Database
make db-generate  # Generate Prisma client
make db-migrate   # Run migrations
make db-studio    # Open Prisma Studio

# Docker
make docker-build # Build Docker image
make docker-dev   # Run development environment

# Documentation
make docs-serve   # Serve docs locally
make docs-build   # Build documentation

# Cleanup
make clean        # Clean generated files
make clean-venv   # Remove virtual environment
```

## Configuration

### Environment Variables

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your configuration:
   ```bash
   # Discord Bot Token
   DISCORD_TOKEN="your_discord_bot_token"
   
   # Database
   DATABASE_URL="your_database_url"
   
   # Other configuration...
   ```

### Poetry Configuration

The development environment automatically configures Poetry to:
- Use the project's virtual environment (`.venv/`)
- Install all dependency groups (main, dev, test, docs, types)

## Project Structure

```
awbot/
├── awbot/                 # Main bot package
├── tests/                 # Test files
├── scripts/               # Development scripts
├── prisma/               # Database schema and migrations
├── config/               # Configuration files
├── .venv/                # Python virtual environment (auto-created)
├── flake.nix             # Nix development environment
├── pyproject.toml        # Poetry configuration
├── Makefile              # Development commands
├── .envrc                # direnv configuration
└── DEVELOPMENT.md        # This file
```

## Troubleshooting

### Virtual Environment Issues

If you encounter issues with the virtual environment:

```bash
# Remove and recreate the virtual environment
make clean-venv
make setup
```

### Poetry Issues

If Poetry isn't working correctly:

```bash
# Reset Poetry configuration
poetry config --unset virtualenvs.path
poetry config virtualenvs.in-project true
poetry install --all-extras
```

### Nix Issues

If Nix isn't finding the flake:

```bash
# Ensure you're in the project directory
cd /path/to/awbot

# Try rebuilding the development shell
nix develop --rebuild
```

### Pre-commit Issues

If pre-commit hooks aren't working:

```bash
# Reinstall pre-commit hooks
pre-commit uninstall
pre-commit install
```

## Development Workflow

### Starting Development

1. Enter the development environment:
   ```bash
   nix develop  # or just cd into directory if using direnv
   ```

2. Create a new branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Start developing!

### Code Quality Checks

Before committing, run:

```bash
make check  # Runs linting, type checking, and tests
```

Or individually:

```bash
make lint        # Check code style
make format      # Fix code formatting
make type-check  # Check types
make test        # Run tests
```

### Committing Changes

The pre-commit hooks will automatically run when you commit:

```bash
git add .
git commit -m "feat: add new feature"
```

If you want to run all pre-commit checks manually:

```bash
make pre-commit
```

### Database Development

When working with the database:

```bash
# Generate Prisma client after schema changes
make db-generate

# Create and run migrations
make db-migrate

# Open Prisma Studio for data exploration
make db-studio
```

## IDE Configuration

### VS Code

The project includes VS Code configuration in `.vscode/`. Key features:

- Python interpreter automatically set to `.venv/bin/python`
- Recommended extensions for Python development
- Integrated terminal uses the virtual environment
- Debugging configuration for the bot

### PyCharm

For PyCharm users:

1. Open the project directory
2. Go to File → Settings → Project → Python Interpreter
3. Select "Existing environment" and point to `.venv/bin/python`
4. Enable Poetry integration in Settings → Languages & Frameworks → Python → Poetry

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run tests with coverage
make test-cov

# Run tests in parallel (faster)
make test-fast

# Run specific test file
poetry run pytest tests/test_specific.py

# Run tests with specific markers
poetry run pytest -m "not slow"
```

### Writing Tests

- Place test files in the `tests/` directory
- Use the naming convention `test_*.py`
- Follow the existing test patterns and fixtures

## Documentation

### Serving Documentation Locally

```bash
make docs-serve
```

This will start a local server (usually at http://127.0.0.1:8000) with the documentation.

### Building Documentation

```bash
make docs-build
```

The built documentation will be in the `site/` directory.

## Docker Development

### Building Docker Image

```bash
make docker-build
```

### Running Development Environment with Docker

```bash
make docker-dev
```

This uses `docker-compose.dev.yml` for the development environment.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Set up the development environment using this guide
4. Make your changes
5. Run tests and quality checks: `make check`
6. Commit your changes with conventional commit messages
7. Push to your fork and create a pull request

## Getting Help

- Check the [main README](README.md) for general project information
- Review the [Docker documentation](DOCKER.md) for container-specific setup
- Look at existing code and tests for examples
- Join the All Things Linux Discord server for community support

## Advanced Usage

### Custom Nix Shell

If you need to customize the Nix environment, edit `flake.nix`:

```nix
buildInputs = with pkgs; [
  # Add your packages here
  python313
  nodejs_20
  # ... existing packages
];
```

### Poetry Scripts

Add custom scripts to `pyproject.toml`:

```toml
[project.scripts]
my-script = "awbot.my_module:main"
```

Then run with:

```bash
poetry run my-script
```

### Environment Variables in Development

Use `.env` files for local development:

```bash
# .env.local (not tracked by git)
DEBUG=true
LOG_LEVEL=debug
```

Load them with:

```bash
export $(cat .env.local | xargs)
```

Happy coding! 🚀