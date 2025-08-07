#!/usr/bin/env bash

# Docker Troubleshooting Script for AWBot
# Helps diagnose and fix common Docker build and runtime issues

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

log_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if we're in the right directory
check_project_directory() {
    log_header "Checking Project Directory"
    
    if [[ ! -f "pyproject.toml" ]]; then
        log_error "Not in the AWBot project directory!"
        log_info "Please run this script from the awbot project root directory"
        exit 1
    fi
    
    log_success "In correct project directory"
}

# Check Docker installation
check_docker() {
    log_header "Checking Docker Installation"
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        log_info "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or not accessible"
        log_info "Please start Docker daemon or check permissions"
        exit 1
    fi
    
    log_success "Docker is installed and running"
    log_info "Docker version: $(docker --version)"
}

# Check git submodules
check_submodules() {
    log_header "Checking Git Submodules"
    
    if [[ ! -f ".gitmodules" ]]; then
        log_warning "No .gitmodules file found"
        return 0
    fi
    
    # Check if discord.py submodule is initialized
    if [[ ! -f "discord.py/pyproject.toml" ]]; then
        log_warning "discord.py submodule not initialized"
        log_info "Initializing git submodules..."
        
        if git submodule update --init --recursive; then
            log_success "Git submodules initialized"
        else
            log_error "Failed to initialize git submodules"
            log_info "Try running manually: git submodule update --init --recursive"
            exit 1
        fi
    else
        log_success "Git submodules are initialized"
    fi
    
    # Check if submodule is up to date
    if git submodule status | grep -q "^+"; then
        log_warning "Git submodules are not up to date"
        log_info "Updating git submodules..."
        git submodule update --recursive
        log_success "Git submodules updated"
    else
        log_success "Git submodules are up to date"
    fi
}

# Check required files
check_required_files() {
    log_header "Checking Required Files"
    
    required_files=(
        "Dockerfile"
        "pyproject.toml"
        "poetry.lock"
        "discord.py/pyproject.toml"
        "awbot/__init__.py"
        "prisma/schema.prisma"
    )
    
    missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
            log_error "Missing required file: $file"
        else
            log_success "Found: $file"
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files for Docker build"
        log_info "Please ensure all required files are present"
        exit 1
    fi
}

# Check environment configuration
check_environment() {
    log_header "Checking Environment Configuration"
    
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            log_warning ".env file not found, but .env.example exists"
            log_info "Consider copying: cp .env.example .env"
        else
            log_warning "No .env or .env.example file found"
        fi
    else
        log_success ".env file exists"
        
        # Check for required environment variables
        required_vars=("DISCORD_TOKEN" "DATABASE_URL")
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" .env; then
                log_success "Found $var in .env"
            else
                log_warning "$var not found in .env"
            fi
        done
    fi
}

# Check Docker build context
check_build_context() {
    log_header "Checking Docker Build Context"
    
    # Check .dockerignore
    if [[ -f ".dockerignore" ]]; then
        log_success ".dockerignore file exists"
        
        # Check if important files are not ignored
        if grep -q "^discord\.py/" .dockerignore; then
            log_error "discord.py/ is excluded in .dockerignore!"
            log_info "Remove 'discord.py/' from .dockerignore or fix the exclusion"
        else
            log_success "discord.py/ is not excluded in .dockerignore"
        fi
    else
        log_warning ".dockerignore file not found"
    fi
    
    # Check build context size
    log_info "Checking build context size..."
    context_size=$(du -sh . 2>/dev/null | cut -f1 || echo "unknown")
    log_info "Build context size: $context_size"
    
    if [[ -d ".git" ]]; then
        git_size=$(du -sh .git 2>/dev/null | cut -f1 || echo "unknown")
        log_warning "Git directory size: $git_size (excluded by .dockerignore)"
    fi
}

# Perform Docker build test
test_docker_build() {
    log_header "Testing Docker Build"
    
    log_info "Attempting Docker build (this may take a while)..."
    
    # Build with verbose output and capture result
    if docker build --progress=plain -t awbot:test . 2>&1 | tee docker-build.log; then
        log_success "Docker build completed successfully!"
        log_info "Build log saved to: docker-build.log"
        
        # Check image size
        image_size=$(docker images awbot:test --format "table {{.Size}}" | tail -n 1)
        log_info "Built image size: $image_size"
        
        # Clean up test image
        docker rmi awbot:test &>/dev/null || true
        
    else
        log_error "Docker build failed!"
        log_info "Build log saved to: docker-build.log"
        log_info "Check the log file for detailed error information"
        
        # Show last few lines of error
        echo ""
        log_info "Last 10 lines of build output:"
        tail -n 10 docker-build.log
        
        return 1
    fi
}

# Clean up Docker resources
cleanup_docker() {
    log_header "Docker Cleanup"
    
    log_info "Cleaning up Docker resources..."
    
    # Remove dangling images
    if docker images -f "dangling=true" -q | wc -l | grep -q "^0$"; then
        log_info "No dangling images to remove"
    else
        docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
        log_success "Removed dangling images"
    fi
    
    # Remove build cache (optional)
    read -p "Do you want to remove Docker build cache? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker builder prune -f
        log_success "Docker build cache cleared"
    fi
}

# Show helpful commands
show_helpful_commands() {
    log_header "Helpful Commands"
    
    echo "Manual Docker commands:"
    echo "  docker build -t awbot .                    # Build production image"
    echo "  docker build --target dev -t awbot:dev .   # Build development image"
    echo "  docker run -it --env-file .env awbot       # Run container"
    echo ""
    echo "Make commands:"
    echo "  make docker-submodules                     # Update git submodules"
    echo "  make docker-build                          # Build with submodule check"
    echo "  make docker-dev                            # Run development environment"
    echo ""
    echo "Debugging:"
    echo "  docker build --progress=plain -t awbot .   # Build with verbose output"
    echo "  docker run -it awbot /bin/bash             # Interactive shell in container"
    echo "  docker logs <container_id>                 # View container logs"
}

# Main function
main() {
    log_header "AWBot Docker Troubleshooting"
    log_info "This script will help diagnose Docker build and runtime issues"
    
    check_project_directory
    check_docker
    check_submodules
    check_required_files
    check_environment
    check_build_context
    
    echo ""
    read -p "Do you want to test Docker build? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if test_docker_build; then
            log_success "All checks passed! Docker build is working correctly."
        else
            log_error "Docker build test failed. Check the logs above for details."
        fi
    else
        log_info "Skipping Docker build test"
    fi
    
    echo ""
    read -p "Do you want to clean up Docker resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_docker
    fi
    
    show_helpful_commands
    
    echo ""
    log_success "Troubleshooting complete!"
    log_info "If you're still having issues, check TROUBLESHOOTING.md or ask for help"
}

# Run main function
main "$@"