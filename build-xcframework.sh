#!/usr/bin/env bash
set -euo pipefail

# Build the Rust library as an XCFramework and generate UniFFI Swift bindings.
#
# Inputs:
# - ./libactr (git submodule with Rust sources + uniffi.toml)
#
# Outputs:
# - ./ActrBindings/** (Actr.swift + headers + modulemap)
# - ./ActrFFI.xcframework/**

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

CRATE_DIR="${ROOT_DIR}/libactr"
CRATE_LIB_NAME="actr"
FRAMEWORK_NAME="ActrFFI"

BINDINGS_DIR="${ACTR_BINDINGS_PATH:-${ROOT_DIR}/ActrBindings}"
HEADERS_DIR="${BINDINGS_DIR}/include"
XCFRAMEWORK_DIR="${ACTR_BINARY_PATH:-${ROOT_DIR}/${FRAMEWORK_NAME}.xcframework}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "error: missing required file: $1" >&2
    exit 1
  fi
}

require_cmd cargo
require_cmd lipo
require_cmd xcodebuild
require_cmd uniffi-bindgen
require_cmd rustc

echo "Checking libactr submodule..."
if [[ ! -d "${CRATE_DIR}/.git" ]]; then
  echo "Initializing libactr submodule..."
  git submodule update --init --recursive
fi

require_file "${CRATE_DIR}/Cargo.toml"
require_file "${CRATE_DIR}/uniffi.toml"

HOST_TARGET="$(rustc -vV | awk -F': ' '/^host:/{print $2}')"
if [[ -z "${HOST_TARGET}" ]]; then
  echo "error: failed to detect host target triple from rustc" >&2
  exit 1
fi

echo "[1/4] Preparing bindings output directory"
mkdir -p "${HEADERS_DIR}"

# Keep the "empty C file trick" for Xcode. UniFFI does not generate this file.
if [[ ! -f "${BINDINGS_DIR}/actrFFI.c" ]]; then
  : > "${BINDINGS_DIR}/actrFFI.c"
fi

# Remove previously generated artifacts to avoid accidentally mixing old/new symbols.
rm -f \
  "${BINDINGS_DIR}/Actr.swift" \
  "${BINDINGS_DIR}/actrFFI.h" \
  "${BINDINGS_DIR}/actrFFI.modulemap" \
  "${HEADERS_DIR}/actrFFI.h"

echo "[2/4] Generating Swift bindings (host: ${HOST_TARGET})"
(cd "${CRATE_DIR}" && cargo build --release --target "${HOST_TARGET}")

DYLIB_PATH="${CRATE_DIR}/target/${HOST_TARGET}/release/lib${CRATE_LIB_NAME}.dylib"
if [[ ! -f "${DYLIB_PATH}" ]]; then
  echo "error: expected host dylib not found: ${DYLIB_PATH}" >&2
  echo "hint: ensure Cargo.toml has crate-type = [\"cdylib\", \"staticlib\"]" >&2
  exit 1
fi

(cd "${CRATE_DIR}" && uniffi-bindgen generate --library "${DYLIB_PATH}" --language swift --out-dir "${BINDINGS_DIR}")

require_file "${BINDINGS_DIR}/Actr.swift"
require_file "${BINDINGS_DIR}/actrFFI.modulemap"

# UniFFI currently writes the header next to the modulemap; SwiftPM expects public headers under
# `publicHeadersPath` (we use `ActrBindings/include`).
if [[ -f "${BINDINGS_DIR}/actrFFI.h" ]]; then
  mv -f "${BINDINGS_DIR}/actrFFI.h" "${HEADERS_DIR}/actrFFI.h"
fi
require_file "${HEADERS_DIR}/actrFFI.h"

# Ensure the modulemap points at the header location used by SwiftPM.
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' 's|header "actrFFI.h"|header "include/actrFFI.h"|g' "${BINDINGS_DIR}/actrFFI.modulemap"
else
  sed -i 's|header "actrFFI.h"|header "include/actrFFI.h"|g' "${BINDINGS_DIR}/actrFFI.modulemap"
fi

echo "[3/4] Building Rust static libraries (iOS + macOS)"
(cd "${CRATE_DIR}" && cargo build --release --target aarch64-apple-ios)
(cd "${CRATE_DIR}" && cargo build --release --target aarch64-apple-ios-sim)
(cd "${CRATE_DIR}" && cargo build --release --target x86_64-apple-ios)
(cd "${CRATE_DIR}" && cargo build --release --target aarch64-apple-darwin)
(cd "${CRATE_DIR}" && cargo build --release --target x86_64-apple-darwin)

IOS_SIM_UNIVERSAL_DIR="${CRATE_DIR}/target/ios-sim-universal/release"
mkdir -p "${IOS_SIM_UNIVERSAL_DIR}"
lipo -create \
  "${CRATE_DIR}/target/aarch64-apple-ios-sim/release/lib${CRATE_LIB_NAME}.a" \
  "${CRATE_DIR}/target/x86_64-apple-ios/release/lib${CRATE_LIB_NAME}.a" \
  -output "${IOS_SIM_UNIVERSAL_DIR}/lib${CRATE_LIB_NAME}.a"

MACOS_UNIVERSAL_DIR="${CRATE_DIR}/target/macos-universal/release"
mkdir -p "${MACOS_UNIVERSAL_DIR}"
lipo -create \
  "${CRATE_DIR}/target/aarch64-apple-darwin/release/lib${CRATE_LIB_NAME}.a" \
  "${CRATE_DIR}/target/x86_64-apple-darwin/release/lib${CRATE_LIB_NAME}.a" \
  -output "${MACOS_UNIVERSAL_DIR}/lib${CRATE_LIB_NAME}.a"

echo "[4/4] Creating XCFramework"
rm -rf "${XCFRAMEWORK_DIR}"

xcodebuild -create-xcframework \
  -library "${CRATE_DIR}/target/aarch64-apple-ios/release/lib${CRATE_LIB_NAME}.a" \
  -headers "${HEADERS_DIR}" \
  -library "${IOS_SIM_UNIVERSAL_DIR}/lib${CRATE_LIB_NAME}.a" \
  -headers "${HEADERS_DIR}" \
  -library "${MACOS_UNIVERSAL_DIR}/lib${CRATE_LIB_NAME}.a" \
  -headers "${HEADERS_DIR}" \
  -output "${XCFRAMEWORK_DIR}"

echo ""
echo "✅ XCFramework build complete!"
echo ""
echo "📦 Output:"
echo "   - Framework: ${XCFRAMEWORK_DIR}"
echo "   - Bindings:  ${BINDINGS_DIR}/Actr.swift"
echo ""
echo "📋 Next steps:"
echo "   1. Package for release: ./scripts/package-binary.sh <tag>"
echo "   2. Update Package.swift checksum/url to match the packaged artifact"
echo "   3. Create/publish a GitHub Release with the zipped XCFramework"
echo ""
