#!/usr/bin/env bash
# Create a new Firefox profile and apply Arkenfox user.js
# Works for both Flatpak and system Firefox
# Non-interactive, reliable, and does not modify existing profiles

set -euo pipefail

echo "=== Arkenfox Firefox Profile Setup ==="

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect Firefox base directory
if [ -d "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" ]; then
    PROFILE_BASE="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    FIREFOX_CMD="flatpak run org.mozilla.firefox"
    echo "Detected Flatpak Firefox."
elif [ -d "$HOME/.mozilla/firefox" ]; then
    PROFILE_BASE="$HOME/.mozilla/firefox"
    FIREFOX_CMD="firefox"
    echo "Detected system Firefox."
else
    echo "Error: Could not find Firefox profile directory."
    exit 1
fi

# Create new profile
PROFILE_NAME="${1:-}"

if [[ -z "$PROFILE_NAME" ]]; then
    echo "No profile name provided, generating one..."
    RANDOM_ID=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8 || true)
    [ -z "$RANDOM_ID" ] && RANDOM_ID=$RANDOM
    PROFILE_NAME="arkenfox_${RANDOM_ID}"
fi

echo "Using profile name: $PROFILE_NAME"

echo "Creating new Firefox profile: $PROFILE_NAME"
$FIREFOX_CMD --headless -CreateProfile "$PROFILE_NAME" >/dev/null 2>&1

# Step 3: Wait for Firefox to register profile in profiles.ini
echo "Waiting for Firefox to register profile..."
for i in {1..10}; do
    PROFILE_PATH=$(grep -A 1 "\[$PROFILE_NAME\]" "$PROFILE_BASE/profiles.ini" | grep '^Path=' | cut -d= -f2 | tail -n1 || true)
    [ -n "${PROFILE_PATH:-}" ] && break
    sleep 1
done

# Step 4: Detect exact profile directory (robust)
if [ -n "${PROFILE_PATH:-}" ]; then
    PROFILE_DIR="$PROFILE_BASE/$PROFILE_PATH"
else
    PROFILE_DIR=$(find "$PROFILE_BASE" -maxdepth 1 -type d -name "*.$PROFILE_NAME" -print -quit || true)
fi

# If still not found, pick the most recently created subfolder matching arkenfox_*
if [ -z "$PROFILE_DIR" ] || [ ! -d "$PROFILE_DIR" ]; then
    PROFILE_DIR=$(find "$PROFILE_BASE" -maxdepth 1 -type d -name "*.arkenfox_*" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2)
fi

if [ -z "$PROFILE_DIR" ] || [ ! -d "$PROFILE_DIR" ]; then
    echo "Error: Could not locate profile directory for $PROFILE_NAME."
    echo "Existing profiles:"
    grep '^\[.*\]' "$PROFILE_BASE/profiles.ini" || true
    exit 1
fi

echo "Profile directory detected: $PROFILE_DIR"

# Step 5: Download latest Arkenfox repo
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
echo "Downloading Arkenfox user.js..."
curl -LO https://github.com/arkenfox/user.js/archive/refs/heads/master.tar.gz
tar -xzf master.tar.gz --strip-components=1

# Step 6: Copy Arkenfox files to profile directory
cp user.js "$PROFILE_DIR/"
cp prefsCleaner.sh "$PROFILE_DIR/"
cp updater.sh "$PROFILE_DIR/"
echo "Copied Arkenfox files to $PROFILE_DIR"

# Overrides
OVERRIDES="$BASE_DIR/user-overrides.js"

if [[ -f "$OVERRIDES" ]]; then
    echo "Found user-overrides.js in base directory"
    cp "$OVERRIDES" "$PROFILE_DIR/"
else
    echo "No local user-overrides.js found — continuing..."
fi


# Step 7: Apply user.js (non-interactive)
cd "$PROFILE_DIR"
./updater.sh -s
echo "Arkenfox configuration applied."

# Step 8: Cleanup temporary files
rm -rf "$TMP_DIR"

# Step 9: Summary
echo
echo "=== Done ==="
echo "New Firefox profile created and hardened with Arkenfox."
echo "Profile name: $PROFILE_NAME"
echo "Profile path: $PROFILE_DIR"
echo
echo "To start Firefox with this profile:"
echo "  $FIREFOX_CMD -P \"$PROFILE_NAME\""
echo
echo "To verify, open about:config and check '_user.js.parrot' = SUCCESS: No no he's not dead, he's, he's restin'!"
