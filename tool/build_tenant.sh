#!/usr/bin/env bash
# Build a release artifact for one white-label tenant.
#
# Usage:
#   ./tool/build_tenant.sh <tenant> <platform> [version]
#
# Examples:
#   ./tool/build_tenant.sh myneedmart ipa 4.0.14
#   ./tool/build_tenant.sh pagariya apk
#   ./tool/build_tenant.sh grahakpeth appbundle 4.0.14
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: build_tenant.sh <tenant> <platform> [version]

Tenants:  myneedmart | pagariya | grahakpeth | sansarpariwar
Platforms: apk | appbundle | ipa
Version:  optional CFBundleShortVersionString / versionName (e.g. 4.0.14)

Uses dart_defines/<tenant>_prod.json for PROJECT_CODE, API_BASE_URL, RAZORPAY_KEY_ID.
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

TENANT="$1"
PLATFORM="$2"
VERSION="${3:-}"

VALID_TENANTS=(myneedmart pagariya grahakpeth sansarpariwar)
VALID_PLATFORMS=(apk appbundle ipa)

if [[ ! " ${VALID_TENANTS[*]} " =~ " ${TENANT} " ]]; then
  echo "error: unknown tenant '$TENANT'" >&2
  usage
  exit 1
fi

if [[ ! " ${VALID_PLATFORMS[*]} " =~ " ${PLATFORM} " ]]; then
  echo "error: unknown platform '$PLATFORM'" >&2
  usage
  exit 1
fi

DEFINE_FILE="$ROOT_DIR/dart_defines/${TENANT}_prod.json"
if [[ ! -f "$DEFINE_FILE" ]]; then
  echo "error: missing $DEFINE_FILE" >&2
  exit 1
fi

# iOS flavors are added incrementally; only myneedmart is wired in Xcode today.
# Pagariya iOS still uses the default Runner scheme (com.patelrmart.iosapp).
IOS_FLAVORS=(myneedmart)

cd "$ROOT_DIR"

echo "==> tenant:   $TENANT"
echo "==> platform: $PLATFORM"
echo "==> defines:  $DEFINE_FILE"
[[ -n "$VERSION" ]] && echo "==> version:  $VERSION"

BUILD_ARGS=(build "$PLATFORM" --release --dart-define-from-file="$DEFINE_FILE")

if [[ "$PLATFORM" == "ipa" ]]; then
  if [[ " ${IOS_FLAVORS[*]} " =~ " ${TENANT} " ]]; then
    BUILD_ARGS+=(--flavor "$TENANT")
  elif [[ "$TENANT" != "pagariya" ]]; then
    echo "error: iOS flavor not configured for '$TENANT' (add Xcode configs first)" >&2
    exit 1
  fi
else
  BUILD_ARGS+=(--flavor "$TENANT")
fi

if [[ -n "$VERSION" ]]; then
  BUILD_ARGS+=(--build-name="$VERSION" --build-number="$VERSION")
fi

flutter pub get
if [[ "$PLATFORM" == "ipa" ]]; then
  (cd ios && pod install)
fi

echo "==> flutter ${BUILD_ARGS[*]}"
flutter "${BUILD_ARGS[@]}"

case "$PLATFORM" in
  apk)
    echo "==> output: build/app/outputs/flutter-apk/app-${TENANT}-release.apk"
    ;;
  appbundle)
    echo "==> output: build/app/outputs/bundle/${TENANT}Release/app-${TENANT}-release.aab"
    ;;
  ipa)
    echo "==> output: build/ios/ipa/*.ipa"
    echo "==> upload with Transporter or Xcode Organizer → App Store Connect → TestFlight"
    ;;
esac
