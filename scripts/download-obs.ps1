. "$PSScriptRoot/common.ps1"
$m=Get-Content -Raw -LiteralPath "$PSScriptRoot/../build/release.json" | ConvertFrom-Json
Assert ($m.archive_url -match '^https://github\.com/obsproject/obs-studio/releases/download/') 'Untrusted download location'
$zip=Join-Path $PSScriptRoot "../build/$($m.archive_name)"
if(Test-Path -LiteralPath $zip) {
  if((Get-Sha $zip) -ne $m.archive_sha256) { Remove-Item -LiteralPath $zip -Force }
}
if(-not (Test-Path -LiteralPath $zip)) { Save-VerifiedDownload $m.archive_url $zip $m.archive_sha256 }
$seven=Find-SevenZip
Invoke-Bounded $seven @('t',"$zip") "$PSScriptRoot/../build" 180 | Out-Null
$target=Join-Path $PSScriptRoot '../build/upstream'
if(Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force }
Ensure-Directory $target
Invoke-Bounded $seven @('x',"$zip","-o$target",'-y') $target 240 | Out-Null
$obs=@(Get-ChildItem $target -Filter obs64.exe -File -Recurse | Where-Object { $_.FullName -match '[\\/]bin[\\/]64bit[\\/]obs64\.exe$' })
Assert ($obs.Count -eq 1) "Upstream ZIP must contain exactly one bin\64bit\obs64.exe, found $($obs.Count)"
$root=$obs[0].Directory.Parent.Parent.FullName
Assert (Test-Path (Join-Path $root 'data/obs-studio')) 'Missing OBS application data directory'
Assert (Test-Path (Join-Path $root 'obs-plugins')) 'Missing OBS plugin directory'
Test-Pe $obs[0].FullName
@{ root=$root; executable=$obs[0].FullName } | ConvertTo-Json | Set-Content "$PSScriptRoot/../build/upstream.json" -Encoding utf8
Write-Host "Verified OBS binaries at $root"
