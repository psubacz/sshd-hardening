# SSH Hardening Ansible Playbooks

## Recent Updates (April 2025)

- **NEW**: Created unified `unified_ssh_hardening.sh` script that combines the functionality of `harden_ssh.sh` and `remote_ssh.sh`
- **FIXED**: Resolved group ownership issues on AL2023 for users with non-matching group names
- Fixed macOS path handling for SSH client configuration (now using `/etc/ssh/ssh_config` instead of `/etc/ssh_config`)
- Added improved error handling for macOS directory creation and permissions
- Updated documentation with local hardening instructions
- Added fallback mechanisms for common macOS configuration issues
- Fixed user detection on macOS to prevent creating .ssh directories for system accounts
- Created improved version of the playbook at `ssh_client_hardening_fixed.yml`
- Added compatibility version `ssh_client_hardening_compat.yml` for older OpenSSH versions

These Ansible playbooks are designed to harden SSH configurations on both servers and clients, addressing the security issues identified in the SSH audit report which gave a score of 33/100. The playbooks support multiple operating systems:

- Amazon Linux 2023
- RHEL 8
- macOS
- Other Linux distributions

## Directory Structure

- `playbooks/` - Contains all SSH hardening playbooks
- `inventory` - Inventory file with OS-specific grouping
- `ansible.cfg` - Basic Ansible configuration
- `unified_ssh_hardening.sh` - Unified script for both local and remote SSH hardening (recommended entry point)

## Playbook Versions

This repository contains three versions of the SSH client hardening playbook in the `playbooks` directory:

1. **Original Playbook** (`playbooks/ssh_client_hardening_playbook.yml`):
   - Basic functionality with newer SSH algorithms
   - May create unnecessary system account directories on macOS
   - Requires OpenSSH 8.9 or newer for all algorithms

2. **Fixed Playbook** (`playbooks/ssh_client_hardening_fixed.yml`):
   - Prevents creating system account directories on macOS
   - Properly filters user accounts for directory creation
   - Requires OpenSSH 8.9 or newer for all algorithms

3. **Compatibility Playbook** (`playbooks/ssh_client_hardening_compat.yml`):
   - Compatible with older OpenSSH versions (7.5+) common on macOS
   - Prevents creating system account directories on macOS
   - Uses only widely supported algorithms
   - **Recommended for most macOS systems**

## Running the Unified Hardening Script

The easiest way to harden your SSH client is to use the included `unified_ssh_hardening.sh` script, which will automatically detect your OpenSSH version and apply the appropriate playbook:

```bash
# Make it executable first
chmod +x unified_ssh_hardening.sh

# Run the script locally
./unified_ssh_hardening.sh

# Run the script on a remote host
./unified_ssh_hardening.sh --remote hostname

# Run the script on a group of hosts from inventory
./unified_ssh_hardening.sh --group servers
```

The script provides several options:

```bash
# Run with automatic selection and execution (no prompts)
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
   - Removes or disables ECDSA keys using potentially compromised NIST P-curves
   - Replaces with ED25519 and RSA keys

2. **Weak Diffie-Hellman Group 14**
   - Removes the Diffie-Hellman Group 14 with 2048-bit modulus (too small)
   - Configures stronger DH groups (16, 18) and increases minimum modulus size to 3072 bits

3. **MAC Algorithms with Insufficient Tag Size**
   - Removes umac-64 algorithms with insufficient (64-bit) tag size
   - Configures stronger MAC algorithms with at least 128-bit tags

4. **Weak SHA-1 Algorithms**
   - Removes all MAC algorithms using SHA-1
   - Replaces with stronger SHA-2 based alternatives (SHA-256, SHA-512)

5. **Encrypt-and-MAC vs Encrypt-then-MAC**
   - Replaces vulnerable encrypt-and-MAC algorithms
   - Configures secure encrypt-then-MAC (ETM) algorithms

6. **General SSH Security Best Practices**
   - Disables root login
   - Enforces key-based authentication
   - Disables X11 forwarding
   - Implements OS-specific security enhancements

## Prerequisites

- Ansible 2.9 or newer
- SSH access to target hosts
- Python 3 on target hosts
- Sudo/root privileges on target hosts

## Setup Instructions

1. **Clone or download this repository**

2. **Update the inventory file**

   Edit `inventory.ini` to include your hosts in the appropriate OS groups:
   
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

3. **Test connectivity to ensure Ansible can reach all hosts**

   ```bash
   ansible all -m ping
   ```

## Usage

### Quick Start: Hardening Your Local System

The simplest way to harden your SSH client is:

```bash
# Make the script executable
chmod +x unified_ssh_hardening.sh

# Run the hardening script
./unified_ssh_hardening.sh
```

This will:
1. Detect your OpenSSH version
2. Select the most appropriate playbook
3. Ask for confirmation before running
4. Apply the hardening configuration
5. Test your SSH connection to ensure everything still works

### Quick Start: Hardening Remote Systems

To harden SSH on remote systems:

```bash
# Harden a specific remote host
./unified_ssh_hardening.sh --remote server.example.com

# Harden all hosts in a group from your inventory
./unified_ssh_hardening.sh --group al2023_servers
```

### Manual Playbook Selection

If you prefer to manually select and run a specific playbook:

```bash
# Using the original playbook
ansible-playbook playbooks/ssh_client_hardening_playbook.yml -i inventory --connection=local -l localhost

# Using the fixed playbook (prevents creating .ssh directories for system accounts)
ansible-playbook playbooks/ssh_client_hardening_fixed.yml -i inventory --connection=local -l localhost

# Using the compatibility version (recommended for older macOS versions)
ansible-playbook playbooks/ssh_client_hardening_compat.yml -i inventory --connection=local -l localhost
```

### Forcing a Specific Playbook

If you want to force a specific playbook with the automated script:

```bash
# Force compatibility playbook (for older systems)
./unified_ssh_hardening.sh --compatibility

# Force fixed playbook (for newer systems)
./unified_ssh_hardening.sh --fixed
```

### Hardening SSH Servers

Run the server hardening playbook on all servers:

```bash
ansible-playbook ssh_hardening_playbook.yml -l servers
```

Or target a specific OS group:

```bash
ansible-playbook ssh_hardening_playbook.yml -l rhel8_servers
ansible-playbook ssh_hardening_playbook.yml -l al2023_servers
```

### Hardening SSH Clients

Run the client hardening playbook on all clients:

```bash
ansible-playbook ssh_client_hardening_playbook.yml -l clients
```

Or target a specific OS group:

```bash
ansible-playbook ssh_client_hardening_playbook.yml -l macos_clients
ansible-playbook ssh_client_hardening_playbook.yml -l linux_clients
```

### Applying to All Hosts

To apply both server and client hardening to all hosts:

```bash
ansible-playbook ssh_hardening_playbook.yml ssh_client_hardening_playbook.yml
```

## OS-Specific Considerations

### macOS

- The playbooks handle the different file paths in macOS
  - Uses `/etc/ssh/ssh_config` for macOS configurations (updated from previous `/etc/ssh_config`)
  - Ensures proper backup and configuration directories exist at `/private/etc/ssh/backups` and `/private/etc/ssh/ssh_config.d`
- Uses `launchctl` to manage SSH services instead of systemd/init.d
- Adds macOS-specific settings like `UseKeychain` and `AddKeysToAgent`
- Includes privilege escalation handling for macOS permissions

### Amazon Linux 2023

- Sets Amazon Linux 2023 specific timeout parameters
- Configures appropriate DH parameters
- Ensures compatibility with AL2023's OpenSSH version
- **FIXED**: Now correctly handles user accounts that are part of groups with different names (e.g., "maxar" group)

### RHEL 8

- Sets RHEL 8 specific login parameters
- Ensures compatibility with RHEL 8's OpenSSH version
- Configures appropriate authentication limits

## Safety Features

These playbooks include several safety mechanisms:

1. **Automatic Backups**
   - Creates dated backups of original configuration files before making changes
   - Example: `/etc/ssh/sshd_config.backup.2025-04-25`

2. **Configuration Verification**
   - Tests new configurations with `sshd -t` before applying
   - If verification fails, automatically restores the backup

3. **Detailed Logging**
   - Displays detailed information about what was changed
   - Shows verification results
   - Provides a summary at the end

## After Running the Playbooks

1. **Do not log out of your current session** until you verify SSH access works with a new session
2. Test connecting to the hardened server from another terminal/machine
3. Verify server SSH service is running:
   - Linux: `systemctl status sshd`
   - macOS: `sudo launchctl list | grep ssh`

## Troubleshooting

### Amazon Linux 2023 Issues

- **Fixed: "chgrp failed: failed to look up group X" errors**: The playbooks now correctly handle users that belong to a different group than their username (e.g., users in the "maxar" group)
- If you still encounter group-related issues, verify user and group assignments with `id <username>`

### macOS-Specific Issues

- **Error with backup path**: The playbook automatically creates the backup directory at `/private/etc/ssh/backups`
- **File path issues**: Configurations are stored at `/etc/ssh/ssh_config` and `/private/etc/ssh/ssh_config.d/10-hardened.conf`
- **Permission denied errors**: The unified script handles permissions properly. If manual issues persist, run with `sudo`
- **SSH config not being applied**: The script tests SSH connectivity after hardening. You can also test with `ssh -vT github.com`
- **Empty directories created for system accounts**: Use `unified_ssh_hardening.sh` which automatically selects playbooks that properly filter system accounts
- **Algorithm compatibility errors**: Run `./unified_ssh_hardening.sh --compatibility` to force using only compatible algorithms

### Issues with the Hardening Script

- **Script can't find playbooks**: Make sure you're running from the main `sshd-hardening` directory or use the full path to the script
- **OpenSSH version detection fails**: Use `./unified_ssh_hardening.sh --compatibility` to force the compatibility playbook
- **Playbook fails to run**: Try running with verbose mode `./unified_ssh_hardening.sh --verbose` to see more details
- **Connection issues after hardening**: Run `./unified_ssh_hardening.sh --compatibility` to apply a more conservative configuration

### General Issues

If you encounter issues:

1. **Restoration from Backup**:
   - Linux: `sudo cp /etc/ssh/sshd_config.backup.YYYY-MM-DD /etc/ssh/sshd_config`
   - macOS: `sudo cp /etc/ssh/sshd_config.backup.YYYY-MM-DD /etc/ssh/sshd_config`

2. **Restarting SSH Service**:
   - Linux (RHEL/AL2023): `sudo systemctl restart sshd`
   - Debian/Ubuntu: `sudo systemctl restart ssh`
   - macOS: 
     ```
     sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
     sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
     ```

3. **Checking Service Status**:
   - Linux: `sudo systemctl status sshd`
   - macOS: `sudo launchctl list | grep ssh`

## Verifying Security Improvements

After running these playbooks, you can verify the security improvements by:

1. Running another SSH audit
2. The score should increase significantly from the original 33/100
3. The specific findings addressed should no longer appear in the audit report

## Customization

If you need to customize the configured algorithms or settings:

- Edit the variable sections at the top of each playbook
- For example, to add or remove key exchange algorithms, modify the `kex_algorithms` list in the playbooks