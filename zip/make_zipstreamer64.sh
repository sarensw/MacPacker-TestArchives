#!/bin/bash
#
# Rebuilds `zipstreamer64.zip` — a zip the way Nextcloud and ownCloud hand out a
# download: put together on the fly by ZipStreamer, in its Zip64 mode.
# Nextcloud's Files app downloads every folder and every selection of files
# that way (its WebDAV zip plugin passes an unknown size, which selects Zip64),
# and ownCloud uses Zip64 for every download on a 64-bit server.
#
# Zip64 mode writes all ones into each field of the classic records that a
# Zip64 field can stand in for, needed or not, and the real value into the
# Zip64 one. That includes the end of central directory record's "number of
# this disk" and "disk where the central directory starts": 0xFFFF there means
# "see the Zip64 end of central directory record", which says disk 0. A reader
# that takes the 0xFFFF for a disk number sees the last piece of a spanned set,
# goes looking for the `.z01` that should come first, and fails on a file that
# was never there — MacPacker issue #348, "Failed to open archive: Failed to
# open file".
#
# The archive of that report was a dictionary someone had downloaded and cannot
# be kept here, so this is its shape with contents of our own: two files at the
# root with names in UTF-8, written by the same library at the version
# Nextcloud and ownCloud both ship (deepdiver/zipstreamer v3.0.1). That makes
# the headers the same field for field: version 4.5 made on Unix, stored, a
# data descriptor with 64-bit sizes, a 28-byte Zip64 extra field in both
# headers, 0xFFFF and 0xFFFFFFFF wherever Zip64 can stand in, and an end of
# central directory record that keeps only the entry count.
#
# Entry dates are fixed and ZipStreamer writes them in UTC, so a rebuild
# produces a byte-identical archive.
#
# Requires: php 7.4 or later with mbstring, and curl.
#
set -euo pipefail

cd "$(dirname "$0")"
OUT="$PWD/zipstreamer64.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# v3.0.1, the version in Nextcloud's and ownCloud's composer.lock
COMMIT=e860b893fce08a370886cba5ec0252c61b0b5e73
curl -fsSL "https://github.com/DeepDiver1975/PHPZipStreamer/archive/$COMMIT.tar.gz" \
    | tar -xz -C "$BUILD"

printf 'Written by ZipStreamer in its Zip64 mode.\n' > "$BUILD/memo.txt"
printf 'The second file of a download of two.\n' > "$BUILD/note.txt"

rm -f "$OUT"
php -- "$BUILD/PHPZipStreamer-$COMMIT/src" "$BUILD" "$OUT" <<'PHP'
<?php
[, $src, $build, $out] = $argv;

spl_autoload_register(function ($class) use ($src) {
    $prefix = 'ZipStreamer\\';
    if (strncmp($class, $prefix, strlen($prefix)) === 0) {
        require $src . '/' . str_replace('\\', '/', substr($class, strlen($prefix))) . '.php';
    }
});

// What Nextcloud's OC\Streamer does with such a download: Zip64 on, the
// library's default compression (store), each file's modification time as its
// date.
$stream = fopen($out, 'wb');
$zip = new ZipStreamer\ZipStreamer(['outstream' => $stream, 'zip64' => true]);
$date = gmmktime(12, 0, 0, 10, 17, 2026);
foreach (['memo.txt' => 'メモ.txt', 'note.txt' => 'ノート.txt'] as $file => $name) {
    $handle = fopen("$build/$file", 'rb');
    $zip->addFileFromStream($handle, $name, ['timestamp' => $date]);
    fclose($handle);
}
$zip->finalize();
fclose($stream);
PHP

echo "wrote zipstreamer64.zip ($(wc -c < "$OUT" | tr -d ' ') bytes)"
