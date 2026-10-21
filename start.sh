#!/bin/bash
set -e

export HERMES_HOME="${HERMES_HOME:-/opt/data}"
mkdir -p "$HERMES_HOME"

# First-boot config
[ -f "$HERMES_HOME/.env" ] || touch "$HERMES_HOME/.env"
if [ ! -f "$HERMES_HOME/config.yaml" ] && [ -f /opt/hermes/cli-config.yaml.example ]; then
  cp /opt/hermes/cli-config.yaml.example "$HERMES_HOME/config.yaml"
fi

# Personality (re-applied every boot, so edit SOUL.md on GitHub to change it)
cp /app/SOUL.md "$HERMES_HOME/SOUL.md"

# Write secrets from Render env vars into Hermes .env
write_env () {
  local key="$1" val="${!1}"
  [ -z "$val" ] && return 0
  grep -v "^${key}=" "$HERMES_HOME/.env" > "$HERMES_HOME/.env.tmp" || true
  echo "${key}=${val}" >> "$HERMES_HOME/.env.tmp"
  mv "$HERMES_HOME/.env.tmp" "$HERMES_HOME/.env"
}
for k in OPENROUTER_API_KEY HERMES_INFERENCE_PROVIDER HERMES_MODEL LLM_MODEL \
         TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS OPENAI_API_KEY OPENAI_BASE_URL; do
  write_env "$k"
done

# Tiny web server so Render sees an open port and UptimeRobot has a URL to ping
mkdir -p /tmp/health
echo "ok" > /tmp/health/index.html
python3 -m http.server "${PORT:-10000}" --bind 0.0.0.0 --directory /tmp/health >/dev/null 2>&1 &

if [ -n "$HERMES_MODEL" ]; then
  hermes config set model "$HERMES_MODEL" || true
fi
exec hermes gateway run
