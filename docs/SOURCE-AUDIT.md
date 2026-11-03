# OBS Studio 33.x source-based Windows portability audit

Upstream: https://github.com/obsproject/obs-studio
Canonical source at build time: the OBS release tag + full Git commit recorded in `build/release.json`.
Verified audit reference version: 33.0.1 (2026-10-29). The build queries the latest stable version again on each run.

## Framework, distribution, build strategy

- OBS uses C/C++, Qt 6, libobs, CMake, CEF for browser sources/docks, FFmpeg, Windows video/audio/capture APIs and bundled plugins.
- Upstream supplies a ready-to-extract Windows x64 ZIP. The builder verifies this official binary ZIP against the SHA-256 digest published in the upstream GitHub release metadata, instead of rebuilding OBS's extensive toolchain. This is a deliberate practical exception to full source compilation. The native portable launcher **is compiled** using the Windows MSVC toolchain in Actions.
- Official Windows supports Windows 10 and 11 with a compatible GPU and graphics runtime. VC++ Redistributable may be needed. A ZIP package is not an installer for drivers or redistributables.
- The `--portable` switch is parsed in `frontend/obs-main.cpp`. Other flags include `--disable-updater`, `--safe-mode`, and `--multi`. OBS documents `--version` as unavailable on Windows, so the CI smoke test does not use it. The portable launcher disallows `--multi` to prevent corruption.
- `GetAppConfigPath` in `frontend/OBSApp.cpp` switches to `CONFIG_PATH` during portable mode; OBS creates `obs-studio/basic`, `logs`, `profiler_data`, `crashes`, `updates`, `plugin_config`, profiles and scenes.
- `frontend/utility/platform-windows.cpp` uses `data/obs-studio` for bundled assets and `CSIDL_MYVIDEO` for the default recording destination.

## Storage and system-impact findings

| Location or component | Observed behavior | Builder handling | Limitation |
|---|---|---|---|
| `%APPDATA%\obs-studio` | Normal-mode application configuration, scene collections and logs | `--portable` avoids using this normal-mode profile | Existing installed-OBS content is never moved or overwritten |
| `<OBS ZIP root>\config\obs-studio` | Native portable settings, global/user INI, scenes, profiles, plugin configuration and logs | On NTFS, `App\OBSStudio\config` temporary junction points into `Data\OBSConfig` and is removed after normal shutdown. On other writable filesystems, verified copy-back/next-launch recovery | Junctions use absolute Windows paths; launcher recreates on each launch, including after folder move |
| `Data\OBSConfig\obs-studio\basic\profiles` | User profiles and settings | Persisted directly through junction or via verified copy-back | Conflicting files saved to `Data\RecoveryConflicts` before replacement |
| `Data\OBSConfig\obs-studio\basic\scenes` | Scene collection JSON | Persisted | Media paths referenced in the JSON may still point to an old device/drive |
| `Data\OBSConfig\obs-studio\logs`, `crashes`, `profiler_data` | OBS diagnostics | Persisted | Runtime-created host Windows event logs, GPU driver caches and prefetch cannot generally be moved safely |
| `Data\OBSConfig\obs-studio\plugin_config`, `plugin_manager` | OBS plugins and plugin manager data | Persisted | Third-party plugins may create unknown custom paths or registry entries, beyond OBS's own contract |
| `%LOCALAPPDATA%`, `%APPDATA%`, `%PROGRAMDATA%`, `%TEMP%` new OBS-named top-level directories | Possible extra storage from controlled dependencies | Before/after snapshot of absent roots, checksum/byte-verified copy to `Data\TraceGuard\<Area>\<Directory>` including empty folders, then removal only on successful capture | Filename/creation-time correlation is not guaranteed Windows process attribution; concurrent installed OBS should not run. Pre-existing roots are intentionally excluded to protect the host |
| User-selected recording directory (often `%USERPROFILE%\Videos`) | Media output can be large and is explicitly selected by user | Never move or delete recordings | Not portable by default; user must choose a relative/destination path intentionally |
| Windows registry, hardware drivers, virtual camera | The official virtualcam registration script uses `regsvr32` to register a COM class such as `HKLM\SOFTWARE\Classes\CLSID\{A3FCE0F5-3493-419F-958A-ABA1250EC20B}`; the installer may create `%PROGRAMDATA%\obs-studio-hook` | Builder and portable launcher never register virtual camera DLLs or create these keys, drivers, services or scheduled tasks | Some optional features require an existing host registration or installation; not a fully self-contained OS abstraction |
| Browser-source CEF user state | Often held under OBS plugin data | Native OBS portable profile redirects supported state | Embedded plugins and browser integrations may leave OS-managed traces |

## Safety and deliberate boundaries

The launcher does **not** install plugins, drivers or VC++ Redistributables, does not forcibly terminate other processes, and does not clean general browser/system cache directories. It does not monitor every possible arbitrary path and it cannot claim that *all* software extensions will be portable without an individual audit. A full per-process write attribution system across every directory requires elevated Windows telemetry or application-specific instrumentation, neither appropriate to introduce silently.

The application-specific external scan is limited to *new top-level directories* beginning with `obs-studio-portable-` or `obs_portable_`, or named `obs-studio` / `obs-studio-updater`. It only examines those roots after OBS stops and preserves their complete nested layout, including empty directories. It leaves pre-existing directories and paths containing reparse points untouched. If a capture fails, the original is retained and the failure appears in `Data\launcher.log`.

The exact list of host-trace locations for arbitrary third-party plugins is not statically knowable. See manual acceptance testing for real Windows validation.

## Official source links

- OBS native portable mode: https://obsproject.com/kb/portable-mode
- Virtual camera registration requires admin: https://obsproject.com/kb/virtual-camera-troubleshooting
- OBS Windows support: https://obsproject.com/kb/system-requirements
- `frontend/obs-main.cpp` source: https://github.com/obsproject/obs-studio/blob/33.0.1/frontend/obs-main.cpp
- `frontend/OBSApp.cpp`: https://github.com/obsproject/obs-studio/blob/33.0.1/frontend/OBSApp.cpp
- `frontend/utility/platform-windows.cpp`: https://github.com/obsproject/obs-studio/blob/33.0.1/frontend/utility/platform-windows.cpp
- OBS GPLv2+ license: https://github.com/obsproject/obs-studio/blob/33.0.1/COPYING
- Official PortableApps Installer 3.9.22 SHA-256: https://sourceforge.net/projects/portableapps/files/PortableApps.com%20Installer/PortableApps.comInstaller_3.9.22.paf.exe/download
- PortableApps installer.ini: https://github.com/PortableApps/Launcher/blob/master/Other/Source/Manual/ref/paf/installer.rst

## OBS Studio 33 plugin-layout update (2026-09-21)

OBS's official [Legacy Plugin Locations](https://obsproject.com/kb/legacy-plugin-locations)
notes document the move of first-party modules into `core` starting with 33.0.
Portable third-party plugins have a separate new `plugins` location; old
`obs-plugins` is supported as legacy until OBS 34. Never require the legacy
folder in a clean OBS 33 ZIP. The builder validates built-in module DLLs in
`core` for OBS 33+ and in `obs-plugins` for OBS 32 and earlier, preserving the
upstream directory layout unchanged.
