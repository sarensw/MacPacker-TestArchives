#!/bin/bash
#
# Rebuilds `appbundle.7z` — the 7z twin of `../zip/appbundle.zip`: the smallest
# tree that shows whether an extractor keeps a Unix mode. An executable stored
# with mode 0755 and a symbolic link beside it, under the folder shape of a
# macOS app bundle, which is where losing either is fatal rather than cosmetic.
#
# Having both formats is the point. Zip carries a POSIX-permissions field of its
# own; 7z has none, and keeps the mode in the high 16 bits of the Windows
# attribute word, flagged with FILE_ATTRIBUTE_UNIX_EXTENSION (0x8000). An
# extractor that reads only the dedicated field sees nothing at all here — which
# is MacPacker issue #243.
#
# `-snl` stores symbolic links as links instead of following them; `-mtc=off`
# leaves out creation times, which are the machine's and not reproducible.
#
# Requires: 7zz (7-Zip 21+; `brew install sevenzip`).
#
set -euo pipefail

cd "$(dirname "$0")"

OUT="$PWD/appbundle.7z"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

MACOS="$BUILD/payload/Contents/MacOS"
mkdir -p "$MACOS"

printf '#!/bin/sh\nexit 0\n' > "$MACOS/bin"
chmod 755 "$MACOS/bin"
ln -s bin "$MACOS/link"

# Same fixed date as ../zip/appbundle.zip, so a rebuild is byte-identical.
STAMP="202607121157.46"
touch -h -t "$STAMP" "$MACOS/link"
touch -t "$STAMP" "$MACOS/bin" "$MACOS" "$BUILD/payload/Contents" "$BUILD/payload"

rm -f "$OUT"
cd "$BUILD"
7zz a -snl -mtc=off "$OUT" payload > /dev/null

echo "wrote appbundle.7z ($(du -h "$OUT" | cut -f1))"
