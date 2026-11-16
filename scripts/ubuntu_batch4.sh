#!/bin/bash
# Apple II / classic Mac disks and ShrinkIt (CiderPress II 1.2.0 built from source), VPK, Doom WAD, Nintendo DS (ndstool),
# C64 T64, UDF 2.50 (BD-R layout), Amiga RDB hardfile. Ubuntu 24.04 arm64 (Bob HQ "ubuntu" VM).
# usage: ubuntu_batch4.sh <repo root> <out dir> <cp2.dll>
# Packages: dotnet-sdk-8.0 udftools build-essential autoconf automake git; pipx: vpk, amitools
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); CP2DLL=$(realpath "$3"); cp2() { c=$1; shift; dotnet "$CP2DLL" "$c" --no-interactive "$@"; }; mkdir -p "$OUT/defaultArchives"
export PATH="$HOME/.local/bin:$PATH" TZ=UTC
W=$(mktemp -d); cp -a "$REPO/defaultArchiveContent" "$W/c"; C="$W/c"; D="$OUT/defaultArchives"; d() { mkdir -p "$OUT/$1"; }
cd "$C"

# ---- CiderPress II: ProDOS .po (baseline), .2mg, .woz; DOS 3.3 .do and .nib, DOS 3.2 .d13; HFS DiskCopy 4.2; ShrinkIt ----
d apple2
cp2 cdi "$D/defaultArchive.po" 140k prodos;            cp2 add "$D/defaultArchive.po" "hello world.txt" folder
cp2 cdi "$OUT/apple2/prodos_800k.2mg" 800k prodos;     cp2 add "$OUT/apple2/prodos_800k.2mg" "hello world.txt" folder
cp2 cdi "$OUT/apple2/prodos_525.woz" 140k prodos;      cp2 add "$OUT/apple2/prodos_525.woz" "hello world.txt" folder
cp2 cdi --sectors=16 "$OUT/apple2/dos33.do" 35trk dos;             cp2 add --strip-paths "$OUT/apple2/dos33.do" "hello world.txt" folder/README.md folder/NestedArchive.zip
cp2 cdi --sectors=16 "$OUT/apple2/dos33.nib" 35trk dos;           cp2 add --strip-paths "$OUT/apple2/dos33.nib" "hello world.txt" folder/README.md folder/NestedArchive.zip
cp2 cdi --sectors=13 "$OUT/apple2/dos32.d13" 35trk dos; cp2 add --strip-paths "$OUT/apple2/dos32.d13" "hello world.txt" folder/README.md folder/NestedArchive.zip
cp2 cdi "$D/defaultArchive.dc42" 800k hfs;             cp2 add "$D/defaultArchive.dc42" "hello world.txt" folder
cp2 cfa "$D/defaultArchive.shk";                       cp2 add "$D/defaultArchive.shk" "hello world.txt" folder
cp2 cfa "$OUT/apple2/binary2.bny" && cp2 add "$OUT/apple2/binary2.bny" "hello world.txt" folder || echo "Binary II: not created"

# ---- Valve VPK (python vpk 1.4.0, VPK v1) ------------------------------------------------------------------------
vpk -c "$C" "$D/defaultArchive.vpk" >/dev/null

# ---- Doom PWAD and C64 T64, written from the documented layouts (scripts/write_wad_t64.py) ------------------------
python3 -I "$REPO/scripts/write_wad_t64.py" "$C" "$D/defaultArchive.wad" "$D/defaultArchive.t64"

# ---- Nintendo DS: ndstool 2.3.1 with a stub ARM9/ARM7 (`b .`) and the content in NitroFS --------------------------
B="$W/b"; git clone -q --depth 1 --branch v2.3.1 https://github.com/devkitPro/ndstool "$B/ndstool"
(cd "$B/ndstool" && ./autogen.sh >/dev/null 2>&1 && ./configure -q >/dev/null && make -s >/dev/null 2>&1)
printf '\xfe\xff\xff\xea' > "$W/arm9.bin"; cp "$W/arm9.bin" "$W/arm7.bin"
"$B/ndstool/ndstool" -c "$D/defaultArchive.nds" -9 "$W/arm9.bin" -7 "$W/arm7.bin" -d "$C" -g MPKR 00 MACPACKER 1 >/dev/null

# UDF 2.50: mkudffs --media-type=bdr --udfrev=0x0250 formats a volume, but the Linux udf driver mounts 2.50 read-only,
# so it cannot be filled here (docs/formats/udf.md).

# ---- Amiga RDB hardfile: rigid disk block + one FFS partition filled with xdftool ----------------------------------
d hdf
rdbtool "$OUT/hdf/rdb_ffs.hdf" create size=4Mi + init + add size=100% name=DH0 fs=ffs >/dev/null
xdftool "$OUT/hdf/rdb_ffs.hdf" open part=DH0 + format defaultArchive ffs + makedir folder + write "$C/hello world.txt" "hello world.txt" \
  + write "$C/folder/README.md" folder/README.md + write "$C/folder/NestedArchive.zip" folder/NestedArchive.zip >/dev/null

cd /; rm -rf "$W"; echo DONE
