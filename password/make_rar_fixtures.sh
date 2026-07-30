#!/bin/bash
#
# Recreates the four encrypted RAR fixtures. Separate from make_fixtures.sh
# because it needs `rar`, which is not redistributable and cannot be driven
# non-interactively on macOS (the Homebrew build hangs with no output).
#
# Run it where `rar` works — Windows (WinRAR, via Git Bash / WSL), or Linux:
#
#   Linux:   download rar from rarlab.com   (apt's `rar` also works)
#   Windows: install WinRAR, then RAR=/c/Program\ Files/WinRAR/Rar.exe ./make_rar_fixtures.sh
#
# WinRAR version note: -ma4 (write RAR3/4) exists in WinRAR 6 and was removed in
# WinRAR 7, which can only write RAR5. On WinRAR 7 the two rar4_* fixtures cannot
# be regenerated — keep the committed ones, or use a WinRAR 6 install.
#
# Payload is ../defaultArchiveContent, the same as every other defaultArchive.*
# in this repo, so PasswordTests.swift asserts the same bytes for every format.
# Password is "password" everywhere.
#
set -euo pipefail

cd "$(dirname "$0")"

RAR="${RAR:-rar}"
PW="password"

command -v "$RAR" >/dev/null || {
    echo "error: '$RAR' not found. Install rar, or set RAR=/path/to/rar" >&2
    exit 1
}

# Does this rar still know -ma4? WinRAR 7 dropped it.
if "$RAR" 2>&1 | grep -q -- "-ma4\|ma\[4,5\]"; then
    CAN_WRITE_RAR4=1
else
    CAN_WRITE_RAR4=0
    echo "note: this rar cannot write RAR3/4 (-ma4 removed in WinRAR 7); skipping rar4_* fixtures" >&2
fi

src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT

cp -R ../defaultArchiveContent/. "$src/"
find "$src" \( -name '.DS_Store' -o -name '._*' -o -name '__MACOSX' \) -delete 2>/dev/null || true

# -ep1  store paths relative to the folder being added
# -r    recurse into folder/
# -p    encrypt file data; entry names stay readable
# -hp   encrypt the header too, so the listing itself needs the password
# -ma4  write RAR3/4 (AES-128, SHA-1 key derivation) instead of RAR5
# -y    assume yes   -idq  quiet
cd "$src"
rm -f ./*.rar

"$RAR" a -y -idq -ep1 -r -p"$PW"  rar5_aes.rar              . >/dev/null
"$RAR" a -y -idq -ep1 -r -hp"$PW" rar5_encrypted_header.rar . >/dev/null
if [ "$CAN_WRITE_RAR4" = 1 ]; then
    "$RAR" a -y -idq -ep1 -r -ma4 -p"$PW"  rar4_aes.rar              . >/dev/null
    "$RAR" a -y -idq -ep1 -r -ma4 -hp"$PW" rar4_encrypted_header.rar . >/dev/null
fi

mv ./*.rar "$OLDPWD"/
cd "$OLDPWD"

# A fixture that opens without its password is useless as a password fixture.
# `rar t` is the check here, not 7zz: some 7-Zip builds (Homebrew's) ship without
# the RAR decoders and report "Unsupported Method" for every entry.
for f in ./*.rar; do
    if "$RAR" t -idq -p"wrong-$PW" "$f" >/dev/null 2>&1; then
        echo "error: $f accepted a wrong password" >&2
        exit 1
    fi
    "$RAR" t -idq -p"$PW" "$f" >/dev/null || {
        echo "error: $f rejected its own password" >&2
        exit 1
    }
    echo "ok: $f"
done

ls -l ./*.rar
