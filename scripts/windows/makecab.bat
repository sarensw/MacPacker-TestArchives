md C:\OUT
cd /d C:\DDF
for %%f in (*.ddf) do makecab /F %%f > C:\OUT\%%~nf.log 2>&1
dir C:\OUT
type C:\OUT\quantum.log
