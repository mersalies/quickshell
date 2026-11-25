#!/usr/bin/env bash
# Установка конфига quickshell (Arch Linux + Hyprland).
#
#   git clone https://github.com/mersalies/quickshell ~/quickshell && cd ~/quickshell && ./install.sh
#
# Флаги:
#   --no-deps     не ставить пакеты
#   --copy        скопировать файлы вместо симлинка (по умолчанию симлинк — обновление через git pull)
#   --no-hypr     не трогать ~/.config/hypr/hyprland.lua
#   -y            не задавать вопросов
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.config/quickshell"
DEPS=1 COPY=0 HYPR=1 YES=0
for a in "$@"; do
    case $a in
        --no-deps) DEPS=0 ;;
        --copy) COPY=1 ;;
        --no-hypr) HYPR=0 ;;
        -y|--yes) YES=1 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "неизвестный флаг: $a"; exit 1 ;;
    esac
done

c() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
w() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
ask() { [[ $YES == 1 ]] && return 0; read -rp "$1 [Y/n] " r; [[ -z $r || $r =~ ^[YyДд] ]]; }

# ─── пакеты ───
PKGS=(
    quickshell hyprland qt6-5compat qt6-multimedia-ffmpeg qt6-svg
    python glib2 jq curl imagemagick ffmpeg
    awww swaync libnotify grim
    pipewire wireplumber pavucontrol playerctl cava
    networkmanager bluez bluez-utils upower power-profiles-daemon
    brightnessctl lm_sensors
    ttf-jetbrains-mono-nerd
)
AUR_PKGS=(python-pywal mpvpaper)                 # нужны
AUR_OPTIONAL=(linux-wallpaperengine-git)          # scene-обои Wallpaper Engine

if [[ $DEPS == 1 ]]; then
    if ! command -v pacman >/dev/null; then
        w "не Arch — поставьте зависимости вручную (список в README)"
    else
        c "Пакеты из репозиториев"
        sudo pacman -S --needed "${PKGS[@]}"
        helper=""
        for h in paru yay; do command -v $h >/dev/null && { helper=$h; break; }; done
        if [[ -n $helper ]]; then
            c "Пакеты из AUR ($helper)"
            $helper -S --needed "${AUR_PKGS[@]}"
            ask "Поставить linux-wallpaperengine (живые обои из Steam, долго собирается)?" \
                && $helper -S --needed "${AUR_OPTIONAL[@]}" || true
        else
            w "нет paru/yay — поставьте из AUR вручную: ${AUR_PKGS[*]}"
        fi
        c "Службы"
        sudo systemctl enable --now bluetooth.service power-profiles-daemon.service 2>/dev/null || true
    fi
fi

# ─── файлы ───
if [[ "$(realpath -m "$TARGET")" == "$REPO" ]]; then
    c "Репозиторий уже лежит в $TARGET"
else
    if [[ -e $TARGET || -L $TARGET ]]; then
        bak="$TARGET.bak-$(date +%Y%m%d-%H%M%S)"
        c "Старый конфиг → $bak"
        mv "$TARGET" "$bak"
    fi
    mkdir -p "$(dirname "$TARGET")"
    if [[ $COPY == 1 ]]; then
        c "Копирую в $TARGET"
        cp -r "$REPO" "$TARGET"
        rm -rf "$TARGET/.git"
    else
        c "Симлинк $TARGET → $REPO"
        ln -s "$REPO" "$TARGET"
    fi
fi
chmod +x "$REPO"/scripts/*.sh "$REPO"/scripts/*.py "$REPO/install.sh"
mkdir -p "$HOME/wallpapers" "$REPO/state"

# ─── Hyprland ───
HL="$HOME/.config/hypr/hyprland.lua"
LINE='pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/hypr/quickshell.lua") -- quickshell'
if [[ $HYPR == 1 ]]; then
    if [[ -f $HL ]]; then
        if grep -qF "/.config/quickshell/hypr/quickshell.lua" "$HL"; then
            c "hyprland.lua уже подключает quickshell"
        elif ask "Добавить автозапуск и бинды quickshell в $HL?"; then
            cp "$HL" "$HL.bak-quickshell"
            printf '\n%s\n' "$LINE" >> "$HL"
            c "Готово (бэкап: $HL.bak-quickshell)"
        fi
    else
        w "Нет $HL. Конфиг рассчитан на Lua-конфиг Hyprland (0.53+)."
        w "Для hyprland.conf добавьте вручную:  exec-once = quickshell  (см. README)"
    fi
fi

c "Готово. Положите обои в ~/wallpapers и перезапустите Hyprland (или выполните: quickshell)"
