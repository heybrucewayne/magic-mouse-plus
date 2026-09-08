#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build/checks
module_cache="$(mktemp -d "${TMPDIR:-/tmp}/magic-mouse-plus-module-cache.XXXXXX")"
trap 'rm -rf "$module_cache"' EXIT
swiftc -module-cache-path "$module_cache" MagicMousePlus/Core/TapRecognizer.swift Tests/TapRecognizerChecks.swift -o build/checks/tap-checks
build/checks/tap-checks
clang -framework CoreFoundation Tests/BridgeChecks.c -o build/checks/bridge-checks
build/checks/bridge-checks
xcodebuild -project MagicMousePlus.xcodeproj -scheme MagicMousePlus -configuration Release -derivedDataPath "${TMPDIR:-/tmp}/magic-mouse-plus-build" build
