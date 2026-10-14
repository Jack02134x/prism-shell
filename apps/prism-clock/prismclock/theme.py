"""Prism's look: the live palette (.state/palette.json), fonts and icon glyphs."""

import codecs
import json
import re

from PySide6.QtCore import QFileSystemWatcher, QObject, QTimer, Signal
from PySide6.QtGui import QColor, QFont, QFontDatabase

from .core import SHELL_DIR

PALETTE_FILE = SHELL_DIR / ".state" / "palette.json"
ICONS_FILE = SHELL_DIR / "common" / "Icons.qml"

# used when Prism isn't installed / hasn't written a palette yet
FALLBACK = {
    "mode": "dark",
    "colors": {
        "surface": "#111318", "surface_container": "#1d2024", "surface_container_high": "#272a2f",
        "on_surface": "#e1e2e8", "on_surface_variant": "#c4c6d0", "outline": "#8e9099",
        "outline_variant": "#43474e", "primary": "#a8c8ff", "on_primary": "#0b305f", "error": "#ffb4ab",
    },
    "accents": ["#a8c8ff", "#e0b0ff", "#ffb4ab", "#9ccfd8", "#f6c177"],
    "gradient": ["#a8c8ff", "#e0b0ff", "#9ccfd8"],
    "fonts": {"ui": "Adwaita Sans", "mono": "Adwaita Mono", "icons": "Symbols Nerd Font"},
}


def _load_icons():
    """name -> glyph, from Prism's generated Icons.qml (scripts/gen-icons.py)."""
    out = {}
    try:
        text = ICONS_FILE.read_text()
    except OSError:
        return out
    for name, esc in re.findall(r'"([a-z0-9_]+)":\s*"((?:\\u[0-9A-Fa-f]{4})+)"', text):
        raw = codecs.decode(esc, "unicode_escape")
        out[name] = raw.encode("utf-16", "surrogatepass").decode("utf-16")
    return out


_ICONS = _load_icons()


def ico(name):
    """Glyph for a Material Design icon name (as in Prism). gen-icons.py collects ico("...") calls."""
    return _ICONS.get(name, "")


class Theme(QObject):
    changed = Signal()

    def __init__(self):
        super().__init__()
        self.data = FALLBACK
        self._watch = QFileSystemWatcher(self)
        # watch the folder: the palette is replaced atomically (rename), which drops file watches
        if PALETTE_FILE.parent.is_dir():
            self._watch.addPath(str(PALETTE_FILE.parent))
        self._debounce = QTimer(self, singleShot=True, interval=150)
        self._debounce.timeout.connect(self.reload)
        self._watch.directoryChanged.connect(lambda _: self._debounce.start())
        self._last = ""
        self.reload()

    def reload(self):
        try:
            text = PALETTE_FILE.read_text()
            if text == self._last:
                return
            data = json.loads(text)
            if not isinstance(data.get("colors"), dict):
                return
            self._last = text
            merged = dict(FALLBACK)
            merged.update(data)
            merged["colors"] = {**FALLBACK["colors"], **data["colors"]}
            self.data = merged
        except (OSError, ValueError):
            return
        self.changed.emit()

    # ---- helpers ----
    def c(self, role, alpha=None):
        col = QColor(self.data["colors"].get(role, FALLBACK["colors"].get(role, "#ff00ff")))
        if alpha is not None:
            col.setAlphaF(alpha)
        return col

    def hex(self, role):
        return self.data["colors"].get(role, FALLBACK["colors"].get(role, "#ff00ff"))

    def rgba(self, role, alpha):
        col = self.c(role)
        return f"rgba({col.red()},{col.green()},{col.blue()},{alpha})"

    @property
    def accent(self):
        g = self.data.get("gradient") or FALLBACK["gradient"]
        return QColor(g[0])

    def accent_hex(self):
        return self.accent.name()

    @property
    def light(self):
        return self.data.get("mode") == "light"

    def font(self, size, weight=QFont.Weight.Normal, mono=False):
        fam = self.data.get("fonts", {}).get("mono" if mono else "ui", "Sans")
        f = QFont(fam if fam in QFontDatabase.families() else ("Monospace" if mono else "Sans"))
        f.setPixelSize(int(size))
        f.setWeight(weight)
        return f

    def icon_font(self, size):
        f = QFont(self.data.get("fonts", {}).get("icons", "Symbols Nerd Font"))
        f.setPixelSize(int(size))
        return f

    def qss(self):
        """Stylesheet for the whole window."""
        acc = self.accent_hex()
        on_acc = "#101418" if self.accent.lightnessF() > 0.55 else "#f4f7f6"
        return f"""
        QWidget {{ color: {self.hex('on_surface')}; }}
        #root {{ background: {self.hex('surface_container')}; }}
        QLabel#dim {{ color: {self.hex('on_surface_variant')}; }}
        QPushButton {{ background: {self.rgba('on_surface', 0.07)}; border: none; border-radius: 14px; padding: 6px 14px; }}
        QPushButton:hover {{ background: {self.rgba('on_surface', 0.12)}; }}
        QPushButton:checked, QPushButton#primary {{ background: {acc}; color: {on_acc}; font-weight: 600; }}
        QPushButton#primary:hover {{ background: {QColor(acc).lighter(110).name()}; }}
        QPushButton#icon {{ background: transparent; border-radius: 15px; padding: 0; }}
        QPushButton#icon:hover {{ background: {self.rgba('on_surface', 0.1)}; }}
        QPushButton#tab {{ border-radius: 10px; padding: 0; background: {self.rgba('on_surface', 0.05)}; }}
        QPushButton#tab:checked {{ background: {self.hex('primary')}; color: {self.hex('on_primary')}; }}
        QPushButton#chip {{ border-radius: 12px; padding: 5px 10px; min-height: 16px; font-size: 11px; }}
        QPushButton#chip:checked {{ background: {self.rgba('primary', 0.25)}; color: {self.hex('on_surface')}; border: 1px solid {acc}; }}
        QPushButton#day {{ border-radius: 15px; padding: 0; font-weight: 700; font-size: 11px; }}
        QPushButton#danger {{ background: {self.rgba('error', 0.15)}; color: {self.hex('error')}; }}
        QLineEdit {{ background: {self.rgba('on_surface', 0.06)}; border: 1px solid {self.hex('outline_variant')};
                     border-radius: 10px; padding: 6px 10px; selection-background-color: {acc}; }}
        QLineEdit:focus {{ border-color: {acc}; }}
        QScrollArea, QScrollArea > QWidget > QWidget {{ background: transparent; border: none; }}
        QScrollBar:vertical {{ width: 6px; background: transparent; }}
        QScrollBar::handle:vertical {{ background: {self.rgba('on_surface', 0.2)}; border-radius: 3px; min-height: 20px; }}
        QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; }}
        QSlider::groove:horizontal {{ height: 6px; border-radius: 3px; background: {self.rgba('on_surface', 0.1)}; }}
        QSlider::sub-page:horizontal {{ border-radius: 3px; background: {acc}; }}
        QSlider::handle:horizontal {{ width: 16px; margin: -5px 0; border-radius: 8px; background: {acc}; }}
        QListWidget {{ background: transparent; border: none; outline: none; }}
        QListWidget::item {{ padding: 0; border: none; }}
        QToolTip {{ background: {self.hex('surface_container_high')}; color: {self.hex('on_surface')};
                    border: 1px solid {self.hex('outline_variant')}; padding: 4px 8px; border-radius: 6px; }}
        """
