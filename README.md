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

`zip/dotUnderscoreDecoy.zip` is the plain-text decoy of `zip/appledouble.zip` without the folder around it: `._notadouble.txt` beside `notadouble.txt`, both at the top of the archive. MacPacker takes an entry for a sidecar by its name alone, so the listing leaves the decoy out and shows a single top-level item, which smart extraction puts into the destination as it is, without a folder of its own. Foundation's directory listings skip every name that starts with `._`, so an extractor that stages the files and moves out what such a listing returns loses the decoy — see MacPacker PR #371. Rebuild it with `zip/make_dot_underscore_decoy.sh`; the entry dates and order are fixed, so a rebuild is byte-identical.

`zip/hiddenFiles.zip` is a folder the way a Mac leaves one, with the files Finder never shows still in it: a `.DS_Store` beside `readme.txt`, another in `folder/` beside `notes.txt`, and a dot folder `.git/` holding `HEAD`. Finder hides every name that starts with a dot, so a viewer that lists them shows files the user has never seen — see MacPacker issue #304. `.git/HEAD` is what a search runs into: its own name is not hidden, the folder it is in is. The `.DS_Store` files hold a line of text, not Finder's binary format; only their names matter here. Rebuild it with `zip/make_hidden_files.sh`; the entry dates and order are fixed, so a rebuild is byte-identical.

`zip/customicon.zip` is the fixture for a folder with a custom icon. Three separate pieces of metadata make that icon, and losing any one of them loses it: a zero-byte `Icon\r` file whose resource fork holds the `icns`, that file's `com.apple.FinderInfo` with kIsInvisible set — without which Finder shows it as `Icon?`, the shape MacPacker issue #216 was reported in — and the folder's own `com.apple.FinderInfo` with kHasCustomIcon, which is what makes Finder look for the icon file at all. Zip holds neither extended attributes nor resource forks, so all of it travels as AppleDouble the way `zip/appledouble.zip` describes; the folder's own sidecar is the half that is easy to miss, and restoring the icon file without it leaves the folder generic — which is what issue #216 looks like. The shape here is Finder's own: compressing such a folder with Finder's "Compress" produces exactly these entries. (`ditto -c -k --sequesterRsrc --keepParent` is often said to be the same command and is not — pointed at a folder it writes no sidecar for that folder, so it is no guide to what Finder stores.) The archive holds the complete form, `__MACOSX/._CustomFolder` included: extracting it must leave no `__MACOSX` and no `._` file behind, `Icon\r` invisible with its resource fork, and the folder showing the picture again. The `CustomFolder/` directory entry is part of that form and not a formality — XADMaster, and so The Unarchiver, refuses an archive whose folder sidecar describes a directory the archive never declares, abandoning the whole extraction with `xadError(11)`. Finder always writes the entry; so does MacPacker. The entry name is the other half of the fixture — `Icon\r` ends in a carriage return, which stock Info-ZIP `unzip` silently drops. Rebuild it with `zip/make_customicon.sh`; the resource fork is embedded and the entry dates and order are fixed, so a rebuild is byte-identical.

`zip/macextras.zip` is the fixture for Finder tags and Finder comments. Both are ordinary extended attributes under long names — `com.apple.metadata:_kMDItemUserTags` and `com.apple.metadata:kMDItemFinderComment` — so an extractor that folds AppleDouble back onto its file already carries them and there is no separate mechanism to get right. They earn a fixture anyway, because they are what a user notices missing, and because nothing else in the corpus shows what one looks like on disk: the values here are real binary plists, so a test can decode them and a person can drop the extracted file into Finder and see the tag. One caveat the fixture cannot fix, worth knowing before trusting a green test: Finder keeps a second copy of a comment in the enclosing folder's `.DS_Store` and Get Info reads *that*, so a comment can be restored on the file and still look blank. Rebuild it with `zip/make_macextras.sh`; the entry dates and order are fixed, so a rebuild is byte-identical.

`zip/noFolderEntries.zip` is a zip the way a download site hands one out: files only, and no entry for any of the folders their paths name. A folder is an entry of a zip only if somebody wrote it; Finder, `ditto`, Info-ZIP, Keka and 7-Zip do, because they walk a tree, while a server that puts a download together adds `Sample Kit/readme.html` and `Sample Kit/Sample Kit.txt` and is done. Whoever shows such an archive has to make the folder up, and must then not mistake the row it made up for an entry the archive can be asked for — see MacPacker issue #306, where dragging that folder out delivered one of the files inside it instead, named like the folder. The archive of that report was a font from a download site, so this is its shape with contents of our own: written by Python's `zipfile` as that one was, one file through `writestr()` (mode 0600 and no file type) and one through `write()`, with the same headers field for field. `Sample Kit/extras/licenses/license.txt` adds what the report did not have: two more folders without an entry, the outer one holding nothing but the inner one. Rebuild it with `zip/make_no_folder_entries.sh`; the entry dates are fixed, so a rebuild is byte-identical.

`zip/zipstreamer64.zip` is a zip the way Nextcloud and ownCloud hand out a download: written on the fly by ZipStreamer (`deepdiver/zipstreamer` v3.0.1, the version both ship) in its Zip64 mode, which Nextcloud's Files app uses for every folder and every selection of files and ownCloud for every download on a 64-bit server. That mode writes all ones into each field of the classic records that a Zip64 field can stand in for, the end of central directory record's two disk numbers included: 0xFFFF there means "see the Zip64 end of central directory record", which says disk 0. Read as a disk number, it makes the file look like the last volume of a spanned set, and MacPacker went looking for a `.z01` that was never there — see MacPacker issue #348, "Failed to open archive: Failed to open file". The archive of that report was a downloaded dictionary, so this is its shape with contents of our own: two stored files at the root with UTF-8 names, written by the same library, with the same headers field for field (7-Zip reports the same "Headers Error" warning for both and tests them OK). Rebuild it with `zip/make_zipstreamer64.sh`, which needs `php` with mbstring; the entry dates are fixed, so a rebuild is byte-identical.

`zip/split_zipjs64.z01`, `.z02` and `.zip` are the counterpart: a spanned set in Zip64 format, written by zip.js, which also puts 0xFFFF into the end of central directory record's disk numbers — but here the Zip64 record says "the last of three". The 0xFFFF alone does not tell a single file from the last piece of a set; only the Zip64 record does, which is where 7-Zip looks. `split_pk.zip` cannot show this: Info-ZIP's `zip -s` writes the real disk number even in Zip64 format. `zip/split_zipjs64comment.z01`, `.z02` and `.zip` are the same kind of set with the longest comment a zip allows, 65,535 bytes. The comment comes after the end of central directory record and the Zip64 records sit before it — right before it the 20-byte locator, which says how many pieces there are — so they lie beyond a reader that reaches back just far enough for the end record and the longest comment. Rebuild both sets with `zip/make_split_zipjs64.sh`, which needs `node` and `npm`; the date is fixed and the script runs with `TZ=UTC`, so a rebuild is byte-identical.

`zip/zip64LocatorDecoy.zip` is the decoy for the Zip64 locator, the 20-byte record right before the end of central directory record whose "total number of disks" tells a single file from the last piece of a set. It is a plain zip, no Zip64, whose one stored file holds the bytes of a locator that says "3 disks" — with no end record after them, which the archive's own locator would have. Compressed data holds the locator's four signature bytes by chance now and then; taken for the archive's locator, they make a single zip look like a spanned set. Rebuild it with `zip/make_zip64_locator_decoy.sh`; the entry date is fixed, so a rebuild is byte-identical.

`sevenzip/appbundle.7z` is the 7z twin of `zip/appbundle.zip`: an executable stored with mode 0755 and a symbolic link beside it, under the folder shape of a macOS app bundle, which is where losing either is fatal rather than cosmetic. Having the same tree in both formats is the point. Zip carries a POSIX-permissions field of its own; 7z has none, and keeps the mode in the high 16 bits of the Windows attribute word, flagged with `FILE_ATTRIBUTE_UNIX_EXTENSION` (0x8000). An extractor that reads only the dedicated field passes on the zip and still hands back a 0644 file and a text file holding a path — see MacPacker issue #243. Rebuild it with `sevenzip/make_appbundle.sh`; the entry dates are fixed and creation times are left out, so a rebuild is byte-identical.

`nested/` holds archives that store another archive as it is: `7zInZip.zip`, `rarInZip.zip` and `cabInZip.zip` each hold `readme.txt`, `notes.txt` and the inner archive, and `7zInTar.tar` holds the same as a tar. Stored, not compressed, the inner archive sits in the outer one byte for byte, its signature included. 7-Zip's handlers for 7z, rar and cab look for their signature anywhere in the first 4 MB of a file, and asked before the outer archive's own handler they take the file for the inner archive: the zip lists what the 7z holds, and saving it writes the 7z over the zip — see MacPacker issue #336. A zip like `7zInZip.zip` is what MacPacker itself writes when it zips a 7z, since its zip writer keeps a file that does not shrink as it is; the rar and the cab are `defaultArchives/defaultArchive.rar` and `.cab`. `spannedZip64InZip.zip` stores, last, the final piece of a spanned Zip64 set (`zip/split_zipjs64.zip`): the piece's own end records — a Zip64 locator that says "3 disks" and the end of central directory record after it — then sit in the outer zip's last few kilobytes. The outer zip is a plain one with no locator of its own, so a reader that takes the last locator in the tail sees a spanned set and goes looking for a `.z01` — see MacPacker issue #348. Only the end record that ends the file, which is also the one 7-Zip reads, belongs to the outer zip. Rebuild them with `nested/make_nested.sh`; the entry dates are fixed, so a rebuild is byte-identical.

`defaultArchives/defaultarchive-dpkg.deb` is the deb as `dpkg-deb` writes it, beside `defaultarchive.deb` from fpm. They differ in how they name their members: dpkg-deb writes `debian-binary`, fpm `debian-binary/`, with GNU ar's terminator. 7-Zip takes an ar for a deb only when its first member is `debian-binary`, and then names the `data.tar.*` inside as the archive to show — a compressed stream without a name, which listed as a lone "unknown" (MacPacker PR #340). fpm's deb opens as a plain ar and never showed that. `defaultArchives/defaultArchive.tar.lzma` and `.tlzma` are `defaultArchive.tar` through `lzma`: GNU tar's `--lzma` writes xz on Debian and Ubuntu, so the earlier ones were xz files under an lzma name.

`defaultArchives/defaultArchive-dotslash.tar` is `defaultArchiveContent` the way `tar -C defaultArchiveContent -cf x.tar .` stores it: every entry starts with `./`, and `./` itself is an entry. It is also how dpkg-deb writes a deb's `data.tar.*`; `defaultarchive-dpkg.deb` holds one, but only nested. Read as written, `.` is a folder that holds everything else: MacPacker showed it as the archive's one folder, extracted the `./` entry as an empty folder named `unknown`, and smart extraction took it for the archive's one top-level folder — see MacPacker issue #362. Rebuild it with `create_archives_linux.sh`.

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
