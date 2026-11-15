cd /d C:\DDF
makecab /F spanned.ddf > C:\OUT\spanned.log 2>&1
C:\DL\inno\innosetup-5.6.1.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=C:\Inno
dir C:\Inno\ISCC.exe
cd /d C:\INNO_ISS
for %%f in (*.iss) do C:\Inno\ISCC.exe /Q %%f
C:\Inno\ISCC.exe 2>&1 | find "Inno Setup"
dir C:\OUT
