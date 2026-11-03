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
