-- Интеграция quickshell с Hyprland (Lua-конфиг, Hyprland 0.53+).
-- Подключается из ~/.config/hypr/hyprland.lua строкой, которую добавляет install.sh:
--   pcall(dofile, os.getenv("HOME") .. "/.config/quickshell/hypr/quickshell.lua")

local home = os.getenv("HOME")

-- Настройки вкладки «Пульт» (мониторы и курсор) — файл пишет сам quickshell
CC = CC or { cursor = { theme = "Adwaita", size = 24 }, monitors = {} }
do
    local ok, cc = pcall(dofile, home .. "/.config/hypr/control-center.lua")
    if ok and type(cc) == "table" then
        if type(cc.cursor) == "table" and cc.cursor.theme then CC.cursor = cc.cursor end
        if type(cc.monitors) == "table" then CC.monitors = cc.monitors end
    end
    for _, m in ipairs(CC.monitors) do pcall(hl.monitor, m) end
    hl.env("XCURSOR_THEME", CC.cursor.theme)
    hl.env("XCURSOR_SIZE", tostring(CC.cursor.size))
    hl.env("HYPRCURSOR_SIZE", CC.cursor.size)
end

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor " .. CC.cursor.theme .. " " .. CC.cursor.size)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("swaync")
    hl.exec_cmd("wal -n -R")
    hl.exec_cmd(home .. "/.config/quickshell/scripts/wallpaper.sh restore")
    hl.exec_cmd("quickshell")
end)

-- Горячие клавиши (поменяйте под себя)
hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("qs ipc call control toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("qs ipc call music toggle"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("pkill quickshell; sleep 0.5; quickshell"))
