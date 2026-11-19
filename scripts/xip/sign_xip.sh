#!/bin/bash
# Sign an XIP-structured xar with a throwaway test CA (mackyle xar 1.6.1). usage: sign_xip.sh <xar binary> <unsigned.xip> <out dir>
set -euo pipefail
XAR=$1; IN=$(realpath "$2"); OUT=$(realpath -m "$3"); mkdir -p "$OUT"; W=$(mktemp -d); cd "$W"
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem -days 3650 -subj "/CN=MacPacker TestArchives Test CA" -addext "basicConstraints=critical,CA:true" -addext "keyUsage=critical,keyCertSign" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -keyout leaf.key -out leaf.csr -subj "/CN=MacPacker TestArchives Test Installer" 2>/dev/null
printf 'basicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,1.2.840.113635.100.4.13\n' > ext.cnf
openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out leaf.pem -days 3650 -extfile ext.cnf 2>/dev/null
openssl x509 -in leaf.pem -outform DER -out leaf.der; openssl x509 -in ca.pem -outform DER -out ca.der
mkdir x && (cd x && "$XAR" -x -f "$IN")
(cd x && "$XAR" -c --compression=none -f "$OUT/defaultArchive.xip" --sign --sig-size 256 --data-to-sign "$W/dts.dat" --cert-loc "$W/leaf.der" --cert-loc "$W/ca.der" Content Metadata)
# PKCS#1 v1.5 over a SHA-1 DigestInfo of the data to sign (xar's RSA scheme)
( printf '\x30\x21\x30\x09\x06\x05\x2b\x0e\x03\x02\x1a\x05\x00\x04\x14'; cat dts.dat ) > di.dat
openssl pkeyutl -sign -inkey leaf.key -pkeyopt rsa_padding_mode:pkcs1 -in di.dat -out sig.dat
python3 -I "$(dirname "$0")/xar_sig.py" inject "$OUT/defaultArchive.xip" sig.dat   # xar --inject-sig segfaults on arm64
cp ca.pem "$OUT/testCA.pem"; cp leaf.pem "$OUT/testInstaller.pem"
ls -la dts.dat sig.dat; echo DONE
