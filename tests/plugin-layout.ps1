# Fast Windows regression test. The official OBS binaries are downloaded later.
# These deliberately small synthetic directories exercise both layout branches.
. "$PSScriptRoot/../scripts/verify-obs-layout.ps1"
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('obs-module-layout-'+[guid]::NewGuid().ToString('N'))
try {
  Ensure-Directory (Join-Path $fixture 'bin/64bit')
  Ensure-Directory (Join-Path $fixture 'data/obs-studio')
  'fixture - not a real binary' | Set-Content -LiteralPath (Join-Path $fixture 'bin/64bit/obs64.exe')
  # v33 must reject an old-only layout; that caused the 2026-11-03 r2 failure.
  Ensure-Directory (Join-Path $fixture 'obs-plugins/64bit')
  'fixture' | Set-Content -LiteralPath (Join-Path $fixture 'obs-plugins/64bit/legacy.dll')
  Assert-ObsLayout -Root $fixture -Version '32.2.0'
  $rejectedModern=$false
  try { Assert-ObsLayout -Root $fixture -Version '33.0.1' } catch {
    if($_.Exception.Message -match 'modern core module directory') { $rejectedModern=$true } else { throw }
  }
  Assert $rejectedModern 'OBS 33 incorrectly accepted only the obsolete plugin folder'
  Ensure-Directory (Join-Path $fixture 'core/obs-browser')
  'fixture' | Set-Content -LiteralPath (Join-Path $fixture 'core/obs-browser/obs-browser.dll')
  Assert-ObsLayout -Root $fixture -Version '33.0.1'
  # The modern core module directory must contain at least one DLL.
  Remove-Item -LiteralPath (Join-Path $fixture 'core/obs-browser/obs-browser.dll')
  $rejectedEmpty=$false
  try { Assert-ObsLayout -Root $fixture -Version '33.0.1' } catch {
    if($_.Exception.Message -match 'no plugin DLL') { $rejectedEmpty=$true } else { throw }
  }
  Assert $rejectedEmpty 'Empty OBS core folder was incorrectly accepted'
  Write-Host 'OBS 32 and OBS 33+ module layout regression fixtures passed.' -ForegroundColor Green
} finally {
  if(Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Force -Recurse }
}
