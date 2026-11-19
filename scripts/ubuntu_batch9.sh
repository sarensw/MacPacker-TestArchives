#!/bin/bash
# Apple Pascal and Apple II CP/M volumes (CiderPress II), Amstrad CPC old-format DSK and CPC system-format EDSK (libdsk +
# cpmtools). Ubuntu 24.04 arm64. usage: ubuntu_batch9.sh <repo root> <out dir> <cp2.dll>
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); CP2DLL=$(realpath "$3"); cp2() { c=$1; shift; dotnet "$CP2DLL" "$c" --no-interactive "$@"; }
W=$(mktemp -d); mkdir -p "$W/s" "$OUT/apple2" "$OUT/cpc"; C="$REPO/defaultArchiveContent"
cp "$C/hello world.txt" "$W/s/HELLO.TXT"; cp "$C/folder/README.md" "$W/s/README.MD"; cp "$C/folder/NestedArchive.zip" "$W/s/NESTED.ZIP"
# Apple Pascal (flat, 15-char names) and Apple II CP/M (8.3) on 140K 5.25" images
cp2 cdi "$OUT/apple2/pascal.po" 140k pascal >/dev/null; (cd "$C" && cp2 add --strip-paths "$OUT/apple2/pascal.po" "hello world.txt" folder/README.md folder/NestedArchive.zip >/dev/null)
cp2 cdi "$OUT/apple2/cpm.po" 140k cpm >/dev/null; (cd "$W/s" && cp2 add "$OUT/apple2/cpm.po" HELLO.TXT README.MD NESTED.ZIP >/dev/null)
# CPC: old (non-extended) DSK container with the data format, and the system format (2 reserved tracks) as EDSK
dskform -type dsk -format cpcdata "$OUT/cpc/cpcdata_olddsk.dsk" >/dev/null
(cd "$W/s" && cpmcp -f cpcdata -T dsk "$OUT/cpc/cpcdata_olddsk.dsk" HELLO.TXT README.MD NESTED.ZIP 0:)
dskform -type edsk -format cpcsys "$OUT/cpc/cpcsys_edsk.dsk" >/dev/null
(cd "$W/s" && cpmcp -f cpcsys -T edsk "$OUT/cpc/cpcsys_edsk.dsk" HELLO.TXT README.MD NESTED.ZIP 0:)
cd /; rm -rf "$W"; echo DONE
