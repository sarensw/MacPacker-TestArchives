# Path migration

No existing fixture was moved, renamed or changed by the 2026-11-15 work. Existing MacPacker tests keep working
without changes.

All additions are new paths: new baselines in `defaultArchives/`, new variant directories (`aar/ adf/ aea/
applesingle/ arj/ atari_st/ binhex/ c64/ cab/ chd/ cpio/ dmg/ hfs/ iso/ macbinary/ nsis/ pbzx/ pkg/ rawdisk/
squashfs/ tar/ udf/ warc/ wim/ xar/`), new files in the existing `sevenzip/`, `zip/` and `lha_lzh/`, plus `docs/`,
`scripts/` and `manifest.json`.

Notes for test authors:
- `defaultArchives/defaultArchive.sparsebundle` is a directory (a bundle), and `defaultArchive.swm` needs
  `defaultArchive2.swm` and `defaultArchive3.swm` beside it.
- `defaultArchives/defaultArchive.tar.bin` is MacBinary, while `defaultArchive.bin` is a CD image: the extension alone
  cannot tell them apart, on purpose.
- If the legacy-content fixtures are regenerated (docs/existing-fixtures-audit.md), their paths stay; only their
  bytes and the manifest change.

| Old path | New path | Reason |
|---|---|---|
| – | – | no moves |
