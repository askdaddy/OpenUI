-- OpenUI M3 Expressive 主题黑盒测试（Issue #7 plan 步骤 1–4 冻结验收，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界（含 Texture/FontString/状态脚本捕获），按 TOC 次序加载后断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_theme_m3_test.lua（仓库任意位置可执行）

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.." -- 包根即仓库根（D54）

local ns = {}
local output = {}
local passCount, failCount = 0, 0
local failures = {}

-- ==== WoW 环境桩 ====
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

local frames = {}
local function mktex()
    local t = {}
    function t:SetAllPoints() end
    function t:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function t:SetAlpha(a) self.alpha = a end
    return t
end
local function mkfs()
    local f = {}
    function f:SetText(s) self.text = s end
    function f:SetTextColor(r, g, b, a) self.tr, self.tg, self.tb, self.ta = r, g, b, a end
    function f:SetAlpha(a) self.fa = a end
    function f:SetFont(file, size, flags) self.font = file; self.size = size end
    return f
end
local function mkframe(frameType)
    local f = { frameType = frameType, registered = {}, scripts = {}, textures = {}, fonts = {} }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:UnregisterEvent(e) self.registered[e] = nil end
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:CreateTexture() local tex = mktex(); self.textures[#self.textures + 1] = tex; return tex end
    function f:CreateFontString() local fs = mkfs(); self.fonts[#self.fonts + 1] = fs; return fs end
    table.insert(frames, f)
    return f
end
function CreateFrame(frameType) return mkframe(frameType) end

SlashCmdList = {}
C_Timer = { tickers = {} }
function C_Timer.NewTicker(interval, fn)
    local t = { cancelled = false }
    function t:Cancel() self.cancelled = true end
    table.insert(C_Timer.tickers, t)
    return t
end

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

-- ==== 按 TOC 次序加载（含 Widgets） ====
local order = {
    "Init.lua",
    "Locales/enUS.lua",
    "Locales/zhCN.lua",
    "Config/Defaults.lua",
    "Core/Core.lua",
    "Core/Resources.lua",
    "Core/Slash.lua",
    "Locales/Manager.lua",
    "UI/Theme.lua",
    "UI/Widgets.lua",
}
for _, file in ipairs(order) do
    local chunk = assert(loadfile(("%s/%s"):format(ADDON, file)))
    chunk("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local T = OpenUI.Theme
local W = OpenUI.Widgets
local coreFrame = frames[1]

print("== S1 色彩引擎与 M3 角色（步骤 1）==")
local tokens = T.Tokens()
check(#tokens == 54, "Tokens() 计数 = 54（实际 " .. #tokens .. "）")
local allResolved = true
for _, tok in ipairs(tokens) do
    if T.Get(tok) == nil then allResolved = false end
end
check(allResolved, "全部 token Get 非 nil")
check(colorEq(T.Get("color.surface"), { 0.068, 0.0755, 0.082, 1 }), "starblue surface 冻结实测值")
check(colorEq(T.Get("color.surface-container"), { 0.1118, 0.1259, 0.1382, 1 }), "surface-container 冻结实测值")
check(colorEq(T.Get("color.primary"), { 0.5724, 0.7298, 0.8676, 1 }), "primary 冻结实测值")
check(colorEq(T.Get("color.on-surface"), { 0.9175, 0.9202, 0.9225, 1 }), "on-surface 冻结实测值")
check(colorEq(T.Get("color.outline-variant"), { 0.254, 0.2817, 0.306, 1 }), "outline-variant 冻结实测值")
check(T.Get("color.bg") == T.Get("color.surface"), "别名 bg==surface 同对象")
check(T.Get("color.panel") == T.Get("color.surface-container"), "别名 panel 同对象")
check(T.Get("color.border") == T.Get("color.outline-variant"), "别名 border 同对象")
check(T.Get("color.text") == T.Get("color.on-surface"), "别名 text 同对象")
check(T.Get("color.textDim") == T.Get("color.on-surface-variant"), "别名 textDim 同对象")
check(T.Get("color.accent") == T.Get("color.primary"), "别名 accent 同对象")
check(T.Get("color.warn") == T.Get("color.tertiary"), "别名 warn 同对象")
check(T.Get("color.danger") == T.Get("color.error"), "别名 danger 同对象")
check(T.Get("font.normal").size == 13 and T.Get("font.normal").file == nil, "旧字体 token 语义保持")
check(T.Get("border.size") == 1 and T.Get("spacing.medium") == 8
    and T.Get("size.cornerRadius") == 4 and T.Get("opacity.panel") == 0.95, "旧数值 token 保持")
check(T.Get("no.such") == nil, "未知 token 返回 nil")

print("== S2 七套配色与迁移（步骤 2）==")
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
check(T.GetPalette() == "starblue", "缺省配色 starblue")
local sbSurface = T.Get("color.surface")
check(T.SetPalette("teal") == true and T.GetPalette() == "teal"
    and _G.OpenUIDB.theme.palette == "teal", "SetPalette(teal) 生效并持久化")
check(not colorEq(T.Get("color.surface"), sbSurface), "teal surface 与 starblue 不同")
for _, name in ipairs({ "amber", "amethyst", "rose", "moss", "graphite", "starblue" }) do
    check(T.SetPalette(name) == true and T.GetPalette() == name, "七套往返: " .. name)
end
local errBefore = #OpenUI.Diagnose.Errors()
check(T.SetPalette("bogus") == false and T.GetPalette() == "starblue"
    and _G.OpenUIDB.theme.palette == "starblue", "非法配色拒绝且不变")
check(T.SetPalette("TEAL") == false, "大写配色名拒绝")
check(#OpenUI.Diagnose.Errors() >= errBefore + 2 and diagnoseHas("Theme"), "非法配色进诊断报告")
check(T.Set("color.primary", { 1, 0, 0, 1 }) == true, "设置角色定制")
check(T.SetPalette("amber") == true and colorEq(T.Get("color.primary"), { 1, 0, 0, 1 }),
    "切换配色保留用户定制")
T.Reset("color.primary")
_G.OpenUIDB = OpenUI.Config.MergeDefaults({ theme = { ["color.accent"] = { 0, 1, 0, 1 } } })
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
check(colorEq(T.Get("color.primary"), { 0, 1, 0, 1 }), "旧键定制迁移到角色读取")
check(_G.OpenUIDB.theme["color.primary"] ~= nil and _G.OpenUIDB.theme["color.accent"] ~= nil,
    "迁移写入角色键且保留旧键")

print("== S3 排版/形状/状态/动效（步骤 3）==")
check(T.Get("type.body").size == 13 and T.Get("type.label").size == 11
    and T.Get("type.display").size == 24 and T.Get("type.body").file == nil, "type 角色存在与字号")
check(T.Get("shape.sm") == 4 and T.Get("shape.full") == 999, "shape 等级")
check(T.Get("state.hover") == 0.08 and T.Get("state.disabled") == 0.38, "state 层不透明度")
check(T.Get("motion.duration-short") == 0.15 and T.Get("motion.easing-standard") == "OUT_QUAD",
    "motion token")
check(T.Set("type.body", { size = 15 }) == true and T.Get("type.body").size == 15,
    "font kind 定制合法")
check(T.Set("state.hover", 2) == false, "数值越界拒绝")
check(T.Set("motion.easing-standard", 1) == false, "string kind 类型错误拒绝")

print("== S4 控件工厂（步骤 4）==")
local parent = CreateFrame("Frame")
local panel = W.Panel(parent)
local panelBg = panel.textures[1]
local sc = T.Get("color.surface-container")
check(panelBg.r == sc[1] and panelBg.g == sc[2] and panelBg.b == sc[3]
    and panelBg.a == 0.95, "Panel 背景 = surface-container × opacity.panel")
local button = W.Button(parent, "OK")
local btnOverlay = button.textures[2]
check(button.fonts[1].text == "OK", "Button 标签文本")
check(btnOverlay.a == 0, "Button 默认状态层 alpha=0")
button.scripts.OnEnter(button)
check(btnOverlay.a == 0.08, "悬停 alpha = state.hover")
button.scripts.OnMouseDown(button)
check(btnOverlay.a == 0.12, "按下 alpha = state.pressed")
button.scripts.OnMouseUp(button)
check(btnOverlay.a == 0.08, "抬起回悬停")
button.scripts.OnLeave(button)
check(btnOverlay.a == 0, "移出清空状态层")
local text = W.Text(parent, "hi", "body")
check(type(text) == "table" and text.text == "hi", "Text 返回 FontString 且含文本")
T.SetPalette("moss")
local mossSc = T.Get("color.surface-container")
check(panelBg.r == mossSc[1] and panelBg.g == mossSc[2] and panelBg.b == mossSc[3],
    "切换配色后既有控件原地换色")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)