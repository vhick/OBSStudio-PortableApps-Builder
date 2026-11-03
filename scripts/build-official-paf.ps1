param([switch]$RequirePaf)
. "$PSScriptRoot/common.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$m=Get-Content -Raw "$project/build/release.json" | ConvertFrom-Json
$stage=(Resolve-Path "$project/build/stage/OBSStudioPortable").Path
$out=Join-Path $project 'output'
Ensure-Directory $out
# Pinned original PortableApps.com Installer binary. SourceForge publishes this SHA-256.
$version='3.9.22'
$expected='689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67'
$url='https://downloads.sourceforge.net/project/portableapps/PortableApps.com%20Installer/PortableApps.comInstaller_3.9.22.paf.exe'
$work=Join-Path $project 'build/official-installer'
Ensure-Directory $work
$source=Join-Path $work 'PortableApps.comInstaller_3.9.22.paf.exe'
$extract=Join-Path $work 'unpacked'
try {
  if(-not (Test-Path $source) -or (Get-Sha $source) -ne $expected) {
      Save-VerifiedDownload $url $source $expected
  }
  Test-Pe $source
  $seven=Find-SevenZip
  Invoke-Bounded $seven @('t',"$source") $work 90 | Out-Null
  if(Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
  Ensure-Directory $extract
  Invoke-Bounded $seven @('x',"$source","-o$extract",'-y') $extract 90 | Out-Null
  $tools=@(Get-ChildItem -LiteralPath $extract -File -Recurse | Where-Object { $_.Name -ieq 'PortableApps.comInstaller.exe' })
  Assert ($tools.Count -eq 1) "Expected one official installer build tool in verified vendor PAF, found $($tools.Count)"
  Test-Pe $tools[0].FullName
  $begun=Get-Date
  $log=Invoke-Bounded $tools[0].FullName @($stage) $work 220
  $log | Set-Content "$work/official-run.log" -Encoding utf8
  $candidateFolders=@((Split-Path -Parent $stage),$work,(Split-Path -Parent $tools[0].FullName),$out)
  $candidates=@($candidateFolders | ForEach-Object {
      if(Test-Path $_) { Get-ChildItem -Path $_ -Filter '*.paf.exe' -File -Recurse -ErrorAction SilentlyContinue }
  } | Where-Object {
      $_.Name -match '^OBSStudioPortable' -and $_.LastWriteTime -ge $begun.AddSeconds(-3)
  } | Sort-Object -Property FullName -Unique)
  Assert ($candidates.Count -eq 1) "Official build produced $($candidates.Count) matching fresh PAF files. See $work/official-run.log"
  $found=$candidates[0].FullName
  Test-Pe $found
  Invoke-Bounded $seven @('t',"$found") $work 180 | Out-Null
  $listing=Invoke-Bounded $seven @('l',"$found",'-slt') $work 90
  Assert ($listing -match 'OBSStudioPortable\.exe') 'Official PAF payload missing launcher'
  Assert ($listing -match 'obs64\.exe') 'Official PAF payload missing real OBS executable'
  $final=Join-Path $out "OBSStudioPortable_$($m.version)_r1_win64.paf.exe"
  if($found -ne $final) { Copy-Item -LiteralPath $found -Destination $final -Force }
  Assert ((Get-Sha $final) -eq (Get-Sha $found)) 'Official PAF copy verification failed'
  @{
      engine='original-unmodified-PortableApps.comInstaller'; version=$version;
      source_sha256=$expected; package_sha256=(Get-Sha $final);
      output=(Split-Path -Leaf $final)
  } | ConvertTo-Json | Set-Content "$project/build/paf-provenance.json" -Encoding utf8
  Write-Host "Official PAF generated and archive-validated: $final" -ForegroundColor Green
} catch {
  Write-Warning "Official PAF unavailable: $_"
  $message="Official PortableApps.com Installer build failed or cannot be verified: $_"
  $message | Set-Content "$work/error.txt" -Encoding utf8
  if($RequirePaf) { throw $message }
  Write-Warning 'Validated ZIP will remain available. No independent NSIS file will be mislabeled as official.'
}
