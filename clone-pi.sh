#!/bin/bash
set -euo pipefail

# Load secrets from global file
if [[ -f "/home/jiblet/secrets.sh" ]]; then
  # shellcheck source=/dev/null
  source "/home/jiblet/secrets.sh"
else
  echo "❌ ERROR: /home/jiblet/secrets.sh file not found. Please create it with your Discord webhook."
  exit 1
fi

if [[ -z "${CLONE_PI_DISCORD_WEBHOOK:-}" ]]; then
  echo "❌ ERROR: CLONE_PI_DISCORD_WEBHOOK is not set in /home/jiblet/secrets.sh"
  exit 1
fi

DISCORD_WEBHOOK="$CLONE_PI_DISCORD_WEBHOOK"

# Check rpi-clone dependency
if ! command -v rpi-clone >/dev/null 2>&1; then
  echo "❌ ERROR: 'rpi-clone' command not found. Please install it."
  curl -s -H "Content-Type: application/json" \
    -X POST -d "{\"content\": \"❌ Clone cancelled: 'rpi-clone' missing on $(hostname)\"}" "$DISCORD_WEBHOOK" >/dev/null || true
  exit 1
fi

# Config
EXPECTED_SERIAL="Generic-_USB3.0_CRW_-SD_201506301013-0:0"
MOUNTPOINT="/mnt/clone"

FORCE=false
DRY_RUN=false

for arg in "$@"; do
  [[ "$arg" == "--force" ]] && FORCE=true
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

log() { echo "$(date '+%F %T') | $1"; }

notify() {
  curl -s -H "Content-Type: application/json" \
    -X POST -d "{\"content\": \"$1\"}" "$DISCORD_WEBHOOK" >/dev/null || log "⚠️ Discord notify failed"
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
  notify "❌ No matching disk found with serial $EXPECTED_SERIAL"
  log "❌ No matching disk found"
  exit 1
}

DEVICE="$(find_disk)"
DISK="$(basename "$DEVICE")"

if [[ "$DRY_RUN" == true ]]; then
  scan_disks
  log "✅ Target disk matched: $DEVICE"
  notify "✅ Target disk matched: $DEVICE"

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

  notify "🧪 Dry run complete. No changes made."
  exit 0
fi

if [[ "$FORCE" != true ]]; then
  log "❌ FORCE flag missing"
  notify "❌ Clone cancelled: FORCE flag not set"
  exit 1
fi

log "✅ Target disk matched: $DEVICE"
notify "✅ Target disk matched: $DEVICE"

for part in $(lsblk -ln -o NAME,MOUNTPOINT "/dev/$DISK" | awk '$2 != "" {print $1}'); do
  umount "/dev/$part" || true
done

notify "🚀 Starting clone to /dev/$DISK"
if ! rpi-clone -f "$DISK" -U; then
  notify "🔥 Clone failed"
  log "❌ Clone failed"
  exit 1
fi
notify "📀 Clone complete"

sleep 2
mkdir -p "$MOUNTPOINT"
mount "/dev/${DISK}2" "$MOUNTPOINT"
mount "/dev/${DISK}1" "$MOUNTPOINT/boot/firmware"

CMDLINE="$MOUNTPOINT/boot/firmware/cmdline.txt"
FSTAB="$MOUNTPOINT/etc/fstab"

if ! [[ -f "$CMDLINE" && -f "$FSTAB" ]]; then
  notify "❌ Missing config files after clone"
  log "⚠️ Missing config files"
  exit 1
fi

BOOT_UUID=$(blkid -s PARTUUID -o value "/dev/${DISK}1")
ROOT_UUID=$(blkid -s PARTUUID -o value "/dev/${DISK}2")

sed -i "s|root=PARTUUID=.*|root=PARTUUID=$ROOT_UUID|" "$CMDLINE"
sed -i "s|PARTUUID=.*-01|PARTUUID=$BOOT_UUID|" "$FSTAB"
sed -i "s|PARTUUID=.*-02|PARTUUID=$ROOT_UUID|" "$FSTAB"

grep -q "$ROOT_UUID" "$CMDLINE" || { notify "❌ UUID mismatch in cmdline"; exit 1; }
grep -q "$BOOT_UUID" "$FSTAB" || { notify "❌ Boot UUID mismatch"; exit 1; }
grep -q "$ROOT_UUID" "$FSTAB" || { notify "❌ Root UUID mismatch"; exit 1; }

umount "$MOUNTPOINT/boot/firmware" || true
umount "$MOUNTPOINT" || true

notify "✅ Clone complete and UUIDs patched"
log "✅ Clone complete and UUIDs patched"

