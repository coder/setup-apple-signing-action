#!/usr/bin/env bash
# Builds rcodesign with PKCS#11 support from indygreg/apple-platform-rs, with
# pkcs11-single-init.patch applied.
#
# Environment:
#   RCODESIGN_REV   Git revision to build.
#   RUST_TOOLCHAIN  Rust toolchain version to build with.
#
# Sets the step outputs path and sha256 for the built binary.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
retry="$here/../scripts/retry.sh"

: "${RCODESIGN_REV:?}" "${RUST_TOOLCHAIN:?}" "${RUNNER_TEMP:?}" "${GITHUB_OUTPUT:?}"

if [[ "$(uname -s)" != "Linux" ]]; then
	echo "::error::This action only supports Linux runners." >&2
	exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
	echo "::error::This action needs rustup on the runner." >&2
	exit 1
fi
rustup toolchain install --profile minimal "$RUST_TOOLCHAIN"
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"

src="$RUNNER_TEMP/apple-platform-rs"
rm -rf "$src"
git init -q "$src"
"$retry" git -C "$src" fetch -q --depth 1 https://github.com/indygreg/apple-platform-rs.git "$RCODESIGN_REV"
git -C "$src" checkout -q FETCH_HEAD
git -C "$src" apply "$here/pkcs11-single-init.patch"

root="$RUNNER_TEMP/rcodesign"
rm -rf "$root"
"$retry" cargo "+$RUST_TOOLCHAIN" install \
	--locked \
	--path "$src/apple-codesign" \
	--features pkcs11 \
	--bin rcodesign \
	--root "$root"

bin="$root/bin/rcodesign"
sha256="$(sha256sum "$bin" | cut -d ' ' -f 1)"
{
	echo "path=$bin"
	echo "sha256=$sha256"
} >>"$GITHUB_OUTPUT"
