#!/bin/bash
#
#  Сборка релиза: универсальный бинарник (Apple Silicon + Intel), бандл
#  «Cerberus DNS.app» с подписью ad hoc и архив для GitHub Releases.
#
#    bash tools/release.sh            # dist/CerberusDNS-<версия>-macOS.zip
#
#  Ничего не публикует. Версия берётся из Contents/Info.plist
#  (CFBundleShortVersionString); тег релиза на GitHub — «v<версия>».
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/Contents/Resources"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Contents/Info.plist")"
DIST="$ROOT/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/Cerberus DNS.app"

# Список исходников — тот же, что в build.sh, в том же порядке.
SOURCES=()
while IFS= read -r f; do SOURCES+=("$RES/$f"); done < <(grep -oE '"\$HERE/src/[^"]+"' "$RES/build.sh" | sed 's/"\$HERE\///; s/"$//')

echo "Релиз Cerberus DNS $VERSION"
for arch in arm64 x86_64; do
  echo "  компиляция $arch…"
  swiftc -O -target "$arch-apple-macos12.0" "${SOURCES[@]}" -o "$WORK/dnsblock-$arch"
done

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$WORK/dnsblock-arm64" "$WORK/dnsblock-x86_64" -output "$APP/Contents/MacOS/dnsblock"
cp "$ROOT/Contents/Info.plist" "$ROOT/Contents/PkgInfo" "$APP/Contents/"
cp "$RES/engine.sh" "$RES/AppIcon.icns" "$RES/AppIcon.png" "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/dnsblock" "$APP/Contents/Resources/engine.sh"
xattr -cr "$APP"

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p "$DIST"
ZIP="$DIST/CerberusDNS-$VERSION-macOS.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "  архитектуры: $(lipo -archs "$APP/Contents/MacOS/dnsblock")"
echo "  архив: $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "  sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
