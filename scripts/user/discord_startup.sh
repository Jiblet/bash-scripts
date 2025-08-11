#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/1392882142391832606/jfRHHLZ2PaquIPi-xe30In_PmjH3Ph3lMFazsO5lS1_AktNTBkN4OGBqSPfaTXpzY-PN"

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

# JSON with description field for newlines
read -r -d '' JSON_PAYLOAD <<EOF
{
  "username": "Server Watcher",
  "embeds": [{
    "title": "🟢 ${HOSTNAME} is back online!",
    "description": "⏰ **Timestamp**\n${TIMESTAMP}\n\n🌐 **Local IP**\n${IP_ADDR}\n\n🛡️ **Tailscale IP**\n${TS_IP}",
    "color": 65280
 }]
}
EOF

curl -H "Content-Type: application/json" \
     -X POST \
     -d "$JSON_PAYLOAD" \
     "$WEBHOOK_URL"
