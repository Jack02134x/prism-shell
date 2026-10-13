pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    // seconds -> "3:07" or "1:02:33"
    function mmss(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0;
        sec = Math.floor(sec);
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const s = sec % 60;
        return h > 0 ? h + ":" + pad2(m) + ":" + pad2(s) : m + ":" + pad2(s);
    }

    // seconds -> "5h 12m" / "12m" / "40s"
    function human(sec) {
        sec = Math.max(0, Math.round(sec));
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        if (m > 0)
            return m + "m";
        return sec + "s";
    }

    function timeAgo(date) {
        const s = Math.floor((Date.now() - date.getTime()) / 1000);
        if (s < 10)
            return "now";
        if (s < 60)
            return s + "s ago";
        if (s < 3600)
            return Math.floor(s / 60) + "m ago";
        if (s < 86400)
            return Math.floor(s / 3600) + "h ago";
        return Math.floor(s / 86400) + "d ago";
    }

    function bytes(n) {
        const u = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) {
            n /= 1024;
            i++;
        }
        return (n >= 100 || i === 0 ? n.toFixed(0) : n.toFixed(1)) + u[i];
    }

    function rate(n) {
        return bytes(n) + "/s";
    }

    function escapeHtml(s) {
        return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function fileName(path) {
        return String(path).slice(String(path).lastIndexOf("/") + 1);
    }

    function stem(path) {
        return fileName(path).replace(/\.[^.]+$/, "");
    }

    function toUrl(path) {
        if (!path)
            return "";
        path = String(path);
        if (path.startsWith("/"))
            return "file://" + path;
        return path;
    }

    function greeting() {
        const h = new Date().getHours();
        if (h < 5)
            return "Still up";
        if (h < 12)
            return "Good morning";
        if (h < 17)
            return "Good afternoon";
        if (h < 22)
            return "Good evening";
        return "Good night";
    }

    function capitalize(s) {
        s = String(s ?? "");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // run a shell snippet detached; extra args become $1, $2, ...
    function sh(script, ...args) {
        Quickshell.execDetached(["sh", "-c", script, "prism"].concat(args.map(a => String(a))));
    }
}
