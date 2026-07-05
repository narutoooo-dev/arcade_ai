; Inno Setup script — builds a real Windows installer (wizard, Program Files,
; Start menu shortcut, uninstaller). Compiled by CI on a windows runner:
;   ISCC.exe windows\installer.iss   (APP_VERSION env var must be set)

#define MyAppName "Arcade AI"
#define MyAppVersion GetEnv("APP_VERSION")
#define MyAppPublisher "NickIBrody"
#define MyAppURL "https://github.com/NickIBrody/arcade_ai"
#define MyAppExeName "arcade_ai.exe"

[Setup]
AppId={{8F2A61D4-9C3B-4E5F-A7D2-1B6C93E40A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf64}\Arcade AI
DefaultGroupName=Arcade AI
DisableProgramGroupPage=yes
OutputBaseFilename=ArcadeAI-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=runner\resources\app_icon.ico
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
