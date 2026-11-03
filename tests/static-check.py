"""Fast dependency-free preflight, intentionally not a Windows integration test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
files = [
    'README.md', '.github/workflows/build-portableapps.yml', 'launcher/OBSStudioPortable.cpp',
    'scripts/resolve.ps1', 'scripts/check-existing-release.ps1', 'scripts/download-obs.ps1', 'scripts/compile-launcher.ps1',
    'scripts/stage.ps1', 'scripts/build-official-paf.ps1', 'scripts/check-packages.ps1',
    'scripts/package.ps1', 'scripts/preflight-launcher.ps1', 'tests/windows-smoke.ps1', 'tests/plugin-layout.ps1',
    'scripts/verify-obs-layout.ps1', 'docs/SOURCE-AUDIT.md'
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
# for a missing release. The r3 preflight uses explicit REST status comparisons.
preflight = (root / 'scripts/check-existing-release.ps1').read_text()
assert 'Invoke-WebRequest' in preflight and '-SkipHttpErrorCheck' in preflight
assert '200 {' in preflight and '404 {' in preflight
assert '/releases/tags/' in preflight and '/git/ref/tags/' in preflight
assert 'skip=false' in preflight and 'skip=true' in preflight
release_check_step = yml.split('      - name: Check existing release and tag (HTTP 200/404 safe)', 1)[1].split('      - name:', 1)[0]
assert 'gh release view' not in release_check_step
assert 'scripts/check-existing-release.ps1' in yml
assert '-r5' in yml and '-r4' not in yml
print('r5 release-check guard passed: REST 200/404 branches and tag-collision safeguards are present (not live-tested).')

# Regression for OBS Studio 33's migration from obs-plugins to core modules.
layout = (root / 'scripts/verify-obs-layout.ps1').read_text()
assert "$major -ge 33" in layout
assert "$relative='core'" in layout
assert "$relative='obs-plugins'" in layout
assert "'*.dll'" in layout
assert 'Assert-ObsLayout -Root $root -Version $m.version' in (root / 'scripts/download-obs.ps1').read_text()
fixtures = (root / 'tests/plugin-layout.ps1').read_text()
for expected in ("Version '32.2.0'", "Version '33.0.1'", 'rejectedModern', 'rejectedEmpty'):
    assert expected in fixtures, f'Missing new/legacy plugin layout fixture: {expected}'
assert 'run: ./tests/plugin-layout.ps1' in yml
assert "package_revision='r5'" in stage
print('r5 OBS plugin-layout guard passed: modern/legacy verification and Windows fixture are wired in (not executed here).')

# r4 regression: Windows SDK user-mode headers do not provide the kernel WDK
# REPARSE_DATA_BUFFER type. Test for our explicit, offset-checked wire layout.
assert 'struct ObsMountPointReparseBuffer' in launcher
assert 'static_assert(kObsReparseHeaderBytes == 8' in launcher
assert 'static_assert(kObsMountPointPrefixBytes == 16' in launcher
assert 'reinterpret_cast<ObsMountPointReparseBuffer*>' in launcher
assert 'reinterpret_cast<REPARSE_DATA_BUFFER*>' not in launcher
assert 'FIELD_OFFSET(REPARSE_DATA_BUFFER' not in launcher
preflight=(root / 'scripts/preflight-launcher.ps1').read_text()
assert not re.search(r'\bcl(?:\.exe)?\b[^\r\n]*?/Zs', preflight, flags=re.I) and 'vcvars64.bat' in preflight
assert 'run: ./scripts/preflight-launcher.ps1' in yml
assert yml.index('run: ./scripts/preflight-launcher.ps1') < yml.index('run: ./scripts/download-obs.ps1')
print('r5 MSVC regression guard passed: portable mount-point struct and early FULL compile/link step wired in (Windows run pending).')

# r5 regression: the r4 C++ compilation had two missing Win32 import libraries.
# Both MSVC execution branches and the early compile-and-link preflight must link
# User32.lib (MessageBoxW) and Shell32.lib (CommandLineToArgvW).
compiler=(root / 'scripts/compile-launcher.ps1').read_text()
preflight=(root / 'scripts/preflight-launcher.ps1').read_text()
assert compiler.count('User32.lib Shell32.lib') == 2, 'Both full compile routes must link required Win32 libraries'
assert preflight.count('User32.lib Shell32.lib') == 2, 'Both preflight routes must link required Win32 libraries'
assert not re.search(r'\bcl(?:\.exe)?\b[^\r\n]*?/Zs', preflight, flags=re.I), 'Syntax-only test cannot catch unresolved externals'
assert 'Test-Pe $preflightExe' in preflight, 'Early preflight must produce a real PE executable'
assert 'run: ./scripts/preflight-launcher.ps1' in yml
assert yml.index('run: ./scripts/preflight-launcher.ps1') < yml.index('run: ./scripts/download-obs.ps1')
assert '--storage-selftest' in launcher
assert '--storage-selftest' in smoke and "@('--version')" not in smoke
assert 'builder-empty-tree' in launcher and 'builder-empty-tree/deep' in smoke
assert 'r4 Actions log' in (root / 'docs/VALIDATION.md').read_text()
print('r5 linker regression passed: both native build routes and early full PE preflight use required Win32 libs; headless storage test enabled.')
