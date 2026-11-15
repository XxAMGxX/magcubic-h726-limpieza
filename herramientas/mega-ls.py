#!/usr/bin/env python3
"""Lista una carpeta pública de MEGA (nombre, tamaño, handle) sin cuenta. Uso: mega-ls.py <enlace de carpeta>"""
import base64, json, struct, sys, urllib.request
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

def b64(s):
    s = s.replace('-', '+').replace('_', '/').replace(',', '')
    return base64.b64decode(s + '=' * (-len(s) % 4))

def aes_ecb_dec(key, data):
    d = Cipher(algorithms.AES(key), modes.ECB()).decryptor()
    return d.update(data) + d.finalize()

def aes_cbc_dec(key, data):
    d = Cipher(algorithms.AES(key), modes.CBC(b'\0' * 16)).decryptor()
    return d.update(data) + d.finalize()

link = sys.argv[1]
fid, fkey = link.split('/folder/')[1].split('#')
fkey = b64(fkey)
req = urllib.request.Request(f'https://g.api.mega.co.nz/cs?id=0&n={fid}',
                             data=json.dumps([{"a": "f", "c": 1, "r": 1}]).encode(),
                             headers={'Content-Type': 'application/json'})
nodes = json.loads(urllib.request.urlopen(req, timeout=60).read())[0]['f']
names = {}
for n in nodes:
    k = b64(n['k'].split(':', 1)[1])
    k = aes_ecb_dec(fkey, k)
    if n['t'] == 0:  # fichero: clave de 32 bytes plegada con XOR
        a = struct.unpack('>8I', k)
        key = struct.pack('>4I', a[0] ^ a[4], a[1] ^ a[5], a[2] ^ a[6], a[3] ^ a[7])
    else:
        key = k[:16]
    attr = aes_cbc_dec(key, b64(n['a'])).rstrip(b'\0')
    name = json.loads(attr[4:].decode('utf-8', 'ignore')).get('n', '?') if attr.startswith(b'MEGA') else '?'
    names[n['h']] = (name, n.get('p'), n['t'], n.get('s', 0), n.get('ts', 0))

def path(h):
    out = []
    while h in names:
        out.append(names[h][0]); h = names[h][1]
    return '/'.join(reversed(out))

for h, (name, p, t, s, ts) in names.items():
    if t == 0:
        print(f"{s/1e6:9.1f} MB  {h}  {path(h)}")
