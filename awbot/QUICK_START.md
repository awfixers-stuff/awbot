# AWBot Quick Start Guide

Get up and running with AWBot development in minutes!

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- Git

### Enable Nix Flakes

Add to `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

## One-Command Setup

```bash
git clone https://github.com/awfixers-stuff/awbot.git
cd awbot
nix develop
```

That's it! 🎉

The `nix develop` command automatically:
- ✅ Sets up the development environment
- ✅ Creates Python virtual environment
- ✅ Downloads generic Linux Prisma engines (NixOS compatible)
- ✅ Installs all dependencies with Poetry
- ✅ Configures pre-commit hooks
- ✅ Generates Prisma client with custom engines
- ✅ Activates the virtual environment

## Essential Commands

```bash
# Run the bot
poetry run awbot

# Run tests
poetry run pytest

# Code quality
poetry run ruff check    # lint
poetry run ruff format   # format
poetry run pyright       # type check

# Database
poetry run prisma studio # database GUI
```

## Configuration

1. Copy environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your Discord token and database URL.

## Alternative: Use Makefile

```bash
make dev     # Enter Nix shell
make setup   # Setup environment
make help    # See all commands
```

## Alternative: Use direnv (Auto-activation)

1. Install [direnv](https://direnv.net/docs/installation.html)
2. `cd awbot && direnv allow`
3. Environment activates automatically when you enter the directory!

## Alternative: Use Docker

For containerized development:

```bash
# Ensure git submodules are initialized
git submodule update --init --recursive

# Build and run with Docker
make docker-build
make docker-run

# Or use development environment
make docker-dev
```

**Docker Requirements:**
- Docker installed and running
- Git submodules initialized (discord.py dependency)

## Troubleshooting

### Prisma Engine Issues
If you see "Precompiled engine files are not available for nixos":
```bash
# This is automatically handled, but you can manually run:
./scripts/download-prisma-engines.sh
```

### Docker Issues
If you see "Path /app/discord.py does not exist":
```bash
# Initialize git submodules and rebuild
git submodule update --init --recursive
make docker-build

# Or run troubleshooting script
./scripts/docker-troubleshoot.sh
```

### Other Issues
For comprehensive troubleshooting help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

Common solutions:
- Environment issues: `make clean-venv && make setup`
- Prisma problems: `make clean-engines && make db-engines`
- Complete reset: `make clean-all && nix develop`

## Need Help?

- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- **Detailed Setup**: [DEVELOPMENT.md](DEVELOPMENT.md) for comprehensive guide
- **Project Overview**: [README.md](README.md) for general information
- **Docker Setup**: [DOCKER.md](DOCKER.md) for container-specific setup

Happy coding! 🚀
