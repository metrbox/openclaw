#!/usr/bin/env bash
#
# Openclaw Proxmox LXC Creator
#
# Run this on your Proxmox host to create and configure an LXC container
# with Openclaw pre-installed.
#
# Usage (on Proxmox host):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/metrbox/openclaw/main/scripts/proxmox-create-lxc.sh)"
#
# Or with options:
#   curl -fsSL https://raw.githubusercontent.com/metrbox/openclaw/main/scripts/proxmox-create-lxc.sh -o create-lxc.sh
#   chmod +x create-lxc.sh
#   ./create-lxc.sh --id 200 --memory 8192 --disk 30
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Default configuration
CTID="${CTID:-}"
HOSTNAME="${HOSTNAME:-openclaw}"
MEMORY="${MEMORY:-4096}"
SWAP="${SWAP:-2048}"
CORES="${CORES:-2}"
DISK_SIZE="${DISK_SIZE:-20}"
STORAGE="${STORAGE:-}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_CONFIG="${IP_CONFIG:-dhcp}"
SETUP_PASSWORD="${SETUP_PASSWORD:-}"
START_AFTER_CREATE="${START_AFTER_CREATE:-yes}"
RUN_SETUP="${RUN_SETUP:-yes}"
INTERACTIVE="${INTERACTIVE:-yes}"

# Debian 12 template
TEMPLATE_NAME="debian-12-standard"
TEMPLATE_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --id)
            CTID="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --swap)
            SWAP="$2"
            shift 2
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --disk)
            DISK_SIZE="$2"
            shift 2
            ;;
        --storage)
            STORAGE="$2"
            shift 2
            ;;
        --template-storage)
            TEMPLATE_STORAGE="$2"
            shift 2
            ;;
        --bridge)
            BRIDGE="$2"
            shift 2
            ;;
        --ip)
            IP_CONFIG="$2"
            shift 2
            ;;
        --password)
            SETUP_PASSWORD="$2"
            shift 2
            ;;
        --no-start)
            START_AFTER_CREATE="no"
            shift
            ;;
        --no-setup)
            RUN_SETUP="no"
            shift
            ;;
        --help|-h)
            echo "Openclaw Proxmox LXC Creator"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --id ID           Container ID (default: next available)"
            echo "  --hostname NAME   Container hostname (default: openclaw)"
            echo "  --memory MB       Memory in MB (default: 4096)"
            echo "  --swap MB         Swap in MB (default: 2048)"
            echo "  --cores NUM       CPU cores (default: 2)"
            echo "  --disk GB         Disk size in GB (default: 20)"
            echo "  --storage NAME    Storage pool for rootfs (interactive if not set)"
            echo "  --template-storage Storage for templates (interactive if not set)"
            echo "  --bridge NAME     Network bridge (default: vmbr0)"
            echo "  --ip CONFIG       IP config: 'dhcp' or 'x.x.x.x/24,gw=y.y.y.y' (default: dhcp)"
            echo "  --password PASS   Setup wizard password (will prompt if not set)"
            echo "  --no-start        Don't start container after creation"
            echo "  --no-setup        Don't run Openclaw setup (just create LXC)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if running on Proxmox
check_proxmox() {
    if [[ ! -f /etc/pve/.version ]]; then
        log_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    log_success "Running on Proxmox VE"
}

# Get available storage pools that support container rootdir
get_available_storage() {
    local storage_type="$1"  # "rootdir" for container storage, "vztmpl" for templates
    pvesm status 2>/dev/null | awk -v type="$storage_type" '
        NR > 1 && $2 == "active" {
            # Get storage content types
            cmd = "pvesm status --storage " $1 " 2>/dev/null | grep -o \"content.*\" | cut -d: -f2"
            cmd | getline content
            close(cmd)
            if (type == "rootdir" && (content ~ /rootdir/ || content ~ /images/)) print $1
            if (type == "vztmpl" && content ~ /vztmpl/) print $1
        }
    '
}

# Interactive storage selection
select_storage() {
    local storage_type="$1"
    local prompt="$2"
    local var_name="$3"

    # Get list of available storage
    local storages=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && storages+=("$line")
    done < <(pvesm status 2>/dev/null | awk 'NR > 1 && $2 == "active" { print $1 }')

    if [[ ${#storages[@]} -eq 0 ]]; then
        log_error "No active storage found"
        exit 1
    fi

    # If only one storage, use it
    if [[ ${#storages[@]} -eq 1 ]]; then
        eval "$var_name='${storages[0]}'"
        log_info "Using storage: ${storages[0]}"
        return
    fi

    echo
    log_info "$prompt"
    echo

    local i=1
    for s in "${storages[@]}"; do
        # Get storage info
        local info
        info=$(pvesm status --storage "$s" 2>/dev/null | awk 'NR==2 {printf "(%s, %s available)", $3, $5}')
        echo "  $i) $s $info"
        ((i++))
    done
    echo

    while true; do
        read -p "Select storage [1-${#storages[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#storages[@]} ]]; then
            eval "$var_name='${storages[$((choice-1))]}'"
            break
        fi
        log_warn "Invalid selection. Please enter a number between 1 and ${#storages[@]}"
    done
}

# Select network bridge
select_bridge() {
    local bridges=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && bridges+=("$line")
    done < <(ip -o link show type bridge 2>/dev/null | awk -F': ' '{print $2}')

    if [[ ${#bridges[@]} -eq 0 ]]; then
        log_warn "No bridges found, using default vmbr0"
        BRIDGE="vmbr0"
        return
    fi

    # If only one bridge or vmbr0 exists, use it
    if [[ ${#bridges[@]} -eq 1 ]]; then
        BRIDGE="${bridges[0]}"
        log_info "Using bridge: $BRIDGE"
        return
    fi

    # Check if vmbr0 exists
    for b in "${bridges[@]}"; do
        if [[ "$b" == "vmbr0" ]]; then
            BRIDGE="vmbr0"
            return
        fi
    done

    echo
    log_info "Select network bridge:"
    echo

    local i=1
    for b in "${bridges[@]}"; do
        echo "  $i) $b"
        ((i++))
    done
    echo

    while true; do
        read -p "Select bridge [1-${#bridges[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#bridges[@]} ]]; then
            BRIDGE="${bridges[$((choice-1))]}"
            break
        fi
        log_warn "Invalid selection"
    done
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Get next available container ID
get_next_ctid() {
    if [[ -n "$CTID" ]]; then
        if pct status "$CTID" &>/dev/null; then
            log_error "Container ID $CTID already exists"
            exit 1
        fi
        return
    fi

    CTID=$(pvesh get /cluster/nextid)
    log_info "Using container ID: $CTID"
}

# Prompt for setup password
get_setup_password() {
    if [[ -z "$SETUP_PASSWORD" ]]; then
        echo
        log_info "No setup password provided."
        read -sp "Enter password for the /setup wizard: " SETUP_PASSWORD
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
}

# Download Debian 12 template if not present
download_template() {
    log_step "Checking for Debian 12 template..."

    # Find existing template
    TEMPLATE_FILE=$(pveam list "$TEMPLATE_STORAGE" 2>/dev/null | grep -o "${TEMPLATE_NAME}[^ ]*" | head -1 || true)

    if [[ -n "$TEMPLATE_FILE" ]]; then
        log_success "Template found: $TEMPLATE_FILE"
        return
    fi

    log_info "Downloading Debian 12 template..."
    pveam update

    # Get the latest Debian 12 template name
    AVAILABLE_TEMPLATE=$(pveam available | grep "$TEMPLATE_NAME" | awk '{print $2}' | head -1)

    if [[ -z "$AVAILABLE_TEMPLATE" ]]; then
        log_error "Could not find Debian 12 template"
        exit 1
    fi

    pveam download "$TEMPLATE_STORAGE" "$AVAILABLE_TEMPLATE"
    TEMPLATE_FILE="$AVAILABLE_TEMPLATE"
    log_success "Template downloaded: $TEMPLATE_FILE"
}

# Create the LXC container
create_container() {
    log_step "Creating LXC container..."

    # Build network config
    local NET_CONFIG="name=eth0,bridge=${BRIDGE}"
    if [[ "$IP_CONFIG" == "dhcp" ]]; then
        NET_CONFIG="${NET_CONFIG},ip=dhcp"
    else
        NET_CONFIG="${NET_CONFIG},ip=${IP_CONFIG}"
    fi

    # Create container
    pct create "$CTID" "${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_FILE}" \
        --hostname "$HOSTNAME" \
        --memory "$MEMORY" \
        --swap "$SWAP" \
        --cores "$CORES" \
        --rootfs "${STORAGE}:${DISK_SIZE}" \
        --net0 "$NET_CONFIG" \
        --unprivileged 1 \
        --features nesting=1 \
        --onboot 1 \
        --start 0

    log_success "Container $CTID created"
}

# Start container
start_container() {
    log_step "Starting container..."
    pct start "$CTID"

    # Wait for container to be running
    local attempts=0
    while [[ $(pct status "$CTID" | grep -c "running") -eq 0 ]]; do
        sleep 1
        ((attempts++))
        if [[ $attempts -ge 30 ]]; then
            log_error "Container failed to start"
            exit 1
        fi
    done

    # Wait for network
    log_info "Waiting for network..."
    sleep 5

    log_success "Container started"
}

# Run setup inside container
run_setup_in_container() {
    log_step "Running Openclaw setup inside container..."

    # Download and run the setup script
    pct exec "$CTID" -- bash -c "
        export SETUP_PASSWORD='${SETUP_PASSWORD}'
        export SKIP_CONFIRM=yes
        curl -fsSL https://raw.githubusercontent.com/metrbox/openclaw/main/scripts/lxc-setup.sh | bash
    "

    log_success "Openclaw setup complete"
}

# Get container IP address
get_container_ip() {
    local IP
    IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}' || true)
    echo "$IP"
}

# Print completion message
print_completion() {
    local IP
    IP=$(get_container_ip)

    echo
    echo -e "${GREEN}=========================================="
    echo "  Openclaw LXC Created Successfully!"
    echo -e "==========================================${NC}"
    echo
    echo "Container Details:"
    echo "  ID:       $CTID"
    echo "  Hostname: $HOSTNAME"
    echo "  Memory:   ${MEMORY}MB"
    echo "  Disk:     ${DISK_SIZE}GB"
    echo "  Cores:    $CORES"
    echo

    if [[ -n "$IP" ]]; then
        echo "Access Openclaw:"
        echo -e "  ${CYAN}http://${IP}:8080/setup${NC}"
        echo
    fi

    echo "Useful commands:"
    echo "  pct enter $CTID              # Enter container shell"
    echo "  pct exec $CTID -- <cmd>      # Run command in container"
    echo "  pct stop $CTID               # Stop container"
    echo "  pct start $CTID              # Start container"
    echo "  pct destroy $CTID            # Delete container"
    echo

    if [[ "$RUN_SETUP" == "no" ]]; then
        echo "To complete Openclaw setup, run inside the container:"
        echo "  pct enter $CTID"
        echo "  export SETUP_PASSWORD='your-password'"
        echo "  curl -fsSL https://raw.githubusercontent.com/metrbox/openclaw/main/scripts/lxc-setup.sh | bash"
        echo
    fi
}

# Main function
main() {
    echo
    echo -e "${CYAN}  ___                        _               ${NC}"
    echo -e "${CYAN} / _ \ _ __   ___ _ __   ___| | __ ___      __${NC}"
    echo -e "${CYAN}| | | | '_ \ / _ \ '_ \ / __| |/ _\` \ \ /\ / /${NC}"
    echo -e "${CYAN}| |_| | |_) |  __/ | | | (__| | (_| |\ V  V / ${NC}"
    echo -e "${CYAN} \___/| .__/ \___|_| |_|\___|_|\__,_| \_/\_/  ${NC}"
    echo -e "${CYAN}      |_|                                     ${NC}"
    echo -e "           ${YELLOW}Proxmox LXC Creator${NC}"
    echo

    check_root
    check_proxmox
    get_next_ctid

    # Interactive storage selection if not specified
    if [[ -z "$STORAGE" ]]; then
        select_storage "rootdir" "Select storage for container disk:" "STORAGE"
    fi

    if [[ -z "$TEMPLATE_STORAGE" ]]; then
        select_storage "vztmpl" "Select storage for templates:" "TEMPLATE_STORAGE"
    fi

    # Select network bridge if default doesn't exist
    if ! ip link show "$BRIDGE" &>/dev/null; then
        select_bridge
    fi

    if [[ "$RUN_SETUP" == "yes" ]]; then
        get_setup_password
    fi

    echo
    echo "Configuration:"
    echo "  Container ID:  $CTID"
    echo "  Hostname:      $HOSTNAME"
    echo "  Memory:        ${MEMORY}MB"
    echo "  Swap:          ${SWAP}MB"
    echo "  Cores:         $CORES"
    echo "  Disk:          ${DISK_SIZE}GB"
    echo "  Storage:       $STORAGE"
    echo "  Template:      $TEMPLATE_STORAGE"
    echo "  Network:       $BRIDGE ($IP_CONFIG)"
    echo "  Run Setup:     $RUN_SETUP"
    echo

    read -p "Proceed with creation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi

    download_template
    create_container

    if [[ "$START_AFTER_CREATE" == "yes" ]]; then
        start_container

        if [[ "$RUN_SETUP" == "yes" ]]; then
            run_setup_in_container
        fi
    fi

    print_completion
}

main "$@"
