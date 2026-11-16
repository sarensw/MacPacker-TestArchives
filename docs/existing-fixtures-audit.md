# Audit of the fixtures that existed before 2026-11-15

**Update 2026-11-16:** on Stephan's decision the legacy-content baselines were regenerated with current content, same
paths: the tar family, rpm, debs, arj, gtar, 7z, jar, wim, iso/bin/img (Linux, `scripts/regenerate_linux_baselines.sh`),
CHD/CSO derived from the iso, ace/cab/lzh (WinAce 2.69), exe (7-Zip 19.00 SFX), rar (WinRAR 6.02)
(`scripts/windows/`). `defaultArchive.tar.hqx` (macOS binhex) and `defaultArchive.nrg`, `.mdf`/`.mds` (WinISO 6.4.1, run 3) followed;
no fixture with older content is left. The findings below describe the state before the regeneration.

All fixtures in `defaultArchives/`, `password/`, `compressed/`, `lha_lzh/`, `lzx/`, `stuffit/` and `sevenzip/` were
extracted on 2026-11-15 and their files compared by sha256 with today's `defaultArchiveContent/`.
Raw output: `docs/verification/2026-11-15/ubuntu_existing_fixtures.jsonl`, `host_7zz.txt`, `ubuntu_unrar.txt`,
`ubuntu_native_tools.txt`, `manual_checks.txt`. Nothing was changed or regenerated; the manifest records what each one holds.

## Finding 1: three generations of "standard content"

| Generation | hello world.txt | folder/README.md | folder/NestedArchive.zip |
|---|---|---|---|
| **current** (since 9283a00, 2025-12-09) | 13 B `03ba204e…` | 437 B `30322444…` | 52334 B `466ab31d…` |
| **2025-11** (65c6ed0, 2025-11-05) | current | current | 53236 B `fa52ae6c…` |
| **2025-11, CRLF** (made on Windows, e6c3b25) | 14 B `cfce4e29…` (CRLF) | 455 B `11397df5…` (CRLF) | 53236 B `fa52ae6c…` |

| Fixtures | Hold |
|---|---|
| defaultArchive.zip, .cpio, .fat, .qcow2, .vdi, .vhd, .vhdx, .vmdk, .squashfs, .xar, .dmg; password/*.7z, *.zip, *.rar; compressed/* | **current** |
| defaultArchive.tar, -dotslash.tar, .gtar¹, .tar.{gz,bz2,xz,lzma,Z,lz,lz4,lzo,zst,br} and the short aliases (.tgz …), .rpm, .arj², defaultarchive.deb³, defaultarchive-dpkg.deb, .exe¹ | **2025-11** |
| defaultArchive.7z, .ace, .cab, .iso, .bin, .img, .nrg, .mdf, .jar, .lzh, .wim | **2025-11, CRLF** |
| defaultArchive.rar | CRLF hello world.txt and README.md, but the current NestedArchive.zip |
| defaultArchive.ar | current files, stored flat (no `folder/`) |
| defaultArchive.tar.hqx | an older layout: `defaultContent/hello world.txt`, `defaultContent/folder/README.md`, `defaultContent/folder/Archive.zip` (= 2025-11 NestedArchive.zip) |
| defaultarchive-dpkg-zstd.deb | current |

¹ `.gtar` and `.exe` name the nested zip `folder/Archive.zip`. ² ARJ stores `folder/README.md` and `folder/NestedArchive.zip` with their folder; unar shows them flat. ³ fpm adds `usr/share/doc/defaultarchive/changelog.gz`.

Impact: a test that compares extracted bytes with `defaultArchiveContent/` fails for these fixtures, and a test
that compares only names and sizes passes or fails by accident (CRLF changes sizes by one byte per line).
**Recommendation (not done, needs Stephan's decision):** regenerate the 2025-11 group with the existing Linux/macOS
scripts and the CRLF group on Windows with `core.autocrlf=false`, then re-run `scripts/verify.py` and the manifest.
Paths would not change.

## Finding 2: other observations

- `defaultArchive.cue` names `DEFAULTARCHIVE.BIN`; the file is `defaultArchive.bin`. On a case-sensitive volume the cue does not resolve.
- `defaultArchive.bin`, `.img` and `.iso` are byte-identical (2048-byte sectors), so `.bin` is not a raw 2352-byte CD image.
- `defaultArchive.dvd` is a 18-byte text file `DEFAULTARCHIVE.IMG`, not an image.
- `defaultArchive.mds`/`.mdf`: lsar calls the mdf ISO 9660, but neither unar nor 7-Zip extracted it: **unverified**.
- `defaultArchive.dmg` carries `com.apple.provenance` extended attributes on all three files (7-Zip shows them as alternate streams).
- `defaultArchive.lzh`: bsdtar 3.7.2 writes `README.md` (-lh5-) empty; lhasa and 7-Zip extract it correctly.
- `defaultArchive.ace` is ACE 2.0 (solid, "created on Win32 with ACE 2.0 for extraction with 2.0+", acefile 0.6.14). ACE 1.0 is not covered.
- `defaultArchive.rar` is RAR5 (unrar: "RAR 5", -m0/-m3). `password/rar4_*` are RAR 4 ("RAR 1.5(v29)" method), `password/rar5_*` RAR 5.
- Homebrew 7-Zip 26.03 on the host has no RAR decoder (entries extract empty); Ubuntu's 7-Zip 23.01 neither. Use unrar or unar for RAR.
- The README in the repo root lists CloneCD and MSI fixtures that do not exist (still true for CloneCD; MSI now exists).
- `stuffit/`, `lzx/`, `lha_lzh/` (the lhasa set) are third-party test files with their own README; they do not hold the standard content.
