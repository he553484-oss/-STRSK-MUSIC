#!/usr/bin/env bash
set -euo pipefail

app="$(cd "${1:?indica la carpeta .app del build Release para iOS}" && pwd)"
output="${2:?indica el nombre de la IPA}"
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"

plist="$app/Info.plist"
plist_read() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
exec_name="$(plist_read CFBundleExecutable)"
display_name="$(plist_read CFBundleDisplayName)"
bundle_id="$(plist_read CFBundleIdentifier)"
platform="$(plist_read CFBundleSupportedPlatforms:0)"
architectures="$(lipo -archs "$app/$exec_name")"
[[ "$display_name" == 'STRSK MUSIC' && "$platform" == iPhoneOS && "$architectures" == arm64 ]]
[[ ! -f "$app/embedded.mobileprovision" && ! -d "$app/_CodeSignature" ]]

staging="$(mktemp -d)"
trap 'rm -rf -- "$staging"' EXIT
mkdir -p "$staging/Payload"
ditto "$app" "$staging/Payload/STRSK MUSIC.app"
ditto -c -k --keepParent "$staging/Payload" "$staging/STRSK.zip"
unzip -tq "$staging/STRSK.zip"
mv "$staging/STRSK.zip" "$output"
(
    cd "$(dirname "$output")"
    shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256"
)
printf 'IPA sin firma: %s\nBundle: %s\nPlataforma: %s %s\n' "$output" "$bundle_id" "$platform" "$architectures"
