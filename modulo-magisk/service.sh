#!/system/bin/sh
# Magcubic H726 - endurecido (servicio late_start de Magisk). Idempotente.
stop qw 2>/dev/null; setprop ctl.stop qw
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done; sleep 5
for T in iptables ip6tables; do
  $T -w -N MAGCUBIC_IN 2>/dev/null; $T -w -F MAGCUBIC_IN
  $T -w -C INPUT -j MAGCUBIC_IN 2>/dev/null || $T -w -I INPUT 1 -j MAGCUBIC_IN
  $T -w -A MAGCUBIC_IN -i lo -j RETURN
  # consola de depuración CF-Vision sin contraseña dentro de tvserver (root), abierta a toda la LAN
  $T -w -A MAGCUBIC_IN -p tcp --dport 1234 -j DROP
done
# Opcional: limitar ADB por red a un solo equipo. Descomenta y pon su IP.
# iptables -w -A MAGCUBIC_IN -p tcp --dport 5555 ! -s 192.0.2.10 -j DROP
log -t magcubic-endurecido "reglas aplicadas"
# El lanzador del fabricante arranca antes que el elegido: pulsar Inicio al terminar el arranque
sleep 8; input keyevent KEYCODE_HOME
