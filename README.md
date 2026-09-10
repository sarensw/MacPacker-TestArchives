# MacPacker Test Archives

A collection of **sample archives and disk images** used for testing [MacPacker](https://github.com/sarensw/MacPacker) — an open-source archive previewer and (future) archiver for macOS.

This repository provides reference test files across a wide range of formats to ensure reliable archive detection, metadata extraction, and preview functionality.

## 📦 Purpose

These archives are used to:
- Validate **format detection** (via file extension and magic bytes)
- Test **nested archive handling**
- Verify **preview and extraction** capabilities across supported formats

## 🧪 Structure

All archives / files that are named `defaultArchive` contain the contents of the `defaultArchive` folder. Those are at the root of the repo. In case there is any special case, or archives cannot be created anymore (e.g. due to missing tools) then there is a corresponding folder that contains those special cases.

`zip/minimalApp.zip` holds a real, launchable, ad-hoc-signed macOS app bundle (`MinimalApp.app`) compressed exactly the way Finder's "Compress" does it (`ditto -c -k --sequesterRsrc --keepParent`), so it carries the `__MACOSX/` sidecar tree, framework version symlinks, an exec-bit Mach-O and a `_CodeSignature`. Leaf names repeat across depths on purpose (`Resources`, `Info.plist`, `_CodeSignature`, `Mini`) so an extractor that flattens the subtree collides instead of failing silently — see MacPacker issue #175. Rebuild it with `zip/make_minimal_app.sh`.

`zip/markdown-kit.zip` holds a small but genuinely working JavaScript repository — it installs, builds and tests — with its entries flat at the archive root. It serves two purposes. MacPacker's screenshot plan opens it and selects `README.md`, which needs an archive that reads as a source checkout at a glance. And it is the fixture for archiving a folder while honoring its `.gitignore`: extract it, run `npm install` and `npm run build`, and the `node_modules/` and `dist/` the `.gitignore` names actually exist, so a test can re-archive the folder and assert both are absent. That is why `package.json` carries a real devDependency and a build script instead of being a plausible-looking stub. Rebuild it with `zip/make_markdown_kit.sh`; the entry dates are fixed, so a rebuild is byte-identical.

`zip/appledouble.zip` is the fixture for AppleDouble sidecar handling. When macOS has to keep a file's extended attributes and resource fork somewhere that cannot hold them — a FAT stick, an SMB share — it splits them out into a sibling `._name` file. From that point the sidecar is an ordinary file on disk, so any archiver that walks the folder stores it: zip is where it shows up most, but tar and 7z carry it just the same. Written back out as a plain file it adds an entry to the extracted tree, and inside a signed `.app` that breaks the code-signature seal — see MacPacker issue #189. Sidecars come in two arrangements and the archive holds both: beside their file, and sequestered in a top-level `__MACOSX/` mirror of the tree, which is what `ditto -c -k --sequesterRsrc` — and therefore Finder's "Compress" — produces. The sequestered one carries an attribute nothing else in the archive supplies, so it can only appear on the real file if it was folded onto that rather than onto the mirror. Because `._` is a convention rather than a reservation, the archive also pairs the genuine sidecars with two decoys that must survive untouched: a plain-text `._notadouble.txt` whose sibling exists, and a real AppleDouble `._orphan.bin` with no sibling at all. Two of the genuine ones are stored in opposite orders relative to their target on purpose, since an extractor that unpacks a sidecar the moment it reads it handles only one of them; the third, `Contents/._Resources`, describes a directory rather than a file. Rebuild it with `zip/make_appledouble.sh`; the entry dates and order are fixed, so a rebuild is byte-identical.

`zip/customicon.zip` is the fixture for a folder with a custom icon. Three separate pieces of metadata make that icon, and losing any one of them loses it: a zero-byte `Icon\r` file whose resource fork holds the `icns`, that file's `com.apple.FinderInfo` with kIsInvisible set — without which Finder shows it as `Icon?`, the shape MacPacker issue #216 was reported in — and the folder's own `com.apple.FinderInfo` with kHasCustomIcon, which is what makes Finder look for the icon file at all. Zip holds neither extended attributes nor resource forks, so all of it travels as AppleDouble the way `zip/appledouble.zip` describes; the folder's own sidecar is the half that is easy to miss, and restoring the icon file without it leaves the folder generic — which is what issue #216 looks like. The shape here is Finder's own: compressing such a folder with Finder's "Compress" produces exactly these entries. (`ditto -c -k --sequesterRsrc --keepParent` is often said to be the same command and is not — pointed at a folder it writes no sidecar for that folder, so it is no guide to what Finder stores.) The archive holds the complete form, `__MACOSX/._CustomFolder` included: extracting it must leave no `__MACOSX` and no `._` file behind, `Icon\r` invisible with its resource fork, and the folder showing the picture again. The `CustomFolder/` directory entry is part of that form and not a formality — XADMaster, and so The Unarchiver, refuses an archive whose folder sidecar describes a directory the archive never declares, abandoning the whole extraction with `xadError(11)`. Finder always writes the entry; so does MacPacker. The entry name is the other half of the fixture — `Icon\r` ends in a carriage return, which stock Info-ZIP `unzip` silently drops. Rebuild it with `zip/make_customicon.sh`; the resource fork is embedded and the entry dates and order are fixed, so a rebuild is byte-identical.

`archivers/` holds one macOS app bundle compressed by each of the tools a Mac user's zip actually comes from — Finder's "Compress", `ditto`, Info-ZIP, Keka, 7-Zip — so extraction can be checked against archives nobody tailored to it. See `archivers/README.md`.

`password/` holds the encrypted archives (ZipCrypto, WinZip AES, 7z AES, encrypted headers, awkward passwords). Unlike the rest, those are reproducible: `password/make_fixtures.sh` rebuilds them, and `password/make_rar_fixtures.sh` builds the RAR ones on a machine that has `rar`. See `password/README.md` for the matrix and the password of each file.

## 🧰 Included Formats

> Not all formats may be extractable by macOS or 7-Zip — some are included purely for identification testing.

| Format | Created where | Created how | Notes |
| --- | --- | --- | --- |
| .zip | Windows VM | 7zip app | |
| .wim | Windows VM | 7zip app | |
| .7z | Windows VM | 7zip app | |
| .tar | Linux | `create_archives_linux.sh` | |
| .jar | Windows VM | WinAce trial | | 
| .cab | Windows VM | WinAce trial | | 
| .lzh | Windows VM | WinAce trial | | 
| .ace | Windows VM | WinAce trial | | 
| .msi | Windows VM | MSI Wrapper | wrapping the self executable .exe file | 
| .iso | Windows VM | WinIso trial | |
| .nrg | Windows VM | WinIso trial | |
| .mdf (.mds) | Windows VM | WinIso trial | .mds only contains the volume info |
| .bin (.cue) | Windows VM | WinIso trial | .cue only contains the volume info |
| .img (.dvd, .ccd) | Windows VM | WinIso trial | .dvd and .ccd only contain volume info |

## ⚙️ Usage

Developers can use this repository in automated tests for format detection or extraction.

You can also clone this repository locally and reference it in your test suite:

```
git clone https://github.com/sarensw/MacPacker-TestArchives.git
```

## 🧩 Notes

All files contain non-sensitive dummy data.

Archives are small in size (< 100 KB per file) to keep the repository lightweight.

Some formats require tools like p7zip, unar, or bsdtar to create or extract.

## 📄 License

All test archives are distributed under the MIT License

They are provided solely for testing and research purposes and contain no copyrighted content.
