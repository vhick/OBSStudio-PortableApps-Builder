. "$PSScriptRoot/common.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$m=Get-Content -Raw "$project/build/release.json" | ConvertFrom-Json
$stage="$project/build/stage/OBSStudioPortable"
$ini=Get-Content -Raw "$stage/App/AppInfo/appinfo.ini"
$installer=Get-Content -Raw "$stage/App/AppInfo/installer.ini"
Assert ($ini -match 'Start=OBSStudioPortable.exe') 'Wrong PortableApps Menu launcher'
Assert ($ini -match 'AppId=OBSStudioPortable') 'Wrong AppID'
Assert ($ini -match "PackageVersion=$([regex]::Escape($m.version))\.1") 'Wrong package version'
Assert ($installer -notmatch '(?mi)^RemoveDataDirectory\s*=') 'Legacy installer Data flag must be omitted; Format 3.9 preserves Data by default'
foreach($size in @(16,32,75,128,256)) { Assert (Test-Path "$stage/App/AppInfo/appicon_$size.png") "Missing Format 3.9 icon $size" }
Test-Pe "$stage/OBSStudioPortable.exe"
Test-Pe "$stage/App/OBSStudio/bin/64bit/obs64.exe"
foreach($icon in @('appicon.ico','appicon_16.png','appicon_32.png')) {
  Assert (Test-Path "$stage/App/AppInfo/$icon") "Missing $icon"
}
$zips=@(Get-ChildItem -Path "$project/output" -Filter '*.zip' -File)
Assert ($zips.Count -eq 1) "Expected one finished ZIP, found $($zips.Count)"
$seven=Find-SevenZip
Invoke-Bounded $seven @('t',$zips[0].FullName) $project 150 | Out-Null
$pafs=@(Get-ChildItem -Path "$project/output" -Filter '*.paf.exe' -File)
Assert ($pafs.Count -le 1) 'Multiple PAF candidates not allowed'
if($pafs.Count -eq 1) {
  Assert (Test-Path "$project/build/paf-provenance.json") 'PAF is missing official-tool provenance'
  $prov=Get-Content -Raw "$project/build/paf-provenance.json" | ConvertFrom-Json
  Assert ($prov.engine -eq 'original-unmodified-PortableApps.comInstaller') 'Not produced by authentic official tool'
  Assert ($prov.package_sha256 -eq (Get-Sha $pafs[0].FullName)) 'PAF digest mismatch'
  Test-Pe $pafs[0].FullName
  Invoke-Bounded $seven @('t',$pafs[0].FullName) $project 150 | Out-Null
}
$checksumLines=@(Get-ChildItem "$project/output" -File | Where-Object { $_.Name -match '(\.zip|\.paf\.exe)$' } | ForEach-Object { "$(Get-Sha $_.FullName)  $($_.Name)" })
$checksumLines | Set-Content "$project/build/SHA256SUMS.txt" -Encoding ascii
$checksumLines | ForEach-Object { Write-Host $_ }
Assert ($checksumLines.Count -ge 1) 'There are no validated finished packages'
Write-Host 'All available package integrity checks succeeded.' -ForegroundColor Green
