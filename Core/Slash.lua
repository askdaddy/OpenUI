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

                -- #66：五图层着色矩阵（同色红 1,0,0,1 × 五层；独立裸 Frame，避免面板干扰）
                local matrix = CreateFrame("Frame", "OpenUIProbeLayers", UIParent)
                matrix:SetSize(640, 70)
                matrix:SetPoint("CENTER", UIParent, "CENTER", 0, -290)
                local layers = { "BACKGROUND", "BORDER", "ARTWORK", "HIGHLIGHT", "OVERLAY" }
                for index, layerName in ipairs(layers) do
                    local tex = matrix:CreateTexture(nil, layerName)
                    tex:SetPoint("TOPLEFT", matrix, "TOPLEFT", (index - 1) * 128, 0)
                    tex:SetSize(90, 40)
                    tex:SetColorTexture(1, 0, 0, 1)
                    local caption = OpenUI.Widgets.Text(matrix, layerName, "label")
                    caption:SetPoint("TOP", tex, "BOTTOM", 0, -2)
                end
                matrix:Show()
                -- 对照组：surface 色 × ARTWORK（独立帧，验证非红色行为）
                local control = CreateFrame("Frame", "OpenUIProbeControl", UIParent)
                control:SetSize(90, 40)
                control:SetPoint("LEFT", matrix, "RIGHT", 10, 12)
                local controlTex = control:CreateTexture(nil, "ARTWORK")
                controlTex:SetAllPoints(control)
                if surface then
                    controlTex:SetColorTexture(surface[1], surface[2], surface[3], 1)
                end
                control:Show()
                if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                    C_Timer.After(20, function() matrix:Hide(); control:Hide() end)
                end
                print("layers: BACKGROUND/BORDER/ARTWORK/HIGHLIGHT/OVERLAY all painted red")
                -- #68 probe v5：Widgets 链路 vs ForeverUI 裸克隆配方 并排对比
                local compare = CreateFrame("Frame", "OpenUIProbeCompare", UIParent)
                compare:SetSize(640, 220)
                compare:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
                compare:Show()

                local function caption(frame, text, x, y)
                    local fs = CreateFrame("Frame", nil, frame)
                    fs:SetSize(10, 10)
                    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
                    local label = fs:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    label:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 0)
                    label:SetText(text)
                    return label
                end

                -- A：Widgets.Panel
                local panelA = OpenUI.Widgets.Panel(compare)
                panelA:SetSize(180, 70)
                panelA:SetPoint("TOPLEFT", compare, "TOPLEFT", 10, -20)
                caption(compare, "A widgets", 10, -4)

                -- B：ForeverUI Install.lua Box 逐行复刻（无 Widgets）
                local boxB = CreateFrame("Frame", nil, compare)
                boxB:SetSize(180, 70)
                boxB:SetPoint("TOPLEFT", compare, "TOPLEFT", 210, -20)
                local fillB = boxB:CreateTexture(nil, "BACKGROUND", nil, -8)
                fillB:SetAllPoints()
                fillB:SetColorTexture(0.112, 0.126, 0.138, 0.88)
                local edgesB = { "top", "bottom", "left", "right" }
                for _, side in ipairs(edgesB) do
                    local e = boxB:CreateTexture(nil, "OVERLAY", nil, 7)
                    e:SetColorTexture(0.408, 0.408, 0.408, 0.95)
                    if side == "top" then e:SetPoint("TOPLEFT"); e:SetPoint("TOPRIGHT"); e:SetHeight(1)
                    elseif side == "bottom" then e:SetPoint("BOTTOMLEFT"); e:SetPoint("BOTTOMRIGHT"); e:SetHeight(1)
                    elseif side == "left" then e:SetPoint("TOPLEFT"); e:SetPoint("BOTTOMLEFT"); e:SetWidth(1)
                    else e:SetPoint("TOPRIGHT"); e:SetPoint("BOTTOMRIGHT"); e:SetWidth(1) end
                end
                caption(compare, "B raw recipe", 210, -4)

                -- C：裸字体 vs Widgets.Text
                local bareFs = compare:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                bareFs:SetPoint("TOPLEFT", compare, "TOPLEFT", 10, -110)
                bareFs:SetText("C raw font 0.917")
                bareFs:SetTextColor(0.917, 0.920, 0.922, 1)

                local widgetFs = OpenUI.Widgets.Text(compare, "C widgets font 0.917", "body")
                widgetFs:SetPoint("TOPLEFT", compare, "TOPLEFT", 210, -110)

                -- D：带阴影 vs 不带
                local shadowFs = compare:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                shadowFs:SetPoint("TOPLEFT", compare, "TOPLEFT", 10, -140)
                shadowFs:SetText("D raw font + shadow")
                shadowFs:SetTextColor(0.917, 0.920, 0.922, 1)
                shadowFs:SetShadowOffset(1, -1)
                shadowFs:SetShadowColor(0, 0, 0, 0.9)

                if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
                    C_Timer.After(25, function() compare:Hide() end)
                end

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
