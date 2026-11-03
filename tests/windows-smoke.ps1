. "$PSScriptRoot/../scripts/common.ps1"
$project=(Resolve-Path "$PSScriptRoot/..").Path
$sourceStage="$project/build/stage/OBSStudioPortable"
# NEVER perform runtime tests inside release staging: these tests create persistent Data.
$stage="$project/build/smoke-target/OBSStudioPortable"
Ensure-Directory (Split-Path -Parent $stage)
if(Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
Copy-Item -LiteralPath $sourceStage -Destination $stage -Recurse -Force
$exe="$stage/OBSStudioPortable.exe"
Test-Pe $exe
# The launcher itself runs its Windows filesystem capture integration fixture.
# All four cases, including empty nested directory trees, are checked by C++.
Invoke-Bounded $exe @('--traceguard-selftest') $stage 30 | Out-Null
$folder="$stage/Data/TraceGuard/Local/obs-studio-portable-fixture-test"
foreach($relative in @('created.txt','nested/nonempty/nested.txt','totally-empty','empty-tree/deep/leaf')) {
  Assert (Test-Path (Join-Path $folder $relative)) "TraceGuard missing fixture: $relative"
}
$local=[Environment]::GetFolderPath('LocalApplicationData')
Assert (-not (Test-Path (Join-Path $local 'obs-studio-portable-fixture-test'))) 'Fixture was not safely removed after verified capture'
# Protect deliberately unrelated pre-existing host file during another launch.
$unrelated=Join-Path $local ('OBSStudioPortable-UNRELATED-'+[guid]::NewGuid().ToString('N'))
Ensure-Directory $unrelated
$sentinel=Join-Path $unrelated 'keep.txt'
'keep original host data' | Set-Content -LiteralPath $sentinel -Encoding utf8
try {
  $profileDir="$stage/Data/OBSConfig/obs-studio"
  Ensure-Directory $profileDir
  'persistent profile' | Set-Content -LiteralPath "$profileDir/keep.txt" -Encoding ascii
  # OBS documents --version/--help as unavailable on Windows. Do not attempt
  # a Qt GUI launch in an unattended runner. Exercise the native launcher
  # storage lifecycle without assuming a Windows CLI-only OBS execution mode.
  Invoke-Bounded $exe @('--storage-selftest') $stage 90 | Out-Null
  Assert ((Get-Content "$profileDir/keep.txt" -Raw).Trim() -eq 'persistent profile') 'Data changed after storage test'
  Assert (Test-Path "$profileDir/builder-storage-selftest.txt") 'Launcher did not preserve config fixture'
  Assert (Test-Path "$profileDir/builder-empty-tree/deep" -PathType Container) 'Launcher lost empty directory tree'
  Assert (-not (Test-Path "$stage/App/OBSStudio/config")) 'Temporary config junction was not removed'
  Assert ((Get-Content $sentinel -Raw).Trim() -eq 'keep original host data') 'Unrelated host file changed'
  # Move the entire root to a path containing spaces, testing relative paths and
  # junction re-binding when the drive/folder changes.
  $relocated="$project/build/relocation test/OBSStudioPortable"
  Ensure-Directory (Split-Path -Parent $relocated)
  if(Test-Path $relocated) { Remove-Item $relocated -Recurse -Force }
  Copy-Item -LiteralPath $stage -Destination $relocated -Recurse -Force
  $relExe="$relocated/OBSStudioPortable.exe"
  Invoke-Bounded $relExe @('--storage-selftest') $relocated 90 | Out-Null
  Assert ((Get-Content "$relocated/Data/OBSConfig/obs-studio/keep.txt" -Raw).Trim() -eq 'persistent profile') 'Moved Data was lost'
  Assert (Test-Path "$relocated/Data/OBSConfig/obs-studio/builder-empty-tree/deep" -PathType Container) 'Moved empty directory tree was lost'
  Assert (-not (Test-Path "$relocated/App/OBSStudio/config")) 'Relocated junction was not removed'
  Assert ((Get-Content $sentinel -Raw).Trim() -eq 'keep original host data') 'Unrelated host file changed during relocation'
  Write-Host 'Windows smoke: TraceGuard fixture + headless storage lifecycle + data persistence + folder move succeeded.' -ForegroundColor Green
} finally {
  Remove-Item $unrelated -Recurse -Force
}
