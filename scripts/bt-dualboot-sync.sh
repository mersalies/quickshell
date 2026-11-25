#!/usr/bin/env bash
# Синхронизация ключей Bluetooth из Windows в Linux (дуалбут).
#
# Проблема: при сопряжении устройство хранит ОДИН ключ на адрес адаптера. Сопрягли в
# Windows — ключ в Linux устарел, и наоборот. Решение: сопрячь сначала в Linux, затем
# в Windows, а потом скопировать ключ из реестра Windows в BlueZ — дальше устройство
# работает в обеих системах без пересопряжения.
#
#   sudo bt-dualboot-sync.sh            — показать, что будет изменено, и применить
#   sudo bt-dualboot-sync.sh --dry-run  — только показать
#   sudo bt-dualboot-sync.sh --part /dev/nvme1n1p3   — указать раздел Windows вручную
#
# Нужно: пакет hivex (hivexregedit), ntfs-3g. Раздел Windows монтируется только на чтение.
# Поддерживаются классические устройства (BR/EDR: наушники, колонки) — ключ LinkKey.
set -euo pipefail

DRY=0 PART=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n) DRY=1 ;;
        --part) PART=$2; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "неизвестный аргумент: $1"; exit 1 ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] || { echo "запустите через sudo"; exit 1; }
command -v hivexregedit >/dev/null || { echo "нет hivexregedit — sudo pacman -S hivex"; exit 1; }

MNT=$(mktemp -d /tmp/winsys.XXXXXX)
cleanup() { mountpoint -q "$MNT" && umount "$MNT"; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

mount_win() {
    local dev=$1
    mount -t ntfs-3g -o ro "$dev" "$MNT" 2>/dev/null || mount -t ntfs3 -o ro "$dev" "$MNT" 2>/dev/null || return 1
    [[ -f $MNT/Windows/System32/config/SYSTEM ]] && return 0
    umount "$MNT"; return 1
}

if [[ -n $PART ]]; then
    mount_win "$PART" || { echo "на $PART не найден Windows"; exit 1; }
else
    found=""
    while read -r dev fs; do
        [[ $fs == ntfs ]] || continue
        if mount_win "/dev/$dev"; then found=/dev/$dev; break; fi
    done < <(lsblk -lno NAME,FSTYPE)
    [[ -n $found ]] || { echo "раздел Windows не найден (укажите --part)"; exit 1; }
    PART=$found
fi
echo "==> Windows: $PART"

# Экспорт ветки ключей: [...\Keys\<адаптер>] "<устройство>"=hex:aa,bb,...
REG=$(hivexregedit --export --prefix 'HKLM\SYSTEM' "$MNT/Windows/System32/config/SYSTEM" \
      '\ControlSet001\Services\BTHPORT\Parameters\Keys' 2>/dev/null | tr -d '\r')
[[ -n $REG ]] || { echo "в реестре нет ключей Bluetooth"; exit 1; }

declare -A WINKEY
adapter=""
while IFS= read -r line; do
    if [[ $line =~ \\Keys\\([0-9a-fA-F]{12})\]$ ]]; then
        adapter=${BASH_REMATCH[1],,}
    elif [[ -n $adapter && $line =~ ^\"([0-9a-fA-F]{12})\"=hex(\(3\))?:([0-9a-fA-F,]+)$ ]]; then
        hex=${BASH_REMATCH[3]//,/}
        [[ ${#hex} -eq 32 ]] && WINKEY["$adapter/${BASH_REMATCH[1],,}"]=${hex^^}
    fi
done <<<"$REG"

colon() { sed -E 's/(..)/\1:/g; s/:$//' <<<"${1^^}"; }

changed=0
for key in "${!WINKEY[@]}"; do
    a=$(colon "${key%/*}"); d=$(colon "${key#*/}")
    info=/var/lib/bluetooth/$a/$d/info
    name=$( [[ -f $info ]] && grep -m1 '^Name=' "$info" | cut -d= -f2- || true)
    if [[ ! -f $info ]]; then
        echo "  -- $d: есть в Windows, но не сопряжено в Linux (сначала сопрягите здесь)"
        continue
    fi
    cur=$(awk -F= '/^\[LinkKey\]/{f=1;next} /^\[/{f=0} f&&$1=="Key"{print $2}' "$info")
    new=${WINKEY[$key]}
    if [[ $cur == "$new" ]]; then
        echo "  ok $d ${name:+($name)}: ключи совпадают"
        continue
    fi
    echo "  >> $d ${name:+($name)}: $cur → $new"
    changed=1
    [[ $DRY == 1 ]] && continue
    cp "$info" "$info.bak-$(date +%Y%m%d-%H%M%S)"
    if [[ -n $cur ]]; then
        sed -i "/^\[LinkKey\]/,/^\[/ s/^Key=.*/Key=$new/" "$info"
    else
        printf '\n[LinkKey]\nKey=%s\nType=4\nPINLength=0\n' "$new" >> "$info"
    fi
done

if [[ $changed == 1 && $DRY == 0 ]]; then
    systemctl restart bluetooth
    echo "==> ключи обновлены, bluetooth перезапущен"
elif [[ $changed == 0 ]]; then
    echo "==> менять нечего"
fi
