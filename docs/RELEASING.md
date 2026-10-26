# Releasing Promptera

## Versioning

1. Update the version in the release command or tag, for example `v1.2.0`.
2. Push a tag:

   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```

The **Release** workflow builds the app, runs the tests, creates the DMG/ZIP,
generates the Sparkle appcast and uploads everything to the GitHub release.

The version baked into `Info.plist` comes from `PROMPTERA_VERSION` (the tag,
without the leading `v`) and `PROMPTERA_BUILD` (the workflow run number).

## Sparkle auto-updates

Promptera uses [Sparkle 2](https://sparkle-project.org). The app reads the
appcast from:

```text
https://github.com/lucasrafaldini/Promptera/releases/latest/download/appcast.xml
```

### One-time key setup

1. Generate an Ed25519 key pair with the Sparkle tools:

   ```bash
   ./bin/generate_keys
   ```

   Keep the private key secret. The public key goes into
   `SUPublicEDKey` in `scripts/build_app.sh`.

2. Add the private key as a repository secret named `SPARKLE_PRIVATE_KEY`.
   The value is the base64 key printed by `generate_keys` (the same format
   accepted by `generate_appcast --ed-key-file -`).

3. If the secret is missing, the workflow still publishes the DMG/ZIP but
   skips `appcast.xml` and prints a warning. Auto-updates will not work until
   the secret is configured.

The workflow downloads the matching Sparkle release tools, signs the ZIP and
uploads `appcast.xml` to the release. Because the feed URL points to
`releases/latest`, clients always see the newest appcast.

## Code signing and notarization

The default build uses an ad-hoc signature so it runs locally. Sparkle only
installs updates signed by the same Developer ID, so public releases should be
signed and notarized.

Add these repository secrets:

| Secret | Purpose |
| --- | --- |
| `MACOS_CERTIFICATE` | Base64-encoded Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the `.p12` |
| `KEYCHAIN_PASSWORD` | Temporary keychain password used in CI |
| `APPLE_ID` | Apple ID used by `notarytool` |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool` |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

Then run:

```bash
./scripts/sign_app.sh          # signs the app + embedded Sparkle framework
./scripts/notarize.sh <dmg>    # notarizes and staples the DMG
```

The release workflow calls these scripts automatically when the secrets are
present; otherwise it falls back to the ad-hoc signature.

## Local release smoke test

```bash
PROMPTERA_VERSION=v1.2.0 PROMPTERA_BUILD=42 ./scripts/build_app.sh
codesign --verify --verbose build/Promptera.app
open build/Promptera.app
```
