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

The workflow contains runtime gates that are intended to execute on `windows-2022`: native launcher PE signature, genuine upstream OBS binary PE signature, native launcher `--storage-selftest` lifecycle (no OBS GUI startup), external file/nonempty/empty directory recovery, relocation, ZIP archive integrity, optional official PAF archive validation and release asset discovery. These must be observed in a real Actions run before calling them passed.

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
- r4 now declares a layout-checked mount-point buffer without WDK dependencies and adds `/Zs` early MSVC preflight before downloading OBS. The r4 `/Zs` preflight later passed on Windows, but r4 failed during full linking; r5 now tests both compilation and linking before download.

## Evidence from the uploaded November 3, 2026 r4 Actions log

- OBS Studio 33.0.1 stable resolution, existing-release check, publisher v1.1.1 interface, OBS module-layout regression and 223,786,669-byte official OBS ZIP checksum/extraction passed on `windows-2022`.
- The new `/Zs` preflight passed, and full compilation reached the MSVC linker.
- Full compilation failed with `LNK2019` for `__imp_MessageBoxW` and `__imp_CommandLineToArgvW`; `LNK1120` reported 2 unresolved externals. This is the currently observed failure.
- r5 links the documented Windows import libraries and replaces syntax-only preflight with compile-and-link, but the r5 fix is **not** verified by a live Windows run yet.
- r5 replaces Windows-incompatible OBS `--version` CI calls with isolated launcher storage tests; actual OBS interface startup/recording remain manual tests.


## r6 PAF-only workflow (2026-11-03)

User confirmed r5 builds and publishes a working ZIP but no PAF. The precise error message in the optional r5 PAF step was not supplied. This r6 project adds mandatory PAF-only recovery from the published r5 ZIP. Locally verified: both YAML workflows parse and both Python static test suites pass; project ZIP integrity verified. **Not executed here:** Windows PowerShell, downloading the r5 release, genuine PortableApps.com Installer compilation, PAF extraction and checksums on Windows, GUI installer acceptance, or Release publishing.

## r8 ProgramData hook revision — new in this kit (2026-11-03)

The user confirmed the r7 two-workflow design builds both ZIP and official PAF on their GitHub Actions runner. That is a user report, not an r8 test. r8 modifies the actual compiled launcher to capture a newly created Game Capture hook directory and makes the PAF-only job strictly reuse the matching r8 ZIP instead of the old r5 launcher.

**Static local checks:** Run `python tests/static-check.py` and `python tests/paf-only-static.py`; both validate workflow structure, safe copy-before-remove, official publisher integration and correct revision/source binding. Windows workflow parsing is checked, and builder ZIP is tested for integrity.

**Not verified in this environment:** Windows MSVC compilation of the changed launcher, actual OBS Game Capture, Windows process-lock handling, real ProgramData permissions, vendor PAF generation from the new r8 ZIP, live release publishing, and manual install/upgrade acceptance. The `--programdata-hook-selftest` fixture is designed to run in the Windows full-build job, not this container.

**Safety exception:** A pre-existing `%PROGRAMDATA%\obs-studio-hook` is intentionally left alone; a failed/locked cleanup can also leave it in place. This does not mean the launcher can guarantee zero ProgramData traces under all circumstances.
