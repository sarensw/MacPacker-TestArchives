#!/bin/bash
#
# Rebuilds `minimalApp.zip` — a real, launchable macOS app bundle compressed the
# way Finder's "Compress" does it (`ditto -c -k --sequesterRsrc --keepParent`).
#
# Fixture for issue #175: extracting the `.app` folder out of such a zip must
# produce one `MinimalApp.app` in the destination, not its loose innards. The
# bundle therefore deliberately repeats leaf names across depths
# (`Resources`, `Info.plist`, `Mini`) so any extractor that flattens the subtree
# collides on a name instead of failing silently.
#
# Requires: clang, codesign, ditto (all stock Xcode / macOS).
#
set -euo pipefail

cd "$(dirname "$0")"

OUT="minimalApp.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

APP="$BUILD/MinimalApp.app"
FW="$APP/Contents/Frameworks/Mini.framework"

mkdir -p "$APP/Contents/MacOS" \
         "$APP/Contents/Resources/en.lproj" \
         "$FW/Versions/A/Resources"

cat > "$BUILD/main.c" <<'EOF'
int main(void) { return 0; }
EOF

cat > "$BUILD/mini.c" <<'EOF'
int mini_answer(void) { return 42; }
EOF

clang -Os -o "$APP/Contents/MacOS/MinimalApp" "$BUILD/main.c"
clang -Os -dynamiclib \
      -install_name "@rpath/Mini.framework/Versions/A/Mini" \
      -o "$FW/Versions/A/Mini" "$BUILD/mini.c"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>MinimalApp</string>
	<key>CFBundleIdentifier</key>
	<string>com.macpacker.testarchives.minimalapp</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>MinimalApp</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
</dict>
</plist>
EOF

cat > "$FW/Versions/A/Resources/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Mini</string>
	<key>CFBundleIdentifier</key>
	<string>com.macpacker.testarchives.mini</string>
	<key>CFBundleName</key>
	<string>Mini</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
EOF

printf '"greeting" = "hello";\n' > "$APP/Contents/Resources/en.lproj/InfoPlist.strings"

# Framework version symlinks — the canonical macOS shape, and a second source of
# repeated leaf names.
ln -s A "$FW/Versions/Current"
ln -s Versions/Current/Mini "$FW/Mini"
ln -s Versions/Current/Resources "$FW/Resources"

# Ad-hoc signature so the bundle carries a real _CodeSignature/CodeResources,
# like every app a user would actually download.
codesign --force --sign - "$FW/Versions/A" >/dev/null 2>&1
codesign --force --sign - "$APP" >/dev/null 2>&1

rm -f "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT"

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
