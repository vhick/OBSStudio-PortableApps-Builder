# r6: Official PAF recovery from the existing r5 release

## Design

The new workflow `.github/workflows/official-paf-from-r5.yml` is PAF-only. It is deliberately separate from the original `build-portableapps.yml` so the known-working r5 pipeline is not replaced with an unverified full rebuild. The exact source release tag is selected manually through `workflow_dispatch`.

Stages:

1. Check source r5 release exists in the **same builder repository** and has the expected ZIP and `SHA256SUMS.txt` assets.
2. Check destination `portable-obs-v<version>-r6` has no existing GitHub release/tag before heavy download. Skip when already published; fail if tag occupied without release.
3. Download **only** those two r5 assets from the original Release using `gh release download` and `GITHUB_TOKEN`.
4. Verify SHA-256 exactly against the published checksum. Validate the ZIP archive and reject entries outside the `OBSStudioPortable/` root or containing traversal segments.
5. Expand ZIP, ensure the original compiled `OBSStudioPortable.exe`, `obs64.exe`, metadata and data-upgrade protection exist, and refuse packages with nonempty `Data`.
6. Download official `PortableApps.comInstaller_3.9.22.paf.exe` from SourceForge and verify SHA-256 `689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67`.
7. Extract the verified original tool with 7-Zip, discover precisely one `PortableApps.comInstaller.exe`, call its documented command-line interface with the staged application directory, apply a timeout, and capture output. It does **not** launch the setup wizard.
8. Discover a fresh generated PAF in controlled output locations; reject zero or multiple candidates; `7z t` then **extract the generated installer as an archive**, and compare the embedded OBS and portable launcher executables with the original stage by SHA-256. Validate the embedded AppID and Start metadata.
9. Write the package provenance, verify the `.paf.exe` PE header and 7-Zip integrity, and run your shared publisher's dry-run followed by publishing.
10. Confirm the new r6 release contains **only** `OBSStudioPortable_<version>_r6_win64.paf.exe` and `SHA256SUMS.txt`.

**What it does not do:** No fresh OBS download, upstream compilation, C++ launcher rebuild, ZIP recompression, release deletion, GitHub artifact storage, independent NSIS fallback or modification of the r5 GitHub release.

## Troubleshooting

- **Missing source release:** Confirm the exact r5 release tag, ensure the ZIP and `SHA256SUMS.txt` exist, and run this workflow inside the **same** builder repository.
- **Mismatch in ZIP checksum:** Stop. Do not disable verification. Inspect your published release assets; the workflow will not trust a changed ZIP.
- **Could not find PortableApps.comInstaller.exe:** The r6 build log lists executables found in the verified vendor archive. Do not run vendor setup GUI in headless Actions; inspect logs before changing the tool acquisition strategy.
- **Official packager exit error or timeout:** Review the `Produce official PortableApps.com PAF` step. The command line and stderr/stdout are reported; no fake PAF is published. A full log is also saved under `build/official-installer/official-run.log` during the job when the tool returns successfully.
- **Zero or multiple output installers:** Read the printed candidate list. A generated filename need not match the final r6 filename; matching PAF payload is mandatory. Do not simply rename a ZIP.
- **Payload mismatch:** The official output's embedded `obs64.exe` and `OBSStudioPortable.exe` must be byte-for-byte identical (SHA-256) to the verified r5 ZIP. Failure is a packaging error, not a reason to drop the check.
- **Already published r6:** The r6 tag is intentionally skipped to prevent overwriting. Never delete an existing release merely to save a build run. If a new revision is needed later, allocate a new revision instead.

## Installer acceptance checks on your Windows computer

1. Back up `Data` in any existing `OBSStudioPortable` folder.
2. Install r6 `.paf.exe` to an empty PortableApps test directory via PortableApps Platform.
3. Check the Platform menu sees OBS and the root `OBSStudioPortable.exe` starts the real OBS GUI.
4. Create a scene and profile, close OBS, and inspect `Data/OBSConfig`.
5. Reinstall the same PAF into the same *test* installation parent and confirm the scene/profile persist.
6. Move the folder to a different location or drive letter, reopen OBS, and confirm the data persist.
7. Review TraceGuard capture of application-specific external folders and empty directory trees; do not expect it to collect arbitrary unrelated user directories.

This is an independent builder output, not an officially endorsed or certified OBS Project / PortableApps.com release. The official packager's unchanged provenance does not make the resulting product an official PortableApps.com distribution.
