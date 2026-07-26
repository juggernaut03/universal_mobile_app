#!/usr/bin/env bash
# tool/verify.sh
#
# The full check. Run before pushing, and from CI if one is added.
#
#   ./tool/verify.sh
#
# Exits non-zero on the first failure.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter analyze"
# Errors fail the build. The remaining info/warning findings are tracked in
# docs/ARCHITECTURE_MIGRATION_PLAN.md and are not a gate yet.
if flutter analyze lib 2>&1 | grep -q "error •"; then
  flutter analyze lib | grep "error •"
  echo "FAIL: analyzer errors"
  exit 1
fi
echo "    no analyzer errors"

echo "==> architecture"
dart run tool/check_architecture.dart

echo "==> tests"
flutter test test/core test/domain test/data

echo
echo "All checks passed."
