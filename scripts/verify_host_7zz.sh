#!/bin/bash
# Second reader for what Ubuntu's 7-Zip 23.01 cannot decode (RAR has no codec there) and for nested payloads:
# 7-Zip 26.03 (Homebrew 7zz) on the Mac. Extracts each fixture (and a tar or data.tar inside a single stream or deb)
# to a temp dir and compares sha256 with defaultArchiveContent. usage: verify_host_7zz.sh <repo root> <fixture> [password]
R=$(cd "$1" && pwd); f="$2"; pw="${3:-password}"
T=$(mktemp -d /tmp/v7.XXXX)
exp=$(cd "$R/defaultArchiveContent" && shasum -a 256 "hello world.txt" folder/README.md folder/NestedArchive.zip | awk '{print $1}' | sort)
echo "== $f"
echo "  7zz: $(7zz i | sed -n 2p | cut -c1-30); $(7zz l -slt -p"$pw" "$R/$f" 2>&1 | grep -E '^(Type|Method|Solid|Encrypted|Characteristics) =' | sort | uniq -c | tr -s ' ' | tr '\n' ';' | cut -c1-300)"
7zz x -y -bso0 -bsp0 -p"$pw" -o"$T/a" "$R/$f" >/dev/null 2>&1
# one level of nesting for single streams, rpm and deb
for n in $(find "$T/a" -type f \( -name '*.tar' -o -name 'data.tar*' -o -name '*.cpio' -o -name 'defaultArchive' \) 2>/dev/null); do mkdir -p "$T/b"; 7zz x -y -bso0 -bsp0 -o"$T/b/$(basename "$n").x" "$n" >/dev/null 2>&1; for m in $(find "$T/b" -type f -name '*.tar'); do 7zz x -y -bso0 -bsp0 -o"$m.x" "$m" >/dev/null 2>&1; rm -f "$m"; done; done
D="$T/a"; [ -d "$T/b" ] && D="$T/b"
got=$(find "$D" -type f -exec shasum -a 256 {} + | awk '{print $1}' | sort)
if [ "$got" = "$exp" ]; then echo "  content: MATCH (3 files, sha256)"; else echo "  content: files:"; (cd "$D" && find . -type f -exec shasum -a 256 {} + | cut -c1-16,65- ); fi
rm -rf "$T"
