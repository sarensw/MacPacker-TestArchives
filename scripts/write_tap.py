#!/usr/bin/env python3
"""Write a ZX Spectrum .tap of defaultArchiveContent from the documented layout (World of Spectrum "TAP format").

usage: python3 -I write_tap.py <content dir> <out.tap>

Each file becomes a 'Bytes' (CODE) file: a 19-byte header block (flag 0x00, type 3, 10-character name, length,
start address 32768, param 32768) and a data block (flag 0xFF + data). Each block is preceded by its 2-byte length and
ends with an XOR checksum. Tape has no folders: names are hello.txt, readme.md, nested.zip (10-character limit).
"""
import os, struct, sys

def block(flag, payload):
    body = bytes([flag]) + payload
    x = 0
    for b in body:
        x ^= b
    body += bytes([x])
    return struct.pack('<H', len(body)) + body

src, out = sys.argv[1:3]
tap = bytearray()
for path, name in (('hello world.txt', 'hello.txt'), ('folder/README.md', 'readme.md'), ('folder/NestedArchive.zip', 'nested.zip')):
    data = open(os.path.join(src, path), 'rb').read()
    assert len(data) <= 0xFFFF
    header = bytes([3]) + name.encode().ljust(10, b' ') + struct.pack('<HHH', len(data), 32768, 32768)
    tap += block(0x00, header) + block(0xFF, data)
open(out, 'wb').write(tap)
