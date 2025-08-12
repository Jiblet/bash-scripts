#!/bin/bash
set -euo pipefail

HOSTNAME=$(hostname)
IP_ADDR=$(hostname -I | awk '{print $1}')
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Wait for Tailscale IP (max 30 seconds)
for i in {1..30}; do
  TS_IP=$(tailscale ip -4 2>/dev/null)
  if [[ -n "$TS_IP" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$TS_IP" ]]; then
  TS_IP="(Tailscale not connected)"
fi

OS_INFO=$(lsb_release -ds 2>/dev/null || grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

KERNEL_VERSION=$(uname -r)

DETAILS="🟢 ${HOSTNAME} is back online!

🐧 OS: ${OS_INFO}
🌽 Kernel: ${KERNEL_VERSION}

🌐 Local IP: ${IP_ADDR}
🛡️ Tailscale IP: ${TS_IP}"
#⏰ Timestamp: ${TIMESTAMP}

/usr/local/bin/notify-discord.sh server_watcher success "Startup Notification" "$DETAILS"


