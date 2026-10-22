#!/usr/bin/env bash
# Build semsys for the host platform and package it as a risset release zip.
#
#   CSOUND_INCLUDE_DIR=/path/to/csound/include ./scripts/package.sh
#
# Produces dist/semsys-csound7-<os>.zip with the same layout as the release
# workflow: the plugin binary, the official onnxruntime / onnxruntime-extensions
# runtime libraries (fetched by scripts/fetch_onnx_runtime.sh) and their license
# notices, named to match the extractpath values in risset.json.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="${here}/build"
dist="${here}/dist"

case "$(uname -s)" in
    Darwin)              os="macos-universal"; lib="libsemsys.dylib"
                         extra=( -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
                                 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 ) ;;
    Linux)               os="linux";           lib="libsemsys.so";   extra=() ;;
    MINGW*|MSYS*|CYGWIN*) os="windows";        lib="semsys.dll";     extra=() ;;
    *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

args=( -S "$here" -B "$build" -DCMAKE_BUILD_TYPE=Release )
[ -n "${CSOUND_INCLUDE_DIR:-}" ]     && args+=( -DCSOUND_INCLUDE_DIR="$CSOUND_INCLUDE_DIR" )
[ -n "${CSOUND_EXTRA_INCLUDE_DIRS:-}" ] && args+=( -DCSOUND_EXTRA_INCLUDE_DIRS="$CSOUND_EXTRA_INCLUDE_DIRS" )
args+=( "${extra[@]}" )

cmake "${args[@]}"
cmake --build "$build" --target semsys --parallel

stage="${dist}/stage-${os}"
rm -rf "$stage"
mkdir -p "$stage"
cp "${build}/${lib}" "$stage/"
"${here}/scripts/fetch_onnx_runtime.sh" "$os" "$stage"

zip_path="${dist}/semsys-csound7-${os}.zip"
rm -f "$zip_path"
( cd "$stage" && cmake -E tar cf "$zip_path" --format=zip -- * )

echo "packaged: $zip_path"
unzip -l "$zip_path"
