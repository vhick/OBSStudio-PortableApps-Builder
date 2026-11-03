# r8 official PAF-only pipeline

This build must be performed AFTER the r8 ZIP release publishes. It downloads only the existing r8 ZIP and SHA256SUMS.txt, verifies both, and runs the official PortableApps.com Installer 3.9.22 without GUI automation. This is the r7-tested technique adapted to the new compiled r8 launcher. A PAF built from r5 or r7 binaries would not contain the ProgramData hook fix and is explicitly rejected.

Run Actions -> **Official OBS PAF r8 from existing r8 ZIP (no OBS rebuild)**. Set `source_release_tag=portable-obs-v33.0.1-r8` if that is the published ZIP tag (otherwise use the actual stable version). The source asset is `OBSStudioPortable_<version>_r8_win64.zip`. The output goes under a separate tag `portable-obs-v<version>-r8-paf` and is `OBSStudioPortable_<version>_r8_win64.paf.exe`, alongside SHA256SUMS.txt. This prevents collision with the already existing r8 ZIP release.

The project keeps `.github/workflows/official-paf-from-r5.yml` as the filename for reliable GitHub Desktop overwrite of the old workflow. Its title and behavior now refer only to r8, and its source acceptance check is strict. As with r7, the vendor CLI probe, time-bounded compression monitor, PE validation, archive integrity and packaged OBS + launcher byte comparisons are mandatory. The user must separately test installing/upgrading an official PAF on a disposable PortableApps directory.

## r8.1: Python validation dependency fix (November 3, 2026)

The uploaded r8 PAF-only Actions logs show the checkout succeeded but `python ./tests/paf-only-static.py` failed immediately with `ModuleNotFoundError: No module named 'yaml'`. The workflow now installs the published PyYAML 6.0.3 wheel, verifies the imported package version, and only then runs the YAML/static validations. It makes no changes to OBS application files, compiled launcher, staging, existing source ZIP, official installer, PAF filenames, or release publisher. Run this updated PAF-only workflow again using the **existing r8 ZIP release**, not a new full build. The PAF installer still requires a successful live Windows run.

## r8.2: PAF release-tag acceptance fix (November 3, 2026)

The r8.1 PAF-only run successfully installed PyYAML, passed the static checks,
resolved the source r8 ZIP asset and stopped at `Check target r8-paf tag` with
`Unexpected release tag`. The shared release checker incorrectly permitted only
`portable-obs-v<version>-r<number>` and rejected the distinct valid PAF tag
`portable-obs-v<version>-r<number>-paf`. r8.2 fixes the anchored pattern, adds a
native PowerShell no-network self-test before API calls, and updates Python
static checks to test both legitimate formats and invalid suffixes.

The PAF tag remains `portable-obs-v33.0.1-r8-paf`; no new OBS ZIP is needed.
No Windows packaging success is claimed until Actions finishes the PAF run.
