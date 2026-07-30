#!/bin/bash
#
# Creates the four encrypted RAR fixtures. Separate from make_fixtures.sh because
# it needs `rar`, which is not redistributable and is not available on the macOS
# dev machine (the Homebrew build could not be driven non-interactively).
#
# Run it anywhere `rar` works — Linux, Windows (Git Bash / WSL), or a Mac with a
# working WinRAR install — then commit the four .rar files next to this script.
#
#   Linux:   sudo apt install rar     (or download from rarlab.com)
#   Windows: install WinRAR, then use Rar.exe from its install folder
#
# Payload matches the zip/7z fixtures exactly, so PasswordTests.swift can assert
# the same contents. Password is "password" everywhere.
#
set -euo pipefail

cd "$(dirname "$0")"

RAR="${RAR:-rar}"
PW="password"

command -v "$RAR" >/dev/null || {
    echo "error: '$RAR' not found. Install rar, or set RAR=/path/to/rar" >&2
    exit 1
}

src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT

mkdir -p "$src/folder"
printf 'encrypted hello\n' > "$src/hello.txt"
printf 'nested secret\n' > "$src/folder/nested.txt"

rm -f rar5_aes.rar rar5_header_encrypted.rar rar4_aes.rar rar4_header_encrypted.rar

# -ep1  store paths relative to the folder being added (no leading temp path)
# -r    recurse into folder/
# -p    encrypt file data; names stay readable
# -hp   encrypt the header too; the listing itself needs the password
# -ma4  RAR3/4 format (AES-128, SHA-1 key derivation) instead of RAR5
# -y    assume yes; -idq quiet
cd "$src"

"$RAR" a -y -idq -ep1 -r -p"$PW"          rar5_aes.rar              hello.txt folder
"$RAR" a -y -idq -ep1 -r -hp"$PW"         rar5_header_encrypted.rar hello.txt folder
"$RAR" a -y -idq -ep1 -r -ma4 -p"$PW"     rar4_aes.rar              hello.txt folder
"$RAR" a -y -idq -ep1 -r -ma4 -hp"$PW"    rar4_header_encrypted.rar hello.txt folder

mv rar5_aes.rar rar5_header_encrypted.rar rar4_aes.rar rar4_header_encrypted.rar "$OLDPWD"/
cd "$OLDPWD"

# Sanity check: every archive must reject a wrong password and accept the right
# one. A fixture that opens without a password is useless as a password fixture.
for f in rar5_aes.rar rar5_header_encrypted.rar rar4_aes.rar rar4_header_encrypted.rar; do
    if "$RAR" t -idq -p"definitely-not-$PW" "$f" >/dev/null 2>&1; then
        echo "error: $f accepted a wrong password — not encrypted?" >&2
        exit 1
    fi
    "$RAR" t -idq -p"$PW" "$f" >/dev/null || { echo "error: $f rejected '$PW'" >&2; exit 1; }
    echo "ok: $f"
done

ls -l ./*.rar
