#!/bin/bash
set -uo pipefail

# ==============================================================================
# Final Refactored APT Update Script
# This script runs as 'root' and switches to 'jiblet' for user-specific actions.
# ==============================================================================

# First, run apt update and capture its output to a variable.
# We explicitly check the exit code of apt update.
if ! apt update &> /dev/null; then
    # If apt update fails, send a failure notification with the error output.
    sudo -u jiblet /usr/local/bin/notify-discord.sh updates failed "APT Refresh" "APT update failed with an unknown error."
    exit 1
fi

# Now, check for available upgrades and capture the output.
UPGRADABLE_PACKAGES=$(apt list --upgradable 2>/dev/null | grep -v 'Listing...')

# Check if the output is not empty.
if [ -n "$UPGRADABLE_PACKAGES" ]; then
    MESSAGE="Found the following upgradable packages:\n\n$UPGRADABLE_PACKAGES"
    sudo -u jiblet /usr/local/bin/notify-discord.sh updates warning "APT Updates Available" "$MESSAGE"
else
    MESSAGE="No new packages found."
    sudo -u jiblet /usr/local/bin/notify-discord.sh updates success "APT Updates" "$MESSAGE"
fi
