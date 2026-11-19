#!/usr/bin/env python3
"""Write a Quake PAK of defaultArchiveContent (documented layout: "PACK", int32 directory offset, int32 directory length,
then 64-byte entries: char name[56], int32 offset, int32 length; little-endian; `/` separators).
usage: python3 -I write_pak.py <content dir> <out.pak>"""
import os, struct, sys
src, out = sys.argv[1:3]
files = ['hello world.txt', 'folder/README.md', 'folder/NestedArchive.zip']
body, dirs = bytearray(), bytearray()
for f in files:
    b = open(os.path.join(src, f), 'rb').read()
    dirs += f.encode().ljust(56, b'\0') + struct.pack('<ii', 12 + len(body), len(b)); body += b
open(out, 'wb').write(b'PACK' + struct.pack('<ii', 12 + len(body), len(dirs)) + body + dirs)
