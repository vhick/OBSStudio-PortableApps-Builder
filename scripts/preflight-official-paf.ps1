# Before downloading the large r5 OBS ZIP, verify that the *actual official*
# packager can compile a very small temporary PAF by CLI without manual input.
# This test PAF is NEVER published and NEVER executed or installed.
. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/official-paf-tool.ps1"
. "$PSScriptRoot/invoke-official-packager.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$tool=Get-OfficialPafTool
$root=Join-Path $project 'build/official-probe'
$app=Join-Path $root 'OBSPackagerProbePortable'
if(Test-Path $root) { Remove-Item -LiteralPath $root -Recurse -Force }
Ensure-Directory "$app/App/AppInfo"
Ensure-Directory "$app/App/Probe"
Ensure-Directory "$app/Data"
Ensure-Directory "$app/Other/Source"
# Build a tiny original Win32 test executable with Microsoft's installed MSVC.
# This prevents distributing (even transiently) copies of a Windows component.
$probeSrc=Join-Path $root 'probe.cpp'
@'
#include <windows.h>
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) { return 0; }
'@ | Set-Content -LiteralPath $probeSrc -Encoding ascii
$probeExe=Join-Path $app 'OBSPackagerProbePortable.exe'
$msvc=Get-Command cl.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if($msvc) {
  Push-Location $root
  try { & $msvc.Source /nologo /EHsc /O1 "/Fe:$probeExe" $probeSrc /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED }
  finally { Pop-Location }
} else {
  $vswhere='C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  Assert (Test-Path -LiteralPath $vswhere) 'MSVC tool locator is missing.'
  $vs=(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
  Assert (-not [string]::IsNullOrWhiteSpace($vs)) 'MSVC C++ tools not installed.'
  $vcvars=Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
  Assert (Test-Path -LiteralPath $vcvars) 'VC environment is unavailable.'
  $command='call "'+$vcvars+'" && cl /nologo /EHsc /O1 /Fe:"'+$probeExe+'" "'+$probeSrc+'" /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED'
  Push-Location $root
  try { & cmd.exe /d /s /c $command } finally { Pop-Location }
}
Assert ($LASTEXITCODE -eq 0) 'Small original Windows probe compilation failed'
Test-Pe $probeExe
'Self-test only. No user application installed.' | Set-Content -LiteralPath "$app/App/Probe/readme.txt" -Encoding ascii
$ini=@'
[Format]
Type=PortableApps.comFormat
Version=3.9

[Details]
Name=OBS Packager Probe Portable
AppID=OBSPackagerProbePortable
Publisher=Independent OBS builder self-test
Homepage=https://obsproject.com/
Category=Utilities
Description=Short-lived build process self-test; not distributed.
Language=English

[License]
Shareable=true
OpenSource=true
Freeware=true
CommercialUse=true

[Version]
PackageVersion=1.0.0.0
DisplayVersion=1.0

[Control]
Icons=1
Start=OBSPackagerProbePortable.exe
'@
$ini | Set-Content -LiteralPath "$app/App/AppInfo/appinfo.ini" -Encoding ascii
'<html><body><h1>Packager build probe</h1><p>Not distributed or installed.</p></body></html>' | Set-Content -LiteralPath "$app/help.html" -Encoding utf8
Add-Type -AssemblyName System.Drawing
$icon=[Drawing.SystemIcons]::Application
$f=[IO.File]::Create("$app/App/AppInfo/appicon.ico")
try { $icon.Save($f) } finally { $f.Dispose() }
foreach($size in @(16,32,75,128,256)) {
  $bmp=[Drawing.Bitmap]::new($size,$size)
  try {
    $g=[Drawing.Graphics]::FromImage($bmp)
    try { $g.DrawIcon($icon,[Drawing.Rectangle]::new(0,0,$size,$size)) } finally { $g.Dispose() }
    $bmp.Save("$app/App/AppInfo/appicon_$size.png",[Drawing.Imaging.ImageFormat]::Png)
  } finally { $bmp.Dispose() }
}
Write-Host 'Checking headless official package compilation using a small disposable fixture.'
$log=Join-Path $project 'build/official-installer/probe-log.txt'
try {
  Invoke-OfficialPackager -Exe $tool -Stage $app -Work $root -LogFile $log -MaxSeconds 120 -IdleSeconds 75
  $produced=@(Get-ChildItem -LiteralPath $root -Filter '*.paf.exe' -File -Recurse |
    Where-Object { $_.Name -like 'OBSPackagerProbePortable*' })
  Assert ($produced.Count -eq 1) "Official vendor CLI did not emit exactly one probe PAF (found $($produced.Count)); $log"
  $seven=Find-SevenZip
  Invoke-Bounded $seven @('t',$produced[0].FullName) $root 45 | Out-Null
  Write-Host 'OFFICIAL VENDOR PACKAGER CLI PREFLIGHT PASSED. No probe installer has been published.' -ForegroundColor Green
} finally {
  # Keep only the small log. Remove the temporary payload and probe PAF.
  if(Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
