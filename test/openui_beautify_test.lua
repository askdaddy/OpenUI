-- OpenUI UI 基础美化黑盒测试（Issue #48 冻结验收，QA 独立编写）。
-- 校验 Widgets 装饰：1px 细边框（四边）、顶部 sheen 渐变、配色切换联动、缺失 API 降级。
-- 运行：lua test/openui_beautify_test.lua

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.."
local ns = {}
local passCount, failCount = 0, 0
local failures = {}

function print() end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function GetAddOnMetadata(name, field)
    if name == "OpenUI" and field == "Version" then return "2026.11.0-dev.1" end
end
function GetLocale() return "enUS" end
function UnitFullName() return "Seven" end
function GetRealmName() return "Forever" end

local frames = {}
local function mktex()
    local t = {}
    function t:SetPoint() end
    function t:SetAllPoints() end
    function t:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function t:SetAlpha() end
    function t:SetTexture() end
    function t:SetSize() end
    function t:SetGradient(orientation, c1, c2)
        self.gradient = { orientation = orientation, c1 = c1, c2 = c2 }
    end
    return t
end
local function mkfs()
    local f = { shown = true }
    function f:SetPoint() end
    function f:SetWidth() end
    function f:SetText(s) self.text = s end
    function f:SetTextColor() end
    function f:SetAlpha() end
    function f:SetFont() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    return f
end
local function mkframe(frameType, name, parent)
    local f = { frameType = frameType, name = name, shown = true, parent = parent,
                registered = {}, scripts = {}, textures = {}, fonts = {}, attrs = {}, refs = {} }
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
    function f:SetMultiLine() end
    function f:SetFontObject() end
    function f:SetTextColor() end
    function f:SetTextInsets() end
    function f:SetText(s) self.text = s end
    function f:GetText() return self.text end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:SetFrameRef(k, v) self.refs[k] = v end
    function f:RegisterForClicks() end
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    table.insert(frames, f)
    return f
end
local BootFrame = mkframe("Frame")
function CreateFrame(frameType, name, parent) return mkframe(frameType, name, parent) end
UIParent = BootFrame
UISpecialFrames = {}
SlashCmdList = {}
C_Timer = { tickers = {} }
function C_Timer.NewTicker(interval, fn)
    local t = { cancelled = false }
    function t:Cancel() self.cancelled = true end
    table.insert(C_Timer.tickers, t)
    return t
end
-- 颜色对象桩（CreateColor 存在 → sheen 生效）
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end

local function check(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end

local order = {
    "Init.lua", "Locales/enUS.lua", "Locales/zhCN.lua", "Config/Defaults.lua",
    "Core/Core.lua", "Core/Resources.lua", "Core/Slash.lua", "Config/Profile.lua",
    "Locales/Manager.lua", "UI/Theme.lua", "UI/Widgets.lua",
}
for _, file in ipairs(order) do
    assert(loadfile(("%s/%s"):format(ADDON, file)))("OpenUI", ns)
end
local OpenUI = ns.OpenUI
local Widgets = OpenUI.Widgets
local Theme = OpenUI.Theme
local L = OpenUI.L

_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
local panel = Widgets.Panel(UIParent)
local border = Theme.Get("color.outline-variant")
local edges = 0
local sheen
for _, tex in ipairs(panel.textures) do
    if tex.r == border[1] and tex.g == border[2] and tex.a == 0.85 then edges = edges + 1 end
    if tex.gradient then sheen = tex end
end
check(edges == 4, "Panel 四边 1px 边框（outline-variant ×0.85，实际 " .. edges .. "）")
check(sheen ~= nil and sheen.gradient.orientation == "VERTICAL", "Panel 顶部 sheen 渐变（VERTICAL）")
check(sheen ~= nil and math.abs(sheen.gradient.c1.a - 0.12) < 1e-9
    and sheen.gradient.c2.a == 0, "sheen 自 0.12 渐隐至 0")
local button = Widgets.Button(UIParent, "OK")
local btnEdges = 0
for _, tex in ipairs(button.textures) do
    if tex.r == border[1] and tex.a == 0.6 then btnEdges = btnEdges + 1 end
end
check(btnEdges == 4, "Button 四边细边框（×0.6，实际 " .. btnEdges .. "）")
-- 配色联动
Theme.SetPalette("moss")
local newBorder = Theme.Get("color.outline-variant")
local updated = 0
for _, tex in ipairs(panel.textures) do
    if tex.r == newBorder[1] and tex.g == newBorder[2] and tex.a == 0.85 then updated = updated + 1 end
end
check(updated == 4, "换配色后边框随 Refresh 换色")
-- 缺失 API 降级
local savedCreateColor = CreateColor
CreateColor = nil
local ok, err = pcall(function() return Widgets.Panel(UIParent) end)
CreateColor = savedCreateColor
check(ok, "CreateColor 缺失时零报错（无 sheen 降级）")
-- 基色保持（旧断言不回归）
local baseOk = false
for _, tex in ipairs(panel.textures) do
    if tex.a == 0.95 then baseOk = true end
end
check(baseOk, "半透明基色（opacity.panel）保持")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
