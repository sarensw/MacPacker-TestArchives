cd /d C:\C
md C:\ACE2
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r C:\ACE2\defaultArchive.ace *.*
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r -m0 C:\ACE2\ace20_store.ace *.*
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r -ppassword C:\ACE2\ace20_password.ace *.*
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r C:\ACE2\defaultArchive.lzh *.*
start /wait "" "C:\Program Files\WinAce\winace.exe" a -r C:\ACE2\defaultArchive.cab *.*
dir C:\ACE2
