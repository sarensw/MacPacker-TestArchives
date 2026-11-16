#!/bin/bash
# DiscJuggler CDI and a second MDS/MDF writer (img4dc: cdi4dc, mds4dc, GPL-3.0, built from source), and a CloneCD
# image (.ccd written from the documented layout over rawcd/mode1_2352.bin). Ubuntu 24.04 arm64 (Bob HQ "ubuntu" VM).
# usage: ubuntu_batch5.sh <repo root> <out dir>
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); mkdir -p "$OUT/defaultArchives" "$OUT/clonecd" "$OUT/mds"
W=$(mktemp -d); I="$REPO/defaultArchives/defaultArchive.iso"
git clone -q https://github.com/Kazade/img4dc "$W/img4dc"; git -C "$W/img4dc" rev-parse HEAD > "$OUT/img4dc.commit"
(cd "$W/img4dc" && mkdir b && cd b && cmake .. >/dev/null && make -s >/dev/null 2>&1) || (cd "$W/img4dc" && for t in cdi4dc mds4dc; do gcc -O2 -o "$t" $t/src/*.c common/*.c -Icommon 2>/dev/null || true; done)
CDI=$(find "$W/img4dc" -type f -name cdi4dc -perm -u+x | head -1); MDS=$(find "$W/img4dc" -type f -name mds4dc -perm -u+x | head -1)
"$CDI" "$I" "$OUT/defaultArchives/defaultArchive.cdi" >/dev/null
"$MDS" "$I" "$OUT/mds/mds4dc.mds" >/dev/null || true

# CloneCD: raw 2352-byte MODE1 sectors (.img) and the control file (.ccd); no subchannel file
cp "$REPO/rawcd/mode1_2352.bin" "$OUT/clonecd/defaultArchive.img"
n=$(( $(stat -c%s "$OUT/clonecd/defaultArchive.img") / 2352 )); lo=$((n + 150))
msf() { printf 'PMin=%d\nPSec=%d\nPFrame=%d\n' $(( $1 / 4500 )) $(( $1 / 75 % 60 )) $(( $1 % 75 )); }
{
printf '[CloneCD]\nVersion=3\n[Disc]\nTocEntries=4\nSessions=1\nDataTracksScrambled=0\nCDTextLength=0\n[Session 1]\nPreGapMode=1\nPreGapSubC=0\n'
printf '[Entry 0]\nSession=1\nPoint=0xa0\nADR=0x01\nControl=0x04\nTrackNo=0\nAMin=0\nASec=0\nAFrame=0\nALBA=-150\nZero=0\nPMin=1\nPSec=0\nPFrame=0\nPLBA=4350\n'
printf '[Entry 1]\nSession=1\nPoint=0xa1\nADR=0x01\nControl=0x04\nTrackNo=0\nAMin=0\nASec=0\nAFrame=0\nALBA=-150\nZero=0\nPMin=1\nPSec=0\nPFrame=0\nPLBA=4350\n'
printf '[Entry 2]\nSession=1\nPoint=0xa2\nADR=0x01\nControl=0x04\nTrackNo=0\nAMin=0\nASec=0\nAFrame=0\nALBA=-150\nZero=0\n'; msf $lo; printf 'PLBA=%d\n' $n
printf '[Entry 3]\nSession=1\nPoint=0x01\nADR=0x01\nControl=0x04\nTrackNo=0\nAMin=0\nASec=0\nAFrame=0\nALBA=-150\nZero=0\nPMin=0\nPSec=2\nPFrame=0\nPLBA=0\n'
printf '[TRACK 1]\nMODE=1\nINDEX 1=0\n'
} | sed 's/$/\r/' > "$OUT/clonecd/defaultArchive.ccd"
cd /; rm -rf "$W"; echo DONE
