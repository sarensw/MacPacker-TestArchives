#!/bin/bash
# Regenerate the defaultArchives/ baselines that held an older defaultArchiveContent (docs/existing-fixtures-audit.md),
# with the commands of create_archives_linux.sh, on Ubuntu 24.04 (Bob HQ "ubuntu" VM). Same paths as before.
# usage: regenerate_linux_baselines.sh <content dir> <out dir>
# Packages: tar gzip bzip2 xz-utils zstd lz4 lzip lzop brotli arj ruby-full rpm dpkg-dev 7zip zip wimtools xorriso; gem install fpm
set -euo pipefail
SRC=$(realpath "$1"); OUT=$(realpath -m "$2"); mkdir -p "$OUT"
export SOURCE_DATE_EPOCH=1700000000 TZ=UTC
W=$(mktemp -d); cp -a "$SRC" "$W/c"; find "$W/c" \( -name .DS_Store -o -name '._*' \) -delete
find "$W/c" -exec touch -h -d @$SOURCE_DATE_EPOCH {} +
cd "$W/c"
T="--sort=name --owner=0 --group=0 --numeric-owner"

tar $T -cf "$OUT/defaultArchive.tar" *
tar $T -cf "$OUT/defaultArchive-dotslash.tar" .
tar $T --format=gnu -cf "$OUT/defaultArchive.gtar" .
for e in tgz tar.gz; do tar $T -czf "$OUT/defaultArchive.$e" *; done
for e in tbz2 tbz tar.bz2; do tar $T -cjf "$OUT/defaultArchive.$e" *; done
for e in txz tar.xz; do tar $T -cJf "$OUT/defaultArchive.$e" *; done
for e in tzst tar.zst; do tar $T --zstd -cf "$OUT/defaultArchive.$e" *; done
for e in tlz4 tar.lz4; do tar $T --use-compress-program=lz4 -cf "$OUT/defaultArchive.$e" *; done
for e in tlz tar.lz; do tar $T --lzip -cf "$OUT/defaultArchive.$e" *; done
for e in tlzma tar.lzma; do tar $T -cf - * | lzma -c > "$OUT/defaultArchive.$e"; done
for e in tlzo tar.lzo; do tar $T --lzop -cf "$OUT/defaultArchive.$e" *; done
for e in tbr tar.br; do tar $T --use-compress-program=brotli -cf "$OUT/defaultArchive.$e" *; done
tar $T -cf - * | { compress -c || [ $? = 2 ]; } > "$OUT/defaultArchive.tar.Z"; cp "$OUT/defaultArchive.tar.Z" "$OUT/defaultArchive.taz"

arj a -r -y "$OUT/defaultArchive.arj" "hello world.txt" "folder/*" >/dev/null

# rpm and deb as before (fpm), then dpkg-deb
(cd "$W/c" && fpm -s dir -t rpm -n defaultArchive -v 1.0 -p "$OUT/defaultArchive.rpm" ./ >/dev/null)
(cd "$W/c" && fpm -s dir -t deb -n defaultarchive -v 1.0 -p "$OUT/defaultarchive.deb" ./ >/dev/null)
mkdir -p "$W/dpkg-root/DEBIAN"; cp -a folder "hello world.txt" "$W/dpkg-root/"
printf 'Package: defaultarchive\nVersion: 1.0\nArchitecture: all\nMaintainer: MacPacker Test Archives <test@example.invalid>\nDescription: MacPacker test archive\n' > "$W/dpkg-root/DEBIAN/control"
dpkg-deb --root-owner-group --build "$W/dpkg-root" "$OUT/defaultarchive-dpkg.deb" >/dev/null

# Formats first made on Windows that a Linux tool writes the same way (WinIso/7-Zip/WinAce originals had CRLF texts)
7z a -bd -bso0 "$OUT/defaultArchive.7z" "hello world.txt" folder                        # LZMA2, solid, as before
(cd "$W/c" && zip -q -r -X "$OUT/defaultArchive.jar" "hello world.txt" folder)            # plain zip named .jar, as before
wimlib-imagex capture "$W/c" "$OUT/defaultArchive.wim" defaultArchive --compress=none --no-acls >/dev/null   # uncompressed, as before
# ISO 9660 + Joliet with volume id MACPACKER, 2048-byte sectors; .bin and .img are the same bytes, as before
xorriso -as mkisofs -quiet -J -joliet-long -V MACPACKER -o "$OUT/defaultArchive.iso" "$W/c" 2>/dev/null
cp "$OUT/defaultArchive.iso" "$OUT/defaultArchive.bin"; cp "$OUT/defaultArchive.iso" "$OUT/defaultArchive.img"
# Images derived from defaultArchive.iso/.bin (made by ubuntu_next.sh from the old bin) follow it
cp "$OUT/defaultArchive.bin" "$W/DEFAULTARCHIVE.BIN"; printf 'FILE "DEFAULTARCHIVE.BIN" BINARY\r\n  TRACK 01 MODE1/2048\r\n    INDEX 01 00:00:00\r\n' > "$W/x.cue"
mkdir -p "$OUT/chd"
chdman createcd -i "$W/x.cue" -o "$OUT/defaultArchive.chd" -f >/dev/null 2>&1
chdman createraw -i "$W/DEFAULTARCHIVE.BIN" -o "$OUT/chd/raw_iso.chd" -us 2048 -hs 2048 -f >/dev/null 2>&1
ciso 9 "$OUT/defaultArchive.iso" "$OUT/defaultArchive.cso" >/dev/null || true; test -s "$OUT/defaultArchive.cso"
cd /; rm -rf "$W"; echo DONE
