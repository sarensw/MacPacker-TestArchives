#!/bin/bash
# Fixtures for formats MacPacker does not ship in 1.2 (catalog candidates and new readers).
# Runs on Ubuntu 24.04 arm64 (Bob HQ "ubuntu" VM) with sudo (loop mounts).
# usage: ubuntu_next.sh <repo root> <out dir>
# Packages: e2fsprogs hfsutils hfsprogs udftools wimtools nsis mame-tools cdrdao vice mtools hatari
#           qemu-utils android-sdk-libsparse-utils ciso lzfse wget fdisk gdisk; pipx install amitools (xdftool)
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); mkdir -p "$OUT"
export SOURCE_DATE_EPOCH=1700000000 TZ=UTC PATH="$HOME/.local/bin:$PATH"
W=$(mktemp -d); cp -a "$REPO/defaultArchiveContent" "$W/c"; find "$W/c" \( -name .DS_Store -o -name '._*' \) -delete
touch -d @$SOURCE_DATE_EPOCH "$W/c" "$W/c/folder" "$W/c"/* "$W/c/folder"/*
C="$W/c"; cd "$W"
d() { mkdir -p "$OUT/$1"; }
D="$OUT/defaultArchives"; d defaultArchives
mnt() { mkdir -p "$W/mnt"; sudo mount -t "$1" -o loop "$2" "$W/mnt"; sudo cp -r --preserve=timestamps "$C/." "$W/mnt/"; sudo umount "$W/mnt"; }

# ---- ext2/3/4 (e2fsprogs 1.47) ---------------------------------------------
for t in ext2 ext3 ext4; do
  mke2fs -q -t $t -b 1024 -U 11111111-2222-3333-4444-555555555555 -E root_owner=0:0,hash_seed=11111111-2222-3333-4444-555555555555 -L defaultArchive -d "$C" "$D/defaultArchive.$t" 4M
done

# ---- HFS+ (hfsprogs 540) and HFSX; classic HFS (hfsutils 3.2.6) ------------
truncate -s 4M "$D/defaultArchive.hfs"; mkfs.hfsplus -v defaultArchive "$D/defaultArchive.hfs" >/dev/null; mnt hfsplus "$D/defaultArchive.hfs"
d hfs
truncate -s 4M "$OUT/hfs/hfsx_casesensitive.hfsx"; mkfs.hfsplus -s -v defaultArchive "$OUT/hfs/hfsx_casesensitive.hfsx" >/dev/null; mnt hfsplus "$OUT/hfs/hfsx_casesensitive.hfsx"
dd if=/dev/zero of="$OUT/hfs/classic_hfs.hfs" bs=1k count=800 status=none
hformat -l defaultArchive "$OUT/hfs/classic_hfs.hfs" >/dev/null
hmount "$OUT/hfs/classic_hfs.hfs" >/dev/null; hmkdir :folder
hcopy -r "$C/hello world.txt" ":hello world.txt"; hcopy -r "$C/folder/README.md" ":folder:README.md"; hcopy -r "$C/folder/NestedArchive.zip" ":folder:NestedArchive.zip"; humount

# ---- UDF (udftools 2.3, kernel udf) ----------------------------------------
mkudffs -b 2048 --media-type=hd --udfrev=0x0201 --label=defaultArchive "$D/defaultArchive.udf" 2048 >/dev/null; mnt udf "$D/defaultArchive.udf"
d udf
# UDF 2.50 is refused by mkudffs for --media-type=hd
for r in 0x0102 0x0150; do mkudffs -b 2048 --media-type=hd --udfrev=$r --label=defaultArchive "$OUT/udf/udf_rev${r#0x}.udf" 2048 >/dev/null; mnt udf "$OUT/udf/udf_rev${r#0x}.udf"; done

# ---- WIM / ESD / SWM (wimlib 1.14) -----------------------------------------
d wim
for c in none xpress lzx lzms; do wimlib-imagex capture "$C" "$OUT/wim/compress_$c.wim" defaultArchive --compress=$c --no-acls >/dev/null; done
wimlib-imagex capture "$C" "$D/defaultArchive.esd" defaultArchive --solid --no-acls >/dev/null
wimlib-imagex capture "$C" "$W/big.wim" defaultArchive --compress=none --no-acls >/dev/null
# split parts are <name>.swm, <name>2.swm, <name>3.swm; all of them belong to the fixture
wimlib-imagex split "$W/big.wim" "$OUT/wim/split.swm" 0.03 >/dev/null
wimlib-imagex split "$W/big.wim" "$D/defaultArchive.swm" 0.03 >/dev/null

# ---- NSIS installer (makensis 3.09) ----------------------------------------
d nsis
for c in zlib bzip2 lzma "/SOLID lzma"; do
  n=$(echo "$c" | tr -d '/' | tr ' ' '_' | tr A-Z a-z)
  cat > "$W/i.nsi" <<N
Unicode true
SetCompressor $c
Name "defaultArchive"
OutFile "$OUT/nsis/nsis_$n.exe"
InstallDir "\$PROGRAMFILES\\defaultArchive"
RequestExecutionLevel user
Section
SetOutPath "\$INSTDIR"
File "$C/hello world.txt"
SetOutPath "\$INSTDIR\\folder"
File "$C/folder/README.md"
File "$C/folder/NestedArchive.zip"
SectionEnd
N
  makensis -V1 "$W/i.nsi"
done
cp "$OUT/nsis/nsis_zlib.exe" "$D/defaultArchive-nsis.exe"

# ---- MAME CHD (chdman 0.264) -----------------------------------------------
cp "$REPO/defaultArchives/defaultArchive.bin" "$W/DEFAULTARCHIVE.BIN"; cp "$REPO/defaultArchives/defaultArchive.cue" "$W/x.cue"
chdman createcd -i "$W/x.cue" -o "$D/defaultArchive.chd" -f >/dev/null 2>&1
d chd
cp "$REPO/defaultArchives/defaultArchive.fat" "$W/fat.img"
chdman createhd -i "$W/fat.img" -o "$OUT/chd/harddisk_fat.chd" -f >/dev/null 2>&1
chdman createraw -i "$W/DEFAULTARCHIVE.BIN" -o "$OUT/chd/raw_iso.chd" -us 2048 -hs 2048 -f >/dev/null 2>&1

# ---- cdrdao TOC over defaultArchive.bin ------------------------------------
printf 'CD_ROM\n\n// MacPacker test archive: one MODE1 data track, 2048-byte sectors\nTRACK MODE1\nDATAFILE "defaultArchive.bin"\n' > "$D/defaultArchive.toc"

# ---- PSP CSO v1 (ciso 1.0.0) -----------------------------------------------
ciso 9 "$REPO/defaultArchives/defaultArchive.iso" "$D/defaultArchive.cso" >/dev/null || true; test -s "$D/defaultArchive.cso"

# ---- Amiga ADF (amitools xdftool) ------------------------------------------
d adf
for fs in ofs ffs; do
  f="$OUT/adf/dos_$fs.adf"
  xdftool "$f" create + format defaultArchive $fs + makedir folder + write "$C/hello world.txt" "hello world.txt" + write "$C/folder/README.md" folder/README.md + write "$C/folder/NestedArchive.zip" folder/NestedArchive.zip
done
cp "$OUT/adf/dos_ofs.adf" "$D/defaultArchive.adf"

# ---- WARC (GNU Wget 1.21) over a local HTTP server -------------------------
d warc
(cd "$C" && python3 -I -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 & echo $! > "$W/http.pid"); sleep 1
printf 'http://127.0.0.1:8765/hello%%20world.txt\nhttp://127.0.0.1:8765/folder/README.md\nhttp://127.0.0.1:8765/folder/NestedArchive.zip\n' > "$W/urls"
(cd "$W" && wget -q -i urls --warc-file=defaultArchive --no-warc-compression --no-warc-keep-log -O /dev/null && mv defaultArchive.warc "$D/defaultArchive.warc")
(cd "$W" && wget -q -i urls --warc-file=gzip -O /dev/null --no-warc-keep-log && mv gzip.warc.gz "$OUT/warc/gzip_per_record.warc.gz")
kill "$(cat "$W/http.pid")" 2>/dev/null || true

# ---- Commodore 64/128 disks (VICE c1541 3.7) -------------------------------
# CBM DOS: no folders, 16-character names: flat, renamed (see docs/formats/c64.md)
d c64
for t in d64 d71 d81 g64; do
  c1541 -format "defaultarchive,01" $t "$OUT/c64/defaultArchive.$t" -write "$C/hello world.txt" "hello world.txt" -write "$C/folder/README.md" "readme.md" -write "$C/folder/NestedArchive.zip" "nestedarch.zip" >/dev/null
done
cp "$OUT/c64/defaultArchive.d64" "$D/defaultArchive.d64"

# ---- Atari ST floppy .st (mtools 4.0) and .msa (Hatari hmsa 2.4) -----------
# TOS FAT12 without long names: 8.3 names (HELLO.TXT, FOLDER/README.MD, FOLDER/NESTED.ZIP)
d atari_st
dd if=/dev/zero of="$OUT/atari_st/defaultArchive.st" bs=512 count=1440 status=none
mformat -i "$OUT/atari_st/defaultArchive.st" -f 720 -v DEFAULT ::
mmd -i "$OUT/atari_st/defaultArchive.st" ::/FOLDER
mcopy -i "$OUT/atari_st/defaultArchive.st" "$C/hello world.txt" ::/HELLO.TXT
mcopy -i "$OUT/atari_st/defaultArchive.st" "$C/folder/README.md" ::/FOLDER/README.MD
mcopy -i "$OUT/atari_st/defaultArchive.st" "$C/folder/NestedArchive.zip" ::/FOLDER/NESTED.ZIP
(cd "$OUT/atari_st" && { hmsa defaultArchive.st >/dev/null || true; } && test -s defaultArchive.msa)  # hmsa exits non-zero even on success
cp "$OUT/atari_st/defaultArchive.st" "$D/defaultArchive.st"; cp "$OUT/atari_st/defaultArchive.msa" "$D/defaultArchive.msa"

# ---- Parallels expanding disk (qemu-img 8.2) -------------------------------
qemu-img convert -f raw -O parallels "$REPO/defaultArchives/defaultArchive.fat" "$D/defaultArchive.hds"

# ---- Android sparse image (img2simg) of defaultArchive.ext4 ----------------
img2simg "$D/defaultArchive.ext4" "$D/defaultArchive-android-sparse.img"

# ---- Raw disk images: MBR and GPT with one 2 MiB FAT12 partition at sector 2048 -----
d rawdisk
truncate -s 2M "$W/p.fat"; mformat -i "$W/p.fat" -v DEFAULT ::; mmd -i "$W/p.fat" ::/folder
mcopy -i "$W/p.fat" "$C/hello world.txt" ::/; mcopy -i "$W/p.fat" "$C/folder/README.md" "$C/folder/NestedArchive.zip" ::/folder/
for pt in mbr gpt; do
  f="$OUT/rawdisk/${pt}_fat.raw"; truncate -s 4M "$f"
  if [ $pt = mbr ]; then printf 'label: dos\nlabel-id: 0x11223344\nstart=2048, size=4096, type=1\n' | sfdisk -q "$f"
  else printf 'label: gpt\nlabel-id: 11111111-2222-3333-4444-555555555555\nstart=2048, size=4096, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, uuid=11111111-2222-3333-4444-000000000001\n' | sfdisk -q "$f"; fi
  dd if="$W/p.fat" of="$f" bs=512 seek=2048 conv=notrunc status=none
done
cp "$OUT/rawdisk/mbr_fat.raw" "$D/defaultArchive.raw"

# ---- LZFSE (lzfse 1.0) single stream over a tar ----------------------------
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@$SOURCE_DATE_EPOCH -C "$C" -cf "$W/d.tar" "hello world.txt" folder
lzfse -encode -i "$W/d.tar" -o "$D/defaultArchive.tar.lzfse"

cd /; sudo rm -rf "$W"; echo DONE
