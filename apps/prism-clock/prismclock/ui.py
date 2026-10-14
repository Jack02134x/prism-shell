"""The window: Clock · Timer · Stopwatch · Alarms · Settings, a mini mode and a
ringing screen. A normal Wayland window; on Hyprland it floats, remembers where
you put it and can be pinned to every workspace (the pin button)."""

import json
import math
import os
import subprocess
import time

from PySide6.QtCore import QPointF, QRectF, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import (QFileDialog, QFrame, QGridLayout, QHBoxLayout, QLabel, QLineEdit, QListWidget,
                               QPushButton, QScrollArea, QSlider, QStackedWidget, QVBoxLayout, QWidget)

from .core import BUILTIN_TONES, days_text, hms, hmsc, human
from .theme import ico

W, H = 316, 448  # full window
MW, MH = 236, 58  # mini
TABS = [("clock", "clock_outline", "Clock"), ("timer", "timer_sand", "Timer"),
        ("stopwatch", "timer_outline", "Stopwatch"), ("alarms", "alarm", "Alarms"), ("settings", "cog", "Settings")]


# ------------------------------------------------------------------ hyprland --
def _hypr():
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"))


def _hyprctl(*args):
    try:
        return subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def _my_window():
    """Our own toplevel as Hyprland sees it (matched by pid)."""
    try:
        for c in json.loads(_hyprctl("clients", "-j") or "[]"):
            if c.get("pid") == os.getpid():
                return c
    except ValueError:
        pass
    return None


# ------------------------------------------------------------------- widgets --
def rpen(color, width):
    """A pen with round ends."""
    pen = QPen(color, width)
    pen.setCapStyle(Qt.RoundCap)
    return pen


class Glyph(QLabel):
    def __init__(self, theme, name, size=16, color_role="on_surface"):
        super().__init__(ico(name))
        self.theme, self.size_, self.role = theme, size, color_role
        self.setFont(theme.icon_font(size))
        self.setAlignment(Qt.AlignCenter)


class IconButton(QPushButton):
    def __init__(self, theme, name, size=30, tip="", object_name="icon"):
        super().__init__(ico(name))
        self.theme = theme
        self.setObjectName(object_name)
        self.setFixedSize(size, size)
        self.setFont(theme.icon_font(int(size * 0.5)))
        self.setToolTip(tip)
        self.setCursor(Qt.PointingHandCursor)

    def set_icon(self, name):
        self.setText(ico(name))


def button(text, primary=False, icon=None, theme=None):
    b = QPushButton((ico(icon) + "  " if icon else "") + text)
    if primary:
        b.setObjectName("primary")
    b.setCursor(Qt.PointingHandCursor)
    if icon and theme:
        # glyph + text in one label: let the icon font fall back for the glyph
        f = theme.font(13, QFont.Weight.DemiBold)
        f.setFamilies([f.family(), "Symbols Nerd Font"])
        b.setFont(f)
    return b


def thin(theme, size, text=""):
    lbl = QLabel(text)
    lbl.setFont(theme.font(size, QFont.Weight.Thin))
    lbl.setAlignment(Qt.AlignCenter)
    return lbl


def dim(text="", size=11):
    lbl = QLabel(text)
    lbl.setObjectName("dim")
    f = lbl.font()
    f.setPixelSize(size)
    lbl.setFont(f)
    return lbl


class Ring(QWidget):
    """A thin progress ring with a big thin number in the middle."""

    def __init__(self, theme, size=176):
        super().__init__()
        self.theme = theme
        self.value, self.text, self.sub = 1.0, "", ""
        self.setFixedSize(size, size)

    def set(self, value, text, sub):
        self.value, self.text, self.sub = value, text, sub
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        r = QRectF(4, 4, self.width() - 8, self.height() - 8)
        p.setPen(QPen(self.theme.c("on_surface", 0.08), 3))
        p.drawEllipse(r)
        p.setPen(rpen(self.theme.accent, 3))
        p.drawArc(r, 90 * 16, int(-360 * 16 * max(0.0, min(1.0, self.value))))
        p.setPen(self.theme.c("on_surface"))
        p.setFont(self.theme.font(44 if len(self.text) <= 5 else 34, QFont.Weight.Thin))
        p.drawText(QRectF(0, -10, self.width(), self.height()), Qt.AlignCenter, self.text)
        p.setPen(self.theme.c("on_surface_variant"))
        p.setFont(self.theme.font(11))
        p.drawText(QRectF(0, self.height() / 2 + 22, self.width(), 20), Qt.AlignHCenter, self.sub)


class AnalogClock(QWidget):
    def __init__(self, theme, size=164):
        super().__init__()
        self.theme = theme
        self.setFixedSize(size, size)

    def paintEvent(self, _):
        t = self.theme
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        s = self.width()
        c = s / 2
        acc = QColor(t.accent)
        acc.setAlphaF(0.45)
        p.setPen(QPen(acc, 1))
        p.setBrush(t.c("on_surface", 0.04))
        p.drawEllipse(QRectF(2, 2, s - 4, s - 4))
        for i in range(12):
            a = math.radians(i * 30)
            big = i % 3 == 0
            r1, r2 = c - 8, c - (20 if big else 14)
            p.setPen(rpen(t.accent if big else t.c("on_surface", 0.35), 2 if big else 1))
            p.drawLine(QPointF(c + r1 * math.sin(a), c - r1 * math.cos(a)), QPointF(c + r2 * math.sin(a), c - r2 * math.cos(a)))
        now = time.time()
        lt = time.localtime(now)
        sec = lt.tm_sec + (now % 1)
        hands = [((lt.tm_hour % 12 + lt.tm_min / 60) * 30, c * 0.48, 3, t.c("on_surface")),
                 ((lt.tm_min + sec / 60) * 6, c * 0.72, 2, t.c("primary")),
                 (sec * 6, c * 0.82, 1, t.accent)]
        for deg, ln, w, col in hands:
            a = math.radians(deg)
            p.setPen(rpen(col, w))
            p.drawLine(QPointF(c - 10 * math.sin(a), c + 10 * math.cos(a)), QPointF(c + ln * math.sin(a), c - ln * math.cos(a)))
        p.setPen(Qt.NoPen)
        p.setBrush(t.accent)
        p.drawEllipse(QRectF(c - 3.5, c - 3.5, 7, 7))


class WheelLabel(QLabel):
    """A big number you can scroll."""

    stepped = Signal(int)

    def wheelEvent(self, e):
        self.stepped.emit(1 if e.angleDelta().y() > 0 else -1)


# --------------------------------------------------------------------- pages --
class Page(QWidget):
    def __init__(self, win):
        super().__init__()
        self.win, self.clock, self.theme = win, win.clock, win.theme

    def refresh(self):
        pass

    def rebuild(self):
        """State changed (not just time passing)."""
        self.refresh()


class ClockPage(Page):
    def __init__(self, win):
        super().__init__(win)
        lay = QVBoxLayout(self)
        lay.setSpacing(6)
        self.face = AnalogClock(self.theme)
        lay.addWidget(self.face, 0, Qt.AlignHCenter)
        row = QHBoxLayout()
        row.addStretch()
        self.hm = thin(self.theme, 50)
        self.ss = QLabel()
        self.ss.setFont(self.theme.font(20, QFont.Weight.ExtraLight))
        row.addWidget(self.hm, 0, Qt.AlignBaseline)
        row.addWidget(self.ss, 0, Qt.AlignBaseline)
        row.addStretch()
        lay.addLayout(row)
        self.date = dim(size=12)
        self.date.setAlignment(Qt.AlignCenter)
        lay.addWidget(self.date)
        self.upcoming = QVBoxLayout()
        self.upcoming.setSpacing(4)
        lay.addLayout(self.upcoming)
        lay.addStretch()
        self._rows = []

    def refresh(self):
        lt = time.localtime()
        self.hm.setText(time.strftime("%H:%M", lt))
        self.ss.setText(time.strftime("%S", lt))
        self.ss.setStyleSheet(f"color: {self.theme.accent_hex()}")
        self.date.setText(time.strftime("%A, %-d %B", lt))
        self.face.update()
        c = self.clock
        lines = []
        nxt = c.next_alarm()
        if nxt:
            lines.append(("alarm", f"{nxt[0]['label'] or 'Alarm'} in {human(nxt[1] / 1000)}", "alarms"))
        if c.timer_running or c.timer_paused:
            lines.append(("timer_sand", f"Timer · {hms(c.timer_left() / 1000)}" + (" (paused)" if c.timer_paused else " left"), "timer"))
        if c.sw_running:
            lines.append(("timer_outline", f"Stopwatch · {hms(c.sw_elapsed() / 1000)}", "stopwatch"))
        while len(self._rows) < len(lines):
            b = QPushButton()
            b.setCursor(Qt.PointingHandCursor)
            b.setStyleSheet("text-align: left; padding: 8px 12px; border-radius: 10px;")
            f = self.theme.font(12)
            f.setFamilies([f.family(), "Symbols Nerd Font"])
            b.setFont(f)
            b.clicked.connect(lambda _=False, b=b: self.win.set_tab(b.property("tab")))
            self.upcoming.addWidget(b)
            self._rows.append(b)
        for i, b in enumerate(self._rows):
            if i < len(lines):
                icon, text, tab = lines[i]
                b.setText(ico(icon) + "   " + text)
                b.setProperty("tab", tab)
                b.show()
            else:
                b.hide()


class TimerPage(Page):
    PRESETS = [1, 3, 5, 10, 15, 25, 45, 60]

    def __init__(self, win):
        super().__init__(win)
        lay = QVBoxLayout(self)
        lay.setSpacing(10)
        self.ring = Ring(self.theme)
        self.ring.wheelEvent = self._wheel
        lay.addWidget(self.ring, 0, Qt.AlignHCenter)

        self.idle_box = QWidget()
        il = QVBoxLayout(self.idle_box)
        il.setContentsMargins(0, 0, 0, 0)
        grid = QGridLayout()
        grid.setSpacing(6)
        self.chips = []
        for i, m in enumerate(self.PRESETS):
            b = QPushButton(f"{m} min" if m < 60 else "1 h")
            b.setObjectName("chip")
            b.setCheckable(True)
            b.setCursor(Qt.PointingHandCursor)
            b.clicked.connect(lambda _=False, m=m: self.clock.timer_set(m * 60000))
            grid.addWidget(b, i // 4, i % 4)
            self.chips.append((m, b))
        il.addLayout(grid)
        adj = QHBoxLayout()
        adj.setSpacing(6)
        for label, ms in (("−1m", -60000), ("−10s", -10000), ("+10s", 10000), ("+1m", 60000)):
            b = QPushButton(label)
            b.setObjectName("chip")
            b.setCursor(Qt.PointingHandCursor)
            b.clicked.connect(lambda _=False, ms=ms: self.clock.timer_set(self.clock.timer_duration + ms))
            adj.addWidget(b)
        il.addLayout(adj)
        lay.addWidget(self.idle_box)
        lay.addStretch()

        row = QHBoxLayout()
        row.addStretch()
        self.reset = IconButton(self.theme, "restore", 40, "Reset")
        self.reset.clicked.connect(self.clock.timer_reset)
        self.go = button("Start", primary=True)
        self.go.setMinimumHeight(40)
        self.go.clicked.connect(lambda: self.clock.timer_pause() if self.clock.timer_running else self.clock.timer_start())
        self.more = IconButton(self.theme, "plus", 40, "+1 minute")
        self.more.clicked.connect(lambda: self.clock.timer_add(60000))
        for w in (self.reset, self.go, self.more):
            row.addWidget(w)
        row.addStretch()
        lay.addLayout(row)

    def _wheel(self, e):
        c = self.clock
        if c.timer_running or c.timer_paused:
            return
        step = 10000 if e.modifiers() & Qt.ShiftModifier else 60000
        c.timer_set(c.timer_duration + (step if e.angleDelta().y() > 0 else -step))

    def refresh(self):
        c = self.clock
        idle = not c.timer_running and not c.timer_paused
        left = c.timer_left()
        sub = "scroll to adjust" if idle else "paused" if c.timer_paused else "of " + hms(c.timer_duration / 1000)
        self.ring.set(1 if idle else left / max(1, c.timer_duration), hms(left / 1000), sub)

    def rebuild(self):
        c = self.clock
        idle = not c.timer_running and not c.timer_paused
        self.idle_box.setVisible(idle)
        self.reset.setVisible(not idle)
        self.more.setVisible(not idle)
        self.go.setText("Pause" if c.timer_running else "Resume" if c.timer_paused else "Start")
        for m, b in self.chips:
            b.setChecked(c.timer_duration == m * 60000)
        self.refresh()


class StopwatchPage(Page):
    def __init__(self, win):
        super().__init__(win)
        lay = QVBoxLayout(self)
        lay.setSpacing(10)
        self.big = thin(self.theme, 48)
        self.big.setMinimumHeight(96)
        f = self.big.font()
        try:  # tabular digits: the numbers don't wobble while counting
            f.setFeature(QFont.Tag("tnum"), 1)
        except (AttributeError, TypeError):
            pass
        self.big.setFont(f)
        lay.addWidget(self.big)
        row = QHBoxLayout()
        row.addStretch()
        self.reset = IconButton(self.theme, "restore", 40, "Reset")
        self.reset.clicked.connect(self.clock.sw_reset)
        self.go = button("Start", primary=True)
        self.go.setMinimumHeight(40)
        self.go.clicked.connect(self.clock.sw_toggle)
        self.lap = IconButton(self.theme, "flag_outline", 40, "Lap")
        self.lap.clicked.connect(self.clock.sw_lap)
        for w in (self.reset, self.go, self.lap):
            row.addWidget(w)
        row.addStretch()
        lay.addLayout(row)
        self.laps = QListWidget()
        self.laps.setFocusPolicy(Qt.NoFocus)
        lay.addWidget(self.laps, 1)

    def refresh(self):
        self.big.setText(hmsc(self.clock.sw_elapsed()))

    def rebuild(self):
        c = self.clock
        self.go.setText("Pause" if c.sw_running else "Resume" if c.sw_banked > 0 else "Start")
        self.reset.setEnabled(c.sw_elapsed() > 0)
        self.lap.setEnabled(c.sw_running)
        self.laps.clear()
        n = len(c.laps)
        for i, total in enumerate(c.laps):
            split = total - (c.laps[i + 1] if i + 1 < n else 0)
            self.laps.addItem(f"Lap {n - i:<3}   +{hmsc(split)}      {hmsc(total)}")
        if not n:
            self.laps.addItem("Laps show up here")
        self.refresh()


class AlarmsPage(Page):
    def __init__(self, win):
        super().__init__(win)
        self.stack = QStackedWidget()
        QVBoxLayout(self).addWidget(self.stack)
        self.layout().setContentsMargins(0, 0, 0, 0)

        # list
        lst = QWidget()
        ll = QVBoxLayout(lst)
        ll.setContentsMargins(0, 0, 0, 0)
        top = QHBoxLayout()
        self.next = dim(size=12)
        top.addWidget(self.next, 1)
        add = button("Add", primary=True)
        add.clicked.connect(lambda: self.edit(None))
        top.addWidget(add)
        ll.addLayout(top)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self.rows_host = QWidget()
        self.rows = QVBoxLayout(self.rows_host)
        self.rows.setContentsMargins(0, 4, 4, 0)
        self.rows.setSpacing(6)
        self.rows.addStretch()
        scroll.setWidget(self.rows_host)
        ll.addWidget(scroll, 1)
        self.stack.addWidget(lst)

        # editor
        ed = QWidget()
        el = QVBoxLayout(ed)
        el.setContentsMargins(0, 0, 0, 0)
        el.setSpacing(10)
        time_row = QHBoxLayout()
        time_row.addStretch()
        self.eh, self.em = 7, 0
        self.h_lbl = self._unit(time_row, True)
        colon = thin(self.theme, 52, ":")
        time_row.addWidget(colon)
        self.m_lbl = self._unit(time_row, False)
        time_row.addStretch()
        el.addLayout(time_row)
        el.addWidget(dim("scroll the numbers for single steps", 10), 0, Qt.AlignHCenter)
        self.label = QLineEdit()
        self.label.setPlaceholderText("Label (optional)")
        self.label.returnPressed.connect(self.save)
        el.addWidget(self.label)
        days = QHBoxLayout()
        days.setSpacing(4)
        self.day_btns = []
        for d in (1, 2, 3, 4, 5, 6, 0):
            b = QPushButton("SMTWTFS"[d])
            b.setObjectName("day")
            b.setCheckable(True)
            b.setFixedHeight(30)
            b.setCursor(Qt.PointingHandCursor)
            b.toggled.connect(self._days_changed)
            days.addWidget(b)
            self.day_btns.append((d, b))
        el.addLayout(days)
        self.days_lbl = dim(size=11)
        self.days_lbl.setAlignment(Qt.AlignCenter)
        el.addWidget(self.days_lbl)
        el.addStretch()
        btns = QHBoxLayout()
        self.delete = button("Delete")
        self.delete.setObjectName("danger")
        self.delete.clicked.connect(self._delete)
        btns.addWidget(self.delete)
        btns.addStretch()
        cancel = button("Cancel")
        cancel.clicked.connect(lambda: self.stack.setCurrentIndex(0))
        btns.addWidget(cancel)
        save = button("Save", primary=True)
        save.clicked.connect(self.save)
        btns.addWidget(save)
        el.addLayout(btns)
        self.stack.addWidget(ed)
        self.edit_id = None

    def _unit(self, row, hour):
        col = QVBoxLayout()
        col.setSpacing(0)
        up = IconButton(self.theme, "chevron_up", 26)
        lbl = WheelLabel()
        lbl.setFont(self.theme.font(52, QFont.Weight.Thin))
        lbl.setAlignment(Qt.AlignCenter)
        down = IconButton(self.theme, "chevron_down", 26)
        up.clicked.connect(lambda: self._bump(hour, 1 if hour else 5))
        down.clicked.connect(lambda: self._bump(hour, -1 if hour else -5))
        lbl.stepped.connect(lambda d: self._bump(hour, d))
        col.addWidget(up, 0, Qt.AlignHCenter)
        col.addWidget(lbl)
        col.addWidget(down, 0, Qt.AlignHCenter)
        row.addLayout(col)
        return lbl

    def _bump(self, hour, d):
        if hour:
            self.eh = (self.eh + d) % 24
        else:
            self.em = (self.em + d) % 60
        self._show_time()

    def _show_time(self):
        self.h_lbl.setText(f"{self.eh:02}")
        self.m_lbl.setText(f"{self.em:02}")

    def _days(self):
        return [d for d, b in self.day_btns if b.isChecked()]

    def _days_changed(self):
        self.days_lbl.setText(days_text(self._days()))

    def edit(self, a):
        if a:
            self.edit_id, self.eh, self.em = a["id"], a["h"], a["m"]
            self.label.setText(a["label"])
            days = a["days"]
        else:
            t = time.localtime(time.time() + 3600)
            self.edit_id, self.eh, self.em = None, t.tm_hour, 0
            self.label.clear()
            days = []
        for d, b in self.day_btns:
            b.setChecked(d in days)
        self._days_changed()
        self._show_time()
        self.delete.setVisible(a is not None)
        self.stack.setCurrentIndex(1)

    def save(self):
        if self.edit_id is None:
            self.clock.add_alarm(self.eh, self.em, self.label.text().strip(), self._days())
        else:
            self.clock.update_alarm(self.edit_id, h=self.eh, m=self.em, label=self.label.text().strip(),
                                    days=self._days(), enabled=True, snoozedTo=0)
        self.stack.setCurrentIndex(0)

    def _delete(self):
        if self.edit_id is not None:
            self.clock.remove_alarm(self.edit_id)
        self.stack.setCurrentIndex(0)

    def refresh(self):
        nxt = self.clock.next_alarm()
        self.next.setText(f"Next in {human(nxt[1] / 1000)}" if nxt else "No alarms on")

    def rebuild(self):
        while self.rows.count() > 1:
            w = self.rows.takeAt(0).widget()
            if w:
                w.deleteLater()
        for a in self.clock.alarms:
            self.rows.insertWidget(self.rows.count() - 1, self._row(a))
        if not self.clock.alarms:
            empty = dim("No alarms yet")
            empty.setAlignment(Qt.AlignCenter)
            empty.setMinimumHeight(120)
            self.rows.insertWidget(0, empty)
        self.refresh()

    def _row(self, a):
        row = QFrame()
        row.setCursor(Qt.PointingHandCursor)
        row.setStyleSheet(f"QFrame {{ background: {self.theme.rgba('on_surface', 0.05)}; border-radius: 12px; }}")
        row.setFixedHeight(58)
        lay = QHBoxLayout(row)
        lay.setContentsMargins(14, 0, 8, 0)
        t = QLabel(f"{a['h']:02}:{a['m']:02}")
        t.setFont(self.theme.font(28, QFont.Weight.Thin))
        t.setStyleSheet("background: transparent")
        lay.addWidget(t)
        col = QVBoxLayout()
        col.setSpacing(0)
        name = QLabel(a["label"] or "Alarm")
        name.setStyleSheet("background: transparent; font-weight: 600")
        snoozed = a.get("snoozedTo", 0) > time.time() * 1000
        sub = dim(days_text(a["days"]) + (" · snoozed" if snoozed else ""), 10)
        sub.setStyleSheet("background: transparent")
        col.addWidget(name)
        col.addWidget(sub)
        lay.addLayout(col, 1)
        sw = QPushButton("On" if a["enabled"] else "Off")
        sw.setObjectName("chip")
        sw.setCheckable(True)
        sw.setChecked(a["enabled"])
        sw.setFixedWidth(46)
        sw.clicked.connect(lambda checked, aid=a["id"]: self.clock.update_alarm(aid, enabled=checked, snoozedTo=0))
        lay.addWidget(sw)
        row.mousePressEvent = lambda _e, a=a: self.edit(a)
        row.setGraphicsEffect(None)
        if not a["enabled"]:
            for w in (t, name):
                w.setStyleSheet(w.styleSheet() + f"; color: {self.theme.hex('on_surface_variant')}")
        return row


class SettingsPage(Page):
    def __init__(self, win):
        super().__init__(win)
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        host = QWidget()
        self.lay = QVBoxLayout(host)
        self.lay.setContentsMargins(0, 0, 6, 0)
        self.lay.setSpacing(6)
        scroll.setWidget(host)
        outer.addWidget(scroll)

        self.lay.addWidget(self._title("Alarm & timer tone"))
        self.tone_rows = []
        for tid, name, _ in BUILTIN_TONES:
            self._tone_row(tid, name, True)
        for tid, name in self.clock.system_tones:
            self._tone_row(tid, name, False)
        custom = QHBoxLayout()
        self.custom_lbl = QLabel()
        custom.addWidget(self.custom_lbl, 1)
        self.custom_play = IconButton(self.theme, "play", 26, "Preview")
        self.custom_play.clicked.connect(lambda: self.clock.preview(self.clock.settings["tone"]))
        custom.addWidget(self.custom_play)
        choose = button("Choose")
        choose.clicked.connect(self._choose)
        custom.addWidget(choose)
        self.lay.addLayout(custom)

        self.lay.addWidget(self._title("Volume"))
        self.vol = QSlider(Qt.Horizontal)
        self.vol.setRange(0, 100)
        self.vol.setValue(int(self.clock.settings["volume"]))
        self.vol.valueChanged.connect(lambda v: self.clock.set_setting("volume", v))
        self.lay.addWidget(self.vol)

        self.snooze = self._stepper("Snooze for", "min", "snoozeMin", 1, 1, 30)
        self.ring = self._stepper('Ring for (then "missed")', "s", "ringSec", 15, 15, 600)
        note = dim("Alarms and timers keep running while this window is closed. "
                   "While one rings: Stop, or Snooze / +1 min, here or in the notification.", 10)
        note.setWordWrap(True)
        self.lay.addWidget(note)
        self.lay.addStretch()

    def _title(self, text):
        lbl = QLabel(text)
        lbl.setStyleSheet("font-weight: 700; margin-top: 6px")
        return lbl

    def _tone_row(self, tid, name, builtin):
        row = QHBoxLayout()
        b = QPushButton(name + ("   · built-in" if builtin else ""))
        b.setCheckable(True)
        b.setObjectName("chip")
        b.setStyleSheet("text-align: left; padding: 7px 10px; font-size: 12px;")
        b.setCursor(Qt.PointingHandCursor)
        b.clicked.connect(lambda _=False, tid=tid: self.clock.set_setting("tone", tid))
        play = IconButton(self.theme, "play", 26, "Preview")
        play.clicked.connect(lambda _=False, tid=tid: self.clock.preview(tid))
        row.addWidget(b, 1)
        row.addWidget(play)
        self.lay.addLayout(row)
        self.tone_rows.append((tid, b, play))

    def _stepper(self, title, unit, key, step, lo, hi):
        row = QHBoxLayout()
        row.addWidget(QLabel(title), 1)
        minus = IconButton(self.theme, "minus", 26)
        val = QLabel()
        val.setFixedWidth(56)
        val.setAlignment(Qt.AlignCenter)
        plus = IconButton(self.theme, "plus", 26)
        minus.clicked.connect(lambda: self.clock.set_setting(key, max(lo, int(self.clock.settings[key]) - step)))
        plus.clicked.connect(lambda: self.clock.set_setting(key, min(hi, int(self.clock.settings[key]) + step)))
        for w in (minus, val, plus):
            row.addWidget(w)
        self.lay.addLayout(row)
        return (val, key, unit)

    def _choose(self):
        path, _ = QFileDialog.getOpenFileName(self, "Alarm tone", os.path.expanduser("~/Music"),
                                              "Audio (*.mp3 *.ogg *.oga *.opus *.wav *.flac *.m4a)")
        if path:
            self.clock.set_setting("tone", path)

    def rebuild(self):
        c = self.clock
        tone = c.settings["tone"]
        known = False
        for tid, b, play in self.tone_rows:
            b.setChecked(tid == tone)
            known |= tid == tone
            play.set_icon("volume_high" if c.previewing == tid else "play")
        self.custom_lbl.setText(("✓  " + os.path.basename(tone)) if not known else "Your own sound file…")
        self.custom_play.setVisible(not known)
        for val, key, unit in (self.snooze, self.ring):
            val.setText(f"{c.settings[key]} {unit}")


class RingingView(QWidget):
    def __init__(self, win):
        super().__init__()
        self.win, self.clock, self.theme = win, win.clock, win.theme
        lay = QVBoxLayout(self)
        lay.addStretch()
        self.icon = Glyph(self.theme, "alarm", 56)
        lay.addWidget(self.icon)
        self.title = QLabel()
        self.title.setAlignment(Qt.AlignCenter)
        self.title.setFont(self.theme.font(24, QFont.Weight.Light))
        lay.addWidget(self.title)
        self.sub = dim(size=12)
        self.sub.setAlignment(Qt.AlignCenter)
        lay.addWidget(self.sub)
        row = QHBoxLayout()
        row.addStretch()
        self.second = button("")
        self.second.clicked.connect(self._second)
        stop = button("Stop", primary=True)
        stop.setMinimumHeight(40)
        stop.clicked.connect(self.clock.stop_ringing)
        row.addWidget(self.second)
        row.addWidget(stop)
        row.addStretch()
        lay.addLayout(row)
        lay.addStretch()
        self._pulse = QTimer(self, interval=420)
        self._pulse.timeout.connect(self._blink)
        self._on = True

    def _second(self):
        r = self.clock.ringing
        if r and r["kind"] == "alarm":
            self.clock.snooze()
        else:
            self.clock.timer_again(60000)

    def _blink(self):
        self._on = not self._on
        col = self.theme.accent if self._on else self.theme.c("on_surface_variant")
        self.icon.setStyleSheet(f"color: {col.name()}")

    def rebuild(self):
        r = self.clock.ringing
        if not r:
            self._pulse.stop()
            return
        self.icon.setText(ico("timer_sand_complete" if r["kind"] == "timer" else "alarm"))
        self.title.setText(r["title"])
        self.sub.setText(r["sub"])
        self.second.setText(f"Snooze {self.clock.settings['snoozeMin']} min" if r["kind"] == "alarm" else "+1 min")
        self._pulse.start()


# -------------------------------------------------------------------- window --
class ClockWindow(QWidget):
    def __init__(self, clock, theme):
        super().__init__()
        self.clock, self.theme = clock, theme
        self.setObjectName("root")
        self.setWindowTitle("Prism Clock")
        self.setWindowFlag(Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_StyledBackground)

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # header: drag to move; pin / mini / close
        self.header = QWidget()
        self.header.setFixedHeight(42)
        self.header.setCursor(Qt.OpenHandCursor)
        hl = QHBoxLayout(self.header)
        hl.setContentsMargins(14, 0, 6, 0)
        hl.setSpacing(2)
        self.grip = Glyph(theme, "drag_horizontal_variant", 15)
        self.grip.setObjectName("dim")
        hl.addWidget(self.grip)
        self.title = QLabel("Clock")
        self.title.setStyleSheet("font-weight: 700; margin-left: 6px")
        hl.addWidget(self.title)
        # mini: the big readout lives in the header row
        self.mini_text = QLabel()
        self.mini_sub = dim(size=10)
        hl.addWidget(self.mini_text)
        hl.addWidget(self.mini_sub)
        hl.addStretch()
        self.mini_go = IconButton(theme, "pause", 28, "Pause / resume")
        self.mini_go.clicked.connect(self._mini_toggle_running)
        hl.addWidget(self.mini_go)
        self.pin = IconButton(theme, "pin", 28)
        self.pin.clicked.connect(self.toggle_pin)
        hl.addWidget(self.pin)
        self.mini_btn = IconButton(theme, "arrow_collapse", 28)
        self.mini_btn.clicked.connect(self.toggle_mini)
        hl.addWidget(self.mini_btn)
        close = IconButton(theme, "close", 28, "Close (keeps running)")
        close.clicked.connect(self.hide_window)
        hl.addWidget(close)
        root.addWidget(self.header)
        self.header.mousePressEvent = self._drag
        self.header.mouseDoubleClickEvent = lambda _e: self.toggle_mini()

        # tabs
        self.tabs_box = QWidget()
        tl = QHBoxLayout(self.tabs_box)
        tl.setContentsMargins(12, 0, 12, 0)
        tl.setSpacing(4)
        self.tab_btns = {}
        for tid, icon, tip in TABS:
            b = IconButton(theme, icon, 30, tip, "tab")
            b.setCheckable(True)
            b.setFixedWidth(52)
            b.clicked.connect(lambda _=False, tid=tid: self.set_tab(tid))
            tl.addWidget(b)
            self.tab_btns[tid] = b
        root.addWidget(self.tabs_box)

        # pages / ringing
        self.body = QStackedWidget()
        self.pages = {"clock": ClockPage(self), "timer": TimerPage(self), "stopwatch": StopwatchPage(self),
                      "alarms": AlarmsPage(self), "settings": SettingsPage(self)}
        self.page_stack = QStackedWidget()
        for p in self.pages.values():
            p.layout().setContentsMargins(0, 0, 0, 0)
            wrap = QWidget()
            wl = QVBoxLayout(wrap)
            wl.setContentsMargins(16, 12, 16, 16)
            wl.addWidget(p)
            self.page_stack.addWidget(wrap)
        self.ringing = RingingView(self)
        self.body.addWidget(self.page_stack)
        self.body.addWidget(self.ringing)
        root.addWidget(self.body, 1)

        self.ticker = QTimer(self)
        self.ticker.timeout.connect(self.tick)
        clock.changed.connect(self.rebuild)
        clock.ringing_changed.connect(self._on_ringing)
        theme.changed.connect(self.restyle)
        self.restyle()
        self.apply_mode()

    # ---- look ----
    def restyle(self):
        # the app font in code, not the stylesheet: a stylesheet font would override
        # every setFont (icon glyphs, the thin big numbers)
        from PySide6.QtWidgets import QApplication
        QApplication.instance().setFont(self.theme.font(12))
        self.setStyleSheet(self.theme.qss())
        self.mini_text.setFont(self.theme.font(22, QFont.Weight.Thin))
        self.rebuild()

    def apply_mode(self):
        mini = self.clock.mini
        self.setFixedSize(MW, MH) if mini else self.setFixedSize(W, H)
        self.header.setFixedHeight(MH if mini else 42)
        for w in (self.grip, self.title, self.pin):
            w.setVisible(not mini)
        self.tabs_box.setVisible(not mini)
        self.body.setVisible(not mini)
        self.mini_text.setVisible(mini)
        self.mini_btn.set_icon("arrow_expand" if mini else "arrow_collapse")
        self.mini_btn.setToolTip("Expand" if mini else "Mini")
        self.rebuild()

    def rebuild(self):
        c = self.clock
        for tid, b in self.tab_btns.items():
            b.setChecked(c.tab == tid)
        self.page_stack.setCurrentIndex(list(self.pages).index(c.tab) if c.tab in self.pages else 0)
        self.body.setCurrentIndex(1 if c.ringing else 0)
        self.pin.set_icon("pin" if c.pinned else "pin_off_outline")
        self.pin.setToolTip("Pinned: on every workspace (click: this workspace only)" if c.pinned
                            else "This workspace only (click: pin to every workspace)")
        self.pages[c.tab].rebuild() if c.tab in self.pages else None
        self.ringing.rebuild()
        self.tick()
        self._set_tick_rate()

    def _set_tick_rate(self):
        c = self.clock
        if not self.isVisible():
            self.ticker.stop()
            return
        fast = c.sw_running and (c.mini or c.tab == "stopwatch")
        self.ticker.start(50 if fast else 250 if c.timer_running or c.tab == "clock" else 1000)

    def tick(self):
        c = self.clock
        if c.mini:
            # the mini readout shows what's running: timer, else stopwatch, else the time
            if c.ringing:
                text, sub, running = c.ringing["title"], "", None
            elif c.timer_running or c.timer_paused:
                text, sub, running = hms(c.timer_left() / 1000), "timer" + (" · paused" if c.timer_paused else ""), c.timer_running
            elif c.sw_running or c.sw_banked > 0:
                text, sub, running = hmsc(c.sw_elapsed()), "stopwatch" if c.sw_running else "stopwatch · paused", c.sw_running
            else:
                text, sub, running = time.strftime("%H:%M:%S"), "", None
            self.mini_text.setText(text)
            self.mini_sub.setText(sub)
            self.mini_sub.setVisible(bool(sub))
            self.mini_go.setVisible(running is not None)
            if running is not None:
                self.mini_go.set_icon("pause" if running else "play")
        else:
            self.mini_sub.hide()
            self.mini_go.hide()
            page = self.pages.get(c.tab)
            if page and not c.ringing:
                page.refresh()

    def _mini_toggle_running(self):
        c = self.clock
        if c.timer_running:
            c.timer_pause()
        elif c.timer_paused:
            c.timer_start()
        else:
            c.sw_toggle()

    # ---- actions ----
    def set_tab(self, tid):
        self.clock.tab = tid
        self.clock.changed.emit()

    def toggle_mini(self):
        self.clock.mini = not self.clock.mini
        self.apply_mode()
        self.clock.changed.emit()
        if _hypr() and self.isVisible():
            w = _my_window()
            if w:
                size = (MW, MH) if self.clock.mini else (W, H)
                _hyprctl("dispatch", f'hl.dsp.window.resize({{ x = {size[0]}, y = {size[1]}, exact = true, window = "address:{w["address"]}" }})')

    def toggle_pin(self):
        self.clock.pinned = not self.clock.pinned
        self.clock.changed.emit()
        if _hypr() and self.isVisible():
            w = _my_window()
            if w:
                act = "enable" if self.clock.pinned else "disable"
                _hyprctl("dispatch", f'hl.dsp.window.pin({{ action = "{act}", window = "address:{w["address"]}" }})')

    def _drag(self, e):
        if e.button() == Qt.LeftButton and self.windowHandle():
            self.windowHandle().startSystemMove()

    def keyPressEvent(self, e):
        if e.key() == Qt.Key_Escape:
            self.hide_window()

    def closeEvent(self, e):
        e.ignore()
        self.hide_window()

    # ---- show / hide ----
    def _register_rule(self):
        """Float, our size and the remembered position; pinned if pin mode is on."""
        if not _hypr():
            return
        c = self.clock
        size = (MW, MH) if c.mini else (W, H)
        parts = ['name = "prism-clock"', 'match = { class = "^(prism-clock)$" }', "float = true",
                 'opacity = "1.0 override"',
                 f'size = "{size[0]} {size[1]}"', f"pin = {'true' if c.pinned else 'false'}"]
        x, y = c.win_x, c.win_y
        if x < 0 or y < 0:
            # first time: top-right of the focused monitor, under the bar
            try:
                mon = next(m for m in json.loads(_hyprctl("monitors", "-j") or "[]") if m.get("focused"))
                x = mon["x"] + int(mon["width"] / mon.get("scale", 1)) - size[0] - 20
                y = mon["y"] + 64
            except (StopIteration, ValueError, KeyError):
                x, y = 1580, 64
        parts.append(f'move = "{int(x)} {int(y)}"')
        _hyprctl("eval", "hl.window_rule({ " + ", ".join(parts) + " })")

    def show_window(self):
        if self.isVisible():
            self.raise_()
            self.activateWindow()
            return
        self._register_rule()
        self.clock.visible = True
        self.apply_mode()
        self.show()
        self.raise_()
        self.activateWindow()
        self.clock.changed.emit()

    def hide_window(self):
        if not self.isVisible():
            return
        if _hypr():
            w = _my_window()
            if w and w.get("floating"):
                self.clock.win_x, self.clock.win_y = w["at"]
        self.hide()
        self.clock.visible = False
        self.ticker.stop()
        self.clock.changed.emit()

    def toggle_window(self):
        self.hide_window() if self.isVisible() else self.show_window()

    def _on_ringing(self):
        if self.clock.ringing:
            self.show_window()
        self.rebuild()
