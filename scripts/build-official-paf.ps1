param(
  [switch]$RequirePaf,
  [ValidateSet('r5','r6')][string]$PackageRevision='r5'
)
. "$PSScriptRoot/common.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$m=Get-Content -Raw "$project/build/release.json" | ConvertFrom-Json
$stage=(Resolve-Path "$project/build/stage/OBSStudioPortable").Path
$out=Join-Path $project 'output'
Ensure-Directory $out
Assert ($m.version -match '^\d+\.\d+\.\d+$') 'Invalid upstream release metadata'
Assert (@(Get-ChildItem -LiteralPath "$stage/Data" -Force -Recurse -ErrorAction Stop).Count -eq 0) 'Data must be empty in release packaging stage'
Assert ((Get-Content -Raw "$stage/App/AppInfo/installer.ini") -match '(?m)^RemoveDataDirectory=false\s*$') 'Data upgrade protection is absent'
Test-Pe "$stage/OBSStudioPortable.exe"
Test-Pe "$stage/App/OBSStudio/bin/64bit/obs64.exe"

# Authentic, unmodified PortableApps.com Installer; checksum published by SourceForge.
$version='3.9.22'
$expected='689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67'
$url='https://downloads.sourceforge.net/project/portableapps/PortableApps.com%20Installer/PortableApps.comInstaller_3.9.22.paf.exe'
$work=Join-Path $project 'build/official-installer'
$source=Join-Path $work 'PortableApps.comInstaller_3.9.22.paf.exe'
$extract=Join-Path $work 'unpacked'
$verify=Join-Path $work 'verified-payload'
Ensure-Directory $work
try {
  $seven=Find-SevenZip
  if(-not (Test-Path -LiteralPath $source) -or (Get-Sha $source) -ne $expected) {
    Save-VerifiedDownload $url $source $expected
  }
  Assert ((Get-Sha $source) -ceq $expected) 'Official installer source digest mismatch.'
  Test-Pe $source
  Invoke-Bounded $seven @('t',$source) $work 90 | Out-Null
  if(Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
  Ensure-Directory $extract
  Invoke-Bounded $seven @('x',$source,"-o$extract",'-y') $extract 90 | Out-Null
  $tools=@(Get-ChildItem -LiteralPath $extract -File -Recurse | Where-Object { $_.Name -ieq 'PortableApps.comInstaller.exe' })
  if($tools.Count -ne 1) {
    $executables=@(Get-ChildItem -LiteralPath $extract -File -Recurse -Filter '*.exe' | Select-Object -ExpandProperty FullName)
    Write-Host "Vendor archive executables discovered: $($executables -join '; ')"
    throw "Expected ONE original PortableApps.comInstaller.exe in extracted verified distribution; found $($tools.Count). Not running an install wizard."
  }
  $tool=$tools[0].FullName
  Test-Pe $tool
  Write-Host "Official packager: $tool"
  Write-Host "Stage: $stage"
  # The official packager's documented CLI takes the PortableApps application's
  # main directory as its positional argument. Never execute the PAF's setup GUI.
  $begun=[DateTime]::UtcNow.AddSeconds(-15)
  $log=Invoke-Bounded $tool @($stage) $work 420
  $log | Set-Content -LiteralPath "$work/official-run.log" -Encoding utf8

  # The packager chooses its own name and output directory. Search controlled
  # locations and validate the CONTENT rather than guessing a filename.
  $folders=@((Split-Path -Parent $stage),$work,(Split-Path -Parent $tool),$out) | Sort-Object -Unique
  $paths=@{}
  foreach($folder in $folders) {
    if(-not (Test-Path -LiteralPath $folder)) { continue }
    Get-ChildItem -LiteralPath $folder -Filter '*.paf.exe' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
      if($_.FullName -ne $source -and $_.LastWriteTimeUtc -ge $begun -and $_.Name -match '^(?i:OBSStudioPortable)[_.-]') {
        $paths[$_.FullName]=$_.FullName
      }
    }
  }
  $candidates=@($paths.Values)
  Write-Host "Fresh OBS PAF candidates: $($candidates -join '; ')"
  Assert ($candidates.Count -eq 1) "Expected one newly generated OBS PAF, found $($candidates.Count). Consult $work/official-run.log and PAF step logs."
  $found=$candidates[0]
  Test-Pe $found
  Invoke-Bounded $seven @('t',$found) $work 180 | Out-Null

  # Actually expand the generated NSIS archive (NOT executing its installer),
  # then compare both Windows executables against the verified r5 ZIP contents.
  if(Test-Path -LiteralPath $verify) { Remove-Item -LiteralPath $verify -Recurse -Force }
  Ensure-Directory $verify
  Invoke-Bounded $seven @('x',$found,"-o$verify",'-y') $verify 180 | Out-Null
  foreach($item in @(
    @{ name='OBSStudioPortable.exe'; original="$stage/OBSStudioPortable.exe" },
    @{ name='obs64.exe'; original="$stage/App/OBSStudio/bin/64bit/obs64.exe" }
  )) {
    $payloadHits=@(Get-ChildItem -LiteralPath $verify -File -Recurse | Where-Object { $_.Name -ceq $item.name })
    Assert ($payloadHits.Count -eq 1) "PAF payload must contain exactly one $($item.name) file; found $($payloadHits.Count)"
    Assert ((Get-Sha $payloadHits[0].FullName) -ceq (Get-Sha $item.original)) "PAF payload differs from validated source for $($item.name)"
  }
  $metadata=@(Get-ChildItem -LiteralPath $verify -File -Recurse | Where-Object { $_.Name -ceq 'appinfo.ini' })
  Assert ($metadata.Count -eq 1) 'Generated PAF does not contain a unique appinfo.ini'
  $appInfo=Get-Content -Raw -LiteralPath $metadata[0].FullName
  Assert ($appInfo -match '(?m)^AppId=OBSStudioPortable\s*$') 'PAF contains an unexpected AppID'
  Assert ($appInfo -match '(?m)^Start=OBSStudioPortable\.exe\s*$') 'PAF contains an unexpected launcher'
  $installerInfos=@(Get-ChildItem -LiteralPath $verify -File -Recurse | Where-Object { $_.Name -ceq 'installer.ini' })
  if($installerInfos.Count -gt 0) {
    Assert ($installerInfos.Count -eq 1) 'Ambiguous installer.ini entries inside the PAF'
    Assert ((Get-Content -Raw -LiteralPath $installerInfos[0].FullName) -match '(?m)^RemoveDataDirectory=false\s*$') 'PAF installer.ini does not protect Data'
  }
  $final=Join-Path $out "OBSStudioPortable_$($m.version)_${PackageRevision}_win64.paf.exe"
  Assert (-not (Test-Path -LiteralPath $final)) "Refusing to overwrite an existing installer: $final"
  Copy-Item -LiteralPath $found -Destination $final
  Assert ((Get-Sha $final) -ceq (Get-Sha $found)) 'Official installer copy verification failed'
  $zipSource='fresh-stage'
  if(Test-Path -LiteralPath "$project/build/paf-source.json") {
    $zipSource=(Get-Content -Raw "$project/build/paf-source.json" | ConvertFrom-Json).source_release
  }
  $provenance=[ordered]@{
    engine='original-unmodified-PortableApps.comInstaller'
    engine_version=$version
    engine_sha256=$expected
    stage_appid='OBSStudioPortable'
    source_zip_release=$zipSource
    package_sha256=(Get-Sha $final)
    package_name=(Split-Path -Leaf $final)
    result='archive-extracted-and-key-binaries-sha256-compared'
  }
  $provenance | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$project/build/paf-provenance.json" -Encoding utf8
  Write-Host "VERIFIED OFFICIAL PAF produced: $final" -ForegroundColor Green
} catch {
  $message="Official PortableApps.com Installer failed or output could not be verified: $_"
  $message | Set-Content -LiteralPath "$work/error.txt" -Encoding utf8
  Write-Warning $message
  if(Test-Path -LiteralPath "$work/official-run.log") {
    Write-Host '---- Last lines of packager log ----'
    Get-Content -LiteralPath "$work/official-run.log" -Tail 70 | ForEach-Object { Write-Host $_ }
  }
  if($RequirePaf) { throw $message }
  Write-Warning 'ZIP-only fallback enabled in original r5 workflow. No independent installer is being mislabeled as official.'
}
