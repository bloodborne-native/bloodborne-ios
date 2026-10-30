# bloodborne-ios

Bloodborne (PS4, CUSA03173 1.09) on the iPhone: the iOS app. A proof of concept, private, for
sideloading with your own Apple ID; nothing here is distributed. No game files are included: the
app runs your own dump, and the recompiled library is built on your Mac from your own copy.

Built on [bbport](https://github.com/deadinside28/bloodborne_pc) by deadinside28 and
[shadPS4](https://github.com/shadps4-emu/shadPS4).

## Where things are

- `app/`: the app shell (`app_main.c`, `Info.plist`, the Xcode project).
- `scripts/`: building, signing and installing the app (`build-app.sh`), measuring on the phone
  (`trial.sh`, `press.sh`, `profile.py`) and finding a crash (`bisect.sh`).
- `runtime/`: [bloodborne-runtime](https://github.com/bloodborne-native/bloodborne-runtime) (the
  game, with the recompiler in `runtime/recomp/`), on its `main` (the iOS code behind `TARGET_OS_IPHONE`, merged 2026-10-29).
- `launcher/`: [bloodborne-launcher](https://github.com/bloodborne-native/bloodborne-launcher), to
  become the app's interface.

What runs where, the measurements and what the iPhone does not allow: the runtime's
[`docs/IOS_POC.md`](https://github.com/bloodborne-native/bloodborne-runtime/blob/main/docs/IOS_POC.md).
The plan: bloodborne-mac's [roadmap](https://github.com/bloodborne-native/bloodborne-mac/blob/main/docs/ROADMAP.md),
section 9.

## Build and install

Needs the macOS build of the runtime first (its dependency sources are reused), Xcode, an iPhone
in developer mode and an Apple ID added to Xcode (a free one works; apps are re-signed every 7
days).

```sh
git clone --recursive https://github.com/bloodborne-native/bloodborne-ios.git
cd bloodborne-ios
bash runtime/build.sh                                  # the macOS build (runtime/deps/: ~1 h)
bash runtime/scripts/ios/build-deps.sh                 # runtime/deps/ios-arm64
bash runtime/scripts/ios/recomp.sh                     # runtime/out/ios/librecomp.dylib
BB_IOS_TEAM=<team> BB_IOS_DEVICE=<udid> bash scripts/build-app.sh   # builds, signs, installs
```

One app, in progress: `scripts/build-launcher.sh` (the same variables, `BB_LAUNCHER` for a
launcher checkout with `npm ci` done, `BB_LAUNCHER_CONFIG=debug` for a debug build; release by
default) builds bloodborne-launcher's iOS app with the game inside; its Play starts the game
(`bb_ios_start_game` in `app/app_main.c`, built with `BB_IOS_IN_LAUNCHER`): the launcher's window
is destroyed, the phone turns to landscape behind a black cover, and the game runs from a main
run-loop timer (inside the launcher's main-queue block, iOS delivered it no touches). Its
`Documents` holds the same files, with the launcher's database and `bbport.ini`.

The limit is the address space, not memory. Without the paid entitlements the host gets about
2 GiB below the shared cache, plus the 6 GiB block that holds the game's image and memory pool.
At Play the launcher uses 1.3-1.6 GiB of the 2 GiB (WebKit's JavaScriptCore region is 256 MiB or,
once grown, 512 MiB; the recompiled library 350 MiB) and the game's start needs about 410 MiB more,
including single blocks of 34 MiB (the rasterizer) and 128 MiB (a Metal buffer). The game starts
when WebKit has not grown (largest free gap ~270 MiB at Play, 92 MiB once running) and fails to
allocate when it has. iOS refuses `execve` (Operation not permitted): no smaller program can take
the launcher's place. The recompiled library is loaded when the app loads; placed in the 6 GiB
block it leaves the game's pool no room, or iOS does not map it there at all.

The app's `Documents` (Finder's Files tab) holds `game/` (the dump), `boot-linked.bin` and
`content.bin` from the Mac build's `runtime/out/`, `patches.bin` written by
`runtime/scripts/patches.py` for the phone's resolution, and the saves (`mac-save/` for a copy of
the Mac's, `user/` for the phone's own).

The app's switches (`app/app_main.c`): `BB_IOS_SAVE` (`mac-save` or the phone's own),
`BB_IOS_EVENT_LOG` (SDL logs its events into the log), `BB_IOS_WEBKIT_HEAP` (the launcher build:
WebKit's own allocator instead of the system's), and the
probes `BB_IOS_CPU_ONLY`, `BB_IOS_PROBE_ONLY`, `BB_IOS_METAL_TEST`, `BB_IOS_FILE_TEST`,
`BB_IOS_GUARD_TEST`. devicectl keeps environment variables between launches, so a switch is turned
off with `0`, not by leaving it out.

## License

GPL-2.0-or-later, as the runtime.
