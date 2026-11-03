# OBS Studio PortableApps Builder — r2

An independent, GitHub Actions-driven builder for **OBS Studio Windows x64**.
No upstream fork, no manually downloaded binaries, no custom Git tokens and no Actions artifacts. Uses the official OBS binary distribution, compiled C++ launcher, OBS native portable mode, and your Universal Portable Release Publisher v1.1.1.

> **Build status:** Project files and static tests are supplied, but this r2 has **not** been run on a Windows GitHub Actions runner at delivery time. Do not interpret an unexecuted workflow or an unbuilt PAF as a successful build. See [validation evidence](docs/VALIDATION.md).

## r2 change: early GitHub release check fixed

The initial r1 GitHub Actions log (November 3, 2026) showed stable OBS resolution
succeeded but the next step returned exit code 1 when using `gh release view`.
Because a new release legitimately does not exist yet, r2 uses the GitHub REST API
and explicitly accepts HTTP 404 for an absent release, then checks that the Git tag
itself has not already been claimed. Status 200 means skip; unexpected HTTP statuses
fail clearly. Revision r2 uses a new release tag so it cannot collide with r1.

This fixes the *identified early failure only*. Windows launcher compilation,
OBS launch, official PAF generation, and live publishing still require a new
GitHub Actions run to verify.

## Outputs (created by GitHub Actions, not included in this builder kit)

- `OBSStudioPortable_<upstream>_r2_win64.zip` — ready-to-extract PortableApps tree with `OBSStudioPortable.exe` at the root.
- `OBSStudioPortable_<upstream>_r2_win64.paf.exe` — **only if** original, verified, unmodified PortableApps.com Installer v3.9.22 generates an authentic, validated installer in fully unattended mode.
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
      obs-plugins/
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
4. Extract the downloaded builder kit ZIP. Copy **the contents inside** the `OBSStudio-PortableApps-Builder-r2` folder into the new repository's top-level folder. Keep the hidden `.github` folder. Do not remove the `.git` folder GitHub Desktop created.
5. In GitHub Desktop, check the changed files; enter the commit summary `Initial OBS PortableApps Builder r2` and click **Commit to main**.
6. Click **Publish repository**. Choose the Public/Private checkbox based on your intended visibility; the workflow never changes it.
7. Open your new repository in a browser. Select **Actions**. If prompted, select **Enable workflows**.
8. Open **Build OBS Studio PortableApps (verified ZIP + optional official PAF)** → **Run workflow**. Keep **upstream_version = latest** and **require_official_paf = false** for the first run.
9. Observe each job step. If it succeeds, open **Releases** in **your new builder repository**. The published release is called `portable-obs-v<upstream version>-r2`. Download the validated ZIP, and the official PAF if generated.
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

See [Windows acceptance checklist](docs/WINDOWS-ACCEPTANCE.md) and [troubleshooting](docs/TROUBLESHOOTING.md). The headless runner checks a real OBS `--version` execution but does not prove that full screen/video/audio capture or official PAF interactive installation works on your computer.

## Licenses and limitations

OBS Studio is GPL-2.0-or-later and redistributable under applicable GPL and bundled-dependency terms. This kit's C++ launcher source is GPL-2.0-or-later. OBS trademarks are their owners' property; this independent builder is not official or certified. PAF packager itself is authentic **only if** the original verified tool produces the archive. Commercial packaging and trademarks may require additional review. The official Windows ZIP may require VC++ runtime and GPU drivers already installed.

See [source audit](docs/SOURCE-AUDIT.md), [validation evidence](docs/VALIDATION.md), and [sources](docs/REFERENCES.md).
