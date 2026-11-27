#!/usr/bin/env bash
# Надёжное подключение Bluetooth-устройства с учётом дуалбута.
#
#   bt-connect.sh connect MAC   — подключить (если ключ устарел — пересопрячь)
#   bt-connect.sh pair MAC      — сопрячь новое устройство и подключить
#   bt-connect.sh disconnect MAC
#   bt-connect.sh forget MAC
#
# Пишет в stdout строки «STATE <код> <текст>» для quickshell:
#   STATE connecting | pairing | waiting | ok | fail
#
# Почему так: при дуалбуте Windows при каждом сопряжении генерирует новый ключ,
# и сохранённый в Linux ключ перестаёт подходить — connect падает с ошибкой
# аутентификации. Если же устройство просто выключено или далеко, ошибка другая
# (page timeout / host down) — в этом случае сопряжение НЕ трогаем.
set -u
export LC_ALL=C

act=${1:-}; mac=${2:-}
[[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || { echo "STATE fail неверный MAC"; exit 2; }
mac=${mac^^}

say() { echo "STATE $*"; }
info() { bluetoothctl info "$mac" 2>/dev/null; }
is() { info | grep -q "^\s*$1: yes"; }

ensure_power() {
    bluetoothctl show | grep -q "Powered: yes" && return
    rfkill unblock bluetooth 2>/dev/null
    bluetoothctl power on >/dev/null 2>&1
    sleep 1
}

try_connect() {
    local out
    out=$(timeout 20 bluetoothctl connect "$mac" 2>&1)
    last_err=$(grep -oE "(org\.bluez\.Error\.[A-Za-z]+[^\r\n]*|Failed to connect[^\r\n]*)" <<<"$out" | tail -1)
    # «Connected: yes» мелькает и при неверном ключе — успех только если соединение держится
    if grep -q "Connection successful" <<<"$out" || [[ -z $last_err ]]; then
        sleep 2
        is Connected && return 0
        [[ -z $last_err ]] && last_err="соединение сразу разорвано"
    fi
    return 1
}

# Ждём, пока устройство появится в эфире в режиме сопряжения
wait_discoverable() {
    local t=${1:-30}
    bluetoothctl --timeout "$t" scan on >/dev/null 2>&1 &
    local scan=$!
    for ((i = 0; i < t; i++)); do
        if bluetoothctl devices 2>/dev/null | grep -qi "$mac" && info | grep -q "RSSI"; then
            kill "$scan" 2>/dev/null; return 0
        fi
        sleep 1
    done
    kill "$scan" 2>/dev/null
    return 1
}

do_pair() {
    say pairing "сопряжение…"
    local out
    out=$(timeout 40 bluetoothctl pair "$mac" 2>&1)
    if ! is Paired; then
        say fail "не удалось сопрячь: $(grep -oE 'org\.bluez\.Error\.[A-Za-z]+' <<<"$out" | tail -1)"
        return 1
    fi
    bluetoothctl trust "$mac" >/dev/null 2>&1
    say connecting "подключение…"
    for _ in 1 2; do try_connect && { say ok "подключено"; return 0; }; sleep 2; done
    say fail "сопряжено, но не подключилось: $last_err"
    return 1
}

repair() {
    # Старый ключ невалиден (устройство сопрягали в Windows) — сопрягаемся заново
    say waiting "ключ устарел (Windows?). Включите на устройстве режим сопряжения"
    bluetoothctl remove "$mac" >/dev/null 2>&1
    sleep 1
    if ! wait_discoverable 40; then
        say fail "устройство не найдено в режиме сопряжения"
        return 1
    fi
    do_pair
}

ensure_power
last_err=""

case $act in
connect)
    is Connected && { say ok "уже подключено"; exit 0; }
    if ! is Paired; then
        wait_discoverable 25 || { say fail "устройство не найдено"; exit 1; }
        do_pair; exit $?
    fi
    bluetoothctl trust "$mac" >/dev/null 2>&1
    say connecting "подключение…"
    for attempt in 1 2; do
        try_connect && { say ok "подключено"; exit 0; }
        case $last_err in
            *page-timeout*|*host-down*|*NotReady*|*not\ available*|*InProgress*)
                [[ $attempt == 1 ]] && { sleep 2; continue; }
                say fail "устройство выключено или вне зоны"; exit 1 ;;
            *AlreadyConnected*) say ok "подключено"; exit 0 ;;
            *profile-unavailable*) say fail "нет аудио-профиля (pipewire/wireplumber?)"; exit 1 ;;
        esac
        break
    done
    # Любая другая ошибка у сопряжённого устройства — почти всегда рассинхрон ключа
    repair; exit $?
    ;;
pair)
    is Paired && is Connected && { say ok "уже подключено"; exit 0; }
    if is Paired; then bluetoothctl remove "$mac" >/dev/null 2>&1; sleep 1; fi
    say waiting "поиск устройства…"
    wait_discoverable 25 || { say fail "устройство не найдено"; exit 1; }
    do_pair; exit $?
    ;;
disconnect)
    bluetoothctl disconnect "$mac" >/dev/null 2>&1
    say ok "отключено"
    ;;
forget)
    bluetoothctl remove "$mac" >/dev/null 2>&1
    say ok "удалено"
    ;;
*)
    echo "STATE fail неизвестное действие"; exit 2 ;;
esac
