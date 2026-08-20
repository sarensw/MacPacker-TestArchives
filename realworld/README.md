# Real-world corpus

One app bundle — the signed `MinimalApp.app` from `../zip/minimalApp.zip` —
archived by the tools people actually use. Same tree in every file, so any
difference between them belongs to the archiver.

| file | made by | shape |
| --- | --- | --- |
| `finder_compress.zip` | `ditto -c -k --sequesterRsrc --keepParent` | Finder's "Compress": sidecars in a `__MACOSX/` mirror |
| `ditto_inline.zip` | `ditto -c -k --keepParent` | sidecars inline, inside the bundle |
| `infozip.zip` | `/usr/bin/zip -r -y` | no sidecars, symlinks kept |
| `sevenzip.zip` | `7zz a -tzip` | 7-Zip's zip writer, the engine Keka uses |
| `keka.zip` | Keka, by hand | added manually; its CLI will not run outside the app |

Added for MacPacker issue #189. The fixtures written for that fix assert what
the implementation was built to do, which is worth only so much when the same
hand wrote both. These are here so the extraction can be checked against
archives nobody tailored to it — read them the way Archive Utility and
XADMaster do, or we have a bug.

`ditto_inline.zip` and `sevenzip.zip` extract to bundles that fail `codesign`.
That is the archives: both lose framework version symlinks, and Archive Utility
fails them identically. Useful for comparing extractors, not for asserting a
valid bundle.

Rebuild with `make_corpus.sh`. Not byte-reproducible — the source bundle is
compiled and signed.
