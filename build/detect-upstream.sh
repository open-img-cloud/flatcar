#!/usr/bin/env bash
# Prints the current Flatcar Container Linux Stable version on stdout
# (e.g. 4757.2.3), read from the channel's version.txt. The version only
# counts once the signed digests of its OpenStack image are published, so a
# half-uploaded release is not picked up.
# Runs in the upstream-watch reusable workflow: portable bash + curl + grep.
set -euo pipefail

UA='openimages.cloud-watch'
BASE='https://stable.release.flatcar-linux.net/amd64-usr'

v=$(curl -fsSL -A "$UA" "$BASE/current/version.txt" | sed -n 's/^FLATCAR_VERSION=//p')
if [[ ! "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::no FLATCAR_VERSION in $BASE/current/version.txt (got '$v')" >&2
  exit 1
fi
for img in openstack; do
  if ! curl -fsSL -A "$UA" "$BASE/$v/flatcar_production_${img}_image.img.DIGESTS.asc" | grep -q 'BEGIN PGP SIGNATURE'; then
    echo "::error::Flatcar $v has no signed digests for the $img image yet" >&2
    exit 1
  fi
done
printf '%s\n' "$v"
