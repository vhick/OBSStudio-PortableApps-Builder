. "$PSScriptRoot/common.ps1"
$m=Get-Content -Raw "$PSScriptRoot/../build/release.json" | ConvertFrom-Json
$paths=Get-Content -Raw "$PSScriptRoot/../build/upstream.json" | ConvertFrom-Json
$project=(Resolve-Path "$PSScriptRoot/..").Path
$stage=Join-Path $project 'build/stage/OBSStudioPortable'
if(Test-Path $stage) { Remove-Item $stage -Force -Recurse }
Ensure-Directory $stage
foreach($rel in @('App/OBSStudio','App/AppInfo/Launcher','App/DefaultData','Data','Other/Source')) {
  Ensure-Directory (Join-Path $stage $rel)
}
# OBS officially distributes a working Windows ZIP; reuse its verified binaries unchanged.
# The actual upstream source is never replaced by the FreeCrawl reference implementation.
Get-ChildItem -LiteralPath $paths.root -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination "$stage/App/OBSStudio" -Recurse -Force
}
Assert (Test-Path "$stage/App/OBSStudio/bin/64bit/obs64.exe") 'OBS staging failed'
Test-Pe "$stage/App/OBSStudio/bin/64bit/obs64.exe"
Copy-Item "$project/build/OBSStudioPortable.exe" "$stage/OBSStudioPortable.exe" -Force
Test-Pe "$stage/OBSStudioPortable.exe"
Copy-Item "$project/launcher/OBSStudioPortable.cpp" "$stage/Other/Source/OBSStudioPortable.cpp" -Force
Copy-Item "$project/docs/SOURCE-AUDIT.md" "$stage/Other/Source/SOURCE-AUDIT.md" -Force
Copy-Item "$project/docs/LAUNCHER-LICENSE.txt" "$stage/Other/Source/LAUNCHER-LICENSE.txt" -Force
$upstreamLicense="$($paths.root)/LICENSE"
if(Test-Path $upstreamLicense) { Copy-Item $upstreamLicense "$stage/Other/Source/OBS-LICENSE.txt" }
else {
  $licenseUri="https://raw.githubusercontent.com/obsproject/obs-studio/$($m.version)/COPYING"
  Invoke-WebRequest -Uri $licenseUri -TimeoutSec 35 -OutFile "$stage/Other/Source/OBS-LICENSE.txt"
}
Assert (Test-Path "$stage/Other/Source/OBS-LICENSE.txt") 'OBS GPL license is missing from package'
Assert ((Get-Content "$stage/Other/Source/OBS-LICENSE.txt" -TotalCount 1) -match 'GNU GENERAL PUBLIC LICENSE') 'Unexpected upstream license text' 
$ini=@"
[Format]
Type=PortableApps.comFormat
Version=3.9

[Details]
Name=OBS Studio Portable (Independent Build)
AppId=OBSStudioPortable
Publisher=OBS Project
Homepage=https://obsproject.com/
Category=Music & Video
Description=OBS Studio recording and streaming software packaged with an independent portable launcher.
Language=Multilingual
Trademarks=OBS Studio and OBS Project names and icons belong to their owners.

[License]
Shareable=true
OpenSource=true
Freeware=true
CommercialUse=true

[Version]
PackageVersion=$($m.version).1
DisplayVersion=$($m.version) Portable Builder r5

[Control]
Icons=1
Start=OBSStudioPortable.exe
"@
Set-Content -LiteralPath "$stage/App/AppInfo/appinfo.ini" -Value $ini -Encoding ascii
$installer=@'
[CheckRunning]
CloseEXE=obs64.exe
CloseName=OBS Studio

[MainDirectories]
RemoveAppDirectory=true
RemoveDataDirectory=false
RemoveOtherDirectory=true

[Source]
IncludeInstallerSource=false
'@
Set-Content -LiteralPath "$stage/App/AppInfo/installer.ini" -Value $installer -Encoding ascii
# This INI is supplied for traceability. The native C++ launcher is the active launcher.
$launcherIni=@'
[Launch]
ProgramExecutable=OBSStudio\bin\64bit\obs64.exe
AdditionalParameters=--portable --disable-updater
WorkingDirectory=%PAL:AppDir%\OBSStudio\bin\64bit
'@
Set-Content -LiteralPath "$stage/App/AppInfo/Launcher/OBSStudioPortable.ini" -Value $launcherIni -Encoding ascii
$info=@'
OBS Studio Portable (independent builder)

Launch OBSStudioPortable.exe in this folder. OBS --portable directs the normal OBS
settings tree to Data\OBSConfig. On NTFS the launcher makes a local directory
junction from App\OBSStudio\config to Data\OBSConfig (no admin required).
On unsupported filesystems it uses verified copies with crash recovery.

DO NOT install into Program Files. Make a backup of Data before updating.
Scene references to external recordings and other media are not rewritten.

This is not an officially endorsed OBS Project or PortableApps.com release.
'@
Set-Content -LiteralPath "$stage/help.txt" -Value $info -Encoding utf8
# Extract the genuine OBS icon from upstream signed/released executable.
Add-Type -AssemblyName System.Drawing
$obsExe=(Resolve-Path "$stage/App/OBSStudio/bin/64bit/obs64.exe").Path
$icon=[System.Drawing.Icon]::ExtractAssociatedIcon($obsExe)
Assert ($null -ne $icon) 'Cannot read official upstream OBS executable icon'
try {
  $ico=[IO.File]::Create("$stage/App/AppInfo/appicon.ico")
  try { $icon.Save($ico) } finally { $ico.Dispose() }
  foreach($size in @(16,32,48,128)) {
    $bmp=New-Object System.Drawing.Bitmap($size,$size)
    try {
      $graphics=[System.Drawing.Graphics]::FromImage($bmp)
      try {
        $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawIcon($icon,(New-Object System.Drawing.Rectangle(0,0,$size,$size)))
      } finally { $graphics.Dispose() }
      $bmp.Save("$stage/App/AppInfo/appicon_$size.png",[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $bmp.Dispose() }
  }
} finally { $icon.Dispose() }
# No Data defaults are seeded into existing installations.
$metadata=[ordered]@{upstream=$m;launcher='Compiled OBSStudioPortable.exe';portable_storage='Data/OBSConfig';package_revision='r5'}
$metadata | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$stage/Other/Source/BUILD-METADATA.json" -Encoding utf8
Write-Host "Staged OBS $($m.version) at $stage"
