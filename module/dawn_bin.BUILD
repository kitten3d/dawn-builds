# Dawn WebGPU — pre-built static library.
#
# This BUILD file is the build_file for the @dawn_bin repo the dawn_binaries
# extension creates. The downloaded tarball (after strip_prefix) contains:
#   include/   — public headers (webgpu/, dawn/)
#   lib64/     — libwebgpu_dawn.a static library (lib/ on macOS)

load("@rules_cc//cc:cc_import.bzl", "cc_import")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_import(
    name = "dawn_import",
    hdrs = glob(["include/**"]),
    static_library = select({
        "@platforms//os:linux": "lib64/libwebgpu_dawn.a",
        "@platforms//os:macos": "lib/libwebgpu_dawn.a",
        "@platforms//os:windows": "lib64/libwebgpu_dawn.a",
        "//conditions:default": "lib/libwebgpu_dawn.a",
    }),
)

cc_library(
    name = "dawn",
    includes = ["include"],
    linkopts = select({
        "@platforms//os:macos": [
            "-framework Metal",
            "-framework QuartzCore",
            "-framework IOKit",
            "-framework IOSurface",
            "-framework Foundation",
            "-framework CoreGraphics",
            "-framework CoreFoundation",
            "-framework Cocoa",
        ],
        "@platforms//os:linux": [
            "-ldl",
            "-lpthread",
        ],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:public"],
    deps = [":dawn_import"],
)
