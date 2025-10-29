#!/usr/bin/env bash
# Create a new Firefox profile and apply Arkenfox user.js

set -euo pipefail

echo "=== Arkenfox Firefox Profile Setup ==="

# Step 1: Define variables
RANDOM_ID=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)
PROFILE_NAME="arkenfox_${RANDOM_ID}"
PROFILE_DIR_BASE="$HOME/.mozilla/firefox"

# Step 2: Ensure Firefox exists
if ! command -v firefox >/dev/null 2>&1; then
    echo "Error: Firefox not found in PATH."
    exit 1
fi

# Step 3: Create a new Firefox profile
echo "Creating a new Firefox profile named: $PROFILE_NAME"

if firefox --headless -CreateProfile "$PROFILE_NAME" >/dev/null 2>&1; then
    echo "Profile created via Firefox CLI."
else
    echo "Firefox CLI profile creation failed, creating manually..."
    mkdir -p "$PROFILE_DIR_BASE"
    PROFILE_PATH="$PROFILE_DIR_BASE/${RANDOM_ID}.${PROFILE_NAME}"
    mkdir -p "$PROFILE_PATH"
    cat >> "$PROFILE_DIR_BASE/profiles.ini" <<EOF

[$PROFILE_NAME]
Name=$PROFILE_NAME
IsRelative=1
Path=${RANDOM_ID}.${PROFILE_NAME}
EOF
fi

# Step 4: Find the new profile directory
PROFILE_DIR=$(grep -A 1 "\[$PROFILE_NAME\]" "$PROFILE_DIR_BASE/profiles.ini" | grep '^Path=' | cut -d= -f2)
PROFILE_DIR="$PROFILE_DIR_BASE/$PROFILE_DIR"

if [ ! -d "$PROFILE_DIR" ]; then
    echo "Error: Could not determine profile directory."
    exit 1
fi

echo "Profile directory: $PROFILE_DIR"

# Step 5: Download Arkenfox
echo "Downloading Arkenfox user.js..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
curl -sLO https://github.com/arkenfox/user.js/archive/refs/heads/master.tar.gz
tar -xzf master.tar.gz --strip-components=1

# Step 6: Copy files
cp user.js "$PROFILE_DIR/"
cp prefsCleaner.sh "$PROFILE_DIR/"
cp updater.sh "$PROFILE_DIR/"
echo "Copied Arkenfox files to $PROFILE_DIR"

# Step 7: Apply updater
cd "$PROFILE_DIR"
bash updater.sh || echo "Warning: updater.sh failed (may not be critical)."

# Step 8: Cleanup
rm -rf "$TMP_DIR"

# Step 9: Output summary
echo
echo "=== Done ==="
echo "New Firefox profile created and hardened with Arkenfox."
echo "Profile name: $PROFILE_NAME"
echo "Profile path: $PROFILE_DIR"
echo
echo "Launch Firefox with:"
echo "  firefox -P \"$PROFILE_NAME\""
echo
echo "If Firefox doesn't open, run:"
echo "  firefox --ProfileManager"
echo
echo "To verify, open about:config in that profile."
