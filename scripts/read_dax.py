#!/usr/bin/env python3
"""Decompress a PSP DAX image (independent of maxcso). usage: python3 -I read_dax.py <in.dax> <out.iso>
Layout (maxcso src/dax.h and the original DAX format by Dark_AleX): 32-byte header ("DAX\\0", u32 uncompressed size,
u32 version, u32 number of NC areas, 4 x u32 unused), u32 offset per 8 KiB frame, u16 compressed length per frame,
then (version >= 1) NC areas (u32 start frame, u32 frame count) that are stored uncompressed; other frames are deflate streams (maxcso 1.13 writes most as raw deflate and some with a
zlib header, which is also why its own --decompress fails on the file)."""
import struct, sys, zlib
b = open(sys.argv[1], 'rb').read()
magic, size, ver, nnc = struct.unpack('<4sIII', b[:16]); assert magic == b'DAX\0', magic
n = (size + 0x1FFF) // 0x2000
offs = struct.unpack('<%dI' % n, b[32:32 + 4 * n]); p = 32 + 4 * n
lens = struct.unpack('<%dH' % n, b[p:p + 2 * n]); p += 2 * n
nc = set()
if ver >= 1:
    for i in range(nnc):
        s, c = struct.unpack('<II', b[p + 8 * i:p + 8 * i + 8]); nc.update(range(s, s + c))
out = bytearray()
for i in range(n):
    chunk = b[offs[i]:offs[i] + lens[i]]
    if i in nc:
        out += chunk
    else:
        try:
            out += zlib.decompress(chunk)          # zlib-wrapped frame
        except zlib.error:
            out += zlib.decompress(chunk, -15)     # raw deflate frame
open(sys.argv[2], 'wb').write(bytes(out[:size]))
print('DAX version %d, %d frames, %d uncompressed (NC) frames, %d bytes' % (ver, n, len(nc), size))
