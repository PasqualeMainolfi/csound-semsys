#!/usr/bin/env bash
# Fetch the ONNX Runtime and onnxruntime-extensions shared libraries that semsys
# loads at runtime, for one release platform, into an output folder:
#
#   scripts/fetch_onnx_runtime.sh <linux|windows|macos-universal> <outdir>
#
# Only the official prebuilt binaries are used (never a system or package-manager
# copy, which links against other libraries of that package manager), so the
# release archive is self-contained. The libraries are written under the names
# semsys looks for, and their license notices under <outdir>/licenses.
#
# ONNX Runtime has no macOS x86_64 build since 1.24: the macOS archive gets an
# arm64 libonnxruntime (macOS >= 14) and a universal libortextensions.
#
# Override the pinned versions with ORT_VERSION / ORTEXT_VERSION.
set -euo pipefail

ORT_VERSION="${ORT_VERSION:-1.31.0}"
ORTEXT_VERSION="${ORTEXT_VERSION:-0.14.0}"

if [ $# -ne 2 ]; then
    echo "usage: $0 <linux|windows|macos-universal> <outdir>" >&2
    exit 1
fi
platform="$1"
out="$2"

case "$platform" in
    linux)           ort_pkg="onnxruntime-linux-x64-${ORT_VERSION}"; ort_ext=tgz ;;
    windows)         ort_pkg="onnxruntime-win-x64-${ORT_VERSION}";   ort_ext=zip ;;
    macos-universal) ort_pkg="onnxruntime-osx-arm64-${ORT_VERSION}"; ort_ext=tgz ;;
    *) echo "unknown platform: $platform" >&2; exit 1 ;;
esac

ort_url="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ort_pkg}.${ort_ext}"
ext_url="https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime.extensions/${ORTEXT_VERSION}/microsoft.ml.onnxruntime.extensions.${ORTEXT_VERSION}.nupkg"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$out/licenses"

curl -fsSL --retry 3 -o "$work/ort.${ort_ext}" "$ort_url"
curl -fsSL --retry 3 -o "$work/ext.nupkg" "$ext_url"

# `cmake -E tar` reads .tgz and .zip (a .nupkg is a zip) on every runner, without
# depending on unzip/7z being installed.
( cd "$work" && cmake -E tar xf "ort.${ort_ext}" )
mkdir -p "$work/ext"
( cd "$work/ext" && cmake -E tar xf ../ext.nupkg )

ort="$work/$ort_pkg"
ext="$work/ext/runtimes"

case "$platform" in
    linux)
        cp "$ort/lib/libonnxruntime.so.${ORT_VERSION}" "$out/libonnxruntime.so"
        cp "$ext/linux-x64/native/libortextensions.so" "$out/libortextensions.so"
        ;;
    windows)
        cp "$ort/lib/onnxruntime.dll" "$out/onnxruntime.dll"
        cp "$ext/win-x64/native/ortextensions.dll" "$out/ortextensions.dll"
        ;;
    macos-universal)
        cp "$ort/lib/libonnxruntime.${ORT_VERSION}.dylib" "$out/libonnxruntime.dylib"
        lipo -create \
            "$ext/osx.10.14-x64/native/libortextensions.dylib" \
            "$ext/osx.10.14-arm64/native/libortextensions.dylib" \
            -output "$out/libortextensions.dylib"
        ;;
esac

cp "$ort/LICENSE"                 "$out/licenses/onnxruntime-LICENSE.txt"
cp "$ort/ThirdPartyNotices.txt"   "$out/licenses/onnxruntime-ThirdPartyNotices.txt"
cp "$work/ext/LICENSE.txt"        "$out/licenses/onnxruntime-extensions-LICENSE.txt"
cp "$work/ext/ThirdPartyNotices.txt" "$out/licenses/onnxruntime-extensions-ThirdPartyNotices.txt"

echo "fetched onnxruntime ${ORT_VERSION} + onnxruntime-extensions ${ORTEXT_VERSION} ($platform) into $out"
