#!/usr/bin/env bash
# Build semsys for the host platform and package it as a risset release zip.
#
#   CSOUND_INCLUDE_DIR=/path/to/csound/include ./scripts/package.sh
#
# Optional:
#   ORT_EXTENSIONS_LIB=/path/to/libortextensions.<ext>   bundle the extensions lib
#   ONNXRUNTIME_LIB=/path/to/libonnxruntime.<ext>          override onnxruntime bundling
#
# Produces dist/semsys-csound7-<os>.zip containing the plugin binary named to match
# the extractpath values in risset.json (libsemsys.dylib / libsemsys.so / semsys.dll).
# The onnxruntime runtime libraries are intentionally NOT shipped in the zip.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="${here}/build"
dist="${here}/dist"

case "$(uname -s)" in
    Darwin)              os="macos-universal"; lib="libsemsys.dylib"
                         extra=( -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" ) ;;
    Linux)               os="linux";           lib="libsemsys.so";   extra=() ;;
    MINGW*|MSYS*|CYGWIN*) os="windows";        lib="semsys.dll";     extra=() ;;
    *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

args=( -S "$here" -B "$build" -DCMAKE_BUILD_TYPE=Release )
[ -n "${CSOUND_INCLUDE_DIR:-}" ]     && args+=( -DCSOUND_INCLUDE_DIR="$CSOUND_INCLUDE_DIR" )
[ -n "${CSOUND_EXTRA_INCLUDE_DIRS:-}" ] && args+=( -DCSOUND_EXTRA_INCLUDE_DIRS="$CSOUND_EXTRA_INCLUDE_DIRS" )
[ -n "${ORT_EXTENSIONS_LIB:-}" ]     && args+=( -DORT_EXTENSIONS_LIB="$ORT_EXTENSIONS_LIB" )
[ -n "${ONNXRUNTIME_LIB:-}" ]        && args+=( -DONNXRUNTIME_LIB="$ONNXRUNTIME_LIB" )
args+=( "${extra[@]}" )

cmake "${args[@]}"
cmake --build "$build" --target semsys --parallel

mkdir -p "$dist"
zip_path="${dist}/semsys-csound7-${os}.zip"
rm -f "$zip_path"
( cd "$build" && zip -j "$zip_path" "$lib" )

echo "packaged: $zip_path"
unzip -l "$zip_path"
