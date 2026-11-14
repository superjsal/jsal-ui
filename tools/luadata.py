"""Reads a Lua table literal as data (never runs it): tables, numbers, strings, true/false/nil.
Tables come back as dicts keyed by position (1..n) or by their [key] / name."""
import re

_num = re.compile(r"-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)")
_name = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


class Reader:
    def __init__(self, text, pos=0):
        self.t, self.i = text, pos

    def ws(self):
        t, n = self.t, len(self.t)
        while self.i < n:
            c = t[self.i]
            if c in " \t\r\n,;":
                self.i += 1
            elif t.startswith("--", self.i):
                if t.startswith("--[[", self.i):
                    self.i = t.index("]]", self.i) + 2
                else:
                    e = t.find("\n", self.i)
                    self.i = n if e < 0 else e + 1
            else:
                break

    def value(self):
        self.ws()
        t, c = self.t, self.t[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string(c)
        if t.startswith("[[", self.i) or t.startswith("[=", self.i):
            return self.long_string()
        m = _num.match(t, self.i)
        if m:
            self.i = m.end()
            s = m.group()
            return int(s, 16) if "x" in s.lower() else (float(s) if any(ch in s for ch in ".eE") else int(s))
        m = _name.match(t, self.i)
        if m:
            self.i = m.end()
            w = m.group()
            if w in ("true", "false", "nil"):
                return {"true": True, "false": False, "nil": None}[w]
            raise ValueError(f"unexpected name {w!r} at {self.i}")
        raise ValueError(f"unexpected {c!r} at {self.i}")

    def string(self, q):
        out, t = [], self.t
        self.i += 1
        while t[self.i] != q:
            if t[self.i] == "\\":
                nxt = t[self.i + 1]
                out.append({"n": "\n", "t": "\t", "r": "\r"}.get(nxt, nxt))
                self.i += 2
            else:
                out.append(t[self.i])
                self.i += 1
        self.i += 1
        return "".join(out)

    def long_string(self):
        m = re.compile(r"\[(=*)\[").match(self.t, self.i)
        close = "]" + m.group(1) + "]"
        e = self.t.index(close, m.end())
        s = self.t[m.end():e]
        self.i = e + len(close)
        return s

    def table(self):
        self.i += 1
        out, n = {}, 0
        while True:
            self.ws()
            if self.t[self.i] == "}":
                self.i += 1
                return out
            if self.t[self.i] == "[" and not self.t.startswith("[[", self.i):
                self.i += 1
                k = self.value()
                self.ws()
                assert self.t[self.i] == "]", self.i
                self.i += 1
                self.ws()
                assert self.t[self.i] == "=", self.i
                self.i += 1
                out[k] = self.value()
                continue
            m = _name.match(self.t, self.i)
            if m and m.group() not in ("true", "false", "nil"):
                j = m.end()
                while j < len(self.t) and self.t[j] in " \t":
                    j += 1
                if j < len(self.t) and self.t[j] == "=" and self.t[j + 1] != "=":
                    self.i = j + 1
                    out[m.group()] = self.value()
                    continue
            n += 1
            v = self.value()
            if v is not None:
                out[n] = v


def table_after(text, marker):
    """The table literal that follows `marker` in text (e.g. 'questData = [[return' or '= ')."""
    i = text.index(marker) + len(marker)
    i = text.index("{", i)
    return Reader(text, i).value()


def seq(t):
    """A Lua sequence table as a Python list."""
    if not isinstance(t, dict):
        return []
    return [t[k] for k in sorted(k for k in t if isinstance(k, int))]
