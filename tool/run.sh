#!/usr/bin/env bash
# Default/explicit overrides are resolved by SupabaseConfig in Dart.
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  echo 'Flutter bulunamadı. Flutter SDK bin dizinini PATH’e ekleyin veya FLUTTER_BIN tanımlayın.' >&2
  exit 1
fi
# Never implicitly read, copy or overwrite a local config file.
exec "$flutter_bin" run "$@"
