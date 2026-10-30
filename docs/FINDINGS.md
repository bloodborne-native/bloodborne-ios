# Findings

What the iPhone allows an app like this one, and what was measured on an iPhone 17 Pro Max
signed with a free Apple ID. The runtime's
[`docs/IOS_POC.md`](https://github.com/bloodborne-native/bloodborne-runtime/blob/main/docs/IOS_POC.md)
covers the runtime's iOS code: the memory layout, the recompiled library, Metal.

## A free Apple ID

An app installed from Xcode with a free Apple ID:

- stops opening seven days after it was signed, until it is built and installed again; at most
  three such apps are installed at a time;
- gets no entitlement beyond the basic ones. The two that matter here, the extended virtual
  addressing and the increased memory limit, need the paid Apple Developer Program, and so does
  every way of handing the app to someone else (TestFlight, the App Store, the alternative
  stores in the EU, which take only apps Apple has notarized);
- cannot run JIT code and cannot start another program (`execve` fails with `EPERM`): the
  game runs as recompiled code or interpreted, in the app's own process.

## The address space

Without the extended virtual addressing, the app has two places to put memory:

- **The low region:** about 2 GiB below the system's shared cache at `0x180000000`. Everything
  that is not the game's own memory lives here: the app's code and libraries, the recompiled
  library, WebKit, every `malloc`, Metal's driver memory.
- **A 6 GiB block at `0x7000000000`:** reserved by the runtime at start for the game's image and
  its memory pool (the runtime's compact layout).

The process's memory limit is about 3.3 GiB. In practice the low region runs out first: a large
allocation fails once the largest free gap is too small, though memory is left under the limit.
The game's log reports both (`room ...`, `Address space: ...`).

What uses the low region, by memory tag, measured with the launcher's app in gameplay:

| Tag | What | Size |
|---|---|---|
| 0 | Mapped files, the app and the recompiled library (its code 304 MiB, its link data 31 MiB) | 346 MiB |
| 2, 3 | `malloc` | varies |
| 53 | WebKit's own allocator (bmalloc) | halved with the system allocator (`Malloc=1`) |
| 63 | WebKit's JavaScript engine | 256 or 512 MiB, absent in one run |
| 88 | IOSurface (the screen's buffers) | |
| 100 | IOAccelerator (Metal) | about 255 MiB |

The crash seen in play: 2,044 MiB of the low region used and its largest gap 2 MiB, when the
system drew an animation over the game.

What reduced its use, each measured on the phone:

- **A release build of the launcher.** The debug build's code and its symbols alone leave the
  game too little to start.
- **WebKit with the system allocator** (`Malloc=1`, set by the app before WebKit starts): halves
  tag 53. Turning off WebKit's Gigacage (`GIGACAGE_ENABLED=no`) did not remove tag 63.
- **The launcher's window destroyed before the game starts:** its web view and its JavaScript
  memory go with it.
- **No Metal binary archive** (`BB_METAL_ARCHIVE=0` in the launcher's app): an archive costs
  13–37 times its size in address space when loaded.
- **A 32 MiB stream buffer** for the renderer's small uploads (16 KiB and under) instead of the
  Mac's size.
- **The game's files read in one allocation**, and the executable linked with one growth of its
  buffer, instead of repeated reallocations that leave the region in pieces.

What did not work:

- **A reserve held back at start** (256 and 533 MiB) for the system: it starved the launcher's
  own start.
- **The recompiled library in the 6 GiB block:** it took the game pool's place, or the system
  refused to map it there. It is loaded early with `dlopen` instead.

Next: a budget for the renderer's textures that keeps room for the system (without evicting
textures only the GPU holds: that drew them dark), then what creates WebKit's tag 63 region,
then smaller tables in the runtime.

## One app: the launcher with the game

The game runs in the launcher's own process, started by its Play. What that took:

- **Starting the game:** Tauri's `run_on_main_thread` re-enters the windowing library's
  observers and aborts. The game is scheduled with `dispatch_async_f` on the main queue, and
  from there on a run-loop timer: a main-queue block that never returns stops touches from
  being delivered.
- **The launcher's window** is destroyed before Play (and the app's exit is prevented), so the
  game's window is the only one and WebKit's memory is freed.
- **Orientation:** the launcher stays in portrait; the phone turns to landscape for the game
  only.
- **The game's output:** Tauri redirects the standard streams, so the game's log is attached at
  Play: standard output through a pipe that also copies it to the log, standard error straight
  to the log, both flushed at an abort with a backtrace and the address space left.
- **Paths:** the app's container path changes between installs; the launcher stores paths
  relative to it.
- **Settings:** the launcher's settings reach the game as on the Mac (`bbport.ini` and
  environment variables). On the iPhone the app also sets the output and render size from the
  screen: at most 540 lines, the screen's own shape when the aspect ratio is Auto.
- **The executable and its patches** are built by the game on the phone from the dump (the
  runtime's preparation and patches in C), so nothing is prepared on a Mac.

## Speed

On the iPhone 17 Pro Max, with the recompiled library and the Metal renderer:

- the title screen at 60 FPS;
- gameplay at 960×540: 38–42 FPS uncapped in the first 20 seconds, falling as the phone heats;
  capped at 30 FPS it holds 30 once the phone has throttled.

The first proof of concept measured about 23 FPS at the same size, bound by the CPU without JIT.

## Touch

On-screen controls drawn by the game's overlay in the launcher's colours: two sticks, the face
buttons, the d-pad, the shoulders, Options, the touchpad and a settings button. Their layout is
measured in screen heights from the safe area's edges, so they fit any phone. They are hidden
while a controller is connected (`BB_TOUCH_CONTROLS` forces them off or on). The design follows
[Bloodborne-Android](https://github.com/ducvd89/Bloodborne-Android)'s on-screen controller,
credited in the runtime's and the app's `CREDITS.md`.

## Copying the game

One `devicectl device copy to` of the whole dump fails partway: the phone runs out of file
handles (`POSIX error 24`) on its 28,797 files. `scripts/copy-game.py` copies it in pieces of at
most 800 files, about 33 minutes over the cable. Finder's file sharing works too: the launcher's
app allows it.
