# r7 official PAF recovery from existing r5 ZIP

## Confirmed observed failure

- GitHub Actions log: `logs_112662529404.zip` (supplied by user).
- Existing ZIP `OBSStudioPortable_33.0.1_r5_win64.zip` SHA-256: `88b9bd9a20c73d003ce48da640db1ef882a9d1fc7c3b0e146803d85255d021c5`.
- Existing ZIP: 236,247,069 bytes; 2,305 file entries extracted. The successful r5 ZIP is not rebuilt.
- Official tool: PortableApps.com Installer 3.9.22, downloaded from SourceForge, SHA-256 checked against `689456f1fb1320c45e82a077afe6b87fb388fd3f75c41d9ee9ce8d45f3966b67`.
- r6 vendor compiler launched with the stage directory, and did not exit by 420 seconds; no CLI output was captured.

No evidence yet distinguishes a Windows GUI prompt from lengthy LZMA compression. Do not claim the vendor tool or the package is corrupt.

## What to expect from the r7 run

- The **probe** runs before the large ZIP download. Success confirms that the CLI can compile one well-formed tiny package without user interaction; it cannot guarantee full-sized OBS compression will finish.
- For the full PAF, `Official PAF status` heartbeats show elapsed time, idle time, accumulated CPU seconds and process IDs/window titles. CPU and child-process activity prolong the build up to 1080 seconds; 180 seconds without activity is treated as a possible modal dialog or deadlock.
- A failed package build is not published. The action stops and retains the diagnostic output in the failing job log; it does not upload CI artifacts or disable antivirus.
- Successful completion is followed by `7z t`, extraction and SHA-256 comparison of embedded `OBSStudioPortable.exe` and `obs64.exe` against the validated r5 ZIP.
- The PAF release tag changes to `portable-obs-v<version>-r7` but the packaged application remains r5 revision, as intended. Do not mix application revision with installer packaging revision.

## Manual acceptance after a successful official PAF

Use a disposable PortableApps root to install twice and confirm `Data` is retained. Then move the installed `OBSStudioPortable` directory to another parent/drive, launch again, and verify scenes, settings and no unwanted host data cleanup. Keep a backup of all real `Data` before upgrading.

## Known limits

The vendor program is GUI-capable; command-line packaging is documented, but the current Windows runner behavior for OBS is not yet verified. We do not fabricate a successful installer, auto-accept prompts, add an independent NSIS fallback, or call generic `/S /D` installer switches in CI.

## Metadata normalization (packaging only)

PortableApps Format 3.9 documents 16/32/75/128/256 icon PNGs and a `help.html` file at the root. The r5 ZIP lacked the 75/256 sizes and had only help.txt. The r7 workflow adds these to its **temporary extracted stage** using the upstream OBS icon. The specification's version history also says `RemoveDataDirectory` was removed; Data is preserved by default. r7 removes that obsolete key for its produced PAF, but leaves the original r5 GitHub Release, source ZIP, compiled launcher and OBS executable untouched. This may avoid a packaging validation popup, but no live vendor packaging result is claimed until Windows CI passes.
