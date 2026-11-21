#!/usr/bin/env bash
# Build and test the exact upstream snapshot without changing its tracked files.
set -euo pipefail

expected_commit=7006a4b51aa3bc5a1175036ea7ec83034fdccbfe
source_dir="$(cd "${1:?indica el directorio de Luma original}" && pwd)"
output_dir="${2:?indica un directorio nuevo para los resultados}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "Commit inesperado: $actual_commit (esperado: $expected_commit)" >&2
    exit 1
fi
if [[ -n "$(git -C "$source_dir" status --porcelain)" ]]; then
    echo "El checkout de Luma contiene modificaciones o archivos sin seguimiento." >&2
    exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Se requiere macOS con Xcode e iOS SDK 26 o posterior (falta xcodebuild)." >&2
    exit 127
fi

project="$source_dir/Luma.xcodeproj"
xcodebuild -version | tee "$output_dir/xcode.log"
xcodebuild -showsdks | tee "$output_dir/sdks.log"

build_status=0
xcodebuild -project "$project" -scheme Luma -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$output_dir/device-build" \
    -resultBundlePath "$output_dir/Release.xcresult" \
    ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$output_dir/release.log" || build_status=$?

xcrun simctl list devices available -j > "$output_dir/simulators.json"
simulator_id="${STRSK_SIMULATOR_ID:-$(python3 - "$output_dir/simulators.json" <<'PY'
import json
import re
import sys

with open(sys.argv[1]) as source:
    runtimes = json.load(source)["devices"]
candidates = []
for runtime, devices in runtimes.items():
    release = re.search(r"\.iOS-(\d+)((?:-\d+)*)$", runtime)
    if not release or int(release.group(1)) < 26:
        continue
    version = tuple(map(int, release.group(0).split("iOS-")[1].split("-")))
    for device in devices:
        if device["isAvailable"] and device["name"].startswith("iPhone"):
            candidates.append((device["name"] == "iPhone 15 Pro", version, "Pro" in device["name"], device["udid"]))
if not candidates:
    sys.exit("No hay un simulador iPhone con iOS 26 o posterior instalado.")
print(max(candidates)[-1])
PY
)}"
printf '%s\n' "$simulator_id" > "$output_dir/selected-simulator.txt"
test_status=0
xcodebuild -project "$project" -scheme Luma -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$output_dir/simulator-build" \
    -resultBundlePath "$output_dir/Tests.xcresult" \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test \
    2>&1 | tee "$output_dir/tests.log" || test_status=$?

[[ -z "$(git -C "$source_dir" status --porcelain)" ]]
printf 'Release exit=%s; tests exit=%s\n' "$build_status" "$test_status" | tee "$output_dir/status.log"
[[ "$build_status" == 0 && "$test_status" == 0 ]]
