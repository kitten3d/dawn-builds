# dawn-builds

Artifact factory and wrapper Bazel module for [Dawn](https://dawn.googlesource.com/dawn),
Google's WebGPU implementation, as consumed by the kitten3d engine. The
upstream Linux release is built X11-only (`DAWN_USE_WAYLAND=OFF`), so a native
Wayland `wl_surface` fails Dawn validation. This repo builds a
Wayland+X11-enabled static Dawn on `ubuntu-latest` and serves it — alongside
the unchanged upstream macOS/Windows binaries — as a single platform-neutral
Bazel module named `dawn`.

## How the pieces fit

1. **`.github/workflows/build-dawn.yml`** — the artifact factory. Dispatched
   with a Dawn tag + commit, it clones and builds Dawn with
   `DAWN_USE_WAYLAND=ON`, checks the result (both `vkCreateWaylandSurfaceKHR`
   and `vkCreateXlibSurfaceKHR` present, size sanity, tarball prefix), and
   publishes `Dawn-<commit>-ubuntu-latest-Release.tar.gz` as a GitHub release
   asset with its sha256 in the release notes and step summary.
2. **`module/`** — the `dawn` wrapper module. `extensions.bzl` picks the right
   per-platform prebuilt at repo-fetch time (macOS/Windows from upstream
   `google/dawn`, Linux from this repo's release) and exposes it as
   `@dawn_bin`; `//:dawn` aliases `@dawn_bin//:dawn` so consumers keep the
   historical `@dawn` label. All four URLs and sha256s live in `extensions.bzl`
   as the single source of truth.
3. **`tools/package-module.sh`** — packages `module/` into a byte-deterministic
   `dawn-module-<version>.tar.gz` and prints its sha256 + SRI integrity. This
   tarball is the second asset on the release and is what the registry serves.
4. **The registry** (`kitten3d/bazel-registry`) — holds `dawn`'s metadata,
   a byte-identical copy of `module/MODULE.bazel`, and a `source.json` pointing
   at the wrapper-module tarball. Consumers add one `bazel_dep(name = "dawn")`
   and two `--registry` lines.

## Dawn version-bump procedure

1. **Dispatch** `build-dawn` with the new upstream `dawn_tag` + `dawn_commit`.
   It publishes the Linux tarball and prints its sha256.
2. **Update `module/`**: bump `DAWN_TAG` / `DAWN_COMMIT` in
   `extensions.bzl`, set `LINUX_SHA256` to the sha the workflow printed, and
   refresh the upstream macOS/Windows shas from the new upstream release. Bump
   `version` in `module/MODULE.bazel` (upstream tag minus the `v`;
   wrapper-only fixes append a BCR-style segment, e.g. `.1`).
3. **Package + upload**: run `tools/package-module.sh`, note the SRI integrity,
   and upload `dawn-module-<version>.tar.gz` to the same release.
4. **Registry**: add `modules/dawn/<version>/` (byte-identical `MODULE.bazel`
   copy + `source.json` with the new URL and SRI integrity) and append the
   version to `modules/dawn/metadata.json`.
5. **Consumers**: bump the `bazel_dep(name = "dawn", version = ...)` in gpu and
   debug, regenerate lockfiles, run the suite.
