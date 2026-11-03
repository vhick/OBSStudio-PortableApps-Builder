. "$PSScriptRoot/common.ps1"
$root = (Resolve-Path "$PSScriptRoot/..").Path
$source = Join-Path $root 'launcher/OBSStudioPortable.cpp'
Assert (Test-Path -LiteralPath $source) 'Missing native launcher source'

# Compile AND LINK this launcher's source BEFORE downloading the large OBS ZIP.
# MSVC /Zs only checks syntax, so it cannot detect unresolved Windows API imports.
# The final build later adds the authentic upstream OBS icon as a resource.
$preflightDir = Join-Path $root 'build/preflight'
Ensure-Directory $preflightDir
$preflightExe = Join-Path $preflightDir 'OBSStudioPortable-linkcheck.exe'
if (Test-Path -LiteralPath $preflightExe) { Remove-Item -LiteralPath $preflightExe -Force }
$msvc = Get-Command cl.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($msvc) {
  Push-Location $preflightDir
  try {
    & $msvc.Source /nologo /std:c++17 /EHsc /W4 /O2 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN "/Fe:$preflightExe" "$source" /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED User32.lib Shell32.lib
  } finally { Pop-Location }
} else {
  $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  Assert (Test-Path -LiteralPath $vswhere) 'VS tools not found (vswhere)'
  $vs = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
  Assert ([bool]$vs) 'Microsoft C++ build tools not installed'
  $vcvars = Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
  Assert (Test-Path -LiteralPath $vcvars) 'Missing vcvars64.bat'
  $command = 'call "' + $vcvars + '" && cl /nologo /std:c++17 /EHsc /W4 /O2 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /Fe:"' + $preflightExe + '" "' + $source + '" /link /SUBSYSTEM:WINDOWS /MANIFEST:EMBED User32.lib Shell32.lib'
  Push-Location $preflightDir
  try { & cmd.exe /d /s /c $command } finally { Pop-Location }
}
Assert ($LASTEXITCODE -eq 0) "Launcher early compile+link preflight failed: MSVC exit code $LASTEXITCODE"
Test-Pe $preflightExe
Write-Host 'Native launcher successfully compiled and linked as a valid PE before OBS download.' -ForegroundColor Green
