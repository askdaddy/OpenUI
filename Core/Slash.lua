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
