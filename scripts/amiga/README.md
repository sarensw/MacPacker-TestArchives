# Amiga fixtures (2026-11-16, Bob HQ `amiga` VM: AROS on FS-UAE)

Content copied with `bob copy <id> defaultArchiveContent Share:in`, run with `bob exec <id> '<script>'`, fetched from `Share:out`.

```
MakeDir Share:out
CD Share:in
LZX -m -r -x a Share:out/defaultArchive.lzx #?        ; LZX 1.21 (registered to the Amiga community), default level
LZX -m -r -x -0 a Share:out/lzx_store.lzx #?
LZX -m -r -x -1 a Share:out/lzx_fast.lzx #?
LZX -m -r -x -9 a Share:out/lzx_max.lzx #?
zoo a Share:out/defaultArchive.zoo "hello world.txt" folder/README.md folder/NestedArchive.zip   ; zoo 2.1 (C:zoo)
ha a Share:out/defaultArchive.ha "hello world.txt" folder/README.md folder/NestedArchive.zip     ; HA 0.999 (C:ha)
```

LZX 1.21 writes its dates in the old format (`LZX v` shows 15-Dec-90 for 2026 files): the well-known LZX date field
limit, see lzx/README.md. `-1` and `-9` give different bytes; `-M1` (merge group size) gave the same bytes as the
default and was not kept. AmigArc 0.23 (C:arc) stored only README.md and was not used; ARC comes from Linux arc 5.21p.
