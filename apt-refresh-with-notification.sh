#!/bin/bash
set -uo pipefail

CACHE_DIR="/run/shell-dashboard"
CACHE_FILE="$CACHE_DIR/updates_cache"

# Ensure the cache directory exists (just in case)
mkdir -p "$CACHE_DIR"
chmod 755 "$CACHE_DIR"

# Run apt update, exit and notify on failure
if ! apt update &> /dev/null; then
    sudo -u jiblet /usr/local/bin/notify-discord.sh updates failed "APT Refresh" "APT update failed with an unknown error."
    exit 1
fi

# Get list of upgradable packages (excluding the 'Listing...' line)
UPGRADABLE_PACKAGES=$(apt list --upgradable 2>/dev/null | grep -v 'Listing...')

# Count how many updates are pending
UPDATES_COUNT=$(echo "$UPGRADABLE_PACKAGES" | grep -c '.')

# Write the count to the cache file
echo "$UPDATES_COUNT" > "$CACHE_FILE"

# Prepare and send Discord notification accordingly
if [ "$UPDATES_COUNT" -gt 0 ]; then
    MESSAGE="Found the following upgradable packages:\n\n$UPGRADABLE_PACKAGES"
    sudo -u jiblet /usr/local/bin/notify-discord.sh updates warning "APT Updates Available" "$MESSAGE"
else
    ## No longer any need to message when no new packages are found
    # MESSAGE="No new packages found."
    # sudo -u jiblet /usr/local/bin/notify-discord.sh updates success "APT Updates" "$MESSAGE"
fi
