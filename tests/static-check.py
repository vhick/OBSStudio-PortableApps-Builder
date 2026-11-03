"""Fast dependency-free preflight, intentionally not a Windows integration test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
files = [
    'README.md', '.github/workflows/build-portableapps.yml', 'launcher/OBSStudioPortable.cpp',
    'scripts/resolve.ps1', 'scripts/check-existing-release.ps1', 'scripts/download-obs.ps1', 'scripts/compile-launcher.ps1',
    'scripts/stage.ps1', 'scripts/build-official-paf.ps1', 'scripts/check-packages.ps1',
    'scripts/package.ps1', 'tests/windows-smoke.ps1', 'docs/SOURCE-AUDIT.md'
]
for name in files:
    f = root / name
    assert f.is_file() and f.stat().st_size > 100, f'Missing/empty: {name}'

yml = (root / '.github/workflows/build-portableapps.yml').read_text()
assert 'workflow_dispatch:' in yml
assert 'runs-on: windows-2022' in yml
assert "contents: write" in yml
assert yml.count('vhick/portable-release-publisher@v1.1.1') == 2
assert "dry-run: 'true'" in yml and "dry-run: 'false'" in yml
assert 'actions/upload-artifact' not in yml
assert 'prune: ' in yml and "prune: 'false'" in yml
assert 'RUNNER_DEBUG' not in yml

launcher = (root / 'launcher/OBSStudioPortable.cpp').read_text()
for text in ('--portable --disable-updater', 'FSCTL_SET_REPARSE_POINT',
             'RemoveDirectoryW(link.c_str())', 'safe_copy_tree',
             'totally-empty', 'empty-tree', 'relocation-manifest.tsv',
             'std::filesystem', 'GetCommandLineW'):
    assert text in launcher, f'Missing launcher requirement: {text}'
assert 'TerminateProcess' not in launcher
assert 'WriteProcessMemory' not in launcher
assert 'VirtualAllocEx' not in launcher

paf = (root / 'scripts/build-official-paf.ps1').read_text()
assert '689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67' in paf
assert "3.9.22" in paf
assert "-RequirePaf" not in paf  # switch in this script is a declared parameter, not mandatory invocation
assert 'New-Item -ItemType Junction' not in paf

stage = (root / 'scripts/stage.ps1').read_text()
assert 'RemoveDataDirectory=false' in stage
assert 'ExtractAssociatedIcon' in stage
assert 'AppId=OBSStudioPortable' in stage

smoke = (root / 'tests/windows-smoke.ps1').read_text()
assert 'smoke-target' in smoke
assert 'Copy-Item -LiteralPath $sourceStage' in smoke
assert 'totally-empty' in smoke and 'empty-tree/deep/leaf' in smoke
print(f'Static preflight passed: {len(files)} files, action inputs, launcher safety patterns, test isolation.')

# Regression: failed r1 step 4 used `gh release view` and returned exit code 1
# for a missing release. The r2 preflight uses explicit REST status comparisons.
preflight = (root / 'scripts/check-existing-release.ps1').read_text()
assert 'Invoke-WebRequest' in preflight and '-SkipHttpErrorCheck' in preflight
assert '200 {' in preflight and '404 {' in preflight
assert '/releases/tags/' in preflight and '/git/ref/tags/' in preflight
assert 'skip=false' in preflight and 'skip=true' in preflight
release_check_step = yml.split('      - name: Check existing release and tag (HTTP 200/404 safe)', 1)[1].split('      - name:', 1)[0]
assert 'gh release view' not in release_check_step
assert 'scripts/check-existing-release.ps1' in yml
assert '-r2' in yml and '-r1' not in yml
print('r2 static guard passed: REST 200/404 branches and tag-collision safeguards are present (not live-tested).')
