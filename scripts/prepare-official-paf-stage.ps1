# Apply PortableApps.com Format 3.9 *packaging metadata* corrections to the
# COPY of the existing r5 ZIP, never to its source GitHub release or binaries.
# App and launcher hashes must not change. No Data is populated or overwritten.
. "$PSScriptRoot/common.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$stage=Join-Path $project 'build/stage/OBSStudioPortable'
Assert (Test-Path -LiteralPath "$stage/OBSStudioPortable.exe") 'Missing existing compiled launcher'
Assert (Test-Path -LiteralPath "$stage/App/OBSStudio/bin/64bit/obs64.exe") 'Missing upstream OBS executable'
$beforeLauncher=Get-Sha "$stage/OBSStudioPortable.exe"
$beforeObs=Get-Sha "$stage/App/OBSStudio/bin/64bit/obs64.exe"
Assert (@(Get-ChildItem -LiteralPath "$stage/Data" -Force -Recurse).Count -eq 0) 'PAF staging Data must be empty'
$info=Join-Path $stage 'App/AppInfo'
Assert (Test-Path -LiteralPath "$info/appinfo.ini") 'Missing appinfo.ini'
Assert (Test-Path -LiteralPath "$info/installer.ini") 'Missing installer.ini'
Assert (Test-Path -LiteralPath "$info/appicon_128.png") 'Missing genuine upstream OBS icon'
# Format 3.9 calls for 16/32/75/128/256 PNG variants. The original r5 ZIP
# included 16/32/48/128, so derive the missing variants from upstream icon.
Add-Type -AssemblyName System.Drawing
foreach($size in @(75,256)) {
  $dst=Join-Path $info "appicon_$size.png"
  if(-not (Test-Path -LiteralPath $dst)) {
    $source=[Drawing.Image]::FromFile("$info/appicon_128.png")
    try {
      $bmp=[Drawing.Bitmap]::new($size,$size)
      try {
        $gfx=[Drawing.Graphics]::FromImage($bmp)
        try {
          $gfx.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
          $gfx.DrawImage($source,[Drawing.Rectangle]::new(0,0,$size,$size))
        } finally { $gfx.Dispose() }
        $bmp.Save($dst,[Drawing.Imaging.ImageFormat]::Png)
      } finally { $bmp.Dispose() }
    } finally { $source.Dispose() }
  }
}
$help=Join-Path $stage 'help.html'
if(-not (Test-Path -LiteralPath $help)) {
  @'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>OBS Studio Portable</title></head>
<body><h1>OBS Studio Portable — Independent Builder</h1>
<p>Launch OBSStudioPortable.exe in this directory.</p>
<p>Profiles, scenes, settings, and application-owned recovered files are kept
under Data. Back up Data before any upgrade.</p>
<p>External media, recordings, scripts, and third-party plugins may still use
paths outside this portable folder; check them manually when moving drives.</p>
<p>This is an independent package, not certified by OBS Project or PortableApps.com.</p>
</body></html>
'@ | Set-Content -LiteralPath $help -Encoding utf8
}
# Per Format 3.9 the Installer preserves Data by default. Remove the obsolete
# RemoveDataDirectory key while keeping only recognized directory defaults.
$installer=Get-Content -LiteralPath "$info/installer.ini"
$newInstaller=@($installer | Where-Object { $_ -notmatch '^\s*RemoveDataDirectory\s*=' })
$newInstaller | Set-Content -LiteralPath "$info/installer.ini" -Encoding ascii
$afterInstaller=Get-Content -Raw -LiteralPath "$info/installer.ini"
Assert ($afterInstaller -match '(?m)^RemoveAppDirectory=true\s*$') 'Missing App replace behavior'
Assert ($afterInstaller -notmatch '(?mi)^RemoveDataDirectory\s*=') 'Unsupported legacy Data removal setting remained'
foreach($size in @(16,32,75,128,256)) {
  Assert (Test-Path -LiteralPath "$info/appicon_$size.png") "Missing PortableApps Format 3.9 icon size: $size"
}
Assert ((Get-Sha "$stage/OBSStudioPortable.exe") -ceq $beforeLauncher) 'Launcher changed while preparing installer metadata'
Assert ((Get-Sha "$stage/App/OBSStudio/bin/64bit/obs64.exe") -ceq $beforeObs) 'OBS executable changed while preparing installer metadata'
Assert (@(Get-ChildItem -LiteralPath "$stage/Data" -Force -Recurse).Count -eq 0) 'Data changed during metadata repair'
Write-Host 'PAF-only metadata repaired: icon sizes 75/256, help.html, obsolete Data switch removed; binaries and Data untouched.' -ForegroundColor Green
