#!/bin/bash
# Cortex — Schedule Automated Tasks
# Sets up periodic auto-improve and re-discover using launchd (macOS) or cron (Linux).
#
# Usage: schedule-autorun.sh [setup|remove|status]
#   setup   — Install scheduled tasks
#   remove  — Uninstall scheduled tasks
#   status  — Show current schedule status

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$HOME/.cortex/logs"
DNA_FILE="$HOME/.cortex/developer-dna.json"

# macOS launchd labels
LABEL_IMPROVE="com.cortex.weekly-improve"
LABEL_DISCOVER="com.cortex.monthly-discover"

# Plist paths (macOS)
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_IMPROVE="$PLIST_DIR/${LABEL_IMPROVE}.plist"
PLIST_DISCOVER="$PLIST_DIR/${LABEL_DISCOVER}.plist"

# Monthly discover wrapper script
MONTHLY_WRAPPER="$HOME/.cortex/scripts/monthly-discover-wrapper.sh"

# Detect platform
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

# Create the monthly discover wrapper script
create_monthly_wrapper() {
  mkdir -p "$(dirname "$MONTHLY_WRAPPER")"
  cat > "$MONTHLY_WRAPPER" <<'WRAPPER_EOF'
#!/bin/bash
# Cortex — Monthly Re-Discover Wrapper
# Runs discover-orchestrator.sh, compares with previous DeveloperDNA, and saves new DNA.
set -uo pipefail

WRAPPER_EOF

  # Append variables that need expansion at creation time
  cat >> "$MONTHLY_WRAPPER" <<WRAPPER_VARS
SCRIPT_DIR="$SCRIPT_DIR"
DNA_FILE="$DNA_FILE"
WRAPPER_VARS

  # Append the rest without expansion
  cat >> "$MONTHLY_WRAPPER" <<'WRAPPER_BODY'

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) — Monthly re-discover starting"

# 1. Run discovery
NEW_DNA=$(bash "$SCRIPT_DIR/discover-orchestrator.sh" 2>/dev/null)

if [ -z "$NEW_DNA" ]; then
  echo "ERROR: discover-orchestrator.sh produced no output"
  exit 1
fi

# 2. Save new DNA to a temp file for safe Python consumption
NEW_DNA_TMPFILE=$(mktemp)
echo "$NEW_DNA" > "$NEW_DNA_TMPFILE"

# 3. Compare with existing DNA (using file paths, no shell interpolation into Python)
if [ -f "$DNA_FILE" ]; then
  echo "Comparing with previous DeveloperDNA..."
  python3 - "$DNA_FILE" "$NEW_DNA_TMPFILE" <<'COMPARE_PYTHON'
import json, sys

old_path, new_path = sys.argv[1], sys.argv[2]

try:
    with open(old_path) as f:
        old = json.load(f)
except Exception as e:
    print("  Could not load previous DNA: " + str(e))
    sys.exit(0)

try:
    with open(new_path) as f:
        new = json.load(f)
except Exception as e:
    print("  Could not parse new DNA: " + str(e))
    sys.exit(0)

old_projects = set(p.get("name", "") for p in old.get("projects", []))
new_projects = set(p.get("name", "") for p in new.get("projects", []))
added = new_projects - old_projects
removed = old_projects - new_projects

print("  Projects: {} -> {}".format(len(old_projects), len(new_projects)))
if added:
    print("    New:     " + ", ".join(sorted(added)))
if removed:
    print("    Removed: " + ", ".join(sorted(removed)))
if not added and not removed:
    print("    No changes")

# Compare integrations (check detected status)
old_detected = set(k for k, v in old.get("integrations", {}).items() if isinstance(v, dict) and v.get("detected"))
new_detected = set(k for k, v in new.get("integrations", {}).items() if isinstance(v, dict) and v.get("detected"))
added_int = new_detected - old_detected
removed_int = old_detected - new_detected

print("  Integrations: {} -> {}".format(len(old_detected), len(new_detected)))
if added_int:
    print("    New:     " + ", ".join(sorted(added_int)))
if removed_int:
    print("    Removed: " + ", ".join(sorted(removed_int)))
if not added_int and not removed_int:
    print("    No changes")

old_summary = old.get("summary", {})
new_summary = new.get("summary", {})
if old_summary.get("role") != new_summary.get("role"):
    print("  Role: {} -> {}".format(old_summary.get("role", "unknown"), new_summary.get("role", "unknown")))
if old_summary.get("dominantLanguage") != new_summary.get("dominantLanguage"):
    print("  Dominant language: {} -> {}".format(old_summary.get("dominantLanguage", "unknown"), new_summary.get("dominantLanguage", "unknown")))
COMPARE_PYTHON
else
  echo "No previous DeveloperDNA found — this is the first discovery."
fi

# 4. Save new DNA (move temp file to permanent location)
mv "$NEW_DNA_TMPFILE" "$DNA_FILE"
echo "DeveloperDNA saved to $DNA_FILE"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) — Monthly re-discover complete"
WRAPPER_BODY

  chmod +x "$MONTHLY_WRAPPER"
}

# --- macOS launchd setup ---

setup_macos() {
  mkdir -p "$PLIST_DIR"

  # Task 1: Weekly Auto-Improve — Sunday at 2:00 AM
  cat > "$PLIST_IMPROVE" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL_IMPROVE}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/auto-improve.sh</string>
        <string>${SKILL_DIR}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/weekly-improve.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/weekly-improve.err</string>
</dict>
</plist>
PLIST_EOF

  # Task 2: Monthly Re-Discover — 1st of every month at 3:00 AM
  cat > "$PLIST_DISCOVER" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL_DISCOVER}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${MONTHLY_WRAPPER}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Day</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/monthly-discover.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/monthly-discover.err</string>
</dict>
</plist>
PLIST_EOF

  # Load the agents
  launchctl load "$PLIST_IMPROVE" 2>/dev/null && echo "  Loaded: $LABEL_IMPROVE" || echo "  WARNING: Failed to load $LABEL_IMPROVE (may already be loaded)"
  launchctl load "$PLIST_DISCOVER" 2>/dev/null && echo "  Loaded: $LABEL_DISCOVER" || echo "  WARNING: Failed to load $LABEL_DISCOVER (may already be loaded)"

  echo ""
  echo "Plist files:"
  echo "  $PLIST_IMPROVE"
  echo "  $PLIST_DISCOVER"
  echo ""
  echo "Next scheduled runs:"
  echo "  Weekly Auto-Improve:  Next Sunday at 02:00 AM"
  echo "  Monthly Re-Discover:  1st of next month at 03:00 AM"
}

setup_linux() {
  # Read existing crontab (suppress error if empty)
  EXISTING_CRON=$(crontab -l 2>/dev/null || true)

  # Remove any old cortex-autorun entries
  CLEAN_CRON=$(echo "$EXISTING_CRON" | grep -v '# cortex-autorun' || true)

  # Append new entries
  NEW_CRON="$CLEAN_CRON
0 2 * * 0 /bin/bash ${SCRIPT_DIR}/auto-improve.sh ${SKILL_DIR} >> ${LOG_DIR}/weekly-improve.log 2>> ${LOG_DIR}/weekly-improve.err # cortex-autorun
0 3 1 * * /bin/bash ${MONTHLY_WRAPPER} >> ${LOG_DIR}/monthly-discover.log 2>> ${LOG_DIR}/monthly-discover.err # cortex-autorun"

  # Write back
  if echo "$NEW_CRON" | crontab -; then
    echo "  Crontab updated successfully"
  else
    echo "  ERROR: Failed to update crontab" >&2
    return 1
  fi

  echo ""
  echo "Crontab entries (tagged # cortex-autorun):"
  crontab -l 2>/dev/null | grep '# cortex-autorun' | sed 's/^/  /'
  echo ""
  echo "Next scheduled runs:"
  echo "  Weekly Auto-Improve:  Next Sunday at 02:00 AM"
  echo "  Monthly Re-Discover:  1st of next month at 03:00 AM"
}

# --- Remove ---

remove_macos() {
  local removed=0

  if [ -f "$PLIST_IMPROVE" ]; then
    launchctl unload "$PLIST_IMPROVE" 2>/dev/null
    rm -f "$PLIST_IMPROVE"
    echo "  Removed: $LABEL_IMPROVE"
    removed=$((removed + 1))
  else
    echo "  Not found: $LABEL_IMPROVE (already removed)"
  fi

  if [ -f "$PLIST_DISCOVER" ]; then
    launchctl unload "$PLIST_DISCOVER" 2>/dev/null
    rm -f "$PLIST_DISCOVER"
    echo "  Removed: $LABEL_DISCOVER"
    removed=$((removed + 1))
  else
    echo "  Not found: $LABEL_DISCOVER (already removed)"
  fi

  if [ -f "$MONTHLY_WRAPPER" ]; then
    rm -f "$MONTHLY_WRAPPER"
    echo "  Removed: monthly wrapper script"
  fi

  echo ""
  if [ "$removed" -gt 0 ]; then
    echo "Uninstalled $removed scheduled task(s)."
  else
    echo "No scheduled tasks were installed."
  fi
}

remove_linux() {
  EXISTING_CRON=$(crontab -l 2>/dev/null || true)
  CORTEX_LINES=$(echo "$EXISTING_CRON" | grep -c '# cortex-autorun' || true)

  if [ "$CORTEX_LINES" -eq 0 ]; then
    echo "  No cortex-autorun entries found in crontab."
  else
    CLEAN_CRON=$(echo "$EXISTING_CRON" | grep -v '# cortex-autorun')
    echo "$CLEAN_CRON" | crontab - && echo "  Removed $CORTEX_LINES crontab entry/entries." || echo "  ERROR: Failed to update crontab" >&2
  fi

  if [ -f "$MONTHLY_WRAPPER" ]; then
    rm -f "$MONTHLY_WRAPPER"
    echo "  Removed: monthly wrapper script"
  fi

  echo ""
  echo "Cortex scheduled tasks uninstalled."
}

# --- Status ---

get_last_log_line() {
  local logfile="$1"
  if [ -f "$logfile" ] && [ -s "$logfile" ]; then
    tail -1 "$logfile"
  else
    echo "no runs yet"
  fi
}

status_macos() {
  local improve_status="not installed"
  local discover_status="not installed"
  local improve_next="unknown"
  local discover_next="unknown"

  # Check if plists exist and are loaded
  if [ -f "$PLIST_IMPROVE" ]; then
    if launchctl list 2>/dev/null | grep -q "$LABEL_IMPROVE"; then
      improve_status="active"
      improve_next="Next Sunday at 02:00 AM"
    else
      improve_status="installed but not loaded"
      improve_next="(not loaded)"
    fi
  fi

  if [ -f "$PLIST_DISCOVER" ]; then
    if launchctl list 2>/dev/null | grep -q "$LABEL_DISCOVER"; then
      discover_status="active"
      discover_next="1st of next month at 03:00 AM"
    else
      discover_status="installed but not loaded"
      discover_next="(not loaded)"
    fi
  fi

  echo "Cortex Scheduled Tasks:"
  echo "  Weekly Auto-Improve:   [$improve_status]"
  echo "    Next run: $improve_next"
  echo "    Last log: $(get_last_log_line "$LOG_DIR/weekly-improve.log")"
  echo "  Monthly Re-Discover:   [$discover_status]"
  echo "    Next run: $discover_next"
  echo "    Last log: $(get_last_log_line "$LOG_DIR/monthly-discover.log")"
}

status_linux() {
  local improve_status="not installed"
  local discover_status="not installed"
  local improve_next="unknown"
  local discover_next="unknown"

  EXISTING_CRON=$(crontab -l 2>/dev/null || true)

  if echo "$EXISTING_CRON" | grep -q 'auto-improve.*# cortex-autorun'; then
    improve_status="active"
    improve_next="Next Sunday at 02:00 AM"
  fi

  if echo "$EXISTING_CRON" | grep -q 'monthly-discover.*# cortex-autorun'; then
    discover_status="active"
    discover_next="1st of next month at 03:00 AM"
  fi

  echo "Cortex Scheduled Tasks:"
  echo "  Weekly Auto-Improve:   [$improve_status]"
  echo "    Next run: $improve_next"
  echo "    Last log: $(get_last_log_line "$LOG_DIR/weekly-improve.log")"
  echo "  Monthly Re-Discover:   [$discover_status]"
  echo "    Next run: $discover_next"
  echo "    Last log: $(get_last_log_line "$LOG_DIR/monthly-discover.log")"
}

# --- Main ---

ACTION="${1:-}"

if [ -z "$ACTION" ]; then
  echo "Usage: schedule-autorun.sh [setup|remove|status]"
  echo ""
  echo "  setup   — Install scheduled tasks (launchd on macOS, cron on Linux)"
  echo "  remove  — Uninstall scheduled tasks"
  echo "  status  — Show current schedule status"
  exit 1
fi

PLATFORM=$(detect_platform)

case "$ACTION" in
  setup)
    echo "Setting up Cortex scheduled tasks..."
    echo ""

    # Create log directory
    mkdir -p "$LOG_DIR"
    echo "  Log directory: $LOG_DIR"

    # Create the monthly wrapper script
    create_monthly_wrapper
    echo "  Monthly wrapper: $MONTHLY_WRAPPER"
    echo ""

    case "$PLATFORM" in
      macos)
        echo "Platform: macOS (using launchd)"
        echo ""
        setup_macos
        ;;
      linux)
        echo "Platform: Linux (using cron)"
        echo ""
        setup_linux
        ;;
      *)
        echo "ERROR: Unsupported platform '$(uname -s)'. Only macOS and Linux are supported." >&2
        exit 1
        ;;
    esac

    echo ""
    echo "Logs will be written to:"
    echo "  $LOG_DIR/weekly-improve.log"
    echo "  $LOG_DIR/weekly-improve.err"
    echo "  $LOG_DIR/monthly-discover.log"
    echo "  $LOG_DIR/monthly-discover.err"
    ;;

  remove)
    echo "Removing Cortex scheduled tasks..."
    echo ""

    case "$PLATFORM" in
      macos)  remove_macos ;;
      linux)  remove_linux ;;
      *)
        echo "ERROR: Unsupported platform '$(uname -s)'." >&2
        exit 1
        ;;
    esac
    ;;

  status)
    case "$PLATFORM" in
      macos)  status_macos ;;
      linux)  status_linux ;;
      *)
        echo "ERROR: Unsupported platform '$(uname -s)'." >&2
        exit 1
        ;;
    esac
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'" >&2
    echo "Usage: schedule-autorun.sh [setup|remove|status]" >&2
    exit 1
    ;;
esac
