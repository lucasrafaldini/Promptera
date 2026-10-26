#!/bin/bash
#
# Notarizes a Promptera release artifact with Apple's notary service.
#
# Usage:
#   APPLE_ID="you@example.com" \
#   APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
#   APPLE_TEAM_ID="ABCDE12345" \
#   ./scripts/notarize.sh build/Promptera-v1.2.0.zip
#
# Accepts a .zip, .dmg or .app. ZIP archives are re-created after the enclosed
# app is stapled, so the archive that ships also contains the notarization
# ticket. DMGs are notarized and stapled directly. Apps are zipped, submitted
# and stapled in place.
#
# You can also use a stored notarytool profile instead of the three variables:
#   NOTARY_PROFILE="promptera" ./scripts/notarize.sh <artifact>

set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <path-to-app|dmg|zip>" >&2
    exit 1
fi
if [ ! -e "$TARGET" ]; then
    echo "❌ Artifact not found: $TARGET" >&2
    exit 1
fi

TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/promptera-notarize.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

submit() {
    local artifact="$1"

    if [ -n "${NOTARY_PROFILE:-}" ]; then
        xcrun notarytool submit "$artifact" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
        return
    fi

    : "${APPLE_ID:?APPLE_ID is required (or set NOTARY_PROFILE)}"
    : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required (or set NOTARY_PROFILE)}"
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required (or set NOTARY_PROFILE)}"

    xcrun notarytool submit "$artifact" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait
}

staple() {
    local artifact="$1"
    echo "📎 Stapling $(basename "$artifact")..."
    xcrun stapler staple "$artifact"
    xcrun stapler validate "$artifact"
}

case "$TARGET" in
    *.app)
        echo "📦 Zipping app for notarization..."
        ZIP_PATH="$WORK_DIR/$(basename "$TARGET" .app).zip"
        ditto -c -k --keepParent "$TARGET" "$ZIP_PATH"
        submit "$ZIP_PATH"
        staple "$TARGET"
        ;;

    *.dmg)
        echo "💿 Submitting DMG..."
        submit "$TARGET"
        staple "$TARGET"
        ;;

    *.zip)
        echo "🗜️  Extracting app from ZIP..."
        ditto -x -k "$TARGET" "$WORK_DIR/unzipped"
        APP_PATH="$(find "$WORK_DIR/unzipped" -maxdepth 2 -name '*.app' -type d | head -n 1)"

        if [ -z "$APP_PATH" ]; then
            echo "❌ No .app bundle found inside $TARGET" >&2
            exit 1
        fi

        echo "📨 Submitting ZIP..."
        submit "$TARGET"

        # Staple the app, then rebuild the ZIP so the shipped archive contains
        # the notarization ticket (ZIP files themselves cannot be stapled).
        staple "$APP_PATH"
        rm -f "$TARGET"
        ditto -c -k --keepParent "$APP_PATH" "$TARGET"
        echo "✅ Re-created $TARGET with the stapled app."
        ;;

    *)
        echo "❌ Unsupported artifact type: $TARGET (expected .app, .dmg or .zip)" >&2
        exit 1
        ;;
esac

echo "✅ Notarization complete: $TARGET"
