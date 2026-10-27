# bloodborne-ios

The iOS app of Bloodborne (PS4, CUSA03173 1.09): the app shell, its build, signing and install
scripts, and what being an app on the iPhone means (touch controls, files, the launcher as its
interface). Private while it is a proof of concept. The game is the `runtime/` submodule
(bloodborne-runtime, on `ios-poc` for now) with the recompiler in `runtime/recomp/`; the launcher
is `launcher/`.

## Read first

- `README.md`: layout, build and install.
- The runtime's `docs/IOS_POC.md` (branch `ios-poc`): measurements, limits, findings.
- bloodborne-mac's `docs/ARCHITECTURE.md` ("Where code lives") and `docs/ROADMAP.md` section 9.

## Where code goes

- Here: the app shell, its scripts, touch controls' app side, file sharing, the launcher's iOS
  integration.
- In the runtime: anything about running the game on iOS (memory layout, system calls, Metal
  differences, the iOS builds of its libraries in `runtime/scripts/ios/`), and fixes the iPhone
  exposed that are not about the iPhone.
- In the launcher: its interface, one codebase for every platform.

## This machine

- The iPhone: `BB_IOS_DEVICE=<iPhone identifier>`, team `BB_IOS_TEAM=<team id>`.
  Keep it unlocked (Auto-Lock: Never) for test runs; `devicectl` cannot launch on a locked phone.
- `runtime/deps` and `runtime/recomp/out` are links to the bloodborne-mac checkout's (built
  once; `deps` records absolute paths).

## Working rules

- The project's repositories and their rules: bloodborne-mac's `CLAUDE.md` (commits, credits,
  no game code, test titles, docs). They apply here.
- Test runs on the phone: `scripts/trial.sh NAME 'INI' '"ENV":"VALUE",...'` with
  `BB_TEST_TITLE` and `BB_TEST_DETAIL` in the environment (the banner says what runs). Logs in
  `out/logs/` (ignored; they contain addresses).
