#!/bin/bash
# ~/.automated-rpi-clone.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <destination-disk>" >&2
  echo "Example: $0 sda" >&2
  exit 1
fi

DEST_DISK="$1"
BOOT_PART="${DEST_DISK}1"
ROOT_PART="${DEST_DISK}2"

echo "Destination disk: /dev/$DEST_DISK"

# Step 1: Unmount any mounted partitions on destination disk
echo "Unmounting any mounted partitions on /dev/${DEST_DISK}..."
for part in ${BOOT_PART} ${ROOT_PART}; do
  if mount | grep -q "^/dev/${part} "; then
    echo "Unmounting /dev/${part}..."
    umount "/dev/${part}"
  fi
done

# Step 2: Run rpi-clone with force initialization
echo "Starting rpi-clone to /dev/${DEST_DISK}..."
rpi-clone -f "$DEST_DISK" || { echo "rpi-clone failed! Exiting."; exit 1; }

# Step 3: Get new PARTUUIDs from the cloned partitions
echo "Reading new PARTUUIDs from /dev/${BOOT_PART} and /dev/${ROOT_PART}..."
BOOT_PARTUUID=$(blkid -s PARTUUID -o value "/dev/${BOOT_PART}")
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "/dev/${ROOT_PART}")

echo "New boot partition PARTUUID: $BOOT_PARTUUID"
echo "New root partition PARTUUID: $ROOT_PARTUUID"

# Step 4: Update /etc/fstab on the clone
FSTAB_PATH="/mnt/clone/etc/fstab"
if [[ -f "$FSTAB_PATH" ]]; then
  echo "Updating PARTUUIDs in $FSTAB_PATH..."
  sed -i -E "s|PARTUUID=[a-f0-9-]+-01|PARTUUID=${BOOT_PARTUUID}|g" "$FSTAB_PATH"
  sed -i -E "s|PARTUUID=[a-f0-9-]+-02|PARTUUID=${ROOT_PARTUUID}|g" "$FSTAB_PATH"
else
  echo "Warning: $FSTAB_PATH not found!"
fi

# Step 5: Update cmdline.txt on the clone boot partition
CMDLINE_PATH="/mnt/clone/boot/firmware/cmdline.txt"
if [[ -f "$CMDLINE_PATH" ]]; then
  echo "Updating root PARTUUID in $CMDLINE_PATH..."
  sed -i -E "s|root=PARTUUID=[a-f0-9-]+|root=PARTUUID=${ROOT_PARTUUID}|g" "$CMDLINE_PATH"
else
  echo "Warning: $CMDLINE_PATH not found!"
fi

# Step 6: Unmount the cloned partitions
echo "Unmounting cloned partitions..."
umount "/mnt/clone/boot/firmware" || echo "Warning: failed to unmount /mnt/clone/boot/firmware"
umount "/mnt/clone" || echo "Warning: failed to unmount /mnt/clone"

echo "Clone completed and verified. You can now test booting from /dev/${DEST_DISK}."

exit 0
