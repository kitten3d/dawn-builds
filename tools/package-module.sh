#!/usr/bin/env bash
#
# Packages module/ into dawn-module-<version>.tar.gz for release upload,
# byte-deterministically (fixed sort/owner/mtime, gzip -n) so the SRI
# integrity the registry pins is stable across machines and reruns.
# Prints the hex sha256 and the SRI integrity string.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module_dir="${repo_root}/module"

version="$(grep -oE 'version = "[^"]+"' "${module_dir}/MODULE.bazel" | head -n1 | cut -d'"' -f2)"
if [ -z "${version}" ]; then
    echo "error: could not read version from ${module_dir}/MODULE.bazel" >&2
    exit 1
fi

if grep -qE '"[a-z0-9_]+": ""' "${module_dir}/extensions.bzl"; then
    echo "error: unpinned sha256 in ${module_dir}/extensions.bzl; run the" >&2
    echo "build-dawn workflow and pin _SHA256S before packaging" >&2
    exit 1
fi

prefix="dawn-module-${version}"
tarball="${repo_root}/${prefix}.tar.gz"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

mkdir -p "${workdir}/${prefix}"
cp -a "${module_dir}/." "${workdir}/${prefix}/"

tar \
    --format=gnu \
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
