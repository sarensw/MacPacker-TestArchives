#!/bin/bash
# Xbox XISO (extract-xiso), ZX Spectrum TAP (scripts/write_tap.py) and TZX (fuse-emulator-utils tapeconv), Atari 8-bit ATR
# (atrcopy), Amstrad CPC EDSK (libdsk dskform + cpmtools cpmcp), MSX-DOS 720K disk (mtools). Ubuntu 24.04 arm64.
# usage: ubuntu_batch6.sh <repo root> <out dir>
# Packages: fuse-emulator-utils libdsk-utils cpmtools mtools cmake git build-essential; pipx atrcopy
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); D="$OUT/defaultArchives"; mkdir -p "$D"; export PATH="$HOME/.local/bin:$PATH"
W=$(mktemp -d); cp -a "$REPO/defaultArchiveContent" "$W/c"; C="$W/c"
# 8.3 copies for the formats without long names
mkdir -p "$W/s"; cp "$C/hello world.txt" "$W/s/HELLO.TXT"; cp "$C/folder/README.md" "$W/s/README.MD"; cp "$C/folder/NestedArchive.zip" "$W/s/NESTED.ZIP"

# ---- Xbox XDVDFS (extract-xiso, built from source) ----------------------------------------------------------------
git clone -q https://github.com/XboxDev/extract-xiso "$W/xiso"; git -C "$W/xiso" rev-parse HEAD > "$OUT/extract-xiso.commit"
(cd "$W/xiso" && cmake -S . -B b >/dev/null && cmake --build b >/dev/null)
X=$(find "$W/xiso/b" -type f -name extract-xiso -perm -u+x | head -1)
(cd "$W" && "$X" -q -c c "$D/defaultArchive.xiso")

# ---- ZX Spectrum: TAP from the documented layout, TZX converted by libspectrum's tapeconv ---------------------------
python3 -I "$REPO/scripts/write_tap.py" "$C" "$D/defaultArchive.tap"
tapeconv "$D/defaultArchive.tap" "$D/defaultArchive.tzx"

# ---- Atari 8-bit: ATR via dir2atr (AtariSIO, GPL, built from source): DOS 2.x single density (flat, 8.3 names) and
# MyDOS double density with a subdirectory. (atrcopy 10.1 fails with NumPy 2: np.alen.) Disks are not bootable (no DOS copied).
git clone -q https://github.com/HiassofT/AtariSIO "$W/asio"; git -C "$W/asio" rev-parse HEAD > "$OUT/atarisio.commit"
make -s -C "$W/asio/tools" dir2atr >/dev/null 2>&1
"$W/asio/tools/dir2atr" -S "$D/defaultArchive.atr" "$W/s" >/dev/null
mkdir -p "$W/my/FOLDER" "$OUT/atari8"; cp "$W/s/HELLO.TXT" "$W/my/"; cp "$W/s/README.MD" "$W/s/NESTED.ZIP" "$W/my/FOLDER/"
"$W/asio/tools/dir2atr" -m -d "$OUT/atari8/mydos_dd_subdir.atr" "$W/my" >/dev/null

# ---- Amstrad CPC: EDSK, CPC data format (dskform + cpmtools via libdsk) ---------------------------------------------
dskform -type edsk -format cpcdata "$D/defaultArchive.dsk" >/dev/null
(cd "$W/s" && cpmcp -f cpcdata -T edsk "$D/defaultArchive.dsk" HELLO.TXT README.MD NESTED.ZIP 0:)

# ---- MSX-DOS: 720K FAT12 disk (MSX-DOS 1/2 read standard FAT12 720K media) ------------------------------------------
mkdir -p "$OUT/msx"; truncate -s 737280 "$OUT/msx/msxdos_720k.dsk"; mformat -i "$OUT/msx/msxdos_720k.dsk" -f 720 -v DEFAULT ::
mmd -i "$OUT/msx/msxdos_720k.dsk" ::/FOLDER; mcopy -i "$OUT/msx/msxdos_720k.dsk" "$W/s/HELLO.TXT" ::/
mcopy -i "$OUT/msx/msxdos_720k.dsk" "$W/s/README.MD" "$W/s/NESTED.ZIP" ::/FOLDER/
cd /; rm -rf "$W"; echo DONE
