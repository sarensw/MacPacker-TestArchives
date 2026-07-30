# Password-protected test fixtures

Encrypted archives for MacPacker's password test suite
(`Modules/Tests/CoreTests/PasswordTests.swift`). Consumed through
`.copy("TestArchives/password")` in `Modules/Package.swift` and reached with
`Bundle.module.url(forResource: "password")`.

Unlike most archives in this repo these are reproducible:

- `make_fixtures.sh` — zip and 7z. Needs `7zz` (`brew install sevenzip`) and
  `/usr/bin/zip`. Runs on macOS.
- `make_rar_fixtures.sh` — the four RAR variants. Needs `rar`, so it has to run
  on Windows or Linux. `-ma4` (write RAR3/4) was removed in WinRAR 7, so the
  `rar4_*` fixtures need WinRAR 6.

## Payload

Every fixture holds `../defaultArchiveContent`, the same payload as the other
`defaultArchive.*` archives:

| path                      | size  |
| ------------------------- | ----- |
| `hello world.txt`         | 13    |
| `folder/README.md`        | 437   |
| `folder/NestedArchive.zip`| 52334 |

The generators copy it to a temp directory and strip `.DS_Store` / `._*` first,
so no macOS metadata ends up in the archives.

## Matrix

| file                        | encryption                                 | password        |
| --------------------------- | ------------------------------------------ | --------------- |
| `zip_zipcrypto.zip`         | ZipCrypto (legacy PKWARE)                  | `password`      |
| `zip_aes256.zip`            | WinZip AES-256                             | `password`      |
| `zip_aes128.zip`            | WinZip AES-128                             | `password`      |
| `zip_mixed.zip`             | ZipCrypto, **only `hello world.txt`**      | `password`      |
| `zip_unicode_pw.zip`        | ZipCrypto                                  | `pässwörd`      |
| `zip_symbol_pw.zip`         | WinZip AES-256                             | `p@ss w'ord"$x` |
| `zip_long_pw.zip`           | ZipCrypto                                  | 200 × `a`       |
| `zip_nested_outer.zip`      | none — holds `inner_encrypted.zip` (= `zip_aes256.zip`) | `password` for the inner |
| `7z_aes256.7z`              | AES-256, plain header                      | `password`      |
| `7z_encrypted_header.7z`    | AES-256, `-mhe=on`                         | `password`      |
| `7z_symbol_pw.7z`           | AES-256, plain header                      | `p@ss w'ord"$x` |
| `rar5_aes.rar`              | RAR5 AES-256 (PBKDF2-HMAC-SHA256)          | `password`      |
| `rar5_encrypted_header.rar` | RAR5 AES-256, `-hp`                        | `password`      |
| `rar4_aes.rar`              | RAR3/4 AES-128 (SHA-1 key derivation)      | `password`      |
| `rar4_encrypted_header.rar` | RAR3/4 AES-128, `-hp`                      | `password`      |

The three `*_encrypted_header.*` files are the only ones whose *listing* needs
the password. Everything else lists fine and fails only on extraction — which is
exactly why "wrong password" bugs used to hide.

## Verifying by hand

Homebrew's `7zz` is built without the RAR decoders and reports
`Unsupported Method` for every RAR entry, so use `rar t` (or MacPacker itself) to
check those. It reads the RAR *headers* fine, which is enough to confirm the
encryption flags:

```sh
7zz l -slt -ppassword rar5_encrypted_header.rar | grep -E '^Path|^Encrypted'
```
