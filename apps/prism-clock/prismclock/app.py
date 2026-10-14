"""The background app: one instance, a command socket, the clock and its window."""

import signal
import sys

from PySide6.QtCore import QTimer
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtWidgets import QApplication

from .core import RUNTIME, Clock
from .theme import Theme
from .ui import ClockWindow

SOCK = str(RUNTIME / "prism-clock.sock")


def run(first_command=""):
    app = QApplication(sys.argv[:1])
    app.setApplicationName("Prism Clock")
    app.setDesktopFileName("prism-clock")  # the Wayland app id Hyprland matches on
    app.setQuitOnLastWindowClosed(False)

    # one instance: if a live one answers on the socket, hand it the command and leave
    probe = QLocalSocket()
    probe.connectToServer(SOCK)
    if probe.waitForConnected(300):
        if first_command:
            probe.write((first_command + "\n").encode())
            probe.waitForBytesWritten(300)
            probe.waitForReadyRead(500)
        return 0
    QLocalServer.removeServer(SOCK)  # a stale socket from a crash
    server = QLocalServer()
    if not server.listen(SOCK):
        print("prism-clock: can't listen on", SOCK, file=sys.stderr)
        return 1

    clock = Clock()
    theme = Theme()
    win = ClockWindow(clock, theme)

    def handle(cmd):
        parts = cmd.split()
        if not parts:
            return
        op, rest = parts[0], parts[1:]
        if op == "toggle":
            win.toggle_window()
        elif op == "show":
            if rest:
                win.set_tab(rest[0])
            win.show_window()
        elif op == "hide":
            win.hide_window()
        elif op == "timer" and rest:
            try:
                minutes = float(rest[0])
            except ValueError:
                return
            if minutes <= 0:
                clock.timer_reset()
            else:
                clock.timer_set(minutes * 60000)
                clock.timer_start()
        elif op == "cancel":
            clock.timer_reset()
        elif op == "stopwatch":
            clock.sw_toggle()
        elif op == "stop":
            clock.stop_ringing()
        elif op == "snooze":
            r = clock.ringing
            clock.snooze() if r and r["kind"] == "alarm" else clock.timer_again(60000) if r else None
        elif op == "quit":
            app.quit()

    def on_connection():
        conn = server.nextPendingConnection()

        def read():
            while conn.canReadLine():
                line = bytes(conn.readLine()).decode(errors="replace").strip()
                handle(line)
                conn.write(b"ok\n")
                conn.flush()
            conn.disconnectFromServer()

        conn.readyRead.connect(read)
        if conn.canReadLine():
            read()

    server.newConnection.connect(on_connection)

    # quit cleanly on SIGTERM / Ctrl+C (Python only sees signals between Qt events)
    signal.signal(signal.SIGTERM, lambda *_: app.quit())
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    keepalive = QTimer(interval=500)
    keepalive.timeout.connect(lambda: None)
    keepalive.start()

    app.aboutToQuit.connect(clock.shutdown)
    app.aboutToQuit.connect(lambda: QLocalServer.removeServer(SOCK))
    clock.write_status()
    if first_command:
        QTimer.singleShot(0, lambda: handle(first_command))
    return app.exec()
