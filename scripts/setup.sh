#!/usr/bin/env bash
# Installs the Google Cloud KMS PKCS#11 library, and writes its configuration
# and the signing certificate to $RUNNER_TEMP/apple-signing.
#
# Environment:
#   CERTIFICATE_PEM  Signing certificate in PEM format.
#   KEY_RING         Resource name of the Cloud KMS key ring that holds the
#                    signing key.
#
# Sets the step outputs certificate-file, pkcs11-library and pkcs11-config.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
retry="$here/retry.sh"

fail() {
	echo "::error::$*" >&2
	exit 1
}

: "${RUNNER_TEMP:?}" "${GITHUB_OUTPUT:?}"

if [[ "$(uname -sm)" != "Linux x86_64" ]]; then
	fail "This action only supports Linux x86_64 runners."
fi
if [[ -z "${CERTIFICATE_PEM:-}" ]]; then
	fail "The certificate-pem input is empty."
fi
if ! openssl x509 -noout -subject -serial -enddate <<<"$CERTIFICATE_PEM"; then
	fail "The certificate-pem input is not a PEM certificate."
fi
if [[ ! "${KEY_RING:-}" =~ ^projects/[^/[:space:]\"]+/locations/[^/[:space:]\"]+/keyRings/[^/[:space:]\"]+$ ]]; then
	fail "The key-ring input must look like projects/PROJECT/locations/LOCATION/keyRings/NAME."
fi

library_version=1.9
library_archive="libkmsp11-${library_version}-linux-amd64"
library_sha256=5397f965073cd5d1e2c43e5148f102f31a7c835902f97eb41c7c9c0f1b876a40
library=/usr/local/lib/libkmsp11.so

dir="$RUNNER_TEMP/apple-signing"
rm -rf "$dir"
mkdir -m 700 "$dir"
umask 077

"$retry" curl -fsSL -o "$dir/$library_archive.tar.gz" \
	"https://github.com/GoogleCloudPlatform/kms-integrations/releases/download/pkcs11-v${library_version}/$library_archive.tar.gz"
echo "$library_sha256  $dir/$library_archive.tar.gz" | sha256sum -c -
tar -xzf "$dir/$library_archive.tar.gz" -C "$dir" --strip-components=1 "$library_archive/libkmsp11.so"
sudo install -m 0755 "$dir/libkmsp11.so" "$library"
rm "$dir/$library_archive.tar.gz" "$dir/libkmsp11.so"

printf '%s\n' "$CERTIFICATE_PEM" >"$dir/certificate.pem"
cat >"$dir/kmsp11_config.yaml" <<CONFIG
---
tokens:
  - key_ring: "$KEY_RING"
CONFIG

{
	echo "certificate-file=$dir/certificate.pem"
	echo "pkcs11-library=$library"
	echo "pkcs11-config=$dir/kmsp11_config.yaml"
} >>"$GITHUB_OUTPUT"
