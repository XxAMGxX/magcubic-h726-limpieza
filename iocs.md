# Indicadores (IOC) — Magcubic H726

## Paquetes / ficheros
| Indicador | Qué es |
|---|---|
| `com.htc.storeos` (`/product/app/StoreOs_QZ`) | Dropper: descarga `com.hotack.silentsdk` |
| `com.htc.htcotaupdate` (`/product/app/HtcOtaUpdate_QZ`) | OTA del fabricante, reinstala |
| `com.hotack.silentsdk`, `com.hotack.writesn` | Agente de proxy SOAX y ayudante (se descargan en tiempo de ejecución) |
| `com.htc.expandsdk`, `com.htc.eventuploadservice` | Referenciados en `/vendor/etc/awbms_config` (lista blanca del gestor de memoria) |
| `/system/xbin/hotacksu` | `su` setuid |
| `/system/bin/qw` + `/system/etc/init/qw.rc` | `su` daemon (Superuser de Koush) como servicio root; socket `/dev/com.koushikdutta.superuser.daemon` |
| `tvserver` TCP 1234 | Consola telnet «CF-Vision» sin contraseña, root |
| `com.htc.magcubicos` → `.cesium/bohrium`, `__send_data_*` | SDK de telemetría (identificadores del aparato) |
| Certificado de plataforma SHA-256 `c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8` | Clave de pruebas pública de AOSP |

## Dominios
```
api.pixelpioneerss.com  sta.smartinnovate.net  bur.thedynamicleap.com  kkoip.com  soax.com
event-api.aodintech.com  pb-api.aodintech.com  store-api.aodintech.com  cdn-store.aodintech.com
ota-api.aodintech.com  faq.aodintech.com  ota.triplesai.com  otaapi.triplesai.com  shortx.srafx.com
hotack.com  int.vaicore.site  int.dewrain.life  int.akisinn.info  ipdatacloud.com
stat.visionular.cn (telemetría)  hmma.baidu.com  dxp.baidu.com
```
Funcional, no bloquear hasta haber activado el casting una vez: `server.mphotool.com` (licencia de AirPlay/DLNA).

## IP fijas (bloquear en el router; el DNS no las ve)
`139.199.190.220`, `128.12.122.35`, `103.124.165.222`, `64.32.27.247`

Fuente de dominios e IP de BADBOX: maximilian-sh/hy350max-badbox-removal (`iocs/`) y observación propia con AdGuard.
