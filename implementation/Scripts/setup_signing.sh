#!/usr/bin/env bash
set -euo pipefail

# Create a local self-signed code-signing identity called
# "FlowLite Local Signer" and import it into the user's login keychain.
#
# Why: macOS attributes Accessibility / Input Monitoring / Microphone
# permission to a code-signing identity + designated requirement.
# An ad-hoc signature (the default codesign behavior) changes its
# code requirement every rebuild, so macOS forgets your permissions
# and you have to re-grant Accessibility every time you recompile.
#
# A stable self-signed cert keeps the designated requirement the same
# across rebuilds, so the permissions stick.
#
# Run this once. Then build_app.sh will pick the identity up automatically.

SIGN_NAME="FlowLite Local Signer"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP_DIR="$(mktemp -d -t flowlite-signing-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if security find-certificate -c "$SIGN_NAME" >/dev/null 2>&1; then
  echo "Identity '$SIGN_NAME' already in keychain. Nothing to do."
  exit 0
fi

cat > "$TMP_DIR/csr.conf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = FlowLite Local Signer
O = FlowLite Local
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 \
  -keyout "$TMP_DIR/key.pem" \
  -out "$TMP_DIR/cert.pem" \
  -days 3650 -nodes \
  -config "$TMP_DIR/csr.conf" >/dev/null 2>&1

# Use -legacy so macOS Security framework can verify the PKCS12 MAC.
openssl pkcs12 -export -legacy \
  -out "$TMP_DIR/identity.p12" \
  -inkey "$TMP_DIR/key.pem" \
  -in "$TMP_DIR/cert.pem" \
  -name "$SIGN_NAME" \
  -passout pass:flowlite

security import "$TMP_DIR/identity.p12" \
  -k "$KEYCHAIN" \
  -P flowlite \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -A

cat <<EOF

Imported identity '$SIGN_NAME' into:
  $KEYCHAIN

Next:
  bash Scripts/build_app.sh
will use this identity automatically. The designated requirement is:
  identifier "com.flowlite.app"

The first time you grant Accessibility / Input Monitoring to the new
signed binary, macOS stores those permissions against this identity,
and they persist across rebuilds.
EOF
