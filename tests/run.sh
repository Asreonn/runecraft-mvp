#!/usr/bin/env bash
set -uo pipefail
suite_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname -- "$suite_dir")"
mkdir -p "$suite_dir/artifacts/xdg-data" "$suite_dir/artifacts/xdg-config" "$suite_dir/artifacts/xdg-cache"
export XDG_DATA_HOME="$suite_dir/artifacts/xdg-data"
export XDG_CONFIG_HOME="$suite_dir/artifacts/xdg-config"
export XDG_CACHE_HOME="$suite_dir/artifacts/xdg-cache"
export GODOT_SILENCE_ROOT_WARNING=1
"${GODOT_BIN:-/usr/bin/godot}" --headless --path "$repo_dir" \
  --log-file "$suite_dir/artifacts/engine.log" --script res://tests/run_all.gd "$@" \
  2>&1 | tee "$suite_dir/artifacts/results.log"
status=${PIPESTATUS[0]}
# Fail on script or unexpected engine errors even if Godot returns zero.
# These two exact shutdown diagnostic families also occur in unmodified main.
# They remain in the saved logs; they do not change the invariant result.
if awk '
  /SCRIPT ERROR:|Parse Error:/ { bad = 1 }
  /^ERROR:/ && $0 !~ /^ERROR: Pages in use exist at exit in PagedAllocator: N20RasterizerSceneDummy21GeometryInstanceDummyE/ && $0 !~ /^ERROR: [0-9]+ RID allocations .* were leaked at exit\./ { bad = 1 }
  END { exit !bad }
' "$suite_dir/artifacts/results.log"; then
  printf '%s\n' 'HARNESS_ERROR: script or unexpected engine error found in results.log' >&2
  exit 1
fi
exit "$status"
