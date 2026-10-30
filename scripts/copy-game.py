#!/usr/bin/env python3
"""bloodborne-ios: copies the game folder (a CUSA03173 dump with update 1.09 merged) into the
app's Documents/game on the iPhone over the cable.

One `devicectl device copy to` of the whole folder fails partway: the phone runs out of file
handles ("too many open files", POSIX error 24) on the game's 28,797 files. This copies it in
pieces of at most 800 files, each tried three times. About 33 minutes for the whole dump.

    BB_IOS_DEVICE=<udid> scripts/copy-game.py GAME_DIR [BUNDLE_ID]

BUNDLE_ID: the app to copy into, the launcher's app by default (io.github.pablovsouza.bloodborne-ios);
io.github.pablovsouza.bloodborne-poc for the game app.
"""
import os
import subprocess
import sys
import time

LIMIT = 800
TRIES = 3


def count(path):
    return sum(len(files) for _, _, files in os.walk(path)) if os.path.isdir(path) else 1


def main():
    if len(sys.argv) < 2 or not os.environ.get("BB_IOS_DEVICE"):
        sys.exit(__doc__)
    game = sys.argv[1].rstrip("/")
    bundle = sys.argv[2] if len(sys.argv) > 2 else "io.github.pablovsouza.bloodborne-ios"
    device = os.environ["BB_IOS_DEVICE"]
    env = dict(os.environ)
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    if not os.path.isfile(os.path.join(game, "eboot.bin")):
        sys.exit(f"{game}: no eboot.bin (the game folder, with update 1.09 merged)")
    total = count(game)
    done = failed = 0
    start = time.time()

    def copy(path, target):
        for attempt in range(TRIES):
            result = subprocess.run(["xcrun", "devicectl", "device", "copy", "to", "--device", device,
                                     "--domain-type", "appDataContainer", "--domain-identifier", bundle,
                                     "--source", path, "--destination", target],
                                    env=env, capture_output=True, text=True)
            if result.returncode == 0:
                return True
            last = (result.stdout.strip().splitlines() or [""])[-1]
            print(f"  retry {attempt + 1}: {target}: {last}", flush=True)
            time.sleep(5)
        return False

    def walk(path, target):
        nonlocal done, failed
        n = count(path)
        if n <= LIMIT or not os.path.isdir(path):
            if copy(path, target):
                done += n
            else:
                failed += n
                print(f"FAILED {target}", flush=True)
            print(f"{done}/{total} files, {time.time() - start:.0f} s", flush=True)
            return
        for name in sorted(os.listdir(path)):
            walk(os.path.join(path, name), f"{target}/{name}")

    walk(game, "Documents/game")
    print(f"Copied {done} files, {failed} failed, in {time.time() - start:.0f} s")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
