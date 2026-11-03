# Troubleshooting

**OBS extraction fails with “Missing OBS plugin directory”:** This was fixed in r3 by version-aware `core` (OBS 33+) and `obs-plugins` (OBS <=32) checks. It does not create fake directories. If a newer upstream changes the layout again, inspect the upstream structure and update the verifier.

**Release check fails at HTTP status:** The r5 workflow uses a token-authenticated GitHub REST API request. A missing release returns 404 (expected) and an existing release returns 200 (skip). Unexpected statuses fail rather than skipping incorrectly. If a Git tag exists without a release, revision must change to avoid overwriting it. Do not fall back to `gh release view` with a naive error catch.

**Workflow missing in Actions:** Commit `.github/workflows/build-portableapps.yml` into the repository default branch. Refresh GitHub's Actions page and enable workflows if asked.

**Upstream download 404 / SHA mismatch:** Check that the selected release has `OBS-Studio-<version>-Windows-x64.zip` and a `sha256` asset digest. The scripts will never silently use unverified mirrors or rename another download.

**VC/RC compiler error:** `windows-2022` includes Visual Studio Build Tools, but runner images can change. Read `Compile genuine Windows C++ launcher` logs. MSVC must compile a real executable, not a script wrapper.

**OBS cannot start:** Check GPU, DirectX, Windows 10/11, Visual C++ runtime and `Data\launcher.log`. Full OBS GUI requires a real interactive desktop; the runner only performs a command-line startup check.

**Stale junction / drive moved:** Launch via the root `OBSStudioPortable.exe`, never `obs64.exe` directly. The launcher removes a stale link after an interrupted run, then creates the link to the current Data path. On normal shutdown the link is removed to protect future upgrades. Before copying/moving a folder, close all OBS processes.

**New files remain under AppData:** The conservative TraceGuard only captures newly created OBS-named *top-level directories* absent at the beginning of this session. It intentionally protects any pre-existing installed OBS data. Third-party plugins with different names require a specific audited storage rule.

**Official PAF not generated:** Inspect `build/official-installer/official-run.log` and `build/official-installer/error.txt` on the runner logs (those files are not uploaded as artifacts). The original vendor tool may reject a staged package or need a GUI; do not use NSIS `/S` to bypass a blocked UI. ZIP remains the supported fallback unless Require official PAF was selected.

**Another OBS instance running:** Exit all instances and try again. This is a protection against profile conflicts, not a launcher failure.

**Publisher refuses release:** The intended tag is `portable-obs-v<OBS-version>-r5`, the repo must allow `contents: write`, and the release must not already exist. v1.1.1's `prune` is disabled, so nothing is automatically deleted.

**r3 MSVC C2065 REPARSE_DATA_BUFFER error:** r4 replaces the Windows Driver Kit-only type with a local buffer matching Microsoft's documented mount-point format. The new `MSVC launcher preflight` step catches C++ type errors before OBS download. If the r4 preflight reports a new compiler error, include that step's text with your report; do not install a third-party Windows Driver Kit or disable antivirus.

**r4 linker errors LNK2019 (`MessageBoxW`, `CommandLineToArgvW`):** r5 links `User32.lib` and `Shell32.lib` in both compiler invocation paths. The early preflight now compiles **and links** an actual executable before OBS is downloaded; `/Zs` alone cannot catch this error.

**Windows OBS `--version` / `--help`:** OBS's official launch parameter documentation explicitly says these options are unavailable on Windows. r5 runs `--storage-selftest` in CI instead. This does not prove OBS's real GUI runs; complete the manual acceptance checklist on a normal Windows desktop.
