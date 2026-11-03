param(
  [Parameter(Mandatory=$true)][string]$SourceReleaseTag,
  [Parameter(Mandatory=$true)][string]$Version
)
. "$PSScriptRoot/common.ps1"
Assert ($Version -match '^\d+\.\d+\.\d+$') 'Unsafe version.'
Assert ($SourceReleaseTag -ceq "portable-obs-v${Version}-r5") 'Source release tag does not match the version.'
Assert ($env:GITHUB_REPOSITORY -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'GITHUB_REPOSITORY missing or invalid.'
Assert (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) 'Missing GITHUB_TOKEN.'
$project=(Resolve-Path "$PSScriptRoot/..").Path
$download=Join-Path $project 'build/source-release'
$stageParent=Join-Path $project 'build/stage'
$stage=Join-Path $stageParent 'OBSStudioPortable'
Ensure-Directory $download
Ensure-Directory $stageParent
$name="OBSStudioPortable_${Version}_r5_win64.zip"
foreach($asset in @($name,'SHA256SUMS.txt')) {
  Write-Host "Downloading the EXISTING r5 release asset: $asset"
  & gh release download $SourceReleaseTag --repo $env:GITHUB_REPOSITORY --pattern $asset --dir $download --clobber
  if($LASTEXITCODE -ne 0) { throw "Failed to download source-release asset $asset (gh exit $LASTEXITCODE)." }
  Assert (Test-Path -LiteralPath (Join-Path $download $asset) -PathType Leaf) "GitHub download did not create $asset"
}
$zipPath=Join-Path $download $name
Assert ((Get-Item -LiteralPath $zipPath).Length -gt 10MB) 'The OBS package is implausibly small.'
$sumText=Get-Content -LiteralPath (Join-Path $download 'SHA256SUMS.txt')
$matchesForZip=@()
foreach($line in $sumText) {
  if($line -match '^\s*(?<hash>[a-fA-F0-9]{64})\s+\*?(?<file>[^\r\n]+?)\s*$') {
    if($Matches['file'] -ceq $name) { $matchesForZip += $Matches['hash'].ToLowerInvariant() }
  }
}
Assert ($matchesForZip.Count -eq 1) "Source release SHA256SUMS.txt must specify $name exactly once."
$actual=Get-Sha $zipPath
Assert ($actual -ceq $matchesForZip[0]) "Existing r5 ZIP SHA256 mismatch. Expected $($matchesForZip[0]), got $actual."
Write-Host "r5 ZIP SHA256 verified: $actual"
$seven=Find-SevenZip
Invoke-Bounded $seven @('t',$zipPath) $download 180 | Out-Null

# Validate every archive entry before extraction, including anti-traversal checks.
Add-Type -AssemblyName System.IO.Compression
$zip=[IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $entries=@($zip.Entries)
  Assert ($entries.Count -gt 100) 'Original release ZIP is unexpectedly empty.'
  foreach($entry in $entries) {
    $entryName=$entry.FullName.Replace('\','/')
    Assert ($entryName.StartsWith('OBSStudioPortable/',[StringComparison]::Ordinal)) "Unexpected ZIP root: $entryName"
    Assert (-not ($entryName -match '(^|/)\.\.(/|$)|(^|/)\.(/|$)|^[A-Za-z]:|//')) "Unsafe path in release ZIP: $entryName"
  }
} finally { $zip.Dispose() }
Assert (-not (Test-Path -LiteralPath $stage)) 'Stage already exists. Refusing to mix release packages.'
Expand-Archive -LiteralPath $zipPath -DestinationPath $stageParent
Assert (Test-Path -LiteralPath "$stage/OBSStudioPortable.exe") 'r5 ZIP lacks compiled launcher.'
Assert (Test-Path -LiteralPath "$stage/App/OBSStudio/bin/64bit/obs64.exe") 'r5 ZIP lacks OBS executable.'
Assert (Test-Path -LiteralPath "$stage/App/AppInfo/appinfo.ini") 'r5 ZIP lacks PortableApps metadata.'
Assert (Test-Path -LiteralPath "$stage/App/AppInfo/installer.ini") 'r5 ZIP lacks official-installer options.'
Assert (Test-Path -LiteralPath "$stage/Other/Source/BUILD-METADATA.json") 'r5 ZIP lacks provenance metadata.'
Test-Pe "$stage/OBSStudioPortable.exe"
Test-Pe "$stage/App/OBSStudio/bin/64bit/obs64.exe"
$manifest=Get-Content -Raw "$stage/Other/Source/BUILD-METADATA.json" | ConvertFrom-Json
Assert ($manifest.package_revision -ceq 'r5') 'This is not the existing r5 portable package.'
Assert ($manifest.upstream.version -ceq $Version) 'Upstream version in ZIP does not match source release tag.'
$ini=Get-Content -Raw "$stage/App/AppInfo/appinfo.ini"
Assert ($ini -match '(?m)^AppId=OBSStudioPortable\s*$') 'Unexpected AppID in source ZIP.'
Assert ($ini -match '(?m)^Start=OBSStudioPortable\.exe\s*$') 'Source ZIP does not use the compiled launcher.'
Assert ($ini -match "(?m)^PackageVersion=$([regex]::Escape($Version))\.1\s*$") 'Unexpected app package version.'
$installer=Get-Content -Raw "$stage/App/AppInfo/installer.ini"
Assert ($installer -match '(?m)^RemoveDataDirectory=false\s*$') 'Source installer configuration does not preserve Data.'
if(-not (Test-Path -LiteralPath "$stage/Data" -PathType Container)) {
  # Compress-Archive may omit an empty folder. Recreate ONLY the empty Data root.
  Ensure-Directory "$stage/Data"
}
Assert (@(Get-ChildItem -LiteralPath "$stage/Data" -Force -Recurse).Count -eq 0) 'Refusing to repackage personal OBS Data from ZIP.'
$manifest.upstream | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/build/release.json" -Encoding utf8
@{
  source_repo=$env:GITHUB_REPOSITORY
  source_release=$SourceReleaseTag
  source_asset=$name
  source_sha256=$actual
  source_version=$Version
  packaging_revision='r6'
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$project/build/paf-source.json" -Encoding utf8
Write-Host 'Validated r5 ZIP extracted into the original PortableApps stage. Data remains empty.' -ForegroundColor Green
