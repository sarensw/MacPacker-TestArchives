#!/bin/bash
#
# Regenerates the password-protected zip and 7z fixtures in this folder.
# The RAR ones need a Windows/Linux machine — see make_rar_fixtures.sh.
#
# The archives are committed so the test suite needs no external tooling; this
# script only needs to run when the matrix changes.
#
# Requires: 7zz (brew install sevenzip) and zip (macOS built-in).
#
set -euo pipefail

cd "$(dirname "$0")"

PW="password"
PW_UNICODE="pässwörd"
PW_SYMBOLS="p@ss w'ord\"\$x"
PW_LONG="$(printf 'a%.0s' {1..200})"

# --- payload ------------------------------------------------------------------
# ../defaultArchiveContent, the same payload as every other defaultArchive.* in
# this repo:
#
#   hello world.txt            (13 bytes, and a space in the name)
#   folder/README.md           (437 bytes)
#   folder/NestedArchive.zip   (52334 bytes — a plain nested archive)
#
# Copied to a temp dir first so the archives never pick up .DS_Store or the
# ._* AppleDouble files Finder leaves behind. `zip -X` and 7zz's defaults keep
# the extra attribute streams out too.
src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT

cp -R ../defaultArchiveContent/. "$src/"
find "$src" \( -name '.DS_Store' -o -name '._*' -o -name '__MACOSX' \) -delete

rm -f ./*.zip ./*.7z

# --- zip: ZipCrypto (legacy PKWARE) -------------------------------------------
# What `zip -e`, Finder-adjacent tools and most "quick password" flows produce.
(cd "$src" && zip -q -X -r -P "$PW" zip_zipcrypto.zip .)
mv "$src/zip_zipcrypto.zip" .

# --- zip: WinZip AES ----------------------------------------------------------
# The modern default of 7-Zip/WinZip/Keka. AES needs the extra field 0x9901 and
# an HMAC check, so it fails differently from ZipCrypto on a wrong password.
(cd "$src" && 7zz a -tzip -mem=AES256 -p"$PW" -bso0 -bsp0 zip_aes256.zip . >/dev/null)
mv "$src/zip_aes256.zip" .
(cd "$src" && 7zz a -tzip -mem=AES128 -p"$PW" -bso0 -bsp0 zip_aes128.zip . >/dev/null)
mv "$src/zip_aes128.zip" .

# --- zip: only some entries encrypted -----------------------------------------
# "hello world.txt" is encrypted, everything under folder/ is not, so listing
# and extracting the plain entries must work with no prompt at all.
(cd "$src" && zip -q -X -P "$PW" zip_mixed.zip "hello world.txt")
(cd "$src" && zip -q -X -r zip_mixed.zip folder)
mv "$src/zip_mixed.zip" .

# --- zip: awkward passwords ---------------------------------------------------
# Non-ASCII exercises the bridge's UTF-8 -> UTF-16 password conversion. Written
# with `zip` because the 7zz CLI rejects non-ASCII -p arguments on macOS; both
# ZipCrypto and AES reach the conversion through CryptoGetTextPassword anyway.
(cd "$src" && zip -q -X -r -P "$PW_UNICODE" zip_unicode_pw.zip .)
mv "$src/zip_unicode_pw.zip" .
(cd "$src" && zip -q -X -r -P "$PW_LONG" zip_long_pw.zip .)
mv "$src/zip_long_pw.zip" .
(cd "$src" && 7zz a -tzip -mem=AES256 -p"$PW_SYMBOLS" -bso0 -bsp0 zip_symbol_pw.zip . >/dev/null)
mv "$src/zip_symbol_pw.zip" .

# --- zip: encrypted archive nested inside a plain one -------------------------
# Opening the inner archive extracts it first, so the password prompt has to
# survive one level of nesting.
cp zip_aes256.zip "$src/inner_encrypted.zip"
(cd "$src" && zip -q -X zip_nested_outer.zip inner_encrypted.zip)
mv "$src/zip_nested_outer.zip" .
rm -f "$src/inner_encrypted.zip"

# --- 7z -----------------------------------------------------------------------
(cd "$src" && 7zz a -t7z -p"$PW" -bso0 -bsp0 7z_aes256.7z . >/dev/null)
mv "$src/7z_aes256.7z" .
# -mhe=on encrypts the header too: the entry list itself needs the password,
# so loadArchive (not just extract) has to prompt.
(cd "$src" && 7zz a -t7z -p"$PW" -mhe=on -bso0 -bsp0 7z_encrypted_header.7z . >/dev/null)
mv "$src/7z_encrypted_header.7z" .
(cd "$src" && 7zz a -t7z -p"$PW_SYMBOLS" -bso0 -bsp0 7z_symbol_pw.7z . >/dev/null)
mv "$src/7z_symbol_pw.7z" .

# --- verify -------------------------------------------------------------------
# A fixture that opens without its password is useless as a password fixture.
check() {
    local file="$1" pw="$2"
    if 7zz t -p"wrong-$pw" "$file" >/dev/null 2>&1; then
        echo "error: $file accepted a wrong password" >&2
        exit 1
    fi
    7zz t -p"$pw" "$file" >/dev/null || {
        echo "error: $file rejected its own password" >&2
        exit 1
    }
    echo "ok: $file"
}

check zip_zipcrypto.zip       "$PW"
check zip_aes256.zip          "$PW"
check zip_aes128.zip          "$PW"
check zip_mixed.zip           "$PW"
check zip_unicode_pw.zip      "$PW_UNICODE"
check zip_symbol_pw.zip       "$PW_SYMBOLS"
check zip_long_pw.zip         "$PW_LONG"
check 7z_aes256.7z            "$PW"
check 7z_encrypted_header.7z  "$PW"
check 7z_symbol_pw.7z         "$PW_SYMBOLS"

ls -l
