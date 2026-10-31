#!/bin/bash
#
# Rebuilds the archives in this folder: names stored in the code page of the
# machine that wrote them, with nothing in the archive to say which one.
#
# A zip names its entries in bytes. Only a flag (general purpose bit 11) or an
# Info-ZIP Unicode path field says those bytes are UTF-8; without either, they
# are whatever the writer's code page made of the name. That is what Windows
# Explorer, WinRAR and 7-Zip write on a machine with a legacy code page, so a
# zip from China arrives in GBK and one from Japan in Shift-JIS — see MacPacker
# issue #373. A tar has no field for it at all.
#
# No tool here runs on such a system, and APFS refuses a file name that is not
# UTF-8, so nothing can be zipped from disk. These were written by Python's
# `zipfile` with one thing changed: the name goes out in the code page, without
# the flag. The rest is what those tools write: version 2.0, made on FAT, no
# extra fields.
#
#   gbk.zip         Simplified Chinese. `图片/` and `一些.txt` are the point: in
#                   GBK their bytes happen to be valid UTF-8 as well (ͼƬ, һЩ),
#                   so they do not give themselves away.
#   gbk_sidecar.zip A real AppleDouble sidecar with a GBK name, which has to
#                   stay out of the listing and fold onto its file under the
#                   decoded name. XADMaster folds UTF-8 names only. Beside it a
#                   decoy, `._说明.txt` in plain text: named like a sidecar, it
#                   stays out of the listing too and arrives as itself.
#   big5.zip        Traditional Chinese. 許, 功 and 蓋 end in 0x5C, a backslash
#                   to anyone reading byte by byte.
#   shiftjis.zip    Japanese. ソ, 表 and 能 end in 0x5C too.
#   cp949.zip       Korean. Its hangul sit in the bytes GBK has its common
#                   characters in, so every name also decodes as Chinese.
#   cp850.zip       Western Europe. Its ü, ö and é sit where CP437, the code page
#                   the zip format itself names, has them; ã and ø only here.
#   cp866.zip       Russian, as a Russian Windows writes it. Its last letters are
#                   lead bytes in Shift-JIS, which then swallow the `/` behind
#                   them: read as a whole, a path fails where its folder does not.
#   cp1251.zip      The same names in the ANSI code page, which some tools use.
#                   Every byte above 0xBF is a letter there, so nothing tells it
#                   from East Asian text: picking an encoding by hand is for this.
#   gbk_mixed.zip   GBK beside a name flagged as UTF-8: a GBK zip after a tool
#                   that writes UTF-8 added a file to it. The UTF-8 name takes an
#                   even number of bytes, so GBK decodes it too, to something else.
#   gbk_traversal.zip
#                   A GBK name that climbs out of the destination: a name read in
#                   a code page is as untrusted as any other. Its `..` must not
#                   turn into a folder in the list either: hidden like any name
#                   that starts with a dot, it would leave the list empty.
#   gbk_password.zip
#                   GBK under ZipCrypto, password `secret`. Python's zipfile
#                   cannot encrypt, so `zip` writes it under an ASCII name of the
#                   same length and the name is swapped in afterwards: it is not
#                   part of what is encrypted.
#   gbk.tar         GBK in a tar, which has no flag to set.
#
# Entry dates are fixed, so a rebuild produces byte-identical archives, except
# for gbk_password.zip, whose encryption header is random.
#
# Requires: python3 and zip (both stock with the Command Line Tools).
#
set -euo pipefail

cd "$(dirname "$0")"

python3 -I - <<'PYTHON'
import io
import tarfile
import zipfile

DATE = (2026, 10, 31, 12, 0, 0)
FAT = 0
FILE, FOLDER = 0x20, 0x10


class CodePageName(zipfile.ZipInfo):
    """A zip entry named in a code page, without the UTF-8 flag."""

    def __init__(self, name, encoding):
        super().__init__(name, date_time=DATE)
        self.encoding = encoding
        self.create_system = FAT
        self.create_version = self.extract_version = 20

    def _encodeFilenameFlags(self):
        return self.filename.encode(self.encoding), self.flag_bits & ~zipfile._MASK_UTF_FILENAME


def add(archive, entry, content=b""):
    folder = entry.filename.endswith("/")
    entry.external_attr = FOLDER if folder else FILE
    entry.compress_type = zipfile.ZIP_STORED if folder else zipfile.ZIP_DEFLATED
    archive.writestr(entry, content)


def build(out, encoding, names):
    with zipfile.ZipFile(out, "w") as archive:
        for name in names:
            add(archive, CodePageName(name, encoding), b"" if name.endswith("/") else name.encode())


# The sidecar of `helper` in zip/appledouble.zip, a genuine AppleDouble file.
with zipfile.ZipFile("../zip/appledouble.zip") as source:
    sidecar = source.read("payload/Contents/MacOS/._helper")

build("big5.zip", "big5", ["繁體中文/", "繁體中文/許功蓋.txt", "說明.txt", "報告/年度預算.txt"])
build("shiftjis.zip", "cp932", ["表示/", "表示/ソフト能力.txt", "日本語のファイル.txt", "データ/テスト.txt"])
build("cp949.zip", "cp949", ["문서/", "문서/보고서.txt", "사진/풍경.txt", "설명서.txt"])
build("cp850.zip", "cp850", ["Müller/", "Müller/Größe.txt", "Übersicht.txt", "résumé.txt", "São Paulo.txt", "Søren.txt"])
build("cp866.zip", "cp866", ["Документы/", "Документы/Отчёт.txt", "Новая папка/Договор.txt"])
build("cp1251.zip", "cp1251", ["Документы/", "Документы/Отчёт.txt", "Новая папка/Договор.txt"])

build("gbk_traversal.zip", "gbk", ["../../中文.txt"])
build("gbk.zip", "gbk", ["中文目录/", "中文目录/你好世界.txt", "中文目录/说明文档.txt", "图片/", "图片/风景.txt", "一些.txt", "readme.txt"])

with zipfile.ZipFile("gbk_sidecar.zip", "w") as archive:
    add(archive, CodePageName("中文目录/你好世界.txt", "gbk"), b"The sidecar folds onto this file.")
    add(archive, CodePageName("中文目录/._你好世界.txt", "gbk"), sidecar)
    add(archive, CodePageName("中文目录/说明.txt", "gbk"), b"Beside a file that only looks like its sidecar.")
    add(archive, CodePageName("中文目录/._说明.txt", "gbk"), b"Plain text, not AppleDouble.")

with zipfile.ZipFile("gbk_mixed.zip", "w") as archive:
    add(archive, CodePageName("中文目录/你好世界.txt", "gbk"), b"GBK name")
    # A plain ZipInfo: `zipfile` flags a name that is not ASCII as UTF-8.
    plain = zipfile.ZipInfo("新建文档.txt", date_time=DATE)
    plain.create_system = FAT
    add(archive, plain, b"UTF-8 name")

with tarfile.open("gbk.tar", "w", format=tarfile.GNU_FORMAT, encoding="gbk") as archive:
    for name in ["中文目录/", "中文目录/你好世界.txt", "图片/", "图片/风景.txt", "一些.txt"]:
        entry = tarfile.TarInfo(name.rstrip("/"))
        entry.mtime = 1793448000
        if name.endswith("/"):
            entry.type = tarfile.DIRTYPE
            entry.mode = 0o755
            archive.addfile(entry)
        else:
            content = name.encode()
            entry.size = len(content)
            entry.mode = 0o644
            archive.addfile(entry, io.BytesIO(content))
PYTHON

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
printf 'Locked behind a GBK name.\n' > "$BUILD/abcdefgh.txt"
touch -t 202610311200 "$BUILD/abcdefgh.txt"
rm -f gbk_password.zip
(cd "$BUILD" && zip -q -X -P secret encrypted.zip abcdefgh.txt)

python3 -I - "$BUILD/encrypted.zip" <<'PYTHON'
import sys

with open(sys.argv[1], "rb") as source:
    archive = source.read()
# once in the local header, once in the central directory
assert archive.count(b"abcdefgh.txt") == 2
with open("gbk_password.zip", "wb") as out:
    out.write(archive.replace(b"abcdefgh.txt", "你好世界.txt".encode("gbk")))
PYTHON

ls -l ./*.zip ./*.tar
