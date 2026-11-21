#!/usr/bin/env bash
# Exercise upstream suites in an isolated Swift package on Linux.
set -euo pipefail
checkouts="$(cd "${1:?indica el directorio que contiene luma-ios y Erhu-IOS}" && pwd)"
luma="$checkouts/luma-ios"
erhu="$checkouts/Erhu-IOS"
[[ "$(git -C "$luma" rev-parse HEAD)" == 7006a4b51aa3bc5a1175036ea7ec83034fdccbfe ]]
[[ "$(git -C "$erhu" rev-parse HEAD)" == 31a0f3c542e62bdc00f8083fc702e9aa1364c0ab ]]
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp"/{Sources/{Luma,Erhu},Tests/{LumaTests,ErhuTests}}
cat > "$tmp/Package.swift" <<'SWIFT'
// swift-tools-version: 6.3
import PackageDescription

let package = Package(name: "UpstreamAudit", targets: [
    .target(name: "Luma"),
    .target(name: "Erhu"),
    .testTarget(name: "LumaTests", dependencies: ["Luma"]),
    .testTarget(name: "ErhuTests", dependencies: ["Erhu"])
], swiftLanguageModes: [.v5])
SWIFT
for path in Erhu/Core/Lyrics/LyricsParser.swift Erhu/Core/Common/Regex16.swift; do
    git -C "$erhu" show "HEAD:$path" > "$tmp/Sources/Erhu/${path##*/}"
done
git -C "$erhu" show HEAD:ErhuTests/Lyrics/LyricsTests.swift |
    sed '/^private let wordSyncedLyricsfile/,$d' > "$tmp/Tests/ErhuTests/LyricsParserTests.swift"
for path in Luma/LyricsService.swift LumaTests/LyricsServiceTests.swift; do
    directory=Sources/Luma
    [[ "$path" != LumaTests/* ]] || directory=Tests/LumaTests
    {
        printf '#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n'
        git -C "$luma" show "HEAD:$path"
    } > "$tmp/$directory/${path##*/}"
done
git -C "$luma" show HEAD:Luma/Models.swift | python3 -c '
import sys
source = sys.stdin.read()
start = source.index("struct LyricLine:")
end = source.index("func formattedTime", start)
print("import Foundation\n" + source[start:end], end="")
' > "$tmp/Sources/Luma/LyricsDocument.swift"
swift test --package-path "$tmp" -j 4
