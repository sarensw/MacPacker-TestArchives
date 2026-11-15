cd /d C:\C
md C:\W2
C:\7\7z.exe a -bd -sfx7z.sfx C:\W2\defaultArchive.exe "hello world.txt" folder > nul
C:\WinRAR\Rar.exe a -r -idq -ma5 C:\W2\defaultArchive.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma5 -s C:\W2\rar5_solid.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma5 -m0 C:\W2\rar5_store.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma5 -rr5%% C:\W2\rar5_recovery.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma5 -m0 -v20k C:\W2\rar5_volumes.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma5 -sfx C:\W2\rar5_sfx.exe *.*
C:\WinRAR\Rar.exe a -r -idq -ma4 C:\W2\rar4_default.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma4 -s C:\W2\rar4_solid.rar *.*
C:\WinRAR\Rar.exe a -r -idq -ma4 -m0 -v20k -vn C:\W2\rar4_volumes.rar *.*
C:\7\7z.exe i | find "7-Zip"
dir C:\W2
