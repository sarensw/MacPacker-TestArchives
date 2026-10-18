#!/bin/bash
#
# Rebuilds `zip64LocatorDecoy.zip` — a plain zip, no Zip64, whose one stored
# file holds the 20 bytes of a Zip64 end of central directory locator that says
# "3 disks", with nothing after them that the archive's own locator would have:
# the end of central directory record, 20 bytes on.
#
# Stored, those bytes sit in the archive's tail, where MacPacker reads the end
# records to tell a single zip from the last piece of a spanned set (issue
# #348). Compressed data holds the four signature bytes by chance now and then;
# taken for the archive's locator, they would make it a spanned set and the
# open would go looking for a `.z01`. Only a locator with the end record right
# after it is the archive's own. A file that holds a whole Zip64 ending is a
# different case: its locator does have its end record after it, and only the
# end record that ends the file tells the two apart — see
# `../nested/spannedZip64InZip.zip`.
#
# Written by Python's `zipfile` with a fixed entry date, so a rebuild is
# byte-identical.
#
# Requires: python3 (stock with the Command Line Tools).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="$PWD/zip64LocatorDecoy.zip"

rm -f "$OUT"
python3 -I - "$OUT" <<'PYTHON'
import struct
import sys
import zipfile

# signature, disk of the Zip64 end record, its offset, total number of disks
locator = b"PK\x06\x07" + struct.pack("<IQI", 0, 0, 3)
data = (
    b"The next 20 bytes look like a Zip64 locator:\n"
    + locator
    + b"\nNo end of central directory record follows them.\n"
)

with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_STORED) as archive:
    entry = zipfile.ZipInfo("decoy.bin", date_time=(2026, 10, 18, 12, 0, 0))
    entry.external_attr = 0o644 << 16
    archive.writestr(entry, data)
PYTHON

echo "wrote zip64LocatorDecoy.zip ($(wc -c < "$OUT" | tr -d ' ') bytes)"
