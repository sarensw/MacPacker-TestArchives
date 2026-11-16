#!/usr/bin/env python3
"""Write simple container formats of defaultArchiveContent from their documented layouts.

usage: python3 -I write_containers.py <content dir> <out dir> <PC-98 2HD FAT12 image>

- NScripter SAR: u16be count, u32be data offset, entries (name\\0 with `\\` separators, u32be offset, u32be size), data.
- NScripter NSA (uncompressed entries): u16be count, u32be data offset, entries (name\\0, u8 compression 0, u32be offset,
  u32be compressed size, u32be size), data. Offsets are relative to the data offset.
- CP/M LBR (Gary Novosielski): 32-byte directory entries (status, 8+3 name, u16 index, u16 length in 128-byte records,
  u16 CRC 0, dates and times 0, pad count at offset 26), first entry describes the directory; files padded to 128-byte records with 0x1A.
- PC-98: FDI (Anex86: 4096-byte header + raw 1.2M 2HD sectors, 1024-byte sectors, 8 per track, 2 heads, 77 tracks),
  D88 (688-byte header with 164 track offsets, then sectors each with a 16-byte ID header).
"""
import os, struct, sys

src, out, fat = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
files = [('hello world.txt', 'hello world.txt'), ('folder/README.md', 'folder\\README.md'), ('folder/NestedArchive.zip', 'folder\\NestedArchive.zip')]
data = [(open(os.path.join(src, p), 'rb').read(), n) for p, n in files]

def nscripter(nsa):
    ents, body, hdr_len = bytearray(), bytearray(), 6
    for b, n in data:
        hdr_len += len(n.encode()) + 1 + (13 if nsa else 8)
    for b, n in data:
        ents += n.encode() + b'\0' + ((b'\0' + struct.pack('>III', len(body), len(b), len(b))) if nsa else struct.pack('>II', len(body), len(b)))
        body += b
    return struct.pack('>HI', len(data), hdr_len) + ents + body

open(os.path.join(out, 'defaultArchive.sar'), 'wb').write(nscripter(False))
open(os.path.join(out, 'defaultArchive.nsa'), 'wb').write(nscripter(True))

# LBR: 8.3 names
lbr_files = [(data[0][0], b'HELLO   TXT'), (data[1][0], b'README  MD '), (data[2][0], b'NESTED  ZIP')]
dir_recs = 1  # 4 entries * 32 bytes = 128 bytes
entries = [b'\0' + b' ' * 11 + struct.pack('<HH', 0, dir_recs) + b'\0' * 16]
blobs, idx = [], dir_recs
for b, name in lbr_files:
    recs = (len(b) + 127) // 128; pad = recs * 128 - len(b)
    entries.append(b'\0' + name + struct.pack('<HHH', idx, recs, 0) + b'\0' * 8 + bytes([pad]) + b'\0' * 5)
    blobs.append(b + b'\x1a' * pad); idx += recs
lbr = b''.join(e.ljust(32, b'\0') for e in entries).ljust(dir_recs * 128, b'\0') + b''.join(blobs)
open(os.path.join(out, 'defaultArchive.lbr'), 'wb').write(lbr)

# PC-98 floppy (1.2M 2HD: 77 cyl * 2 heads * 8 sectors * 1024)
raw = open(fat, 'rb').read(); assert len(raw) == 77 * 2 * 8 * 1024
fdi_hdr = struct.pack('<IIIIIIII', 0, 0x90, 4096, len(raw), 1024, 8, 2, 77).ljust(4096, b'\0')
open(os.path.join(out, 'defaultArchive.fdi'), 'wb').write(fdi_hdr + raw)
tracks, offs = bytearray(), []
for t in range(154):
    offs.append(688 + len(tracks)); c, h = t // 2, t % 2
    for s in range(8):
        sec = raw[(t * 8 + s) * 1024:(t * 8 + s + 1) * 1024]
        tracks += struct.pack('<BBBBHBBB5sH', c, h, s + 1, 3, 8, 0, 0, 0, b'\0' * 5, 1024) + sec
offs += [0] * (164 - len(offs))
d88_hdr = b'MACPACKER'.ljust(17, b'\0') + b'\0' * 9 + bytes([0, 0x20]) + struct.pack('<I', 688 + len(tracks)) + struct.pack('<164I', *offs)
open(os.path.join(out, 'defaultArchive.d88'), 'wb').write(d88_hdr + tracks)
