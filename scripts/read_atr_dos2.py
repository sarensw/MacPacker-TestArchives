#!/usr/bin/env python3
"""Read the files of an Atari DOS 2.x single-density ATR (independent of the tool that wrote it).

usage: python3 -I read_atr_dos2.py <image.atr> <out dir>
Layout (Atari DOS 2.0S manual): 16-byte ATR header (0x0296 magic), 128-byte sectors numbered from 1, directory in sectors
361-368 with 16-byte entries (flags, sector count, first sector, 8+3 name). Each data sector holds 125 data bytes,
then file number (6 bits) + next sector (10 bits) and the byte count.
"""
import os, struct, sys

img, out = sys.argv[1:3]
b = open(img, 'rb').read()
assert b[:2] == b'\x96\x02', 'not an ATR'
body = b[16:]
sec = lambda n: body[(n - 1) * 128:n * 128]
os.makedirs(out, exist_ok=True)
for s in range(361, 369):
    d = sec(s)
    for i in range(8):
        e = d[i * 16:(i + 1) * 16]
        flags, count, start = e[0], struct.unpack('<H', e[1:3])[0], struct.unpack('<H', e[3:5])[0]
        if flags == 0 or flags & 0x80:
            continue
        name = (e[5:13].decode().rstrip() + '.' + e[13:16].decode().rstrip()).rstrip('.')
        data, n = bytearray(), start
        while n:
            t = sec(n); data += t[:t[127]]; n = ((t[125] & 3) << 8) | t[126]
        open(os.path.join(out, name), 'wb').write(data)
        print('%s %d bytes, %d sectors' % (name, len(data), count))
