param([string]$Version='latest')
. "$PSScriptRoot/common.ps1"
$api='https://api.github.com/repos/obsproject/obs-studio'
$headers=@{'Accept'='application/vnd.github+json';'User-Agent'='OBSStudioPortableBuilder/1'}
if($Version -eq 'latest') { $uri="$api/releases/latest" }
else {
    Assert ($Version -match '^\d+\.\d+\.\d+$') 'Only stable X.Y.Z versions are accepted'
    $uri="$api/releases/tags/$Version"
}
$release=Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 40
Assert (-not $release.draft -and -not $release.prerelease) 'Upstream release is not stable'
Assert ($release.tag_name -match '^\d+\.\d+\.\d+$') 'Upstream tag is not a stable semantic version'
$archiveName="OBS-Studio-$($release.tag_name)-Windows-x64.zip"
$asset=@($release.assets | Where-Object { $_.name -ceq $archiveName })
Assert ($asset.Count -eq 1) "Missing unique official Windows x64 ZIP: $archiveName"
Assert ($asset[0].digest -match '^sha256:[a-fA-F0-9]{64}$') 'Missing official SHA256 asset digest'
$commit=Invoke-RestMethod -Uri "$api/commits/$($release.tag_name)" -Headers $headers -TimeoutSec 40
Assert ($commit.sha -match '^[a-f0-9]{40}$') 'Could not resolve full upstream commit SHA'
Ensure-Directory (Join-Path $PSScriptRoot '../build')
$metadata=[ordered]@{
  version=$release.tag_name; upstream_commit=$commit.sha;
  upstream_release=$release.html_url; archive_name=$archiveName;
  archive_url=$asset[0].browser_download_url;
  archive_sha256=$asset[0].digest.Substring(7).ToLowerInvariant();
  release_published_at=$release.published_at
}
$path=Join-Path $PSScriptRoot '../build/release.json'
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding utf8
Write-Host "Resolved OBS stable $($release.tag_name), commit $($commit.sha)" -ForegroundColor Green
if($env:GITHUB_OUTPUT) {
  "version=$($release.tag_name)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
  "commit=$($commit.sha)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
