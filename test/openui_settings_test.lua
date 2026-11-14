-- OpenUI 统一设置窗口黑盒测试（Issue #8 plan 步骤 1–4 冻结验收，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界（帧/EditBox/状态脚本），按 TOC 次序加载后断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_settings_test.lua（仓库任意位置可执行）

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
    local f = { shown = true }
    function f:SetText(s) self.text = s end
    function f:SetTextColor() end
    function f:SetAlpha() end
    function f:SetFont() end
    function f:SetPoint() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    return f
end
local function mkframe(frameType, name)
    local f = { frameType = frameType, name = name, shown = true,
                registered = {}, scripts = {}, textures = {}, fonts = {} }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:UnregisterEvent(e) self.registered[e] = nil end
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:CreateTexture() local x = mktex(); self.textures[#self.textures + 1] = x; return x end
    function f:CreateFontString() local x = mkfs(); self.fonts[#self.fonts + 1] = x; return x end
    function f:SetSize() end
    function f:SetPoint() end
    function f:SetAllPoints() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetAutoFocus() end
    function f:SetText(s) self.text = s end
    function f:GetText() return self.text end
    table.insert(frames, f)
    return f
end
function CreateFrame(frameType, name) return mkframe(frameType, name) end

UISpecialFrames = {}
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

local function btnBySuffix(suffix)
    for _, f in ipairs(frames) do
        if f.frameType == "Button" and f.themedLabel then
            local t = f.themedLabel.text:gsub("^[●%s]+", "")
            if t == suffix then return f end
        end
    end
end

local function btnByExact(text)
    for _, f in ipairs(frames) do
        if f.frameType == "Button" and f.themedLabel and f.themedLabel.text == text then
            return f
        end
    end
end

local function fsContains(fragment)
    for _, f in ipairs(frames) do
        for _, fs in ipairs(f.fonts or {}) do
            if fs.text and fs.text:find(fragment, 1, true) then return fs end
        end
    end
end

local function countType(frameType)
    local n = 0
    for _, f in ipairs(frames) do
        if f.frameType == frameType then n = n + 1 end
    end
    return n
end

-- ==== 按 TOC 次序加载（含 Settings） ====
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
    "UI/Settings.lua",
}
for _, file in ipairs(order) do
    local chunk = assert(loadfile(("%s/%s"):format(ADDON, file)))
    chunk("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local L = OpenUI.L
local T = OpenUI.Theme
local S = OpenUI.Settings
local Loc = OpenUI.Locale

print("== S1 开窗/打印/单实例/ESC（步骤 2）==")
output = {}
SlashCmdList.OPENUI("")
local win
for _, f in ipairs(frames) do
    if f.name == "OpenUISettings" then win = f end
end
check(win ~= nil and win:IsShown(), "裸 /openui 打开设置窗口")
local cmd = table.concat(output, " | ")
check(cmd:find("2026.11.0-dev.1", 1, true) ~= nil and cmd:find("Core", 1, true) ~= nil,
    "版本/模块打印保留（Q2）")
SlashCmdList.OPENUI("")
local wins = 0
for _, f in ipairs(frames) do
    if f.name == "OpenUISettings" then wins = wins + 1 end
end
check(wins == 1, "单实例：再次 /openui 不重复创建（" .. wins .. "）")
check(#UISpecialFrames >= 1 and UISpecialFrames[1] == "OpenUISettings", "ESC 关闭已注册")

print("== S2 导航与页面（步骤 2–3）==")
local navLabels = { "Appearance", "Language", "Modules", "About" }
local navFound = 0
for _, label in ipairs(navLabels) do
    if btnByExact(label) then navFound = navFound + 1 end
end
check(navFound == 4, "左导航 4 页（" .. navFound .. "）")
check(btnBySuffix("starblue") ~= nil, "外观页渲染 7 套配色按钮")
local btnBefore = countType("Button")
btnByExact("Language").scripts.OnClick()
check(countType("Button") == btnBefore + 3, "语言页切换并渲染 3 个选项")

print("== S3 搜索（步骤 4）==")
local box
for _, f in ipairs(frames) do
    if f.frameType == "EditBox" then box = f break end
end
check(box ~= nil, "搜索框存在")
box.text = "language"
box.scripts.OnTextChanged(box)
check(btnByExact("Language") ~= nil and btnByExact("Language"):IsShown(), "命中页保留")
check(btnByExact("Appearance") and not btnByExact("Appearance"):IsShown(), "未命中页隐藏")
box.text = "xyz"
box.scripts.OnTextChanged(box)
local anyShown = false
for _, label in ipairs(navLabels) do
    local b = btnByExact(label)
    if b and b:IsShown() then anyShown = true end
end
check(not anyShown, "无结果时导航全隐")
local nr = fsContains("No matching settings.")
check(nr ~= nil and nr:IsShown(), "无结果提示可见")
box.text = ""
box.scripts.OnTextChanged(box)
check(btnByExact("Appearance"):IsShown() and btnByExact("About"):IsShown(), "清空恢复全量导航")
check(nr ~= nil and not nr:IsShown(), "提示随清空隐藏")

print("== S4 页面功能即时生效（步骤 3）==")
btnByExact("Modules").scripts.OnClick()
btnBySuffix("teal").scripts.OnClick()
check(T.GetPalette() == "teal", "配色点击即时生效")
check(btnBySuffix("teal").themedLabel.text:find("●", 1, true) == 1, "当前配色选中标记")
btnBySuffix("zhCN").scripts.OnClick()
check(Loc.Get() == "zhCN" and L.VERSION_LINE:find("已加载", 1, true) ~= nil, "语言点击即时生效")
check(fsContains("OpenUI 设置") ~= nil, "窗口文案随语言刷新")
local toggle
for _, f in ipairs(frames) do
    if f.frameType == "Button" and f.themedLabel
        and f.themedLabel.text:find("Theme: ", 1, true) == 1 then
        toggle = f
    end
end
check(toggle ~= nil, "模块页 Toggle 存在")
toggle.scripts.OnClick()
check(OpenUI:IsModuleEnabled("Theme") == false, "Toggle 关闭模块生效")
check(fsContains("Theme: 关") ~= nil, "Toggle 文案反映关闭（zhCN）")
toggle.scripts.OnClick()
check(OpenUI:IsModuleEnabled("Theme") == true, "Toggle 重新开启模块")
btnBySuffix("关于").scripts.OnClick()
check(fsContains("2026.11.0-dev.1") ~= nil, "关于页含版本串")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)