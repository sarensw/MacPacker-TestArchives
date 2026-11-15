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
