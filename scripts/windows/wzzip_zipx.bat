cd /d C:\C
C:\WinZip\wzzip.exe -a -r -p -ez C:\OUT\zipx_best.zipx *.* > C:\OUT\wz1.txt 2>&1
C:\WinZip\wzzip.exe -a -r -p -eL C:\OUT\zipx_lzma.zipx *.* >> C:\OUT\wz1.txt 2>&1
C:\WinZip\wzzip.exe -a -r -p -ep C:\OUT\zipx_ppmd.zipx *.* >> C:\OUT\wz1.txt 2>&1
C:\WinZip\wzzip.exe -a -r -p -eb C:\OUT\zipx_bzip2.zipx *.* >> C:\OUT\wz1.txt 2>&1
C:\WinZip\wzzip.exe -a -r -p -ee C:\OUT\zipx_enhanced_deflate.zipx *.* >> C:\OUT\wz1.txt 2>&1
C:\WinZip\wzzip.exe -a -r -p -ez -spassword -ycAES256 C:\OUT\zipx_aes256.zipx *.* >> C:\OUT\wz1.txt 2>&1
type C:\OUT\wz1.txt
dir C:\OUT\*.zipx
