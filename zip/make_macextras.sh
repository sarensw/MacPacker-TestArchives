#!/bin/bash
#
# Rebuilds `macextras.zip` — the fixture for Finder tags and Finder comments.
#
# Both are ordinary extended attributes under long names, so an extractor that
# folds AppleDouble back onto its file already carries them; there is no separate
# mechanism to get right. They get a fixture of their own anyway, because they
# are what a *user* notices missing, and because nothing else in the corpus shows
# what they actually look like on disk:
#
#   com.apple.metadata:_kMDItemUserTags        a binary plist holding an array of
#                                              "Label\nColorNumber" strings — the
#                                              number is Finder's colour index,
#                                              and 0 means a tag with no colour.
#   com.apple.metadata:kMDItemFinderComment    a binary plist holding one string,
#                                              the text from Get Info.
#
# Real binary plists rather than made-up bytes, so a test can decode them and a
# person can drop the extracted file into Finder and see the tag.
#
# One caveat the fixture cannot fix, worth knowing before trusting a green test
# about comments: Finder also keeps the comment in the enclosing folder's
# `.DS_Store`, and Get Info reads that copy. Restoring the attribute is all an
# archiver can do — the comment can be back on the file and still show up blank.
#
#   tagged.txt      + __MACOSX/._tagged.txt
#   commented.txt   + __MACOSX/._commented.txt
#
# Expect after extraction: no `__MACOSX` and no `._` file left, and both
# attributes back on their files byte for byte.
#
# Sidecars are packed with `copyfile(3)` rather than round-tripped through
# `ditto` and `unzip`, for the same reason `make_customicon.sh` does it: it is
# one step instead of three, and it is the same call `ditto` itself makes.
#
# Entry dates are fixed and entries are added by explicit argument, so a rebuild
# produces a byte-identical archive with a stable entry order.
#
# Requires: clang, plutil, xxd, zip, xattr (all stock Xcode / macOS).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="macextras.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# --- the sidecar writer -------------------------------------------------------
cat > "$BUILD/pack.c" <<'PACK'
#include <copyfile.h>
#include <stdio.h>
// argv[1] -> argv[2], as AppleDouble. COPYFILE_PACK without COPYFILE_DATA
// serializes the metadata alone, which is what a sidecar holds.
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    if (copyfile(argv[1], argv[2], NULL,
                 COPYFILE_PACK | COPYFILE_XATTR | COPYFILE_ACL) != 0) {
        perror("copyfile");
        return 1;
    }
    return 0;
}
PACK
clang -Os -o "$BUILD/pack" "$BUILD/pack.c"

# Writes a binary plist from the XML on stdin onto `$2` as extended attribute $1.
set_plist_xattr() {
    local name="$1" file="$2"
    plutil -convert binary1 -o "$BUILD/value.plist" -- -
    xattr -wx "$name" "$(xxd -p "$BUILD/value.plist" | tr -d '\n')" "$file"
}

SRC="$BUILD/src"
mkdir -p "$SRC"

# --- a file with two Finder tags ----------------------------------------------
# "Red" is one of Finder's own, colour 6. "MacPacker" is a plain label with no
# colour, which is the form a user's own tag takes.
printf 'This file carries two Finder tags.\n' > "$SRC/tagged.txt"
set_plist_xattr "com.apple.metadata:_kMDItemUserTags" "$SRC/tagged.txt" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <string>Red
6</string>
  <string>MacPacker
0</string>
</array>
</plist>
PLIST

# --- a file with a Finder comment ---------------------------------------------
printf 'This file carries a Finder comment.\n' > "$SRC/commented.txt"
set_plist_xattr "com.apple.metadata:kMDItemFinderComment" "$SRC/commented.txt" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<string>Kept in Get Info, and in the folder's .DS_Store.</string>
</plist>
PLIST

# `com.apple.provenance` is added by macOS per machine and would make the sidecar
# bytes differ between rebuilds. `com.apple.TextEncoding` arrives the same way on
# anything written by a Cocoa tool.
for file in "$SRC"/*; do
    xattr -d com.apple.provenance "$file" 2>/dev/null || true
    xattr -d com.apple.TextEncoding "$file" 2>/dev/null || true
done

# --- assemble the archive tree ------------------------------------------------
STAGE="$BUILD/stage"
mkdir -p "$STAGE/__MACOSX"

for name in tagged.txt commented.txt; do
    cp "$SRC/$name" "$STAGE/$name"
    xattr -c "$STAGE/$name"
    "$BUILD/pack" "$SRC/$name" "$STAGE/__MACOSX/._$name"
done

# The targets are stored bare, so anything a test finds on them can only have
# come through a sidecar.
grep -q "_kMDItemUserTags" "$STAGE/__MACOSX/._tagged.txt" \
    || { echo "the tagged.txt sidecar carries no tags" >&2; exit 1; }
grep -q "kMDItemFinderComment" "$STAGE/__MACOSX/._commented.txt" \
    || { echo "the commented.txt sidecar carries no comment" >&2; exit 1; }

# --- fixed dates, so a rebuild is byte-identical ------------------------------
find "$STAGE" -exec touch -t 202608190900 {} +

rm -f "$OUT"
# -X: no uid/gid, no extended attributes. Without it macOS zip would sequester
# metadata into a __MACOSX/ tree of its own, on top of the one staged here.
(cd "$STAGE" && zip -q -X "$OLDPWD/$OUT" \
    tagged.txt \
    __MACOSX/._tagged.txt \
    commented.txt \
    __MACOSX/._commented.txt)

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
zipinfo -1 "$OUT"
