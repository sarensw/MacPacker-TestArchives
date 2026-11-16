#!/bin/bash
# Checks for the scripts/ubuntu_batch4.sh fixtures. usage: verify_batch4.sh <content dir> <fixture root> <cp2.dll>
C=$(realpath "$1"); cd "$2" || exit 1; CP2=$(realpath "$3"); export PATH="$HOME/.local/bin:$PATH"
cp2() { dotnet "$CP2" "$@"; }
ck() { (cd "$1" && find . -type f -exec sha256sum {} + | cut -c1-16,65- | sort -k2 | sed "s/^/  /"); }
T=$(mktemp -d)
for f in defaultArchives/defaultArchive.po apple2/prodos_800k.2mg apple2/prodos_525.woz defaultArchives/defaultArchive.dc42 defaultArchives/defaultArchive.shk apple2/binary2.bny; do
  echo "== $f"; echo "  CREATOR-ONLY: CiderPress II 1.2.0 extract (unar 1.10, 7-Zip and bsdtar did not open it). $(cp2 catalog "$f" 2>&1 | sed -n 2p)"
  mkdir -p "$T/x.$$" && rm -rf "$T/x" && mkdir "$T/x" && (cd "$T/x" && cp2 extract --no-interactive "$OLDPWD/$f" >/dev/null 2>&1); ck "$T/x"; done
for f in apple2/dos33.do apple2/dos33.nib apple2/dos32.d13; do
  echo "== $f"; echo "  CREATOR-ONLY: CiderPress II 1.2.0. DOS 3.x stores these as type S files without a length, so each extracts padded with zeros to a 256-byte multiple; checked that the original bytes are the prefix:"
  rm -rf "$T/x" && mkdir "$T/x" && (cd "$T/x" && cp2 extract --no-interactive "$OLDPWD/$f" >/dev/null 2>&1)
  for p in "hello world.txt:HELLO WORLD.TXT" "folder/README.md:README.MD" "folder/NestedArchive.zip:NESTEDARCHIVE.ZIP"; do
    o=${p%%:*}; n=${p##*:}; s=$(stat -c%s "$C/$o"); echo "  $(head -c $s "$T/x/$n" | sha256sum | cut -c1-16)  ./$o (first $s bytes of $n)"; done; done
echo "== defaultArchives/defaultArchive.dc42"; echo "  hfsutils 3.2.6 on the image without its 84-byte DiskCopy header (independent):"
dd if=defaultArchives/defaultArchive.dc42 of="$T/hfs.img" bs=84 skip=1 status=none; hmount "$T/hfs.img" >/dev/null
rm -rf "$T/h" && mkdir -p "$T/h/folder"; hcopy -r ":hello world.txt" "$T/h/hello world.txt"; hcopy -r ":folder:README.md" "$T/h/folder/README.md"; hcopy -r ":folder:NestedArchive.zip" "$T/h/folder/NestedArchive.zip"; humount >/dev/null; ck "$T/h"
echo "== defaultArchives/defaultArchive.t64"; echo "  cbmconvert 2.1.5 -t -N (independent); NestedArchive.zip is not on the tape (see scripts/write_wad_t64.py); VICE c1541 does not open T64"
rm -rf "$T/t" && mkdir "$T/t" && (cd "$T/t" && cbmconvert -t -N "$OLDPWD/defaultArchives/defaultArchive.t64" >/dev/null 2>&1); ck "$T/t"
echo "== defaultArchives/defaultArchive.wad"; echo "  independent parse of the PWAD directory (header, lump table):"
python3 -I - defaultArchives/defaultArchive.wad <<'PY'
import struct, hashlib, sys
b = open(sys.argv[1], 'rb').read(); n, o = struct.unpack('<ii', b[4:12]); print('  %s, %d lumps' % (b[:4].decode(), n))
for i in range(n):
    p, s, nm = struct.unpack('<ii8s', b[o + 16 * i:o + 16 * i + 16]); print('  %s  ./%s (lump)' % (hashlib.sha256(b[p:p + s]).hexdigest()[:16], nm.rstrip(b'\0').decode()))
PY
echo "== defaultArchives/defaultArchive.vpk"; echo "  CREATOR-ONLY: python vpk 1.4.0 (no other VPK reader available): $(vpk -l defaultArchives/defaultArchive.vpk | tr '\n' ' ')"
rm -rf "$T/v" && mkdir "$T/v" && (cd "$T/v" && vpk -x . "$OLDPWD/defaultArchives/defaultArchive.vpk" >/dev/null); ck "$T/v"
echo "== hdf/rdb_ffs.hdf"; echo "  rdbtool/xdftool (amitools 0.9.0): $(rdbtool hdf/rdb_ffs.hdf info 2>&1 | grep -E "Partition" | head -1)"
rm -rf "$T/u" && mkdir "$T/u" && xdftool hdf/rdb_ffs.hdf open part=DH0 + unpack "$T/u" >/dev/null 2>&1; ck "$T/u/defaultArchive"
rm -rf "$T"
