#!/bin/bash
# Cortex service discovery engine
# Detects running services (databases, caches, message queues) and Docker containers
# Part of the Cortex "Discover" feature — machine-wide discovery for developer environments
#
# Usage:
#   ./discover-services.sh [projects-json-file]
#
# Arguments:
#   projects-json-file  Optional path to a JSON file containing project paths
#                       (output from discover-projects.sh). Used to find
#                       docker-compose files in each project directory.
#
# Output: JSON to stdout with three sections:
#   - running:          Services detected via port checks
#   - dockerContainers: Running Docker containers
#   - composeFiles:     Docker Compose files found in project directories
#
# Requirements: bash + Python 3.10+ stdlib only (no pip packages)
# All external commands use a 5-second timeout
# Always exits 0 — failures produce empty arrays

set -uo pipefail

PROJECTS_FILE="${1:-}"
TIMEOUT_CMD="timeout"

# macOS uses gtimeout from coreutils, fall back to no timeout
if [[ "$(uname)" == "Darwin" ]]; then
  if command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
  else
    TIMEOUT_CMD=""
  fi
fi

run_with_timeout() {
  if [ -n "$TIMEOUT_CMD" ]; then
    $TIMEOUT_CMD 5 "$@" 2>/dev/null
  else
    "$@" 2>/dev/null
  fi
}

# --- Detect OS for port-check strategy ---
IS_MACOS=false
[[ "$(uname)" == "Darwin" ]] && IS_MACOS=true

check_port() {
  local port="$1"
  if $IS_MACOS; then
    run_with_timeout lsof -i :"$port" -P -n 2>/dev/null | grep LISTEN | head -1
  else
    run_with_timeout ss -tlnp 2>/dev/null | grep ":${port} "
  fi
  return $?
}

# --- Running services (port checks) ---
declare -a SERVICE_NAMES=(postgres mysql redis mongodb elasticsearch rabbitmq kafka consul minio)
declare -a SERVICE_PORTS=(5432 3306 6379 27017 9200 5672 9092 8500 9000)

RUNNING_JSON="["
FIRST=true
for i in "${!SERVICE_NAMES[@]}"; do
  name="${SERVICE_NAMES[$i]}"
  port="${SERVICE_PORTS[$i]}"
  if check_port "$port" &>/dev/null; then
    [ "$FIRST" = true ] && FIRST=false || RUNNING_JSON+=","
    RUNNING_JSON+=$(printf '\n    {"name": "%s", "port": %d, "detected": true, "source": "port-check"}' "$name" "$port")
  fi
done
RUNNING_JSON+=$'\n  ]'

# --- Docker containers ---
DOCKER_JSON="["
if command -v docker &>/dev/null; then
  RAW=$(run_with_timeout docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null)
  if [ -n "$RAW" ]; then
    FIRST=true
    while IFS=$'\t' read -r cname cimage cstatus cports; do
      [ -z "$cname" ] && continue
      # Escape double quotes in fields
      cname="${cname//\"/\\\"}"
      cimage="${cimage//\"/\\\"}"
      cstatus="${cstatus//\"/\\\"}"
      cports="${cports//\"/\\\"}"
      [ "$FIRST" = true ] && FIRST=false || DOCKER_JSON+=","
      DOCKER_JSON+=$(printf '\n    {"name": "%s", "image": "%s", "status": "%s", "ports": "%s"}' "$cname" "$cimage" "$cstatus" "$cports")
    done <<< "$RAW"
  fi
fi
DOCKER_JSON+=$'\n  ]'

# --- Docker Compose files from project paths ---
COMPOSE_JSON="["
if [ -n "$PROJECTS_FILE" ] && [ -f "$PROJECTS_FILE" ]; then
  # Extract project paths using Python stdlib
  PATHS=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    # Support both a list of strings and a list of objects with 'path' key
    if isinstance(data, list):
        for item in data:
            if isinstance(item, str):
                print(item)
            elif isinstance(item, dict) and 'path' in item:
                print(item['path'])
    elif isinstance(data, dict):
        # Support {projects: [...]} wrapper
        for key in ('projects', 'paths', 'dirs'):
            if key in data and isinstance(data[key], list):
                for item in data[key]:
                    if isinstance(item, str):
                        print(item)
                    elif isinstance(item, dict) and 'path' in item:
                        print(item['path'])
                break
except Exception:
    pass
" "$PROJECTS_FILE" 2>/dev/null)

  FIRST=true
  while IFS= read -r proj_path; do
    [ -z "$proj_path" ] && continue
    DC_FILE=""
    if [ -f "$proj_path/docker-compose.yml" ]; then
      DC_FILE="$proj_path/docker-compose.yml"
    elif [ -f "$proj_path/docker-compose.yaml" ]; then
      DC_FILE="$proj_path/docker-compose.yaml"
    fi
    if [ -n "$DC_FILE" ]; then
      # Extract service names from compose file
      SERVICES=$(grep -E '^\s+\w+:' "$DC_FILE" 2>/dev/null | grep -v '#' | sed 's/://; s/^[[:space:]]*//')
      if [ -n "$SERVICES" ]; then
        SVC_ARRAY="["
        SVC_FIRST=true
        while IFS= read -r svc; do
          [ -z "$svc" ] && continue
          svc="${svc//\"/\\\"}"
          [ "$SVC_FIRST" = true ] && SVC_FIRST=false || SVC_ARRAY+=", "
          SVC_ARRAY+="\"$svc\""
        done <<< "$SERVICES"
        SVC_ARRAY+="]"
        [ "$FIRST" = true ] && FIRST=false || COMPOSE_JSON+=","
        COMPOSE_JSON+=$(printf '\n    {"path": "%s", "services": %s}' "$DC_FILE" "$SVC_ARRAY")
      fi
    fi
  done <<< "$PATHS"
fi
COMPOSE_JSON+=$'\n  ]'

# --- Assemble final JSON ---
echo "{"
echo "  \"running\": $RUNNING_JSON,"
echo "  \"dockerContainers\": $DOCKER_JSON,"
echo "  \"composeFiles\": $COMPOSE_JSON"
echo "}"

exit 0
