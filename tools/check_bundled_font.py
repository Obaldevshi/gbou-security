"""Read-only cmap/name evidence for the unmodified SDK Roboto font."""
from pathlib import Path
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
b = (ROOT / 'init-app/assets/fonts/Roboto-Regular.ttf').read_bytes()
tables = {}
for i in range(struct.unpack_from('>H', b, 4)[0]):
    tag, _, offset, size = struct.unpack_from('>4sIII', b, 12 + i*16)
    tables[tag] = (offset, size)
offset = tables[b'cmap'][0]
subs = [offset + struct.unpack_from('>HHI', b, offset+4+i*8)[2]
        for i in range(struct.unpack_from('>H', b, offset+2)[0])]
f = next(s for s in subs if struct.unpack_from('>H', b, s)[0] == 4)
n = struct.unpack_from('>H', b, f+6)[0]//2
ends = struct.unpack_from('>'+str(n)+'H', b, f+14)
starts = struct.unpack_from('>'+str(n)+'H', b, f+16+2*n)
deltas = struct.unpack_from('>'+str(n)+'h', b, f+16+4*n)
roff = f+16+6*n
ranges = struct.unpack_from('>'+str(n)+'H', b, roff)
def glyph(c):
    for i, (start, end) in enumerate(zip(starts, ends)):
        if start<=c<=end:
            if not ranges[i]: return (c+deltas[i]) & 0xffff
            index = struct.unpack_from('>H', b, roff+2*i+ranges[i]+2*(c-start))[0]
            return ((index+deltas[i]) & 0xffff) if index else 0
    return 0
assert all(glyph(c) for c in range(0x410, 0x450))
assert all(glyph(c) for c in map(ord,'Ёё№—…'))
missing = {}
for p in (ROOT/'init-app/lib').rglob('*'):
    if p.suffix not in {'.dart','.arb'}: continue
    for c in set(p.read_text(encoding='utf8')):
        if ord(c)>=128 and not glyph(ord(c)):
            missing.setdefault(f'U+{ord(c):04X} {c}',[]).append(str(p.relative_to(ROOT)))
print(json.dumps({'cyrillic':True,'missing_source_characters':missing},ensure_ascii=True))
