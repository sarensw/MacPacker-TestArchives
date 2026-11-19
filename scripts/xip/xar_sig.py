#!/usr/bin/env python3
"""Inject or extract an RSA signature in a xar archive (layout: 28-byte header, zlib TOC, heap; the TOC <checksum>
and <signature> elements give heap offsets/sizes). usage: xar_sig.py inject <xar> <sig.bin> | dump <xar> <outdir>"""
import re, struct, sys, zlib, hashlib, os
def parse(path):
    b = bytearray(open(path, 'rb').read())
    magic, hsize, ver, tclen, tulen, alg = struct.unpack('>IHHQQI', b[:28]); assert magic == 0x78617221
    toc = zlib.decompress(bytes(b[hsize:hsize + tclen])).decode()
    heap = hsize + tclen
    return b, toc, heap, hsize, tclen
def elem(toc, tag):
    m = re.search(r'<%s[^>]*>.*?<offset>(\d+)</offset>\s*<size>(\d+)</size>' % tag, toc, re.S)
    return int(m.group(1)), int(m.group(2))
cmd, path = sys.argv[1], sys.argv[2]
b, toc, heap, hsize, tclen = parse(path)
co, cs = elem(toc, 'checksum'); so, ss = elem(toc, 'signature')
if cmd == 'inject':
    sig = open(sys.argv[3], 'rb').read(); assert len(sig) == ss, (len(sig), ss)
    b[heap + so:heap + so + ss] = sig; open(path, 'wb').write(b)
else:
    out = sys.argv[3]; os.makedirs(out, exist_ok=True)
    stored = bytes(b[heap + co:heap + co + cs]); actual = hashlib.sha1(bytes(b[hsize:hsize + tclen])).digest()
    open(os.path.join(out, 'toc_sha1.bin'), 'wb').write(stored); open(os.path.join(out, 'signature.bin'), 'wb').write(bytes(b[heap + so:heap + so + ss]))
    for i, c in enumerate(re.findall(r'<X509Certificate>(.*?)</X509Certificate>', toc, re.S)):
        open(os.path.join(out, 'cert%02d.pem' % i), 'w').write('-----BEGIN CERTIFICATE-----\n' + c.strip() + '\n-----END CERTIFICATE-----\n')
    print('toc checksum stored == sha1(compressed toc):', stored == actual, '| signature style:', re.search(r'<signature style="([^"]+)"', toc).group(1), '| certs:', toc.count('<X509Certificate>'))
