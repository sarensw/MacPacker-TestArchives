#!/bin/bash
# Format-specific inspection for fixtures the generic readers (7z, unar, bsdtar) cannot fully check.
# Runs on Ubuntu 24.04 (Bob HQ "ubuntu" VM). usage: verify_special_ubuntu.sh <content dir> <fixture root>
# Prints the tool's own view of each fixture; hashes are compared with sha256sum against the content.
C=$(realpath "$1"); cd "$2" || exit 1
export PATH="$HOME/.local/bin:$PATH"
T=$(mktemp -d)
exp() { (cd "$C" && sha256sum "hello world.txt" folder/README.md folder/NestedArchive.zip | awk '{print $1}' | sort); }
cmpdir() { got=$(find "$1" -type f -exec sha256sum {} + | awk '{print $1}' | sort); [ "$got" = "$(exp)" ] && echo "  content: MATCH (3 files, sha256)" || { echo "  content: DIFF"; find "$1" -type f -exec sha256sum {} +; }; }
h() { echo "== $1"; }

for f in squashfs/*.squashfs defaultArchives/defaultArchive.squashfs; do [ -f "$f" ] || continue; h "$f"; unsquashfs -s "$f" | grep -E "Compression|Filesystem size|version" | head -3; rm -rf $T/s; unsquashfs -q -d $T/s "$f" >/dev/null && cmpdir $T/s; done

for f in defaultArchives/defaultArchive.ext[234]; do [ -f "$f" ] || continue; h "$f"; dumpe2fs -h "$f" 2>/dev/null | grep -E "features|revision"; e2fsck -fn "$f" >/dev/null 2>&1 && echo "  e2fsck: clean"; rm -rf $T/e; mkdir $T/e; for p in "hello world.txt" folder/README.md folder/NestedArchive.zip; do mkdir -p "$T/e/$(dirname "$p")"; debugfs -R "dump \"/$p\" \"$T/e/$p\"" "$f" >/dev/null 2>&1; done; cmpdir $T/e; done

for f in defaultArchives/defaultArchive.hfs hfs/*.hfsx; do [ -f "$f" ] || continue; h "$f"; fsck.hfsplus -n -f "$f" 2>&1 | tail -1; xxd -s 1024 -l 4 "$f"; done
for f in hfs/classic_hfs.hfs; do [ -f "$f" ] || continue; h "$f"; xxd -s 1024 -l 2 "$f"; hmount "$f" >/dev/null && hls -lR; rm -rf $T/h; mkdir -p $T/h/folder; hcopy -r ":hello world.txt" "$T/h/hello world.txt"; hcopy -r ":folder:README.md" $T/h/folder/README.md; hcopy -r ":folder:NestedArchive.zip" $T/h/folder/NestedArchive.zip; humount; cmpdir $T/h; done

for f in defaultArchives/defaultArchive.udf udf/*.udf; do [ -f "$f" ] || continue; h "$f"; udfinfo "$f" 2>/dev/null | grep -E "udfrev|label|blocksize"; done

for f in defaultArchives/defaultArchive.esd wim/*.wim; do [ -f "$f" ] || continue; h "$f"; wimlib-imagex info "$f" | grep -E "Compression|Part Number|Total Parts|Image Count|Version|Flags"; wimlib-imagex verify "$f" >/dev/null 2>&1 && echo "  wimlib verify: OK"; done
for s in defaultArchives/defaultArchive.swm wim/split.swm; do [ -f "$s" ] || continue; h "$s"; b=${s%.swm}; wimlib-imagex info "$s" | grep -E "Part Number|Total Parts"; rm -rf $T/w; wimlib-imagex apply "$s" 1 $T/w --ref="$b*.swm" >/dev/null 2>&1 && cmpdir $T/w; done

for f in defaultArchives/defaultArchive.chd chd/*.chd; do [ -f "$f" ] || continue; h "$f"; chdman info -i "$f" | grep -E "File Version|Logical size|Compression|Metadata" | head -5; chdman verify -i "$f" 2>&1 | tail -1; done
rm -f $T/x.cue $T/x.bin; chdman extractcd -i defaultArchives/defaultArchive.chd -o $T/x.cue -ob $T/x.bin >/dev/null 2>&1 && echo "  extractcd bin sha256: $(sha256sum < $T/x.bin | cut -c1-64)"
[ -f chd/harddisk_fat.chd ] && chdman extracthd -i chd/harddisk_fat.chd -o $T/x.img -f >/dev/null 2>&1 && echo "  extracthd sha256: $(sha256sum < $T/x.img | cut -c1-64)"
[ -f chd/raw_iso.chd ] && chdman extractraw -i chd/raw_iso.chd -o $T/r.iso -f >/dev/null 2>&1 && echo "  extractraw sha256: $(sha256sum < $T/r.iso | cut -c1-64)"

h defaultArchives/defaultArchive.toc; (cd defaultArchives && cdrdao show-toc defaultArchive.toc 2>&1 | grep -v -E "^Cdrdao|^  by|^$" | head -8)

h defaultArchives/defaultArchive.cso; xxd -l 24 defaultArchives/defaultArchive.cso; ciso 0 defaultArchives/defaultArchive.cso $T/c.iso >/dev/null 2>&1; echo "  decompressed sha256: $(sha256sum < $T/c.iso | cut -c1-64)"

for f in defaultArchives/defaultArchive.adf adf/*.adf; do [ -f "$f" ] || continue; h "$f"; xxd -l 4 "$f"; xdftool "$f" list; rm -rf $T/a; mkdir -p $T/a; xdftool "$f" unpack $T/a >/dev/null 2>&1; cmpdir $T/a; done

for f in c64/*.d64 c64/*.d71 c64/*.d81 c64/*.g64; do [ -f "$f" ] || continue; h "$f"; c1541 -attach "$f" -list 2>/dev/null; rm -rf $T/c; mkdir -p $T/c; (cd $T/c && c1541 -attach "$OLDPWD/$f" -read "hello world.txt" hello -read readme.md readme -read nestedarch.zip nested >/dev/null 2>&1); cmpdir $T/c; done

for f in atari_st/defaultArchive.st; do h "$f"; mdir -/ -i "$f" ::; rm -rf $T/st; mkdir $T/st; mcopy -s -i "$f" ::/ $T/st/; cmpdir $T/st; done
h atari_st/defaultArchive.msa; xxd -l 10 atari_st/defaultArchive.msa; cp atari_st/defaultArchive.msa $T/r.msa; (cd $T && hmsa r.msa >/dev/null 2>&1); echo "  msa->st sha256: $(sha256sum < $T/r.st | cut -c1-64)  st: $(sha256sum < atari_st/defaultArchive.st | cut -c1-64)"

h defaultArchives/defaultArchive.hds; qemu-img info defaultArchives/defaultArchive.hds | grep -E "format|virtual"; qemu-img compare -f parallels -F raw defaultArchives/defaultArchive.hds "$C/../defaultArchives/defaultArchive.fat" 2>&1

h defaultArchives/defaultArchive-android-sparse.img; xxd -l 8 defaultArchives/defaultArchive-android-sparse.img; simg2img defaultArchives/defaultArchive-android-sparse.img $T/u.img && cmp -s $T/u.img defaultArchives/defaultArchive.ext4 && echo "  simg2img == defaultArchive.ext4"

for f in rawdisk/*.raw; do h "$f"; sfdisk -d "$f" 2>/dev/null | grep -E "label|start="; rm -rf $T/r; mkdir $T/r; mcopy -s -i "$f@@1M" ::/ $T/r/ && cmpdir $T/r; done

h defaultArchives/defaultArchive.tar.lzfse; xxd -l 4 defaultArchives/defaultArchive.tar.lzfse; lzfse -decode -i defaultArchives/defaultArchive.tar.lzfse -o $T/l.tar && rm -rf $T/lt && mkdir $T/lt && tar -xf $T/l.tar -C $T/lt && cmpdir $T/lt

for f in defaultArchives/defaultArchive.warc warc/*.warc.gz; do [ -f "$f" ] || continue; h "$f"; (zcat -f "$f") | grep -a -E "^WARC/|^WARC-Type|^WARC-Target-URI" | sort | uniq -c; done

for f in defaultArchives/defaultArchive.chm; do h "$f"; xxd -l 8 "$f"; done
for f in defaultArchives/defaultArchive.msi; do h "$f"; msiinfo tables "$f" | tr '\n' ' '; echo; msiinfo export "$f" File; msiinfo export "$f" Directory; rm -rf $T/m; mkdir $T/m; msiextract -C $T/m "$f" >/dev/null && cmpdir $T/m; done
for f in defaultArchives/defaultArchive.ntfs; do h "$f"; ntfsinfo -m "$f" 2>/dev/null | grep -E "Volume Version|Volume Name|Cluster Size"; rm -rf $T/n; mkdir -p $T/n/folder; ntfscat "$f" "/hello world.txt" > "$T/n/hello world.txt"; ntfscat "$f" /folder/README.md > $T/n/folder/README.md; ntfscat "$f" /folder/NestedArchive.zip > $T/n/folder/NestedArchive.zip; cmpdir $T/n; done
for f in defaultArchives/defaultArchive-nsis.exe nsis/*.exe; do [ -f "$f" ] || continue; h "$f"; 7z l "$f" | grep -E "^Type|^Method|^Physical|Solid|hello|README|Nested" ; done
rm -rf "$T"
