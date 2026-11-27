# LCTweakNoBackup

A LiveContainer "tweak to self" that keeps LiveContainer's own `Documents`
directory out of iCloud / iTunes backup.

Guest app bundles installed by LiveContainer are re-installable, yet they are
backed up like user data. A single large guest title can push the next iCloud
backup from roughly a gigabyte to tens of gigabytes. Because that data is
attributed to LiveContainer's container as a whole, it never shows up as its
own row in the per-app backup list — so there is no way to opt out from the UI.

This tweak restores the missing switch. No app rebuild required: it is a dylib
that LiveContainer already knows how to load into itself.

## Scope — read this first

This tweak excludes **the entire `Documents` directory**, not just the guest
app bundles. So `Documents/Data/Application` — guest app **save data** — is
**not backed up either**. Restoring to another device gives you an empty
LiveContainer: no guest apps, no saves.

That is a deliberate choice, not an oversight. The author's own use case is
"I manage save data myself, I don't want any of it in iCloud".

If you would rather keep save data in the backup, change the target in
`LCTweakNoBackupInit` from `documentsURL` to
`[documentsURL URLByAppendingPathComponent:@"Applications"]`. The guest bundles
are by far the largest part of the container, so that still removes the bulk of
it while keeping saves in the backup.

That narrower variant is also what makes more sense as a *default* inside
LiveContainer itself, since it does not conflict with restoring on another
device — it is what I suggested upstream in
[LiveContainer#820](https://github.com/LiveContainer/LiveContainer/issues/820).

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

## Effect

With this scope the reported next iCloud backup size drops from tens of
gigabytes to well under a gigabyte. The exact figures depend entirely on what
guest apps you have installed.

## Limitations

- Apple documents `isExcludedFromBackup` as *guidance* to the system, "not a
  mechanism to guarantee" those items never appear in a backup. It works in
  practice, but it is not a contract.
- Because the whole `Documents` directory is excluded, guest app **save data**
  (`Documents/Data/Application`) is not backed up either — see
  [Scope](#scope--read-this-first) above.
- A backup that has already been uploaded is not shrunk immediately; the next
  completed backup replaces it.
- The dylib must be signed (or JIT enabled), otherwise library validation
  rejects the `dlopen`.

## License

MIT
