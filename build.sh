#!/bin/sh
# Builds AirChecker.app (menu bar app) next to this script.
set -e
cd "$(dirname "$0")"
APP=AirChecker.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O AirChecker.swift -o "$APP/Contents/MacOS/AirChecker"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>AirChecker</string>
  <key>CFBundleIdentifier</key><string>com.family-village.airchecker</string>
  <key>CFBundleExecutable</key><string>AirChecker</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"
echo "Built $APP"
