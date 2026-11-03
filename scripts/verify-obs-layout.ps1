# Validates OBS Windows ZIP install structure without changing upstream files.
# OBS 33 moved bundled modules from obs-plugins to core; see OBS's official
# "Legacy Plugin Locations" documentation dated 2026-09-21.
. "$PSScriptRoot/common.ps1"

function Assert-ObsLayout {
  param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Version
  )
  Assert (Test-Path -LiteralPath (Join-Path $Root 'bin/64bit/obs64.exe') -PathType Leaf) 'Missing OBS bin/64bit/obs64.exe'
  Assert (Test-Path -LiteralPath (Join-Path $Root 'data/obs-studio') -PathType Container) 'Missing OBS application data directory'
  Assert ($Version -match '^(\d+)\.(\d+)\.(\d+)$') "Unrecognized stable OBS version: $Version"
  $major=[int]$Matches[1]
  if ($major -ge 33) {
    $relative='core'
    $message="OBS $Version requires the modern core module directory (OBS 33+), not the legacy obs-plugins directory."
  } else {
    $relative='obs-plugins'
    $message="OBS $Version requires the legacy obs-plugins module directory (OBS 32 and earlier)."
  }
  $modulesPath=Join-Path $Root $relative
  if (-not (Test-Path -LiteralPath $modulesPath -PathType Container)) {
    $topLevel=@(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | ForEach-Object Name) -join ', '
    throw "$message Available top-level directories: $topLevel"
  }
  $modules=@(Get-ChildItem -LiteralPath $modulesPath -Filter '*.dll' -Recurse -File -ErrorAction Stop)
  Assert ($modules.Count -gt 0) "OBS $Version has no plugin DLL files under '$relative'; the archive may be incomplete."
  Write-Host "Validated OBS $Version built-in modules: $relative ($($modules.Count) DLL files)."
}
