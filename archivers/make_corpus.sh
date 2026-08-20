#!/bin/bash
#
# Rebuilds the real-world corpus: one app bundle, archived by the tools people
# actually use. Source is the bundle inside `../zip/minimalApp.zip`, so the trees
# are identical and any difference between the archives is the archiver's doing.
#
# `keka.zip` is not built here — Keka's CLI will not run outside its app bundle,
# so that one is made by hand through the Keka UI. See README.md. Its output is
# not the same as `7zz`'s despite Keka being built on 7-Zip: it keeps the
# framework symlinks that `7zz -tzip` does not.
#
# Not byte-reproducible: the source bundle is compiled and signed. Rebuildable.
#
# Requires: ditto, unzip, zip (stock macOS), 7zz (Homebrew p7zip).
#
set -euo pipefail

cd "$(dirname "$0")"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

ditto -x -k ../zip/minimalApp.zip "$BUILD/src"
APP="$BUILD/src/MinimalApp.app"
[ -d "$APP" ] || { echo "no MinimalApp.app in ../zip/minimalApp.zip" >&2; exit 1; }

# Metadata worth preserving. Resource forks are left out on purpose: inside a
# signed bundle codesign rejects them as "detritus", so they cannot be part of a
# fixture whose point is that it still verifies.
xattr -w com.macpacker.appmeta bundle-level "$APP"
xattr -w com.macpacker.filemeta plist-level "$APP/Contents/Info.plist"

rm -f finder_compress.zip ditto_inline.zip infozip.zip sevenzip.zip

# Finder's "Compress": sidecars sequestered into a __MACOSX/ mirror.
ditto -c -k --sequesterRsrc --keepParent "$APP" finder_compress.zip

# Same tool without sequestering: sidecars inline, inside the bundle.
ditto -c -k --keepParent "$APP" ditto_inline.zip

# Info-ZIP, as shipped with macOS. -y keeps symlinks; xattrs are dropped.
(cd "$BUILD/src" && zip -q -r -y "$OLDPWD/infozip.zip" MinimalApp.app)

# 7-Zip's zip writer.
(cd "$BUILD/src" && 7zz a -tzip -bso0 -bsp0 "$OLDPWD/sevenzip.zip" MinimalApp.app >/dev/null)

for f in finder_compress.zip ditto_inline.zip infozip.zip sevenzip.zip; do
    printf '%-22s %6s bytes  %3s entries  %3s sidecars\n' "$f" "$(stat -f%z "$f")" \
        "$(unzip -l "$f" | tail -1 | awk '{print $2}')" "$(unzip -l "$f" | grep -c '/\._' || true)"
done
