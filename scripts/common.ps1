Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Ensure-Directory([string]$Path) { [void](New-Item -ItemType Directory -Force -Path $Path) }
function Find-SevenZip {
    foreach($name in @('7z.exe', '7za.exe')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if($cmd) { return $cmd.Source }
    }
    foreach($candidate in @('C:\Program Files\7-Zip\7z.exe','C:\Program Files (x86)\7-Zip\7z.exe')) {
        if(Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw '7-Zip is not installed on this Windows runner.'
}
function Test-Pe([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "PE file missing: $Path"
    $f = [IO.File]::OpenRead($Path)
    try {
        Assert ($f.Length -gt 512) "PE file too small: $Path"
        $reader = [IO.BinaryReader]::new($f)
        Assert ($reader.ReadUInt16() -eq 0x5A4D) "Missing MZ signature: $Path"
        $f.Position = 0x3c
        $offset = $reader.ReadInt32()
        Assert ($offset -gt 0 -and $offset -lt ($f.Length - 4)) "Invalid PE offset: $Path"
        $f.Position = $offset
        Assert ($reader.ReadUInt32() -eq 0x4550) "Missing PE signature: $Path"
    } finally { $f.Dispose() }
}
function Invoke-Bounded([string]$Exe,[string[]]$Arguments,[string]$Work,[int]$Seconds=120) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $Work
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }
    $p = [Diagnostics.Process]::Start($psi)
    try {
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit($Seconds * 1000)) {
            $p.Kill()
            throw "Timed out after $Seconds seconds: $Exe"
        }
        [Threading.Tasks.Task]::WaitAll(@($outTask,$errTask),10000) | Out-Null
        $out = $outTask.Result + [Environment]::NewLine + $errTask.Result
        Write-Host $out
        if($p.ExitCode -ne 0) { throw "$Exe failed with exit code $($p.ExitCode)." }
        return $out
    } finally { $p.Dispose() }
}
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Save-VerifiedDownload([string]$Uri,[string]$Out,[string]$Hash) {
    Ensure-Directory (Split-Path -Parent $Out)
    $ok = $false
    for($attempt=1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $Out -MaximumRedirection 8 -TimeoutSec 240 -Headers @{'User-Agent'='OBSStudioPortableBuilder/1'}
            Assert ((Get-Item $Out).Length -gt 100KB) 'Downloaded file is implausibly small'
            Assert ((Get-Sha $Out) -eq $Hash.ToLowerInvariant()) "SHA256 mismatch for $Uri"
            $ok = $true; break
        } catch {
            Write-Warning "Download attempt ${attempt}: $_"
            Remove-Item -LiteralPath $Out -Force -ErrorAction SilentlyContinue
            if($attempt -lt 3) { Start-Sleep -Seconds (2 * $attempt) }
        }
    }
    Assert $ok "Failed verified download: $Uri"
}
