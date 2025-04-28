# SSH Hardening Ansible Playbooks

## Overview

These Ansible playbooks harden SSH configurations on both servers and clients to address security issues identified in an SSH audit report (which scored 33/100). They support multiple operating systems including Amazon Linux 2023, RHEL 8, macOS, and other Linux distributions.

## Recent Updates (April 2025)

- **NEW**: Created unified `unified_ssh_hardening.sh` script that combines local and remote hardening functionality
- **FIXED**: Resolved group ownership issues on AL2023 for users with non-matching group names
- Fixed macOS path handling for SSH client configuration
- Added improved error handling for macOS directory creation and permissions
- Added fallback mechanisms for common macOS configuration issues
- Fixed user detection on macOS to prevent creating .ssh directories for system accounts
- Created `ssh_client_hardening_fixed.yml` with improvements
- Added `ssh_client_hardening_compat.yml` for older OpenSSH versions

## Directory Structure

- `playbooks/` - Contains all SSH hardening playbooks
- `inventory` - Inventory file with OS-specific grouping
- `ansible.cfg` - Basic Ansible configuration
- `unified_ssh_hardening.sh` - Unified script for both local and remote SSH hardening (recommended entry point)

## Playbook Versions

1. **Original Playbook** (`playbooks/ssh_client_hardening_playbook.yml`):
   - Basic functionality with newer SSH algorithms
   - Requires OpenSSH 8.9+

2. **Fixed Playbook** (`playbooks/ssh_client_hardening_fixed.yml`):
   - Prevents creating system account directories on macOS
   - Properly filters user accounts for directory creation
   - Requires OpenSSH 8.9+

3. **Compatibility Playbook** (`playbooks/ssh_client_hardening_compat.yml`):
   - Compatible with older OpenSSH versions (7.5+)
   - Prevents creating system account directories on macOS
   - **Recommended for most macOS systems**

## Quick Start

### Local Hardening

```bash
# Make the script executable
chmod +x unified_ssh_hardening.sh

# Run the hardening script
./unified_ssh_hardening.sh
```

### Remote Hardening

```bash
# Harden a specific remote host
./unified_ssh_hardening.sh --remote server.example.com

# Harden all hosts in a group from your inventory
./unified_ssh_hardening.sh --group al2023_servers
```

### Script Options

```bash
# Run with automatic selection (no prompts)
./unified_ssh_hardening.sh --auto

# Force using the compatibility playbook
./unified_ssh_hardening.sh --compatibility

# Force using the fixed playbook
./unified_ssh_hardening.sh --fixed

# Show verbose output
./unified_ssh_hardening.sh --verbose

# Specify a remote user for SSH connection
./unified_ssh_hardening.sh --remote server.example.com --user admin

# Show help
./unified_ssh_hardening.sh --help
```

## Security Issues Addressed

1. **Possibly Compromised NIST P-Curves**
   - Replaces ECDSA keys with ED25519 and RSA keys

2. **Weak Diffie-Hellman Group 14**
   - Configures stronger DH groups (16, 18) with minimum 3072-bit modulus

3. **MAC Algorithms with Insufficient Tag Size**
   - Configures MAC algorithms with at least 128-bit tags

4. **Weak SHA-1 Algorithms**
   - Replaces with stronger SHA-2 based alternatives

5. **Encrypt-and-MAC vs Encrypt-then-MAC**
   - Configures secure encrypt-then-MAC (ETM) algorithms

6. **General SSH Security Best Practices**
   - Disables root login
   - Enforces key-based authentication
   - Disables X11 forwarding
   - Implements OS-specific security enhancements

## Prerequisites

- Ansible 2.9+
- SSH access to target hosts
- Python 3 on target hosts
- Sudo/root privileges

## Setup Instructions

1. **Clone or download this repository**

2. **Update the inventory file**

   Edit `inventory.ini` to include your hosts:
   
   ```ini
   [linux_servers]
   your-linux-server.example.com
   
   [rhel8_servers]
   your-rhel8-server.example.com
   
   [al2023_servers]
   your-al2023-server.example.com
   
   [macos_clients]
   your-mac.example.com
   ```

3. **Test connectivity**

   ```bash
   ansible all -m ping
   ```

## Manual Playbook Selection

```bash
# Using the original playbook
ansible-playbook playbooks/ssh_client_hardening_playbook.yml -i inventory --connection=local -l localhost

# Using the fixed playbook
ansible-playbook playbooks/ssh_client_hardening_fixed.yml -i inventory --connection=local -l localhost

# Using the compatibility version (for older macOS)
ansible-playbook playbooks/ssh_client_hardening_compat.yml -i inventory --connection=local -l localhost
```

## OS-Specific Considerations

### macOS
- Uses `/etc/ssh/ssh_config` for configurations
- Uses `launchctl` to manage SSH services
- Adds macOS-specific settings like `UseKeychain`

### Amazon Linux 2023
- Handles users in different groups (e.g., "maxar" group)
- Configures appropriate DH parameters

### RHEL 8
- Sets RHEL-specific login parameters
- Configures appropriate authentication limits

## Safety Features

1. **Automatic Backups** of configuration files
2. **Configuration Verification** with `sshd -t`
3. **Detailed Logging** of changes

## Post-Hardening Verification

1. **Keep your current session open** until you verify SSH access works
2. Test connecting from another terminal/machine
3. Verify server SSH service is running:
   - Linux: `systemctl status sshd`
   - macOS: `sudo launchctl list | grep ssh`

## Troubleshooting

### Common Issues

- **Group-related issues**: Verify user/group assignments with `id <username>`
- **macOS permission errors**: Run with `sudo`
- **Algorithm compatibility errors**: Use `--compatibility` flag
- **Connection issues after hardening**: Apply a more conservative configuration with `--compatibility`

### Restoration from Backup

- Linux: `sudo cp /etc/ssh/sshd_config.backup.YYYY-MM-DD /etc/ssh/sshd_config`
- macOS: `sudo cp /etc/ssh/sshd_config.backup.YYYY-MM-DD /etc/ssh/sshd_config`

### Restarting SSH Service

- RHEL/AL2023: `sudo systemctl restart sshd`
- Debian/Ubuntu: `sudo systemctl restart ssh`
- macOS: 
  ```
  sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
  sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
  ```

## Verifying Security Improvements

Run another SSH audit after applying the hardening at [sshaudit](https://www.sshaudit.com/)

## Customization

To customize algorithms or settings, edit the variable sections at the top of each playbook.
