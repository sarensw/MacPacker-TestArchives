#!/bin/bash
#
# Rebuilds `unsupportedMethod.zip`: a zip with a file compressed by a method
# 7-Zip doesn't decode. Testing it can't tell whether that file is whole, and
# that isn't damage: MacPacker has to say it can't check the file, not that
# the file is damaged (MacPacker #232).
#
# Two files, stored. `sound.wav` is then marked as compressed with method 97,
# WavPack, which WinZip uses for .wav files and which 7-Zip lists but doesn't
# decode: it reports "Unsupported Method" for that file and tests `readme.txt`
# OK. Nothing decodes the stored bytes as WavPack, so they stay plain text.
# The method sits at 8 in a local header and at 10 in a central directory one.
#
# The dates are fixed (in UTC, as zip writes local time) and zip writes no
# extra fields (-X), so a rebuild is byte-identical.
set -euo pipefail
cd "$(dirname "$0")"

BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
printf 'This file is stored, and is checked like any other.\n' > "$BUILD/readme.txt"
printf 'This file says it is compressed with WavPack.\n' > "$BUILD/sound.wav"
TZ=UTC touch -t 202611130900 "$BUILD/readme.txt" "$BUILD/sound.wav"
(cd "$BUILD" && TZ=UTC zip -q -X -0 stored.zip readme.txt sound.wav)

python3 - "$BUILD/stored.zip" unsupportedMethod.zip <<'EOF'
import struct, sys
data = bytearray(open(sys.argv[1], "rb").read())
# signature, then where its method, its name's length and its name are
for sig, method, length, name in ((b"PK\x03\x04", 8, 26, 30), (b"PK\x01\x02", 10, 28, 46)):
    at = data.find(sig)
    while at != -1:
        size = struct.unpack_from("<H", data, at + length)[0]
        if data[at + name:at + name + size] == b"sound.wav":
            struct.pack_into("<H", data, at + method, 97)
        at = data.find(sig, at + 4)
open(sys.argv[2], "wb").write(data)
EOF
echo "wrote unsupportedMethod.zip ($(wc -c < unsupportedMethod.zip | tr -d ' ') bytes)"
