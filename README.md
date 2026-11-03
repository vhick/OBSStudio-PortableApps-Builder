# OBS Studio PortableApps Builder r8.2 — PAF Release-Tag Validation Fix

This is an independent GitHub Actions builder for official OBS Studio Windows x64 packages. The **r8 ZIP workflow already succeeded** and is unchanged. The r8 PAF-only workflow was first blocked by a missing YAML parser (corrected in r8.1), and the next run stopped at `Unexpected release tag`. This r8.2 revision fixes the exact release-tag validation error without downloading or recompiling OBS.

**Use the PAF-only workflow with your existing `portable-obs-v33.0.1-r8` ZIP release.** The new PAF release target stays `portable-obs-v33.0.1-r8-paf`, since the failed run did not reach publishing. Retain the working r7/r8 release assets.

## What r8.2 fixes (PAF-only)

- The release-check script accepted only `portable-obs-v<version>-r<number>` tags. It now accepts that format **and** `portable-obs-v<version>-r<number>-paf` while rejecting extra suffixes, slashes and other unsafe patterns.
- The same release checker protects against an existing release or an orphaned Git tag; it still **does not overwrite existing tags**.
- A no-network PowerShell self-test runs on Windows **before** the release lookup, so this validation mistake will be caught quickly on future runs.
- The existing Python regression test now checks the script's real tag pattern and both ZIP and PAF tag cases.
- The PAF-only workflow continues to reuse the original r8 ZIP, with the r8 launcher and `%PROGRAMDATA%\obs-studio-hook` protection intact. The ZIP workflow, installer logic, source checksums and Universal Release Publisher v1.1.1 are unchanged.


## What r8.1 fixes (PAF-only)

- The uploaded November 3, 2026 PAF-only Actions log stopped at `Run PAF-only static regression checks` with `ModuleNotFoundError: No module named 'yaml'` on a clean `windows-2022` runner.
- The PAF-only workflow now installs **PyYAML 6.0.3** from a binary wheel and confirms its import **before** running `tests/paf-only-static.py`. The test also checks this prerequisite is present and correctly ordered.
- Everything else is unchanged: the successful r8 ZIP workflow, OBS binaries, launcher with ProgramData hook capture, original r8 ZIP release tag, separate `r8-paf` release tag, official packager and release publisher.
- The PAF-only workflow downloads the already published r8 ZIP only **after** cheap tests and preflight; it does **not** recompile OBS or the launcher. Since the PAF run failed before publishing, reusing the intended `r8-paf` tag is appropriate; if that tag now exists, the workflow's existing release check will protect it.

## What changed in r8

- Source-based fix: OBS can create `%PROGRAMDATA%\obs-studio-hook` for Windows Game Capture even in portable mode (OBS issue #10486). While OBS is running, this folder must remain accessible in ProgramData. See `docs/PROGRAMDATA-HOOK.md`.
- `OBSStudioPortable.exe` now includes `obs-studio-hook` in TraceGuard's before/after directory discovery. If this **top-level directory was absent before launching** portable OBS and appears during the session, the launcher copies its files and *all directory levels, including empty ones*, into `Data\TraceGuard\ProgramData\obs-studio-hook` after OBS fully exits.
- The launcher verifies copied files byte-for-byte, refuses reparse points, checks for concurrent additions, and removes only captured files and now-empty directories. It never recursively deletes an entire ProgramData tree. Copy failures, locks, changed files and permission problems are logged to `Data\launcher.log`. Files already safely copied to Data remain there even if host cleanup is incomplete.
- If `%PROGRAMDATA%\obs-studio-hook` **already existed when the portable launcher started**, it is left untouched. It may belong to an installed OBS copy, Streamlabs, or a previous OBS version. **Do not enable unconditional deletion**.
- No hook DLLs are forcibly restored into ProgramData before the next launch. OBS itself installs the version it requires for Game Capture, and automatically copying a saved DLL from an older OBS version could break game capture. The stored hook copy is for preservation/diagnostics.
- Both the ZIP and official PAF must now contain this updated r8 executable. The PAF-only job reuses the **r8 ZIP**, not the original r5 ZIP that lacks the fix.
- Retains the v1.1.1 Universal Portable Release Publisher, default `prune: 'false'`, source checksums, authentic official PAF packager, compiled launcher and established r7 PAF diagnostics.

## Two workflows — run them in this order

### 1. Build the revised r8 ZIP

**Workflow:** `Build OBS Studio PortableApps r8 (ZIP + optional official PAF)`

Settings:

- `upstream_version`: `latest` (or an exact stable version).
- `build_official_paf`: `false` (default; build ZIP first, saving GitHub Actions minutes).
- `require_official_paf`: `false` (default).

On success, your **builder** repository's GitHub Releases will contain, for OBS 33.0.1 as an example:

- Tag: `portable-obs-v33.0.1-r8`
- ZIP asset: `OBSStudioPortable_33.0.1_r8_win64.zip`
- `SHA256SUMS.txt`

This step downloads OBS once, compiles the launcher with the authentic OBS icon, and tests the storage and isolated hook fixture without opening the OBS GUI. If you intentionally set `build_official_paf=true`, it additionally tries an official PAF in the same release, but the default two-workflow route is recommended.

### 2. Package the same r8 ZIP as an official PAF

**Workflow:** `Official OBS PAF r8 from existing r8 ZIP (no OBS rebuild)`

Set `source_release_tag` to the tag created by step 1 (for example `portable-obs-v33.0.1-r8`). This job downloads the validated r8 ZIP and checksum, verifies the launcher and upstream OBS executable, tests the authentic headless PortableApps.com Installer with a small disposable app, and builds the OBS installer. It does **not** rebuild OBS or its launcher.

Successful output, for example:

- Tag: `portable-obs-v33.0.1-r8-paf` — intentionally separate to avoid colliding with the ZIP release.
- `OBSStudioPortable_33.0.1_r8_win64.paf.exe`
- `SHA256SUMS.txt`

The official PAF can only be claimed when the vendor tool compiles it and the payload and checksums actually pass validation. Neither output is included in this source-only builder ZIP.

## GitHub Desktop update: step by step

1. **Keep the successful r7 release and a backup of `OBSStudioPortable\Data`.** Close OBS and any running games before upgrading.
2. Download this r8.2 builder kit and extract it.
3. Open the existing independent `OBSStudio-PortableApps-Builder` repository in GitHub Desktop.
4. Select **Repository → Show in Explorer**.
5. Copy everything **inside** the extracted `OBSStudio-PortableApps-Builder-r8.2` folder into the repository root, including `.github`. Replace matching files; **never remove `.git`**.
6. The PAF workflow keeps its existing filename `.github/workflows/official-paf-from-r5.yml` solely so the new r8 contents **overwrite** the old r7 workflow during this copy. Its visible name is now the r8 workflow. If you previously manually created any other PAF workflow files, disable or delete obsolete duplicates.
7. Files `scripts/restore-r5-stage.ps1` and `scripts/build-official-paf-r5.ps1` from older kits, if present, are not referenced by either r8 workflow. They can be deleted after you confirm the changes, but they do not prevent an r8 build.
8. Return to GitHub Desktop and commit `Accept r8-paf release tags - r8.2`. Click **Push origin**.
9. **Do not run the ZIP workflow again:** your r8 ZIP already exists and the successful application files are unchanged.
10. On GitHub choose **Actions → Official OBS PAF r8 from existing r8 ZIP (no OBS rebuild)** and use `source_release_tag=portable-obs-v33.0.1-r8` (or the exact tag of your successful ZIP release).
11. Download the ZIP and PAF from their corresponding **Releases**. Test both in a **separate** PortableApps folder before upgrading your working installation.

## Install the resulting packages

**ZIP**: Extract the `OBSStudioPortable` folder into `X:\PortableApps\`. The launcher must be at `X:\PortableApps\OBSStudioPortable\OBSStudioPortable.exe`. Refresh the PortableApps menu if needed. Do not nest two `OBSStudioPortable` directories.

**Official PAF**: In PortableApps Platform choose **Apps → Install a New App**, select the `.paf.exe` from the r8-paf release, then choose your PortableApps parent folder. Verify the app and launcher first on a throwaway install.

**Upgrade from r7**: Close OBS and all applications using Game Capture. Back up the complete `Data` folder. For a manual ZIP upgrade, replace the root launcher, `App` and `Other` from the r8 ZIP, **never overwrite or delete existing Data**. For a PAF upgrade, test the official installer's data preservation separately before upgrading your working directory. The PortableApps.com Format preserves Data by default.

## Important: an existing r7 `obs-studio-hook` folder

The folder left behind by r7 **already exists before the first r8 launch**. It may be shared, so r8 does not silently claim or remove it. The new automatic capture applies when the folder is created **during** an r8 portable session. See `docs/PROGRAMDATA-HOOK.md` for a cautious one-time migration method and how to distinguish an active shared hook from a stale leftover.

If a game's hook DLL is in use or the directory has protected permissions, a copy may succeed but deletion may be deferred. The launcher does not elevate privileges, terminate games or force-delete DLLs. This is an upstream Game Capture limitation rather than a packaging error.

## Implementation / evidence limits

- Upstream OBS ZIP is downloaded from the official release with source digest verification; OBS itself is not recompiled. The Windows launcher is native MSVC C++ and uses `--portable` with a Data-backed configuration junction/copy fallback.
- Headless Windows tests verify hook files, an empty directory tree, an entirely empty hook directory, and preservation of a pre-existing host hook using **private test paths only**. Recording, virtual camera, audio, plugins and real Game Capture must be tested manually on Windows.
- Static project/YAML checks and ZIP archive validation run in the artifact-creation environment. **The user reported a successful r8 ZIP Actions run. This source-only kit does not independently establish installer success.** Do not claim the PAF was published or tested just because its workflow is included.
- Official references and constraints: `docs/PROGRAMDATA-HOOK.md`, `docs/SOURCE-AUDIT.md`, `docs/VALIDATION.md`, `docs/WINDOWS-ACCEPTANCE.md`, `docs/REFERENCES.md`.

Not an official OBS Project or PortableApps.com release. Respect OBS's GPL and included dependencies; do not imply official certification or guaranteed antivirus behavior.
