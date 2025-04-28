#!/bin/bash
# unified_ssh_hardening.sh
# Script for SSH hardening that can run locally or on remote hosts
# Combines functionality from harden_ssh.sh and remote_ssh.sh

echo "=== Unified SSH Hardening Script ==="
echo "This script will apply SSH hardening to local or remote hosts"
echo "=============================================="
echo ""

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOKS_DIR="${SCRIPT_DIR}/playbooks"
INVENTORY_FILE="${SCRIPT_DIR}/inventory"

# Process command line arguments
AUTO_RUN=false
FORCE_COMPAT=false
FORCE_FIXED=false
VERBOSE=false
REMOTE_HOST=""
REMOTE_USER=""
LIMIT_HOSTS="localhost"
CONNECTION_TYPE="local"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --auto|-a)
            AUTO_RUN=true
            ;;
        --compatibility|-c)
            FORCE_COMPAT=true
            ;;
        --fixed|-f)
            FORCE_FIXED=true
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --remote|-r)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --remote requires a hostname or IP address"
                exit 1
            fi
            REMOTE_HOST="$2"
            CONNECTION_TYPE="ssh"
            LIMIT_HOSTS="$2"
            shift
            ;;
        --user|-u)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --user requires a username"
                exit 1
            fi
            REMOTE_USER="$2"
            shift
            ;;
        --group|-g)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --group requires an inventory group name"
                exit 1
            fi
            LIMIT_HOSTS="$2"
            CONNECTION_TYPE="ssh"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --auto, -a          Automatically run the recommended playbook without confirmation"
            echo "  --compatibility, -c Force using the compatibility playbook"
            echo "  --fixed, -f         Force using the fixed playbook (may not work on older systems)"
            echo "  --verbose, -v       Display more detailed output"
            echo "  --remote, -r HOST   Run on a remote host (specified by hostname or IP)"
            echo "  --user, -u USER     Username for remote connection"
            echo "  --group, -g GROUP   Run on a group of hosts from inventory"
            echo "  --help, -h          Display this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Check if playbooks directory exists
if [ ! -d "$PLAYBOOKS_DIR" ]; then
    echo "Error: Playbooks directory not found at $PLAYBOOKS_DIR"
    echo "Make sure you're running this script from the sshd-hardening directory"
    exit 1
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file not found at $INVENTORY_FILE"
    echo "Make sure you're running this script from the sshd-hardening directory"
    exit 1
fi

# Function to get SSH version
get_ssh_version() {
    local ssh_version
    
    if [ -n "$REMOTE_HOST" ]; then
        # Get SSH version from remote host
        local ssh_cmd="ssh"
        if [ -n "$REMOTE_USER" ]; then
            ssh_cmd="$ssh_cmd -l $REMOTE_USER"
        fi
        
        echo "Getting SSH version from remote host: $REMOTE_HOST"
        ssh_version=$($ssh_cmd $REMOTE_HOST "ssh -V 2>&1")
    else
        # Get SSH version from local host
        ssh_version=$(ssh -V 2>&1)
    fi
    
    echo "Detected SSH version: $ssh_version"
    echo "$ssh_version"
}

# Function to detect macOS and get version
detect_macos() {
    local os_type
    local macos_version
    
    if [ -n "$REMOTE_HOST" ]; then
        # Check remote host OS
        local ssh_cmd="ssh"
        if [ -n "$REMOTE_USER" ]; then
            ssh_cmd="$ssh_cmd -l $REMOTE_USER"
        fi
        
        os_type=$($ssh_cmd $REMOTE_HOST "uname")
        if [[ "$os_type" == "Darwin" ]]; then
            macos_version=$($ssh_cmd $REMOTE_HOST "sw_vers -productVersion")
            echo "Remote macOS version: $macos_version"
            echo "$macos_version"
            return 0
        fi
    else
        # Check local OS
        if [[ $(uname) == "Darwin" ]]; then
            macos_version=$(sw_vers -productVersion)
            echo "macOS version: $macos_version"
            echo "$macos_version"
            return 0
        fi
    fi
    
    return 1
}

# Get SSH version
SSH_VERSION_STR=$(get_ssh_version)

# Choose playbook based on SSH version
if [ "$FORCE_COMPAT" = true ]; then
    RECOMMENDED_PLAYBOOK="ssh_client_hardening_compat.yml"
    PLAYBOOK_REASON="(forced compatibility mode)"
elif [ "$FORCE_FIXED" = true ]; then
    RECOMMENDED_PLAYBOOK="ssh_client_hardening_fixed.yml"
    PLAYBOOK_REASON="(forced fixed mode)"
else
    # Extract version number using regex
    if [[ $SSH_VERSION_STR =~ OpenSSH_([0-9]+)\.([0-9]+) ]]; then
        MAJOR=${BASH_REMATCH[1]}
        MINOR=${BASH_REMATCH[2]}
        
        echo "OpenSSH major version: $MAJOR"
        echo "OpenSSH minor version: $MINOR"
        
        if [[ $MAJOR -gt 8 || ($MAJOR -eq 8 && $MINOR -ge 9) ]]; then
            RECOMMENDED_PLAYBOOK="ssh_client_hardening_fixed.yml"
            PLAYBOOK_REASON="(based on OpenSSH version supporting newer algorithms)"
        else
            RECOMMENDED_PLAYBOOK="ssh_client_hardening_compat.yml"
            PLAYBOOK_REASON="(based on OpenSSH version requiring compatibility mode)"
        fi
    else
        echo "Could not determine OpenSSH version."
        RECOMMENDED_PLAYBOOK="ssh_client_hardening_compat.yml"
        PLAYBOOK_REASON="(using compatibility mode since version detection failed)"
    fi
fi

# Check for macOS
MACOS_VERSION=$(detect_macos)
if [ $? -eq 0 ]; then
    # Warning for newer macOS versions with potential algorithm restrictions
    if [[ $MACOS_VERSION =~ ^13\.|^14\. ]] && [ "$RECOMMENDED_PLAYBOOK" != "ssh_client_hardening_compat.yml" ] && [ "$FORCE_FIXED" != true ]; then
        echo ""
        echo "⚠️  Note: macOS $MACOS_VERSION may have additional algorithm restrictions."
        echo "Switching to compatibility playbook for better support."
        RECOMMENDED_PLAYBOOK="ssh_client_hardening_compat.yml"
        PLAYBOOK_REASON="(adjusted for macOS $MACOS_VERSION compatibility)"
    fi
fi

echo ""
echo "Recommended playbook: $RECOMMENDED_PLAYBOOK $PLAYBOOK_REASON"
echo ""

PLAYBOOK_PATH="$PLAYBOOKS_DIR/$RECOMMENDED_PLAYBOOK"

# Verify playbook exists
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: Recommended playbook not found at $PLAYBOOK_PATH"
    exit 1
fi

# Run playbook automatically or ask for confirmation
if [ "$AUTO_RUN" = true ]; then
    echo "Automatically running recommended playbook..."
    RUN_PLAYBOOK=true
else
    echo -n "Run this playbook now? [Y/n]: "
    read -r CONFIRMATION
    if [[ $CONFIRMATION =~ ^[Nn]$ ]]; then
        RUN_PLAYBOOK=false
    else
        RUN_PLAYBOOK=true
    fi
fi

if [ "$RUN_PLAYBOOK" = true ]; then
    echo ""
    echo "=============================================="
    echo "Running SSH hardening playbook: $RECOMMENDED_PLAYBOOK"
    if [ "$CONNECTION_TYPE" = "ssh" ]; then
        echo "Target: $LIMIT_HOSTS (via SSH)"
    else
        echo "Target: localhost (local connection)"
    fi
    echo "=============================================="
    
    # Build the ansible command
    ANSIBLE_COMMAND="ansible-playbook $PLAYBOOK_PATH -i $INVENTORY_FILE"
    
    if [ "$CONNECTION_TYPE" = "local" ]; then
        ANSIBLE_COMMAND="$ANSIBLE_COMMAND --connection=local --ask-become-pass"
    fi
    
    ANSIBLE_COMMAND="$ANSIBLE_COMMAND -l $LIMIT_HOSTS"
    
    if [ -n "$REMOTE_USER" ]; then
        ANSIBLE_COMMAND="$ANSIBLE_COMMAND -u $REMOTE_USER"
    fi
    
    if [ "$VERBOSE" = true ]; then
        ANSIBLE_COMMAND="$ANSIBLE_COMMAND -v"
    fi
    
    echo "Executing: $ANSIBLE_COMMAND"
    echo ""
    
    # Run the playbook
    $ANSIBLE_COMMAND
    
    PLAYBOOK_EXIT_CODE=$?
    
    echo ""
    if [ $PLAYBOOK_EXIT_CODE -eq 0 ]; then
        echo "✅ SSH hardening completed successfully!"
        
        # Only test connection if operating on localhost
        if [ "$CONNECTION_TYPE" = "local" ]; then
            echo ""
            echo "Testing SSH connection to github.com..."
            ssh -T git@github.com -o BatchMode=yes -o ConnectTimeout=5 2>&1 | grep -v "Permission denied"
            
            SSH_TEST_EXIT_CODE=${PIPESTATUS[0]}
            if [ $SSH_TEST_EXIT_CODE -eq 255 ] || [ $SSH_TEST_EXIT_CODE -eq 1 ]; then
                echo "✅ SSH connection test successful (authentication would be required)"
            else
                echo "⚠️  SSH connection test returned unexpected code: $SSH_TEST_EXIT_CODE"
                echo "You may want to check your SSH configuration"
            fi
        fi
    else
        echo "⚠️  SSH hardening encountered issues (exit code: $PLAYBOOK_EXIT_CODE)"
        echo "Review the output above for errors."
        echo ""
        echo "You can try running with the compatibility playbook using:"
        echo "$0 --compatibility $([ -n "$REMOTE_HOST" ] && echo "--remote $REMOTE_HOST")"
    fi
else
    echo "Playbook not run. You can manually run it with:"
    echo "ansible-playbook $PLAYBOOK_PATH -i $INVENTORY_FILE -l $LIMIT_HOSTS"
fi

echo ""
echo "=============================================="
echo "For more information, see the README.md file"
echo "=============================================="