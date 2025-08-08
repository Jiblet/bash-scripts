# bash-scripts

A collection of Bash utilities for automating Raspberry Pi workflows and system tasks.  
No secrets are included—configuration happens via environment files.

---

## 🟢 clone-pi.sh

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

## 🔴 automated-rpi-clone.sh

> ⚠️ **Status: COMPLETELY UNTESTED** – use at your own risk. Script logic is sound but hasn't been verified AT ALL.

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

## 📣 notify_discord.sh

A reusable Bash script to send rich Discord webhook notifications for job status updates.

### Features
- Supports multiple named webhooks configured via secrets or environment variables.
- Sends embedded messages with status: `success`, `failed`, or `warning`.
- Includes a `test` mode to send sample notifications for easy validation.
- Logs notification attempts and errors to systemd journal (`notify_discord` tag).
- Automatically detects secrets file from multiple standard locations.

### Requirements
- `jq` installed (used to build JSON payloads)
- `curl` installed (to send HTTP POST requests)
- Secrets file defining Discord webhook URLs, e.g.:
  ```bash
  export DISCORD_WEBHOOK_UPDATES="https://discord.com/api/webhooks/..."
  export DISCORD_WEBHOOK_CLONE="https://discord.com/api/webhooks/..."
  # ...and so on
  ```

### Usage

```bash
# Send a success notification to the 'updates' webhook
./notify_discord.sh updates success "Daily Apt Update" "No updates available"

# Send a failure notification to the 'clone' webhook
./notify_discord.sh clone failed "Backup Clone Job" "Disk not found"

# Send a warning notification to any webhook
./notify_discord.sh updates warning "Memory Usage" "Memory above threshold"

# Run the built-in test sequence (sends success, warning, failed test notifications)
./notify_discord.sh test

# or equivalently:
./notify_discord.sh --test
```

---

## 🔔 needrestart-check.sh

Monitors kernel and service restart requirements using `needrestart` and sends Discord notifications accordingly.

### Features
- Detects if a kernel reboot is required after updates
- If no kernel reboot is needed, checks for services that require restarting
- Sends rich warning notifications to Discord via `notify-discord.sh`
- Provides detailed info on current vs expected kernel versions in notifications

### Requirements
- `needrestart` installed and runnable with sudo
- `notify-discord.sh` available and configured for Discord webhook notifications
- `sudo` privileges to run `needrestart` commands

### Usage
```bash
sudo ./needrestart-check.sh

---

## 📦 apt-refresh-with-notification.sh

Runs an APT package list update and sends Discord notifications about update status.

### Features
- Performs `apt update` and checks for upgradable packages
- Sends Discord notifications on success, warning (upgrades available), or failure
- Runs as root but switches to the `jiblet` user for Discord notification commands
- Minimal output, designed for automated systemd or cron jobs

### Requirements
- `apt` package manager available
- `notify-discord.sh` configured and accessible by user `jiblet`
- Run as root or with sufficient privileges to execute `apt update`

### Usage
```bash
sudo ./apt-refresh-with-notification.sh
