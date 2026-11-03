. "$PSScriptRoot/common.ps1"
$m=Get-Content -Raw "$PSScriptRoot/../build/release.json" | ConvertFrom-Json
$project=(Resolve-Path "$PSScriptRoot/..").Path
$stage=Join-Path $project 'build/stage'
$out=Join-Path $project 'output'
Ensure-Directory $out
$allStagedData=@(Get-ChildItem -LiteralPath "$stage/OBSStudioPortable/Data" -Recurse -Force -ErrorAction Stop)
Assert ($allStagedData.Count -eq 0) 'CRITICAL: release staging contains runtime test data; refusing to package a user profile'
$name="OBSStudioPortable_$($m.version)_r4_win64.zip"
$dest=Join-Path $out $name
if(Test-Path $dest) { Remove-Item $dest -Force }
# The staging parent is archived: ZIP contains OBSStudioPortable/ at root.
Compress-Archive -Path "$stage/OBSStudioPortable" -DestinationPath $dest -CompressionLevel Optimal
$zip=[IO.Compression.ZipFile]::OpenRead($dest)
try {
  $names=@($zip.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
  foreach($required in @('OBSStudioPortable/OBSStudioPortable.exe',
    'OBSStudioPortable/App/AppInfo/appinfo.ini',
    'OBSStudioPortable/App/OBSStudio/bin/64bit/obs64.exe')) {
    Assert ($names -ccontains $required) "ZIP missing $required"
  }
} finally { $zip.Dispose() }
Write-Host "ZIP: $dest" -ForegroundColor Green
Write-Host "SHA256: $(Get-Sha $dest)"
