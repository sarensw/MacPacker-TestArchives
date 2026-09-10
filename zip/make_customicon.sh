#!/bin/bash
#
# Rebuilds `customicon.zip` — the fixture for a folder with a custom icon.
#
# A folder that shows a custom picture in Finder is three separate pieces of
# metadata, and losing any one of them loses the icon:
#
#   Icon\r                  a zero-byte file inside the folder. Its data fork is
#                           empty; the picture lives in its resource fork
#                           (`com.apple.ResourceFork`) as an `icns`.
#   Icon\r FinderInfo       `com.apple.FinderInfo` with kIsInvisible (0x4000) in
#                           the flags at offset 8. This is what keeps `Icon\r`
#                           out of sight. Without it the file shows up in Finder
#                           as `Icon?`, which is how MacPacker issue #216 was
#                           reported — Finder renders the trailing carriage
#                           return as a question mark.
#   folder FinderInfo       `com.apple.FinderInfo` on the folder itself, with
#                           kHasCustomIcon (0x0400) at offset 8. Finder only
#                           looks for `Icon\r` when this bit is set, so restoring
#                           the icon file alone still leaves the folder generic.
#
# None of it survives a plain zip: extended attributes and resource forks have
# no place in the format, so they travel as AppleDouble sidecars, the same way
# `appledouble.zip` describes. The folder's own sidecar is the half that is easy
# to miss, and the reason this case earns a fixture: restoring the icon file
# alone leaves the folder generic, which is what issue #216 looks like.
#
# The shape below is Finder's. Compressing a folder with a custom icon through
# Finder's "Compress" produces exactly this — the folder's entry, its sidecar at
# the root of the `__MACOSX/` mirror, and a sidecar for each file that has
# metadata of its own. (`ditto -c -k --sequesterRsrc --keepParent` is often said
# to be the same thing and is not: pointed at a folder it writes no sidecar for
# that folder, so do not use it to reason about what Finder stores.)
#
# The entries:
#
#   CustomFolder/                       the directory entry, and not a formality:
#                                       XADMaster (so The Unarchiver, and our own
#                                       XAD engine) refuses an archive whose
#                                       folder sidecar describes a directory the
#                                       archive never declares. It tries to write
#                                       the metadata to a file that is not there
#                                       and gives up on the whole extraction with
#                                       `xadError(11, "Opening file failed")`.
#                                       Finder always writes this entry; so does
#                                       MacPacker. Measured with two archives
#                                       differing in nothing else.
#   CustomFolder/note.txt               ordinary content, so the folder is not
#                                       nothing but metadata
#   CustomFolder/Icon\r                 stored bare: zero bytes, no attributes.
#                                       Everything a test asserts on has to
#                                       arrive through a sidecar, or it proves
#                                       nothing about the folding.
#   __MACOSX/._CustomFolder             the folder's own FinderInfo. A sidecar at
#                                       the root of the mirror describing a
#                                       directory — the arrangement Finder never
#                                       writes.
#   __MACOSX/CustomFolder/._Icon\r      the icon file's FinderInfo and resource
#                                       fork.
#
# Expect after extraction: no `__MACOSX` left, no `._` file left, `Icon\r` back
# and invisible with its resource fork, `CustomFolder` carrying kHasCustomIcon —
# and the folder showing the picture again. See MacPacker issues #216 and #191.
#
# The entry name is the other half of the fixture. `Icon\r` ends in a carriage
# return: legal in a zip entry name, and awkward everywhere afterwards. Stock
# Info-ZIP `unzip` silently drops it and writes a file called `Icon`, which is
# why this script does not round-trip through `unzip` to get at the bytes it
# needs.
#
# The AppleDouble bytes are not hand-written. `copyfile(3)` with COPYFILE_PACK
# serializes a file's metadata into exactly the sidecar `ditto` writes — same
# call, one step instead of three — and the extraction path uses the same call
# in reverse to fold it back. The resource fork is embedded as base64 rather
# than generated because generating it needs AppKit (`NSWorkspace.setIcon`) and
# its `icns` encoder is free to change between macOS releases; these bytes are
# one 32x32 disc, encoded once, so a rebuild stays byte-identical.
#
# Entry dates are fixed and entries are added by explicit argument, so a rebuild
# produces a byte-identical archive with a stable entry order.
#
# Requires: clang, zip, xattr, chflags (all stock Xcode / macOS).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="customicon.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# FinderInfo is 32 bytes. For a file the flags sit at offset 8 of an FInfo
# (kIsInvisible = 0x4000); for a folder at offset 8 of a DInfo, past the window
# rectangle (kHasCustomIcon = 0x0400). Everything else stays zero — a fixture
# that also carried a window position or a Finder label would make a failure
# harder to read, not more realistic.
FINDERINFO_INVISIBLE="00 00 00 00 00 00 00 00 40 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
FINDERINFO_CUSTOMICON="00 00 00 00 00 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"

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

# --- rebuild the folder the fixture is made from ------------------------------
SRC="$BUILD/CustomFolder"
mkdir -p "$SRC"

printf 'A folder is more than its icon.\n' > "$SRC/note.txt"

ICON=$'Icon\r'
: > "$SRC/$ICON"
base64 -D > "$SRC/$ICON/..namedfork/rsrc" <<'RSRC'
AAABAAAABH4AAAN+AAAAMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA3ppY25zAAADemljMDUAAAIQQVJHQqkAhf+S
AIv/jgCN/4sAkf+IAJP/hgCV/4UAlf+EAJf/ggCZ/4EAmf+BAJn/gACb/wEAAJv/AQAAm/8BAACb
/wEAAJv/AQAAm/8BAACb/wEAAJv/gACZ/4EAmf+BAJn/ggCX/4QAlf+FAJX/hgCT/4gAkf+LAI3/
jgCL/5IAhf+pAKkAhf+SAIv/jgCN/4sAkf+IAJP/hgCV/4UAlf+EAJf/ggCZ/4EAmf+BAJn/gACb
/wEAAJv/AQAAm/8BAACb/wEAAJv/AQAAm/8BAACb/wEAAJv/gACZ/4EAmf+BAJn/ggCX/4QAlf+F
AJX/hgCT/4gAkf+LAI3/jgCL/5IAhf+pAKkAhS2SAIstjgCNLYsAkS2IAJMthgCVLYUAlS2EAJct
ggCZLYEAmS2BAJktgACbLQEAAJstAQAAmy0BAACbLQEAAJstAQAAmy0BAACbLQEAAJstgACZLYEA
mS2BAJktggCXLYQAlS2FAJUthgCTLYgAkS2LAI0tjgCLLZIAhS2pAKkAhW6SAItujgCNbosAkW6I
AJNuhgCVboUAlW6EAJduggCZboEAmW6BAJlugACbbgEAAJtuAQAAm24BAACbbgEAAJtuAQAAm24B
AACbbgEAAJtugACZboEAmW6BAJluggCXboQAlW6FAJVuhgCTbogAkW6LAI1ujgCLbpIAhW6pAGlj
MTEAAAFiiVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAERl
WElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAIKAD
AAQAAAABAAAAIAAAAACshmLzAAAAxElEQVRYCe2VyxGAIAwFxX5szWJszYJ0ovMYQGJAPvGAlxzQ
7PLC4DQpPyaXfyzr8faN2besnkkvS1BOKEVGFPgKh5QkwQqUgiGAyolEBWrD3yQeAq3gnMSMBa3q
JdB699ikex6sQC94KKE+AnWBawS943fHoJ7AEBgJjATGVax+BuwI6HrsdSVHf8e4n1tLuHBi/msE
rVMId0887wxAgGrtUcTgxGEFaJGeUhEOfHdPECiRkODUW0wApqhSIilQ9PpFPQGgokQsRQ9Y4QAA
AABJRU5ErkJgggAAAQAAAAR+AAADfgAAADIDAAAACwAAAAAcADIAAGljbnMAAAAKv7n//wAAAAAB
AAAA
RSRC

xattr -wx com.apple.FinderInfo "$FINDERINFO_INVISIBLE" "$SRC/$ICON"
chflags hidden "$SRC/$ICON"
xattr -wx com.apple.FinderInfo "$FINDERINFO_CUSTOMICON" "$SRC"

# `com.apple.provenance` is added by macOS per machine and would make the
# sidecar bytes differ between rebuilds.
xattr -d com.apple.provenance "$SRC" 2>/dev/null || true
xattr -d com.apple.provenance "$SRC/$ICON" 2>/dev/null || true

# --- assemble the archive tree ------------------------------------------------
STAGE="$BUILD/stage"
mkdir -p "$STAGE/CustomFolder" "$STAGE/__MACOSX/CustomFolder"

cp "$SRC/note.txt" "$STAGE/CustomFolder/note.txt"
: > "$STAGE/CustomFolder/$ICON"
"$BUILD/pack" "$SRC" "$STAGE/__MACOSX/._CustomFolder"
"$BUILD/pack" "$SRC/$ICON" "$STAGE/__MACOSX/CustomFolder/._$ICON"

# A sidecar that carries nothing is indistinguishable from a missing one, and
# would make every assertion below pass for the wrong reason.
grep -q "$(printf 'icns')" "$STAGE/__MACOSX/CustomFolder/._$ICON" \
    || { echo "the Icon sidecar carries no resource fork" >&2; exit 1; }

# --- fixed dates, so a rebuild is byte-identical ------------------------------
find "$STAGE" -exec touch -t 202608190900 {} +

rm -f "$OUT"
# -X: no uid/gid, no extended attributes. Without it macOS zip would sequester
# metadata into a __MACOSX/ tree of its own, on top of the one staged here.
(cd "$STAGE" && zip -q -X "$OLDPWD/$OUT" \
    "CustomFolder/" \
    "CustomFolder/note.txt" \
    "CustomFolder/$ICON" \
    "__MACOSX/._CustomFolder" \
    "__MACOSX/CustomFolder/._$ICON")

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
zipinfo -1 "$OUT" | cat -v
