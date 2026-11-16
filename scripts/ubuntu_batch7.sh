#!/bin/bash
# NScripter SAR/NSA, CP/M LBR, PC-98 FDI/D88 (scripts/write_containers.py), PSP EBOOT.PBP (pspsdk mksfo + pack-pbp),
# Dreamcast GDI (3 tracks, high-density area at LBA 45000; xorriso + scripts/raw_mode1.py). Ubuntu 24.04 arm64.
# usage: ubuntu_batch7.sh <repo root> <out dir>
# Packages: mtools xorriso git build-essential
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); D="$OUT/defaultArchives"; mkdir -p "$D"
W=$(mktemp -d); cp -a "$REPO/defaultArchiveContent" "$W/c"; C="$W/c"

# ---- PC-98 2HD floppy: FAT12, 1024-byte sectors, 8 per track, 2 heads, 77 cylinders (1.2 MB), 8.3 names ------------
F="$W/pc98.img"; truncate -s 1261568 "$F"; mformat -i "$F" -t 77 -h 2 -s 8 -S 3 -v DEFAULT ::
mmd -i "$F" ::/FOLDER; mcopy -i "$F" "$C/hello world.txt" ::/HELLO.TXT
mcopy -i "$F" "$C/folder/README.md" ::/FOLDER/README.MD; mcopy -i "$F" "$C/folder/NestedArchive.zip" ::/FOLDER/NESTED.ZIP
python3 -I "$REPO/scripts/write_containers.py" "$C" "$D" "$F"
# NScripter loads arc.sar / arc.nsa (arc1.nsa, ...) and XAD recognises them only by those names: keep canonical copies
mkdir -p "$OUT/nscripter"; cp "$D/defaultArchive.sar" "$OUT/nscripter/arc.sar"; cp "$D/defaultArchive.nsa" "$OUT/nscripter/arc.nsa"

# ---- PSP EBOOT.PBP: sections PARAM.SFO (mksfo), DATA.PSP = hello world.txt, DATA.PSAR = NestedArchive.zip, -------
# ---- PIC1.PNG slot = README.md (the container does not check section types) -----------------------------------------
git clone -q --depth 1 https://github.com/pspdev/pspsdk "$W/pspsdk"; git -C "$W/pspsdk" rev-parse HEAD > "$OUT/pspsdk.commit"
gcc -O2 -o "$W/pack-pbp" "$W/pspsdk/tools/pack-pbp.c" -I"$W/pspsdk/tools" 2>/dev/null || gcc -O2 -DHAVE_CONFIG_H=0 -o "$W/pack-pbp" "$W/pspsdk/tools/pack-pbp.c"
gcc -O2 -o "$W/mksfo" "$W/pspsdk/tools/mksfo.c" 2>/dev/null || gcc -O2 -o "$W/mksfo" "$W/pspsdk/tools/mksfo.c" -I"$W/pspsdk/tools"
"$W/mksfo" "MacPacker test archive" "$W/PARAM.SFO" >/dev/null
"$W/pack-pbp" "$D/defaultArchive.pbp" "$W/PARAM.SFO" NULL NULL NULL "$C/folder/README.md" NULL "$C/hello world.txt" "$C/folder/NestedArchive.zip" >/dev/null

# ---- Dreamcast GDI: track01 data (LBA 0, 300 sectors), track02 audio (LBA 450, 302 sectors of silence), ------------
# ---- track03 data at LBA 45000 holding an ISO 9660 built for that start sector (-C 0,45000) -------------------------
G="$OUT/gdi"; mkdir -p "$G"
xorriso -as mkisofs -quiet -V MACPACKER -o "$W/low.iso" "$C" 2>/dev/null; truncate -s $((300 * 2048)) "$W/low.iso"
python3 -I "$REPO/scripts/raw_mode1.py" "$W/low.iso" "$G/track01.bin" 0
head -c $((302 * 2352)) /dev/zero > "$G/track02.raw"
xorriso -as mkisofs -quiet -V MACPACKER -C 0,45000 -o "$W/high.iso" "$C" 2>/dev/null
python3 -I "$REPO/scripts/raw_mode1.py" "$W/high.iso" "$G/track03.bin" 45000
printf '3\r\n1 0 4 2352 track01.bin 0\r\n2 450 0 2352 track02.raw 0\r\n3 45000 4 2352 track03.bin 0\r\n' > "$G/defaultArchive.gdi"
cd /; rm -rf "$W"; echo DONE
