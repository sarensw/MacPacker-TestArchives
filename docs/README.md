# Fixture documentation

These files describe every test archive in this repository: what format and variant it is, what a reader should
find inside, and how that was checked. They are meant to stand on their own, without the Confluence overview,
and to be picked up by the next person (or agent) who adds fixtures.

A fixture says nothing about whether MacPacker supports its format. The status markers below track fixture work only.

## Where things are

| Path | What |
|---|---|
| `defaultArchiveContent/` | the standard input: `hello world.txt`, `folder/README.md`, `folder/NestedArchive.zip` |
| `defaultArchives/defaultArchive.<ext>` | one **baseline** per format: standard content, ordinary settings. Compound names (`defaultArchive-nsis.exe`, `defaultArchive-encrypted.dmg`, `defaultarchive-dpkg.deb`) where two baselines share an extension |
| `<format>/` | **variants**: versions, methods, encryption, file systems, volumes (`sevenzip/`, `zip/`, `lha_lzh/`, `dmg/`, `wim/`, ...) |
| `password/`, `encodings/`, `damaged/`, `nested/`, `archivers/` | cross-format special cases, each with its own README |
| `manifest.json` | machine-readable map: fixture path → formats, role, size, sha256, expected content, verification status and evidence |
| `docs/coverage.md` | one row per format (same order as the Confluence overview): status, baseline, verified count, outstanding |
| `docs/formats/<id>.md` | per format: extensions, MIME, UTI, magic, tar use, variants covered and outstanding, blocked reasons, fixtures, evidence |
| `docs/existing-fixtures-audit.md` | what the fixtures that existed before 2026-11-15 actually contain |
| `docs/migration.md` | path changes (none so far) |
| `docs/verification/<date>/` | raw logs of every verification run |
| `scripts/` | generators and checkers (below) |

`docs/coverage.md`, `docs/formats/*.md` and `manifest.json` are generated: edit `scripts/formats.py` (format metadata,
custom expected contents) or add logs to `docs/verification/`, then run `python3 -I scripts/build_docs.py`.

## Expected content

`"expected": "standard"` in the manifest means exactly the three files of `defaultArchiveContent/` with these hashes:

| Path | Size | sha256 |
|---|---|---|
| `hello world.txt` | 13 | `03ba204e50d126e4674c005e04d82e84c21366780af1f43bd54a37816b6ab340` |
| `folder/README.md` | 437 | `30322444506aed4dd156964c5926a66eb545990301bdc41a83a2c49c66091eb3` |
| `folder/NestedArchive.zip` | 52334 | `466ab31d0374b763d3cc3b8cfe790e16314da006128071ad60982bdab256ae85` |

Formats that cannot hold this are adapted and say so (`expected` is then a sentence): ar and CBM DOS are flat, TOS
and ISO level 1 need 8.3 names, single-stream compressors hold a tar of the content (or `hello world.txt` in
`compressed/`). Folder entries, timestamps, owners and permissions are not part of `expected`.

Many fixtures made before this work hold an older version of the content; their `expected` lists what they hold
(`verified-other-content`), see `docs/existing-fixtures-audit.md`.

## Passwords

`password` everywhere (see `password/README.md`), except Apple Encrypted Archive: `aea` refuses passwords under 20
characters, so AEA uses `passwordpasswordpassword`. The AEA symmetric key and the signing public key are documented
in `docs/formats/aea.md`; no private key is stored.

## Status markers (docs/coverage.md, Confluence)

- **DONE** – baseline (or the documented substitute) exists and is verified; outstanding variants may be listed.
- **PARTIAL** – some fixtures exist; the baseline or a listed variant that matters is missing.
- **BLOCKED** – cannot be made now; the format page says what was tried and what is needed.
- **TODO** – not started. **SKIP** / **WONTDO** – as decided in the Confluence overview (console keys, consoles on sale).

## Verification

Each new fixture was checked by at least one reader that did not write it, and its extracted files were compared by
sha256 with `defaultArchiveContent`:

| Check | Where | Tool |
|---|---|---|
| `scripts/verify.py` | Bob HQ `ubuntu` VM (Ubuntu 24.04.5 arm64) | 7-Zip 23.01, unar/lsar 1.10.1 (The Unarchiver/XAD), bsdtar 3.7.2, file 5.45 |
| `scripts/verify_special_ubuntu.sh` | same | the format's own tool where no independent reader exists (unsquashfs, debugfs/e2fsck, fsck.hfsplus, hfsutils, udfinfo, wimlib, chdman, ciso, xdftool, c1541, mtools, hmsa, qemu-img compare, simg2img, lzfse, msiextract, ntfscat, cdrdao) |
| `scripts/verify_macos.sh` | Bob HQ `lb_27` VM (macOS 27.2) | hdiutil attach, aa, aea, pkgutil, applesingle/macbinary/binhex, xar, compression_tool |
| `scripts/verify_host_7zz.sh` | the Mac host | 7-Zip 26.03 (Homebrew; this build has no RAR decoder) |
| unrar | `ubuntu` VM | UNRAR 7.00 freeware (RARLAB, Ubuntu multiverse) |
| acefile | `ubuntu` VM | acefile 0.6.14 (pipx) for ACE |

Where only the creating tool could read a fixture the manifest status is `verified-creator-only` (Apple II images, ShrinkIt,
Binary II, VPK) and the format page says so; `unverified` means no reader confirmed the content (DAX, StuffIt SFX). Evidence for each fixture is in its format page and in `manifest.json`.

Versions of everything used on the Ubuntu VM: `docs/verification/2026-11-15/ubuntu_tool_versions.txt`.
All tools came from Ubuntu 24.04 archives (main/universe/multiverse), PyPI via pipx (amitools 0.9.0, acefile 0.6.14),
or ship with macOS 27.2. Licenses: GPL/LGPL/BSD/MIT for the Linux tools; unrar is RARLAB freeware (extraction only);
the macOS tools are part of the OS. No tool needed registration.

## Making fixtures

| Script | Runs on | Makes |
|---|---|---|
| `create_archives_linux.sh`, `create_archives_macos.sh`, `create_disk_images_linux.sh` | Linux / macOS | the original baselines (pre-2026-11) |
| `scripts/ubuntu_v12.sh <content> <out>` | `ubuntu` VM, needs sudo for the NTFS loop mount | CHM, MSI, NTFS, LHA baselines; variants in `sevenzip/ zip/ tar/ cpio/ arj/ cab/ squashfs/ iso/ lha_lzh/` |
| `scripts/ubuntu_next.sh <repo> <out>` | `ubuntu` VM, sudo | ext2/3/4, HFS+/HFSX/HFS, UDF, WIM/ESD/SWM, NSIS, CHD, TOC, CSO, ADF, WARC, C64, Atari ST, Parallels, Android sparse, MBR/GPT raw, LZFSE |
| `scripts/macos_fixtures.sh <content> <out>` | `lb_27` VM | pkg, aar, aea, pbzx, AppleSingle/MacBinary/BinHex, DMG variants, sparse images, APFS, APM/GPT raw, xar variants |
| `scripts/regenerate_linux_baselines.sh <content> <out>` | `ubuntu` VM | the regenerated legacy baselines (2026-11-16) |
| `scripts/ubuntu_batch3.sh`, `scripts/ubuntu_batch4.sh` (+ `verify_batch4.sh`, `write_wad_t64.py`) | `ubuntu` VM | ARC, ECM, maxcso, HDF; CiderPress II (Apple II, ShrinkIt, DiskCopy), VPK, WAD, T64, NDS, RDB HDF |
| `scripts/amiga/README.md` | `amiga` VM | LZX, Zoo, HA |
| `scripts/macos_batch2.sh` | `lb_27` VM | tar.hqx regeneration, unsigned XIP layout, makehybrid UDF |
| `scripts/windows/` (README there) | `win98`, `winxp` VMs | RAR 2.x/4/5, CAB (makecab), Inno Setup, ZIPX (WinZip), ACE (WinAce), StuffIt 5 .sit, 7-Zip SFX |
| `<dir>/make_*.sh` | see each | the special-purpose fixtures |

The scripts copy the content to a temp dir, strip `.DS_Store`/`._*`, and fix timestamps where the tool allows
(SOURCE_DATE_EPOCH=1700000000), but most outputs are not byte-reproducible (UUIDs, build times, random salts).
Rebuilt fixtures must be re-verified and the manifest rebuilt.

## Resuming the work

1. Read `docs/coverage.md`: rows with TODO, PARTIAL or BLOCKED, in Confluence order, 1.2 formats first.
2. Add the generator commands to a script in `scripts/` (or the format's directory), run it in a Bob HQ VM, copy
   the output in, run the checkers and put their logs under `docs/verification/<date>/`.
3. Add or update the format's entry in `scripts/formats.py`, run `python3 -I scripts/build_docs.py`, and update the
   Confluence overview's fixture-status column.

Next candidates (no Windows needed): ARC/Zoo (`zoo`, `nomarch`), Amiga hard disk file (amitools `rdbtool`), LZX
baseline on the `amiga` VM, maxcso (ZSO/DAX/CSO v2) and ecm built from source, XIP built by hand.
Windows VMs (`winxp`, `win98`): WinZip for ZIPX, WinRAR 2.71 RAR 2.x archive, makecab LZX/Quantum, Inno Setup,
StuffIt for Windows, ACE 1.0 via WinAce.
