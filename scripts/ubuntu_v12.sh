#!/bin/bash
# Fixtures for MacPacker 1.2 formats that had none, and variants of 1.2 formats.
# Runs on Ubuntu 24.04 arm64 (Bob HQ "ubuntu" VM). Usage: ubuntu_v12.sh <content dir> <out dir>
# Packages: 7zip fp-utils wixl msitools ntfs-3g jlha-utils arj cpio gcab squashfs-tools xorriso
set -euo pipefail
SRC=$(realpath "$1"); OUT=$(realpath -m "$2"); mkdir -p "$OUT"
export SOURCE_DATE_EPOCH=1700000000 TZ=UTC
W=$(mktemp -d); cp -a "$SRC" "$W/c"; find "$W/c" \( -name .DS_Store -o -name '._*' \) -delete
touch -d @$SOURCE_DATE_EPOCH "$W/c" "$W/c/folder" "$W/c"/* "$W/c/folder"/*
cd "$W/c"
d() { mkdir -p "$OUT/$1"; }
d defaultArchives

# ---- CHM (chmcmd, Free Pascal) ---------------------------------------------
cat > p.hhp <<'H'
[OPTIONS]
Compiled file=defaultArchive.chm
Title=MacPacker test archive
Default topic=hello world.txt

[FILES]
hello world.txt
folder/README.md
folder/NestedArchive.zip
H
chmcmd p.hhp >/dev/null; rm p.hhp; mv defaultArchive.chm "$OUT/defaultArchives/"

# ---- MSI (wixl, msitools) --------------------------------------------------
cat > ../p.wxs <<'X'
<?xml version="1.0" encoding="utf-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
 <Product Id="11111111-2222-3333-4444-555555555555" Name="defaultArchive" Language="1033" Version="1.0.0" Manufacturer="MacPacker Test Archives" UpgradeCode="11111111-2222-3333-4444-666666666666">
  <Package InstallerVersion="200" Compressed="yes" Comments="MacPacker test archive"/>
  <Media Id="1" Cabinet="data.cab" EmbedCab="yes"/>
  <Directory Id="TARGETDIR" Name="SourceDir"><Directory Id="ProgramFilesFolder"><Directory Id="INSTALLDIR" Name="defaultArchive">
   <Component Id="C1" Guid="11111111-2222-3333-4444-000000000001"><File Id="hello_world.txt" Name="hello world.txt" Source="hello world.txt"/></Component>
   <Directory Id="FOLDER" Name="folder">
    <Component Id="C2" Guid="11111111-2222-3333-4444-000000000002"><File Id="README.md" Name="README.md" Source="folder/README.md"/></Component>
    <Component Id="C3" Guid="11111111-2222-3333-4444-000000000003"><File Id="NestedArchive.zip" Name="NestedArchive.zip" Source="folder/NestedArchive.zip"/></Component>
   </Directory></Directory></Directory></Directory>
  <Feature Id="F" Level="1"><ComponentRef Id="C1"/><ComponentRef Id="C2"/><ComponentRef Id="C3"/></Feature>
 </Product>
</Wix>
X
wixl -o "$OUT/defaultArchives/defaultArchive.msi" ../p.wxs

# ---- NTFS (mkntfs + kernel ntfs3) ------------------------------------------
truncate -s 8M ../n.img && mkntfs -q -F -L defaultArchive -c 4096 ../n.img >/dev/null
mkdir -p ../mnt && sudo mount -t ntfs3 -o loop ../n.img ../mnt && sudo cp -r --preserve=timestamps . ../mnt/ && sudo umount ../mnt
mv ../n.img "$OUT/defaultArchives/defaultArchive.ntfs"

# ---- LHA (jlha-utils = LHa for UNIX 1.14i) ---------------------------------
# baseline: default method -lh5-, default header level
jlha a ../b.lha "hello world.txt" folder >/dev/null && mv ../b.lha "$OUT/defaultArchives/defaultArchive.lha"
d lha_lzh
# jLHA options: z = store (-lh0-), o5/o6/o7 = method, 0/1/2 = header level (default 2)
for m in z:0 o5:5 o6:6 o7:7; do jlha a${m%%:*} ../m.lzh "hello world.txt" folder >/dev/null; mv ../m.lzh "$OUT/lha_lzh/method_lh${m##*:}.lzh"; done
for l in 0 1 2; do jlha a$l ../h.lzh "hello world.txt" folder >/dev/null; mv ../h.lzh "$OUT/lha_lzh/header_level$l.lzh"; done

# ---- 7z variants (7-Zip 23.01) ---------------------------------------------
d sevenzip
S="hello world.txt folder"
z() { 7z a -bd -bso0 "$@" "hello world.txt" folder; }
z -m0=LZMA "$OUT/sevenzip/method_lzma.7z"
z -m0=LZMA2 "$OUT/sevenzip/method_lzma2.7z"
z -m0=PPMd "$OUT/sevenzip/method_ppmd.7z"
z -m0=BZip2 "$OUT/sevenzip/method_bzip2.7z"
z -m0=Deflate "$OUT/sevenzip/method_deflate.7z"
z -m0=Copy "$OUT/sevenzip/method_copy.7z"
z -ms=on "$OUT/sevenzip/solid.7z"
z -ms=off "$OUT/sevenzip/nonsolid.7z"
z -mf=ARM64 "$OUT/sevenzip/filter_arm64.7z"
z -m0=Copy -v20k "$OUT/sevenzip/split.7z"

# ---- ZIP compression methods (7-Zip 23.01) ---------------------------------
d zip
for m in Copy Deflate Deflate64 BZip2 LZMA PPMd; do 7z a -tzip -bd -bso0 -mm=$m "$OUT/zip/method_$(echo $m|tr A-Z a-z).zip" "hello world.txt" folder; done

# ---- tar header formats (GNU tar 1.35) -------------------------------------
d tar
for f in v7 oldgnu gnu ustar posix; do tar --format=$f --sort=name --owner=0 --group=0 --numeric-owner --mtime=@$SOURCE_DATE_EPOCH -cf "$OUT/tar/format_$f.tar" "hello world.txt" folder; done

# ---- cpio header formats (GNU cpio 2.15) -----------------------------------
d cpio
for f in bin odc newc crc; do find "hello world.txt" folder | sort | cpio --quiet -o -H $f > "$OUT/cpio/format_$f.cpio"; done

# ---- ARJ methods (ARJ 3.10) ------------------------------------------------
d arj
for m in 0 1 4; do arj a -r -m$m -y "$OUT/arj/method_m$m.arj" "hello world.txt" "folder/*" >/dev/null; done

# ---- CAB (gcab 1.6) --------------------------------------------------------
d cab
gcab -c "$OUT/cab/gcab_none.cab" "hello world.txt" folder/README.md folder/NestedArchive.zip
gcab -cz "$OUT/cab/gcab_mszip.cab" "hello world.txt" folder/README.md folder/NestedArchive.zip

# ---- SquashFS compressors (squashfs-tools 4.6) -----------------------------
d squashfs
for c in gzip lzo lz4 xz zstd lzma; do mksquashfs "hello world.txt" folder "$OUT/squashfs/comp_$c.squashfs" -noappend -comp $c -all-root -quiet -no-progress >/dev/null 2>&1 || echo "squashfs $c failed"; done

# ---- ISO 9660 extensions (xorriso 1.5.6) -----------------------------------
d iso
xorriso -as mkisofs -quiet -iso-level 1 -o "$OUT/iso/level1_plain.iso" . 2>/dev/null
xorriso -as mkisofs -quiet -R -o "$OUT/iso/rockridge.iso" . 2>/dev/null
xorriso -as mkisofs -quiet -J -joliet-long -o "$OUT/iso/joliet.iso" . 2>/dev/null
xorriso -as mkisofs -quiet -R -J -iso-level 3 -o "$OUT/iso/rockridge_joliet.iso" . 2>/dev/null

cd /; rm -rf "$W"; echo DONE
