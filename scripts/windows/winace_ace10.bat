cd /d C:\C
reg add HKCU\Software\e-merge\WinAce\2.0 /v Ace2 /t REG_DWORD /d 0 /f
reg add HKCU\Software\e-merge\WinAce\2.0 /v Solid /t REG_DWORD /d 0 /f
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r C:\ACE2\ace10_nonsolid.ace *.*
reg add HKCU\Software\e-merge\WinAce\2.0 /v Solid /t REG_DWORD /d 1 /f
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r C:\ACE2\ace10_solid.ace *.*
reg add HKCU\Software\e-merge\WinAce\2.0 /v Ace2 /t REG_DWORD /d 1 /f
reg add HKCU\Software\e-merge\WinAce\2.0 /v Solid /t REG_DWORD /d 0 /f
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r C:\ACE2\ace20_nonsolid.ace *.*
reg add HKCU\Software\e-merge\WinAce\2.0 /v Solid /t REG_DWORD /d 1 /f
dir C:\ACE2
