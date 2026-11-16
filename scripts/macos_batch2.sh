#!/bin/bash
# macOS 27.2 (Bob HQ lb_27 VM): regenerated defaultArchive.tar.hqx, an unsigned XIP-structured xar, a makehybrid UDF.
# usage: macos_batch2.sh <content dir> <out dir>
set -euo pipefail
O=$2; mkdir -p "$O"; W=$(mktemp -d); ditto --norsrc --noextattr "$1" "$W/c"; find "$W/c" -name .DS_Store -delete; cd "$W/c"
tar --uid 0 --gid 0 -cf "$W/d.tar" "hello world.txt" folder; binhex encode -o "$O/defaultArchive.tar.hqx" "$W/d.tar"
# XIP layout: xar (no compression) holding Content = pbzx of an odc cpio, and Metadata = plist. NOT signed: macOS xar
# 1.8dev has no --sign and `xip --sign` needs a trusted installer identity (docs/formats/xip.md).
find . -mindepth 1 | sort | cpio -o --format odc > "$W/c.cpio" 2>/dev/null
compression_tool -encode -A lzma -i "$W/c.cpio" -o "$W/Content"
printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>UncompressedSize</key>\n\t<integer>%s</integer>\n\t<key>Version</key>\n\t<integer>1</integer>\n</dict>\n</plist>\n' "$(stat -f %z "$W/c.cpio")" > "$W/Metadata"
(cd "$W" && xar -c --compression none -f "$O/unsigned_structure.xip" Content Metadata)
# -udf-version is accepted but ignored: the result is UDF 1.50
hdiutil makehybrid -quiet -udf -udf-version 2.50 -udf-volume-name defaultArchive -o "$O/udf_rev0250" "$W/c"
