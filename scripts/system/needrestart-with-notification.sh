#!/bin/bash
set -euo pipefail

FLAGFILE="/run/needrestart-reboot-needed"

# Kernel status (batch + list-only). Hide noisy ucode warnings on some systems.
OUT="$(sudo needrestart -k -b -r l 2>/dev/null || true)"

KCUR="$(printf '%s\n' "$OUT" | awk -F': ' '/^NEEDRESTART-KCUR:/ {print $2; exit}')"
KEXP="$(printf '%s\n' "$OUT" | awk -F': ' '/^NEEDRESTART-KEXP:/ {print $2; exit}')"
KSTA="$(printf '%s\n' "$OUT" | awk -F': ' '/^NEEDRESTART-KSTA:/ {print $2; exit}')"
KSTA="${KSTA:-0}"

# KSTA meanings (practical): 1 = OK/no reboot; 2 or 3 = reboot needed.
if [[ "$KSTA" == "2" || "$KSTA" == "3" ]]; then
  note="required"
  [[ "$KSTA" == "2" ]] && note="recommended"
  REBOOT_MSG=$'Kernel reboot '"$note"$'.\n\nCurrent Kernel: '"${KCUR:-unknown}"$'\nExpected Kernel: '"${KEXP:-unknown}"$'\nStatus Code: '"$KSTA"$'\n\nA full system reboot is recommended to apply updates.'
  /usr/local/bin/notify-discord.sh updates warning "System Reboot Needed" "$REBOOT_MSG"
  echo "1" > "$FLAGFILE"
else
  # No kernel reboot; check services that need restarts
  SVC_OUT="$(sudo needrestart -b -r l 2>/dev/null || true)"
  SERVICES="$(printf '%s\n' "$SVC_OUT" | awk -F': ' '/^NEEDRESTART-SVC:/ {print $2}' | sort -u)"
  if [[ -n "$SERVICES" ]]; then
    MESSAGE=$'The following services need to be restarted:\n\n'"$SERVICES"
    /usr/local/bin/notify-discord.sh updates info "Service Restarts Needed" "$MESSAGE"
  fi
  rm -f "$FLAGFILE"
fi
