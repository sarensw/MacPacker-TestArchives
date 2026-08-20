# Archivers

One macOS app bundle — the signed `MinimalApp.app` from `../zip/minimalApp.zip`
— compressed by each of the tools a Mac user's zip actually comes from. Same
tree in every file, so any difference belongs to the archiver.

| file | made by | what it stores |
| --- | --- | --- |
| `finder_compress.zip` | Finder "Compress" (`ditto -c -k --sequesterRsrc --keepParent`) | metadata in a `__MACOSX/` mirror |
| `ditto_inline.zip` | `ditto -c -k --keepParent` | metadata inline, as `._name` beside each file |
| `infozip.zip` | `/usr/bin/zip -r -y` | no metadata; symlinks kept |
| `keka.zip` | Keka 1.x, ZIP tab, defaults | no metadata; symlinks kept |
| `sevenzip.zip` | `7zz a -tzip` | no metadata; symlinks stored differently |

Added for MacPacker issue #189, where extracting an app bundle produced one
macOS called damaged. The fixtures written for that fix assert what the
implementation was built to do — these are archives nobody here shaped, so
extraction can be measured against Archive Utility and XADMaster instead.

`ditto_inline.zip` and `sevenzip.zip` extract to bundles `codesign` rejects.
That is the archives: both lose framework version symlinks, and Archive Utility
fails them identically.

Rebuild with `make_corpus.sh` — except `keka.zip`, which is made by hand because
Keka's CLI will not run outside its app bundle. Not byte-reproducible: the
source bundle is compiled and signed.
