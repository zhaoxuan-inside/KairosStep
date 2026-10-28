#!/usr/bin/env python3
"""Extract embedded data from AdviceInteractiveDemo.html into JSON assets for the Flutter app."""
import re, json, os

HTML = '/home/hardstone/Share/Common/CodeSpace/KairosStep/docs/AdviceInteractiveDemo.html'
OUT = '/home/hardstone/Share/Common/CodeSpace/KairosStep/app/assets/data'
os.makedirs(OUT, exist_ok=True)
html = open(HTML, encoding='utf-8').read()

# ---------- minimal JS-literal parser ----------
class P:
    def __init__(self, s): self.s, self.i = s, 0
    def ws(self):
        while self.i < len(self.s) and self.s[self.i] in ' \t\r\n': self.i += 1
    def parse(self):
        self.ws()
        c = self.s[self.i]
        if c == '{': return self.obj()
        if c == '[': return self.arr()
        if c in "'\"": return self.str()
        if c == '/' and self.s[self.i+1] == '/':
            nl = self.s.find('\n', self.i); self.i = nl + 1; return self.parse()
        m = re.match(r'true|false|null|-\d+|\d+(?:\.\d+)?', self.s[self.i:])
        if m:
            t = m.group(0); self.i += len(t)
            return {'true': True, 'false': False, 'null': None}.get(t, json.loads(t))
        raise ValueError(f'unexpected {c!r} at {self.i}: ...{self.s[self.i-40:self.i+60]!r}')
    def obj(self):
        self.i += 1; out = {}
        self.ws()
        while self.s[self.i] != '}':
            self.ws()
            if self.s[self.i] == ',': self.i += 1; continue
            m = re.match(r'\'([^\']*)\'|"([^"]*)"|([A-Za-z_$][\w$]*|\d+)', self.s[self.i:])
            key = m.group(1) or m.group(2) or m.group(3)
            self.i += m.end()
            self.ws(); assert self.s[self.i] == ':', f'expect : at {self.i}'
            self.i += 1
            out[key] = self.parse()
            self.ws()
        self.i += 1; return out
    def arr(self):
        self.i += 1; out = []
        self.ws()
        while self.s[self.i] != ']':
            self.ws()
            if self.s[self.i] == ',': self.i += 1; continue
            out.append(self.parse()); self.ws()
        self.i += 1; return out
    def str(self):
        q = self.s[self.i]; self.i += 1; buf = []
        while self.s[self.i] != q:
            ch = self.s[self.i]
            if ch == '\\':
                nxt = self.s[self.i+1]
                if nxt == 'n': buf.append('\n'); self.i += 2
                elif nxt == 't': buf.append('\t'); self.i += 2
                elif nxt == '\\': buf.append('\\'); self.i += 2
                elif nxt == q: buf.append(q); self.i += 2
                elif nxt == 'u':
                    buf.append(chr(int(self.s[self.i+2:self.i+6], 16))); self.i += 6
                else: buf.append(nxt); self.i += 2
            else: buf.append(ch); self.i += 1
        self.i += 1; return ''.join(buf)

def grab_const(name, kind='auto'):
    """Grab `const NAME = <literal>` handling nested braces via the parser."""
    m = re.search(r'const ' + name + r'\s*=\s*', html)
    assert m, name
    p = P(html[m.end():])
    v = p.parse()
    return v

data = {}
data['advice'] = grab_const('ALL_ENRICHED_ADVICE')
print('advice:', len(data['advice']))
data['detail'] = grab_const('ADVICE_DETAIL')
print('detail:', len(data['detail']))
try:
    data['node_packages'] = grab_const('HEALTH_NODE_PACKAGES')
    print('node_packages:', len(data['node_packages']))
except AssertionError as e:
    print('node_packages missing:', e)
try:
    data['pinyin'] = grab_const('PINYIN_MAP')
    print('pinyin:', len(data['pinyin']))
except AssertionError as e:
    print('pinyin missing:', e)

for k, v in data.items():
    with open(os.path.join(OUT, k + '.json'), 'w', encoding='utf-8') as f:
        json.dump(v, f, ensure_ascii=False, separators=(',', ':'))
print('written to', OUT)
