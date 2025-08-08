#!/bin/bash
set -euo pipefail

# Start the clock
START_TIME=$(date +%s)

# ==============================================================================
# TMUX Check
# Ensures the script runs in a detached tmux session to prevent termination
# upon SSH disconnection. The script re-runs itself inside a new session.
# ==============================================================================
if [[ -z "${TMUX:-}" ]]; then
    echo "Not running in tmux. Automatically starting a new session."
    # The session name now includes both date (%F) and time (%H%M%S)
    tmux new-session -d -s "clone-pi-$(date +%F-%H%M%S)" "$0" "$@"
    echo "Started clone-pi in a detached tmux session. You can reattach with: sudo tmux attach-session -t clone-pi-$(date +%F-%H%M%S)"
    exit 0
fi

# ==============================================================================
# Load secrets from global file
# Sources the secrets file to load Discord webhook URLs and other variables.
# ==============================================================================
if [[ -f "/home/jiblet/secrets.sh" ]]; then
    # shellcheck source=/dev/null
    source "/home/jiblet/secrets.sh"
else
    notify failed "Clone" "❌ ERROR: /home/jiblet/secrets.sh file not found."
    exit 1
fi

# ==============================================================================
# Check Dependencies
# Ensures the core 'rpi-clone' command is installed before proceeding.
# ==============================================================================
if ! command -v rpi-clone >/dev/null 2>&1; then
    notify failed "Clone" "❌ Clone cancelled: 'rpi-clone' missing on $(hostname)"
    exit 1
fi

# ==============================================================================
# Helper Functions
# These functions simplify logging, notifications, and other common tasks.
# ==============================================================================

log() { echo "$(date '+%F %T') | $1"; }

notify() {
    local STATUS="$1"
    local JOB_NAME="$2"
    local MESSAGE="$3"
    local WEBHOOK_TYPE="${4:-clone}"  # Default webhook type = 'clone'

    # Calculate elapsed time since script start
    local now elapsed elapsed_str
    now=$(date +%s)
    elapsed=$(( now - START_TIME ))

    if (( elapsed < 60 )); then
        elapsed_str=$'\nTimer: '${elapsed}s
    elif (( elapsed < 3600 )); then
        local minutes=$(( elapsed / 60 ))
        local seconds=$(( elapsed % 60 ))
        elapsed_str=$(printf $'\nTimer: %02d:%02d' "$minutes" "$seconds")
    else
        local hours=$(( elapsed / 3600 ))
        local minutes=$(( (elapsed % 3600) / 60 ))
        local seconds=$(( elapsed % 60 ))
        elapsed_str=$(printf $'\nTimer: %d:%02d:%02d' "$hours" "$minutes" "$seconds")
    fi

    # Append elapsed time to message
    MESSAGE="${MESSAGE}${elapsed_str}"

    # Map webhook type to environment variable holding webhook URL
    local WEBHOOK_VAR="DISCORD_WEBHOOK_${WEBHOOK_TYPE^^}"  # uppercase
    local WEBHOOK_URL="${!WEBHOOK_VAR:-}"

    if [[ -z "$WEBHOOK_URL" ]]; then
        log "⚠️  Warning: Discord webhook URL for type '$WEBHOOK_TYPE' not found. Notification skipped."
        return 1
    fi

    /usr/local/bin/notify-discord.sh "$WEBHOOK_TYPE" "$STATUS" "$JOB_NAME" "$MESSAGE"
}

send_monthly_reminder() {
    local REMINDER_FILE="/var/lib/clone-pi/last_backup_test_reminder"
    local now
    now=$(date +%s)

    if [[ -f "$REMINDER_FILE" ]]; then
        last=$(cat "$REMINDER_FILE")
    else
        last=0
    fi

    local month_seconds=$((30*24*60*60))

    if (( now - last > month_seconds )); then
        notify warning "Backup Test Reminder" "⏰ Reminder: It's been a month since the last backup test. Please boot from your backup SD card to ensure it's working!"
        echo "$now" > "$REMINDER_FILE"
    fi
}

scan_disks() {
    log "🔍 Scanning available /dev/sd? disks:"
    for dev in /dev/sd?; do
        serial=$(udevadm info --query=property --name="$dev" | grep '^ID_SERIAL=' | cut -d= -f2)
        model=$(udevadm info --query=property --name="$dev" | grep '^ID_MODEL=' | cut -d= -f2)
        size=$(lsblk -dn -o SIZE "$dev")
        log "$dev | Serial: ${serial:-unknown} | Model: ${model:-unknown} | Size: ${size:-unknown}"
    done
}

find_disk() {
    for dev in /dev/sd?; do
        serial=$(udevadm info --query=property --name="$dev" | grep '^ID_SERIAL=' | cut -d= -f2)
        if [[ "$serial" == "$EXPECTED_SERIAL" ]]; then
            echo "$dev"
            return
        fi
    done
    notify failed "Clone" "❌ No matching disk found with serial $EXPECTED_SERIAL"
    log "❌ No matching disk found"
    exit 1
}

# ==============================================================================
# Main Script Logic
# This is the main execution flow of the clone-pi script.
# ==============================================================================
# Config variables for the script
EXPECTED_SERIAL="Generic-_USB3.0_CRW_-SD_201506301013-0:0"
MOUNTPOINT="/mnt/clone"

# Flags to control script behavior
FORCE=false
DRY_RUN=false

for arg in "$@"; do
    [[ "$arg" == "--force" ]] && FORCE=true
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

DEVICE="$(find_disk)"
DISK="$(basename "$DEVICE")"

# --- Dry Run ---
if [[ "$DRY_RUN" == true ]]; then
    scan_disks
    log "✅ Target disk matched: $DEVICE"
    notify success "Clone" "✅ Target disk matched: $DEVICE" "test"

    log "🔍 lsblk preview:"
    lsblk -o NAME,FSTYPE,LABEL,SIZE,TYPE,MOUNTPOINT "/dev/$DISK"

    model=$(udevadm info --query=property --name="$DEVICE" | grep '^ID_MODEL=' | cut -d= -f2)
    size=$(lsblk -dn -o SIZE "$DEVICE")
    mounts=$(lsblk -ln -o MOUNTPOINT "/dev/$DISK" | awk '$1 != ""' || echo "None")

    log "Dry run:"
    log "Device: $DEVICE"
    log "Model: ${model:-unknown}"
    log "Size: ${size:-unknown}"
    log "Mounts: $mounts"

    notify success "Clone Dry Run" "🧪 Dry run complete. No changes made." "test"
    exit 0
fi

# --- Check for FORCE flag before destructive actions ---
if [[ "$FORCE" != true ]]; then
    log "❌ Clone cancelled: FORCE flag not set"
    notify failed "Clone" "❌ Clone cancelled: FORCE flag not set"
    exit 1
fi

log "✅ Target disk matched: $DEVICE"
notify success "Clone" "✅ Target disk matched: $DEVICE"

# --- Unmount existing partitions to prepare for clone ---
for part in $(); do
    umount "/dev/$part" || true
done

# --- Run the clone ---
notify success "Clone" "🚀 Starting clone to /dev/$DISK"
if ! rpi-clone -f "$DISK" -U; then
    notify failed "Clone" "🔥 Clone failed"
    log "❌ Clone failed"
    exit 1
fi
notify success "Clone" "📀 Clone complete"

sleep 2
mkdir -p "$MOUNTPOINT"
mount "/dev/${DISK}2" "$MOUNTPOINT"
mount "/dev/${DISK}1" "$MOUNTPOINT/boot/firmware"

CMDLINE="$MOUNTPOINT/boot/firmware/cmdline.txt"
FSTAB="$MOUNTPOINT/etc/fstab"

if ! [[ -f "$CMDLINE" && -f "$FSTAB" ]]; then
    notify failed "Clone" "❌ Missing config files after clone"
    log "⚠️ Missing config files"
    exit 1
fi

# --- Patch UUIDs on the new SD card ---
BOOT_UUID=$(blkid -s PARTUUID -o value "/dev/${DISK}1")
ROOT_UUID=$(blkid -s PARTUUID -o value "/dev/${DISK}2")

sed -i "s|root=PARTUUID=.*|root=PARTUUID=$ROOT_UUID|" "$CMDLINE"
sed -i "s|PARTUUID=.*-01|PARTUUID=$BOOT_UUID|" "$FSTAB"
sed -i "s|PARTUUID=.*-02|PARTUUID=$ROOT_UUID|" "$FSTAB"

# --- Final checks and cleanup ---
grep -q "$ROOT_UUID" "$CMDLINE" || { notify failed "Clone" "❌ UUID mismatch in cmdline"; exit 1; }
grep -q "$BOOT_UUID" "$FSTAB" || { notify failed "Clone" "❌ Boot UUID mismatch"; exit 1; }
grep -q "$ROOT_UUID" "$FSTAB" || { notify failed "Clone" "❌ Root UUID mismatch"; exit 1; }

umount "$MOUNTPOINT/boot/firmware" || true
umount "$MOUNTPOINT" || true

notify success "Clone" "✅ Clone complete and UUIDs patched"
log "✅ Clone complete and UUIDs patched"
send_monthly_reminder
