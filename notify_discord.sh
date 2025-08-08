#!/bin/bash
set -euo pipefail

# ======================================================================
# Reusable Discord Notification Script
# Sends rich Discord webhook notifications for job status updates.
# Supports secrets file auto-detection with root/systemd friendly logic.
# Includes a --test mode to send sample notifications for easy validation.
# Logs notification success/failure to systemd journal.
# ======================================================================

# --- Load secrets file ---

# Preferred override: explicit environment variable pointing to secrets file
if [[ -n "${SECRETS_FILE:-}" && -f "$SECRETS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
elif [[ -z "${HOME:-}" ]]; then
    INVOKER="${SUDO_USER:-${USER:-}}"
    if [[ -n "$INVOKER" ]]; then
        HOME_DIR="$(getent passwd "$INVOKER" | cut -d: -f6)"
    else
        HOME_DIR="/root"
    fi
    if [[ -f "$HOME_DIR/secrets.sh" ]]; then
        # shellcheck disable=SC1090
        source "$HOME_DIR/secrets.sh"
    elif [[ -f "/etc/notify-discord/secrets.sh" ]]; then
        # shellcheck disable=SC1090
        source "/etc/notify-discord/secrets.sh"
    elif [[ -f "/home/jiblet/secrets.sh" ]]; then
        # shellcheck disable=SC1090
        source "/home/jiblet/secrets.sh"
    else
        echo "❌ ERROR: Secrets file not found.
Checked locations:
• SECRETS_FILE env var
• \$HOME or detected home dir/secrets.sh ($HOME_DIR/secrets.sh)
• /etc/notify-discord/secrets.sh
• /home/jiblet/secrets.sh (legacy)"
        exit 1
    fi
else
    if [[ -f "$HOME/secrets.sh" ]]; then
        # shellcheck disable=SC1090
        source "$HOME/secrets.sh"
    elif [[ -f "/etc/notify-discord/secrets.sh" ]]; then
        # shellcheck disable=SC1090
        source "/etc/notify-discord/secrets.sh"
    elif [[ -f "/home/jiblet/secrets.sh" ]]; then
        # shellcheck disable=SC1090
        source "/home/jiblet/secrets.sh"
    else
        echo "❌ ERROR: Secrets file not found.
Checked locations:
• SECRETS_FILE env var
• \$HOME/secrets.sh ($HOME/secrets.sh)
• /etc/notify-discord/secrets.sh
• /home/jiblet/secrets.sh (legacy)"
        exit 1
    fi
fi

declare -A WEBHOOKS=(
    [updates]="${DISCORD_WEBHOOK_UPDATES:-}"
    [clone]="${DISCORD_WEBHOOK_CLONE:-}"
    [borgmatic]="${DISCORD_WEBHOOK_BORGMATIC:-}"
    [vaultwarden_backup]="${DISCORD_WEBHOOK_VAULTWARDEN_BACKUP:-}"
    [test]="${DISCORD_WEBHOOK_TEST:-}"
)

for key in "${!WEBHOOKS[@]}"; do
    if [[ -z "${WEBHOOKS[$key]}" ]]; then
        echo "❌ ERROR: Webhook URL for '$key' is missing! Check your secrets or environment variables."
        exit 1
    fi
done

if [ "$#" -eq 0 ] || [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0 "WEBHOOK_NAME" [success|failed|warning] "Job Name" [Optional Message]

Send a Discord notification using the named webhook.

Examples:
  $0 updates success "Daily Apt Update" "No updates available"

Special modes:
  $0 test       # Runs a series of test notifications (success, warning, failed)
  $0 --test     # Same as 'test'

EOF
    exit 0
fi

if { [ "$#" -eq 1 ] && { [ "$1" = "test" ] || [ "$1" = "--test" ]; }; }; then
    echo "Running test notifications..."

    "$0" test success "Test Success" "This is a test success message." && \
    "$0" test warning "Test Warning" "This is a test warning message." && \
    "$0" test failed "Test Failed" "This is a test failure message."

    if [ $? -eq 0 ]; then
        echo "All test notifications sent successfully."
        exit 0
    else
        echo "One or more test notifications failed."
        exit 1
    fi
fi

if [ "$#" -lt 3 ]; then
    echo "❌ ERROR: Insufficient arguments."
    echo "Usage: $0 \"WEBHOOK_NAME\" [success|failed|warning] \"Job Name\" [Optional Message]"
    echo "Try '$0 test' or '$0 --test' to send test notifications."
    exit 1
fi

WEBHOOK_NAME="$1"
JOB_STATUS="$2"
JOB_NAME="$3"
CUSTOM_MESSAGE="${4-}"

HOSTNAME=$(hostname)

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ ERROR: 'jq' is required but not installed."
    exit 1
fi

WEBHOOK_URL="${WEBHOOKS[$WEBHOOK_NAME]:-}"
if [[ -z "$WEBHOOK_URL" ]]; then
    echo "❌ ERROR: Webhook name '$WEBHOOK_NAME' not found or webhook URL is empty."
    exit 1
fi

case "$JOB_STATUS" in
    success)
        EMBED_COLOR=65280
        EMBED_TITLE="✅ Job Success: $JOB_NAME"
        BASE_DESCRIPTION="The job completed successfully on **$HOSTNAME** at $(date '+%Y-%m-%d %H:%M:%S')."
        ;;
    failed)
        EMBED_COLOR=16711680
        EMBED_TITLE="❌ Job Failed: $JOB_NAME"
        BASE_DESCRIPTION="The job failed to complete on **$HOSTNAME** at $(date '+%Y-%m-%d %H:%M:%S')."
        ;;
    warning)
        EMBED_COLOR=16776960
        EMBED_TITLE="⚠️ Job Warning: $JOB_NAME"
        BASE_DESCRIPTION="The job completed with a warning on **$HOSTNAME** at $(date '+%Y-%m-%d %H:%M:%S')."
        ;;
    *)
        echo "❌ ERROR: Invalid job status provided. Use 'success', 'failed', or 'warning'."
        exit 1
        ;;
esac

if [[ -n "$CUSTOM_MESSAGE" ]]; then
    JSON_PAYLOAD=$(jq -n \
        --arg title "$EMBED_TITLE" \
        --arg description "$BASE_DESCRIPTION" \
        --arg custom_message "$CUSTOM_MESSAGE" \
        --argjson color "$EMBED_COLOR" \
        '{embeds: [{title: $title, description: ($description + "\n\n**Details:**\n```\n" + $custom_message + "\n```"), color: $color}]}')
else
    JSON_PAYLOAD=$(jq -n \
        --arg title "$EMBED_TITLE" \
        --arg description "$BASE_DESCRIPTION" \
        --argjson color "$EMBED_COLOR" \
        '{embeds: [{title: $title, description: $description, color: $color}]}')
fi

# --- Send notification and log results to journald ---
if curl -s -S -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$WEBHOOK_URL"; then
    logger -t notify_discord -p user.info "Notification sent successfully to '$WEBHOOK_NAME' for job '$JOB_NAME' with status '$JOB_STATUS'."
else
    logger -t notify_discord -p user.err "Failed to send notification to '$WEBHOOK_NAME' for job '$JOB_NAME' with status '$JOB_STATUS'."
    echo "❌ ERROR: Failed to send notification for job '$JOB_NAME'."
    exit 1
fi
