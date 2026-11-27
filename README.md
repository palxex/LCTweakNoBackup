# LCTweakNoBackup

A LiveContainer "tweak to self" that keeps LiveContainer's own `Documents`
directory out of iCloud / iTunes backup.

Guest app bundles installed by LiveContainer are re-installable, yet they are
backed up like user data. A single large guest title can push the next iCloud
backup from ~1 GB to over 20 GB, and because that data is attributed to
LiveContainer's container as a whole it never shows up as its own row in the
per-app backup list — so there is no way to opt out from the UI.

This tweak restores the missing switch. No app rebuild required: it is a dylib
that LiveContainer already knows how to load into itself.

## How it works

LiveContainer has a "load tweaks to self" feature:

- `LCBootstrap.m` reads `LCLoadTweaksToSelf`, sets `LC_GLOBAL_TWEAKS_FOLDER`
  to `Documents/Tweaks`, then `dlopen`s `Frameworks/TweakLoader.dylib`.
- `TweakLoader.m` enumerates that folder and `dlopen`s every `.dylib` in it
  (skipping itself and anything ending in `.disabled`).

This library sits in that folder. Its constructor then:

1. Detects the host by `NSClassFromString(@"LCUtils") != nil`. `LCUtils` lives
   in `LiveContainerSwiftUI.framework`, which only exists inside
   LiveContainer's own process — the same discriminator `LCTaskForPIDTweak`
   uses. Injected into a guest app, the tweak stands down immediately.
2. Sets `NSURLIsExcludedFromBackupKey` on `Documents`. The flag is recursive,
   so one syscall covers the whole subtree, and guest apps installed later
   inherit it.
3. Reads the value back and logs it, so the log proves what landed on disk.

`PlugIns/LiveProcess.appex` is skipped explicitly, because its
`NSDocumentDirectory` is a different container.

## Control

| `Documents/turniCloudBackupOnAgain.flag` | Effect |
| --- | --- |
| absent (default) | **backup OFF** — `Documents` is excluded from backup |
| present | **backup ON** — the exclusion is removed |

Create or delete the file, then restart LiveContainer. The flag itself is never
backed up, which is fine: it is a switch, not data.

## Install

1. Build (either works):
   ```sh
   ./build.sh    # plain clang, no Theos needed
   make          # Theos
   ```
2. Copy `LCTweakNoBackup.dylib` into LiveContainer's `Documents/Tweaks/`,
   next to `TweakLoader.dylib`.
3. Sign it from LiveContainer's Tweaks screen (same certificate as the app).
   If JIT is enabled, `init_bypassDyldLibValidation()` lets unsigned dylibs
   load as well.
4. Settings → enable **Load tweaks to self**.
5. Restart LiveContainer and check the log for:
   ```
   [LCTweakNoBackup] host context, turniCloudBackupOnAgain.flag absent -> backup OFF
   [LCTweakNoBackup] OK /var/mobile/.../Documents -> excluded=YES (readback=1)
   ```

## Measured effect

On an iPhone 16 (iOS 27.2.1) with ~24.55 GB of backup-eligible data in
LiveContainer's container:

| | next iCloud backup size |
| --- | --- |
| before | 22.88 GB |
| after | 146 MB |

## Limitations

- Apple documents `isExcludedFromBackup` as *guidance* to the system, "not a
  mechanism to guarantee" those items never appear in a backup. It worked in
  the measurement above, but it is not a contract.
- Because the whole `Documents` directory is excluded, guest app **save data**
  (`Documents/Data/Application`) is not backed up either. Restoring to another
  device gives you an empty LiveContainer. Narrow the target to
  `Documents/Applications` if you want saves kept.
- A backup that has already been uploaded is not shrunk immediately; the next
  completed backup replaces it.
- The dylib must be signed (or JIT enabled), otherwise library validation
  rejects the `dlopen`.

## License

MIT
