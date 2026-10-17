#!/bin/bash
#
# Rebuilds two spanned zips in Zip64 format, written by zip.js, the JavaScript
# library behind many web apps that zip in the browser:
#
#   split_zipjs64.z01, .z02, .zip
#   split_zipjs64comment.z01, .z02, .zip
#
# The last piece of a spanned set says which piece it is in its end of central
# directory record: "number of this disk", one less than the number of pieces.
# Info-ZIP's `zip -s` writes that number there even in Zip64 format (see
# `split_pk.zip` for the plain kind). zip.js writes 0xFFFF instead, as Zip64
# allows — "see the Zip64 end of central directory record" — and the real
# number only there. So the 0xFFFF alone does not say whether a file is a
# piece of a set: `zipstreamer64.zip` has the same 0xFFFF and is a single
# file. Only the Zip64 record tells the two apart, and this set is the case
# where it says "the last of three" — the counterpart to MacPacker issue #348,
# where reading the 0xFFFF as a disk number made a single file look like a set.
#
# The second set adds a zip comment of the greatest length a zip allows,
# 65,535 bytes. The comment comes last in the file, right after the end of
# central directory record, and the Zip64 records sit right before that one:
# 76 bytes further from the end than a reader looks that reaches back just far
# enough for the end record and the longest comment. Such a reader finds the
# 0xFFFF and nothing to settle it.
#
# One stored text file in each. The first set splits 100 lines into pieces of
# 2 KiB. The comment cannot be split, so the second set has pieces of 66 KiB,
# and 1,300 lines to fill the first of them: zip.js closes a piece early when
# the end records and the comment no longer fit, and 7-Zip 26 does not open a
# set whose last piece is larger than its first. Fixed dates and `TZ=UTC`, so a
# rebuild produces byte-identical pieces.
#
# Requires: node and npm (zip.js 2.24.0 is installed into a temporary folder).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="$PWD"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

(cd "$BUILD" && npm install --silent --no-save @zip.js/zip.js@2.24.0)

# set name, lines of text, piece size, comment length
build() {
    for i in $(seq -w 1 "$2"); do
        printf 'Line %s of a text that zip.js spreads over three files.\n' "$i"
    done > "$BUILD/lorem.txt"
    rm -f "$1".z?? "$1".zip
    (cd "$BUILD" && TZ=UTC node --input-type=module - "$BUILD/lorem.txt" "$OUT" "$1" "$3" "$4") <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ZipWriter, SplitDataWriter, Uint8ArrayReader, Uint8ArrayWriter, configure } from "@zip.js/zip.js";

const [input, out, set, pieceSize, commentLength] = process.argv.slice(2);
configure({ useWebWorkers: false });

const pieces = [];
async function* writers() {
    while (true) {
        const writer = new Uint8ArrayWriter();
        pieces.push(writer);
        yield writer;
    }
}

const comment = new TextEncoder()
    .encode("A zip comment as long as a zip allows. ".repeat(1700))
    .subarray(0, Number(commentLength));

const zip = new ZipWriter(new SplitDataWriter(writers(), Number(pieceSize)), { zip64: true });
await zip.add("lorem.txt", new Uint8ArrayReader(readFileSync(input)), {
    level: 0,
    lastModDate: new Date(Date.UTC(2026, 9, 17, 12, 0, 0)),
});
await zip.close(comment);

// Info-ZIP's naming: .z01, .z02, … and the last piece is the .zip
for (const [index, writer] of pieces.entries()) {
    const name = index === pieces.length - 1
        ? `${set}.zip`
        : `${set}.z${String(index + 1).padStart(2, "0")}`;
    writeFileSync(join(out, name), await writer.getData());
}
NODE
}

build split_zipjs64 100 2048 0
build split_zipjs64comment 1300 67584 65535

ls -l split_zipjs64.* split_zipjs64comment.*
