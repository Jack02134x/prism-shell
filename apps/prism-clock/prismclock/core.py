"""Clock state and logic: timer, stopwatch, alarms, ringing, persistence.

Everything is stored as wall-clock times (ms since the epoch), so a timer or a
running stopwatch survives the app restarting. The window is only a view of this.
"""

import json
import os
import re
import time
from pathlib import Path

from PySide6.QtCore import QObject, QProcess, QTimer, Signal

SHELL_DIR = Path(__file__).resolve().parents[3]  # ~/.config/quickshell
STATE_FILE = SHELL_DIR / ".state" / "clock.json"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/prism-clock-{os.getuid()}")
STATUS_FILE = RUNTIME / "prism-clock.status.json"

DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

# generated tones: ffmpeg's lavfi synthesises them, no sound files needed
BUILTIN_TONES = [
    ("builtin:digital", "Digital", "0.45*sin(2*PI*2000*t)*lt(mod(t,0.25),0.09)*lt(mod(t,1.6),1)"),
    ("builtin:beep", "Beep", "0.45*sin(2*PI*880*t)*lt(mod(t,0.6),0.18)"),
    ("builtin:chime", "Chime", "0.35*sin(2*PI*(660+330*lt(mod(t,1.2),0.6))*t)*exp(-4*mod(t,0.6))"),
    ("builtin:gentle", "Gentle rise", "min(1,t/20)*0.4*sin(2*PI*523*t)*(0.6+0.4*sin(2*PI*0.5*t))"),
]
SKIP_SOUNDS = re.compile(r"audio-channel|audio-test|audio-volume|camera|device-|power-|service-|suspend|trash|screen-capture")


def now_ms():
    return time.time() * 1000


def hms(sec):
    sec = max(0, int(-(-sec // 1)))  # ceil
    h, m, s = sec // 3600, sec // 60 % 60, sec % 60
    return f"{h}:{m:02}:{s:02}" if h else f"{m}:{s:02}"


def hmsc(ms):
    ms = max(0, int(ms))
    t = ms // 1000
    h, m, s = t // 3600, t // 60 % 60, t % 60
    head = f"{h}:{m:02}" if h else f"{m:02}"
    return f"{head}:{s:02}.{ms // 10 % 100:02}"


def human(sec):
    sec = max(0, int(sec))
    h, m = sec // 3600, sec // 60 % 60
    if h:
        return f"{h}h {m}m" if m else f"{h}h"
    return f"{m}m" if m else f"{sec}s"


def days_text(days):
    if not days:
        return "Once"
    if len(days) == 7:
        return "Every day"
    s = sorted(days)
    if s == [1, 2, 3, 4, 5]:
        return "Weekdays"
    if s == [0, 6]:
        return "Weekends"
    return " ".join(DAY_NAMES[d] for d in sorted(days, key=lambda d: (d + 6) % 7))


def system_tones():
    out = []
    root = Path("/usr/share/sounds")
    if root.is_dir():
        for p in sorted(root.rglob("*")):
            if p.suffix in (".oga", ".ogg", ".wav") and not SKIP_SOUNDS.search(str(p)):
                out.append((str(p), p.stem.replace("-", " ").replace("_", " ").capitalize()))
    return out[:40]


class Clock(QObject):
    """All state. `changed` fires on any state change (not on ticks)."""

    changed = Signal()
    ringing_changed = Signal()

    def __init__(self):
        super().__init__()
        # window (the view reads/writes these too)
        self.visible = False
        self.mini = False
        self.pinned = True
        self.tab = "clock"
        self.win_x = -1
        self.win_y = -1
        # timer
        self.timer_duration = 5 * 60000
        self.timer_ends_at = 0
        self.timer_left_paused = 0
        self.timer_running = False
        # stopwatch
        self.sw_running = False
        self.sw_started_at = 0
        self.sw_banked = 0
        self.laps = []
        # alarms: {id, h, m, label, days: [0..6] (0 = Sunday; empty = once), enabled, snoozedTo}
        self.alarms = []
        self.last_fired = ""
        # ringing: {kind, title, sub, alarmId} or None
        self.ringing = None
        self.settings = {"tone": "builtin:digital", "volume": 80, "snoozeMin": 5, "ringSec": 60}
        self.system_tones = system_tones()

        self._player = QProcess(self)
        self._preview = QProcess(self)
        self.previewing = ""
        self._notify = QProcess(self)
        self._notify.finished.connect(self._on_notify_action)
        self._notify_id = ""

        self._auto_stop = QTimer(self, singleShot=True)
        self._auto_stop.timeout.connect(self._missed)
        self._save_timer = QTimer(self, singleShot=True, interval=400)
        self._save_timer.timeout.connect(self._write)
        self._tick = QTimer(self, interval=1000)
        self._tick.timeout.connect(self.check)
        self._tick.start()

        self.load()
        self.changed.connect(self.save)

    # ---------------------------------------------------------------- timer --
    @property
    def timer_paused(self):
        return not self.timer_running and self.timer_left_paused > 0

    def timer_left(self):
        if self.timer_running:
            return max(0, self.timer_ends_at - now_ms())
        return self.timer_left_paused if self.timer_paused else self.timer_duration

    def timer_start(self):
        if self.timer_running:
            return
        self.timer_ends_at = now_ms() + (self.timer_left_paused if self.timer_paused else self.timer_duration)
        self.timer_left_paused = 0
        self.timer_running = True
        self.changed.emit()

    def timer_pause(self):
        if not self.timer_running:
            return
        self.timer_left_paused = max(1, self.timer_ends_at - now_ms())
        self.timer_running = False
        self.changed.emit()

    def timer_reset(self):
        self.timer_running = False
        self.timer_left_paused = 0
        self.changed.emit()

    def timer_set(self, ms):
        self.timer_duration = max(1000, min(int(ms), 24 * 3600000))
        self.timer_reset()

    def timer_add(self, ms):
        if self.timer_running:
            self.timer_ends_at += ms
        elif self.timer_paused:
            self.timer_left_paused += ms
        else:
            self.timer_duration = min(self.timer_duration + ms, 24 * 3600000)
        self.changed.emit()

    # ------------------------------------------------------------ stopwatch --
    def sw_elapsed(self):
        return self.sw_banked + (now_ms() - self.sw_started_at if self.sw_running else 0)

    def sw_toggle(self):
        if self.sw_running:
            self.sw_banked += now_ms() - self.sw_started_at
            self.sw_running = False
        else:
            self.sw_started_at = now_ms()
            self.sw_running = True
        self.changed.emit()

    def sw_lap(self):
        if self.sw_running:
            self.laps = ([self.sw_elapsed()] + self.laps)[:99]
            self.changed.emit()

    def sw_reset(self):
        self.sw_running = False
        self.sw_banked = 0
        self.laps = []
        self.changed.emit()

    # --------------------------------------------------------------- alarms --
    def _sort_alarms(self):
        self.alarms.sort(key=lambda a: a["h"] * 60 + a["m"])

    def add_alarm(self, h, m, label, days):
        self.alarms.append({"id": int(now_ms()), "h": h, "m": m, "label": label, "days": list(days), "enabled": True, "snoozedTo": 0})
        self._sort_alarms()
        self.changed.emit()

    def update_alarm(self, aid, **changes):
        for a in self.alarms:
            if a["id"] == aid:
                a.update(changes)
        self._sort_alarms()
        self.changed.emit()

    def remove_alarm(self, aid):
        self.alarms = [a for a in self.alarms if a["id"] != aid]
        self.changed.emit()

    def next_in(self, a):
        """ms until the alarm rings next (None when it won't)."""
        if not a["enabled"]:
            return None
        t = now_ms()
        if a.get("snoozedTo", 0) > t:
            return a["snoozedTo"] - t
        lt = time.localtime()
        base = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, a["h"], a["m"], 0, 0, 0, -1)) * 1000
        for i in range(8):
            when = base + i * 86400000
            if when <= t:
                continue
            wday = (time.localtime(when / 1000).tm_wday + 1) % 7  # Python Monday=0 -> Sunday=0
            if not a["days"] or wday in a["days"]:
                return when - t
        return None

    def next_alarm(self):
        best = None
        for a in self.alarms:
            t = self.next_in(a)
            if t is not None and (best is None or t < best[1]):
                best = (a, t)
        return best

    # --------------------------------------------------------------- ticking --
    def check(self):
        t = now_ms()
        if self.timer_running and t >= self.timer_ends_at:
            self.timer_running = False
            self.timer_left_paused = 0
            self.changed.emit()
            self.ring("timer", "Time's up", "Timer · " + human(self.timer_duration / 1000))
            return
        lt = time.localtime()
        stamp = time.strftime("%Y-%m-%d %H:%M", lt)
        wday = (lt.tm_wday + 1) % 7
        for a in self.alarms:
            if not a["enabled"]:
                continue
            snooze_due = a.get("snoozedTo", 0) > 0 and t >= a["snoozedTo"]
            time_due = lt.tm_hour == a["h"] and lt.tm_min == a["m"] and (not a["days"] or wday in a["days"])
            key = f"{a['id']}@{stamp}"
            if (time_due or snooze_due) and self.last_fired != key:
                self.last_fired = key
                # one-off alarms switch themselves off once they ring
                self.update_alarm(a["id"], snoozedTo=0, enabled=bool(a["days"]))
                sub = f"{a['h']:02}:{a['m']:02}" + (" · " + days_text(a["days"]) if a["days"] else "")
                self.ring("alarm", a["label"] or "Alarm", sub, a["id"])
                return

    # -------------------------------------------------------------- ringing --
    def ring(self, kind, title, sub, alarm_id=0):
        self.ringing = {"kind": kind, "title": title, "sub": sub, "alarmId": alarm_id}
        self._play(self._player, self.settings["tone"], 0)
        self._auto_stop.start(max(5, int(self.settings["ringSec"])) * 1000)
        second = f"snooze=Snooze {self.settings['snoozeMin']} min" if kind == "alarm" else "more=+1 min"
        self._notify.start("notify-send", ["-a", "Prism Clock", "-u", "critical", "-i", "alarm-symbolic", "-p",
                                           "-A", "stop=Stop", "-A", second, title, sub])
        self.ringing_changed.emit()
        self.changed.emit()

    def _on_notify_action(self):
        out = bytes(self._notify.readAllStandardOutput()).decode(errors="replace").split()
        action = out[-1] if len(out) > 1 else ""
        if not self.ringing:
            return
        if action in ("stop", ""):  # "" = the notification was dismissed
            self.stop_ringing()
        elif action == "snooze":
            self.snooze()
        elif action == "more":
            self.timer_again(60000)

    def _close_notification(self):
        # -p printed the id as the first line while notify-send waits for an action
        out = bytes(self._notify.peek(64)).decode(errors="replace").split()
        nid = out[0] if out and out[0].isdigit() else ""
        if self._notify.state() != QProcess.NotRunning:
            self._notify.kill()
        if nid:
            QProcess.startDetached("gdbus", ["call", "--session", "--dest", "org.freedesktop.Notifications",
                                             "--object-path", "/org/freedesktop/Notifications",
                                             "--method", "org.freedesktop.Notifications.CloseNotification", nid])

    def stop_ringing(self):
        if not self.ringing:
            return
        self.ringing = None
        self._player.kill()
        self._auto_stop.stop()
        self._close_notification()
        self.ringing_changed.emit()
        self.changed.emit()

    def snooze(self):
        r = self.ringing
        self.stop_ringing()
        if r and r.get("alarmId"):
            self.update_alarm(r["alarmId"], snoozedTo=now_ms() + self.settings["snoozeMin"] * 60000, enabled=True)

    def timer_again(self, ms):
        self.stop_ringing()
        self.timer_set(ms)
        self.timer_start()

    def _missed(self):
        r = self.ringing
        self.stop_ringing()
        if r:
            QProcess.startDetached("notify-send", ["-a", "Prism Clock", "-i", "alarm-symbolic", "Missed: " + r["title"], r["sub"]])

    # ---------------------------------------------------------------- tones --
    def tone_name(self, tid):
        for i, name, _ in BUILTIN_TONES:
            if i == tid:
                return name
        for i, name in self.system_tones:
            if i == tid:
                return name
        return Path(tid).stem

    def _play(self, proc, tid, seconds):
        proc.kill()
        proc.waitForFinished(200)
        args = ["-nodisp", "-loglevel", "quiet", "-volume", str(int(self.settings["volume"]))]
        expr = next((e for i, _, e in BUILTIN_TONES if i == tid), None)
        if expr:
            args += ["-f", "lavfi", "-i", "aevalsrc=" + expr.replace(",", "\\,") + ":s=44100"]
        else:
            args += ["-loop", "0", tid]
        if seconds:
            proc.start("timeout", [str(seconds), "ffplay"] + args)
        else:
            proc.start("ffplay", args)

    def preview(self, tid):
        self.previewing = tid
        self._play(self._preview, tid, 4)
        QTimer.singleShot(4000, self._preview_done)
        self.changed.emit()

    def _preview_done(self):
        self.previewing = ""
        self.changed.emit()

    def set_setting(self, key, value):
        self.settings[key] = value
        self.changed.emit()

    # ---------------------------------------------------------- persistence --
    def load(self):
        try:
            s = json.loads(STATE_FILE.read_text())
        except (OSError, ValueError):
            return
        t, sw, w = s.get("timer", {}), s.get("stopwatch", {}), s.get("window", {})
        self.timer_duration = t.get("duration", self.timer_duration)
        self.timer_ends_at = t.get("endsAt", 0)
        self.timer_left_paused = t.get("leftPaused", 0)
        self.timer_running = t.get("running", False)
        self.sw_running = sw.get("running", False)
        self.sw_started_at = sw.get("startedAt", 0)
        self.sw_banked = sw.get("banked", 0)
        self.laps = sw.get("laps", [])
        self.alarms = [{"label": "", "days": [], "enabled": True, "snoozedTo": 0, **a} for a in s.get("alarms", [])]
        self.settings.update(s.get("settings", {}))
        self.win_x, self.win_y = w.get("x", -1), w.get("y", -1)
        self.mini = w.get("mini", False)
        self.pinned = w.get("pinned", True)
        self.tab = w.get("tab", "clock") if w.get("tab") != "focus" else "clock"

    def save(self):
        self._save_timer.start()

    def _write(self):
        data = {
            "timer": {"duration": self.timer_duration, "endsAt": self.timer_ends_at, "leftPaused": self.timer_left_paused, "running": self.timer_running},
            "stopwatch": {"running": self.sw_running, "startedAt": self.sw_started_at, "banked": self.sw_banked, "laps": self.laps},
            "alarms": self.alarms,
            "settings": self.settings,
            "window": {"x": self.win_x, "y": self.win_y, "mini": self.mini, "pinned": self.pinned, "tab": self.tab},
        }
        _atomic_write(STATE_FILE, json.dumps(data, indent=1))
        self.write_status()

    def write_status(self):
        """What Prism's bar shows. Live numbers are derived from these timestamps."""
        nxt = self.next_alarm()
        status = {
            "version": 1,
            "pid": os.getpid(),
            "visible": self.visible,
            "mini": self.mini,
            "pinned": self.pinned,
            "tab": self.tab,
            "timer": {"running": self.timer_running, "paused": self.timer_paused, "endsAt": self.timer_ends_at,
                      "left": self.timer_left_paused if self.timer_paused else self.timer_duration, "duration": self.timer_duration},
            "stopwatch": {"running": self.sw_running, "startedAt": self.sw_started_at, "banked": self.sw_banked},
            "ringing": self.ringing,
            "nextAlarm": {"label": nxt[0]["label"] or "Alarm", "at": now_ms() + nxt[1]} if nxt else None,
            "ts": time.time(),
        }
        _atomic_write(STATUS_FILE, json.dumps(status))

    def shutdown(self):
        self._player.kill()
        self._preview.kill()
        self._write()
        try:
            STATUS_FILE.unlink()
        except OSError:
            pass


def _atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)
