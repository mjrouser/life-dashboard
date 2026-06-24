#!/usr/bin/env bash
# EA Scanner wrapper — fetches prompt from GitHub, injects date/weekday, runs claude.
# Called by cron on Mac Mini. Cron entry redirects stdout/stderr to /tmp/ea-scanner.log.
set -e

# Prevent concurrent runs — cron overlap or slow Claude sessions would send duplicate notifications
LOCKFILE="/tmp/ea-scanner.pid"
if [[ -f "$LOCKFILE" ]] && kill -0 "$(cat "$LOCKFILE")" 2>/dev/null; then
  echo "$(date): EA scanner already running (PID $(cat "$LOCKFILE")), skipping"
  exit 0
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# Load long-lived OAuth token for subscription auth (cron can't use interactive login)
if [[ -f "$HOME/.anthropic_key" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.anthropic_key"
fi

TODAY=$(date +%Y-%m-%d)
WEEKDAY=$(date +%A)
PROMPT_URL="https://raw.githubusercontent.com/mjrouser/life-dashboard/main/agents/ea-scanner-prompt.md"

PROMPT=$(curl -sf "$PROMPT_URL") || {
  echo "$(date): ERROR — failed to fetch scanner prompt from GitHub" >&2
  exit 1
}

# Load dispatcher config — token stays off GitHub, injected at runtime
DISPATCHER_HOST="192.168.1.225"
DISPATCHER_PORT="8765"
DISPATCHER_TOKEN=""
if [[ -f "/Users/mjr/scripts/action-dispatcher/.env" ]]; then
  DISPATCHER_TOKEN=$(grep -m1 "^SECRET_TOKEN=" /Users/mjr/scripts/action-dispatcher/.env | cut -d= -f2)
fi

# Inject date and weekday into the prompt — dispatcher config stays in this process only
PROMPT="${PROMPT//TODAY/$TODAY}"
PROMPT="${PROMPT//WEEKDAY/$WEEKDAY}"

echo "$(date): EA scanner starting — $TODAY ($WEEKDAY)"
CLAUDE_OUTPUT=$(echo "$PROMPT" | /Users/mjr/.local/bin/claude --print --allowedTools "Bash,WebFetch" 2>&1)
echo "$CLAUDE_OUTPUT"

# Parse the EA_ACTION line and dispatch — token never entered Claude's context
ACTION_LINE=$(echo "$CLAUDE_OUTPUT" | grep '^EA_ACTION: ' | tail -1)
if [[ -z "$ACTION_LINE" ]]; then
  echo "$(date): ERROR — no EA_ACTION found in Claude output" >&2
  exit 1
fi
ACTION_JSON="${ACTION_LINE#EA_ACTION: }"
JQ=/usr/local/bin/jq
ACTION=$(echo "$ACTION_JSON" | $JQ -r '.action')

if [[ "$ACTION" == "all_clear" ]]; then
  curl -s -o /dev/null \
    -H "Title: EA — Nothing to surface today" \
    -H "Tags: white_check_mark" \
    -d "All threads are recent, on cooldown, or parked. Nothing needs you right now." \
    "https://ntfy.sh/life-os"
  echo "$(date): EA scanner — all clear sent"
elif [[ "$ACTION" == "notify" ]]; then
  THREAD_ID=$(echo "$ACTION_JSON" | $JQ -r '.thread_id')
  NOTIFICATION_TITLE=$(echo "$ACTION_JSON" | $JQ -r '.notification_title')
  NOTIFICATION_BODY=$(echo "$ACTION_JSON" | $JQ -r '.notification_body')
  DRAFT_TYPE=$(echo "$ACTION_JSON" | $JQ -r '.draft_type')

  curl -s -o /dev/null -w "HTTP %{http_code}" \
    -H "Title: ${NOTIFICATION_TITLE}" \
    -H "Priority: default" \
    -H "Tags: robot" \
    -H "Click: https://mjrouser.github.io/life-dashboard" \
    -H "Actions: http, Approve, http://${DISPATCHER_HOST}:${DISPATCHER_PORT}/action/approve/${THREAD_ID}, method=POST, headers.Authorization=Bearer ${DISPATCHER_TOKEN}; http, Snooze, http://${DISPATCHER_HOST}:${DISPATCHER_PORT}/action/snooze/${THREAD_ID}, method=POST, headers.Authorization=Bearer ${DISPATCHER_TOKEN}; http, Refine, http://${DISPATCHER_HOST}:${DISPATCHER_PORT}/action/refine/${THREAD_ID}, method=POST, headers.Authorization=Bearer ${DISPATCHER_TOKEN}" \
    --data-raw "${NOTIFICATION_BODY}" \
    "https://ntfy.sh/life-os"
  echo ""
  echo "$(date): EA scanner — notification sent for ${THREAD_ID} (${DRAFT_TYPE})"
else
  echo "$(date): ERROR — unknown action: $ACTION" >&2
  exit 1
fi
