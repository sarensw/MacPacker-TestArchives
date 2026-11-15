#!/bin/bash
# Inspect the Apple-format fixtures with Apple's own tools and compare against defaultArchiveContent.
# Runs on macOS 27.2 (Bob HQ "lb_27" VM). usage: verify_macos.sh <content dir> <fixture root>
C=$(cd "$1" && pwd); cd "$2" || exit 1
PW=password
T=$(mktemp -d /tmp/v.XXXX)
exp=$(cd "$C" && shasum -a 256 "hello world.txt" folder/README.md folder/NestedArchive.zip | awk '{print $1}' | sort)
cmpdir() { got=$(find "$1" -type f ! -path '*/.fseventsd/*' ! -name '.DS_Store' ! -path '*/.Spotlight-V100/*' ! -path '*/.Trashes/*' ! -name '._*' -exec shasum -a 256 {} + | awk '{print $1}' | sort)
  if [ "$got" = "$exp" ]; then echo "  content: MATCH (3 files, sha256)"; else echo "  content: DIFF"; (cd "$1" && find . -type f -exec shasum -a 256 {} +); fi
  extra=$(cd "$1" && find . -mindepth 1 \( -name .fseventsd -o -name .Spotlight-V100 -o -name .Trashes -o -name '._*' -o -name .DS_Store \) | tr '\n' ' '); [ -n "$extra" ] && echo "  extra entries: $extra"; }
h() { echo "== $1"; }
att() { mp=$(hdiutil attach -nobrowse -readonly -noverify "$@" 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}' | head -1); echo "$mp"; }

for f in defaultArchives/defaultArchive.pkg pkg/*.pkg; do h "$f"; xar -tf "$f" | tr '\n' ' '; echo; rm -rf $T/p; pkgutil --expand-full "$f" $T/p >/dev/null 2>&1; pl=$(find $T/p -type d -name Payload | head -1); [ -n "$pl" ] && cmpdir "$pl"
  b=$(find $T/p -name Payload -type f | head -1); rm -rf $T/q; mkdir $T/q; xar -xf "$f" -C $T/q; for p in $(find $T/q -name Payload); do printf '  Payload magic: '; xxd -l 4 -p "$p"; done; done

for f in defaultArchives/defaultArchive.aar defaultArchives/defaultArchive-raw.aar aar/*.aar; do h "$f"; printf '  magic: '; xxd -l 4 "$f" | cut -c11-20; rm -rf $T/a; mkdir $T/a; aa extract -i "$f" -d $T/a && cmpdir $T/a; done

h defaultArchives/defaultArchive.aea; rm -rf $T/e; mkdir $T/e; aea decrypt -password-value "$PW$PW$PW" -i defaultArchives/defaultArchive.aea -o $T/e.aar && aa extract -i $T/e.aar -d $T/e && cmpdir $T/e
h aea/profile1_symmetric.aea; rm -rf $T/e; mkdir $T/e; aea decrypt -key-value "hex:000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f" -i aea/profile1_symmetric.aea -o $T/e.aar && aa extract -i $T/e.aar -d $T/e && cmpdir $T/e
h aea/profile0_signed.aea; rm -rf $T/e; mkdir $T/e; aea decrypt -sign-pub aea/profile0_signed.pub.pem -i aea/profile0_signed.aea -o $T/e.aar && aa extract -i $T/e.aar -d $T/e && cmpdir $T/e
for f in defaultArchives/defaultArchive.aea aea/*.aea; do printf "  $f id: "; aea id -i "$f" 2>&1 | head -1; xxd -l 8 "$f" | cut -c11-30; done

tarck() { rm -rf $T/t; mkdir $T/t; tar -xf "$1" -C $T/t && cmpdir $T/t; }
for f in defaultArchives/defaultArchive.tar.pbzx pbzx/block_lzfse.tar.pbzx pbzx/apple_compression_tool.tar.lzfse; do h "$f"; xxd -l 4 "$f" | cut -c11-20; compression_tool -decode -i "$f" -o $T/x.tar && tarck $T/x.tar; done
h defaultArchives/defaultArchive.tar.as; xxd -l 8 defaultArchives/defaultArchive.tar.as | cut -c11-30; rm -f $T/as.tar; applesingle decode -o $T/as.tar defaultArchives/defaultArchive.tar.as && tarck $T/as.tar
h defaultArchives/defaultArchive.tar.bin; rm -f $T/mb.tar; macbinary decode -o $T/mb.tar defaultArchives/defaultArchive.tar.bin && tarck $T/mb.tar
h defaultArchives/defaultArchive.tar.hqx; rm -f $T/hq.tar; binhex decode -o $T/hq.tar defaultArchives/defaultArchive.tar.hqx 2>/dev/null && tarck $T/hq.tar
for f in applesingle/forked.txt.as macbinary/forked.txt.bin binhex/forked.txt.hqx; do h "$f"; rm -rf $T/f; mkdir $T/f; case $f in *.as) applesingle decode -o $T/f/forked.txt "$f";; *.bin) macbinary decode -o $T/f/forked.txt "$f";; *.hqx) binhex decode -o $T/f/forked.txt "$f";; esac
  echo "  data: $(cat $T/f/forked.txt | xxd -p)  rsrc: $(cat $T/f/forked.txt/..namedfork/rsrc)  FinderInfo: $(xattr -px com.apple.FinderInfo $T/f/forked.txt | tr -d ' \n' | cut -c1-16)"; done

for f in dmg/*.dmg defaultArchives/defaultArchive-encrypted.dmg defaultArchives/defaultArchive.sparseimage defaultArchives/defaultArchive.sparsebundle defaultArchives/defaultArchive.apfs rawdisk/apm_hfsplus.raw rawdisk/gpt_hfsplus.raw; do
  h "$f"; hdiutil imageinfo "$f" -stdinpass <<<"$PW" 2>/dev/null | grep -E "^Format:|partition-scheme|Encrypted|Format Description" | head -4 | tr '\n' ' '; echo
  case $f in *encrypted*) mp=$(printf '%s' "$PW" | att -stdinpass "$f");; *.apfs|*.raw) mp=$(att -imagekey diskimage-class=CRawDiskImage "$f");; *) mp=$(att "$f");; esac
  [ -n "$mp" ] && { echo "  fs: $(diskutil info "$mp" | awk -F: '/File System Personality/{gsub(/^ +/,"",$2);print $2}')"; cmpdir "$mp"; hdiutil detach -quiet "$mp"; } || echo "  attach failed"; done
[ -f ../defaultArchives/defaultArchive.dmg ] && { h defaultArchive.dmg; hdiutil imageinfo ../defaultArchives/defaultArchive.dmg | grep -E "^Format:"; }

for f in xar/*.xar; do h "$f"; xar --dump-header -f "$f" | grep -E "Checksum algorithm|size"; xar --dump-toc=- -f "$f" | grep -o 'encoding style="[^"]*"' | sort | uniq -c; rm -rf $T/x; mkdir $T/x; xar -xf "$f" -C $T/x && cmpdir $T/x; done
rm -rf "$T"
