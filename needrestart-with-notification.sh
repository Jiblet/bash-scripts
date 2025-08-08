#!/bin/bash

# Run needrestart kernel check with batch mode and list-only
readarray -t lines < <(sudo needrestart -k -b -r l)

if [[ ${#lines[@]} -gt 0 ]]; then
    # Parse key kernel variables from output
    KCUR=$(echo "${lines[@]}" | grep -oP 'NEEDRESTART-KCUR:\s*\K\S+')
    KEXP=$(echo "${lines[@]}" | grep -oP 'NEEDRESTART-KEXP:\s*\K\S+')
    KSTA=$(echo "${lines[@]}" | grep -oP 'NEEDRESTART-KSTA:\s*\K\S+')

    # Compose detailed reboot message
    REBOOT_MSG=$'Kernel reboot required.\n\nCurrent Kernel: '"$KCUR"$'\nExpected Kernel: '"$KEXP"$'\nStatus Code: '"$KSTA"$'\n\nA full system reboot is recommended to apply updates.'    
    # Send Discord notification
    /usr/local/bin/notify-discord.sh updates warning "System Reboot Needed" "$REBOOT_MSG"
else
    # Check for services needing restart
    NEEDS_RESTART_SERVICES=$(sudo needrestart -b | grep "service" | cut -d' ' -f2)
    
    if [[ -n "$NEEDS_RESTART_SERVICES" ]]; then
        MESSAGE=$(printf "The following services need to be restarted:\n\n%s" "$NEEDS_RESTART_SERVICES")
        /usr/local/bin/notify-discord.sh updates warning "System Restart Needed" "$MESSAGE"
    fi
fi
