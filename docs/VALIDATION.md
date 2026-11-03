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
