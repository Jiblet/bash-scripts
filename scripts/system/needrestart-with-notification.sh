#!/bin/bash
set -uo pipefail

# Run needrestart kernel check with batch mode and list-only
readarray -t lines < <(sudo needrestart -k -b -r r)

FLAGFILE="/run/needrestart-reboot-needed"

if [[ ${#lines[@]} -gt 0 ]]; then
    KCUR=$(echo "${lines[@]}" | grep -oP 'NEEDRESTART-KCUR:\s*\K\S+')
    KEXP=$(echo "${lines[@]}" | grep -oP 'NEEDRESTART-KEXP:\s*\K\S+')
    KSTA=$(echo "${lines[@]}" | grep -oP 'NEEDRESTART-KSTA:\s*\K\S+')

    REBOOT_MSG=$'Kernel reboot required.\n\nCurrent Kernel: '"$KCUR"$'\nExpected Kernel: '"$KEXP"$'\nStatus Code: '"$KSTA"$'\n\nA full system reboot is recommended to apply updates.'    
    /usr/local/bin/notify-discord.sh updates warning "System Reboot Needed" "$REBOOT_MSG"

    # Create the flag file to indicate reboot needed
    echo "1" > "$FLAGFILE"
else
    NEEDS_RESTART_SERVICES=$(sudo needrestart -b | grep "service" | cut -d' ' -f2)

    if [[ -n "$NEEDS_RESTART_SERVICES" ]]; then
        MESSAGE=$(printf "The following services need to be restarted:\n\n%s" "$NEEDS_RESTART_SERVICES")
        /usr/local/bin/notify-discord.sh updates warning "System Restart Needed" "$MESSAGE"
    fi

    # Remove the reboot needed flag, if present
    rm -f "$FLAGFILE"
fi

