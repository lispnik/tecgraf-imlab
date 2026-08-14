[Setup]
AppName=ImLab
AppVersion=3.2
DefaultDirName={pf}\ImLab
DefaultGroupName=ImLab
UninstallDisplayIcon={app}\bin\imlab.exe
Uninstallable=yes
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=imlab-3.2_x64_setup
SourceDir=..
OutputDir=dist\files

[Dirs]
Name: "{app}";  

[Files]
Source: "bin\Win64\*"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "bin\*"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{app}\bin\imlab.exe"; Description: "Run ImLab"; Flags: postinstall nowait skipifsilent 

[Icons]
Name: "{group}\ImLab"; Filename: "{app}\bin\imlab.exe"
Name: "{group}\Remover ImLab"; Filename: "{uninstallexe}"
Name: "{commondesktop}\ImLab"; Filename: "{app}\bin\imlab.exe"
