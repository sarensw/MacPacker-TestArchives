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
#   gbk_unflagged.zip
#                   GBK beside a real UTF-8 name with no flag, which is what a tool
#                   writes that takes UTF-8 for granted. Only the bytes can tell.
#   gbk_flagged.zip GBK beside names flagged as UTF-8 that are not East Asian, so
#                   nothing about them looks like UTF-8 to anyone who ignores the
#                   flag: Отчёт.txt in GBK is 袨褌褔褢褌.txt, Señor.txt is Se帽or.txt.
#   cp866_lookalike.zip
#                   Russian names whose bytes happen to be valid UTF-8 as well,
#                   beside one that is not and one flagged as UTF-8. сон in CP866
#                   is E1 AE AD, one Sundanese letter in UTF-8. Nothing tells which
#                   reading is meant, which is what picking an encoding is for,
#                   and the pick must not touch the flagged name.
#   gbk_traversal.zip
#                   A GBK name that climbs out of the destination: a name read in
#                   a code page is as untrusted as any other. Its `..` must not
#                   turn into a folder in the list either: hidden like any name
#                   that starts with a dot, it would leave the list empty.
#   gbk_twins.zip   Three files that land on one path, each with its own content:
#                   `../中文.txt`, `./中文.txt` and `中文.txt`. Rewriting the archive
#                   extracts them first, and must not let one replace the others.
#   gbk_password.zip
#                   GBK under ZipCrypto, password `secret`. Python's zipfile
#                   cannot encrypt, so `zip` writes it under an ASCII name of the
#                   same length and the name is swapped in afterwards: it is not
#                   part of what is encrypted.
#   gbk.tar         GBK in a tar, which has no flag to set.
#   gbk_combining.zip
#                   Names that start on a character whose GBK bytes are valid UTF-8
#                   for a combining mark: 通 is CD A8, U+0368. Behind a `/`, the `/`
#                   and that mark are one Swift Character.
#   gbk_escape_bytes.zip, big5_escape_bytes.zip
#                   Bytes that read as the very character 7-Zip escapes a stray
#                   byte to: EE BE B2 in 李静 is valid UTF-8 for U+EFB2, and U+EFB2
#                   is also what it makes of a lone B2.
#   big5_windows.zip
#                   恒 and 碁, which Windows has in its Big5 and the standard has not.
#   gbk_unicode_path.zip
#                   GBK beside names with an Info-ZIP Unicode path field. No flag,
#                   but declared all the same.
#   gbk_pax.tar     GBK beside names in a pax `path` record, which is how a tar
#                   declares UTF-8.
#   gbk_flag_wrong.zip
#                   GBK bytes under the UTF-8 flag, which is what a tool writes that
#                   takes the bytes for UTF-8 because the locale says so.
#   gbk_flip.zip    Cut down to `文档/`, it holds too little to tell GBK from CP949:
#                   a save that leaves only that must not change how it reads.
#   gbk_cv.zip, gbk_forms.zip
#                   Everyday Chinese that stays in the bytes of everyday Korean.
#   cp866_symbols.zip, cp850_symbols.zip
#                   One name with a №, § or ° among names of nothing but letters.
#   utf8_stray_latin1.tar
#                   UTF-8 throughout but for one name in Latin-1. That one name
#                   must not turn the others into Chinese.
#   nested_gbk.zip  A GBK zip inside a zip in CP1251, which takes a pick by hand.
#   dotdot_entry.zip
#                   A folder entry `sub/../` after `sub/x.txt`.
#   sjis_backslash.lzh, sjis_backslash.rar, sjis_backslash.cab
#                   Shift-JIS with ソ, 表, 能, 予 and 申, whose second byte is 0x5C.
#                   7-Zip turns each 0x5C of these formats into `/`, as it takes
#                   them all for path separators. Written byte by byte, as nothing
#                   here writes these formats in a code page: stored, in the plainest
#                   header each has (LZH level 0, RAR 4, a CAB without checksums).
#   macroman.sit, macjapanese.sit
#                   Classic StuffIt, stored, as a Mac wrote it. Mac Roman puts `é`
#                   at 0x8E, where CP850 has `Ä`, so only the format tells them apart.
#   gbk_accident.zip, gbk_accident.tar
#                   Nothing but Chinese whose GBK bytes happen to be valid UTF-8, so
#                   not one byte gives it away: 图片 reads ͼƬ and 一些 reads һЩ. Only
#                   someone who sees the names can tell, which is what a pick is for.
#   utf8_unflagged.zip
#                   Real UTF-8 with no flag. Nothing tells it from the two above, so
#                   it reads as it is and takes a pick all the same.
#   unicode.7z      A 7z stores UTF-16, so its names are never in a code page and
#                   there is nothing to pick.
#
# Entry dates are fixed, so a rebuild produces byte-identical archives, except
# for gbk_password.zip, whose encryption header is random.
#
# Requires: python3 and zip (both stock with the Command Line Tools), and 7zz.
#
set -euo pipefail

cd "$(dirname "$0")"

python3 -I - <<'PYTHON'
import io
import struct
import tarfile
import zipfile
import zlib

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


def flagged(name):
    """A zip entry named in UTF-8, with the flag: `zipfile` sets it for a name that is not ASCII."""
    entry = zipfile.ZipInfo(name, date_time=DATE)
    entry.create_system = FAT
    return entry


class WronglyFlaggedName(CodePageName):
    """A zip entry named in a code page, with the UTF-8 flag all the same."""

    def _encodeFilenameFlags(self):
        return self.filename.encode(self.encoding), self.flag_bits | zipfile._MASK_UTF_FILENAME


def unicode_path(name, encoding):
    """A zip entry with an Info-ZIP Unicode path field holding its real name."""
    entry = CodePageName(name, encoding)
    field = struct.pack("<BI", 1, zlib.crc32(name.encode(encoding))) + name.encode()
    entry.extra = struct.pack("<HH", 0x7075, len(field)) + field
    return entry


def crc16(data):
    """The CRC of LZH and StuffIt."""
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = crc >> 1 ^ 0xA001 if crc & 1 else crc >> 1
    return crc


DOS_TIME = 0x5D5F6000


def lzh(out, encoding, names):
    with open(out, "wb") as archive:
        for name in names:
            raw, content = name.encode(encoding), name.encode()
            body = (b"-lh0-" + struct.pack("<IIIBBB", len(content), len(content), DOS_TIME, 0x20, 0, len(raw))
                    + raw + struct.pack("<H", crc16(content)))
            archive.write(bytes([len(body), sum(body) & 0xFF]) + body + content)
        archive.write(b"\0")


def rar4(out, encoding, names):
    def block(fields):
        return struct.pack("<H", zlib.crc32(fields) & 0xFFFF) + fields

    with open(out, "wb") as archive:
        archive.write(b"Rar!\x1a\x07\x00" + block(struct.pack("<BHHHI", 0x73, 0, 13, 0, 0)))
        for name in names:
            raw, content = name.encode(encoding), name.encode()
            archive.write(block(struct.pack(
                "<BHHIIBIIBBHI", 0x74, 0x8000, 32 + len(raw), len(content), len(content), 2,
                zlib.crc32(content), DOS_TIME, 20, 0x30, len(raw), 0x20) + raw) + content)
        archive.write(block(struct.pack("<BHH", 0x7B, 0x4000, 7)))


def cab(out, encoding, names):
    contents = [name.encode() for name in names]
    files, start = b"", 0
    for name, content in zip(names, contents):
        files += struct.pack("<IIHHHH", len(content), start, 0, DOS_TIME >> 16, DOS_TIME & 0xFFFF, 0x20)
        files += name.encode(encoding) + b"\0"
        start += len(content)
    data = b"".join(contents)
    first_block = 36 + 8 + len(files)
    blocks = struct.pack("<IHH", 0, len(data), len(data)) + data
    with open(out, "wb") as archive:
        archive.write(b"MSCF" + struct.pack(
            "<IIIIIBBHHHHH", 0, first_block + len(blocks), 0, 36 + 8, 0, 3, 1, 1, len(names), 0, 0, 0))
        archive.write(struct.pack("<IHH", first_block, 1, 0) + files + blocks)


def sit(out, encoding, items):
    """`name/` opens a folder and `<` closes it."""

    def header(fork_method, name, content=b""):
        fields = bytearray(112)
        fields[0:3] = bytes([fork_method, fork_method, len(name)])
        fields[3:3 + len(name)] = name
        struct.pack_into(">H", fields, 34, crc16(bytes([len(name)]) + name.ljust(31, b"\0")))
        fields[66:74] = b"TEXTttxt"
        struct.pack_into(">II", fields, 76, 0xDCC00000, 0xDCC00000)
        struct.pack_into(">I", fields, 88, len(content))
        struct.pack_into(">I", fields, 96, len(content))
        struct.pack_into(">H", fields, 102, crc16(content))
        struct.pack_into(">H", fields, 110, crc16(fields[:110]))
        return bytes(fields) + content

    entries = [
        header(33, b"") if item == "<"
        else header(32, item[:-1].encode(encoding)) if item.endswith("/")
        else header(0, item.encode(encoding), item.encode())
        for item in items]
    body = b"".join(entries)
    with open(out, "wb") as archive:
        archive.write(b"SIT!" + struct.pack(">HI", len(items), 22 + len(body)) + b"rLau" + b"\x01" + bytes(7) + body)


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
    add(archive, flagged("新建文档.txt"), b"UTF-8 name")

with zipfile.ZipFile("gbk_unflagged.zip", "w") as archive:
    add(archive, CodePageName("中文目录/你好世界.txt", "gbk"), b"GBK name")
    add(archive, CodePageName("新建文档.txt", "utf-8"), b"UTF-8 name, no flag")

with zipfile.ZipFile("gbk_flagged.zip", "w") as archive:
    add(archive, CodePageName("中文目录/你好世界.txt", "gbk"), b"GBK name")
    for name in ["Отчёт.txt", "Señor.txt", "Café.txt"]:
        add(archive, flagged(name), b"UTF-8 name")

with zipfile.ZipFile("cp866_lookalike.zip", "w") as archive:
    add(archive, CodePageName("Документы/Отчёт.txt", "cp866"), b"Not valid UTF-8")
    add(archive, CodePageName("сон.txt", "cp866"), b"Valid UTF-8 by accident")
    add(archive, CodePageName("сад/том.txt", "cp866"), b"Valid UTF-8 by accident, folder and all")
    add(archive, flagged("Café.txt"), b"UTF-8 name")

with zipfile.ZipFile("gbk_twins.zip", "w") as archive:
    add(archive, CodePageName("../中文.txt", "gbk"), b"from above")
    add(archive, CodePageName("./中文.txt", "gbk"), b"from here")
    add(archive, CodePageName("中文.txt", "gbk"), b"plain")

build("gbk_combining.zip", "gbk", [
    "工作/通知/会议.txt", "工作/通知/计划.txt", "工作/说明.txt",
    "中文目录/通知.txt", "中文目录/同学录.xls", "中文目录/你好世界.txt"])
build("gbk_escape_bytes.zip", "gbk", ["李静简历.doc", "杨静/报告.txt", "李经理的报告.xlsx", "羁绊.txt", "说明.txt"])
build("big5_escape_bytes.zip", "cp950", ["溫度控制器手冊.pdf", "說明.txt"])
build("big5_windows.zip", "cp950", ["恒生銀行/年度報告.txt", "宏碁/說明.txt"])
build("gbk_flip.zip", "gbk", ["文档/", "说明.txt", "图片/", "图片/风景.txt"])
build("gbk_cv.zip", "gbk", ["个人简历模板.doc"])
build("gbk_forms.zip", "gbk", ["简历模板.doc", "报名表.xls"])
build("cp866_symbols.zip", "cp866", ["Документы/Отчёт.txt", "Приказ №15.doc", "Новая папка/Договор.txt", "Письмо.txt", "Акт.doc", "Счёт.xls"])
build("cp850_symbols.zip", "cp850", ["Übersicht.txt", "§ 34 Änderung.pdf", "Müller.doc"])
build("dotdot_entry.zip", "ascii", ["sub/x.txt", "sub/y.txt", "sub/../"])
build("gbk_accident.zip", "gbk", ["图片.txt", "一些.txt"])
build("utf8_unflagged.zip", "utf-8", ["Größe.txt", "日本語.txt"])

with zipfile.ZipFile("gbk_unicode_path.zip", "w") as archive:
    add(archive, CodePageName("中文目录/你好世界.txt", "gbk"), b"GBK name")
    add(archive, CodePageName("新建文档.txt", "gbk"), b"GBK name")
    add(archive, unicode_path("Señor.txt", "cp850"), b"Named by its field")
    add(archive, unicode_path("Отчёт.txt", "cp866"), b"Named by its field")

with zipfile.ZipFile("gbk_flag_wrong.zip", "w") as archive:
    add(archive, WronglyFlaggedName("中文目录/", "gbk"))
    add(archive, WronglyFlaggedName("中文目录/你好世界.txt", "gbk"), b"Flagged, and not UTF-8")

inner = io.BytesIO()
build(inner, "gbk", ["中文目录/", "中文目录/你好世界.txt", "图片/风景.txt"])
with zipfile.ZipFile("nested_gbk.zip", "w") as archive:
    add(archive, CodePageName("Отчёт.txt", "cp1251"), b"Beside a zip in GBK")
    add(archive, CodePageName("inner.zip", "ascii"), inner.getvalue())

lzh("sjis_backslash.lzh", "cp932", ["データ\\表示.txt", "ソフト.txt", "能力表.txt", "予定\\申請書.txt"])
rar4("sjis_backslash.rar", "cp932", ["データ\\表示.txt", "ソフト.txt", "能力表.txt", "予定\\申請書.txt"])
cab("sjis_backslash.cab", "cp932", ["データ\\表示.txt", "ソフト.txt", "能力表.txt", "予定\\申請書.txt"])

sit("macroman.sit", "mac_roman", [
    "Bücher/", "Übersicht.txt", "Größe.txt", "<", "Prüfung.doc", "Résumé.doc", "Café.txt", "Señor.txt", "plain.txt"])
sit("macjapanese.sit", "cp932", ["データ/", "日本語のファイル.txt", "<", "説明書.txt", "写真.txt"])


def tar_entry(name):
    entry = tarfile.TarInfo(name.rstrip("/"))
    entry.mtime = 1793448000
    return entry


def tar_add(archive, name, encoding_of_content="utf-8"):
    entry = tar_entry(name)
    if name.endswith("/"):
        entry.type = tarfile.DIRTYPE
        entry.mode = 0o755
        archive.addfile(entry)
    else:
        content = name.encode(encoding_of_content, "surrogateescape")
        entry.size = len(content)
        entry.mode = 0o644
        archive.addfile(entry, io.BytesIO(content))


with tarfile.open("gbk.tar", "w", format=tarfile.GNU_FORMAT, encoding="gbk") as archive:
    for name in ["中文目录/", "中文目录/你好世界.txt", "图片/", "图片/风景.txt", "一些.txt"]:
        tar_add(archive, name)

with tarfile.open("gbk_accident.tar", "w", format=tarfile.GNU_FORMAT, encoding="gbk") as archive:
    for name in ["图片.txt", "一些.txt"]:
        tar_add(archive, name)

with tarfile.open("gbk_pax.tar", "w", format=tarfile.GNU_FORMAT, encoding="gbk") as archive:
    tar_add(archive, "中文目录/你好世界.txt")
    tar_add(archive, "新建文档.txt")
    archive.format, archive.encoding = tarfile.PAX_FORMAT, "utf-8"
    tar_add(archive, "Señor.txt")
    tar_add(archive, "Отчёт.txt")

with tarfile.open("utf8_stray_latin1.tar", "w", format=tarfile.GNU_FORMAT, encoding="utf-8", errors="surrogateescape") as archive:
    for name in ["Müller/", "Müller/Größe.txt", "Übersicht.txt", "Änderung.doc"]:
        tar_add(archive, name)
    tar_add(archive, "Müller.txt".encode("latin-1").decode("utf-8", "surrogateescape"))
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

mkdir -p "$BUILD/unicode/中文目录"
printf 'UTF-16 in the header.\n' > "$BUILD/unicode/中文目录/你好世界.txt"
printf 'UTF-16 in the header.\n' > "$BUILD/unicode/Größe.txt"
rm -f unicode.7z
(cd "$BUILD/unicode" && 7zz a -bso0 -bsp0 -mx=0 -mtm=off -mtc=off -mta=off -mtr=off -- unicode.7z 中文目录 Größe.txt)
mv "$BUILD/unicode/unicode.7z" unicode.7z

ls -l ./*.zip ./*.tar ./*.lzh ./*.rar ./*.cab ./*.sit ./*.7z
