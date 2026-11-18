-- OpenUI 主控面板黑盒测试（Issue #46 冻结验收，QA 独立编写；替代 #8 旧交互测试）。
-- 运行：lua test/openui_settings_test.lua

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
    local t = { w = 0, h = 0 }
    function t:SetPoint() end
    function t:SetAllPoints() end
    function t:SetHeight(h) self.h = h end
    function t:SetWidth(w) self.w = w end
    function t:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function t:SetAlpha() end
    function t:SetTexture() end
    function t:SetSize(w, h) self.w, self.h = w, h end
    return t
end
local function mkfs()
    local f = { shown = true }
    function f:SetPoint() end
    function f:SetWidth() end
    function f:SetJustifyH() end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetText(s) self.text = s end
    function f:SetTextColor() end
    function f:SetFont() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    return f
end
local function mkframe(frameType, name, parent, template)
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
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:GetVerticalScroll() return self.vScroll or 0 end
    function f:SetVerticalScroll(v) self.vScroll = v end
    function f:GetVerticalScrollRange() return self.vRange or 0 end
    function f:EnableMouseWheel(v) self.mouseWheel = v end
    function f:SetText(s) self.text = s end
    function f:GetText() return self.text end
    function f:SetFontObject() end
    function f:SetTextColor() end
    function f:SetTextInsets() end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:SetFrameRef(k, v) self.refs[k] = v end
    function f:RegisterForClicks() end
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    function f:SetBackdropColor(r, g, b, a) self.bgColor = { r, g, b, a } end
    function f:GetBackdropColor() return table.unpack(self.bgColor or { 0, 0, 0, 0 }) end
    function f:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r, g, b, a } end
    function f:GetBackdropBorderColor() return table.unpack(self.borderColor or { 0, 0, 0, 0 }) end
    function f:GetFont() return "FRIZQT__.TTF", 14, "" end
    function f:SetFont(file, size, flags) self.fontFile = file; self.fontSize = size end
    table.insert(frames, f)
    return f
end
local BootFrame = mkframe("Frame")
function CreateFrame(frameType, name, parent, template) return mkframe(frameType, name, parent, template) end
UIParent = BootFrame
UISpecialFrames = {}
SlashCmdList = {}
C_Timer = { tickers = {} }
function C_Timer.NewTicker(interval, fn)
    local t = { interval = interval, fn = fn, cancelled = false }
    function t:Cancel() self.cancelled = true end
    function t:Tick() if not self.cancelled then self.fn() end end
    table.insert(C_Timer.tickers, t)
    return t
end
function GetActionTexture(slot) return "tex" .. slot end
function GetActionCount(slot) return 1 end
function GetActionBarPage() return 1 end
function GetPetActionInfo(slot) return nil, nil, nil end
function RegisterStateDriver() end
MainMenuBar = mkframe("Frame", "MainMenuBar", UIParent)
PetActionBar = mkframe("Frame", "PetActionBar", UIParent)
NUM_CHAT_WINDOWS = 0

local function check(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end

local order = {
    "Init.lua", "Locales/enUS.lua", "Locales/zhCN.lua", "Config/Defaults.lua",
    "Core/Core.lua", "Core/Resources.lua", "Core/Slash.lua", "Config/Profile.lua",
    "Locales/Manager.lua", "UI/Theme.lua", "UI/Widgets.lua", "UI/Settings.lua",
    "UI/Diagnostics.lua", "UI/ActionBars.lua", "UI/Chat.lua", "UI/Native.lua",
    "UI/UnitFrames.lua", "UI/CastBars.lua", "UI/Auras.lua", "UI/Nameplates.lua",
    "UI/Restyle.lua", "UI/MinimapUI.lua", "UI/Media.lua",
}
for _, file in ipairs(order) do
    assert(loadfile(("%s/%s"):format(ADDON, file)))("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local L = OpenUI.L
local S = OpenUI.Settings
local Theme = OpenUI.Theme
local Loc = OpenUI.Locale

local coreFrame, resFrame
for _, f in ipairs(frames) do
    if not coreFrame and f.registered["ADDON_LOADED"] then
        coreFrame = f
    elseif coreFrame and not resFrame and f.scripts["OnEvent"] then
        resFrame = f
    end
end
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
coreFrame.scripts.OnEvent(coreFrame, "PLAYER_LOGIN")

local function fsByText(text)
    for _, f in ipairs(frames) do
        for _, fs in ipairs(f.fonts or {}) do
            if fs.text == text then return fs end
        end
        for _, tex in ipairs(f.textures or {}) do end
    end
end

local function buttonByText(text)
    for _, f in ipairs(frames) do
        if f.frameType == "Button" and f.themedLabel and f.themedLabel.text == text then
            return f
        end
    end
    for _, f in ipairs(frames) do
        if f.frameType == "Button" and f.themedLabel then
            local t = f.themedLabel.text:gsub("^[●○%s]+", "")
            if t == text then return f end
        end
    end
end

print("== S1 主控总览（步骤 1）==")
local outBefore = #OpenUI.moduleOrder
S.Open()
check(S.IsOpen(), "/openui 打开主控面板")
check(outBefore > 5, "注册模块数=" .. outBefore)
local tiles = 0
for _, module in ipairs(OpenUI.moduleOrder) do
    if module.name ~= "Core" and S.Tile(module.name) then tiles = tiles + 1 end
end
check(tiles == outBefore - 1, "磁贴数=注册模块数-1（" .. tiles .. "/" .. (outBefore - 1) .. "）")
check(buttonByText("Theme & Widgets") ~= nil, "磁贴显示本地化模块名")
check(fsByText("Core") ~= nil and fsByText("Combat HUD") ~= nil, "类目标题渲染（Core/Combat HUD）")

print("== S2 模块小窗（步骤 2）==")
S.OpenModule("Theme")
check(S.IsModuleWindowShown() and S.CurrentModule() == "Theme", "点击磁贴打开模块小窗")
check(buttonByText("teal") ~= nil, "Theme 小窗含配色按钮")
buttonByText("teal").scripts.OnClick()
check(Theme.GetPalette() == "teal", "小窗内配色即时生效")
local toggle
for _, f in ipairs(frames) do
    if f.frameType == "Button" and f.themedLabel
        and f.themedLabel.text:find("Enabled: ", 1, true) == 1 then
        toggle = f
    end
end
check(toggle ~= nil, "小窗含启用开关")
toggle.scripts.OnClick()
check(OpenUI:IsModuleEnabled("Theme") == false, "开关关闭模块生效")
toggle.scripts.OnClick()
check(OpenUI:IsModuleEnabled("Theme") == true, "开关重新启用")
S.OpenModule("Diagnostics")
check(S.CurrentModule() == "Diagnostics", "切换模块小窗")
check(buttonByText("Open diagnostics") ~= nil, "诊断模块小窗含打开按钮")
S.OpenModule("UnitFrames")
check(fsByText("No options yet. Enable or disable this module here.") ~= nil,
    "无专属设置模块显示提示")
S.CloseModule()
check(not S.IsModuleWindowShown(), "关闭小窗")

print("== S3 搜索（步骤 3）==")
local box
for _, f in ipairs(frames) do
    if f.frameType == "EditBox" then box = f break end
end
check(box ~= nil, "搜索框存在")
box.text = "theme"
box.scripts.OnTextChanged(box)
check(S.Tile("Theme").button:IsShown(), "命中磁贴保留")
check(not S.Tile("Chat").button:IsShown(), "未命中磁贴隐藏")
box.text = "xyz"
box.scripts.OnTextChanged(box)
check(not S.Tile("Theme").button:IsShown(), "无结果全部隐藏")
box.text = ""
box.scripts.OnTextChanged(box)
check(S.Tile("Theme").button:IsShown() and S.Tile("Chat").button:IsShown(), "清空恢复")

print("== S4 语言切换刷新（步骤 3）==")
Loc.Set("zhCN")
check(buttonByText("主题与控件") ~= nil, "磁贴文案随语言刷新")
check(fsByText("战斗界面") ~= nil, "类目标题随语言刷新")

print("== S6 v2：滚动容器与卡片边界（#71）==")
local S2 = OpenUI.Settings
check(S2.ContentHeight() > 100, "滚动内容已按分区实测布局（"..S2.ContentHeight().."px）")
-- 找到滚动帧（含 SetScrollChild 的 Frame）
local scroller
for _, f in ipairs(frames) do
    if f.scrollChild then scroller = f end
end
check(scroller ~= nil, "ScrollFrame 存在且已挂内容")
scroller.vRange = S2.ContentHeight() - 200
scroller.scripts.OnMouseWheel(scroller, -1)
check((scroller.vScroll or 0) == 40, "滚轮向下滚动 40px")
scroller.scripts.OnMouseWheel(scroller, -100)
check(scroller.vScroll == scroller.vRange, "滚动钳制到范围上限")
-- 卡片边界与状态点
local tile = S2.Tile("Theme")
check(tile ~= nil and #tile.edges == 4, "磁贴有四边边界（按钮可感知）")
check(tile.dot ~= nil and tile.dot.text == "●", "启用模块状态点 ●")
OpenUI:DisableModule("Theme")
-- refreshTileStates 经 Refresh 触发
S2.Refresh()
check(tile.dot.text == "○", "禁用后状态点 ○")
check((tile.label.alpha or 1) < 1, "禁用模块标签变淡")
OpenUI:EnableModule("Theme")
S2.Refresh()
check(tile.dot.text == "●", "重新启用恢复 ●")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
