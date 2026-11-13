#!/usr/bin/env bash
# gen-release-keys.sh — generate INIM release signing keys ON YOUR OWN MACHINE.
#
# Creates:
#   1. an Android APK signing keystore (PKCS12, RSA 4096)
#   2. a minisign key pair for signing release manifests/checksums
#   3. a passphrase-encrypted backup archive (age) of both private keys
#
# Run it only on a computer you control. Do not run it in CI, in a shared
# environment, or inside any assistant session. It never prints passwords.
# Keystore and minisign prompts ask for passphrases interactively.
#
# Requirements: keytool (JDK), minisign, age, tar, sha256sum
# Usage: ./gen-release-keys.sh [output-dir]      (default: ~/inim-release-keys)

set -euo pipefail

OUT="${1:-$HOME/inim-release-keys}"

for tool in keytool minisign age tar sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done

if [ -e "$OUT" ] && [ -n "$(ls -A "$OUT" 2>/dev/null)" ]; then
  echo "Refusing to use non-empty directory: $OUT" >&2
  exit 1
fi

umask 077
mkdir -p "$OUT"

echo "== 1/3 APK signing keystore =="
keytool -genkeypair -v \
  -keystore "$OUT/inim-release.p12" \
  -storetype PKCS12 \
  -alias inim-release \
  -keyalg RSA -keysize 4096 \
  -validity 10000

echo
echo "== 2/3 Manifest signing key (minisign) =="
minisign -G -p "$OUT/inim-manifest.pub" -s "$OUT/inim-manifest.key"

echo
echo "== 3/3 Encrypted backup (age, passphrase) =="
echo "Choose a passphrase for the backup. Do not store it next to the backup file."
tar -C "$OUT" -cf - inim-release.p12 inim-manifest.key | age -p -o "$OUT/inim-keys-backup.tar.age"

echo
echo "== Fingerprints (publish these in several independent places) =="
echo "APK certificate (SHA-256):"
keytool -list -v -keystore "$OUT/inim-release.p12" -alias inim-release 2>/dev/null | grep -m1 "SHA256:" || true
echo "Manifest public key:"
cat "$OUT/inim-manifest.pub"
echo "Manifest public key file SHA-256:"
sha256sum "$OUT/inim-manifest.pub"

echo
echo "Done. Output directory: $OUT"
echo "Next steps:"
echo "  1. Copy ONLY $OUT/inim-keys-backup.tar.age to your server (e.g. scp)."
echo "  2. Keep a second encrypted copy in a different physical place."
echo "  3. Test a restore: age -d inim-keys-backup.tar.age | tar -tf -"
echo "  4. Keep the unencrypted .p12 and .key files only on this computer."
