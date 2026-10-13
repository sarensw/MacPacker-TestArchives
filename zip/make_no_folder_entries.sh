#!/bin/bash
#
# Rebuilds `noFolderEntries.zip` — a zip the way a download site hands one out:
# files only, and no entry for any of the folders their paths name.
#
# A zip is a list of entries, and a folder is one of them only if somebody wrote
# it. Finder, ditto, Info-ZIP, Keka and 7-Zip walk a tree and store each folder
# as they pass it. A server that puts a download together has no tree to walk:
# it adds `Sample Kit/readme.html` and `Sample Kit/Sample Kit.txt` and is done,
# so `Sample Kit/` exists only as the start of two paths. Whoever shows such an
# archive has to make the folder up, and must then not mistake the row it made
# up for an entry the archive can be asked for — MacPacker issue #306, where
# dragging that folder out delivered one of the files inside it instead, named
# like the folder: a document without an extension that Finder cannot open.
#
# The archive of that report was a font from a download site and cannot be kept
# here, so this is its shape with contents of our own. It was written by
# Python's `zipfile`, and so is this one, which makes the headers the same field
# for field (version 2.0 made on Unix, no flags, no extra fields):
#
#   Sample Kit/readme.html
#       Through writestr(), as a page generated for the download. writestr()
#       gives a bare name the mode 0600 and no file type at all, which zipinfo
#       prints as `?rw-------`.
#
#   Sample Kit/Sample Kit.txt
#       Through write(), as a file read from disk, with the mode it has there.
#
#   Sample Kit/extras/licenses/license.txt
#       Not in the report: two more folders without an entry, the outer one
#       holding nothing but the inner one. A folder whose place can only be
#       found through another made-up folder is the case one level cannot show.
#
# `zip -D` writes the same kind of archive, and so does anything else that adds
# files by name. `appledouble.zip` has no folder entries either, but it is about
# its sidecars, and its entries were chosen by hand.
#
# Entry dates are fixed, so a rebuild produces a byte-identical archive.
#
# Requires: python3 (stock with the Command Line Tools).
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="$PWD/noFolderEntries.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

printf 'The file this download is about.\n' > "$BUILD/kit.txt"
printf 'Free to use for testing.\n' > "$BUILD/license.txt"
chmod 644 "$BUILD/kit.txt" "$BUILD/license.txt"

rm -f "$OUT"
python3 -I - "$OUT" "$BUILD" <<'PYTHON'
import os
import sys
import time
import zipfile

out, build = sys.argv[1], sys.argv[2]

# write() stamps an entry with the file's modification time as the local clock
# shows it, so the files get theirs through the local clock too: the same date
# in the archive wherever this runs.
stamp = time.mktime((2026, 10, 13, 12, 0, 0, 0, 0, -1))
for name in ("kit.txt", "license.txt"):
    os.utime(os.path.join(build, name), (stamp, stamp))

page = (
    "<!doctype html>\n"
    "<html><head><meta charset=\"utf-8\"><title>Sample Kit</title></head>\n"
    "<body><p>A page generated for this download.</p></body></html>\n"
)

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    # What writestr("Sample Kit/readme.html", page) writes, except for the date:
    # given a bare name it takes the current time, which no rebuild can repeat.
    readme = zipfile.ZipInfo("Sample Kit/readme.html", date_time=(2026, 10, 13, 12, 0, 0))
    readme.compress_type = zipfile.ZIP_DEFLATED
    readme.external_attr = 0o600 << 16
    archive.writestr(readme, page)

    archive.write(os.path.join(build, "kit.txt"), "Sample Kit/Sample Kit.txt")
    archive.write(os.path.join(build, "license.txt"), "Sample Kit/extras/licenses/license.txt")
PYTHON

echo "wrote noFolderEntries.zip ($(wc -c < "$OUT" | tr -d ' ') bytes)"
