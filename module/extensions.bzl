"""Platform-aware downloader for pre-built Dawn WebGPU binaries.

Ports the old third_party/dawn_prebuilt.bzl logic into a module extension: the
same ctx.os -> platform key, suffix map, and download_and_extract with
stripPrefix. This is the single source of truth for the Dawn version pin, all
four per-platform URLs, and all four sha256s — the values the old design
duplicated across gpu and debug.

macOS and Windows binaries still come from Dawn's official google/dawn nightly
releases (X11/Metal/D3D — unchanged). The Linux binary comes from our own
kitten3d/dawn-builds release, which is built with DAWN_USE_WAYLAND=ON so a
native wl_surface passes Dawn validation.
"""

# ─── Dawn version pin (bump this block for a new Dawn version) ────────────────
DAWN_TAG = "v20260214.164635"
DAWN_COMMIT = "1a3afc99a7ef7dacaab73b71d44575c4f1bf2dd7"

# ─── URL bases ───────────────────────────────────────────────────────────────
_UPSTREAM_BASE = "https://github.com/google/dawn/releases/download"
_LINUX_BASE = "https://github.com/kitten3d/dawn-builds/releases/download"

_SUFFIXES = {
    "macos_arm64": "macos-latest-Release",
    "macos_x86_64": "macos-15-intel-Release",
    "linux": "ubuntu-latest-Release",
    "windows": "windows-latest-Release",
}

# ─── sha256 checksums, keyed by platform ─────────────────────────────────────
# macOS/Windows: upstream google/dawn release shas (unchanged).
# Linux: sha256 of OUR kitten3d/dawn-builds release asset, as printed by the
# build-dawn workflow run that published it.
LINUX_SHA256 = "e0375c6d396a80edd3f5dea2e41aa8d03dad6d6607db12a03d01847688591712"

_SHA256S = {
    "macos_arm64": "536c7ae9e2e679224797880afe6a3a6ba072e6986d5bc9b7cce18c2d730aa578",
    "macos_x86_64": "50439db37abd602ad7f46342b3200d11eaa955e6482c43d7daad72735cfd608a",
    "linux": LINUX_SHA256,
    "windows": "3abbab979ea196c0cc9e171be30a8c14850257ab77fd8e38a1a9473727bf5319",
}

def _dawn_bin_impl(ctx):
    os_name = ctx.os.name.lower()
    arch = ctx.os.arch

    if "mac" in os_name:
        key = "macos_arm64" if ("aarch64" in arch or "arm64" in arch) else "macos_x86_64"
    elif "linux" in os_name:
        key = "linux"
    elif "windows" in os_name:
        key = "windows"
    else:
        fail("Unsupported platform: {} {}".format(os_name, arch))

    suffix = _SUFFIXES[key]
    sha = _SHA256S[key]

    prefix = "Dawn-{}-{}".format(DAWN_COMMIT, suffix)
    base = _LINUX_BASE if key == "linux" else _UPSTREAM_BASE
    url = "{}/{}/Dawn-{}-{}.tar.gz".format(base, DAWN_TAG, DAWN_COMMIT, suffix)

    ctx.download_and_extract(url = url, sha256 = sha, stripPrefix = prefix)
    ctx.file("BUILD.bazel", ctx.read(ctx.path(Label("//:dawn_bin.BUILD"))))

_dawn_bin = repository_rule(
    implementation = _dawn_bin_impl,
)

def _dawn_binaries_impl(_ctx):
    _dawn_bin(name = "dawn_bin")

dawn_binaries = module_extension(
    implementation = _dawn_binaries_impl,
)
