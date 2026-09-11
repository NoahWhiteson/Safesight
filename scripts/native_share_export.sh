#!/usr/bin/env bash
# Build + run the native ScanShareExporter CLI (exact app share PNG).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/tools/ShareExportCLI/.build"
BIN="${OUT_DIR}/share-export"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios17.0-simulator"

mkdir -p "$OUT_DIR"

xcrun --sdk iphonesimulator swiftc \
  -parse-as-library \
  -O \
  -sdk "$SDK" \
  -target "$TARGET" \
  -D SHARE_EXPORT_CLI \
  \
  "${ROOT}/tools/ShareExportCLI/Models.swift" \
  "${ROOT}/Safesight/ScanShareExporter.swift" \
  "${ROOT}/tools/ShareExportCLI/main.swift" \
  -o "$BIN"

echo "built $BIN"

# Prefer spawning inside a booted simulator so UIKit is happy.
DEVICE_UDID="$(xcrun simctl list devices booted | awk -F '[()]' '/iPhone/{print $2; exit}')"
if [[ -z "${DEVICE_UDID}" ]]; then
  # Boot first available iPhone
  DEVICE_UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"
  if [[ -z "${DEVICE_UDID}" ]]; then
    echo "No iPhone simulator available" >&2
    exit 1
  fi
  xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE_UDID" -b
fi

# Install binary into a writable sim path and run
SIM_BIN="/tmp/safesight-share-export"
xcrun simctl spawn "$DEVICE_UDID" /bin/rm -f "$SIM_BIN" 2>/dev/null || true
# Copy into host /tmp which is shared… actually simctl spawn needs path inside sim.
# Use `simctl spawn` with the host-built binary — works for arm64 simulator bins on Apple Silicon.
exec xcrun simctl spawn "$DEVICE_UDID" "$BIN" "$@"
