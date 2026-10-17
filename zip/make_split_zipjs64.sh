#!/bin/bash
#
# Rebuilds `split_zipjs64.z01` … `split_zipjs64.zip` — a spanned zip in Zip64
# format, written by zip.js, the JavaScript library behind many web apps that
# zip in the browser.
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
# One stored text file split into pieces of 2 KiB, with a fixed date and
# `TZ=UTC`, so a rebuild produces byte-identical pieces.
#
# Requires: node and npm (zip.js 2.24.0 is installed into a temporary folder).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="$PWD"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

for i in $(seq -w 1 100); do
    printf 'Line %s of a text that zip.js spreads over three files.\n' "$i"
done > "$BUILD/lorem.txt"

(cd "$BUILD" && npm install --silent --no-save @zip.js/zip.js@2.24.0)

rm -f split_zipjs64.z?? split_zipjs64.zip
(cd "$BUILD" && TZ=UTC node --input-type=module - "$BUILD/lorem.txt" "$OUT") <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ZipWriter, SplitDataWriter, Uint8ArrayReader, Uint8ArrayWriter, configure } from "@zip.js/zip.js";

const [input, out] = process.argv.slice(2);
configure({ useWebWorkers: false });

const pieces = [];
async function* writers() {
    while (true) {
        const writer = new Uint8ArrayWriter();
        pieces.push(writer);
        yield writer;
    }
}

const zip = new ZipWriter(new SplitDataWriter(writers(), 2048), { zip64: true });
await zip.add("lorem.txt", new Uint8ArrayReader(readFileSync(input)), {
    level: 0,
    lastModDate: new Date(Date.UTC(2026, 9, 17, 12, 0, 0)),
});
await zip.close();

// Info-ZIP's naming: .z01, .z02, … and the last piece is the .zip
for (const [index, writer] of pieces.entries()) {
    const name = index === pieces.length - 1
        ? "split_zipjs64.zip"
        : `split_zipjs64.z${String(index + 1).padStart(2, "0")}`;
    writeFileSync(join(out, name), await writer.getData());
}
NODE

ls -l split_zipjs64.*
