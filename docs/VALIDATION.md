# Validation evidence and limits

## Executed before delivery

- Project files generated on a Linux-based container: yes.
- Python YAML parsing of GitHub Actions workflow: see delivery result.
- Static checks for source scripts and required workflow steps: see delivery result.
- ZIP builder-kit archive creation and `zipfile.testzip()`: see delivery result.

## NOT executed before delivery

- PowerShell scripts under `pwsh` on Windows: no. This container does not provide Windows or PowerShell.
- Native Windows MSVC compile/resource compiler: no. No Windows build toolchain is available here.
- Download/extraction of the 223.8 MB OBS Windows archive: no. This container cannot reach external download hosts.
- Genuine `OBSStudioPortable.exe` Windows runtime and junction operations: not executed here.
- Official PortableApps installer headless output: not executed here.
- GitHub Actions run/publisher dry-run/live release: not executed here.
- Full OBS GUI, recording, streaming, audio, plugins, optional virtual camera: manual Windows testing required.

The workflow contains runtime gates that are intended to execute on `windows-2022`: native launcher PE signature, genuine upstream OBS binary PE signature, executable `--version` startup, external file/nonempty/empty directory recovery, relocation, ZIP archive integrity, optional official PAF archive validation and release asset discovery. These must be observed in a real Actions run before calling them passed.

## Evidence from the uploaded November 3, 2026 r2 Actions log

- `scripts/resolve.ps1` selected OBS 33.0.1 successfully.
- `scripts/check-existing-release.ps1` detected absent release/tag correctly.
- Shared publisher `action.yml` interface check succeeded.
- Downloaded official 223,786,669-byte OBS ZIP passed 7-Zip archive testing.
- Archive extracted 2,290 files and 112 folders successfully.
- r2 failed in `scripts/download-obs.ps1` because it required obsolete `obs-plugins`; OBS 33 uses `core`. Neither launcher compilation nor publishing was reached.
- r3 adds a version-aware module validation function and synthetic PowerShell regression fixtures. The fixtures must execute on the next Windows Actions run; do not represent them as having run in this Linux container.

## Evidence from the uploaded November 3, 2026 r3 Actions log

- Source/tag resolution, publisher interface, OBS 32/33 layout fixture and OBS 33.0.1 ZIP SHA/extraction passed in a Windows GitHub Actions run.
- MSVC compilation failed: `REPARSE_DATA_BUFFER` and `REPARSE_DATA_BUFFER_HEADER_SIZE` are unavailable from the ordinary Windows SDK headers.
- r4 now declares a layout-checked mount-point buffer without WDK dependencies and adds `/Zs` early MSVC preflight before downloading OBS. The r4 preflight itself has **not** yet executed on Windows at delivery time.
