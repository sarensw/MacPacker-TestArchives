#!/bin/bash
# ARC, Zoo, Amiga HDF, PSP ZSO/DAX/CSO v2 (maxcso), ECM. Ubuntu 24.04 arm64 (Bob HQ "ubuntu" VM).
# usage: ubuntu_batch3.sh <repo root> <out dir>
# Packages: arc zoo build-essential git libuv1-dev liblz4-dev zlib1g-dev pkg-config; pipx amitools
# Builds from source (pinned commits, see docs/formats/zso.md and ecm.md): maxcso (ISC), ecm-tools (GPL-3.0)
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); mkdir -p "$OUT/defaultArchives"
export SOURCE_DATE_EPOCH=1700000000 TZ=UTC PATH="$HOME/.local/bin:$PATH"
W=$(mktemp -d); cp -a "$REPO/defaultArchiveContent" "$W/c"; find "$W/c" -exec touch -h -d @$SOURCE_DATE_EPOCH {} +
C="$W/c"; D="$OUT/defaultArchives"; d() { mkdir -p "$OUT/$1"; }

# ---- ARC (arc 5.21p, SEA ARC compatible): flat, DOS 8.3 names (arc prompts forever on longer ones) ----
mkdir -p "$W/arc"; cp "$C/hello world.txt" "$W/arc/HELLO.TXT"; cp "$C/folder/README.md" "$W/arc/README.MD"; cp "$C/folder/NestedArchive.zip" "$W/arc/NESTED.ZIP"
(cd "$W/arc" && timeout 60 arc a DEFAULTA.ARC HELLO.TXT README.MD NESTED.ZIP </dev/null >/dev/null && mv DEFAULTA.ARC "$D/defaultArchive.arc")
# ---- Zoo (zoo 2.10): keeps folder paths --------------------------------------------------------------
# zoo is not packaged for Ubuntu 24.04 (removed from Debian); skipped when missing
if command -v zoo >/dev/null; then
  (cd "$C" && zoo a "$D/defaultArchive.zoo" "hello world.txt" folder/README.md folder/NestedArchive.zip >/dev/null)
fi

# ---- Amiga hard disk file: RDB with one FFS partition (amitools rdbtool + xdftool) --------------------
# baseline: a partition-less hardfile (UAE "hardfile" without RDB), FFS; an RDB-partitioned HDF is outstanding

xdftool "$D/defaultArchive.hdf" create size=2M + format defaultArchive ffs + makedir folder \
  + write "$C/hello world.txt" "hello world.txt" + write "$C/folder/README.md" folder/README.md + write "$C/folder/NestedArchive.zip" folder/NestedArchive.zip >/dev/null

# ---- maxcso: CSO v1, CSO v2, ZSO, DAX of defaultArchive.iso ------------------------------------------
B="$W/build"; mkdir -p "$B"
git clone -q https://github.com/unknownbrackets/maxcso "$B/maxcso" && git -C "$B/maxcso" checkout -q v1.13.0
make -s -C "$B/maxcso" >/dev/null 2>&1
d cso
I="$REPO/defaultArchives/defaultArchive.iso"
"$B/maxcso/maxcso" --quiet --format=cso1 -o "$OUT/cso/maxcso_v1.cso" "$I"
"$B/maxcso/maxcso" --quiet --format=cso2 -o "$OUT/cso/maxcso_v2.cso" "$I"
"$B/maxcso/maxcso" --quiet --format=zso -o "$D/defaultArchive.zso" "$I"
"$B/maxcso/maxcso" --quiet --format=dax -o "$D/defaultArchive.dax" "$I"

# ---- ECM of a raw 2352-byte MODE1 image ---------------------------------------------------------------
git clone -q https://github.com/alucryd/ecm-tools "$B/ecm" && git -C "$B/ecm" checkout -q 2765930b79fff478a6a584a554c719b8bf041422 && make -s -C "$B/ecm" >/dev/null 2>&1
# defaultArchive.bin has 2048-byte sectors, which ECM does not reduce; build the 2352-byte raw MODE1 form first
python3 -I - "$I" "$W/raw.bin" <<'PY'
import sys
# MODE1 raw sector: 12-byte sync, 4-byte header (BCD MSF + mode 1), 2048 data, EDC (4) + 8 zero + ECC (276)
def edc_table():
    t=[]
    for i in range(256):
        e=i
        for _ in range(8): e=(e>>1)^(0xD8018001 if e&1 else 0)
        t.append(e)
    return t
ET=edc_table()
def edc(b):
    e=0
    for x in b: e=(e>>8)^ET[(e^x)&0xFF]
    return e
F=[0]*256; B=[0]*256
for i in range(256):
    j=(i<<1)^(0x11D if i&0x80 else 0); F[i]=j; B[i^j]=i
def ecc_block(sec,major,minor,mmul,minc,off):
    size=major*minor
    for m in range(major):
        idx=(m>>1)*mmul+(m&1); a=b=0
        for n in range(minor):
            t=sec[0xC+idx]; idx+=minc
            if idx>=size: idx-=size
            a^=t; b^=t; a=F[a]
        a=B[F[a]^b]
        sec[off+m]=a; sec[off+m+major]=a^b
def bcd(v): return ((v//10)<<4)|(v%10)
data=open(sys.argv[1],'rb').read(); out=bytearray()
for lba in range(len(data)//2048):
    s=bytearray(2352); s[0]=0; s[1:11]=b'\xff'*10; s[11]=0
    a=lba+150; s[12]=bcd(a//4500); s[13]=bcd(a//75%60); s[14]=bcd(a%75); s[15]=1
    s[16:2064]=data[lba*2048:(lba+1)*2048]
    e=edc(s[0:2064]); s[2064:2068]=e.to_bytes(4,'little')
    ecc_block(s,86,24,2,86,0x81C); ecc_block(s,52,43,86,88,0x8C8)
    out+=s
open(sys.argv[2],'wb').write(out)
PY
d rawcd
cp "$W/raw.bin" "$W/defaultArchive-raw2352.bin"
"$B/ecm/bin2ecm" "$W/defaultArchive-raw2352.bin" "$D/defaultArchive.bin.ecm" >/dev/null
cp "$W/raw.bin" "$OUT/rawcd/mode1_2352.bin"
printf 'FILE "mode1_2352.bin" BINARY\r\n  TRACK 01 MODE1/2352\r\n    INDEX 01 00:00:00\r\n' > "$OUT/rawcd/mode1_2352.cue"
cd /; rm -rf "$W"; echo DONE
