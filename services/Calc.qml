pragma Singleton

import QtQuick
import Quickshell

// Safe recursive-descent calculator: + - * / % ^, parentheses, constants
// (pi, e, tau) and functions (sqrt, sin, cos, tan, log, ln, abs, ...).
Singleton {
    id: root

    readonly property var funcs: ({
            sqrt: Math.sqrt,
            cbrt: Math.cbrt,
            sin: Math.sin,
            cos: Math.cos,
            tan: Math.tan,
            asin: Math.asin,
            acos: Math.acos,
            atan: Math.atan,
            log: Math.log10,
            ln: Math.log,
            log2: Math.log2,
            abs: Math.abs,
            floor: Math.floor,
            ceil: Math.ceil,
            round: Math.round,
            exp: Math.exp
        })
    readonly property var consts: ({
            pi: Math.PI,
            e: Math.E,
            tau: Math.PI * 2
        })

    function looksLikeMath(s) {
        s = String(s).trim();
        return /^[\d\s.+\-*/%^()x×÷,]+$/.test(s) && /\d/.test(s) && /[+\-*/%^x×÷]/.test(s.replace(/^-/, ""));
    }

    function evaluate(expr) {
        let s = String(expr).toLowerCase().replace(/×|x(?![a-z])/g, "*").replace(/÷/g, "/").replace(/,/g, "").replace(/\s+/g, "");
        let pos = 0;

        function fail() {
            throw new Error("bad");
        }
        function peek() {
            return s[pos];
        }
        function primary() {
            if (peek() === "(") {
                pos++;
                const v = sum();
                if (peek() !== ")")
                    fail();
                pos++;
                return v;
            }
            const num = s.slice(pos).match(/^(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/);
            if (num) {
                pos += num[0].length;
                return Number(num[0]);
            }
            const id = s.slice(pos).match(/^[a-z][a-z0-9]*/);
            if (id) {
                pos += id[0].length;
                if (root.consts[id[0]] !== undefined)
                    return root.consts[id[0]];
                const f = root.funcs[id[0]];
                if (!f)
                    fail();
                return f(unary());
            }
            fail();
        }
        function power() {
            let v = primary();
            if (peek() === "^") {
                pos++;
                v = Math.pow(v, unary());
            }
            return v;
        }
        function unary() {
            if (peek() === "+") {
                pos++;
                return unary();
            }
            if (peek() === "-") {
                pos++;
                return -unary();
            }
            return power();
        }
        function product() {
            let v = unary();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = s[pos++];
                const r = unary();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        }
        function sum() {
            let v = product();
            while (peek() === "+" || peek() === "-") {
                const op = s[pos++];
                const r = product();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }

        try {
            if (s.length === 0)
                return { ok: false, text: "Type an expression" };
            const v = sum();
            if (pos !== s.length || !isFinite(v))
                return { ok: false, text: "…" };
            const out = Number(v.toPrecision(12));
            return { ok: true, value: out, text: out.toLocaleString(Qt.locale("en_US"), "f", Math.min(10, (String(out).split(".")[1] ?? "").length)) };
        } catch (e) {
            return { ok: false, text: "…" };
        }
    }
}
