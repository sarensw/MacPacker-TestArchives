#!/bin/bash
#
# Rebuilds the archives in this folder: `../defaultArchiveContent` packed, then
# damaged the ways a file gets damaged on its way to someone — a byte that
# changed, or a download cut short. Each archive still opens, so what is wrong
# can only be found by decoding what it holds, which is what testing an archive
# does — see MacPacker issue #232.
#
#   crc.zip                 `folder/README.md` stored, one byte of it changed:
#                           it reads, and its CRC no longer matches.
#   crc.7z                  a solid 7z, one byte of its packed data changed.
#   crc.tar.gz              the tar decompresses whole, and the CRC in the gzip
#                           trailer no longer matches it.
#   truncated.zip           cut off inside `folder/NestedArchive.zip`, the
#                           central directory gone with it.
#   noCentralDirectory.zip  cut off where the central directory starts: every
#                           entry is there and reads, and only the archive itself
#                           can say it is incomplete.
#   crcEncrypted.7z         ../password/7z_aes256.7z, one byte near the end of its
#                           packed data changed: `folder/NestedArchive.zip`
#                           decrypts first and matches, so the password
#                           (`password`) is right, and the two files after it
#                           fail on the damage.
#   crc.dmg                 ../defaultArchives/defaultArchive.dmg, one byte of
#                           `folder/README.md` changed: APFS reads it as it is,
#                           and only the image's own CRC no longer matches.
#   tocChecksum.xar         ../defaultArchives/defaultArchive.xar, one byte of the
#                           SHA-1 of its table of contents changed: every file
#                           reads and matches its own checksum, and the table of
#                           contents no longer matches its one.
#
# Entry dates are fixed, entries are added by explicit argument, and the damage
# is at offsets worked out from the archive, so a rebuild is byte-identical. The
# last three are copies of archives in the other folders, which no tool rebuilds
# the same: 7-Zip encrypts with a random IV, and a dmg and a xar hold the time
# they were made.
#
# Requires: zip, tar, gzip, xxd (stock macOS), 7zz (`brew install sevenzip`).
#
set -euo pipefail

cd "$(dirname "$0")"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

cp -R ../defaultArchiveContent/. "$BUILD/"
find "$BUILD" \( -name '.DS_Store' -o -name '._*' -o -name '__MACOSX' \) -delete
find "$BUILD" -exec touch -t 202611040900 {} +

ENTRIES=("hello world.txt" folder folder/README.md folder/NestedArchive.zip)

# Writes the byte at `offset` of `file` back with `mask` XORed into it.
flip() {
    local file=$1 offset=$2 mask=$3
    local byte
    byte=$(xxd -s "$offset" -l 1 -p "$file")
    printf "\\x$(printf '%02x' $((0x$byte ^ mask)))" | dd of="$file" bs=1 seek="$offset" conv=notrunc status=none
}

# Offset of the first occurrence of `text` in `file`.
offset_of() {
    LC_ALL=C grep -obUa -- "$2" "$1" | head -1 | cut -d: -f1
}

rm -f crc.zip crc.7z crc.tar.gz truncated.zip noCentralDirectory.zip crcEncrypted.7z crc.dmg tocChecksum.xar

# -0 stores the entries, so a changed byte decodes as it is and only the CRC can
# tell. -X: no uid/gid, no extended attributes, no extra timestamps.
(cd "$BUILD" && zip -q -X -0 "$BUILD/stored.zip" "${ENTRIES[@]}")

cp "$BUILD/stored.zip" crc.zip
flip crc.zip "$(offset_of crc.zip 'Lorem ipsum')" 0x20

# The local header of the last entry, then 1000 bytes into its data.
head -c $(($(offset_of "$BUILD/stored.zip" folder/NestedArchive.zip) + 1000)) "$BUILD/stored.zip" > truncated.zip

# The end of central directory record is the last 22 bytes (no comment); its
# last-but-one field says where the central directory starts.
SIZE=$(wc -c < "$BUILD/stored.zip")
CD=$(od -An -tu4 -j $((SIZE - 6)) -N 4 "$BUILD/stored.zip" | tr -d ' ')
head -c "$CD" "$BUILD/stored.zip" > noCentralDirectory.zip

# -mtc=off: creation times are the machine's and not reproducible. The packed
# streams start right after the 32-byte signature header; 200 bytes in is inside
# the LZMA2 data and well clear of the headers at the end.
(cd "$BUILD" && 7zz a -mtc=off -bso0 -bsp0 "$OLDPWD/crc.7z" "hello world.txt" folder)
flip crc.7z 232 0x01

(cd "$BUILD" && COPYFILE_DISABLE=1 tar --no-mac-metadata --no-xattrs --no-acls \
    --no-recursion --format ustar --uid 0 --gid 0 --uname root --gname wheel \
    -cf "$BUILD/crc.tar" "${ENTRIES[@]}")
# -n: no name and no time in the header.
gzip -n -c "$BUILD/crc.tar" > crc.tar.gz
# The trailer is the CRC-32 of the data, then its size.
flip crc.tar.gz $(($(wc -c < crc.tar.gz) - 8)) 0x01

# One solid block of 52496 bytes (`7zz l -slt`) right after the 32-byte signature
# header; 100 bytes before its end is past `folder/NestedArchive.zip`, which
# comes first.
cp ../password/7z_aes256.7z crcEncrypted.7z
flip crcEncrypted.7z $((32 + 52496 - 100)) 0x01

# The image is stored uncompressed, so the text of README.md is in it as it is.
cp ../defaultArchives/defaultArchive.dmg crc.dmg
flip crc.dmg "$(offset_of crc.dmg 'Lorem ipsum')" 0x20

# The checksum of the table of contents is the first thing on the heap, which
# starts after the header (its size at offset 4) and the compressed table of
# contents (its size at offset 8).
cp ../defaultArchives/defaultArchive.xar tocChecksum.xar
flip tocChecksum.xar $((0x$(xxd -s 4 -l 2 -p tocChecksum.xar) + 0x$(xxd -s 8 -l 8 -p tocChecksum.xar))) 0x01

for f in crc.zip crc.7z crc.tar.gz truncated.zip noCentralDirectory.zip crcEncrypted.7z crc.dmg tocChecksum.xar; do
    echo "wrote $f ($(wc -c < "$f" | tr -d ' ') bytes)"
done
