#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to.xcresult>" >&2
  exit 2
fi

BUNDLE="$1"
FAIL_CI="${FAIL_CI:-true}"

if [[ ! -d "$BUNDLE" ]]; then
  echo "error: xcresult bundle not found: $BUNDLE" >&2
  exit 2
fi

python3 - "$BUNDLE" "$FAIL_CI" <<'PY'
import json, subprocess, sys, os

bundle, fail_ci = sys.argv[1], sys.argv[2].lower() == "true"

proc = subprocess.run(
    ["xcrun", "xccov", "view", "--report", "--json", bundle],
    capture_output=True, text=True,
)
if proc.returncode != 0:
    print(proc.stderr or proc.stdout, file=sys.stderr)
    sys.exit(2)

data = json.loads(proc.stdout)
target = next(
    (t for t in data.get("targets", []) if t.get("name", "").endswith("MusicWall.app")),
    None,
)
if target is None:
    print("error: MusicWall.app target not found in coverage report", file=sys.stderr)
    sys.exit(2)

EXCLUDED_ADAPTERS = {
    "MusicKitAlbumRepository.swift",
    "SystemMusicPlayerAdapter.swift",
    "MusicKitArtworkProvider.swift",
    "AlbumMapper.swift",
    "SecurityScopedResourceReader.swift",
    "LiveMusicAuthorizationProvider.swift",
    "CarPlaySceneDelegate.swift",
    "CarPlayCoordinator.swift",
    "CarPlayGridBuilder.swift",
    "CarPlaySetupTemplate.swift",
}

THRESHOLDS = {
    "Core": 0.95,
    "ViewModels": 0.90,
    "Adapters": 0.80,
}

layers = {
    "Core": {"covered": 0, "total": 0, "files": []},
    "ViewModels": {"covered": 0, "total": 0, "files": []},
    "Adapters": {"covered": 0, "total": 0, "files": []},
}

def classify(path: str):
    if "/Features/" in path and path.endswith("ViewModel.swift"):
        return "ViewModels"
    if "/Core/" in path:
        return "Core"
    if "/Adapters/" in path:
        return "Adapters"
    return None

for f in target.get("files", []):
    path = f.get("path", "")
    name = os.path.basename(path)
    layer = classify(path)
    if layer is None:
        continue
    if layer == "Adapters" and name in EXCLUDED_ADAPTERS:
        continue
    covered = int(f.get("coveredLines", 0))
    total = int(f.get("executableLines", 0))
    if total == 0:
        continue
    layers[layer]["covered"] += covered
    layers[layer]["total"] += total
    layers[layer]["files"].append((name, covered, total, covered / total))

print(f"{'Layer':<14}{'Covered':>8}{'Total':>8}{'Pct':>8}{'Threshold':>12}{'Status':>8}")
print("-" * 58)

failed = []
for layer, threshold in THRESHOLDS.items():
    cov = layers[layer]["covered"]
    tot = layers[layer]["total"]
    pct = (cov / tot) if tot else 0.0
    status = "PASS" if pct >= threshold else "FAIL"
    if status == "FAIL":
        failed.append(layer)
    print(f"{layer:<14}{cov:>8}{tot:>8}{pct:>7.1%}{threshold:>11.0%}{status:>8}")

if failed:
    for layer in failed:
        print(f"\nLowest coverage in {layer}:")
        for name, c, t, p in sorted(layers[layer]["files"], key=lambda x: x[3])[:5]:
            print(f"  {p:6.1%}  {c:3}/{t:3}  {name}")
    if fail_ci:
        sys.exit(1)
    print("\nFAIL_CI=false — reporting only.")
PY
