# OBS Game Capture graphics hook in ProgramData — r8 design and operating guide

## Confirmed origin

`%PROGRAMDATA%\obs-studio-hook` is **not** ordinary OBS profile data. OBS Project members confirmed in upstream issue https://github.com/obsproject/obs-studio/issues/10486 that portable OBS may install a Game Capture graphics hook under ProgramData, and that Game Capture expects it there. They warned against changing that live dependency. OBS forum discussions (https://obsproject.com/forum/threads/is-there-anything-special-you-have-to-do-to-uninstall-a-portable-copy-of-obs.183667/) also report that OBS can recreate the directory when Game Capture is used.

## r8 runtime lifecycle

1. The launcher snapshots top-level folder names beneath `%PROGRAMDATA%` and other known user roots **before** launching OBS. Existing directories and files are marked as host-owned.
2. OBS runs with `--portable` and may create a graphics-hook folder at `%PROGRAMDATA%\obs-studio-hook`. The launcher does not redirect that folder during a recording. Doing so could break Game Capture.
3. The launcher waits for the OBS process to finish, plus its existing bounded detached-OBS process check.
4. If `obs-studio-hook` did **not** exist in the pre-launch snapshot but exists at shutdown, TraceGuard checks that it is a regular directory, not a Windows junction/symlink, then copies it to `Data\TraceGuard\ProgramData\obs-studio-hook`. Empty directories and empty nested directory trees are recreated. Files are checked byte-for-byte.
5. Existing Data conflicts are backed up under `Data\RecoveryConflicts`; no existing portable user data is silently overwritten without backup.
6. After checking original files and their saved copies, the launcher deletes individual verified original files and attempts to remove directories only when they are empty. It **does not recursively remove a ProgramData folder**, and it refuses to clean up if other entries appear while copying.
7. If a file is locked by a game or OBS child process, the copy may be saved but the external folder can remain. Inspect `Data\launcher.log` and `Data\TraceGuard\relocation-manifest.tsv`. Do not force-delete in-use DLLs.
8. On the next run, OBS supplies the current hook DLL version itself as required for Game Capture. The launcher does not blindly reinstall an older copied DLL back into a shared host directory.

## What happens to a hook already left by r7?

**It is not automatically moved or deleted.** The folder existed before the r8 snapshot, so ownership cannot be established solely from its name. In particular, OBS installed normally and other OBS-based software may share this location. This is a deliberate safety requirement.

For a one-time manual cleanup **only if you are confident it belongs solely to the portable OBS**:

1. Close portable and installed OBS, other OBS-based recording software, and any games that could have loaded the hook DLLs. Do not disable antivirus or run unknown administrator scripts.
2. Open File Explorer and inspect `%PROGRAMDATA%\obs-studio-hook`. Determine whether another OBS installation, Streamlabs installation or similar software depends on these files. If in doubt, leave the directory alone.
3. Back up the directory to a safe location (for example a dated folder inside `OBSStudioPortable\Data\ManualBackup`) without changing any permissions or deleting the original.
4. If you have confirmed there is no other user of the hook, move the original folder aside **using File Explorer** (for example to a clearly named backup path), rather than deleting it. If Windows reports files in use or denies access, stop and leave it alone.
5. Launch your revised r8 **ZIP** and exercise OBS Game Capture, then close OBS and the game. On successful cleanup, the *new* `obs-studio-hook` created during that session is preserved at `Data\TraceGuard\ProgramData\obs-studio-hook` and removed from ProgramData.
6. If an external folder remains, read `Data\launcher.log` before taking any further action. Leave the backup available until the next Game Capture launch works.

Do **not** manually restore a saved older hook DLL into ProgramData for an updated OBS release. Game Capture hook version mismatches can cause capture problems.

## Limitations

- A shared, pre-existing hook is never claimed automatically; ownership cannot safely be inferred from a folder name.
- A running game may retain hook DLL handles beyond OBS's lifetime; Windows may refuse deletion until the game exits or the computer restarts.
- ProgramData permissions vary. This non-elevated launcher does not request administrator access to force cleanup.
- A crash may interrupt relocation. Saved files are kept, but an ambiguous leftover directory will be treated as pre-existing on the next launch, not force-deleted.
- The launcher does not promise that unrelated processes can never modify a newly created directory. It rechecks contents and avoids recursive deletion to reduce this risk.
- This mechanism does not silently move existing recordings, user-selected output paths, arbitrary third-party plugins or non-OBS-named directories.

## Testing

On GitHub Actions Windows, `--programdata-hook-selftest` redirects **only its own process's** `PROGRAMDATA` environment variable to a disposable folder under `Data\_ProgramDataHookSelfTest`. It deliberately creates a hook file, nested file, empty nested directories, and an empty hook root, and confirms a pre-existing host-owned hook fixture remains unchanged. The real `C:\ProgramData` is not used for this fixture. The launcher source contains no admin escalation, process injection or forced game termination.

Real-world Windows Game Capture with a full installed OBS copy is **manual acceptance**, not a CI test or a certified compatibility guarantee.
