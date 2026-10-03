# DAR fixtures

For MacPacker issue [#276](https://github.com/sarensw/MacPacker/issues/276).
Created with official DAR 2.8.6 (libdar 7.0.5), using only original generated test data.
No personal or third-party content. Same MIT terms as this fixture repository.

| Archive base | Purpose |
| --- | --- |
| `plain` | Uncompressed full archive |
| `gzip` | Gzip-compressed full archive |
| `encrypted` | AES-encrypted full archive |
| `split` | Full archive split into 8 KiB slices |
| `split-padded` | Same, with three-digit slice numbers |

The public test password is `macpacker-dar-test`. DAR archive names include a
slice number even for single-file archives: `plain.1.dar`. Keep every slice
of a split set together. The CLI accepts the base name without `.1.dar`.

Each archive contains four regular files and two directories, including a
nested Unicode filename and an empty directory. `expected-files.json` lists
SHA-256 hashes for the original file contents. The generator includes the
complete source payload definition; timestamps and archive identifiers can
vary between runs, so archive bytes themselves need not be identical.

## Rebuild and verify

```sh
DAR=/path/to/dar python3 dar/make_fixtures.py
```

Requires Python 3 and DAR with gzip and AES enabled. It uses `-Q` so local DAR
configuration cannot change the fixture options. All inputs and extracted
outputs are temporary. It checks archive integrity, compares every extracted
file hash and verifies the empty directory, checks compression reduced size,
and confirms rejection of an incorrect password and a missing middle slice.
Do not use the test password for real archives.

Verified on macOS arm64 with DAR 2.8.6. This fixture contribution is the first
step required by MacPacker's AGENTS.md; app engine integration follows after
these fixtures are merged. It does not claim DAR support is already in the app.
