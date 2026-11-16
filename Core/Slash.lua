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
    if msg == "probe" then
        -- 现场诊断（#8/#11 验收修复）：窗口/按钮几何与动作槽数据
        local S = OpenUI.Settings
        print("probe: GetActionTexture=" .. type(GetActionTexture)
            .. " GetActionBarPage=" .. type(GetActionBarPage)
            .. " C_ActionBar=" .. type(C_ActionBar))
        if S and S.IsOpen then
            print("settings open=" .. tostring(S.IsOpen()))
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
