#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIGN_IDENTITY="${KELLO_SIGN_IDENTITY:-Developer ID Application}"
APP="$ROOT/build/Kello.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Kello" "$APP/Contents/MacOS/Kello"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Sparkle's own build embeds Sparkle.framework via Xcode's "Embed Frameworks" phase; here
# we copy it out of SwiftPM's artifact cache instead.
SPARKLE_FRAMEWORK="$(find "$BIN_DIR" -maxdepth 1 -type d -name "Sparkle.framework" | head -n 1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" -type d -name "Sparkle.framework" | head -n 1)"
fi
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "error: Sparkle.framework not found; run 'swift build' first" >&2
    exit 1
fi
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

# SwiftPM doesn't add an rpath for embedded frameworks, so Sparkle can't be found at launch
# without this.
if ! otool -l "$APP/Contents/MacOS/Kello" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Kello"
fi

# SwiftPM resource bundles (from a target's declared `resources`, like KeyboardShortcuts'
# localizations) land next to the binary. Bundle.module looks for them at the app's root,
# which codesign rejects, so they go in Contents/Resources, where ResourceBundles.swift
# points the lookup. They hold no code and are sealed with the app's own signature.
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
    [[ "$(basename "$bundle")" == "Kello_Kello.bundle" ]] && continue
    ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
shopt -u nullglob

# Bundle.main resolves localizations from .lproj folders directly under Contents/Resources,
# not from inside a nested resource bundle, so Kello's own bundle is unpacked there instead.
# The string catalogs arrive compiled (Localizable.strings, .stringsdict, InfoPlist.strings);
# the bundle keeps them in Contents/Resources, or at its root in a flat layout.
KELLO_BUNDLE="$BIN_DIR/Kello_Kello.bundle"
if [[ -d "$KELLO_BUNDLE" ]]; then
    shopt -s nullglob
    for lproj in "$KELLO_BUNDLE"/Contents/Resources/*.lproj "$KELLO_BUNDLE"/*.lproj; do
        ditto "$lproj" "$APP/Contents/Resources/$(basename "$lproj")"
    done
    shopt -u nullglob
fi
if [[ ! -f "$APP/Contents/Resources/it.lproj/Localizable.strings" ]]; then
    echo "error: compiled Italian strings missing from $APP" >&2
    exit 1
fi

# Ad-hoc identities (SIGN_IDENTITY=-, for local builds without a Developer ID cert) can't
# carry a secure timestamp.
SIGN_FLAGS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN_FLAGS+=(--timestamp)
fi

# Sign inside-out, following Sparkle's documented order: its XPC services and helper
# tools first, then the framework itself, then the app. Kello's own entitlements only
# apply to the app; Sparkle's pieces keep their own.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
for item in \
    "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
    "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
    "$FRAMEWORK/Versions/B/Autoupdate" \
    "$FRAMEWORK/Versions/B/Updater.app"; do
    [[ -e "$item" ]] && codesign "${SIGN_FLAGS[@]}" "$item"
done
codesign "${SIGN_FLAGS[@]}" "$FRAMEWORK"

codesign "${SIGN_FLAGS[@]}" --entitlements "$ROOT/Resources/Kello.entitlements" "$APP"

echo "Built $APP"
