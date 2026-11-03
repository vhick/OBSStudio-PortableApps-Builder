"""Local structural regression only: not an official PAF Windows integration test."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
workflow=root/'.github/workflows/official-paf-from-r5.yml'
text=workflow.read_text()
assert 'jobs:' in text and '  paf-only:' in text
assert text.count('      - name: ') >= 9
assert 'Download existing r5 ZIP' in text
assert 'Probe official packager CLI' in text
assert text.index('Probe official packager CLI') < text.index('Download existing r5 ZIP')
assert 'Check target r7 tag' in text
assert 'Confirm new r7 release' in text
assert 'actions/upload-artifact' not in text
assert text.count('vhick/portable-release-publisher@v1.1.1')==2
assert "files: output/*.paf.exe" in text
assert 'output/*.zip' not in text
assert 'scripts/download-obs.ps1' not in text
assert 'scripts/compile-launcher.ps1' not in text
assert 'scripts/stage.ps1' not in text
assert "-RequirePaf -PackageRevision r7" in text
assert "prune: 'false'" in text
for file in ['scripts/resolve-paf-source.ps1','scripts/restore-r5-stage.ps1','scripts/build-official-paf.ps1','scripts/validate-paf-only.ps1']:
    assert (root/file).is_file(),file
assert 'SHA256SUMS.txt' in (root/'scripts/resolve-paf-source.ps1').read_text()
assert 'SHA256 mismatch' in (root/'scripts/restore-r5-stage.ps1').read_text()
assert 'No OBS download' in (root/'scripts/resolve-paf-source.ps1').read_text()
paf=(root/'scripts/build-official-paf.ps1').read_text()
for t in ['[switch]$RequirePaf', 'PackageRevision', 'original-unmodified-PortableApps.comInstaller', 'official-run.log', 'verified-payload', 'obs64.exe', 'Get-Sha']:
    assert t in paf,t
assert "if($RequirePaf) { throw $message }" in paf
old=(root/'.github/workflows/build-portableapps.yml').read_text()
assert 'portable-obs-v${{ steps.upstream.outputs.version }}-r5' in old
assert 'scripts/preflight-launcher.ps1' in old
print('PAF-only structural checks passed; unchanged r5 workflow retained; no Windows execution was performed.')

# Verify timeout monitoring/early failure are real code, not documentation-only.
monitor=(root/'scripts/invoke-official-packager.ps1').read_text()
for s in ['WaitForExit(15000)', 'Get-OfficialProcessIds', 'Get-CimInstance Win32_Process', 'IdleSeconds', 'MaxSeconds', 'Kill($true)', 'Set-Content -LiteralPath $LogFile']:
    assert s in monitor,s
probe=(root/'scripts/preflight-official-paf.ps1').read_text()
assert 'OBSPackagerProbePortable' in probe
assert '-MaxSeconds 120 -IdleSeconds 75' in probe
assert 'Get-OfficialPafTool' in probe
assert 'Get-OfficialPafTool' in paf
assert 'Invoke-OfficialPackager' in paf
assert (root/'scripts/official-paf-tool.ps1').is_file()
assert 'PortableApps.comInstaller.exe' in (root/'scripts/official-paf-tool.ps1').read_text()

assert 'Normalize r5 PAF metadata' in text
assert text.index('Normalize r5 PAF metadata') < text.index('Produce official PortableApps.com PAF')
normalized=(root/'scripts/prepare-official-paf-stage.ps1').read_text()
assert 'appicon_$size.png' in normalized
assert 'help.html' in normalized
assert 'RemoveDataDirectory' in normalized
assert 'Get-Sha' in normalized
assert 'r7' in (root/'scripts/validate-paf-only.ps1').read_text()

assert 'scripts/build-official-paf-r5.ps1' in old
assert (root/'scripts/build-official-paf-r5.ps1').is_file()
