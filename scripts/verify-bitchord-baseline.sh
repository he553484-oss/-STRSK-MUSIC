#!/usr/bin/env bash
set -euo pipefail

repo="$1"
: "${BITCHORD_REVISION:?Set the exact upstream Git commit}"
: "${EVIDENCE_DIR:?Set an absolute output directory outside the upstream checkout}"
mkdir -p "$EVIDENCE_DIR"
cd "$repo"
git rev-parse HEAD | tee "$EVIDENCE_DIR/commit.txt"
test "$(git rev-parse HEAD)" = "$BITCHORD_REVISION"
test -z "$(git status --porcelain --untracked-files=all)"

run_stage() {
    local stage="$1"
    shift
    printf '\n--- %s ---\n' "$stage"
    if "$@" 2>&1 | tee "$EVIDENCE_DIR/$stage.log"; then
        printf '%s\tPASS\n' "$stage" >> "$EVIDENCE_DIR/stages.txt"
    else
        printf '%s\tFAIL\n' "$stage" >> "$EVIDENCE_DIR/stages.txt"
        return 1
    fi
}

collect_results() {
    shopt -s nullglob
    local bundles=("$EVIDENCE_DIR"/*.xcresult)
    if (( ${#bundles[@]} )); then
        tar -C "$EVIDENCE_DIR" -czf "$EVIDENCE_DIR/results.tar.gz" \
            $(printf '%s\n' "${bundles[@]##*/}")
    fi
}
trap collect_results EXIT

failed=0
run_stage rust-framework scripts/build-native-core.sh || failed=1
run_stage kotlin-framework env CONFIG=release scripts/build-shared-framework.sh || failed=1
run_stage swift-queue-verifier scripts/check-queue.sh || failed=1
run_stage swift-local-library-verifier scripts/check-local-library.sh || failed=1
run_stage rust-tests cargo test --locked --manifest-path native-core/Cargo.toml --lib || failed=1
run_stage kotlin-tests ./gradlew :shared:macosArm64Test :innertubex:macosArm64Test :quackjs:macosArm64Test || failed=1

if [[ -d AppleApp/Frameworks/BitChordShared.xcframework && -d AppleApp/Frameworks/NativeCoreFFI.xcframework ]] &&
   run_stage xcodegen xcodegen generate --spec AppleApp/project.yml; then
    project=(-project AppleApp/BitChord.xcodeproj -scheme BitChord -configuration Release)
    signing=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= ARCHS=arm64)
    run_stage release-arm64 xcodebuild "${project[@]}" -destination 'generic/platform=iOS' \
        -derivedDataPath "$RUNNER_TEMP/bitchord-device" -resultBundlePath "$EVIDENCE_DIR/Release.xcresult" \
        "${signing[@]}" build || failed=1
    if run_stage simulator-build xcodebuild "${project[@]}" -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$RUNNER_TEMP/bitchord-simulator" -resultBundlePath "$EVIDENCE_DIR/Simulator.xcresult" \
        "${signing[@]}" build; then
        xcrun simctl list devices available -j > "$EVIDENCE_DIR/simulators.json"
        xcrun simctl list runtimes available -j > "$EVIDENCE_DIR/runtimes.json"
        runtime="$(python3 - "$EVIDENCE_DIR/runtimes.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as source:
    runs = json.load(source)["runtimes"]
choices = []
for runtime in runs:
    if runtime["isAvailable"] and ".iOS-" in runtime["identifier"]:
        version = tuple(int(part) for part in runtime["version"].split("."))
        if version[0] >= 26:
            choices.append((version[0] == 26, version, runtime["identifier"]))
if choices:
    print(max(choices)[-1])
PY
        )"
        if [[ -n "$runtime" ]]; then
            printf '%s\n' "$runtime" | tee "$EVIDENCE_DIR/simulator-runtime.txt"
            app="$RUNNER_TEMP/bitchord-simulator/Build/Products/Release-iphonesimulator/BitChord.app"
            run_stage simulator-smoke bash -e -c '
                runtime="$1"
                app="$2"
                evidence="$3"
                device="$(xcrun simctl create "BitChord iPhone 15 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro "$runtime")"
                trap "xcrun simctl delete $device" EXIT
                xcrun simctl bootstatus "$device" -b
                xcrun simctl install "$device" "$app"
                xcrun simctl launch "$device" app.bitchord.BitChord
                xcrun simctl io "$device" screenshot "$evidence/BitChord-Simulator.png"
            ' _ "$runtime" "$app" "$EVIDENCE_DIR" || failed=1
        else
            printf 'simulator-smoke\tBLOCKED (no available iOS Simulator runtime 26 or later)\n' >> "$EVIDENCE_DIR/stages.txt"
            failed=1
        fi
    else
        failed=1
    fi
else
    printf 'release-arm64, simulator-build\tBLOCKED (framework or project missing)\n' >> "$EVIDENCE_DIR/stages.txt"
    failed=1
fi
git diff --exit-code HEAD -- || failed=1
exit "$failed"
