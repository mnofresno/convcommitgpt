#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to confirm uninstallation
confirm_uninstall() {
    read -p "Are you sure you want to uninstall convcommitgpt? This will remove all files and configurations. (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "Uninstallation cancelled." "$YELLOW"
        exit 1
    fi
}

# Function to backup configuration
backup_config() {
    if [ -f /etc/convcommitgpt/.env ]; then
        print_message "Backing up configuration..." "$YELLOW"
        backup_dir="$HOME/convcommitgpt_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        sudo cp /etc/convcommitgpt/.env "$backup_dir/"
        print_message "Configuration backed up to: $backup_dir" "$GREEN"
    fi
}

# Function to remove installed files
remove_files() {
    print_message "Removing installed files..." "$YELLOW"
    
    # Remove main script
    if [ -f /usr/local/bin/convcommit ]; then
        sudo rm /usr/local/bin/convcommit
    fi
    
    # Remove installation directory
    if [ -d /var/lib/convcommitgpt ]; then
        sudo rm -rf /var/lib/convcommitgpt
    fi
    
    # Remove configuration
    if [ -d /etc/convcommitgpt ]; then
        sudo rm -rf /etc/convcommitgpt
    fi
}

# Main uninstallation process
main() {
    print_message "Starting convcommitgpt uninstallation..." "$YELLOW"
    
    # Confirm uninstallation
    confirm_uninstall
    
    # Backup configuration
    backup_config
    
    # Remove files
    remove_files
    
    print_message "Uninstallation completed successfully!" "$GREEN"
}

# Run main function
main 