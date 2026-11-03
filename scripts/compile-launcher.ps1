. "$PSScriptRoot/common.ps1"
$root=(Resolve-Path "$PSScriptRoot/..").Path
Ensure-Directory "$root/build"
$upstream=Get-Content -Raw "$root/build/upstream.json" | ConvertFrom-Json
# Use the real OBS Project icon embedded in the official OBS binary, not a replacement artwork.
Add-Type -AssemblyName System.Drawing
$icon=[System.Drawing.Icon]::ExtractAssociatedIcon($upstream.executable)
Assert ($null -ne $icon) 'Upstream OBS executable did not expose an icon'
$iconPath="$root/build/obs-upstream-icon.ico"
try {
  $stream=[IO.File]::Create($iconPath)
  try { $icon.Save($stream) } finally { $stream.Dispose() }
} finally { $icon.Dispose() }
$resource="$root/build/launcher-icon.rc"
$escaped=$iconPath.Replace('\','/')
'MAINICON ICON "'+$escaped+'"' | Set-Content -LiteralPath $resource -Encoding ascii
$msvc=Get-Command cl.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if(-not $msvc) {
  $vswhere='C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  Assert (Test-Path $vswhere) 'VS tools not found (vswhere)'
  $vs=(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
  Assert ([bool]$vs) 'Microsoft C++ build tools not installed'
  $vcvars=Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
  Assert (Test-Path $vcvars) 'Missing vcvars64.bat'
  $command='call "'+$vcvars+'" && rc /nologo /fo"'+$root+'\build\launcher-icon.res" "'+$resource+'" && cl /nologo /std:c++17 /EHsc /W4 /O2 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /Fe:"'+$root+'\build\OBSStudioPortable.exe" "'+$root+'\launcher\OBSStudioPortable.cpp" "'+$root+'\build\launcher-icon.res" /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED User32.lib Shell32.lib'
  & cmd.exe /d /s /c $command
} else {
  & rc.exe /nologo "/fo$root/build/launcher-icon.res" $resource
  Assert ($LASTEXITCODE -eq 0) 'Windows resource compiler failed'
  & $msvc.Source /nologo /std:c++17 /EHsc /W4 /O2 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN "/Fe:$root/build/OBSStudioPortable.exe" "$root/launcher/OBSStudioPortable.cpp" "$root/build/launcher-icon.res" /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED User32.lib Shell32.lib
}
Assert ($LASTEXITCODE -eq 0) "Native launcher compilation failed: $LASTEXITCODE"
Test-Pe "$root/build/OBSStudioPortable.exe"
Write-Host 'Compiled genuine OBSStudioPortable.exe with upstream OBS icon' -ForegroundColor Green
