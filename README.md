# OBS Studio PortableApps Builder — r7 (official PAF CLI / compression diagnosis)

**Use the dedicated PAF-only r7 workflow, not the original r5 full build.** This revision reuses the existing successful r5 release ZIP and never recompiles OBS, recompiles the launcher, or modifies the r5 release.

## What the latest real GitHub Actions failure proves

The failed r6 PAF-only run on November 3, 2026 downloaded the existing **226 MiB** r5 ZIP, verified SHA-256, and restored the exact 2,305 application files. It also downloaded, verified, and extracted authentic PortableApps.com Installer **3.9.22**. The vendor packager executable did not exit before r6's 420-second deadline. This does **not** establish whether the program was still compressing or waiting for interactive input. No .paf.exe was published.

## r7 corrections

1. A disposable small-package **official vendor CLI preflight** is performed before downloading the large OBS r5 ZIP. It does not launch/install the probe PAF and deletes it after testing. This can detect a non-headless packager *before* using 226 MiB network traffic.
2. The PAF-only stage repairs the existing r5 **packaging metadata** (missing 75/256 icons, help.html and an obsolete installer option) while preserving the OBS/launcher bytes and original r5 Release. This targets documented Format 3.9 requirements and may prevent an interactive metadata warning.
3. The real OBS PAF build uses the same **unmodified, checksum-pinned official tool**. Its maximum execution allowance is increased to 18 minutes only while the tool or its children show CPU or process-tree activity. An idle process is terminated after 180 seconds, without simulating GUI clicks or opening a PAF installer wizard.
4. The packager reports process IDs, CPU use and visible window titles, and writes its stdout/stderr or failure reason to an internal log. Failed jobs stop before publication. This helps distinguish a stuck dialog from lengthy LZMA compression.
5. The source ZIP and release SHA-256 continue to be verified; generated PAF payloads are checked against the original portable launcher and OBS executable. The r7 PAF will be published through `vhick/portable-release-publisher@v1.1.1` with automatic pruning disabled.
6. The successful r5 release is left unchanged. r6 was unsuccessful; r7 uses a new tag to avoid collisions.

**Important:** This is a targeted robustness and diagnosis fix, *not proof* that the official tool can create the large OBS PAF on the GitHub runner. If the vendor's compiler requires a GUI dialog despite valid metadata, r7 will fail clearly rather than manufacture an installer. No independently created NSIS installer is relabeled as official.

## Install the updated builder with GitHub Desktop

1. Download and extract `OBSStudio-PortableApps-Builder-r7-OfficialPAF-MonitorFix.zip`.
2. In GitHub Desktop, select your existing `OBSStudio-PortableApps-Builder` repository → **Repository → Show in Explorer**.
3. Copy **everything inside the extracted r7 directory** into your existing builder repository, including the hidden `.github` directory. Replace the old files, but **do not touch `.git`**.
4. Commit with `PAF-only official compiler probe and compression monitor - r7` and select **Push origin**.
5. On GitHub, open **Actions → Official OBS PAF r7 from existing r5 ZIP (no OBS rebuild)**, then **Run workflow**.
6. Leave `source_release_tag=portable-obs-v33.0.1-r5` (or the exact version-specific successful r5 release).
7. Watch **Probe official packager CLI with a tiny disposable package**. If it fails, read its diagnostic log; do **not** rerun blindly. If it passes, the job downloads the existing r5 ZIP and compiles the real PAF.
8. On success, download `OBSStudioPortable_33.0.1_r7_win64.paf.exe` and `SHA256SUMS.txt` from the new `portable-obs-v33.0.1-r7` Release. Your large r5 ZIP remains in the existing r5 Release.
9. Before using the PAF for an upgrade, test it in a **separate** PortableApps folder: installation, launch, saving scenes/config, data preservation on reinstall, and moving the folder.

**Safety:** Never install an untested PAF over production `Data`. The workflow does not publish any PAF unless real official compiler output passes PE, 7-Zip, original binary hash, appinfo and installer metadata checks. All Windows execution and installer creation are still pending for r7.

See `docs/PAF-RECOVERY-r7.md` for the specific CI diagnostics and `docs/WINDOWS-ACCEPTANCE.md` for the user acceptance tests. The original r5 full-build workflow still invokes a frozen copy of its working PAF script (`scripts/build-official-paf-r5.ps1`); the new r7 PAF-only workflow uses separate monitored packaging logic.

---

## Original r5 builder documentation (preserved)

# OBS Studio PortableApps Builder — r5

An independent, GitHub Actions-driven builder for **OBS Studio Windows x64**.
No upstream fork, no manually downloaded binaries, no custom Git tokens and no Actions artifacts. Uses the official OBS binary distribution, compiled C++ launcher, OBS native portable mode, and your Universal Portable Release Publisher v1.1.1.

> **Build status:** Project files and static tests are supplied, but this r5 has **not** been run on a Windows GitHub Actions runner at delivery time. Do not interpret an unexecuted workflow or an unbuilt PAF as a successful build. See [validation evidence](docs/VALIDATION.md).

## r5 fixes: missing Windows linker libraries and unsupported CI command

The uploaded November 3, 2026 **r4** Windows Actions log shows that release
resolution, publisher checks, module layout regression tests, early MSVC
source compilation, and OBS 33.0.1 checksum verification/extraction **passed**.
The native launcher compile then failed with **LNK2019** for `MessageBoxW` and
`CommandLineToArgvW`, because their Win32 import libraries were not linked.

r5 explicitly links **User32.lib** and **Shell32.lib** in both full MSVC build
paths. Its early preflight now performs a **real compile + link + PE validation**
(without the upstream OBS icon, which is applied later) before downloading
223.8 MB of OBS binaries. This catches missing linker libraries and other
link-time errors upfront instead of relying on the syntax-only `/Zs` test.

Also, the official OBS documentation states that `--version`/`--help` are not
available on Windows. r5 replaces CI's unsupported `--version` smoke check
with native `--storage-selftest`, testing junction or copy-back storage,
empty folders, Data persistence, relocation, and unrelated host-data protection
without opening OBS's GUI. **Full OBS GUI startup still requires a manual
interactive Windows test.**

Neither native Windows compilation nor a full end-to-end r5 Actions build has
been executed here. Preserve your previous working OBS builder until r5 passes.

## r4 fix: Windows SDK/MSVC launcher compilation

The November 3, 2026 r3 live Windows Actions log confirms that stable release
resolution, publisher checks, OBS 33 module-layout tests and the verified 214 MiB
OBS ZIP download all passed. The next step failed with MSVC C2065 because
`REPARSE_DATA_BUFFER` is declared in the Windows Driver Kit (`ntifs.h`), not in the
normal user-mode Windows SDK used by Visual Studio on GitHub-hosted runners.

r4 replaces the WDK-only type with a small local mount-point buffer having
compile-time checks of the Microsoft-documented 8-byte header and 16-byte
path-buffer offset. It retains normal Win32 `DeviceIoControl` junction creation,
without WDK, elevation or externally launched `mklink`. `scripts/preflight-launcher.ps1`
used MSVC `/Zs` in r4; r5 upgrades it to full compile-and-link **before**
the large OBS download, catching both source and linker errors early. Successful full compilation,
Windows runtime tests, PAF generation and publication still await a live run.

## r3 fix: OBS 33 plugin folder detection

The r2 GitHub Actions log from November 3, 2026 proves OBS Studio 33.0.1's
official ZIP passed checksum and `7z t`, and extracted 2,290 files. The build
then failed at `Missing OBS plugin directory`: r2 incorrectly required the old
`obs-plugins` folder, which OBS 33 replaced with `core` for bundled modules.

r3 checks `core` and its DLL modules for OBS 33 or newer, and `obs-plugins` and
its DLL modules for OBS 32 and earlier. It provides a new Windows regression
fixture before downloading the large OBS ZIP, and reports available top-level
folders if the version-specific expectation fails. It does not alter or
invent upstream modules, and it retains r2's verified release-check fix.

**Live build status:** r4 reached the linker, then failed. This r5 correction
is statically checked here; its full Windows build, launcher runtime, and
headless official PAF generation remain unverified.

## Outputs (created by GitHub Actions, not included in this builder kit)

- `OBSStudioPortable_<upstream>_r5_win64.zip` — ready-to-extract PortableApps tree with `OBSStudioPortable.exe` at the root.
- `OBSStudioPortable_<upstream>_r5_win64.paf.exe` — **only if** original, verified, unmodified PortableApps.com Installer v3.9.22 generates an authentic, validated installer in fully unattended mode.
- `SHA256SUMS.txt` — generated and uploaded automatically by your Universal Portable Release Publisher v1.1.1 alongside the ZIP and any official PAF. The local build also writes `build/SHA256SUMS.txt`.

**ZIP always comes first.** Official PAF is attempted by default. If the official tool cannot run headlessly, the workflow can publish a valid ZIP only. To fail instead, check **Require official PAF** on the workflow form. No generic NSIS program will be mislabeled official.

## PortableApps folder structure

```text
OBSStudioPortable/
  OBSStudioPortable.exe              [genuine native Windows executable]
  App/
    OBSStudio/                       [entire verified upstream OBS release]
      bin/64bit/obs64.exe
      data/obs-studio/
      core/                          [OBS 33+ built-in modules]
      plugins/                       [optional OBS 33+ third-party plugins]
      config/                        [junction to Data on NTFS, dynamically created]
    AppInfo/
      appinfo.ini
      installer.ini
      appicon.ico                     [icon extracted from official OBS binary]
      appicon_16.png
      appicon_32.png
      Launcher/OBSStudioPortable.ini  [documentation; custom C++ EXE used]
    DefaultData/
  Data/
    OBSConfig/                       [OBS portable profile, scenes, browser plugin data]
    TraceGuard/                      [new OBS-owned host roots and empty directories]
    RecoveryConflicts/               [verified non-destructive profile merge backups]
    launcher.log
  Other/Source/                      [launcher source, provenance, licenses]
  help.txt
```

## Step-by-step setup in GitHub Desktop

1. Open **GitHub Desktop**. Choose **File → New repository**.
2. Name it **OBSStudio-PortableApps-Builder** and choose your local destination. This is **not** a fork of `obsproject/obs-studio`.
3. Choose **Repository → Show in Explorer**.
4. Extract the downloaded builder kit ZIP. Copy **the contents inside** the `OBSStudio-PortableApps-Builder-r5` folder into the new repository's top-level folder. Keep the hidden `.github` folder. Do not remove the `.git` folder GitHub Desktop created.
5. In GitHub Desktop, check the changed files; enter the commit summary `OBS PortableApps Builder r5 - MSVC Link Fix` and click **Commit to main**.
6. Click **Publish repository**. Choose the Public/Private checkbox based on your intended visibility; the workflow never changes it.
7. Open your new repository in a browser. Select **Actions**. If prompted, select **Enable workflows**.
8. Open **Build OBS Studio PortableApps (verified ZIP + optional official PAF)** → **Run workflow**. Keep **upstream_version = latest** and **require_official_paf = false** for the first run.
9. Observe each job step. If it succeeds, open **Releases** in **your new builder repository**. The published release is called `portable-obs-v<upstream version>-r5`. Download the validated ZIP, and the official PAF if generated.
10. A repeat run for an existing matching release is skipped before the large OBS download. For a new upstream version, manually run again. No schedules are configured.

## Install the portable app

**ZIP:** Extract **OBSStudioPortable** into `X:\PortableApps\` so the executable is `X:\PortableApps\OBSStudioPortable\OBSStudioPortable.exe`. Do **not** place it in `X:\PortableApps\OBSStudioPortable\OBSStudioPortable\`. Open PortableApps Platform and refresh the menu. Launch **OBS Studio Portable**.

**Official PAF (if produced):** In PortableApps Platform choose **Apps → Install a New App**, select the PAF, and choose the **parent** `X:\PortableApps` if asked. The official tool should place OBSStudioPortable inside it.

**Upgrades:** Exit OBS fully. Back up `OBSStudioPortable\Data`. For a ZIP update replace `OBSStudioPortable.exe`, `App`, and `Other` only; never delete or overwrite `Data`. For official PAF, install into the existing parent directory: `installer.ini` explicitly has `RemoveDataDirectory=false`. Verify user data after reinstalling.

## How portable storage and recovery work

1. **Before launch** the compiled launcher locks this portable folder against a second instance and checks for other running OBS processes.
2. It uses `--portable --disable-updater`, creates `Data\OBSConfig`, and on NTFS creates a normal Windows **directory junction** so OBS's `App\OBSStudio\config` points directly into `Data`. No administrator privileges are requested.
3. If junctions are unavailable (e.g., FAT filesystem), the launcher uses verified copy-back and recovers left-behind physical `App\OBSStudio\config` files after an interrupted previous launch. Conflicting `Data` copies are backed up.
4. The launcher snapshots OBS-named top-level directories under AppData, LocalAppData, ProgramData and TEMP before running; after OBS has exited it preserves newly created matching directory trees into `Data\TraceGuard`, **including folders containing no files**, and records source/destination paths in `Data\TraceGuard\relocation-manifest.tsv`.
5. It does **not** take pre-existing host directories, move a user's recordings, migrate an installed OBS profile, force-stop OBS, modify the registry, or inject anything into Windows processes.
6. After relocating the portable folder, the next start creates the directory junction pointing to the *new* Data path. After normal shutdown it removes the junction, preventing an updater from following it into Data. OBS scene references to absolute external file paths may require separate editing by the user.

**Scope restriction:** No non-elevated, no-injection utility can safely attribute every unknown Windows file created by arbitrary OBS third-party plugins. New, OBS-named **top-level directories** are captured with a before/after comparison; arbitrary filenames elsewhere are not moved. This protects unrelated files. Treat full third-party plugin portability as a separate acceptance test.

## Manual checks after first successful Actions release

See [Windows acceptance checklist](docs/WINDOWS-ACCEPTANCE.md) and [troubleshooting](docs/TROUBLESHOOTING.md). The headless runner tests the compiled launcher storage lifecycle without launching OBS GUI but does not prove that full screen/video/audio capture or official PAF interactive installation works on your computer.

## Licenses and limitations

OBS Studio is GPL-2.0-or-later and redistributable under applicable GPL and bundled-dependency terms. This kit's C++ launcher source is GPL-2.0-or-later. OBS trademarks are their owners' property; this independent builder is not official or certified. PAF packager itself is authentic **only if** the original verified tool produces the archive. Commercial packaging and trademarks may require additional review. The official Windows ZIP may require VC++ runtime and GPU drivers already installed.

See [source audit](docs/SOURCE-AUDIT.md), [validation evidence](docs/VALIDATION.md), and [sources](docs/REFERENCES.md).
