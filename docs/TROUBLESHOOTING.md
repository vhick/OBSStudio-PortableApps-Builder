# Troubleshooting

**Workflow missing in Actions:** Commit `.github/workflows/build-portableapps.yml` into the repository default branch. Refresh GitHub's Actions page and enable workflows if asked.

**Upstream download 404 / SHA mismatch:** Check that the selected release has `OBS-Studio-<version>-Windows-x64.zip` and a `sha256` asset digest. The scripts will never silently use unverified mirrors or rename another download.

**VC/RC compiler error:** `windows-2022` includes Visual Studio Build Tools, but runner images can change. Read `Compile genuine Windows C++ launcher` logs. MSVC must compile a real executable, not a script wrapper.

**OBS cannot start:** Check GPU, DirectX, Windows 10/11, Visual C++ runtime and `Data\launcher.log`. Full OBS GUI requires a real interactive desktop; the runner only performs a command-line startup check.

**Stale junction / drive moved:** Launch via the root `OBSStudioPortable.exe`, never `obs64.exe` directly. The launcher removes a stale link after an interrupted run, then creates the link to the current Data path. On normal shutdown the link is removed to protect future upgrades. Before copying/moving a folder, close all OBS processes.

**New files remain under AppData:** The conservative TraceGuard only captures newly created OBS-named *top-level directories* absent at the beginning of this session. It intentionally protects any pre-existing installed OBS data. Third-party plugins with different names require a specific audited storage rule.

**Official PAF not generated:** Inspect `build/official-installer/official-run.log` and `build/official-installer/error.txt` on the runner logs (those files are not uploaded as artifacts). The original vendor tool may reject a staged package or need a GUI; do not use NSIS `/S` to bypass a blocked UI. ZIP remains the supported fallback unless Require official PAF was selected.

**Another OBS instance running:** Exit all instances and try again. This is a protection against profile conflicts, not a launcher failure.

**Publisher refuses release:** The intended tag is `portable-obs-v<OBS-version>-r1`, the repo must allow `contents: write`, and the release must not already exist. v1.1.1's `prune` is disabled, so nothing is automatically deleted.
