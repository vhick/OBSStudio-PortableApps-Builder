"""Portable OBS r8 static consistency checks. Not a Windows runtime test."""
from pathlib import Path
import re
import yaml
root=Path(__file__).resolve().parents[1]
workflows=list((root/'.github/workflows').glob('*.yml'))
assert len(workflows)==2,workflows
for f in workflows:
    text=f.read_text(encoding='utf-8')
    assert 'workflow_dispatch:' in text and 'runs-on: windows-2022' in text,f
    assert text.count('vhick/portable-release-publisher@v1.1.1')==2,f
    assert "prune: 'false'" in text and "dry-run: 'true'" in text and "dry-run: 'false'" in text,f
    assert 'actions/upload-artifact' not in text,f
    yaml.safe_load(text)
launcher=(root/'launcher/OBSStudioPortable.cpp').read_text()
for term in ('obs-studio-hook', 'safe_capture_and_remove', 'safe_copy_tree',
             'same_bytes(source / rel, destination / rel)',
             'fs::remove(source / rel)', '--programdata-hook-selftest',
             'snapshot_roots()', '--portable --disable-updater',
             'FSCTL_SET_REPARSE_POINT', 'RemoveDirectoryW(link.c_str())',
             'SetEnvironmentVariableW(L"PROGRAMDATA"', 'graphics-hook64.dll'):
    assert term in launcher,term
assert 'fs::remove_all(path);' not in launcher, 'Blind recursive ProgramData deletion forbidden'
for term in ('TerminateProcess','WriteProcessMemory','VirtualAllocEx'):
    assert term not in launcher, term
stage=(root/'scripts/stage.ps1').read_text()
for term in ("package_revision='r8'", "@(16,32,48,75,128,256)",
             'OBSStudioPortable.exe', 'AppId=OBSStudioPortable', 'help.html'):
    assert term in stage,term
assert 'RemoveDataDirectory=false' not in stage
full=(root/'.github/workflows/build-portableapps.yml').read_text()
assert 'portable-obs-v${{ steps.upstream.outputs.version }}-r8' in full
assert 'build_official_paf:' in full
assert 'scripts/preflight-launcher.ps1' in full and 'tests/windows-smoke.ps1' in full
assert 'scripts/build-official-paf.ps1 -RequirePaf -PackageRevision r8' in full
assert full.index('scripts/preflight-launcher.ps1')<full.index('scripts/download-obs.ps1')
assert full.index('scripts/preflight-official-paf.ps1')<full.index('scripts/download-obs.ps1')
assert '_r8_win64.zip' in (root/'scripts/package.ps1').read_text()
assert 'User32.lib Shell32.lib' in (root/'scripts/compile-launcher.ps1').read_text()
assert 'User32.lib Shell32.lib' in (root/'scripts/preflight-launcher.ps1').read_text()
assert "('r8')" in (root/'scripts/build-official-paf.ps1').read_text()
smoke=(root/'tests/windows-smoke.ps1').read_text()
assert "--programdata-hook-selftest" in smoke
assert 'obs-studio-hook/installed-obs-keep.txt' in smoke
assert 'ProgramData' in smoke and 'totally-empty' in smoke
print('r8 full-build static checks passed (no Windows build executed).')
