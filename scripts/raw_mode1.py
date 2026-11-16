#!/usr/bin/env python3
"""Write 2352-byte raw CD MODE1 sectors (sync, header, data, EDC, ECC) for a 2048-byte image.

usage: python3 -I raw_mode1.py <in.iso> <out.bin> [first LBA, default 0]
The MSF in each header is LBA + 150 + first LBA. EDC/ECC as in ECMA-130 (same tables as ecm/cdrdao).
"""
import sys
# MODE1 raw sector: 12-byte sync, 4-byte header (BCD MSF + mode 1), 2048 data, EDC (4) + 8 zero + ECC (276)
def edc_table():
    t=[]
    for i in range(256):
        e=i
        for _ in range(8): e=(e>>1)^(0xD8018001 if e&1 else 0)
        t.append(e)
    return t
ET=edc_table()
def edc(b):
    e=0
    for x in b: e=(e>>8)^ET[(e^x)&0xFF]
    return e
F=[0]*256; B=[0]*256
for i in range(256):
    j=(i<<1)^(0x11D if i&0x80 else 0); F[i]=j; B[i^j]=i
def ecc_block(sec,major,minor,mmul,minc,off):
    size=major*minor
    for m in range(major):
        idx=(m>>1)*mmul+(m&1); a=b=0
        for n in range(minor):
            t=sec[0xC+idx]; idx+=minc
            if idx>=size: idx-=size
            a^=t; b^=t; a=F[a]
        a=B[F[a]^b]
        sec[off+m]=a; sec[off+m+major]=a^b
def bcd(v): return ((v//10)<<4)|(v%10)
data=open(sys.argv[1],'rb').read(); out=bytearray()
for lba in range(len(data)//2048):
    s=bytearray(2352); s[0]=0; s[1:11]=b'\xff'*10; s[11]=0
    a=lba+150+(int(sys.argv[3]) if len(sys.argv)>3 else 0); s[12]=bcd(a//4500); s[13]=bcd(a//75%60); s[14]=bcd(a%75); s[15]=1
    s[16:2064]=data[lba*2048:(lba+1)*2048]
    e=edc(s[0:2064]); s[2064:2068]=e.to_bytes(4,'little')
    ecc_block(s,86,24,2,86,0x81C); ecc_block(s,52,43,86,88,0x8C8)
    out+=s
open(sys.argv[2],'wb').write(out)
