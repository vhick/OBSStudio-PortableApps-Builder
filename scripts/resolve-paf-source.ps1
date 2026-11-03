param(
  [Parameter(Mandatory=$true)][string]$SourceReleaseTag
)
. "$PSScriptRoot/common.ps1"
Assert ($SourceReleaseTag -match '^portable-obs-v(?<version>\d+\.\d+\.\d+)-r5$') 'Source tag must be an existing OBS r5 release such as portable-obs-v33.0.1-r5.'
$version=$Matches['version']
Assert ($env:GITHUB_REPOSITORY -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'GITHUB_REPOSITORY must identify the current builder repository.'
Assert (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) 'GITHUB_TOKEN is required to read the source release.'
Assert (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) 'GITHUB_OUTPUT missing.'
$headers=@{
  'Authorization'="Bearer $env:GH_TOKEN"
  'Accept'='application/vnd.github+json'
  'User-Agent'='OBSStudioPortableBuilder/PAF-only-r6'
}
$encoded=[uri]::EscapeDataString($SourceReleaseTag)
$uri="https://api.github.com/repos/$($env:GITHUB_REPOSITORY)/releases/tags/$encoded"
try { $release=Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 45 }
catch { throw "Cannot access original r5 GitHub Release $SourceReleaseTag in $($env:GITHUB_REPOSITORY): $_" }
Assert (-not $release.draft -and -not $release.prerelease) 'The r5 source release is draft or prerelease.'
Assert ($release.tag_name -ceq $SourceReleaseTag) 'Source release tag mismatch.'
$zipName="OBSStudioPortable_${version}_r5_win64.zip"
foreach($name in @($zipName,'SHA256SUMS.txt')) {
  $found=@($release.assets | Where-Object { $_.name -ceq $name })
  Assert ($found.Count -eq 1) "Existing r5 release must contain exactly one asset named $name."
  Assert ($found[0].size -gt 0) "Source release asset $name is empty."
}
"version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
"zip_name=$zipName" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
"source_tag=$SourceReleaseTag" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
Write-Host "Existing verified-package source found: $SourceReleaseTag / $zipName"
Write-Host 'No OBS download, C++ compilation or launcher rebuild is required.'
