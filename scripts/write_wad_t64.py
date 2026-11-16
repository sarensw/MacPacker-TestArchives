#!/usr/bin/env python3
"""Write a Doom PWAD and a C64 T64 tape image of defaultArchiveContent from their documented layouts.

usage: python3 -I write_wad_t64.py <content dir> <out.wad> <out.t64>

PWAD (Doom wiki "WAD"): 12-byte header "PWAD", int32 lump count, int32 directory offset; lumps; directory of 16-byte
entries (int32 offset, int32 size, char[8] name, NUL padded). Lumps are flat and named with up to 8 upper-case
characters: HELLO, README, NESTED.

T64 (VICE manual, "T64 tape image"): 64-byte header ("C64 tape image file" padded to 32, version 0x0101, max and used
entries, tape name 24 bytes), 32-byte directory entries (type 1, C64 type 0x82 PRG, start and end address, offset,
16-byte PETSCII name padded with 0x20), then the data. A PRG's first two bytes are its load address, so each file is
stored with start address = its first two bytes and data = the rest: a reader that rebuilds the PRG (load address +
data) gets the original bytes. A C64 file must end below $10000, so folder/NestedArchive.zip (52334 bytes, load address
0x4B50 "PK") does not fit and is left out of the T64; the tape holds `hello world.txt` and `readme.md`.
"""
import os, struct, sys

src, wad, t64 = sys.argv[1:4]
files = [('hello world.txt', 'HELLO'), ('folder/README.md', 'README'), ('folder/NestedArchive.zip', 'NESTED')]
data = [(open(os.path.join(src, p), 'rb').read(), n) for p, n in files]

out = bytearray(b'PWAD' + b'\0' * 8); dir_ = bytearray()
for b, n in data:
    dir_ += struct.pack('<ii8s', len(out), len(b), n.encode()); out += b
out[4:12] = struct.pack('<ii', len(data), len(out)); out += dir_
open(wad, 'wb').write(out)

entries = [(open(os.path.join(src, 'hello world.txt'), 'rb').read(), b'hello world.txt'),
           (open(os.path.join(src, 'folder/README.md'), 'rb').read(), b'readme.md')]
hdr = b'C64 tape image file'.ljust(32, b'\0') + struct.pack('<HHHH', 0x0101, len(entries), len(entries), 0) + b'MACPACKER'.ljust(24, b' ')
off = 64 + 32 * len(entries); dirs = bytearray(); body = bytearray()
for b, name in entries:
    start = b[0] | (b[1] << 8); payload = b[2:]; end = start + len(payload)
    assert end <= 0xFFFF, name
    dirs += struct.pack('<BBHHHII', 1, 0x82, start, end, 0, off + len(body), 0) + name.ljust(16, b' ')
    body += payload
open(t64, 'wb').write(hdr + dirs + body)
