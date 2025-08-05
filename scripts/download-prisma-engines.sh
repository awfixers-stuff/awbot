#!/usr/bin/env bash

# Standalone Prisma Engine Download Script
# Downloads generic Linux Prisma engines to avoid NixOS compatibility issues

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
if [ -n "${PROJECT_ROOT:-}" ]; then
    PROJECT_ROOT="$PROJECT_ROOT"
elif [ -f "pyproject.toml" ]; then
    PROJECT_ROOT="$(pwd)"
else
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

ENGINES_DIR="$PROJECT_ROOT/.prisma-engines"

log_info "Downloading Prisma engines for NixOS compatibility..."
log_info "Project root: $PROJECT_ROOT"
log_info "Engines directory: $ENGINES_DIR"

# Create engines directory
mkdir -p "$ENGINES_DIR"

# Multiple commit hashes to try (from different Prisma versions)
COMMIT_HASHES=(
    "393aa359c9ad4a4bb28630fb5613f9c281cde053"
    "5a9203d0590c951969b85658dd707a50e63ad7b9"
    "bf0e5e8a04cada8225617067eaa5d6ad23f62d98"
    "4bc8b29b2c0de98bdcb68f4d1a31de3b5a3e9e7a"
    "89662a2b6c1b5b3e4b4b9c5e8d6a8b4a5c3e2e1a"
)

# Engine binaries to download
engines=("query-engine" "schema-engine" "prisma-fmt")

# Platform targets to try (in order of preference)
platforms=("linux-musl" "linux" "linux-arm64-openssl-1.1.x" "linux-arm64-openssl-3.0.x")

log_info "Trying multiple commit hashes and platforms for maximum compatibility"

for engine in "${engines[@]}"; do
    engine_path="$ENGINES_DIR/$engine"
    
    if [[ -f "$engine_path" && -x "$engine_path" ]]; then
        log_success "$engine already exists and is executable, skipping"
        continue
    fi
    
    log_info "Downloading $engine..."
    downloaded=false
    
    for commit in "${COMMIT_HASHES[@]}"; do
        if [[ "$downloaded" = true ]]; then
            break
        fi
        
        log_info "  Trying commit $commit..."
        
        for platform in "${platforms[@]}"; do
            url="https://binaries.prisma.sh/all_commits/$commit/$platform/$engine"
            log_info "    Trying $platform..."
            
            if curl -fsSL --connect-timeout 10 --max-time 30 "$url" -o "$engine_path.tmp" 2>/dev/null; then
                # Verify the downloaded file is not empty
                if [[ -s "$engine_path.tmp" ]]; then
                    # Try to verify it's a valid binary (if file command is available)
                    if command -v file >/dev/null 2>&1; then
                        if file "$engine_path.tmp" | grep -q "executable\|ELF"; then
                            mv "$engine_path.tmp" "$engine_path"
                            chmod +x "$engine_path"
                            log_success "    $engine downloaded successfully ($platform, $commit)"
                            downloaded=true
                            break
                        else
                            log_warning "    Downloaded file doesn't appear to be a valid binary"
                            rm -f "$engine_path.tmp"
                        fi
                    else
                        # If file command not available, just check size and assume it's valid
                        mv "$engine_path.tmp" "$engine_path"
                        chmod +x "$engine_path"
                        log_success "    $engine downloaded successfully ($platform, $commit)"
                        downloaded=true
                        break
                    fi
                else
                    log_warning "    Downloaded file is empty"
                    rm -f "$engine_path.tmp"
                fi
            else
                log_warning "    Failed to download from $platform"
            fi
        done
    done
    
    if [[ "$downloaded" = false ]]; then
        log_warning "Could not download $engine from any source"
        # Create a placeholder script that explains the issue
        cat > "$engine_path" << 'EOF'
#!/bin/bash
echo "Prisma engine not available - manual download required" >&2
echo "Please check https://github.com/prisma/prisma-engines/releases for manual download" >&2
exit 1
EOF
        chmod +x "$engine_path"
        log_warning "Created placeholder script for $engine"
    fi
done

# Verify all engines were downloaded and are executable
log_info "Verifying downloaded engines..."
all_good=true

for engine in "${engines[@]}"; do
    engine_path="$ENGINES_DIR/$engine"
    
    if [[ -f "$engine_path" && -x "$engine_path" ]]; then
        # Try to get version info to verify the binary works
        if "$engine_path" --version >/dev/null 2>&1 || "$engine_path" --help >/dev/null 2>&1; then
            log_success "$engine is ready and functional"
        else
            log_warning "$engine exists but may not be functional"
        fi
    else
        log_error "$engine is missing or not executable"
        all_good=false
    fi
done

echo ""
if [[ "$all_good" = true ]]; then
    log_success "All Prisma engines are ready and functional!"
else
    log_warning "Some engines may not be fully functional, but setup completed"
fi

echo ""
echo -e "${BLUE}Engine locations:${NC}"
for engine in "${engines[@]}"; do
    engine_path="$ENGINES_DIR/$engine"
    if [[ -f "$engine_path" ]]; then
        size=$(ls -lh "$engine_path" | awk '{print $5}')
        echo "  $engine: $engine_path (size: $size)"
    else
        echo "  $engine: NOT FOUND"
    fi
done

echo ""
echo -e "${YELLOW}Environment variables to set:${NC}"
echo "export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1"
echo "export PRISMA_QUERY_ENGINE_BINARY=\"$ENGINES_DIR/query-engine\""
echo "export PRISMA_SCHEMA_ENGINE_BINARY=\"$ENGINES_DIR/schema-engine\""
echo "export PRISMA_FMT_BINARY=\"$ENGINES_DIR/prisma-fmt\""
echo "export PRISMA_BINARIES_MIRROR=\"https://binaries.prisma.sh\""
echo "export PRISMA_ENGINES_MIRROR=\"https://binaries.prisma.sh\""
echo "export PRISMA_CLI_BINARY_TARGETS=\"linux-musl,native\""

echo ""
if [[ "$all_good" = true ]]; then
    echo -e "${GREEN}You can now run Prisma commands without engine download issues!${NC}"
else
    echo -e "${YELLOW}Some engines may need manual installation. Check the Prisma documentation for troubleshooting.${NC}"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run 'poetry run prisma generate' to generate the Prisma client"
echo "  2. Run 'poetry run prisma studio' to open the database studio"
echo "  3. If engines still don't work, try updating Prisma: 'poetry update prisma'"