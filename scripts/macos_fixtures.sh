#!/bin/bash
# Apple-format fixtures. Runs on macOS 27.2 (Bob HQ "lb_27" VM), system tools only.
# usage: macos_fixtures.sh <content dir> <out dir>
set -euo pipefail
SRC=$(cd "$1" && pwd); mkdir -p "$2"; OUT=$(cd "$2" && pwd)
PW=password   # the repository's test password (password/README.md)
W=$(mktemp -d /tmp/fx.XXXX); ditto --norsrc --noextattr "$SRC" "$W/c"; find "$W/c" \( -name .DS_Store -o -name '._*' \) -delete
C="$W/c"; D="$OUT/defaultArchives"; mkdir -p "$D"
d() { mkdir -p "$OUT/$1"; }
cd "$W"

# ---- macOS installer packages (pkgbuild/productbuild) ----------------------
d pkg
pkgbuild --quiet --root "$C" --identifier com.macpacker.testarchives.default --version 1.0 --install-location /tmp/defaultArchive "$D/defaultArchive.pkg"
pkgbuild --quiet --root "$C" --identifier com.macpacker.testarchives.default --version 1.0 --install-location /tmp/defaultArchive --compression latest --min-os-version 13.0 "$OUT/pkg/component_compression_latest.pkg"
productbuild --quiet --package "$D/defaultArchive.pkg" "$OUT/pkg/product_archive.pkg"

# ---- Apple Archive (aa) ----------------------------------------------------
aa archive -d "$C" -o "$D/defaultArchive.aar"
aa archive -d "$C" -o "$D/defaultArchive-raw.aar" -a raw
d aar
for a in lzma lz4 zlib lzbitmap; do aa archive -d "$C" -o "$OUT/aar/compression_$a.aar" -a $a; done

# ---- Apple Encrypted Archive (aea) -----------------------------------------
aa archive -d "$C" -o "$W/raw.aar" -a raw
# aea refuses passwords shorter than 20 characters, so AEA uses the repo password three times
aea encrypt -profile 5 -password-value "$PW$PW$PW" -i "$W/raw.aar" -o "$D/defaultArchive.aea"
d aea
# profile 1, symmetric key: the fixed test key below (32 bytes), documented in docs/formats/aea.md
aea encrypt -profile 1 -key-value "hex:000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f" -i "$W/raw.aar" -o "$OUT/aea/profile1_symmetric.aea"
# profile 0, signed only, with a throwaway P-256 key; the public key is kept next to it, the private key is discarded
openssl ecparam -name prime256v1 -genkey -noout -out "$W/sign.pem" 2>/dev/null
openssl ec -in "$W/sign.pem" -pubout -out "$OUT/aea/profile0_signed.pub.pem" 2>/dev/null
aea encrypt -profile 0 -sign-priv "$W/sign.pem" -i "$W/raw.aar" -o "$OUT/aea/profile0_signed.aea"

# ---- single streams over a tar (pbzx, LZFSE via Apple's compression_tool) --
tar --uid 0 --gid 0 -C "$C" -cf "$W/d.tar" "hello world.txt" folder
compression_tool -encode -A lzma -i "$W/d.tar" -o "$D/defaultArchive.tar.pbzx"
d pbzx
compression_tool -encode -A lzfse -i "$W/d.tar" -o "$OUT/pbzx/block_lzfse.tar.pbzx"
compression_tool -encode -a lzfse -i "$W/d.tar" -o "$OUT/pbzx/apple_compression_tool.tar.lzfse"

# ---- AppleSingle / MacBinary / BinHex --------------------------------------
applesingle encode -o "$D/defaultArchive.tar.as" "$W/d.tar"
macbinary encode -o "$D/defaultArchive.tar.bin" "$W/d.tar"
# a file with a resource fork and a Finder type/creator, which is what these encodings exist for
printf 'hello world\n\n' > "$W/forked.txt"; printf 'resource fork of forked.txt\n' > "$W/forked.txt/..namedfork/rsrc"
xattr -wx com.apple.FinderInfo "54455854 74747874 00000000 00000000 00000000 00000000 00000000 00000000" "$W/forked.txt"
d applesingle; d macbinary; d binhex
applesingle encode -o "$OUT/applesingle/forked.txt.as" "$W/forked.txt"
macbinary encode -o "$OUT/macbinary/forked.txt.bin" "$W/forked.txt"
binhex encode -o "$OUT/binhex/forked.txt.hqx" "$W/forked.txt"

# ---- Disk images (hdiutil) -------------------------------------------------
d dmg
mkimg() { hdiutil create -quiet -srcfolder "$C" -volname defaultArchive "$@"; }
for f in UDZO UDBZ ULFO ULMO UDRO UDRW; do mkimg -fs HFS+ -format $f "$OUT/dmg/format_$f.dmg"; done
mkimg -fs APFS -format UDZO "$OUT/dmg/fs_apfs.dmg"
mkimg -fs HFS+ -format UDZO "$OUT/dmg/fs_hfsplus.dmg"
mkimg -fs MS-DOS -format UDZO "$OUT/dmg/fs_msdos_fat16.dmg"   # hdiutil picks FAT16 at this size
# exFAT: needs an explicit size, and refuses the 14-character volume name
hdiutil create -quiet -srcfolder "$C" -volname DEFAULT -size 4m -fs ExFAT -format UDZO "$OUT/dmg/fs_exfat.dmg"
printf '%s' "$PW" | mkimg -fs HFS+ -format UDZO -encryption AES-128 -stdinpass "$OUT/dmg/encrypted_aes128.dmg"
printf '%s' "$PW" | mkimg -fs APFS -format UDZO -encryption AES-256 -stdinpass "$OUT/dmg/encrypted_aes256.dmg"
cp "$OUT/dmg/encrypted_aes256.dmg" "$D/defaultArchive-encrypted.dmg"
# sparse images: made empty, then filled through a mount
for t in SPARSE SPARSEBUNDLE; do
  ext=$( [ $t = SPARSE ] && echo sparseimage || echo sparsebundle )
  hdiutil create -quiet -size 4m -fs HFS+ -volname defaultArchive -type $t -imagekey sparse-band-size=2048 "$D/defaultArchive.$ext"
  mp=$(hdiutil attach -nobrowse -noverify "$D/defaultArchive.$ext" | awk -F'\t' '/Volumes/{print $NF}')
  ditto "$C" "$mp"; mdutil -i off "$mp" >/dev/null 2>&1 || true; rm -rf "$mp/.fseventsd" 2>/dev/null || true
  hdiutil detach -quiet "$mp"; hdiutil compact -quiet "$D/defaultArchive.$ext" 2>/dev/null || true
done
# raw file-system images without a partition map, and raw partitioned disks
hdiutil create -quiet -size 8m -layout NONE -fs APFS -volname defaultArchive -srcfolder "$C" -format UDTO "$W/apfs"; mv "$W/apfs.cdr" "$D/defaultArchive.apfs"
d rawdisk
hdiutil create -quiet -size 4m -layout SPUD -fs HFS+ -volname defaultArchive -srcfolder "$C" -format UDTO "$W/apm"; mv "$W/apm.cdr" "$OUT/rawdisk/apm_hfsplus.raw"
hdiutil create -quiet -size 4m -layout GPTSPUD -fs HFS+ -volname defaultArchive -srcfolder "$C" -format UDTO "$W/gpt"; mv "$W/gpt.cdr" "$OUT/rawdisk/gpt_hfsplus.raw"

# ---- XAR compression variants (Apple xar; its lzma support is not compiled in) ---
d xar
(cd "$C" && for z in none gzip bzip2; do xar -cf "$OUT/xar/compression_$z.xar" --compression=$z "hello world.txt" folder; done)
(cd "$C" && xar -cf "$OUT/xar/toc_sha256.xar" --toc-cksum=sha256 --file-cksum=sha256 "hello world.txt" folder)

cd /; rm -rf "$W"; echo DONE
