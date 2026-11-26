#!/usr/bin/env bash
# Root-часть раздачи Wi-Fi. Запускается через sudo без пароля
# (ставится скриптом hotspot-setup.sh в /usr/local/lib/quickshell-hotspot/helper).
#
# Точку доступа держит hostapd на виртуальном интерфейсе ap0, DHCP/DNS — dnsmasq,
# NAT — своя nft-таблица, ap0 кладётся в зону firewalld nm-shared (она разрешает
# форвардинг, DHCP и DNS). NetworkManager ap0 не трогает (см. hotspot-setup.sh):
# его wpa_supplicant пытается поднять ap0 вторым клиентом, а карта такого не умеет.
#
#   helper up <wifi-iface> <a|bg> <канал>   имя и пароль — две строки на stdin
#   helper down
#   helper status                           active | inactive
#   helper clients                          MAC<TAB>IP<TAB>имя<TAB>blocked(0/1)
#   helper kick <MAC>                       отключить и не пускать до выключения раздачи
#   helper unblock <MAC>
set -u
export LANG=C LC_ALL=C
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
umask 022

AP=ap0
RUN=/run/qs-hotspot
CTRL=$RUN/ctrl
NET=10.43.0
TABLE=qs_hotspot

die() { echo "ERR: $*"; exit 1; }
valid_mac() { [[ $1 =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; }
alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }
cli() { hostapd_cli -p "$CTRL" -i "$AP" "$@"; }

teardown() {
    [ -f $RUN/dnsmasq.pid ] && kill "$(cat $RUN/dnsmasq.pid)" 2>/dev/null
    [ -f $RUN/hostapd.pid ] && kill "$(cat $RUN/hostapd.pid)" 2>/dev/null
    sleep 0.3
    nft delete table inet "$TABLE" 2>/dev/null
    if [ -d "/sys/class/net/$AP" ]; then
        firewall-cmd -q --zone=nm-shared --remove-interface="$AP" 2>/dev/null
        iw dev "$AP" del 2>/dev/null
    fi
    if [ -f $RUN/ip_forward ]; then
        sysctl -qw net.ipv4.ip_forward="$(cat $RUN/ip_forward)"
    fi
    rm -rf "$RUN"
}

case "${1:-}" in
up)
    parent=${2:-}; band=${3:-}; chan=${4:-}
    [[ $parent =~ ^[a-zA-Z0-9_-]{1,15}$ ]] || die "bad interface"
    [ -d "/sys/class/net/$parent/wireless" ] || die "$parent is not wifi"
    [[ $band == a || $band == bg ]] || die "bad band"
    [[ $chan =~ ^[0-9]{1,3}$ ]] || die "bad channel"
    IFS= read -r ssid || die "no ssid"
    IFS= read -r pass || die "no password"
    [ -n "$ssid" ] && [ "${#ssid}" -le 32 ] || die "имя сети: 1–32 символа"
    [[ $pass =~ ^[[:print:]]{8,63}$ ]] || die "пароль: 8–63 печатных символа"
    command -v hostapd >/dev/null || die "не установлен hostapd: sudo pacman -S hostapd"

    teardown
    mkdir -p "$CTRL"; chmod 755 "$RUN"; chmod 700 "$CTRL"
    cat /proc/sys/net/ipv4/ip_forward > $RUN/ip_forward

    mac=$(cat "/sys/class/net/$parent/address")
    first=$(( 0x${mac:0:2} | 0x02 ))
    [ "$(printf '%02x' "$first")" = "${mac:0:2}" ] && first=$(( first ^ 0x04 ))
    apmac=$(printf '%02x' "$first")${mac:2}
    iw dev "$parent" interface add "$AP" type __ap addr "$apmac" \
        || { teardown; die "карта не дала создать точку доступа"; }
    nmcli device set "$AP" managed no 2>/dev/null

    : > $RUN/deny
    {
        echo "interface=$AP"
        echo "driver=nl80211"
        echo "ctrl_interface=$CTRL"
        echo "ssid2=$(printf '%s' "$ssid" | od -An -tx1 | tr -d ' \n')"
        echo "utf8_ssid=1"
        if [ "$band" = a ]; then
            echo "hw_mode=a"
            echo "ieee80211ac=1"
        else
            echo "hw_mode=g"
        fi
        echo "channel=$chan"
        echo "ieee80211n=1"
        echo "wmm_enabled=1"
        echo "auth_algs=1"
        echo "wpa=2"
        echo "wpa_key_mgmt=WPA-PSK"
        echo "rsn_pairwise=CCMP"
        echo "wpa_passphrase=$pass"
        echo "macaddr_acl=0"
        echo "deny_mac_file=$RUN/deny"
    } > $RUN/hostapd.conf
    chmod 600 $RUN/hostapd.conf

    if ! hostapd -B -P $RUN/hostapd.pid $RUN/hostapd.conf > /run/qs-hotspot.log 2>&1; then
        chmod 644 /run/qs-hotspot.log
        err=$(grep -iE 'fail|error|could not|unable|invalid|not supported|refus' /run/qs-hotspot.log | grep -v deinit | head -1)
        teardown
        die "hostapd: ${err:-не запустился}"
    fi

    ip addr flush dev "$AP"
    ip addr add $NET.1/24 dev "$AP"
    ip link set "$AP" up

    dnsmasq --conf-file=/dev/null --interface="$AP" --bind-interfaces --except-interface=lo \
        --listen-address=$NET.1 --dhcp-range=$NET.10,$NET.250,255.255.255.0,12h \
        --dhcp-option=option:router,$NET.1 --dhcp-option=option:dns-server,$NET.1 \
        --dhcp-leasefile=$RUN/leases --pid-file=$RUN/dnsmasq.pid --dhcp-authoritative \
        || { teardown; die "dnsmasq не запустился"; }

    sysctl -qw net.ipv4.ip_forward=1
    nft -f - <<EOF || { teardown; die "nft"; }
table inet $TABLE {
    chain forward {
        type filter hook forward priority filter - 5; policy accept;
        iifname "$AP" accept
        oifname "$AP" ct state established,related accept
    }
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr $NET.0/24 oifname != "$AP" masquerade
    }
}
EOF
    if systemctl -q is-active firewalld; then
        firewall-cmd -q --zone=nm-shared --change-interface="$AP" || { teardown; die "firewalld"; }
    fi
    ;;
down)
    teardown
    true
    ;;
status)
    if alive $RUN/hostapd.pid && [ -d "/sys/class/net/$AP" ]; then echo active; else echo inactive; fi
    ;;
clients)
    alive $RUN/hostapd.pid || exit 0
    blocked=$(cli deny_acl SHOW 2>/dev/null | grep -oiE '^([0-9a-f]{2}:){5}[0-9a-f]{2}' | tr 'A-F' 'a-f')
    stations=$(iw dev "$AP" station dump | awk '/^Station/ {print tolower($2)}')
    for mac in $(printf '%s\n%s\n' "$stations" "$blocked" | sort -u); do
        [ -z "$mac" ] && continue
        ip=""; name=""
        if [ -r $RUN/leases ]; then
            read -r ip name < <(awk -v m="$mac" 'tolower($2)==m {print $3, ($4=="*" ? "" : $4)}' $RUN/leases | tail -1)
        fi
        [ -z "$ip" ] && ip=$(ip -4 neigh show dev "$AP" | awk -v m="$mac" 'tolower($3)==m {print $1; exit}')
        b=0; grep -qx "$mac" <<<"$blocked" && b=1
        printf '%s\t%s\t%s\t%s\n' "$mac" "${ip:-}" "${name:-}" "$b"
    done
    ;;
kick)
    mac=${2:-}; valid_mac "$mac" || die "bad mac"
    mac=${mac,,}
    alive $RUN/hostapd.pid || die "раздача выключена"
    cli deny_acl ADD_MAC "$mac" >/dev/null || die "hostapd_cli"
    cli deauthenticate "$mac" >/dev/null
    true
    ;;
unblock)
    mac=${2:-}; valid_mac "$mac" || die "bad mac"
    alive $RUN/hostapd.pid || exit 0
    cli deny_acl DEL_MAC "${mac,,}" >/dev/null
    true
    ;;
*)
    echo "usage: helper up <iface> <a|bg> <chan> (ssid, pass on stdin) | down | status | clients | kick <mac> | unblock <mac>"
    exit 2
    ;;
esac
