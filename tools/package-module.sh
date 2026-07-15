#!/usr/bin/env bash
#
# Packages module/ into the wrapper-module source archive for release upload.
#
# The archive is byte-deterministic (fixed sort/owner/mtime, gzip -n) so its
# sha256 / SRI integrity is stable across machines and reruns — the registry's
# source.json pins that integrity. Prints both the hex sha256 and the SRI
# integrity string; copy the SRI value into the registry's source.json.
#
# Output: dawn-module-<version>.tar.gz with a single top-level directory
# dawn-module-<version>/ (this is the strip_prefix the registry must declare).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module_dir="${repo_root}/module"

# Single source of truth for the version: the wrapper module itself.
version="$(grep -oE 'version = "[^"]+"' "${module_dir}/MODULE.bazel" | head -n1 | cut -d'"' -f2)"
if [ -z "${version}" ]; then
    echo "error: could not read version from ${module_dir}/MODULE.bazel" >&2
    exit 1
fi

prefix="dawn-module-${version}"
tarball="${repo_root}/${prefix}.tar.gz"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

# Stage module/ under the stable prefix directory.
mkdir -p "${workdir}/${prefix}"
cp -a "${module_dir}/." "${workdir}/${prefix}/"

# Deterministic tar + gzip: same input bytes -> same archive bytes.
tar \
    --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime='UTC 2026-01-01' \
    -C "${workdir}" \
    -cf - "${prefix}" \
    | gzip -n -9 > "${tarball}"

hex="$(sha256sum "${tarball}" | awk '{print $1}')"
sri="sha256-$(openssl dgst -sha256 -binary "${tarball}" | base64)"

echo "packaged: ${tarball}"
echo "sha256:   ${hex}"
echo "integrity: ${sri}"
