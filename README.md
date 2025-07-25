# bash-scripts

A collection of Bash utilities for automating Raspberry Pi workflows and system tasks.  
No secrets are included—configuration happens via environment files.

---

## ✔️ clone-pi.sh

Automates disk cloning on a Raspberry Pi using `rpi-clone`, with Discord webhook integration for notifications and UUID patching.

### Features
- Scans and matches USB disks by serial to ensure the correct target — *you’ll need to adjust the hardcoded serial value!*
- Supports dry runs (`--dry-run`) to preview the target device
- Requires explicit `--force` flag to proceed with cloning
- Sends notifications via Discord at all stages (see Requirements)
- Automatically patches `cmdline.txt` and `fstab` with new UUIDs

### Requirements
- `rpi-clone` installed
- `sudo` access (rpi-clone needs it)
- Secrets file at `/home/jiblet/secrets.sh` containing:
  ```bash
  export CLONE_PI_DISCORD_WEBHOOK="your-webhook-url"
  ```
  So you'll want to switch that for your homedir, because I'm quite lazy and it runs as root.

### Usage
```bash
sudo ./clone-pi.sh --dry-run    # scan and validate disk without cloning
sudo ./clone-pi.sh --force      # proceed with cloning to matched device
```

---

## ⚠️ automated-rpi-clone.sh

> **Status: COMPLETELY UNTESTED** – use at your own risk. Script logic is sound but hasn't been verified AT ALL.

Minimalistic one-shot clone utility. Does not rely on serial matching or Discord integration. Assumes a specified disk and standard Raspberry Pi layout.

### Features
- Requires `sudo`
- Accepts disk argument (e.g. `sda`, `sdb`)
- Unmounts target partitions before cloning
- Runs `rpi-clone` with force initialization
- Automatically updates `fstab` and `cmdline.txt` with correct PARTUUIDs

### Usage
```bash
sudo ./automated-rpi-clone.sh sda
```

### Assumptions
- `/mnt/clone` is used for post-clone mounting
- Target disk has two partitions: `1` for boot, `2` for root
- System can access the cloned disk for UUID patching

---

