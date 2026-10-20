#!/usr/bin/env python3
"""Play a live (video) wallpaper with mpvpaper, sized for each monitor.

    live-wallpaper.py <video> [auto|integrated]

For every monitor it plays a copy of the video at the monitor's resolution
(never upscaled; scaled to cover the screen) and at most 60 fps (lower frame
rates are kept). Copies are made once, in the background, into Prism's cache:
the original plays straight away and the window swaps to the copy when it's
ready. A video that already fits is played as it is.

GPU: "auto" plays on the discrete GPU of a hybrid laptop (NVIDIA through PRIME
render offload, AMD / Mesa through DRI_PRIME); "integrated" always uses the main
one. Hardware decoding is on either way, and copies are encoded on NVENC when
there is an NVIDIA GPU.
"""

import hashlib
import json
import os
import subprocess
import sys
import time
from fractions import Fraction
from pathlib import Path

SHELL = Path(__file__).resolve().parents[1]
CACHE = SHELL / ".cache" / "live"
CURRENT = CACHE / "current.json"
MAX_FPS = 60
CACHE_LIMIT = 4 * 1024**3  # bytes; oldest copies go first
MPV_OPTS = "no-audio --loop-playlist --hwdec=auto-safe"


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30, **kw).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def has_nvidia():
    gpus = Path("/proc/driver/nvidia/gpus")
    return gpus.is_dir() and any(gpus.iterdir())


def gpu_env(mode):
    env = dict(os.environ)
    hybrid = len(list(Path("/dev/dri").glob("renderD*"))) > 1
    if mode == "auto" and hybrid:
        if has_nvidia() and Path("/usr/share/glvnd/egl_vendor.d/10_nvidia.json").exists():
            env.update({
                "__NV_PRIME_RENDER_OFFLOAD": "1",
                "__VK_LAYER_NV_optimus": "NVIDIA_only",
                "__GLX_VENDOR_LIBRARY_NAME": "nvidia",
                "__EGL_VENDOR_LIBRARY_FILENAMES": "/usr/share/glvnd/egl_vendor.d/10_nvidia.json",
            })
        else:
            env["DRI_PRIME"] = "1"
    return env


def monitors():
    """[(name, width, height)] in physical pixels; [] when not on Hyprland."""
    try:
        out = []
        for m in json.loads(run(["hyprctl", "monitors", "-j"]) or "[]"):
            w, h = m["width"], m["height"]
            if m.get("transform", 0) % 2:  # rotated 90 / 270
                w, h = h, w
            out.append((m["name"], w, h))
        return out
    except (ValueError, KeyError):
        return []


def probe(video):
    """(width, height, fps) of the first video stream."""
    out = run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
               "stream=width,height,avg_frame_rate,r_frame_rate", "-of", "json", str(video)])
    s = json.loads(out or "{}").get("streams", [{}])[0]
    fps = 0.0
    for key in ("avg_frame_rate", "r_frame_rate"):
        try:
            fps = float(Fraction(s.get(key, "0/0")))
        except (ValueError, ZeroDivisionError):
            fps = 0.0
        if fps > 0:
            break
    return s.get("width", 0), s.get("height", 0), fps


def target(src_w, src_h, fps, mon_w, mon_h):
    """Size that covers the monitor without upscaling, and the frame rate to use."""
    scale = max(mon_w / src_w, mon_h / src_h)
    if scale >= 1:
        w, h = src_w, src_h
    else:
        w, h = round(src_w * scale / 2) * 2, round(src_h * scale / 2) * 2
    return w, h, (MAX_FPS if fps > MAX_FPS + 0.5 else 0)  # 0 = keep the video's own rate


def cached_name(video, w, h, fps):
    st = video.stat()
    key = hashlib.sha1(f"{video.resolve()}|{st.st_size}|{int(st.st_mtime)}".encode()).hexdigest()[:12]
    return CACHE / f"{video.stem[:40]}-{key}-{w}x{h}{'-' + str(fps) if fps else ''}.mp4"


def encode(video, out, w, h, fps):
    """Make the sized copy; True when it worked."""
    vf = f"scale={w}:{h}:flags=lanczos" + (f",fps={fps}" if fps else "")
    encoders = run(["ffmpeg", "-hide_banner", "-encoders"])
    if has_nvidia() and "hevc_nvenc" in encoders:
        codec = ["-c:v", "hevc_nvenc", "-preset", "p5", "-rc", "vbr", "-cq", "23", "-b:v", "0"]
    else:
        codec = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "21"]
    tmp = out.with_name(out.name + ".part.mp4")
    cmd = ["nice", "-n", "15", "ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(video), "-an",
           "-vf", vf, *codec, "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(tmp)]
    try:
        ok = subprocess.run(cmd, timeout=3600).returncode == 0 and tmp.stat().st_size > 0
    except (OSError, subprocess.SubprocessError):
        ok = False
    if ok:
        os.replace(tmp, out)
    else:
        tmp.unlink(missing_ok=True)
    return ok


def prune():
    files = sorted((p for p in CACHE.glob("*.mp4") if not p.name.endswith(".part.mp4")),
                   key=lambda p: p.stat().st_atime)
    total = sum(p.stat().st_size for p in files)
    while files and total > CACHE_LIMIT:
        p = files.pop(0)
        total -= p.stat().st_size
        p.unlink(missing_ok=True)


def play(output, file, env):
    return subprocess.Popen(["mpvpaper", "-o", MPV_OPTS, output, str(file)], env=env,
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, start_new_session=True)


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 2
    video = Path(sys.argv[1]).expanduser()
    mode = sys.argv[2] if len(sys.argv) > 2 else "auto"
    env = gpu_env(mode)
    CACHE.mkdir(parents=True, exist_ok=True)
    token = f"{video}|{time.time()}"
    CURRENT.write_text(json.dumps({"source": str(video), "token": token}))

    mons = monitors()
    src_w, src_h, fps = probe(video)
    if not mons or not src_w or not src_h:
        play("ALL", video, env)  # can't tell: play it as it is everywhere
        return 0

    pending = []  # (monitor, process playing the original, copy to make, w, h, fps)
    for name, mw, mh in mons:
        w, h, out_fps = target(src_w, src_h, fps, mw, mh)
        if (w, h) == (src_w, src_h) and not out_fps:
            play(name, video, env)
            continue
        copy = cached_name(video, w, h, out_fps)
        if copy.exists():
            os.utime(copy)  # keep recently used copies when pruning
            play(name, copy, env)
        else:
            pending.append((name, play(name, video, env), copy, w, h, out_fps))

    # make the missing copies one at a time, then swap each monitor over
    for name, proc, copy, w, h, out_fps in pending:
        if not copy.exists() and not encode(video, copy, w, h, out_fps):
            continue
        try:
            still_current = json.loads(CURRENT.read_text()).get("token") == token
        except (OSError, ValueError):
            still_current = False
        if still_current and proc.poll() is None:  # same wallpaper, still playing
            fresh = play(name, copy, env)
            time.sleep(0.6)  # let the copy start before the original goes
            if fresh.poll() is None:
                proc.terminate()
            else:
                fresh = None
    prune()
    return 0


if __name__ == "__main__":
    sys.exit(main())
