# magcubic-h726-limpieza

**Español** · [English below](#english)

Quita el malware **BADBOX 2.0** y las puertas traseras de fábrica de los proyectores **Magcubic con chip Allwinner H726**
(HY300 Pro+, HY300 Max, HY350 Max…), generando **tu propio firmware limpio** a partir del `update.img` oficial que
descargas de Magcubic. Este repositorio **no distribuye ningún firmware**: solo el método y las herramientas.

> ⚠️ **Flashear firmware puede dejar el proyector inservible.** Lo haces bajo tu responsabilidad. Probado en un
> **HY300 Pro+ (placa `h726_p2`)** con el firmware `H726 M Projector 20260116`. En otras placas, el script se para si la
> placa del firmware no es `h726_p1` o `h726_p2`; aun así, comprueba que el firmware que descargas es el de tu modelo.

## Qué trae de fábrica (comprobado en un HY300 Pro+ `h726_p2`, Android 14)

| Hallazgo | Detalle | Riesgo |
|---|---|---|
| **StoreOS** (`com.htc.storeos`) | Descarga en segundo plano el agente de **proxy residencial** `com.hotack.silentsdk` (red SOAX) | Desconocidos navegan con tu IP |
| **HtcOtaUpdate** (`com.htc.htcotaupdate`) | Actualizador del fabricante que reinstala lo anterior | Persistencia |
| **`/system/xbin/hotacksu`** | `su` setuid escondido | Root para el usuario de ADB |
| **`/system/bin/qw`** *(nuevo, no estaba en listas públicas)* | Segundo `su`: el antiguo *Superuser* de Koush corriendo como **servicio root** de init (`qw.rc`), con su socket `/dev/com.koushikdutta.superuser.daemon` accesible para todos | Puerta trasera de root |
| **Consola en TCP 1234** *(nuevo)* | Consola de depuración **telnet sin contraseña** («CF-Vision») dentro de `tvserver`, que corre como **root**, abierta a toda la red | Cualquiera de tu red puede hablar con un proceso root |
| **Firmas** *(nuevo)* | Todo el sistema está firmado con la **clave de pruebas pública de AOSP** (`c8a2e9bc…`) | Cualquier APK firmada con esa clave conocida obtiene privilegios de sistema: **no instales APKs de fuentes dudosas** |
| Telemetría | El lanzador `com.htc.magcubicos` lleva un SDK que envía identificadores del aparato a `stat.visionular.cn` | Privacidad |
| Otros | SELinux en modo permisivo; el núcleo se compiló en la máquina del usuario `hotack` (el mismo nombre del SDK del malware) | — |

Lista de dominios e IP en [`iocs.md`](iocs.md).

## ¿Lo necesito?

- **Si usas el proyector sin conectarlo a la red** (por ejemplo con un Fire TV o un Chromecast por HDMI): no. Sin
  internet el malware no puede hacer nada. Es la opción más sencilla.
- **Si quieres usar su sistema Android con wifi:** como mínimo, desactiva por ADB la tienda y el actualizador (abajo) y
  bloquea los dominios en tu Pi-hole/AdGuard. La limpieza completa es reflashear con este script.

### Mínimo sin flashear (por ADB)
```sh
adb shell pm uninstall -k --user 0 com.htc.storeos
adb shell pm uninstall -k --user 0 com.htc.htcotaupdate
```
Esto corta la descarga del agente de proxy, pero `hotacksu`, `qw` y la consola del puerto 1234 siguen ahí.

## 1. Descargar el firmware oficial

Magcubic publica cada firmware en su web de soporte, con un enlace a una carpeta de MEGA que contiene `update.img` y
`auto_update.txt`. Descarga **los dos** desde el navegador y déjalos en la misma carpeta.

| Modelo (chip H726) | Página oficial |
|---|---|
| HY300 Pro+ | https://www.magcubic-support.com/newsinfo/3145165.html |
| HY300 Pro | https://www.magcubic-support.com/newsinfo/3145157.html |
| HY300 Max | https://www.magcubic-support.com/newsinfo/3145154.html |
| HY300 Ultra | https://www.magcubic-support.com/newsinfo/3145156.html |
| HY350 Max | https://www.magcubic-support.com/newsinfo/3145143.html |

Comprueba que la página es la de **tu modelo exacto**. El script se para si el firmware no es de una placa H726
conocida (`h726_p1` / `h726_p2`), pero no puede saber qué modelo tienes tú.

## 2. Uso del script

Requisitos: Linux o WSL en Windows, `python3`, `e2fsprogs`, `android-sdk-libsparse-utils` y unos **6 GB libres**
además del `update.img` (tarda 1-2 minutos).
```sh
sudo apt install python3 e2fsprogs android-sdk-libsparse-utils
./limpiar-firmware.sh update.img --placa h726_p2
```
Opciones:
- `--init-boot init_boot_parcheado.img`: root con Magisk (ver abajo). **Sin esta opción, el firmware no lleva root.**
- `--version-nueva`: necesario si tu proyector ya tiene instalado un build **más nuevo** que el que vas a flashear (si
  no, el cargador lo rechaza).
- `--quitar-tubesky`: borra `/priv-app/Tubesky`. En el HY300 Pro+ es la Play Store auténtica (firmada por Google), así
  que por defecto se deja; en el HY350 Max se ha descrito como tienda falsa.

Al final dice `Verificación: los N ficheros empaquetados coinciden` y `LISTO`. Si algo no cuadra, **se para sin
generar nada**.

Qué hace: comprueba el formato (reempaqueta el original y exige que salga idéntico byte a byte) y la placa; quita
StoreOS, HtcOtaUpdate, HYK_TEST, `hotacksu`, `qw` y su servicio; pone las banderas de `vbmeta` a 3 (verificación AVB
desactivada, necesario para que arranque un sistema modificado); recalcula las sumas `V*.fex` y verifica el resultado.

## 3. Flashear
1. USB en **FAT32 con tabla MBR** y una sola partición.
2. Copia la carpeta `update` que genera el script (con `update.img` **y** `auto_update.txt` dentro) a la raíz del USB.
3. Proyector **desenchufado** → pon el USB → enchúfalo y **mantén el botón de encendido del proyector** (no el del mando)
   hasta que la luz pase de **roja a azul**. Sale una barra de progreso.
4. Si la barra se queda llena más de 10 minutos, quita el USB y desenchufa y enchufa.

Guarda también el `update.img` **original**: se flashea igual para volver atrás. Si no arranca ni con ese, la
recuperación es con PhoenixSuit desde Windows.

## 4. Root con Magisk (opcional)
1. Ejecuta el script una vez sin `--init-boot` y saca `init_boot.fex` del firmware oficial:
   `python3 herramientas/awimg.py extract update.img extraido/`
2. Con el proyector conectado por ADB, instala Magisk y parchea ese `init_boot` desde la app (Instalar → Seleccionar y
   parchear un archivo) o con `boot_patch.sh`.
3. Vuelve a generar el firmware con `--init-boot magisk_patched.img`.
4. Tras flashear, instala el módulo [`magcubic-h726-endurecido.zip`](magcubic-h726-endurecido.zip) desde Magisk: para
   `qw` (por si quedara), **cierra el puerto 1234 a la red** y bloquea por `hosts` los dominios del malware y de la
   telemetría.

Con el arranque desbloqueado y root, algunas apps de vídeo (Netflix…) pueden bajar a calidad SD.

## Qué está probado
- **HY300 Pro+ (`h726_p2`)**, firmware `H726 M Projector 20260116`: flasheado, arranca, sin StoreOS/OTA/HYK_TEST/
  `hotacksu`, Play Store y ajustes del proyector (enfoque, trapecio, HDMI, AirPlay/DLNA) funcionando; con root de Magisk.
- El script se ha probado desde un clon limpio de este repositorio sobre el firmware oficial: la imagen generada es
  igual, fichero a fichero, a la que se flasheó (más la eliminación de `qw`).
- **No probado por nosotros**: placas `h726_p1` (HY350 Max; el método de base sí lo probó maximilian-sh en esa placa),
  otros firmwares y el firmware sin Magisk en hardware. Si lo pruebas, abre una incidencia contando cómo te ha ido.

## Herramientas
- `herramientas/awimg.py`: lee, extrae y reempaqueta imágenes Allwinner **IMAGEWTY** (recalcula las sumas `V*.fex`).
- `herramientas/lpinfo.py`: lee los metadatos de particiones dinámicas (liblp) de `super` y da offsets.
- `herramientas/mega-ls.py`: lista una carpeta pública de MEGA (donde Magcubic publica sus firmwares).

## Créditos
Basado en el trabajo de [maximilian-sh/hy350max-badbox-removal](https://github.com/maximilian-sh/hy350max-badbox-removal)
(HY350 Max, `h726_p1`) y [micha102/hy300pro-debloat](https://github.com/micha102/hy300pro-debloat).

Licencia MIT (solo las herramientas y scripts de este repositorio).

---

## English

Removes the **BADBOX 2.0** malware and factory backdoors from **Magcubic projectors with the Allwinner H726 chip**
(HY300 Pro+, HY300 Max, HY350 Max…) by building **your own clean firmware** from the official `update.img` you download
from Magcubic. **No firmware is distributed here**, only the method and tools.

> ⚠️ **Flashing can brick your projector.** At your own risk. Tested on a **HY300 Pro+ (`h726_p2`)** with
> `H726 M Projector 20260116`. The script stops if the firmware's board is not `h726_p1`/`h726_p2`.

**New findings** not in previous public reports (HY300 Pro+ `h726_p2`, Android 14):
- `/system/bin/qw` is a **second hidden `su`**: Koush's legacy *Superuser* daemon started by init as **root**
  (`/system/etc/init/qw.rc`), with a world-accessible socket `/dev/com.koushikdutta.superuser.daemon`.
- **TCP 1234**: an **unauthenticated telnet debug console** ("CF-Vision") inside `tvserver`, running as **root**,
  reachable from the whole LAN.
- The whole system is signed with the **public AOSP test platform key** (`c8a2e9bc…`): any APK signed with it can get
  system privileges.
- The vendor launcher `com.htc.magcubicos` ships an analytics SDK sending device identifiers to `stat.visionular.cn`.

**Download** the official `update.img` **and** `auto_update.txt` for your exact model from magcubic-support.com (links
in the Spanish section; Linux or WSL, ~6 GB free). **Usage:** `sudo apt install python3 e2fsprogs android-sdk-libsparse-utils` then
`./limpiar-firmware.sh update.img --placa h726_p2 [--init-boot magisk_patched.img] [--version-nueva] [--quitar-tubesky]`.
Copy the generated `update` folder (with `update.img` **and** `auto_update.txt` inside) to the root of a FAT32/MBR USB
stick, plug it into the unpowered projector, then hold the projector's power button while connecting power until the
LED turns from red to blue.

**Not flashing?** If you use it offline with an HDMI stick, you don't need any of this. If you connect it to Wi-Fi, at
least `pm uninstall -k --user 0 com.htc.storeos` and `com.htc.htcotaupdate`, and block the domains in [`iocs.md`](iocs.md).

MIT licence (tools and scripts only).
