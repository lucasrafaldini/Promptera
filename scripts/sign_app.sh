#!/bin/bash
#
# Signs Promptera.app (and its embedded Sparkle framework) with a Developer ID
# certificate so releases can be notarized and Sparkle can install updates.
#
# Usage:
#   CODESIGN_IDENTITY="Developer ID Application: ..." ./scripts/sign_app.sh [path/to/Promptera.app]
#
# In CI, provide the certificate through environment variables instead:
#   MACOS_CERTIFICATE          base64-encoded Developer ID Application .p12
#   MACOS_CERTIFICATE_PASSWORD password for the .p12
#   KEYCHAIN_PASSWORD          password for the temporary CI keychain
#
# If no identity and no certificate are available, the script exits with an
# error. The release workflow checks for the secrets first and keeps the
# ad-hoc signature from build_app.sh when they are missing.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$DIR/build/Promptera.app}"
IDENTITY="${CODESIGN_IDENTITY:-}"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found: $APP_PATH" >&2
    echo "   Run ./scripts/build_app.sh first." >&2
    exit 1
fi

KEYCHAIN_PATH=""
CERT_PATH=""

cleanup() {
    if [ -n "$KEYCHAIN_PATH" ] && [ -f "$KEYCHAIN_PATH" ]; then
        security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
    fi
    if [ -n "$CERT_PATH" ] && [ -f "$CERT_PATH" ]; then
        rm -f "$CERT_PATH"
    fi
}
trap cleanup EXIT

# Import the certificate into an isolated keychain when running in CI.
if [ -z "$IDENTITY" ] && [ -n "${MACOS_CERTIFICATE:-}" ]; then
    if [ -z "${MACOS_CERTIFICATE_PASSWORD:-}" ]; then
        echo "❌ MACOS_CERTIFICATE_PASSWORD is required to import the certificate." >&2
        exit 1
    fi

    KEYCHAIN_PATH="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/promptera-signing.keychain-db"
    CERT_PATH="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/promptera-certificate.p12"
    KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(openssl rand -base64 24)}"

    echo "🔐 Creating temporary signing keychain..."
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    if ! printf '%s' "$MACOS_CERTIFICATE" | base64 --decode > "$CERT_PATH" 2>/dev/null; then
        printf '%s' "$MACOS_CERTIFICATE" | base64 -D > "$CERT_PATH"
    fi

    security import "$CERT_PATH" \
        -P "$MACOS_CERTIFICATE_PASSWORD" \
        -A -t cert -f pkcs12 \
        -k "$KEYCHAIN_PATH" >/dev/null

    security list-keychain -d user -s "$KEYCHAIN_PATH"
    security set-key-partition-list \
        -S apple-tool:,apple: \
        -s -k "$KEYCHAIN_PASSWORD" \
        "$KEYCHAIN_PATH" >/dev/null

    IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" \
        | grep "Developer ID Application" \
        | head -n 1 \
        | sed -E 's/.*"(.*)"/\1/' || true)"
fi

if [ -z "$IDENTITY" ]; then
    echo "❌ No Developer ID Application identity found." >&2
    echo "   Set CODESIGN_IDENTITY, or provide MACOS_CERTIFICATE + MACOS_CERTIFICATE_PASSWORD." >&2
    exit 1
fi

echo "🔏 Signing with: $IDENTITY"

sign() {
    local target="$1"
    echo "   • $(basename "$target")"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$target"
}

FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
SPARKLE_DIR="$FRAMEWORKS_DIR/Sparkle.framework"

if [ -d "$SPARKLE_DIR" ]; then
    echo "🧩 Signing Sparkle framework components..."
    SPARKLE_B="$SPARKLE_DIR/Versions/B"

    # Nested code must be signed before the framework that contains it.
    for xpc in "$SPARKLE_B"/XPCServices/*.xpc; do
        [ -e "$xpc" ] && sign "$xpc"
    done
    if [ -d "$SPARKLE_B/Updater.app" ]; then
        sign "$SPARKLE_B/Updater.app"
    fi
    if [ -f "$SPARKLE_B/Autoupdate" ]; then
        sign "$SPARKLE_B/Autoupdate"
    fi

    sign "$SPARKLE_DIR"
fi

echo "📱 Signing app bundle..."
sign "$APP_PATH"

echo "✅ Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "✅ Signed: $APP_PATH"
