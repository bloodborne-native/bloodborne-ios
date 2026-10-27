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
  game, with the recompiler in `runtime/recomp/`), on its `ios-poc` branch for now.
- `launcher/`: [bloodborne-launcher](https://github.com/bloodborne-native/bloodborne-launcher), to
  become the app's interface.

What runs where, the measurements and what the iPhone does not allow: the runtime's
[`docs/IOS_POC.md`](https://github.com/bloodborne-native/bloodborne-runtime/blob/ios-poc/docs/IOS_POC.md).
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

The app's `Documents` (Finder's Files tab) holds `game/` (the dump), `boot-linked.bin` and
`content.bin` from the Mac build's `runtime/out/`, `patches.bin` written by
`runtime/scripts/patches.py` for the phone's resolution, and the saves (`mac-save/` for a copy of
the Mac's, `user/` for the phone's own).

## License

GPL-2.0-or-later, as the runtime.
