#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIGN_IDENTITY="${KELLO_SIGN_IDENTITY:-Developer ID Application}"
APP="$ROOT/build/Kello.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Kello" "$APP/Contents/MacOS/Kello"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
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
SIGN_FLAGS=(--force --options runtime --entitlements "$ROOT/Resources/Kello.entitlements" --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN_FLAGS+=(--timestamp)
fi

codesign "${SIGN_FLAGS[@]}" "$APP"

echo "Built $APP"
