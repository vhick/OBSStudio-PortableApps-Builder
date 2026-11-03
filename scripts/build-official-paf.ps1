param(
  [switch]$RequirePaf,
  [ValidateSet('r8')][string]$PackageRevision='r8'
)
. "$PSScriptRoot/common.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$m=Get-Content -Raw "$project/build/release.json" | ConvertFrom-Json
$stage=(Resolve-Path "$project/build/stage/OBSStudioPortable").Path
$out=Join-Path $project 'output'
Ensure-Directory $out
Assert ($m.version -match '^\d+\.\d+\.\d+$') 'Invalid upstream release metadata'
Assert (@(Get-ChildItem -LiteralPath "$stage/Data" -Force -Recurse -ErrorAction Stop).Count -eq 0) 'Data must be empty in release packaging stage'
Assert ((Get-Content -Raw "$stage/App/AppInfo/installer.ini") -notmatch '(?mi)^RemoveDataDirectory\s*=') 'Obsolete Data removal key present.'
Test-Pe "$stage/OBSStudioPortable.exe"
Test-Pe "$stage/App/OBSStudio/bin/64bit/obs64.exe"

# The same vendor distribution was tested on a tiny package before downloading
# the large OBS ZIP. Reuse it; do not extract or execute a PAF setup wizard.
. "$PSScriptRoot/official-paf-tool.ps1"
. "$PSScriptRoot/invoke-official-packager.ps1"
$version='3.9.22'
$expected='689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67'
$work=Join-Path $project 'build/official-installer'
$source=Join-Path $work "PortableApps.comInstaller_${version}.paf.exe"
$verify=Join-Path $work 'verified-payload'
Ensure-Directory $work
try {
  $seven=Find-SevenZip
  $tool=Get-OfficialPafTool
  Write-Host "Official packager: $tool"
  Write-Host "Stage: $stage"
  $begun=[DateTime]::UtcNow.AddSeconds(-15)
  $maxSeconds=1080
  $idleSeconds=180
  Invoke-OfficialPackager -Exe $tool -Stage $stage -Work $work -LogFile "$work/official-run.log" -MaxSeconds $maxSeconds -IdleSeconds $idleSeconds

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
  # then compare both Windows executables against the validated portable stage contents.
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
    $instText=Get-Content -Raw -LiteralPath $installerInfos[0].FullName
    Assert ($instText -notmatch '(?mi)^RemoveDataDirectory\s*=') 'PAF unexpectedly contains the obsolete Data setting'
    Assert ($instText -match '(?m)^RemoveAppDirectory=true\s*$') 'PAF is missing the expected upgrade App behavior'
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
  Write-Warning 'ZIP-only fallback enabled in r8 workflow. No independent installer is being mislabeled as official.'
}
