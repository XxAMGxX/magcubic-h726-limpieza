#!/usr/bin/env python3
"""Allwinner IMAGEWTY (update.img) — list / extract / repack (formato v3 de cabeceras de 1024 bytes).
  awimg.py list <img>
  awimg.py extract <img> <dir>
  awimg.py repack <img_original> <dir> <img_nueva>   # reconstruye con los ficheros de <dir>,
        recalcula V*.fex (suma de palabras de 32 bits LE mod 2^32 del fichero pareja) y alinea a 1024.
"""
import os, struct, sys

HDR = 1024

def entries(buf):
    n = struct.unpack_from('<I', buf, 0x3c)[0]
    out = []
    for i in range(n):
        o = HDR + i * HDR
        fl, ths = struct.unpack_from('<II', buf, o)
        main = buf[o + 8:o + 16].decode('latin1').rstrip('\0 ')
        sub = buf[o + 16:o + 32].decode('latin1').rstrip('\0 ')
        name = buf[o + 0x24:o + 0x24 + 256].split(b'\0')[0].decode('latin1')
        stored, orig, off = (struct.unpack_from('<I', buf, o + x)[0] for x in (0x124, 0x12c, 0x134))
        out.append(dict(i=i, hoff=o, main=main, sub=sub, name=name, stored=stored, orig=orig, off=off))
    return out

def read_head(path):
    with open(path, 'rb') as f:
        h = f.read(HDR)
        n = struct.unpack_from('<I', h, 0x3c)[0]
        f.seek(0)
        return f.read(HDR + n * HDR)

def csum(data):
    pad = (-len(data)) % 4
    data = data + b'\0' * pad
    return sum(struct.unpack('<%dI' % (len(data) // 4), data)) & 0xffffffff

def main():
    cmd, img = sys.argv[1], sys.argv[2]
    head = read_head(img)
    es = entries(head)
    if cmd == 'list':
        for e in es:
            print(f"{e['i']:3d} {e['main']:8s} {e['sub']:16s} {e['name']:28s} orig={e['orig']:>11d} stored={e['stored']:>11d} off={e['off']:>11d}")
        last = max(es, key=lambda e: e['off'])
        print('fin del último:', last['off'] + last['stored'], ' tamaño fichero:', os.path.getsize(img),
              ' campo image_size(0x18):', struct.unpack_from('<I', head, 0x18)[0])
    elif cmd == 'extract':
        d = sys.argv[3]; os.makedirs(d, exist_ok=True)
        with open(img, 'rb') as f:
            for e in es:
                f.seek(e['off'])
                with open(os.path.join(d, e['name']), 'wb') as o:
                    left = e['orig']
                    while left:
                        b = f.read(min(left, 1 << 24)); o.write(b); left -= len(b)
    elif cmd == 'repack':
        d, out = sys.argv[3], sys.argv[4]
        names = {e['name'] for e in es}
        # recalcular V*.fex: 'Vxxx.fex' guarda la suma de 'xxx.fex'
        for e in es:
            if e['name'].startswith('V') and e['name'][1:] in names:
                with open(os.path.join(d, e['name'][1:]), 'rb') as f:
                    s = 0; rest = b''
                    while True:
                        b = f.read(1 << 24)
                        if not b: break
                        b = rest + b; cut = len(b) - len(b) % 4
                        s = (s + sum(struct.unpack('<%dI' % (cut // 4), b[:cut]))) & 0xffffffff
                        rest = b[cut:]
                    if rest: s = (s + csum(rest)) & 0xffffffff
                with open(os.path.join(d, e['name']), 'wb') as f:
                    f.write(struct.pack('<I', s))
        head = bytearray(head)
        off = min(e['off'] for e in es)
        with open(out, 'wb') as o:
            o.write(b'\0' * off)
            for e in sorted(es, key=lambda e: e['off']):
                p = os.path.join(d, e['name']); size = os.path.getsize(p)
                stored = e['stored'] if size == e['orig'] else (size + 15) // 16 * 16
                o.seek(off)
                with open(p, 'rb') as f:
                    while True:
                        b = f.read(1 << 24)
                        if not b: break
                        o.write(b)
                o.write(b'\0' * (stored - size))
                struct.pack_into('<I', head, e['hoff'] + 0x124, stored)
                struct.pack_into('<I', head, e['hoff'] + 0x12c, size)
                struct.pack_into('<I', head, e['hoff'] + 0x134, off)
                fin = off + stored
                off = (fin + 1023) // 1024 * 1024
            struct.pack_into('<I', head, 0x18, (fin + 1023) // 1024 * 1024)
            o.seek(0); o.write(head)
            o.truncate(fin)
            off = fin
        print('escrita', out, off, 'bytes')

if __name__ == '__main__':
    main()
