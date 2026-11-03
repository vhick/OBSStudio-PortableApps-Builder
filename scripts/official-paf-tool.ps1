# Fetch only the authenticated PortableApps.com packaging tool. It is NOT launched
# as a PAF installer and its files are never modified. Shared by the probe and
# final build to avoid downloading/extracting the same vendor archive twice.
. "$PSScriptRoot/common.ps1"
function Get-OfficialPafTool {
  $project=(Resolve-Path "$PSScriptRoot/..").Path
  $version='3.9.22'
  $expected='689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67'
  $url='https://downloads.sourceforge.net/project/portableapps/PortableApps.com%20Installer/PortableApps.comInstaller_3.9.22.paf.exe'
  $work=Join-Path $project 'build/official-installer'
  $source=Join-Path $work "PortableApps.comInstaller_${version}.paf.exe"
  $extract=Join-Path $work 'unpacked'
  Ensure-Directory $work
  $seven=Find-SevenZip
  if(-not (Test-Path -LiteralPath $source) -or (Get-Sha $source) -cne $expected) {
    Save-VerifiedDownload $url $source $expected
  }
  Assert ((Get-Sha $source) -ceq $expected) 'Official Installer 3.9.22 SHA256 is incorrect.'
  Test-Pe $source
  if(-not (Test-Path "$extract/PortableApps.comInstaller.exe")) {
    Invoke-Bounded $seven @('t',$source) $work 90 | Out-Null
    if(Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    Ensure-Directory $extract
    Invoke-Bounded $seven @('x',$source,"-o$extract",'-y') $extract 90 | Out-Null
  }
  $tools=@(Get-ChildItem -LiteralPath $extract -File -Recurse | Where-Object { $_.Name -ieq 'PortableApps.comInstaller.exe' })
  Assert ($tools.Count -eq 1) "Expected exactly one vendor packager executable; found $($tools.Count)."
  Test-Pe $tools[0].FullName
  Write-Host "Official unmodified installer tool: $($tools[0].FullName)"
  return $tools[0].FullName
}
