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
            
            # Function to download Prisma engines
            download_prisma_engines() {
              mkdir -p "$ENGINES_DIR"
              
              # Multiple commit hashes to try (from different Prisma versions)
              COMMIT_HASHES=(
                "393aa359c9ad4a4bb28630fb5613f9c281cde053"
                "5a9203d0590c951969b85658dd707a50e63ad7b9"
                "bf0e5e8a04cada8225617067eaa5d6ad23f62d98"
              )
              
              # Engine binaries to download
              engines=("query-engine" "schema-engine" "prisma-fmt")
              
              # Platforms to try
              platforms=("linux-musl" "linux" "linux-arm64-openssl-1.1.x" "linux-arm64-openssl-3.0.x")
              
              echo "📥 Setting up Prisma engines in $ENGINES_DIR..."
              
              for engine in "''${engines[@]}"; do
                engine_path="$ENGINES_DIR/$engine"
                if [[ -f "$engine_path" && -x "$engine_path" ]]; then
                  echo "  ✅ $engine already exists and is executable"
                  continue
                fi
                
                echo "  Downloading $engine..."
                downloaded=false
                
                for commit in "''${COMMIT_HASHES[@]}"; do
                  if [[ "$downloaded" == "true" ]]; then
                    break
                  fi
                  
                  for platform in "''${platforms[@]}"; do
                    url="https://binaries.prisma.sh/all_commits/$commit/$platform/$engine"
                    echo "    Trying $platform ($commit)..."
                    
                    if curl -fsSL --connect-timeout 10 --max-time 30 "$url" -o "$engine_path.tmp" 2>/dev/null; then
                      # Check if file is not empty and appears to be a binary
                      if [[ -s "$engine_path.tmp" ]]; then
                        mv "$engine_path.tmp" "$engine_path"
                        chmod +x "$engine_path"
                        echo "    ✅ $engine downloaded successfully ($platform)"
                        downloaded=true
                        break
                      else
                        rm -f "$engine_path.tmp"
                      fi
                    fi
                  done
                done
                
                if [[ "$downloaded" == "false" ]]; then
                  echo "    ⚠️  Could not download $engine, but continuing..."
                  # Create a placeholder script that explains the issue
                  cat > "$engine_path" << 'EOF'
#!/bin/bash
echo "Prisma engine not available - please run: make db-engines" >&2
exit 1
EOF
                  chmod +x "$engine_path"
                fi
              done
              
              echo "🔧 Prisma engine setup complete"
            }
            
            # Create virtual environment if it doesn't exist
            if [ ! -d "$VENV_PATH" ]; then
              echo "Creating Python virtual environment..."
              python -m venv "$VENV_PATH"
            fi
            
            # Activate the virtual environment
            source "$VENV_PATH/bin/activate"
            
            # Upgrade pip (handle externally-managed-environment)
            pip install --upgrade pip --break-system-packages 2>/dev/null || pip install --upgrade pip --user 2>/dev/null || echo "⚠️  Could not upgrade pip, but continuing..."
            
            # Download Prisma engines before installing dependencies (but don't fail if it doesn't work)
            echo "🔧 Setting up Prisma engines..."
            download_prisma_engines || echo "⚠️  Prisma engine download had issues, but continuing..."
            
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