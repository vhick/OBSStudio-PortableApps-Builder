"""PAF-only r8 input/output isolation. No genuine PAF generated here."""
from pathlib import Path
import yaml
root=Path(__file__).resolve().parents[1]
p=root/'.github/workflows/official-paf-from-r5.yml'
s=p.read_text()
yaml.safe_load(s)
# A clean GitHub-hosted Windows runner does not guarantee third-party PyYAML.
# Install it before executing this test; do not add the dependency to the OBS build.
assert 'PyYAML==6.0.3' in s, 'Missing pinned PyYAML installation'
assert s.index('PyYAML==6.0.3') < s.index('run: python ./tests/paf-only-static.py'), 'Dependency installed too late'
assert '--only-binary=:all:' in s, 'Prefer a prebuilt wheel on the Windows runner'
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
# Regression for Nov 3, 2026 r8.1 failure: the shared release checker formerly
# rejected the PAF-only release tag because it only permitted a trailing -rN.
# Extract the ACTUAL script pattern, not a duplicated hard-coded replacement.
import re
release_check = (root/'scripts/check-existing-release.ps1').read_text()
m = re.search(r"\$releaseTagPattern\s*=\s*'([^']+)'", release_check)
assert m, 'Release-check validation pattern not found'
tag_pattern = re.compile(m.group(1))
for tag in ('portable-obs-v33.0.1-r8', 'portable-obs-v33.0.1-r8-paf',
            'portable-obs-v34.1.0-r12', 'portable-obs-v34.1.0-r12-paf'):
    assert tag_pattern.fullmatch(tag), f'Valid release tag rejected: {tag}'
for tag in ('', 'portable-obs-v33.0.1-r8-paf-extra',
            'portable-obs-v33.0.1-r8.zip', 'portable-obs-v33.0.1-r8-zip',
            'portable-obs-v33.0.1-r0', 'portable-obs-v33.0.1-r8-PAF',
            'portable-obs-v33.0.1-r8-paf/other'):
    assert not tag_pattern.fullmatch(tag), f'Unsafe release tag accepted: {tag}'
assert 'Assert ($env:RELEASE_TAG -cmatch $releaseTagPattern)' in release_check
assert 'if ($ValidateTagsOnly)' in release_check
assert 'check-existing-release.ps1 -ValidateTagsOnly' in s
assert s.index('check-existing-release.ps1 -ValidateTagsOnly') < s.index('resolve-paf-source.ps1')
pack=(root/'scripts/build-official-paf.ps1').read_text()
assert 'original-unmodified-PortableApps.comInstaller' in pack
assert 'Get-OfficialPafTool' in pack
assert 'Invoke-OfficialPackager' in pack
assert 'official-run.log' in pack
assert 'verified-payload' in pack
assert 'original r5' not in pack
assert 'r8_win64.paf.exe' in (root/'scripts/validate-paf-only.ps1').read_text()
print('r8.2 PAF-only static checks passed (r8 ZIP reuse, r8-paf release, release-tag regression).')
