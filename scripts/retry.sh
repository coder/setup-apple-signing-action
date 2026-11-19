#!/usr/bin/env bash
# Runs a command, retrying it up to three times with a growing delay.
#
# Usage: retry.sh command [args...]
set -euo pipefail

max_attempts=3
attempt=1
until "$@"; do
	if ((attempt >= max_attempts)); then
		echo "::error::Command failed after $max_attempts attempts: $*" >&2
		exit 1
	fi
	delay=$((2 ** attempt))
	echo "Attempt $attempt/$max_attempts failed, retrying in ${delay}s." >&2
	sleep "$delay"
	attempt=$((attempt + 1))
done
