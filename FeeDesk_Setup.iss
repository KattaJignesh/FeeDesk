
#define MyAppName "FeeDesk"
#define MyAppVersion "2.0.0"
#define MyAppExeName "pappa_project.exe"
#define ReleaseDir "E:\Desktop\pappa project\build\windows\x64\runner\Release"

[Setup]
AppId={{B8A4F7D2-6C31-4E95-A2B8-91D7C5F04316}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=FeeDesk
DefaultDirName={autopf}\FeeDesk
DefaultGroupName=FeeDesk
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=E:\Desktop\pappa project\installer
OutputBaseFilename=FeeDesk_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FeeDesk"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\FeeDesk"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch FeeDesk"; Flags: postinstall nowait skipifsilent
