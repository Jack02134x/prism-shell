#!/usr/bin/env python3
"""Prism Clock: timer, stopwatch, alarms and a floating clock window.

    prism_clock.py toggle            show / hide the window (starts the app if needed)
    prism_clock.py show [tab]        clock | timer | stopwatch | alarms | settings
    prism_clock.py hide
    prism_clock.py mini [on|off]     shrink to / expand from the mini pill
    prism_clock.py timer <minutes>   start a timer (0 or `cancel` stops it)
    prism_clock.py stopwatch         start / pause the stopwatch
    prism_clock.py stop | snooze     whatever is ringing
    prism_clock.py daemon            run in the background, window hidden
    prism_clock.py quit

One background process keeps time (alarms ring with the window closed). Commands
go to it over a unix socket; this client part only needs the standard library,
so it answers instantly. Prism's bar reads $XDG_RUNTIME_DIR/prism-clock.status.json.
"""

import os
import socket
import subprocess
import sys
from pathlib import Path

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/prism-clock-{os.getuid()}")
SOCK = RUNTIME / "prism-clock.sock"
STARTS_APP = {"toggle", "show", "timer", "stopwatch", "daemon"}


def send(cmd):
    """Send a command to the running app; False if none is running."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(1.0)
            s.connect(str(SOCK))
            s.sendall((cmd + "\n").encode())
            s.recv(64)  # wait for "ok" so the command has been handled
        return True
    except OSError:
        return False


def main():
    args = sys.argv[1:] or ["toggle"]
    if args[0] in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0
    if args[0] == "--run":  # the background app itself
        from prismclock.app import run
        return run(" ".join(args[1:]))
    cmd = " ".join(args)
    if send(cmd):
        return 0
    if args[0] not in STARTS_APP:
        return 1  # nothing running, nothing to stop / hide
    # start the app detached; it runs `cmd` once it's up
    first = "" if args[0] == "daemon" else cmd
    subprocess.Popen([sys.executable, os.path.abspath(__file__), "--run", first],
                     cwd=os.path.dirname(os.path.abspath(__file__)), start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


if __name__ == "__main__":
    sys.exit(main())
