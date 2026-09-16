#!/bin/bash
# Create once; keep the private key in the login keychain across rebuilds.
set -euo pipefail
IDENTITY='Just Pure Paste Local Development'
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$IDENTITY\""; then
    printf 'Development identity ready: %s\n' "$IDENTITY"
    exit 0
fi
# Do not silently replace an existing certificate: that would lose TCC identity.
if security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
    echo 'Existing development certificate is not a valid signing identity. Repair its private key/trust in Keychain Access; do not regenerate it.' >&2
    exit 1
fi
umask 077
SIGNING_TEMP="$(mktemp -d)"
trap 'rm -rf "$SIGNING_TEMP"' EXIT
cat > "$SIGNING_TEMP/openssl.cnf" <<CONFIG
[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no
[subject]
CN = $IDENTITY
[extensions]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIG
openssl req -new -newkey rsa:2048 -x509 -sha256 -nodes -days 3650 \
    -config "$SIGNING_TEMP/openssl.cnf" \
    -keyout "$SIGNING_TEMP/key.pem" -out "$SIGNING_TEMP/cert.pem" 2>/dev/null
SIGNING_PASSWORD="$(openssl rand -hex 24)"
printf '%s' "$SIGNING_PASSWORD" > "$SIGNING_TEMP/password"
openssl pkcs12 -export -inkey "$SIGNING_TEMP/key.pem" -in "$SIGNING_TEMP/cert.pem" \
    -name "$IDENTITY" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -passout "file:$SIGNING_TEMP/password" -out "$SIGNING_TEMP/identity.p12"
security import "$SIGNING_TEMP/identity.p12" -k "$KEYCHAIN" -P "$SIGNING_PASSWORD" -T /usr/bin/codesign
# User-level trust, restricted to code signing; no system-wide trust changes.
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$SIGNING_TEMP/cert.pem"
security find-identity -v -p codesigning "$KEYCHAIN" | grep -F "\"$IDENTITY\""
printf 'Development identity ready: %s\n' "$IDENTITY"
