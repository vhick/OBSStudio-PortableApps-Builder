param([Parameter(Mandatory=$true)][string]$Version)
. "$PSScriptRoot/common.ps1"
Assert ($Version -match '^\d+\.\d+\.\d+$') 'Unsafe version'
$project=(Resolve-Path "$PSScriptRoot/..").Path
$paf=Join-Path $project "output/OBSStudioPortable_${Version}_r7_win64.paf.exe"
Assert (Test-Path -LiteralPath $paf -PathType Leaf) 'Official r7 PAF was not produced'
Test-Pe $paf
$prov=Get-Content -Raw -LiteralPath "$project/build/paf-provenance.json" | ConvertFrom-Json
Assert ($prov.engine -ceq 'original-unmodified-PortableApps.comInstaller') 'Not produced by genuine official tool'
Assert ($prov.engine_sha256 -ceq '689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67') 'Unverified official packager digest'
Assert ($prov.package_sha256 -ceq (Get-Sha $paf)) 'Official PAF digest mismatch'
Assert ($prov.result -ceq 'archive-extracted-and-key-binaries-sha256-compared') 'PAF payload comparison missing'
$stagedInfo=Get-Content -Raw -LiteralPath "$project/build/stage/OBSStudioPortable/App/AppInfo/installer.ini"
Assert ($stagedInfo -notmatch '(?mi)^RemoveDataDirectory\s*=') 'Obsolete Data removal setting reintroduced'
Assert ((Get-Content -Raw "$project/build/paf-source.json" | ConvertFrom-Json).source_version -ceq $Version) 'Source version mismatch'
$seven=Find-SevenZip
Invoke-Bounded $seven @('t',$paf) $project 180 | Out-Null
$files=@(Get-ChildItem -Path "$project/output" -File)
Assert ($files.Count -eq 1 -and $files[0].Name -ceq "OBSStudioPortable_${Version}_r7_win64.paf.exe") 'PAF-only workflow must not publish any ZIP or unrelated files'
Write-Host "Validated official PAF ($Version) SHA256: $(Get-Sha $paf)" -ForegroundColor Green
