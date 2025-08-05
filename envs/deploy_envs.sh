#!/bin/bash
# deploy_envs.sh
# Deploys the global .env.example to each bot environment, allowing for local overrides.
# Usage: bash awbot/envs/deploy_envs.sh [--force]

set -e

GLOBAL_ENV="awbot/envs/.env.example"
ENV_DIR="awbot/envs"
BOTS=("bot" "cloud" "djs" "dpy")
FORCE=0

if [[ "$1" == "--force" ]]; then
  FORCE=1
fi

echo "Deploying global .env.example to bot environments..."

for BOT in "${BOTS[@]}"; do
  BOT_ENV_DIR="$ENV_DIR/$BOT"
  BOT_ENV_EXAMPLE="$BOT_ENV_DIR/.env.example"
  BOT_ENV="$BOT_ENV_DIR/.env"

  # Ensure bot env directory exists
  if [[ ! -d "$BOT_ENV_DIR" ]]; then
    echo "Creating directory: $BOT_ENV_DIR"
    mkdir -p "$BOT_ENV_DIR"
  fi

  # Copy global .env.example to bot's .env.example if not present or --force
  if [[ ! -f "$BOT_ENV_EXAMPLE" || $FORCE -eq 1 ]]; then
    echo "Copying $GLOBAL_ENV to $BOT_ENV_EXAMPLE"
    cp "$GLOBAL_ENV" "$BOT_ENV_EXAMPLE"
  else
    echo "$BOT_ENV_EXAMPLE already exists. Use --force to overwrite."
  fi

  # Copy .env.example to .env if not present or --force
  if [[ ! -f "$BOT_ENV" || $FORCE -eq 1 ]]; then
    echo "Copying $BOT_ENV_EXAMPLE to $BOT_ENV"
    cp "$BOT_ENV_EXAMPLE" "$BOT_ENV"
  else
    echo "$BOT_ENV already exists. Use --force to overwrite."
  fi

  echo "Deployed env for $BOT."
done

echo "All environments deployed."
echo "You may now edit each bot's .env file for local overrides."