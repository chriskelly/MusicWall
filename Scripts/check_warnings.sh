#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-xcodebuild.log>" >&2
  exit 2
fi

LOG="$1"
FAIL_ON_TEST_WARNINGS="${FAIL_ON_TEST_WARNINGS:-false}"
FAIL_CI="${FAIL_CI:-true}"

if [[ ! -f "$LOG" ]]; then
  echo "error: build log not found: $LOG" >&2
  exit 2
fi

python3 - "$LOG" "$FAIL_ON_TEST_WARNINGS" "$FAIL_CI" <<'PY'
import re, sys

log_path, fail_on_tests, fail_ci = sys.argv[1], sys.argv[2].lower() == "true", sys.argv[3].lower() == "true"

ALLOWLIST = re.compile(r"appintentsmetadataprocessor.*Metadata extraction skipped", re.I)
WARNING_LINE = re.compile(r"warning:", re.I)
PATH_BUCKETS = [
    ("tests", re.compile(r"/MusicWallTests/")),
    ("ui_tests", re.compile(r"/MusicWallUITests/")),
    ("app", re.compile(r"/MusicWall/")),
]

buckets = {name: [] for name, _ in PATH_BUCKETS}
buckets["filtered"] = []
buckets["other"] = []
seen = set()

with open(log_path, encoding="utf-8", errors="replace") as f:
    for line in f:
        if not WARNING_LINE.search(line):
            continue
        key = line.strip()
        if key in seen:
            continue
        seen.add(key)
        if ALLOWLIST.search(line):
            buckets["filtered"].append(key)
            continue
        placed = False
        for name, pattern in PATH_BUCKETS:
            if pattern.search(line):
                buckets[name].append(key)
                placed = True
                break
        if not placed:
            buckets["other"].append(key)

print("Warnings summary")
print(f"{'Bucket':<12} {'Count':>6}")
for name in ("app", "tests", "ui_tests", "other", "filtered"):
    print(f"{name:<12} {len(buckets[name]):>6}")

for name in ("app", "tests", "ui_tests", "other"):
    if buckets[name]:
        print(f"\n--- {name} ---")
        for w in buckets[name]:
            print(w)

test_count = len(buckets["tests"]) + len(buckets["ui_tests"])
if buckets["app"]:
    print("\nerror: app warnings found in log (compiler should have failed)", file=sys.stderr)
    sys.exit(1)

if fail_on_tests and test_count > 0 and fail_ci:
    print(f"\nerror: {test_count} test-target warning(s) (FAIL_ON_TEST_WARNINGS=true)", file=sys.stderr)
    sys.exit(1)

if test_count > 0:
    print(f"\nnote: {test_count} test-target warning(s) reported (not failing in v1)")
PY
