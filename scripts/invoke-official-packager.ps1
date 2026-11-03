# Monitor the vendor compiler while it runs. Never send keystrokes, automate
# dialogs, modify the vendor program, or launch a PAF installation wizard.
# A real large OBS package can take longer than a fixed 420-second limit.
# However, an idle interactive prompt is stopped without consuming 20 minutes.
function Get-OfficialProcessIds([int]$RootId) {
  $ids=New-Object 'System.Collections.Generic.HashSet[int]'
  [void]$ids.Add($RootId)
  try {
    $all=@(Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object ProcessId,ParentProcessId)
    $again=$true
    while($again) {
      $again=$false
      foreach($entry in $all) {
        if($ids.Contains([int]$entry.ParentProcessId)) {
          if($ids.Add([int]$entry.ProcessId)) { $again=$true }
        }
      }
    }
  } catch {
    Write-Host "Process-tree inspection unavailable; monitoring packager root only: $_"
  }
  foreach($id in $ids) { Write-Output ([int]$id) }
}
function Invoke-OfficialPackager {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Stage,
    [Parameter(Mandatory)][string]$Work,
    [Parameter(Mandatory)][string]$LogFile,
    [int]$MaxSeconds=1080,
    [int]$IdleSeconds=180
  )
  Ensure-Directory $Work
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$Exe
  $psi.WorkingDirectory=$Work
  $psi.UseShellExecute=$false
  $psi.RedirectStandardOutput=$true
  $psi.RedirectStandardError=$true
  [void]$psi.ArgumentList.Add($Stage)
  $p=[Diagnostics.Process]::new()
  $p.StartInfo=$psi
  $startedAt=[DateTime]::UtcNow
  $lastActivity=$startedAt
  $previousCpu=-1.0
  $previousTree=''
  $lastWindowReport=''
  $result=''
  $stdoutTask=$null
  $stderrTask=$null
  try {
    Assert ($p.Start()) "Failed to start vendor packager: $Exe"
    $stdoutTask=$p.StandardOutput.ReadToEndAsync()
    $stderrTask=$p.StandardError.ReadToEndAsync()
    Write-Host "Vendor CLI launched with package directory (PID $($p.Id)): $Stage"
    while(-not $p.WaitForExit(15000)) {
      $elapsed=([DateTime]::UtcNow-$startedAt).TotalSeconds
      $ids=@(Get-OfficialProcessIds $p.Id)
      $cpu=0.0
      $windows=New-Object 'System.Collections.Generic.List[string]'
      foreach($id in $ids) {
        try {
          $child=Get-Process -Id $id -ErrorAction Stop
          if($null -ne $child.CPU) { $cpu += [double]$child.CPU }
          if(-not [string]::IsNullOrWhiteSpace($child.MainWindowTitle)) {
            $windows.Add("PID ${id}: $($child.MainWindowTitle)")
          }
        } catch {} # A child may have exited between enumeration and inspection.
      }
      $tree=(@($ids | Sort-Object) -join ',')
      if($previousCpu -lt 0 -or ($cpu-$previousCpu) -gt 0.15 -or ($tree -cne $previousTree)) {
        $lastActivity=[DateTime]::UtcNow
      }
      $previousCpu=$cpu
      $previousTree=$tree
      $idle=([DateTime]::UtcNow-$lastActivity).TotalSeconds
      $windowText=if($windows.Count) { $windows -join ' | ' } else { '<none reported>' }
      Write-Host ('Official PAF status: {0:N0}s elapsed, {1:N0}s idle, {2:N1} CPU-s, processes [{3}], windows: {4}' -f $elapsed,$idle,$cpu,$tree,$windowText)
      if($elapsed -ge $MaxSeconds) {
        throw "Vendor packager exceeded $MaxSeconds seconds; process details were printed above."
      }
      if($idle -ge $IdleSeconds) {
        throw "Vendor packager was idle for $IdleSeconds seconds. Possible hidden GUI prompt or stalled compiler; process/window diagnostics printed above."
      }
    }
    if(-not $stdoutTask.Wait(10000) -or -not $stderrTask.Wait(10000)) {
      throw 'Official packager exited, but inherited stdout/stderr pipes did not close; possible orphan child process.'
    }
    $result="--- stdout ---`n$($stdoutTask.Result)`n--- stderr ---`n$($stderrTask.Result)"
    Set-Content -LiteralPath $LogFile -Value $result -Encoding utf8
    if($result.Trim().Length -gt 0) { Write-Host $result }
    if($p.ExitCode -ne 0) { throw "Vendor packager exited with status $($p.ExitCode)." }
    Write-Host "Vendor process exited successfully in $([int]([DateTime]::UtcNow-$startedAt).TotalSeconds) seconds."
  } catch {
    $errorMessage=$_.ToString()
    $diagnostic="ERROR: $errorMessage`nStage: $Stage`nCompiler: $Exe`nElapsed: $([int]([DateTime]::UtcNow-$startedAt).TotalSeconds)s`n"
    if($stdoutTask -and $stdoutTask.IsCompletedSuccessfully) { $diagnostic += "`nSTDOUT:`n$($stdoutTask.Result)" }
    if($stderrTask -and $stderrTask.IsCompletedSuccessfully) { $diagnostic += "`nSTDERR:`n$($stderrTask.Result)" }
    $diagnostic | Set-Content -LiteralPath $LogFile -Encoding utf8
    try { if(-not $p.HasExited) { $p.Kill($true); [void]$p.WaitForExit(10000) } } catch { Write-Warning "Could not stop vendor process tree cleanly: $_" }
    throw $errorMessage
  } finally {
    $p.Dispose()
  }
}
