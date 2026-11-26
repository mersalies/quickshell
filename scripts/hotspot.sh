#!/usr/bin/env bash
# Раздача Wi-Fi при подключении к Wi-Fi (как «Мобильный хот-спот» в Windows).
# Всё, что требует root, делает hotspot-helper.sh (ставится hotspot-setup.sh):
# hostapd на виртуальном ap0 + dnsmasq + NAT. Карта умеет клиент + AP одновременно
# только на одном канале, поэтому AP поднимается на канале текущей Wi-Fi сети.
#
#   hotspot.sh start <ssid> <пароль>   включить (или перезапустить с новыми данными)
#   hotspot.sh stop
#   hotspot.sh status                   active | inactive
#   hotspot.sh clients                  MAC<TAB>IP<TAB>имя<TAB>blocked
#   hotspot.sh kick <MAC> | unblock <MAC>
set -u
export LANG=C LC_ALL=C

AP=ap0
HELPER=/usr/local/lib/quickshell-hotspot/helper
SETUP_HINT="sudo ~/.config/quickshell/scripts/hotspot-setup.sh"

die() { echo "ERR: $*"; exit 1; }

helper() {
    [ -x "$HELPER" ] && sudo -n -l "$HELPER" >/dev/null 2>&1 \
        || die "не настроено — выполните в терминале: $SETUP_HINT"
    sudo -n "$HELPER" "$@" 2>&1
}

wifi_iface() {
    for d in /sys/class/net/*/wireless; do
        d=${d%/wireless}; d=${d##*/}
        [ "$d" != "$AP" ] && { echo "$d"; return; }
    done
}

case "${1:-}" in
start)
    ssid=${2:-}; pass=${3:-}
    [ -n "$ssid" ] && [ "${#ssid}" -le 32 ] || die "имя сети: 1–32 символа"
    [ "${#pass}" -ge 8 ] && [ "${#pass}" -le 63 ] || die "пароль: 8–63 символа"
    [ "$(nmcli radio wifi)" = enabled ] || die "Wi-Fi выключен"
    iface=$(wifi_iface); [ -n "$iface" ] || die "нет Wi-Fi адаптера"

    # Канал текущего подключения: AP обязан быть на нём же
    freq=$(iw dev "$iface" link 2>/dev/null | awk '/freq:/ {print int($2); exit}')
    if [ -z "$freq" ]; then
        band=bg; chan=6
    elif [ "$freq" -lt 3000 ]; then
        band=bg; chan=$(( (freq - 2407) / 5 ))
    elif [ "$freq" -lt 5925 ]; then
        band=a; chan=$(( (freq - 5000) / 5 ))
        # DFS-каналы (52–144): точку доступа там поднять нельзя
        [ "$chan" -ge 52 ] && [ "$chan" -le 144 ] && \
            die "сеть на DFS-канале $chan — подключитесь к 2.4 ГГц или другой сети"
    else
        die "раздача из сети 6 ГГц не поддерживается"
    fi
    # Intel (iwlwifi/LAR) отдаёт 5 ГГц с флагом «No IR» — hostapd там AP не поднимет
    phy=$(iw dev "$iface" info | awk '/wiphy/ {print "phy" $2; exit}')
    if iw phy "$phy" channels 2>/dev/null | awk -v c="[$chan]" '$4==c {f=1; next} /^\t\*/ {f=0} f && /No IR/ {found=1} END {exit !found}'; then
        die "карта не может раздавать на канале $chan ($((freq / 1000)) ГГц) — подключитесь к сети 2.4 ГГц"
    fi

    printf '%s\n%s\n' "$ssid" "$pass" | helper up "$iface" "$band" "$chan" | grep '^ERR:' && exit 1
    [ "$("$0" status)" = active ] || die "точка доступа не запустилась"
    ;;
stop)
    [ -x "$HELPER" ] && sudo -n "$HELPER" down >/dev/null 2>&1
    true
    ;;
status)
    pid=$(cat /run/qs-hotspot/hostapd.pid 2>/dev/null)
    if [ -n "$pid" ] && [ -d "/proc/$pid" ] && [ -d "/sys/class/net/$AP" ]; then echo active; else echo inactive; fi
    ;;
clients) helper clients ;;
kick|unblock) helper "$1" "${2:-}" ;;
*) echo "usage: hotspot.sh start <ssid> <pass> | stop | status | clients | kick <mac> | unblock <mac>"; exit 2 ;;
esac
