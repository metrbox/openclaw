#!/usr/bin/env bash
#
# Openclaw LXC Setup Script
#
# Automated installation of Openclaw on a Debian 12 LXC container (Proxmox)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USER/openclaw-railway-template/main/scripts/lxc-setup.sh | bash
#
#   Or download and run:
#   chmod +x lxc-setup.sh
#   ./lxc-setup.sh
#
# Environment variables (optional):
#   SETUP_PASSWORD      - Password for /setup wizard (will prompt if not set)
#   OPENCLAW_GIT_REF    - Openclaw version/branch to build (default: main)
#   WRAPPER_REPO        - URL of this wrapper repository
#   SKIP_CONFIRM        - Set to "yes" to skip confirmation prompts
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
OPENCLAW_GIT_REF="${OPENCLAW_GIT_REF:-main}"
WRAPPER_REPO="${WRAPPER_REPO:-https://github.com/metrbox/openclaw.git}"
OPENCLAW_DIR="/openclaw"
WRAPPER_DIR="/app"
DATA_DIR="/data"
STATE_DIR="${DATA_DIR}/.openclaw"
WORKSPACE_DIR="${DATA_DIR}/workspace"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if running on Debian 12
check_debian() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    source /etc/os-release
    if [[ "$ID" != "debian" ]] || [[ "$VERSION_ID" != "12" ]]; then
        log_warn "This script is designed for Debian 12 (Bookworm)."
        log_warn "Detected: $PRETTY_NAME"
        if [[ "${SKIP_CONFIRM:-}" != "yes" ]]; then
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Prompt for setup password if not set
get_setup_password() {
    if [[ -z "${SETUP_PASSWORD:-}" ]]; then
        echo
        log_info "No SETUP_PASSWORD environment variable set."
        read -sp "Enter a password for the /setup wizard: " SETUP_PASSWORD
        echo
        if [[ -z "$SETUP_PASSWORD" ]]; then
            log_error "Password cannot be empty"
            exit 1
        fi
        read -sp "Confirm password: " SETUP_PASSWORD_CONFIRM
        echo
        if [[ "$SETUP_PASSWORD" != "$SETUP_PASSWORD_CONFIRM" ]]; then
            log_error "Passwords do not match"
            exit 1
        fi
    fi
    export SETUP_PASSWORD
}

# Show configuration and confirm
confirm_install() {
    echo
    echo "=========================================="
    echo "  Openclaw LXC Installation"
    echo "=========================================="
    echo
    echo "Configuration:"
    echo "  Openclaw version:  ${OPENCLAW_GIT_REF}"
    echo "  Wrapper repo:      ${WRAPPER_REPO}"
    echo "  Install dir:       ${OPENCLAW_DIR}"
    echo "  Wrapper dir:       ${WRAPPER_DIR}"
    echo "  Data dir:          ${DATA_DIR}"
    echo

    if [[ "${SKIP_CONFIRM:-}" != "yes" ]]; then
        read -p "Proceed with installation? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
}

# Install system dependencies
install_system_deps() {
    log_info "Installing system dependencies..."

    apt-get update
    apt-get upgrade -y

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        curl \
        git \
        build-essential \
        gcc \
        g++ \
        make \
        python3 \
        pkg-config \
        procps \
        file \
        sudo \
        wget \
        openssl

    log_success "System dependencies installed"
}

# Install Node.js 22
install_nodejs() {
    log_info "Installing Node.js 22..."

    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        if [[ "$NODE_VERSION" =~ ^v22\. ]]; then
            log_success "Node.js 22 already installed: $NODE_VERSION"
            return
        fi
    fi

    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs

    # Enable corepack for pnpm
    corepack enable

    log_success "Node.js $(node --version) installed"
    log_success "pnpm $(pnpm --version) available"
}

# Install Bun
install_bun() {
    log_info "Installing Bun..."

    if command -v bun &> /dev/null; then
        log_success "Bun already installed: $(bun --version)"
        return
    fi

    curl -fsSL https://bun.sh/install | bash

    # Add to current shell PATH
    export PATH="$HOME/.bun/bin:$PATH"

    # Add to bashrc for future sessions
    if ! grep -q '.bun/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
    fi

    log_success "Bun $(bun --version) installed"
}

# Install Homebrew
install_homebrew() {
    log_info "Installing Homebrew..."

    if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        log_success "Homebrew already installed"
        return
    fi

    # Create linuxbrew user if not exists
    if ! id -u linuxbrew &>/dev/null; then
        useradd -m -s /bin/bash linuxbrew
        echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
    fi

    # Install Homebrew as linuxbrew user
    su - linuxbrew -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

    # Make Homebrew globally accessible
    chown -R root:root /home/linuxbrew/.linuxbrew

    # Add to system PATH
    cat > /etc/profile.d/homebrew.sh << 'BREWEOF'
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
BREWEOF

    # Source for current session
    source /etc/profile.d/homebrew.sh

    log_success "Homebrew $(brew --version | head -1) installed"
}

# Build Openclaw from source
build_openclaw() {
    log_info "Building Openclaw from source (this may take 10-15 minutes)..."

    mkdir -p "$OPENCLAW_DIR"
    cd "$OPENCLAW_DIR"

    if [[ -d .git ]]; then
        log_info "Updating existing Openclaw installation..."
        git fetch origin
        git checkout "$OPENCLAW_GIT_REF"
        git pull origin "$OPENCLAW_GIT_REF" || true
    else
        log_info "Cloning Openclaw repository..."
        git clone --depth 1 --branch "$OPENCLAW_GIT_REF" https://github.com/openclaw/openclaw.git .
    fi

    # Patch extension package.json files
    log_info "Patching extension dependencies..."
    find ./extensions -name 'package.json' -type f 2>/dev/null | while read -r f; do
        sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*">=[^"]+"/"openclaw": "*"/g' "$f"
        sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*"workspace:[^"]+"/"openclaw": "*"/g' "$f"
    done

    # Build
    export OPENCLAW_PREFER_PNPM=1

    log_info "Installing dependencies..."
    pnpm install --no-frozen-lockfile

    log_info "Building Openclaw..."
    pnpm build

    log_info "Building UI..."
    pnpm ui:install
    pnpm ui:build

    # Create openclaw command
    cat > /usr/local/bin/openclaw << 'CLAWEOF'
#!/usr/bin/env bash
exec node /openclaw/dist/entry.js "$@"
CLAWEOF
    chmod +x /usr/local/bin/openclaw

    log_success "Openclaw built successfully"
    openclaw --version || log_warn "Could not verify openclaw version"
}

# Install wrapper application
install_wrapper() {
    log_info "Installing wrapper application..."

    mkdir -p "$WRAPPER_DIR"
    cd "$WRAPPER_DIR"

    # Clone wrapper repository
    if [[ -d /tmp/wrapper ]]; then
        rm -rf /tmp/wrapper
    fi

    git clone --depth 1 "$WRAPPER_REPO" /tmp/wrapper

    # Copy required files
    cp /tmp/wrapper/package.json /tmp/wrapper/pnpm-lock.yaml "$WRAPPER_DIR/"
    cp -r /tmp/wrapper/src "$WRAPPER_DIR/"

    # Copy scripts if they exist
    if [[ -d /tmp/wrapper/scripts ]]; then
        cp -r /tmp/wrapper/scripts "$WRAPPER_DIR/"
    fi

    rm -rf /tmp/wrapper

    # Install dependencies
    cd "$WRAPPER_DIR"
    pnpm install --prod --frozen-lockfile

    log_success "Wrapper application installed"
}

# Create data directories
create_data_dirs() {
    log_info "Creating data directories..."

    mkdir -p "$STATE_DIR" "$WORKSPACE_DIR"
    chmod 755 "$DATA_DIR" "$STATE_DIR" "$WORKSPACE_DIR"

    log_success "Data directories created"
}

# Create environment configuration
create_env_config() {
    log_info "Creating environment configuration..."

    # Generate gateway token
    GATEWAY_TOKEN=$(openssl rand -hex 32)

    cat > "$WRAPPER_DIR/.env" << ENVEOF
# Openclaw LXC Configuration
# Generated by lxc-setup.sh on $(date)

# Required - Password for /setup wizard
SETUP_PASSWORD=${SETUP_PASSWORD}

# Gateway authentication token
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}

# Data directories
OPENCLAW_STATE_DIR=${STATE_DIR}
OPENCLAW_WORKSPACE_DIR=${WORKSPACE_DIR}

# Network
PORT=8080
INTERNAL_GATEWAY_PORT=18789
INTERNAL_GATEWAY_HOST=127.0.0.1

# Paths
OPENCLAW_ENTRY=${OPENCLAW_DIR}/dist/entry.js
NODE_ENV=production
ENVEOF

    chmod 600 "$WRAPPER_DIR/.env"

    log_success "Environment configuration created"
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."

    cat > /etc/systemd/system/openclaw.service << 'SVCEOF'
[Unit]
Description=Openclaw AI Coding Assistant
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/app
EnvironmentFile=/app/.env

# Set PATH to include Homebrew and Bun
Environment=NODE_ENV=production
Environment=PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/root/.bun/bin:/usr/local/bin:/usr/bin:/bin

ExecStart=/usr/bin/node src/server.js
Restart=on-failure
RestartSec=10
TimeoutStartSec=300

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable openclaw

    log_success "systemd service created and enabled"
}

# Start service and verify
start_and_verify() {
    log_info "Starting Openclaw service..."

    systemctl start openclaw

    # Wait for service to start
    log_info "Waiting for service to become ready..."
    sleep 5

    # Check if service is running
    if systemctl is-active --quiet openclaw; then
        log_success "Openclaw service is running"
    else
        log_error "Service failed to start. Check logs with: journalctl -u openclaw -n 50"
        return 1
    fi

    # Test health endpoint
    for i in {1..12}; do
        if curl -sf http://localhost:8080/setup/healthz > /dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        log_info "Waiting for health endpoint... (attempt $i/12)"
        sleep 5
    done

    log_warn "Health endpoint not responding yet. Service may still be starting."
    log_info "Check status with: systemctl status openclaw"
}

# Print completion message
print_completion() {
    local IP_ADDR
    IP_ADDR=$(hostname -I | awk '{print $1}')

    echo
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo
    echo "Access the setup wizard at:"
    echo "  http://${IP_ADDR}:8080/setup"
    echo
    echo "Login with the password you provided."
    echo
    echo "Useful commands:"
    echo "  systemctl status openclaw    - Check service status"
    echo "  systemctl restart openclaw   - Restart service"
    echo "  journalctl -u openclaw -f    - View live logs"
    echo
    echo "Configuration files:"
    echo "  /app/.env                    - Environment config"
    echo "  /data/.openclaw/             - Openclaw state"
    echo "  /data/workspace/             - Workspace files"
    echo
}

# Main installation flow
main() {
    echo
    echo "  ___                        _               "
    echo " / _ \ _ __   ___ _ __   ___| | __ ___      __"
    echo "| | | | '_ \ / _ \ '_ \ / __| |/ _\` \ \ /\ / /"
    echo "| |_| | |_) |  __/ | | | (__| | (_| |\ V  V / "
    echo " \___/| .__/ \___|_| |_|\___|_|\__,_| \_/\_/  "
    echo "      |_|                                     "
    echo "                    LXC Setup Script"
    echo

    check_root
    check_debian
    get_setup_password
    confirm_install

    log_info "Starting installation..."
    echo

    install_system_deps
    install_nodejs
    install_bun
    install_homebrew

    # Ensure PATH is set for build steps
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$HOME/.bun/bin:$PATH"

    build_openclaw
    install_wrapper
    create_data_dirs
    create_env_config
    create_systemd_service
    start_and_verify

    print_completion
}

# Run main function
main "$@"
