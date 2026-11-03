# Sources inspected, 3 November 2026

- Official OBS upstream: https://github.com/obsproject/obs-studio
- Official stable releases and SHA-256 metadata: https://api.github.com/repos/obsproject/obs-studio/releases/latest
- Official OBS Windows portable-mode KB: https://obsproject.com/kb/portable-mode
- `obs-main.cpp` portable flags and startup: https://raw.githubusercontent.com/obsproject/obs-studio/33.0.1/frontend/obs-main.cpp
- `OBSApp.cpp` configuration paths and profile directories: https://raw.githubusercontent.com/obsproject/obs-studio/33.0.1/frontend/OBSApp.cpp
- `platform-windows.cpp` Windows system paths: https://raw.githubusercontent.com/obsproject/obs-studio/33.0.1/frontend/utility/platform-windows.cpp
- OBS GPL license: https://raw.githubusercontent.com/obsproject/obs-studio/33.0.1/COPYING
- OBS system requirements: https://obsproject.com/kb/system-requirements
- PortableApps.com Installer current SourceForge archive and hash: https://sourceforge.net/projects/portableapps/files/PortableApps.com%20Installer/PortableApps.comInstaller_3.9.22.paf.exe/download
- PortableApps Format reference: https://portableapps.com/development/portableapps.com_format
- PortableApps official installer documentation: https://portableapps.com/apps/development/portableapps.com_installer
- PAF `installer.ini` values: https://raw.githubusercontent.com/PortableApps/Launcher/master/Other/Source/Manual/ref/paf/installer.rst
- Publisher v1.1.1 exact inputs: https://raw.githubusercontent.com/vhick/portable-release-publisher/v1.1.1/action.yml
- Technique reference only: https://github.com/vhick/FreeCrawl-PortableApps-Builder

The upstream source code is unmodified; only the independent launcher/build scripts are compiled. Do not claim that the reference builder's past successful runs establish Windows compatibility here.

- Microsoft `MessageBoxW` library: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messageboxw (`User32.lib`)
- Microsoft `CommandLineToArgvW` library: https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw (`Shell32.lib`)
- Microsoft `/Zs` syntax-only limitation: https://learn.microsoft.com/en-us/cpp/build/reference/zs-syntax-check-only
- Official OBS launch flags (Windows limitations for `--version` and `--help`): https://obsproject.com/kb/launch-parameters/

- OBS Project confirmed portable-mode Game Capture hook folder and shared-location limitation: https://github.com/obsproject/obs-studio/issues/10486
- OBS Windows install script creates the hook directory: https://github.com/obsproject/obs-studio/blob/master/build-aux/steam/scripts_windows/install.bat
- OBS forum on hook recreation and uninstalling a portable OBS: https://obsproject.com/forum/threads/is-there-anything-special-you-have-to-do-to-uninstall-a-portable-copy-of-obs.183667/
- PortableApps Format 3.9, host modifications and Data retention: https://portableapps.com/development/portableapps.com_format
