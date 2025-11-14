#!/usr/bin/env bash
# Automatically install uBlock Origin into a chosen Firefox profile (user only)
# Clean display: profile numbers start from 1, only names shown

set -e

echo "=== uBlock Origin Installer for Firefox (User Profile) ==="

# Detect Firefox binary
FIREFOX_BIN=$(command -v firefox || true)
if [ -z "$FIREFOX_BIN" ]; then
  echo "Firefox not found! Please install Firefox first."
  exit 1
fi

# Locate profiles.ini
PROFILES_DIR="$HOME/.mozilla/firefox"
PROFILES_INI="$PROFILES_DIR/profiles.ini"

if [ ! -f "$PROFILES_INI" ]; then
  echo "No Firefox profiles found."
  echo "→ Launch Firefox once to generate a profile, then re-run this script."
  exit 1
fi

# --- Parse profiles properly (handles multiple [ProfileX] sections) ---
PROFILE_NAMES=()
PROFILE_PATHS=()
CURRENT_NAME=""
CURRENT_PATH=""

while IFS= read -r line; do
  case "$line" in
    Name=*)
      CURRENT_NAME="${line#Name=}"
      ;;
    Path=*)
      CURRENT_PATH="${line#Path=}"
      ;;
    \[*\])
      if [[ -n "$CURRENT_NAME" && -n "$CURRENT_PATH" ]]; then
        PROFILE_NAMES+=("$CURRENT_NAME")
        PROFILE_PATHS+=("$CURRENT_PATH")
      fi
      CURRENT_NAME=""
      CURRENT_PATH=""
      ;;
  esac
done < "$PROFILES_INI"

if [[ -n "$CURRENT_NAME" && -n "$CURRENT_PATH" ]]; then
  PROFILE_NAMES+=("$CURRENT_NAME")
  PROFILE_PATHS+=("$CURRENT_PATH")
fi

if [ ${#PROFILE_PATHS[@]} -eq 0 ]; then
  echo "❌ No Firefox profiles found in $PROFILES_INI"
  echo "→ Launch Firefox once to generate one, then re-run this script."
  exit 1
fi

# --- Determine which profile to use ---
if [ -n "$1" ]; then
  # Argument provided: find matching profile
  PROFILE_ARG="$1"
  INDEX=-1
  for i in "${!PROFILE_NAMES[@]}"; do
    if [ "${PROFILE_NAMES[$i]}" = "$PROFILE_ARG" ]; then
      INDEX=$i
      break
    fi
  done

  if [ $INDEX -eq -1 ]; then
    echo "❌ Profile '$PROFILE_ARG' not found."
    echo "Available profiles:"
    for ((n=0; n<${#PROFILE_NAMES[@]}; n++)); do
      echo "  ${PROFILE_NAMES[$n]}"
    done
    exit 1
  fi
else
  # No argument: prompt user
  echo "Available Firefox profiles:"
  echo
  for ((n=0; n<${#PROFILE_PATHS[@]}; n++)); do
    num=$((n+1))
    echo "[$num] ${PROFILE_NAMES[$n]}"
  done
  echo
  read -rp "Enter the number of the profile to install uBlock Origin: " CHOICE

  # Convert to zero-based index
  INDEX=$((CHOICE-1))
  if [[ -z "${PROFILE_PATHS[$INDEX]}" || $CHOICE -le 0 ]]; then
    echo "Invalid choice."
    exit 1
  fi
fi

PROFILE_FULL_PATH="$PROFILES_DIR/${PROFILE_PATHS[$INDEX]}"
EXT_DIR="$PROFILE_FULL_PATH/extensions"
mkdir -p "$EXT_DIR"

echo
echo "Installing uBlock Origin into profile: ${PROFILE_NAMES[$INDEX]}"
echo "Profile path: $PROFILE_FULL_PATH"

# Download uBlock Origin latest XPI
UBLOCK_URL="https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
TEMP_FILE=$(mktemp /tmp/ublock_origin_XXXX.xpi)
EXTENSION_ID="uBlock0@raymondhill.net"

echo "Downloading uBlock Origin..."
curl -sSL "$UBLOCK_URL" -o "$TEMP_FILE"

# Copy to extensions directory
cp "$TEMP_FILE" "$EXT_DIR/$EXTENSION_ID.xpi"

echo
echo "✅ uBlock Origin installed successfully!"
echo "Location: $EXT_DIR/$EXTENSION_ID.xpi"
echo
echo "Restart Firefox to activate the extension."

