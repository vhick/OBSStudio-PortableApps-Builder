"""PAF-only r8 input/output isolation. No genuine PAF generated here."""
from pathlib import Path
import yaml
root=Path(__file__).resolve().parents[1]
p=root/'.github/workflows/official-paf-from-r5.yml'
s=p.read_text()
yaml.safe_load(s)
assert s.count('vhick/portable-release-publisher@v1.1.1')==2
assert 'portable-obs-v${{ steps.source.outputs.version }}-r8-paf' in s
assert 'RELEASE_TAG: portable-obs-v${{ steps.source.outputs.version }}-r8\n' not in s
assert "default: 'portable-obs-v33.0.1-r8'" in s
assert 'output/*.zip' not in s
assert 'files: output/*.paf.exe' in s
assert s.index('scripts/preflight-official-paf.ps1')<s.index('scripts/restore-r8-stage.ps1')
assert 'scripts/build-official-paf.ps1 -RequirePaf -PackageRevision r8' in s
for n in ('resolve-paf-source.ps1','restore-r8-stage.ps1','prepare-official-paf-stage.ps1',
          'build-official-paf.ps1','validate-paf-only.ps1','official-paf-tool.ps1',
          'invoke-official-packager.ps1'):
    assert (root/'scripts'/n).is_file(),n
source=(root/'scripts/resolve-paf-source.ps1').read_text()
restore=(root/'scripts/restore-r8-stage.ps1').read_text()
assert '-r8$' in source
assert '_r8_win64.zip' in source and '_r8_win64.zip' in restore
assert "package_revision -ceq 'r8'" in restore
assert 'SHA256 mismatch' in restore
assert 'Get-Sha' in restore and 'Test-Pe' in restore
assert 'No OBS download' in source
pack=(root/'scripts/build-official-paf.ps1').read_text()
assert 'original-unmodified-PortableApps.comInstaller' in pack
assert 'Get-OfficialPafTool' in pack
assert 'Invoke-OfficialPackager' in pack
assert 'official-run.log' in pack
assert 'verified-payload' in pack
assert 'original r5' not in pack
assert 'r8_win64.paf.exe' in (root/'scripts/validate-paf-only.ps1').read_text()
print('r8 PAF-only static checks passed (must use actual r8 ZIP, separate r8-paf tag).')
