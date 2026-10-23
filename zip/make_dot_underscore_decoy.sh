#!/bin/bash
#
# Rebuilds `dotUnderscoreDecoy.zip` — a file that merely starts with `._`,
# beside the file that name points at, both at the top of the archive.
#
# `._name` is how macOS names an AppleDouble sidecar, and MacPacker takes an
# entry for a sidecar by its name alone, without reading it: the listing leaves
# `._notadouble.txt` out as the sidecar of `notadouble.txt`. Extraction then
# finds plain text where AppleDouble belongs and writes it out as the file it
# is. So the archive lists one top-level item, which smart extraction puts into
# the destination as it is, without a folder around it — and Foundation's
# directory listings skip every name that starts with `._`. An extractor that
# stages the files and moves out what such a listing returns leaves the decoy
# behind, and deletes it with the staging folder: MacPacker PR #371.
#
# `appledouble.zip` holds the same decoy, but inside `payload/`, and a folder
# moves out as a whole.
#
# Entry dates are fixed and entries are added by explicit argument, so a
# rebuild produces a byte-identical archive with a stable entry order.
#
# Requires: zip, unzip (stock macOS).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="dotUnderscoreDecoy.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

printf 'The sibling that makes the decoy tempting.\n' > "$BUILD/notadouble.txt"
printf 'A real file that merely starts with dot-underscore.\n' > "$BUILD/._notadouble.txt"
touch -t 202610230900 "$BUILD/notadouble.txt" "$BUILD/._notadouble.txt"

rm -f "$OUT"
# -X: no uid/gid, no extended attributes. Without it macOS zip would sequester
# metadata into a __MACOSX/ tree of its own.
(cd "$BUILD" && zip -q -X "$OLDPWD/$OUT" notadouble.txt ._notadouble.txt)

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
unzip -l "$OUT"
