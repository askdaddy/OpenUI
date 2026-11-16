-- /openui 命令（D01）：回显版本与模块列表；/openui errors 输出诊断队列。

local _, ns = ...
local OpenUI = ns.OpenUI
local L = OpenUI.L

local function moduleList()
    local names = {}
    for _, module in ipairs(OpenUI.moduleOrder) do
        names[#names + 1] = module.name
    end
    return table.concat(names, ", ")
end

SLASH_OPENUI1 = "/openui"

SlashCmdList["OPENUI"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "edit" then
        if OpenUI.EditMode then
            local on = OpenUI.EditMode.Toggle()
            print(L.EDIT_MODE_HINT:format(on and L.SETTINGS_GRID_ON or L.SETTINGS_GRID_OFF))
        end
        return
    end
    if msg:match("^grid") then
        if OpenUI.Grid then
            local size = tonumber(msg:match("^grid%s+(%d+)$"))
            if size and OpenUI.Grid.SetSize(size) then
                OpenUI.Grid.Show()
                print(L.SETTINGS_GRID_SIZE_FMT:format(size))
            else
                local shown = OpenUI.Grid.Toggle()
                print(L.GRID_TOGGLE_HINT:format(shown and L.SETTINGS_GRID_ON or L.SETTINGS_GRID_OFF))
            end
        end
        return
    end
    if msg == "probe" then
        -- 现场诊断（#8/#11 验收修复）：窗口/按钮几何与动作槽数据
        local S = OpenUI.Settings
        print("probe: GetActionTexture=" .. type(GetActionTexture)
            .. " GetActionBarPage=" .. type(GetActionBarPage)
            .. " C_ActionBar=" .. type(C_ActionBar))
        if S and S.IsOpen then
            print("settings open=" .. tostring(S.IsOpen()))
        end
        local function printThemeLine()
            local surf = OpenUI.Theme.Get("color.surface")
            local onSurf = OpenUI.Theme.Get("color.on-surface")
            local outline = OpenUI.Theme.Get("color.outline")
            print(("theme palette=%s surface=%.3f/%.3f/%.3f onSurface=%.3f outline=%.3f opacity=%.2f")
                :format(tostring(OpenUI.Theme.GetPalette()),
                    surf and surf[1] or -1, surf and surf[2] or -1, surf and surf[3] or -1,
                    onSurf and onSurf[1] or -1, outline and outline[1] or -1,
                    OpenUI.Theme.Get("opacity.panel") or -1))
            -- #60：打印 OpenUIDB.theme 全部键值（检测旧/异常定制）
            local theme = _G.OpenUIDB and _G.OpenUIDB.theme
            if type(theme) == "table" then
                local parts = {}
                for key, value in pairs(theme) do
                    local text
                    if type(value) == "table" then
                        text = ("{%.3f,%.3f,%.3f,%.3f}"):format(
                            value[1] or -1, value[2] or -1, value[3] or -1, value[4] or -1)
                    else
                        text = tostring(value)
                    end
                    parts[#parts + 1] = key .. "=" .. text
                end
                table.sort(parts)
                print("theme-db: " .. (#parts > 0 and table.concat(parts, " ") or "(empty)"))
            else
                print("theme-db: (nil)")
            end
        end
        printThemeLine()
        if OpenUI.Widgets and OpenUI.Widgets.DebugInfo then
            print(OpenUI.Widgets.DebugInfo())
        end
        -- #58：客户端像素自证——两个色块（红=SetColorTexture；绿=WHITE8X8+SetVertexColor），10 秒后自动消失
        do
            local swatch = CreateFrame("Frame", "OpenUIProbeSwatch", UIParent)
            swatch:SetSize(260, 70)
            swatch:SetPoint("CENTER", UIParent, "CENTER", 0, -260)
            local red = swatch:CreateTexture(nil, "ARTWORK")
            red:SetPoint("TOPLEFT", swatch, "TOPLEFT", 0, 0)
            red:SetSize(120, 60)
            red:SetColorTexture(1, 0, 0, 1)
            local green = swatch:CreateTexture(nil, "ARTWORK")
            green:SetPoint("TOPLEFT", swatch, "TOPLEFT", 140, 0)
            green:SetSize(120, 60)
            if red.SetTexture then green:SetTexture("Interface\\Buttons\\WHITE8X8") end
            if type(green.SetVertexColor) == "function" then green:SetVertexColor(0, 1, 0, 1) end
            swatch:Show()
            -- #64 probe v3：屏上主题读数 + 四对照条 + 主条帧名扫描
            local probePanel = OpenUI.Widgets and OpenUI.Widgets.Panel(UIParent)
            if probePanel then
                probePanel:SetSize(560, 150)
                probePanel:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
                local surface = OpenUI.Theme.Get("color.surface-container")
                local onSurface = OpenUI.Theme.Get("color.on-surface")
                local function fmtColor(c)
                    if type(c) ~= "table" then return "nil" end
                    return ("%.3f/%.3f/%.3f"):format(c[1] or -1, c[2] or -1, c[3] or -1)
                end
                local info = ("surface=%s on=%s opacity=%.2f palette=%s")
                    :format(fmtColor(surface), fmtColor(onSurface),
                        OpenUI.Theme.Get("opacity.panel") or -1,
                        tostring(OpenUI.Theme.GetPalette()))
                local infoText = OpenUI.Widgets.Text(probePanel, info, "label")
                infoText:SetPoint("TOPLEFT", probePanel, "TOPLEFT", 10, -8)

                -- 四条对照条
                local function strip(x, label, painter)
                    local tex = probePanel:CreateTexture(nil, "ARTWORK")
                    tex:SetPoint("TOPLEFT", probePanel, "TOPLEFT", x, -40)
                    tex:SetSize(120, 44)
                    painter(tex)
                    local caption = OpenUI.Widgets.Text(probePanel, label, "label")
                    caption:SetPoint("TOP", tex, "BOTTOM", 0, -4)
                end
                strip(10, "alpha1", function(tex)
                    if surface then tex:SetColorTexture(surface[1], surface[2], surface[3], 1) end
                end)
                strip(150, "a088", function(tex)
                    if surface then tex:SetColorTexture(surface[1], surface[2], surface[3], 0.88) end
                end)
                strip(290, "vtx", function(tex)
                    if surface and type(tex.SetTexture) == "function" then
                        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
                        if type(tex.SetVertexColor) == "function" then
                            tex:SetVertexColor(surface[1], surface[2], surface[3], 1)
                        end
                    end
                end)
                strip(430, "ref05", function(tex)
                    tex:SetColorTexture(0.5, 0.5, 0.5, 1)
                end)

                -- 主条帧名扫描
                local candidates = {}
                for name, value in pairs(_G) do
                    if type(name) == "string" and type(value) == "table"
                        and type(value.IsObjectType) == "function"
                        and value:IsObjectType("Frame")
                        and (name:find("MainMenu", 1, true) or name:find("MainBar", 1, true)) then
                        candidates[#candidates + 1] = name
                    end
                end
                table.sort(candidates)
                local lines = {}
                for i = 1, math.min(#candidates, 6) do
                    lines[#lines + 1] = candidates[i]
                end
                local scan = "frames: " .. (#lines > 0 and table.concat(lines, " | ") or "(none)")
                local scanText = OpenUI.Widgets.Text(probePanel, scan, "label")
                scanText:SetPoint("TOPLEFT", probePanel, "TOPLEFT", 10, -108)
                scanText:SetWidth(540)
                print(scan)
                if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                    C_Timer.After(20, function() probePanel:Hide() end)
                end
            end
            -- 结尾重复主题行，避免聊天滚动
            printThemeLine()
            if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                C_Timer.After(10, function() swatch:Hide() end)
            end
        end
        if OpenUI.Native and OpenUI.Native.Snapshot then
            local snapshot = OpenUI.Native.Snapshot()
            print("native hiding (" .. #snapshot .. "): " .. table.concat(snapshot, " | "))
        end
        if OpenUI.ActionBars then
            local bar = OpenUI.ActionBars.MainBar()
            local buttons = OpenUI.ActionBars.MainButtons()
            if bar and buttons and buttons[1] then
                print(("actionbar shown=%s buttons=%d"):format(tostring(bar:IsShown()), #buttons))
                for i = 1, 3 do
                    local tex = (type(GetActionTexture) == "function") and GetActionTexture(i) or nil
                    print(("slot %d texture=%s"):format(i, tostring(tex)))
                end
            end
        end
        return
    end
    if msg == "errors" then
        local recorded = OpenUI.Diagnose.Errors()
        if #recorded == 0 then
            print(L.NO_ERRORS)
        else
            print(L.ERRORS_HEADER:format(#recorded))
            for i, err in ipairs(recorded) do
                print(L.ERRORS_ITEM:format(i, err))
            end
        end
        -- #10：追加可复制视图（未加载时零影响）
        if OpenUI.Diagnostics then OpenUI.Diagnostics.Open() end
        return
    end
    print(L.VERSION_LINE:format(OpenUI.version))
    print(L.MODULES_LINE:format(moduleList()))
    -- #8 Q2：追加打开设置窗口（Settings 未加载时零影响）
    if OpenUI.Settings then OpenUI.Settings.Open() end
end
