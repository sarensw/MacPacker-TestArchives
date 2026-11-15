[Setup]
AppName=defaultArchive
AppVersion=1.0
AppPublisher=MacPacker Test Archives
DefaultDirName={pf}\defaultArchive
DisableProgramGroupPage=yes
OutputDir=C:\OUT
OutputBaseFilename=inno_lzma_solid
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest

[Files]
Source: "C:\C\hello world.txt"; DestDir: "{app}"
Source: "C:\C\folder\README.md"; DestDir: "{app}\folder"
Source: "C:\C\folder\NestedArchive.zip"; DestDir: "{app}\folder"
