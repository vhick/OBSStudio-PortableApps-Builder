"""Local structural regression only: not an official PAF Windows integration test."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
workflow=root/'.github/workflows/official-paf-from-r5.yml'
text=workflow.read_text()
assert 'jobs:' in text and '  paf-only:' in text
assert text.count('      - name: ') >= 9
assert 'Download existing r5 ZIP' in text
assert 'Check target r6 tag' in text
assert 'Confirm new r6 release' in text
assert 'actions/upload-artifact' not in text
assert text.count('vhick/portable-release-publisher@v1.1.1')==2
assert "files: output/*.paf.exe" in text
assert 'output/*.zip' not in text
assert 'scripts/download-obs.ps1' not in text
assert 'scripts/compile-launcher.ps1' not in text
assert 'scripts/stage.ps1' not in text
assert "-RequirePaf -PackageRevision r6" in text
assert "prune: 'false'" in text
for file in ['scripts/resolve-paf-source.ps1','scripts/restore-r5-stage.ps1','scripts/build-official-paf.ps1','scripts/validate-paf-only.ps1']:
    assert (root/file).is_file(),file
assert 'SHA256SUMS.txt' in (root/'scripts/resolve-paf-source.ps1').read_text()
assert 'SHA256 mismatch' in (root/'scripts/restore-r5-stage.ps1').read_text()
assert 'No OBS download' in (root/'scripts/resolve-paf-source.ps1').read_text()
paf=(root/'scripts/build-official-paf.ps1').read_text()
for t in ['[switch]$RequirePaf', 'PackageRevision', 'PortableApps.comInstaller.exe', 'original-unmodified-PortableApps.comInstaller', 'official-run.log', 'verified-payload', 'obs64.exe', 'Get-Sha']:
    assert t in paf,t
assert "if($RequirePaf) { throw $message }" in paf
old=(root/'.github/workflows/build-portableapps.yml').read_text()
assert 'portable-obs-v${{ steps.upstream.outputs.version }}-r5' in old
assert 'scripts/preflight-launcher.ps1' in old
print('PAF-only structural checks passed; unchanged r5 workflow retained; no Windows execution was performed.')
