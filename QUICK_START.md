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
git clone https://github.com/allthingslinux/awbot.git
cd awbot
nix develop
```

That's it! 🎉

The `nix develop` command automatically:
- ✅ Sets up the development environment
- ✅ Creates Python virtual environment
- ✅ Installs all dependencies with Poetry
- ✅ Configures pre-commit hooks
- ✅ Generates Prisma client
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

## Need Help?

- See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup
- Check [README.md](README.md) for project overview
- Review [DOCKER.md](DOCKER.md) for container setup

Happy coding! 🚀