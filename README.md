# quickshell

Оболочка рабочего стола для **Hyprland** на [Quickshell](https://quickshell.org): бар, лаунчер, обои, пульт управления, музыка, Wi-Fi/Bluetooth.
Цвета берутся из обоев через pywal.

## Что внутри

- **Бар**: рабочие столы, раскладка клавиатуры, часы с таймером, секундомером, будильником и календарём, сейчас играет + визуализатор cava, CPU/GPU/RAM/VRAM, батарея, Wi-Fi, Bluetooth.
- **Громкость**: колесо меняет громкость, ЛКМ — mute, ПКМ — pavucontrol. При наведении выпадает микшер: устройство вывода, MPRIS-плееры (⏮ ⏯ ⏭) и отдельная громкость/mute для каждого приложения.
- **Лаунчер** (панель слева), вкладки:
  - **Пульт**: Wi-Fi / Bluetooth / «Не беспокоить» / режим питания;
    устройства с кольцами заряда в стиле iOS (Bluetooth, 2.4G, USB, индикатор зарядки);
    мониторы — перетаскивание, разрешение, частота, поворот, масштаб, откат через 15 с;
    курсор — галерея тем с превью и любой размер.
  - **Walls / Fav**: обои (картинки, GIF, видео через mpvpaper, scene-обои Wallpaper Engine), разные обои на разные мониторы, избранное.
  - **Apps**: поиск приложений с сортировкой по частоте запуска.
- **Музыка**, **дашборд**, панели **Wi-Fi**, **Bluetooth**, **режимов питания**.
- Подключение Bluetooth через `scripts/bt-connect.sh`: если при дуалбуте Windows сменила ключ сопряжения, скрипт сам пересопрягает устройство, а выключенное устройство не трогает.
- `sudo scripts/bt-dualboot-sync.sh` копирует ключи Bluetooth из реестра Windows в Linux: устройство работает в обеих системах без пересопряжения (нужен пакет `hivex`). Порядок: сопрячь в Linux → сопрячь в Windows → загрузиться в Linux и запустить скрипт.

## Установка

Arch Linux, Hyprland **0.53+ с Lua-конфигом** (`~/.config/hypr/hyprland.lua`).

```bash
git clone https://github.com/mersalies/quickshell ~/quickshell
cd ~/quickshell
./install.sh
```

Скрипт:
1. ставит пакеты через `pacman` и AUR (`paru`/`yay`);
2. сохраняет старый `~/.config/quickshell` в `*.bak-<дата>` и делает симлинк на репозиторий (обновление — `git pull`);
3. добавляет в `hyprland.lua` одну строку, которая подключает [`hypr/quickshell.lua`](hypr/quickshell.lua): автозапуск, бинды, загрузку настроек мониторов и курсора из «Пульта».

Флаги: `--no-deps`, `--copy` (копия вместо симлинка), `--no-hypr`, `-y`.

Обои кладите в `~/wallpapers`.

### Зависимости

Репозитории: `quickshell hyprland qt6-5compat qt6-multimedia-ffmpeg qt6-svg python glib2 jq curl imagemagick ffmpeg awww swaync libnotify grim pipewire wireplumber pavucontrol playerctl cava networkmanager bluez bluez-utils upower power-profiles-daemon brightnessctl lm_sensors ttf-jetbrains-mono-nerd`, для синхронизации Bluetooth с Windows — `hivex ntfs-3g`

AUR: `python-pywal mpvpaper`, по желанию `linux-wallpaperengine-git`.

### Если у вас `hyprland.conf`

Всё, кроме сохранения мониторов из «Пульта», работает и так: добавьте `exec-once = quickshell`, `exec-once = awww-daemon`, `exec-once = swaync` и бинды из таблицы ниже.

## Горячие клавиши / IPC

| Бинд (по умолчанию) | Команда |
|---|---|
| `Super+D` | `qs ipc call launcher toggle` |
| `Super+W` | `qs ipc call wallpaper toggle` |
| `Super+C` | `qs ipc call control toggle` |
| `Super+M` | `qs ipc call music toggle` |
| — | `qs ipc call dashboard toggle` |
| — | `qs ipc call wifi toggle` / `bluetooth toggle` |
| — | `qs ipc call timer start 300` |

## Структура

```
shell.qml            корень: состояние, процессы, IPC
components/          бар, лаунчер, пульт, микшер, панели
scripts/             обои, обложки/тексты песен, bluetooth, сохранение настроек пульта
hypr/quickshell.lua  подключение к Hyprland
assets/              аватарки и гифки для дашборда
```
