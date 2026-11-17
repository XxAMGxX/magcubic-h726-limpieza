#!/usr/bin/env bash
# limpiar-firmware.sh — genera un firmware limpio (sin BADBOX 2.0 ni puertas traseras) para proyectores
# Magcubic con chip Allwinner H726 a partir del update.img OFICIAL que tú mismo descargas de Magcubic.
# No distribuye ninguna imagen: todo se hace en tu equipo sobre tu copia.
#
# Uso:
#   ./limpiar-firmware.sh update.img [opciones]
# Opciones:
#   --placa h726_p2|h726_p1   placa esperada (por defecto: la que diga el firmware; se para si no es una de estas)
#   --init-boot FICHERO       sustituye init_boot por uno parcheado con Magisk (root). Ver README.
#   --version-nueva           sube la fecha de sunxi_version.fex (si tu proyector ya tiene un build más nuevo)
#   --quitar-tubesky          borra también /priv-app/Tubesky (en algunos modelos es una tienda falsa;
#                             en el HY300 Pro+ h726_p2 es la Play Store auténtica de Google)
#   --salida DIR              carpeta de trabajo y resultado (por defecto ./salida)
#
# Requisitos (Debian/Ubuntu): python3, e2fsprogs (debugfs, e2fsck), android-sdk-libsparse-utils (simg2img, img2simg).
# Espacio: ~7 GB libres además del update.img. No necesita root ni montar nada. Solo Linux (o WSL en Windows).
set -euo pipefail
AQUI=$(cd "$(dirname "$0")" && pwd); H=$AQUI/herramientas
IMG=""; PLACA=""; INITBOOT=""; BUMP=0; TUBESKY=0; OUT=./salida
while [ $# -gt 0 ]; do
  case "$1" in
    --placa) PLACA=$2; shift 2;; --init-boot) INITBOOT=$(readlink -f "$2"); shift 2;;
    --version-nueva) BUMP=1; shift;; --quitar-tubesky) TUBESKY=1; shift;;
    --salida) OUT=$2; shift 2;; -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) IMG=$(readlink -f "$1"); shift;;
  esac
done
[ -f "$IMG" ] || { echo "Falta el update.img oficial. Uso: $0 update.img [opciones]"; exit 1; }
for b in python3 debugfs e2fsck simg2img img2simg; do command -v $b >/dev/null || { echo "Falta '$b' (ver README)"; exit 1; }; done
mkdir -p "$OUT"; OUT=$(readlink -f "$OUT"); W=$OUT/trabajo; rm -rf "$W"; mkdir -p "$W"
paso(){ echo; echo "==> $*"; }

paso "1/8 Comprobando el firmware de partida"
sha256sum "$IMG" | tee "$OUT/original.sha256"
python3 "$H/awimg.py" extract "$IMG" "$W/ext"
python3 "$H/awimg.py" repack "$IMG" "$W/ext" "$W/prueba.img" >/dev/null
cmp -s "$IMG" "$W/prueba.img" || { echo "El reempaquetado de control no es idéntico al original: formato no soportado, paro."; exit 1; }
rm -f "$W/prueba.img"; echo "Formato IMAGEWTY reconocido (reempaquetado idéntico byte a byte)."

paso "2/8 Desempaquetando super"
simg2img "$W/ext/super.fex" "$W/super.raw"
SABOR=$(grep -a -o -m1 'ro.build.flavor=[a-z0-9_]*-user' "$W/super.raw" | head -1 | cut -d= -f2 | sed 's/-user//')
BUILD=$(grep -a -o -m1 'ro.build.display.id=[A-Za-z0-9._]*' "$W/super.raw" | head -1 | cut -d= -f2)
echo "Placa del firmware: ${SABOR:-?}   Build: ${BUILD:-?}"
case "$SABOR" in h726_p1|h726_p2) ;; *) echo "Placa '$SABOR' no soportada por este script (solo H726 p1/p2). Paro."; exit 1;; esac
[ -n "$PLACA" ] && [ "$PLACA" != "$SABOR" ] && { echo "Pediste --placa $PLACA pero el firmware es $SABOR. Paro (flashear otra placa puede inutilizarlo)."; exit 1; }

paso "3/8 Extrayendo product_a y system_a"
read -r OFF_P SZ_P < <(python3 "$H/lpinfo.py" "$W/super.raw" --offset product_a)
read -r OFF_S SZ_S < <(python3 "$H/lpinfo.py" "$W/super.raw" --offset system_a)
dd if="$W/super.raw" of="$W/product_a.img" bs=4M iflag=skip_bytes,count_bytes skip=$OFF_P count=$SZ_P status=none
dd if="$W/super.raw" of="$W/system_a.img"  bs=4M iflag=skip_bytes,count_bytes skip=$OFF_S count=$SZ_S status=none

paso "4/8 Quitando el malware y las puertas traseras"
borra(){ # imagen ruta descripción
  if debugfs -R "stat $2" "$1" 2>/dev/null | grep -q '^Inode:'; then
    debugfs -w -R "rm $2" "$1" >/dev/null 2>&1 && echo "  quitado: $2  ($3)"
  else echo "  (no está: $2)"; fi; }
borra "$W/product_a.img" /app/StoreOs_QZ/StoreOs_QZ.apk            "StoreOS: descarga el agente de proxy BADBOX"
borra "$W/product_a.img" /app/HtcOtaUpdate_QZ/HtcOtaUpdate_QZ.apk  "OTA del fabricante: reinstala el malware"
borra "$W/product_a.img" /app/HYK_TEST/HYK_TEST.apk                "app de test de fábrica"
[ $TUBESKY = 1 ] && borra "$W/product_a.img" /priv-app/Tubesky/Tubesky.apk "Tubesky"
borra "$W/system_a.img"  /system/xbin/hotacksu                     "su oculto setuid"
borra "$W/system_a.img"  /system/bin/qw                            "segundo su oculto (Superuser de Koush como servicio root)"
borra "$W/system_a.img"  /system/etc/init/qw.rc                    "servicio de init que arranca qw"
for i in product_a system_a; do e2fsck -fn "$W/$i.img" >/dev/null 2>&1 || { echo "e2fsck encuentra errores en $i: paro."; exit 1; }; done
echo "  sistemas de ficheros verificados con e2fsck"

paso "5/8 Volviendo a montar super"
dd if="$W/product_a.img" of="$W/super.raw" bs=4M oflag=seek_bytes seek=$OFF_P conv=notrunc status=none
dd if="$W/system_a.img"  of="$W/super.raw" bs=4M oflag=seek_bytes seek=$OFF_S conv=notrunc status=none
img2simg "$W/super.raw" "$W/ext/super.fex"
rm -f "$W/super.raw" "$W/product_a.img" "$W/system_a.img"     # ya no hacen falta: libera ~4 GB

paso "6/8 Arranque: verificación AVB desactivada${INITBOOT:+ y init_boot con Magisk}"
# Con system/product modificados, la verificación de dm-verity fallaría: flags del vbmeta principal a 3
# (VERIFICATION_DISABLED | HASHTREE_DISABLED). Cubre también vbmeta_system/vbmeta_vendor encadenados.
printf '\x03' | dd of="$W/ext/vbmeta.fex" bs=1 seek=123 conv=notrunc status=none
if [ -n "$INITBOOT" ]; then
  [ "$(stat -c %s "$INITBOOT")" = "$(stat -c %s "$W/ext/init_boot.fex")" ] || { echo "init_boot de tamaño distinto al original: paro."; exit 1; }
  cp "$INITBOOT" "$W/ext/init_boot.fex"; echo "  init_boot sustituido"
fi

paso "7/8 Fecha de versión"
if [ $BUMP = 1 ]; then printf '2030-12-31 23:59:59\n2030-12-31 23:59:59\n' > "$W/ext/sunxi_version.fex"; echo "  sunxi_version subida a 2030-12-31"
else echo "  sin tocar ($(head -1 "$W/ext/sunxi_version.fex")). Si tu proyector tiene un build más nuevo, usa --version-nueva"; fi

paso "8/8 Empaquetando y verificando"
mkdir -p "$OUT/update"
python3 "$H/awimg.py" repack "$IMG" "$W/ext" "$OUT/update/update.img"
cp "$(dirname "$IMG")/auto_update.txt" "$OUT/update/" 2>/dev/null || printf 'sunxi_flash write update/update.img firmware\n' > "$OUT/update/auto_update.txt"
# verificación: cada fichero empaquetado se compara con su original, uno a uno (sin desempaquetar todo otra vez)
python3 - "$OUT/update/update.img" "$W/ext" <<'PY' || { echo "Verificación fallida. Paro."; exit 1; }
import os, sys, struct
img, d = sys.argv[1], sys.argv[2]
f = open(img, "rb"); h = f.read(1024); n = struct.unpack_from("<I", h, 0x3c)[0]; f.seek(0); h = f.read(1024 + n * 1024)
for i in range(n):
    o = 1024 + i * 1024
    name = h[o + 0x24:o + 0x124].split(b"\0")[0].decode()
    orig, off = struct.unpack_from("<I", h, o + 0x12c)[0], struct.unpack_from("<I", h, o + 0x134)[0]
    f.seek(off); g = open(os.path.join(d, name), "rb"); left = orig
    if os.path.getsize(os.path.join(d, name)) != orig: sys.exit(f"tamaño distinto: {name}")
    while left:
        a = f.read(min(left, 1 << 22)); b = g.read(len(a))
        if a != b: sys.exit(f"contenido distinto: {name}")
        left -= len(a)
print("Verificación: los", n, "ficheros empaquetados coinciden")
PY
sha256sum "$OUT/update/update.img" | tee "$OUT/limpio.sha256"
rm -rf "$W"
echo
echo "LISTO. Copia la carpeta '$OUT/update' (con update.img y auto_update.txt dentro) a la raíz de un USB FAT32 (MBR)."
echo "Proyector desenchufado → USB puesto → enchufa y mantén el botón de encendido del proyector hasta que la luz pase de roja a azul."
