#!/usr/bin/env bash
#
# Openclaw LXC Uninstall Script
#
# Removes Openclaw installation from a Debian 12 LXC container
#
# Usage:
#   ./lxc-uninstall.sh [--keep-data]
#
# Options:
#   --keep-data    Keep /data directory (config, workspace, credentials)
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

KEEP_DATA=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
    esac
done

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root"
    exit 1
fi

echo
echo "Openclaw LXC Uninstaller"
echo "========================"
echo

if [[ "$KEEP_DATA" == "true" ]]; then
    echo "Data directory (/data) will be KEPT."
else
    echo -e "${YELLOW}WARNING: This will DELETE all data including API keys and workspace!${NC}"
fi

echo
read -p "Are you sure you want to uninstall Openclaw? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Stop and disable service
log_info "Stopping Openclaw service..."
systemctl stop openclaw 2>/dev/null || true
systemctl disable openclaw 2>/dev/null || true
rm -f /etc/systemd/system/openclaw.service
systemctl daemon-reload
log_success "Service removed"

# Remove wrapper
log_info "Removing wrapper application..."
rm -rf /app
log_success "Wrapper removed"

# Remove Openclaw
log_info "Removing Openclaw..."
rm -rf /openclaw
rm -f /usr/local/bin/openclaw
log_success "Openclaw removed"

# Remove data (optional)
if [[ "$KEEP_DATA" == "false" ]]; then
    log_info "Removing data directory..."
    rm -rf /data
    log_success "Data removed"
else
    log_info "Keeping data directory at /data"
fi

# Note: Not removing Homebrew, Node.js, or system packages
# as they may be used by other applications

echo
log_success "Openclaw has been uninstalled."
echo
if [[ "$KEEP_DATA" == "true" ]]; then
    echo "Your data is preserved at /data"
    echo "To completely remove, run: rm -rf /data"
fi
echo
