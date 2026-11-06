#define MyAppName "FeeDesk"
#define MyAppVersion "1.0.0"

[Setup]
AppId={{D7A2B8C1-42F6-4A91-9E32-8B5C61F20A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=FeeDesk
DefaultDirName={autopf}\FeeDesk
DefaultGroupName=FeeDesk
UninstallDisplayIcon={app}\FeeDesk.exe
OutputDir=installer
OutputBaseFilename=FeeDesk_Setup
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "build\windows\x64\runner\Release\pappa_project.exe"; DestDir: "{app}"; DestName: "FeeDesk.exe"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Excludes: "pappa_project.exe"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\FeeDesk"; Filename: "{app}\FeeDesk.exe"
Name: "{autodesktop}\FeeDesk"; Filename: "{app}\FeeDesk.exe"

[Run]
Filename: "{app}\FeeDesk.exe"; Description: "Launch FeeDesk"; Flags: postinstall nowait skipifsilent