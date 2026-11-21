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
printf '%s\n' "$actual_commit" > "$output_dir/upstream-commit.txt"
xcodebuild -version | tee "$output_dir/xcode.log"
xcodebuild -showsdks | tee "$output_dir/sdks.log"

release_status=0
xcodebuild -project "$project" -scheme Luma -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$output_dir/device-build" \
    -resultBundlePath "$output_dir/Release.xcresult" \
    ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$output_dir/release.log" || release_status=$?

xcrun simctl list devices available -j > "$output_dir/simulators.json"
read -r simulator_id runtime simulator_model < <(python3 - "$output_dir/simulators.json" "${STRSK_SIMULATOR_ID:-}" <<'PY'
import json
import re
import sys

with open(sys.argv[1]) as source:
    runtimes = json.load(source)["devices"]
requested = sys.argv[2]
candidates = []
for runtime, devices in runtimes.items():
    release = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not release:
        continue
    version = tuple(map(int, release.group(1).split("-")))
    if version[0] < 26:
        continue
    for device in devices:
        name, udid = device["name"], device["udid"]
        if device["isAvailable"] and name.startswith("iPhone") and (not requested or requested == udid):
            candidates.append((name == "iPhone 15 Pro", version, name.endswith(" Pro"), name, udid, runtime))
if not candidates:
    sys.exit("No hay un simulador iPhone disponible con iOS 26 o posterior que coincida con la selección.")
_, _, _, name, udid, runtime = max(candidates)
print(udid, runtime, name)
PY
)

# GitHub's image may ship a newer iPhone by default. Try the requested model on
# its installed runtime. Keep the compatible preconfigured iPhone as fallback.
if [[ "${CI:-}" == true && -z "${STRSK_SIMULATOR_ID:-}" && "$simulator_model" != "iPhone 15 Pro" ]]; then
    if created_id="$(xcrun simctl create 'STRSK iPhone 15 Pro' \
        com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro "$runtime" 2>"$output_dir/simulator-create.log")"; then
        simulator_id="$created_id"
        simulator_model="iPhone 15 Pro"
    fi
fi
printf 'UUID=%s\nModelo=%s\nRuntime=%s\n' "$simulator_id" "$simulator_model" "$runtime" \
    | tee "$output_dir/selected-simulator.txt"

simulator_build_status=0
xcodebuild -project "$project" -scheme Luma -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$output_dir/simulator-build" \
    -resultBundlePath "$output_dir/SimulatorBuild.xcresult" \
    CODE_SIGNING_ALLOWED=NO build-for-testing \
    2>&1 | tee "$output_dir/simulator-build.log" || simulator_build_status=$?

test_status=skipped
if [[ "$simulator_build_status" == 0 ]]; then
    test_status=0
    xcodebuild -project "$project" -scheme Luma -configuration Debug \
        -destination "platform=iOS Simulator,id=$simulator_id" \
        -derivedDataPath "$output_dir/simulator-build" \
        -resultBundlePath "$output_dir/Tests.xcresult" \
        -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test-without-building \
        2>&1 | tee "$output_dir/tests.log" || test_status=$?
fi

[[ -z "$(git -C "$source_dir" status --porcelain)" ]]
printf 'Release exit=%s\nSimulator build exit=%s\nSimulator tests exit=%s\n' \
    "$release_status" "$simulator_build_status" "$test_status" | tee "$output_dir/status.log"
[[ "$release_status" == 0 && "$simulator_build_status" == 0 && "$test_status" == 0 ]]
