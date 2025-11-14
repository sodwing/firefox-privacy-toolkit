PROFILE_NAME="${1:-}"

if [[ -z "$PROFILE_NAME" ]]; then
    echo "No profile name provided, generating one..."
    RANDOM_ID=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8 || true)
    [ -z "$RANDOM_ID" ] && RANDOM_ID=$RANDOM
    PROFILE_NAME="arkenfox_${RANDOM_ID}"
fi

bash arkenfox-new-profile.sh "$PROFILE_NAME"
echo
bash install_ublock.sh "$PROFILE_NAME"
