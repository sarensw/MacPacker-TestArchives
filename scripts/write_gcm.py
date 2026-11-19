#!/usr/bin/env python3
"""Write a GameCube disc image (GCM/ISO) of defaultArchiveContent from the documented layout (YAGCD, "Disc" chapter).

usage: python3 -I write_gcm.py <content dir> <out.iso>

Layout (big-endian):
  0x0000 boot.bin (0x440): game code "DMPK", maker "00", magic 0xC2339F3D at 0x1C, game name at 0x20,
         DOL offset at 0x420, FST offset/size/max size at 0x424/0x428/0x42C
  0x0440 bi2.bin (0x2000): zeros except region 0x458 = 2 (PAL? no: 0 = NTSC-J, 1 = NTSC-U, 2 = PAL) -> 1
  0x2440 apploader: 16-byte date string, entry point, code size, trailer size, padding, then the code
  DOL:   our own stub (one text section with `b .` = 0x48000000 at 0x80003100); no Nintendo code
  FST:   12-byte entries (root, `folder` directory, three files) + string table; file data 32 KiB aligned
The image is padded to a multiple of 32 KiB, not to a full 1.4 GB disc.
"""
import os, struct, sys

src, out = sys.argv[1:3]
align = lambda n, a: (n + a - 1) // a * a
img = bytearray(0x2440)
img[0:6] = b'DMPK00'
img[0x1C:0x20] = struct.pack('>I', 0xC2339F3D)
name = b'MacPacker test archive'; img[0x20:0x20 + len(name)] = name
img[0x440 + 0x18:0x440 + 0x1C] = struct.pack('>I', 1)   # bi2 region: NTSC-U

app_code = struct.pack('>I', 0x48000000)
app = b'2026/11/19'.ljust(16, b'\0') + struct.pack('>III', 0x81200000, len(app_code), 0) + b'\0' * 4 + app_code
img += app
dol_off = align(len(img), 0x100)
text = struct.pack('>I', 0x48000000)
dol = bytearray(0x100)
struct.pack_into('>I', dol, 0x00, 0x100)          # text0 file offset
struct.pack_into('>I', dol, 0x48, 0x80003100)     # text0 load address
struct.pack_into('>I', dol, 0x90, len(text))      # text0 size
struct.pack_into('>I', dol, 0xE0, 0x80003100)     # entry point
dol += text
img += b'\0' * (dol_off - len(img)) + dol

# FST
entries = [('dir', '', None), ('file', 'hello world.txt', 'hello world.txt'), ('dir', 'folder', None),
           ('file', 'NestedArchive.zip', 'folder/NestedArchive.zip'), ('file', 'README.md', 'folder/README.md')]
names = bytearray(); name_off = []
for kind, n, _ in entries:
    name_off.append(len(names)); names += n.encode() + b'\0' if n else b''
name_off[0] = 0
fst_off = align(len(img), 0x100)
fst_size = 12 * len(entries) + len(names)
data_off = align(fst_off + fst_size, 0x8000)
fst = bytearray(); blobs = []; pos = data_off
for i, (kind, n, path) in enumerate(entries):
    if i == 0:
        fst += struct.pack('>III', 0x01000000, 0, len(entries))
    elif kind == 'dir':
        fst += struct.pack('>III', 0x01000000 | name_off[i], 0, len(entries))   # parent = root (0), next = end
    else:
        b = open(os.path.join(src, path), 'rb').read()
        fst += struct.pack('>III', name_off[i], pos, len(b)); blobs.append((pos, b)); pos = align(pos + len(b), 0x8000)
fst += names
struct.pack_into('>III', img, 0x420, dol_off, fst_off, fst_size)
struct.pack_into('>I', img, 0x42C, fst_size)
img += b'\0' * (fst_off - len(img)) + fst
img += b'\0' * (data_off - len(img))
for p, b in blobs:
    img += b'\0' * (p - len(img)) + b
img += b'\0' * (align(len(img), 0x8000) - len(img))
open(out, 'wb').write(img)
