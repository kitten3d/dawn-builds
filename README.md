# dawn-builds

Artifact factory and wrapper Bazel module for [Dawn](https://dawn.googlesource.com/dawn),
Google's WebGPU implementation, as consumed by the kitten3d engine. The
upstream Linux release is built X11-only (`DAWN_USE_WAYLAND=OFF`), so a native
Wayland `wl_surface` fails Dawn validation, and upstream ships no Linux arm64
build at all. This repo builds a Wayland+X11-enabled static Dawn for Linux
x86-64 and arm64 on Ubuntu 24.04 runners and serves them — alongside the
unchanged upstream macOS/Windows binaries — as a single platform-neutral Bazel
module named `dawn`.

## How the pieces fit

1. **`.github/workflows/build-dawn.yml`** — the artifact factory. Dispatched
   with a Dawn tag + commit, it clones and builds Dawn with
   `DAWN_USE_WAYLAND=ON` on `ubuntu-24.04` and `ubuntu-24.04-arm`, checks each
   result (both `vkCreateWaylandSurfaceKHR` and `vkCreateXlibSurfaceKHR`
   present, size sanity, tarball prefix), and publishes
   `Dawn-<commit>-linux-{x86_64,arm64}-Release.tar.gz` as GitHub release
   assets with both sha256s in the release notes and step summary.
2. **`module/`** — the `dawn` wrapper module. `extensions.bzl` picks the right
   per-platform prebuilt for the host OS and CPU at repo-fetch time
   (macOS/Windows from upstream `google/dawn`, Linux from this repo's release)
   and exposes it as `@dawn_bin`; `//:dawn` aliases `@dawn_bin//:dawn` so
   consumers keep the historical `@dawn` label. Every URL and sha256 lives in
   `extensions.bzl` as the single source of truth; a host with no entry fails
   at fetch naming the supported set.
3. **`tools/package-module.sh`** — packages `module/` into a byte-deterministic
   `dawn-module-<version>.tar.gz` and prints its sha256 + SRI integrity. This
   tarball is an extra asset on the release and is what the registry serves.
   It refuses to package while any `_SHA256S` entry is unpinned.
4. **The registry** (`kitten3d/bazel-registry`) — holds `dawn`'s metadata,
   a byte-identical copy of `module/MODULE.bazel`, and a `source.json` pointing
   at the wrapper-module tarball. Consumers add one `bazel_dep(name = "dawn")`
   and two `--registry` lines.

## Dawn version-bump procedure

1. **Dispatch** `build-dawn` with the new upstream `dawn_tag` + `dawn_commit`.
   It publishes both Linux tarballs and prints their sha256s.
2. **Update `module/`**: bump `DAWN_TAG` / `DAWN_COMMIT` in
   `extensions.bzl`, set the `linux_*` `_SHA256S` entries to the shas the
   workflow printed, and refresh the upstream macOS/Windows shas from the new
   upstream release. Bump
   `version` in `module/MODULE.bazel` (upstream tag minus the `v`;
   wrapper-only fixes append a BCR-style segment, e.g. `.1`).
3. **Package + upload**: run `tools/package-module.sh`, note the SRI integrity,
   and upload `dawn-module-<version>.tar.gz` to the same release.
4. **Registry**: add `modules/dawn/<version>/` (byte-identical `MODULE.bazel`
   copy + `source.json` with the new URL and SRI integrity) and append the
   version to `modules/dawn/metadata.json`.
5. **Engine**: bump `bazel_dep(name = "dawn", version = ...)` in kitten's
   `MODULE.bazel`, regenerate the lockfile, `bazel test //:tests`.
