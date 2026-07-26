#!/usr/bin/env bash
# tool/verify.sh
#
# The full check. Run before pushing, and from CI if one is added.
#
#   ./tool/verify.sh
#
# Exits non-zero on the first failure.

set -uo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter analyze"
# `flutter analyze` exits non-zero for ANY finding, including info-level, so its
# exit code cannot be the gate — the repo still carries ~100 info findings that
# are tracked, not blocking. Capture the output and count real errors instead.
#
# This previously piped straight into `grep -q` under `set -o pipefail`, which
# made the pipeline fail whenever analyze exited non-zero — so the `if` never
# saw grep's match and the script reported success while errors existed.
analysis="$(flutter analyze lib 2>&1 || true)"
errors="$(printf '%s\n' "$analysis" | grep -c 'error •' || true)"

if [ "$errors" -ne 0 ]; then
  printf '%s\n' "$analysis" | grep 'error •'
  echo "FAIL: $errors analyzer error(s)"
  exit 1
fi
echo "    no analyzer errors"

echo "==> architecture"
dart run tool/check_architecture.dart || exit 1

echo "==> tests"
flutter test test/core test/domain test/data || exit 1

echo
echo "All checks passed."
