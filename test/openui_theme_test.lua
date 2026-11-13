-- OpenUI 主题系统黑盒测试（Issue #3 plan 步骤 1–6 冻结验收，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界，按 TOC 次序加载插件文件后断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_theme_test.lua（仓库任意位置可执行）

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.." -- 包根即仓库根（D54）

local ns = {}
local output = {} -- print 捕获
local passCount, failCount = 0, 0
local failures = {}

-- ==== WoW 环境桩（与 openui_skeleton_test.lua 同型） ====
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    output[#output + 1] = table.concat(parts, " ")
end

function strtrim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function GetAddOnMetadata(name, field)
    if name == "OpenUI" and field == "Version" then
        return "2026.11.0-dev.1"
    end
end

function GetLocale()
    return "enUS"
end

local frame
function CreateFrame(frameType)
    frame = { frameType = frameType, registered = {}, scripts = {} }
    function frame:RegisterEvent(ev) self.registered[ev] = true end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    return frame
end

SlashCmdList = {}

-- ==== 断言工具 ====
local function check(cond, label)
    if cond then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        failures[#failures + 1] = label
    end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end

local function colorEq(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for i = 1, 4 do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function diagnoseHas(fragment)
    for _, e in ipairs(ns.OpenUI.Diagnose.Errors()) do
        if e:find(fragment, 1, true) then return true end
    end
    return false
end

-- ==== 按 TOC 次序加载插件文件 ====
local order = {
    "Init.lua",
    "Locales/enUS.lua",
    "Locales/zhCN.lua",
    "Config/Defaults.lua",
    "Core/Core.lua",
    "Core/Slash.lua",
    "UI/Theme.lua",
}
for _, file in ipairs(order) do
    local chunk = assert(loadfile(("%s/%s"):format(ADDON, file)))
    chunk("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local T = OpenUI.Theme

print("== S1 预设注册表与读取（步骤 1）==")
local tokens = T.Tokens()
check(#tokens == 17, "Tokens() 计数 = 17（实际 " .. #tokens .. "）")
local allResolved = true
for _, tok in ipairs(tokens) do
    if T.Get(tok) == nil then allResolved = false end
end
check(allResolved, "全部 token Get 非 nil")
check(colorEq(T.Get("color.bg"), { 0.09, 0.09, 0.11, 1 }), "color.bg 冻结默认值逐元素相等")
check(T.Get("opacity.panel") == 0.95, "opacity.panel == 0.95")
check(type(T.Get("font.normal")) == "table" and T.Get("font.normal").size == 13
    and T.Get("font.normal").file == nil, "font.normal size=13 且 file 为 nil")
check(T.Get("border.size") == 1, "border.size == 1")
check(T.Get("spacing.medium") == 8, "spacing.medium == 8")
check(T.Get("size.cornerRadius") == 4, "size.cornerRadius == 4")
check(T.Get("no.such") == nil, "未知 token Get 返回 nil 不抛错")

print("== S2 全局定制 Set/Reset（步骤 2，ADDON_LOADED 后）==")
frame.scripts.OnEvent(frame, "ADDON_LOADED", "OpenUI")
local ok1 = T.Set("opacity.panel", 0.5)
check(ok1 == true and T.Get("opacity.panel") == 0.5
    and _G.OpenUIDB.theme["opacity.panel"] == 0.5, "Set 后生效值与 OpenUIDB.theme 同步为 0.5")
T.Reset("opacity.panel")
check(T.Get("opacity.panel") == 0.95 and _G.OpenUIDB.theme["opacity.panel"] == nil,
    "Reset 后回预设 0.95 且 DB 键清除")
check(T.Set("opacity.panel", 5) == false and T.Get("opacity.panel") == 0.95,
    "越界值 Set 返回 false 且值不变")
check(diagnoseHas("Theme") and diagnoseHas("opacity.panel"),
    "软失败进诊断队列（含 Theme 归属与 token 名）")
check(T.Set("no.such", 1) == false, "未知 token Set 返回 false 不抛错")

print("== S3 模块覆盖与分别重置（步骤 3）==")
check(T.SetOverride("Bars", "color.bg", { 0, 0, 0, 1 }) == true, "合法覆盖返回 true")
check(colorEq(T.GetFor("Bars", "color.bg"), { 0, 0, 0, 1 }), "GetFor 取到覆盖值")
check(colorEq(T.Get("color.bg"), { 0.09, 0.09, 0.11, 1 }), "全局值不受覆盖影响")
check(colorEq(T.GetFor("Chat", "color.bg"), { 0.09, 0.09, 0.11, 1 }), "其他模块取全局值（隔离）")
check(_G.OpenUIDB.theme["color.bg"] == nil, "覆盖不落 OpenUIDB")
T.ResetOverride("Bars", "color.bg")
check(colorEq(T.GetFor("Bars", "color.bg"), { 0.09, 0.09, 0.11, 1 }), "单项重置回全局值")
T.SetOverride("Bars", "spacing.small", 6)
T.ResetOverride("Bars")
check(T.GetFor("Bars", "spacing.small") == 4, "无参重置清空该模块全部覆盖")
check(T.SetOverride("Bars", "color.bg", { 1, 2 }) == false
    and colorEq(T.GetFor("Bars", "color.bg"), { 0.09, 0.09, 0.11, 1 }),
    "非法覆盖值返回 false 且不生效")

print("== S4 兼容 shim（步骤 4）==")
check(T.GetColor("bg") == T.colors.bg, "GetColor 与 colors 视图恒等")
check(T.GetColor("textDim") ~= nil, "新色 textDim 进旧视图")
check(T.GetColor("nonexistent") == nil, "未定义颜色返回 nil")
T.Set("font.normal", { size = 20 })
check(T.GetFont("normal") == "GameFontNormal", "字体旧视图静态（Set 后仍 GameFontNormal）")

print("== S5 模块注册与生命周期（步骤 5）==")
output = {}
SlashCmdList.OPENUI("")
local cmd = table.concat(output, " | ")
check(cmd:find("Theme", 1, true) ~= nil, "/openui 模块列表含 Theme")
_G.OpenUIDB = { configVersion = 1, theme = { ["opacity.panel"] = 0.7 } }
frame.scripts.OnEvent(frame, "ADDON_LOADED", "OpenUI")
check(T.Get("opacity.panel") == 0.7, "DB 合法定制值经 OnInitialize 生效")
_G.OpenUIDB = { configVersion = 1, theme = { ["opacity.panel"] = "abc" } }
frame.scripts.OnEvent(frame, "ADDON_LOADED", "OpenUI")
check(T.Get("opacity.panel") == 0.95, "DB 非法值回预设")
check(_G.OpenUIDB.theme["opacity.panel"] == "abc", "DB 非法值不被清洗")
check(diagnoseHas("opacity.panel"), "非法值进诊断队列")

print("== S6 配置默认节点与本地化（步骤 6）==")
local m = OpenUI.Config.MergeDefaults(nil)
check(type(m.theme) == "table", "MergeDefaults(nil) 含 theme 表")
local u = OpenUI.Config.MergeDefaults({ configVersion = 1, theme = { ["spacing.small"] = 6 } })
check(u.theme["spacing.small"] == 6, "用户 theme 值合并后保留")
check(OpenUI.L.THEME_INVALID:find("%%s") ~= nil
    and OpenUI.L.THEME_INVALID:find("Invalid", 1, true) ~= nil,
    "enUS THEME_INVALID 为含 %s 的英文串")
function GetLocale() return "zhCN" end
assert(loadfile(ADDON .. "/Locales/zhCN.lua"))("OpenUI", ns)
check(OpenUI.L.THEME_INVALID:find("无效", 1, true) ~= nil
    and OpenUI.L.THEME_INVALID:find("%%s") ~= nil,
    "zhCN 重载后为含 %s 的中文串")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)
