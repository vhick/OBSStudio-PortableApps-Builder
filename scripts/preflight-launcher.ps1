. "$PSScriptRoot/common.ps1"
$root = (Resolve-Path "$PSScriptRoot/..").Path
$source = Join-Path $root 'launcher/OBSStudioPortable.cpp'
Assert (Test-Path -LiteralPath $source) 'Missing native launcher source'
# A syntax/type check before downloading OBS: catches missing Windows SDK types
# with only the installed Microsoft C++ tools. /Zs does not link an executable.
$msvc = Get-Command cl.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($msvc) {
  & $msvc.Source /nologo /Zs /std:c++17 /EHsc /W4 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN "$source"
} else {
  $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
  Assert (Test-Path -LiteralPath $vswhere) 'VS tools not found (vswhere)'
  $vs = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
  Assert ([bool]$vs) 'Microsoft C++ build tools not installed'
  $vcvars = Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
  Assert (Test-Path -LiteralPath $vcvars) 'Missing vcvars64.bat'
  $command = 'call "' + $vcvars + '" && cl /nologo /Zs /std:c++17 /EHsc /W4 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN "' + $source + '"'
  & cmd.exe /d /s /c $command
}
Assert ($LASTEXITCODE -eq 0) "Launcher source preflight failed: MSVC exit code $LASTEXITCODE"
Write-Host 'Native launcher passed MSVC source syntax/type checking before OBS download.' -ForegroundColor Green
