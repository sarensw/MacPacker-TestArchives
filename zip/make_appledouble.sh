#!/bin/bash
#
# Rebuilds `appledouble.zip` — the fixture for AppleDouble sidecar handling.
#
# A macOS zip can carry a file's extended attributes and resource fork in a
# sibling file named `._name`, in AppleDouble format. Archive Utility unpacks
# such a sidecar into the real file and removes it; an extractor that writes it
# out as an ordinary file adds a file to the tree. Inside a signed `.app` that
# breaks the code-signature seal and macOS calls the app damaged — MacPacker
# issue #189, where the 7-Zip engine left `._wd-logo120.png` behind.
#
# The trap is that `._` is a naming convention, not a reservation: a file may
# legitimately be named that way and hold anything. So the fixture pairs the
# real thing with decoys an extractor must not touch, and it puts them in one
# archive, because the bug is only interesting when a single pass handles them
# all. Five cases:
#
#   payload/Contents/Resources/icon.png    + ._icon.png     (sidecar stored FIRST)
#   payload/Contents/MacOS/helper          + ._helper       (sidecar stored SECOND)
#       The real case, in both entry orders. Each sidecar is a genuine
#       AppleDouble produced by ditto, carrying a resource fork and a
#       `com.macpacker.test` xattr; each target is stored with no xattrs of its
#       own, so an extractor can only produce them by unpacking the sidecar.
#       Expect for both: sidecar gone, resource fork and xattr on the target.
#
#       Both orders are deliberate, and this is where the fixture asks for more
#       than Archive Utility delivers. Archive Utility unpacks a sidecar the
#       moment it reads it, so it handles `helper` and gives up on `icon.png`,
#       leaving `._icon.png` on disk. Entry order carries no meaning in zip, and
#       sidecar-first is not a corner case — `._x` sorts before `x`, so it is
#       what plain `zip -r` emits over a tree with inline sidecars. An extractor
#       that resolves sidecars after the entries are written gets both right.
#
#   payload/notadouble.txt                 + ._notadouble.txt
#       A decoy. Plain UTF-8 text that is not AppleDouble, and its sibling
#       *does* exist — so the only thing separating it from the cases above is
#       its content. A name-based extractor deletes it. Expect: still there,
#       byte-identical.
#
#   payload/._orphan.bin
#       A genuine AppleDouble with no sibling at all. `copyfile(3)` with
#       COPYFILE_UNPACK does not mind a missing destination: it creates it,
#       conjuring a file the archive never contained. Expect: still there, and
#       no `payload/orphan.bin`.
#
# The AppleDouble bytes are not hand-written — `ditto -c -k --sequesterRsrc`
# emits them into a `__MACOSX/` tree, which this script unpacks and moves inline
# where the bug actually occurs. That keeps the fixture honest: it is what macOS
# itself produces, not our idea of the format.
#
# Entry dates are fixed and entries are added by explicit argument, so a rebuild
# produces a byte-identical archive with a stable entry order.
#
# Requires: ditto, zip, unzip (all stock macOS).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="appledouble.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

STAGE="$BUILD/stage/payload"
mkdir -p "$STAGE/Contents/Resources" "$STAGE/Contents/MacOS"

# --- the file whose metadata gets sequestered ---------------------------------
# A 1x1 transparent PNG. Small, valid, and nothing but pixels.
base64 -d > "$BUILD/seed" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
PNG

printf 'RESOURCE-FORK-PAYLOAD' > "$BUILD/seed/..namedfork/rsrc"
xattr -w com.macpacker.test appledouble-fixture "$BUILD/seed"

# Let ditto serialize those into a real AppleDouble under __MACOSX/, then take
# just that file. `com.apple.provenance` is added by macOS per machine and would
# make the bytes differ between rebuilds, so it is cleared before packing.
xattr -d com.apple.provenance "$BUILD/seed" 2>/dev/null || true
mkdir -p "$BUILD/seeddir" && cp -p "$BUILD/seed" "$BUILD/seeddir/seed"
ditto -c -k --sequesterRsrc --keepParent "$BUILD/seeddir" "$BUILD/sequestered.zip"
unzip -q "$BUILD/sequestered.zip" -d "$BUILD/unsequestered"
SIDECAR="$BUILD/unsequestered/__MACOSX/seeddir/._seed"
[ -s "$SIDECAR" ] || { echo "ditto produced no AppleDouble sidecar" >&2; exit 1; }

# --- assemble the archive tree ------------------------------------------------
# Sidecars go next to their file, not into __MACOSX/: that inline form is what
# issue #189 tripped over, and it is the one that lands inside the bundle. The
# targets go in bare — everything the test asserts on has to arrive through the
# sidecar, or the assertion proves nothing.
cp "$BUILD/seed" "$STAGE/Contents/Resources/icon.png"
xattr -c "$STAGE/Contents/Resources/icon.png"
cp "$SIDECAR" "$STAGE/Contents/Resources/._icon.png"

printf 'not a real Mach-O, just a target for its sidecar\n' > "$STAGE/Contents/MacOS/helper"
cp "$SIDECAR" "$STAGE/Contents/MacOS/._helper"

# Decoy 1: not AppleDouble, but its sibling exists.
printf 'A real file that merely starts with dot-underscore.\n' > "$STAGE/._notadouble.txt"
printf 'The sibling that makes the decoy tempting.\n' > "$STAGE/notadouble.txt"

# Decoy 2: genuine AppleDouble, no sibling. Same bytes as the sidecars above —
# what makes it a decoy is the missing target, not the content.
cp "$SIDECAR" "$STAGE/._orphan.bin"

# --- fixed dates, so a rebuild is byte-identical ------------------------------
find "$BUILD/stage" -exec touch -t 202608190900 {} +

rm -f "$OUT"
# Entries are named one by one rather than with -r, because their order is part
# of the fixture: `._icon.png` before its target, `._helper` after its own.
# -X: no uid/gid, no extended attributes. Without it macOS zip would sequester
# metadata into a __MACOSX/ tree of its own and the fixture would test that
# instead.
(cd "$BUILD/stage" && zip -q -X "$OLDPWD/$OUT" \
    payload/Contents/Resources/._icon.png \
    payload/Contents/Resources/icon.png \
    payload/Contents/MacOS/helper \
    payload/Contents/MacOS/._helper \
    payload/notadouble.txt \
    payload/._notadouble.txt \
    payload/._orphan.bin)

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
unzip -l "$OUT"
