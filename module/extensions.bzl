"""Platform-aware downloader for pre-built Dawn WebGPU binaries.

Single source of truth for the Dawn version pin, the per-platform URLs, and
their sha256s. macOS/Windows binaries come from upstream google/dawn
releases; Linux comes from our own kitten3d/dawn-builds release (built with
DAWN_USE_WAYLAND=ON so a native wl_surface passes Dawn validation), one
build per CPU architecture.
"""

DAWN_TAG = "v20260214.164635"
DAWN_COMMIT = "1a3afc99a7ef7dacaab73b71d44575c4f1bf2dd7"

_UPSTREAM_BASE = "https://github.com/google/dawn/releases/download"
_OWN_BASE = "https://github.com/kitten3d/dawn-builds/releases/download"

_SUFFIXES = {
    "linux_x86_64": "linux-x86_64-Release",
    "linux_arm64": "linux-arm64-Release",
    "macos_arm64": "macos-latest-Release",
    "macos_x86_64": "macos-15-intel-Release",
    "windows_x86_64": "windows-latest-Release",
}

_SHA256S = {
    "linux_x86_64": "481e391ff511c4c2f2857f08bddbef0a8678403ddfa972a58119c5a3fb5be43c",
    "linux_arm64": "ce10cae95156b25f32961d7ca8327d25d2bba263a926eced89d08e3221de59f2",
    "macos_arm64": "536c7ae9e2e679224797880afe6a3a6ba072e6986d5bc9b7cce18c2d730aa578",
    "macos_x86_64": "50439db37abd602ad7f46342b3200d11eaa955e6482c43d7daad72735cfd608a",
    "windows_x86_64": "3abbab979ea196c0cc9e171be30a8c14850257ab77fd8e38a1a9473727bf5319",
}

def _os(name):
    if "mac" in name:
        return "macos"
    if "linux" in name:
        return "linux"
    if "windows" in name:
        return "windows"
    return name

def _arch(arch):
    if "aarch64" in arch or "arm64" in arch:
        return "arm64"
    if "amd64" in arch or "x86_64" in arch:
        return "x86_64"
    return arch

def _dawn_bin_impl(ctx):
    os_key = _os(ctx.os.name.lower())
    key = "{}_{}".format(os_key, _arch(ctx.os.arch))
    if key not in _SUFFIXES:
        fail("No prebuilt Dawn for {}; dawn-builds ships {}.".format(
            key,
            ", ".join(sorted(_SUFFIXES.keys())),
        ))

    sha = _SHA256S[key]
    if not sha:
        fail("dawn-builds: sha256 for '{}' is unpinned; run the build-dawn ".format(key) +
             "workflow and copy the printed sha into _SHA256S.")

    prefix = "Dawn-{}-{}".format(DAWN_COMMIT, _SUFFIXES[key])
    base = _OWN_BASE if os_key == "linux" else _UPSTREAM_BASE
    url = "{}/{}/{}.tar.gz".format(base, DAWN_TAG, prefix)

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
