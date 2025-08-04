{
  description = "AWBot development environment with Python virtual environment";

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
            which
          ];

          # Environment variables
          LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib";
          
          # Shell hook to set up and activate virtual environment
          shellHook = ''
            # Set up the project directory
            export PROJECT_ROOT="$(pwd)"
            export VENV_PATH="$PROJECT_ROOT/.venv"
            
            # Create virtual environment if it doesn't exist
            if [ ! -d "$VENV_PATH" ]; then
              echo "Creating Python virtual environment..."
              python -m venv "$VENV_PATH"
            fi
            
            # Activate the virtual environment
            source "$VENV_PATH/bin/activate"
            
            # Upgrade pip and install poetry if not already installed
            pip install --upgrade pip
            
            # Install dependencies using Poetry
            if [ -f "pyproject.toml" ]; then
              echo "Installing Python dependencies with Poetry..."
              poetry config virtualenvs.in-project true
              poetry config virtualenvs.path "$PROJECT_ROOT"
              poetry install --all-extras
            fi
            
            # Install pre-commit hooks if .pre-commit-config.yaml exists
            if [ -f ".pre-commit-config.yaml" ]; then
              echo "Installing pre-commit hooks..."
              pre-commit install
            fi
            
            echo "✅ Development environment ready!"
            echo "📍 Virtual environment: $VENV_PATH"
            echo "🐍 Python version: $(python --version)"
            echo "📦 Poetry version: $(poetry --version)"
            echo ""
            echo "Available commands:"
            echo "  - poetry run awbot: Run the bot"
            echo "  - poetry run pytest: Run tests"
            echo "  - pre-commit run --all-files: Run pre-commit checks"
            echo ""
          '';
        };
      });
}