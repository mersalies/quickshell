#!/usr/bin/env bash
# Однократная настройка раздачи Wi-Fi: sudo ~/.config/quickshell/scripts/hotspot-setup.sh
# - копирует hotspot-helper.sh в /usr/local/lib (принадлежит root, чтобы его нельзя было
#   подменить без пароля) и разрешает текущему пользователю запускать его через sudo без пароля;
# - запрещает NetworkManager трогать интерфейс ap0 (иначе он не даёт поднять точку доступа).
# После изменения hotspot-helper.sh запустите снова.
# Удаление: sudo ~/.config/quickshell/scripts/hotspot-setup.sh --remove
set -euo pipefail

DIR=/usr/local/lib/quickshell-hotspot
HELPER=$DIR/helper
SUDOERS=/etc/sudoers.d/quickshell-hotspot
NMCONF=/etc/NetworkManager/conf.d/quickshell-hotspot.conf

[ "$(id -u)" -eq 0 ] || { echo "Запустите через sudo: sudo $0"; exit 1; }

if [ "${1:-}" = "--remove" ]; then
    [ -x "$HELPER" ] && "$HELPER" down || true
    rm -f "$SUDOERS" "$HELPER" "$NMCONF"
    rmdir "$DIR" 2>/dev/null || true
    systemctl reload NetworkManager 2>/dev/null || true
    echo "Удалено."
    exit 0
fi

user=${SUDO_USER:-}
[ -n "$user" ] && [ "$user" != root ] || { echo "Запустите через sudo от своего пользователя"; exit 1; }

if ! command -v hostapd >/dev/null; then
    echo "Ставлю hostapd…"
    pacman -S --needed --noconfirm hostapd
fi
for bin in iw nft nmcli dnsmasq hostapd hostapd_cli; do
    command -v "$bin" >/dev/null || { echo "Нет программы $bin"; exit 1; }
done

src="$(cd "$(dirname "$0")" && pwd)/hotspot-helper.sh"
install -d -m 755 -o root -g root "$DIR"
install -m 755 -o root -g root "$src" "$HELPER"

tmp=$(mktemp)
{
    # без записи в журнал: панель опрашивает список устройств каждые пару секунд
    echo "Defaults!$HELPER !syslog, !pam_session"
    echo "$user ALL=(root) NOPASSWD: $HELPER"
} > "$tmp"
visudo -cf "$tmp" >/dev/null
install -m 440 -o root -g root "$tmp" "$SUDOERS"
rm -f "$tmp"

install -d -m 755 /etc/NetworkManager/conf.d
printf '[keyfile]\nunmanaged-devices=interface-name:ap0\n' > "$NMCONF"
systemctl reload NetworkManager 2>/dev/null || true
# профиль от старой версии раздачи через NetworkManager
nmcli -t -f NAME connection show | grep -qx qs-hotspot && nmcli connection delete qs-hotspot >/dev/null || true

echo "Готово: $user может включать раздачу из quickshell."
