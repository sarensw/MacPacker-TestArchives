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
