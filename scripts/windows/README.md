# Windows fixtures (2026-11-16)

Made in Bob HQ VMs. The batch files expect the standard content in `C:\C` (`bob copy <id> defaultArchiveContent 'C:\C'`)
and write to `C:\OUT`, `C:\ACE2`, `C:\W2`. Installers were downloaded on the host into `work/dl/<tool>/` and copied in;
the VMs have no network.

| Tool | Source, sha256 | VM | How it ran |
|---|---|---|---|
| WinRAR 2.71 (`Rar.exe`) | preinstalled in Bob HQ `win98` | win98 | `rar a -r [-s] [-m0/-m5 -md1024] [-ppassword] [-rr] [-m0 -v20k] [-sfx]` from `C:\C`; outputs `rar/rar2_*` |
| makecab 5.1.2600.5512 | part of Windows XP SP3 | winxp | `makecab.bat` with `makecab/*.ddf`; Quantum refused (`Invalid Compression Type: QUANTUM`) |
| Inno Setup 5.6.1 | https://files.jrsoftware.org/is/5/innosetup-5.6.1.exe, `96fd6a5e…` | winxp | `/VERYSILENT /DIR=C:\Inno`, then `ISCC /Q inno/*.iss` (`inno_setup.bat`) |
| WinZip 14.5 + Command Line Add-On 3.2 | https://download.winzip.com/winzip145.exe `eeb058d3…`, wzcline32.exe `a497defc…` | winxp | GUI installer hung in disk costing; installed `WINZIP145.MSI` with `msiexec /qn ROOTDRIVE=C:\ INSTALLDIR=C:\WinZip\`. Add-on installed through its dialog. `wzzip_zipx.bat`; every call shows an evaluation notice that waits for a key (answered with `bob key <id> enter`) |
| WinAce 2.69 | archive.org `winace_winace_2.65_anglais_9748/winace_winace_2.69.exe`, md5 `49fe093f…`, sha256 `426b19f2…` | winxp | installed through its dialog (shareware trial). CLI `winace a -r [-m0] [-ppassword] archive *.*` (`winace_baselines.bat`); ACE 1.0 / non-solid through registry values `Ace2`, `Solid` (`winace_ace10.bat`) |
| 7-Zip 19.00 | https://www.7-zip.org/a/7z1900.exe, `759aa04d…` | winxp | installed through its dialog to `C:\7`; `7z a -sfx7z.sfx` (`winrar602_7zip1900.bat`) |
| WinRAR 6.02 | https://www.rarlab.com/rar/wrar602.exe, `f3c32238…` | winxp | `wrar602.exe /S /DC:\WinRAR` (trial); `winrar602_7zip1900.bat` |
| StuffIt Standard 7.5 | archive.org `stuff-75-l/Stuff75L.exe`, md5 `90f3312b…`, sha256 `215abffc…` | winxp | installer pre-fills a serial: the field was emptied so it installed in 30-day demo mode. GUI: Options → Compression → StuffIt Archive (.sit), max; Archive → Add Files (`C:\C\hello world.txt`) and Add Folder (`C:\C\folder`); File → Save Archive As `defaultArchive.sit`; Archive → Password Protect (`password`), Save As `stuffit5_password.sit`; Archive → Make Self Extracting (`stuffit5_password.exe`) |

Not used: archive.org StuffIt 9 / Deluxe 2010 items (ship a serial or are pre-registered).

## Disc images (run 3, 2026-11-16, winxp)

Input: `defaultArchives/defaultArchive.iso` copied to `C:\ISO`.

| Tool | Source, sha256 | How it ran | Output |
|---|---|---|---|
| PowerISO 9.5 trial (`PowerISO7.exe` URL now serves 9.5; runs on XP) | https://www.poweriso.com/PowerISO7.exe `208c63f5…` | `/S`; `piso convert C:\ISO\defaultArchive.iso -o C:\OUT\defaultArchive.daa -ot daa -y`; `piso create -o C:\OUT\piso_files.daa -add "C:\C\hello world.txt" / -add C:\C\folder /folder -y` | defaultArchive.daa, daa/piso_files.daa |
| UltraISO Premium 9.x trial | https://www.ultraiso.com/uiso9_pe.exe `5564abf8…` | `/VERYSILENT`; `UltraISO.exe -in C:\ISO\defaultArchive.iso -out C:\OUT\defaultArchive.isz` (no window) | defaultArchive.isz |
| WinISO 6.4.1.5976 trial (limit: saves over 500 MB) | archive.org `winiso_202011/winiso.exe` md5 `a8589b41…`, sha256 `338c439a…` | `/S`; GUI Convert: source `C:\ISO\defaultArchive.iso`, formats Nero (.nrg), Alcohol 120% (.mds/.mdf), CloneCD (writes .img + .dvd, no .ccd), Cue sheets (.cue/.bin); "Later" on the registration dialog | defaultArchive.nrg, .mds/.mdf, .img/.dvd, .cue/.bin |

Not used: the archive.org DiscJuggler Pro 6 bundle (ships a replacement `pfc.dll`); CDI comes from cdi4dc instead
(`scripts/ubuntu_batch5.sh`). CloneCD's own `.ccd` is written by `scripts/ubuntu_batch5.sh` over the raw 2352-byte image.

## Windows 7 (2026-11-19, `win7` VM)

| Tool | Source, sha256 | How it ran | Output |
|---|---|---|---|
| diskpart / format (Windows 7 SP1) | built in | `create vdisk ... maximum=16 type=fixed`, `create partition primary`, `format fs=udf revision=2.50 quick`, xcopy; the partition (sector 128, 30592 sectors) cut out of the VHD on the host | udf/udf_rev0250_win7.udf |
| ALZip 8.51 trial (60 days, "Use Trial Version", no registration) | archive.org `alzip-851_202508/ALZip851.exe` md5 `3e9dc327…`, sha256 `72b076ea…` | `/S`; `ALZipCon.exe -a [-s] [-ppassword -tp0/1/2] C:\defaultArchiveContent C:\ALZ2\<name>.{alz,egg}` (a source list with spaces fails; spanning needs ≥ 64 KB volumes) | defaultArchive.alz/.egg, alz/, egg/ |
| Bandizip 6 (freeware, Bandisoft "old" build for Windows 7) | https://www.bandisoft.com/bandizip/dl.php?old `37d68f27…` | `/S`; `bc.exe x -y -p:password -o:<dir> <archive>`, certutil SHA256 | verification of ALZ/EGG |
| DAEMON Tools Lite 4.30.4 (free) | archive.org `daemon_tools_lite_4_30_4_0027` md5 `99102a9f…`, sha256 `12f5f431…` | installed (toolbar/search/start page unticked; needs one reboot for SPTD); `daemon.exe -mount 0,C:\ISO\defaultArchive.iso`; Disc imaging of its own drive fails, WinCDEmu's drive is not listed → no MDX | – |
| WinCDEmu 4.0 portable (LGPL) | https://github.com/sysprogs/WinCDEmu/releases/download/v4.1/PortableWinCDEmu-4.0.exe `c11fd7da…` | mounted the ISO as G: (to give DAEMON Tools a second drive) | – |

Not used: archive.org BlindWrite 6.2 (keygen serial in readme) and 7.0 (cracked BW.exe in a "Fix" folder).
