#!/bin/bash
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(cd "$HERE/../.." && pwd)"

echo "Сборка Cerberus DNS $(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist" 2>/dev/null)..."

# Каталога с бинарником нет в git: на чистой копии его нужно создать.
mkdir -p "$APP_DIR/Contents/MacOS"

swiftc -O -target arm64-apple-macos12.0 \
  "$HERE/src/AppPaths.swift" \
  "$HERE/src/Localization.swift" \
  "$HERE/src/EngineText.swift" \
  "$HERE/src/Updates.swift" \
  "$HERE/src/Models.swift" \
  "$HERE/src/Theme.swift" \
  "$HERE/src/DNSManager.swift" \
  "$HERE/src/Views/CustomVectorIcons.swift" \
  "$HERE/src/Views/CommandPaletteView.swift" \
  "$HERE/src/Views/MenuBarPopoverView.swift" \
  "$HERE/src/Views/SettingsView.swift" \
  "$HERE/src/Views/DashboardView.swift" \
  "$HERE/src/Views/QueryInspectorView.swift" \
  "$HERE/src/Views/ProfilesView.swift" \
  "$HERE/src/Views/EmbeddedVPNCard.swift" \
  "$HERE/src/Views/VPNView.swift" \
  "$HERE/src/Views/AddNodeSheet.swift" \
  "$HERE/src/Views/DiagnosticsView.swift" \
  "$HERE/src/Views/RulesView.swift" \
  "$HERE/src/Views/ToolsView.swift" \
  "$HERE/src/Views/FAQView.swift" \
  "$HERE/src/Views/OnboardingView.swift" \
  "$HERE/src/Views/UpdateBanner.swift" \
  "$HERE/src/Views/MainView.swift" \
  "$HERE/src/AppMain.swift" \
  -o "$APP_DIR/Contents/MacOS/dnsblock"

chmod +x "$APP_DIR/Contents/MacOS/dnsblock"
chmod +x "$HERE/engine.sh"

echo "✔ Сборка успешно завершена: $APP_DIR/Contents/MacOS/dnsblock"
