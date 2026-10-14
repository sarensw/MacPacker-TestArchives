#!/bin/bash
#
# Rebuilds the archives that hold another archive as it is: stored, not
# compressed, so the inner one sits in the outer byte for byte, its signature
# included, near the start of the file.
#
#   7zInZip.zip   readme.txt, notes.txt, inner.7z (in-a.txt, in-b.txt)
#   rarInZip.zip  readme.txt, notes.txt, inner.rar (../defaultArchives/defaultArchive.rar)
#   cabInZip.zip  readme.txt, notes.txt, inner.cab (../defaultArchives/defaultArchive.cab)
#   7zInTar.tar   readme.txt, notes.txt, inner.7z
#
# 7-Zip's handlers for 7z, rar and cab look for their signature anywhere in the
# first 4 MB of a file. Asked before the outer archive's own handler, they took
# these for the inner archive: the zip listed what the 7z holds, and saving it
# wrote the 7z over it — MacPacker issue #336.
#
# The zips are 7-Zip's, as MacPacker's are. `-mx=0` stores every entry;
# MacPacker's writer stores whatever does not shrink, which an archive seldom
# does.
#
# Requires: 7zz (7-Zip 21+; `brew install sevenzip`).
#
set -euo pipefail

cd "$(dirname "$0")"

OUT="$PWD"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# 7z keeps times in UTC and zip in local time: one zone for both, and fixed
# dates, so a rebuild is byte-identical anywhere.
export TZ=UTC
STAMP="202610140900.00"

printf 'readme\n' > "$BUILD/readme.txt"
printf 'notes\n' > "$BUILD/notes.txt"
printf 'in a\n' > "$BUILD/in-a.txt"
printf 'in b\n' > "$BUILD/in-b.txt"
cp ../defaultArchives/defaultArchive.rar "$BUILD/inner.rar"
cp ../defaultArchives/defaultArchive.cab "$BUILD/inner.cab"
chmod 644 "$BUILD"/*
touch -t "$STAMP" "$BUILD"/*

cd "$BUILD"
7zz a -mtc=off -mta=off inner.7z in-a.txt in-b.txt > /dev/null
touch -t "$STAMP" inner.7z

for inner in 7z rar cab; do
  rm -f "$OUT/${inner}InZip.zip"
  7zz a -tzip -mx=0 -mtc=off -mta=off "$OUT/${inner}InZip.zip" readme.txt notes.txt "inner.$inner" > /dev/null
done
rm -f "$OUT/7zInTar.tar"
7zz a -ttar "$OUT/7zInTar.tar" readme.txt notes.txt inner.7z > /dev/null

ls -l "$OUT"/*InZip.zip "$OUT"/*InTar.tar
