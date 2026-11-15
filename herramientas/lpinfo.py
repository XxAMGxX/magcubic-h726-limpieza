#!/usr/bin/env python3
"""Lee los metadatos de particiones dinámicas (liblp) de un super.raw y lista particiones y extensiones.
   lpinfo.py <super.raw> [--extract nombre fichero]   (solo particiones con una única extensión lineal)"""
import struct, sys

def main():
    f = open(sys.argv[1], 'rb')
    f.seek(4096)
    g = f.read(4096)
    magic, gsize = struct.unpack_from('<II', g, 0)
    assert magic == 0x616c4467, hex(magic)
    meta_max, slots, lblock = struct.unpack_from('<III', g, 40)
    f.seek(4096 + 2 * 4096)           # primera copia de metadatos (slot 0)
    h = f.read(4096)
    m, maj, mino, hsize = struct.unpack_from('<IHHI', h, 0)
    assert m == 0x414C5030, hex(m)
    tables_size = struct.unpack_from('<I', h, 44)[0]
    # descriptores de tabla: partitions, extents, groups, block_devices (offset, num, entry_size) desde 80
    desc = [struct.unpack_from('<III', h, 80 + 12 * i) for i in range(4)]
    f.seek(4096 + 2 * 4096 + hsize)
    t = f.read(tables_size)
    parts = []
    for i in range(desc[0][1]):
        o = desc[0][0] + i * desc[0][2]
        name = t[o:o + 36].split(b'\0')[0].decode()
        attr, fe, ne, gi = struct.unpack_from('<IIII', t, o + 36)
        parts.append((name, fe, ne))
    exts = []
    for i in range(desc[1][1]):
        o = desc[1][0] + i * desc[1][2]
        ns, tt, td, ts = struct.unpack_from('<QIQI', t, o)
        exts.append((ns, tt, td))
    for name, fe, ne in parts:
        e = exts[fe:fe + ne]
        if len(sys.argv) > 2: continue
        print(f"{name:20s} extensiones={ne} " + ' '.join(f"[sector {x[2]} x {x[0]} = {x[0]*512/1e6:.1f} MB]" for x in e))
    if len(sys.argv) > 3 and sys.argv[2] == '--offset':
        name, fe, ne = next(p for p in parts if p[0] == sys.argv[3])
        assert ne == 1, 'más de una extensión'
        ns, tt, td = exts[fe]
        print(td * 512, ns * 512)
        return
    if len(sys.argv) > 3 and sys.argv[2] == '--extract':
        want, out = sys.argv[3], sys.argv[4]
        name, fe, ne = next(p for p in parts if p[0] == want)
        assert ne == 1, 'más de una extensión'
        ns, tt, td = exts[fe]
        f.seek(td * 512)
        with open(out, 'wb') as o:
            left = ns * 512
            while left:
                b = f.read(min(left, 1 << 24)); o.write(b); left -= len(b)
        print('extraída', want, 'offset', td * 512, 'bytes', ns * 512)

main()
