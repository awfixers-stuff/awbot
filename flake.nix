{
  description = "AWBot development environment with Python virtual environment and Prisma engine support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js and Prisma for database management
            nodejs_20
            prisma
            openssl

            # Python and related tools
            python313
            python313Packages.pip
            python313Packages.virtualenv
            poetry

            # Additional development tools
            git
            curl
            wget
            which
            gnutar
            gzip
            file

            # Other Languages
            deno
            go
            bun
            cachix
            kubectl
            kubeaudit
            kind
            doctl
            flyctl
            wrangler
            elixir
            elixir-ls
            erlang
            gleam
          ];

          # Environment variables
          LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib";

          # Shell hook to set up and activate virtual environment
          shellHook = ''
            # Set up the project directory
            export PROJECT_ROOT="$(pwd)"
            export VENV_PATH="$PROJECT_ROOT/.venv"
            export ENGINES_DIR="$PROJECT_ROOT/.prisma-engines"

            # Prisma engine environment variables
            export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
            export PRISMA_QUERY_ENGINE_BINARY="$ENGINES_DIR/query-engine"
            export PRISMA_SCHEMA_ENGINE_BINARY="$ENGINES_DIR/schema-engine"
            export PRISMA_FMT_BINARY="$ENGINES_DIR/prisma-fmt"

            # Additional Prisma configuration to prevent NixOS-specific downloads
            export PRISMA_BINARIES_MIRROR="https://binaries.prisma.sh"
            export PRISMA_ENGINES_MIRROR="https://binaries.prisma.sh"
            export PRISMA_CLI_BINARY_TARGETS="linux-musl,native"

            # Create virtual environment if it doesn't exist
            if [ ! -d "$VENV_PATH" ]; then
              echo "Creating Python virtual environment..."
              python -m venv "$VENV_PATH"
            fi

            # Activate the virtual environment
            source "$VENV_PATH/bin/activate"

            # Upgrade pip (handle externally-managed-environment)
            pip install --upgrade pip --break-system-packages 2>/dev/null || pip install --upgrade pip --user 2>/dev/null || echo "⚠️  Could not upgrade pip, but continuing..."

            # Download Prisma engines using Python script if not present
            if [ ! -f "$ENGINES_DIR/query-engine" ] || [ ! -f "$ENGINES_DIR/schema-engine" ] || [ ! -f "$ENGINES_DIR/prisma-fmt" ]; then
              echo "🔄 Downloading Prisma engines with Python script..."
              python3 "$PROJECT_ROOT/scripts/download_prisma_engines.py" || echo "⚠️  Python Prisma engine download failed, continuing..."
            fi

            # Install dependencies using Poetry
            if [ -f "pyproject.toml" ]; then
              echo "Installing Python dependencies with Poetry..."
              poetry config virtualenvs.in-project true
              poetry config virtualenvs.path "$PROJECT_ROOT"

              # Handle potential Poetry installation issues
              if ! poetry install --all-extras 2>/dev/null; then
                echo "⚠️  Poetry install failed, trying alternative approach..."
                # Try installing without extras first
                poetry install || echo "⚠️  Poetry install had issues, but continuing..."
              fi
            fi

            # Generate Prisma client with custom engines (only if engines were downloaded successfully)
            if [ -f "prisma/schema.prisma" ] && [ -f "$ENGINES_DIR/query-engine" ]; then
              echo "🗄️  Generating Prisma client with custom engines..."
              poetry run prisma generate || echo "⚠️  Prisma generation failed, but continuing..."
            elif [ -f "prisma/schema.prisma" ]; then
              echo "⚠️  Prisma schema found but engines not available, skipping client generation"
              echo "    Run 'make db-engines' or './scripts/download-prisma-engines.sh' to download engines"
            fi

            # Install pre-commit hooks if .pre-commit-config.yaml exists
            if [ -f ".pre-commit-config.yaml" ]; then
              echo "Installing pre-commit hooks..."
              pre-commit install
            fi

            echo "✅ Development environment ready!"
            echo "📍 Virtual environment: $VENV_PATH"
            echo "🔧 Prisma engines: $ENGINES_DIR"
            echo "🐍 Python version: $(python --version)"
            echo "📦 Poetry version: $(poetry --version)"
            echo ""
            echo "Prisma Engine Paths:"
            echo "  PRISMA_QUERY_ENGINE_BINARY=$PRISMA_QUERY_ENGINE_BINARY"
            echo "  PRISMA_SCHEMA_ENGINE_BINARY=$PRISMA_SCHEMA_ENGINE_BINARY"
            echo "  PRISMA_FMT_BINARY=$PRISMA_FMT_BINARY"
            echo ""
            echo "Available commands:"
            echo "  - poetry run awbot: Run the bot"
            echo "  - poetry run pytest: Run tests"
            echo "  - poetry run prisma studio: Open database studio"
            echo "  - poetry run prisma generate: Regenerate client"
            echo "  - pre-commit run --all-files: Run pre-commit checks"
            echo ""
          '';
        };
      });
}
