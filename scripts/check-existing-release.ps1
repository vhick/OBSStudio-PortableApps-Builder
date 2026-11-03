# Uses the GitHub REST API rather than `gh release view`, which returns exit code 1
# for an expected missing release and can terminate pwsh steps prematurely.
# Distinguishes an unused tag from an existing release or an orphaned tag.
. "$PSScriptRoot/common.ps1"
Assert (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) 'GITHUB_REPOSITORY is missing'
Assert ($env:GITHUB_REPOSITORY -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'Unexpected repository name'
Assert ($env:RELEASE_TAG -match '^portable-obs-v\d+\.\d+\.\d+-r\d+$') 'Unexpected release tag'
Assert (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) 'Missing GITHUB_TOKEN for release preflight'
Assert (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) 'GITHUB_OUTPUT is missing'

$headers = @{
  'Accept' = 'application/vnd.github+json'
  'Authorization' = "Bearer $env:GH_TOKEN"
  'User-Agent' = 'OBSStudioPortableBuilder/release-check-r4'
}
$api = 'https://api.github.com/repos/' + $env:GITHUB_REPOSITORY
$escapedTag = [uri]::EscapeDataString($env:RELEASE_TAG)

function Get-HttpStatus([string]$Uri) {
  # HTTP 404 is a normal, *successful check* for a new release, not a build failure.
  # On pwsh 7, -SkipHttpErrorCheck provides a response object for 404 without
  # invoking the usual terminating error behavior.
  $response = Invoke-WebRequest -Uri $Uri -Headers $headers -TimeoutSec 40 -SkipHttpErrorCheck
  return [int]$response.StatusCode
}

$releaseStatus = Get-HttpStatus "$api/releases/tags/$escapedTag"
switch ($releaseStatus) {
  200 {
    Write-Host "Release already exists: $env:RELEASE_TAG. Skipping expensive rebuild."
    'skip=true' | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    exit 0
  }
  404 { Write-Host "No release found for $env:RELEASE_TAG; checking tag name availability." }
  default { throw "GitHub release lookup returned unexpected HTTP $releaseStatus (expected 200/404). Refusing to guess." }
}

# A tag without a release is NOT safe to reuse: the publisher must never
# silently overwrite or repoint tags that may have been created manually.
$tagStatus = Get-HttpStatus "$api/git/ref/tags/$escapedTag"
switch ($tagStatus) {
  404 {
    Write-Host "Release and Git tag absent: $env:RELEASE_TAG. Proceeding with build."
    'skip=false' | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
  }
  200 { throw "Tag $env:RELEASE_TAG already exists without a published release. Refusing to reuse it. Change builder revision." }
  default { throw "GitHub tag lookup returned unexpected HTTP $tagStatus (expected 200/404). Refusing to guess." }
}
