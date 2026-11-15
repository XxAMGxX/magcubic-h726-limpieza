Title: HY300 Pro+ (h726_p2): second hidden su (`qw`), unauthenticated root telnet on TCP 1234, AOSP test platform key

Hi! Thanks for the write-up, it was the base for cleaning my unit. Some findings on a **HY300 Pro+ (`h726_p2`, Android 14,
build `Projector.20260116.113201`)** that are not in the current IOCs:

1. **`/system/bin/qw` is a second hidden `su`**: Koush's legacy *Superuser* daemon, started by init as root from
   `/system/etc/init/qw.rc` (`service qw /system/bin/qw --daemon`, class core). Its socket
   `/dev/com.koushikdutta.superuser.daemon/server` is `srwxrwxrwx`. No vendor app references it. Removing both files
   (plus `hotacksu`) boots fine.
2. **TCP 1234 on all interfaces**: an unauthenticated telnet debug console ("Build: Dec 9 2025 / Copyright (c) 2025
   CF-Vision", prompt `CF:`) inside `/vendor/bin/hw/tvserver`, which runs as root. I did not probe its commands; I
   firewalled it.
3. The platform is signed with the **public AOSP test key** (framework-res and system apps, cert SHA-256
   `c8a2e9bc…92ab8`), so any APK signed with it can share `android.uid.system`.
4. On `h726_p2`, `/product/priv-app/Tubesky` is the **genuine Google Play Store** (signed by Google, `f0fd6c5b…`), unlike
   your p1 notes.
5. Kernel `5.15.167` built by `hotack@dell-PowerEdge-R740`.
6. The vendor launcher `com.htc.magcubicos` queues analytics (`__send_data_*`, device IDs) for `stat.visionular.cn`.

I put a script that does your recipe automatically from the official `update.img` (checks byte-identical repack and
board, removes StoreOS/OTA/HYK_TEST/hotacksu/qw, sets vbmeta flags, optional Magisk init_boot) here: <ENLACE AL REPO>.
Flashed and running on my unit.
