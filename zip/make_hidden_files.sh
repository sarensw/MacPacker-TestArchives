#!/bin/bash
#
# Rebuilds `hiddenFiles.zip` — a folder the way a Mac leaves one, with the files
# Finder never shows still in it: a `.DS_Store` at the top and one in a
# subfolder, and a dot folder with an ordinary name inside.
#
#   readme.txt
#   .DS_Store
#   folder/notes.txt
#   folder/.DS_Store
#   .git/HEAD
#
# Finder hides every name that starts with a dot, and an archive viewer that
# lists them shows a `.DS_Store` the user has never seen next to their files —
# MacPacker issue #304. `.git/HEAD` is the case a search runs into: its own name
# is not hidden, the folder it is in is.
#
# The `.DS_Store` files hold a line of text, not Finder's binary format: only
# their names matter here.
#
# Entry dates are fixed and entries are added by explicit argument, so a
# rebuild produces a byte-identical archive with a stable entry order.
#
# Requires: zip, unzip (stock macOS).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="hiddenFiles.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

mkdir "$BUILD/folder" "$BUILD/.git"
printf 'A file anyone can see.\n' > "$BUILD/readme.txt"
printf 'Finder keeps its view settings here.\n' > "$BUILD/.DS_Store"
printf 'Another file anyone can see.\n' > "$BUILD/folder/notes.txt"
printf 'Finder keeps its view settings here.\n' > "$BUILD/folder/.DS_Store"
printf 'ref: refs/heads/main\n' > "$BUILD/.git/HEAD"
(cd "$BUILD" && chmod 644 readme.txt .DS_Store folder/notes.txt folder/.DS_Store .git/HEAD && chmod 755 folder .git \
    && touch -t 202610260900 readme.txt .DS_Store folder/notes.txt folder/.DS_Store .git/HEAD folder .git)

rm -f "$OUT"
# -X: no uid/gid, no extended attributes. Without it macOS zip would sequester
# metadata into a __MACOSX/ tree of its own.
(cd "$BUILD" && zip -q -X "$OLDPWD/$OUT" \
    readme.txt .DS_Store folder/ folder/notes.txt folder/.DS_Store .git/ .git/HEAD)

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
unzip -l "$OUT"
