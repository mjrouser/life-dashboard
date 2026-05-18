#!/usr/bin/env bash
# EA Scanner wrapper — fetches prompt from GitHub, injects date/weekday, runs claude.
# Called by cron on Mac Mini. Cron entry redirects stdout/stderr to /tmp/ea-scanner.log.
set -e

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

# Inject date and weekday into the prompt
PROMPT="${PROMPT//TODAY/$TODAY}"
PROMPT="${PROMPT//WEEKDAY/$WEEKDAY}"

echo "$(date): EA scanner starting — $TODAY ($WEEKDAY)"
echo "$PROMPT" | /Users/mjr/.local/bin/claude --print --allowedTools "Bash,WebFetch"
echo "$(date): EA scanner finished"
