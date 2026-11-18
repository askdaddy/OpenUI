-- OpenUI 主控导航、主题和搜索回归（#72）。
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
    local t = {}
    function t:SetPoint() end
    function t:SetAllPoints() end
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
    function f:SetText(s) self.text = s end
    function f:SetTextColor() end
    function f:SetAlpha() end
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
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetPoint() end
    function f:SetAllPoints() end
    function f:SetMinMaxValues(low, high) self.low, self.high = low, high end
    function f:SetValue(v)
        self.value = v
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
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
    "UI/Diagnostics.lua", "UI/ActionBars.lua", "UI/Grid.lua", "UI/Chat.lua", "UI/Native.lua",
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

local function visible(f)
    return f and f:IsShown() and (not f.parent or visible(f.parent))
end

local function buttons(text)
    local found = {}
    for _, f in ipairs(frames) do
        if f.frameType == "Button" and f.themedLabel and f.themedLabel.text == text and visible(f) then
            found[#found + 1] = f
        end
    end
    return found
end

local function click(text, index)
    local button = assert(buttons(text)[index or 1], "Missing visible button: " .. text)
    assert(button.scripts.OnClick, "No handler: " .. text)(button)
end

local function named(name)
    for _, f in ipairs(frames) do
        if f.name == name then return f end
    end
end

SlashCmdList.OPENUI("")
check(S.IsOpen(), "/openui opens control panel")
local root = named("OpenUISettings")
check(root.width == 700 and root.height == 520, "approved panel dimensions")
for _, tab in ipairs({ "Plugin Settings", "Combat HUD", "Maps & Quests", "Game Windows", "Social & Trade" }) do
    check(#buttons(tab) == 1, "visible tab: " .. tab)
end
check(S.CurrentModule() == "Theme", "Theme initially selected")
check(#buttons("Enabled: On") == 0, "Theme has no module switch")
for _, label in ipairs({ "Starblue", "Jade", "Amber", "Amethyst", "Rose", "Moss", "Graphite" }) do
    check(#buttons(label) == 1, "visible palette: " .. label)
end
local before = root.textures[1].r
click("Jade")
check(Theme.GetPalette() == "teal" and root.textures[1].r ~= before, "palette changes panel surface immediately")
click("Layout Grid")
check(S.CurrentModule() == "Grid" and #buttons("Enabled: On") == 0, "Grid is inline without a module switch")
check(OpenUI:IsModuleEnabled("Grid") and #buttons("Show grid: Off") == 1, "Grid feature still has a display toggle")
click("Combat HUD")
check(S.CurrentModule() == "ActionBars", "tab opens first registered module")
click("Unit Frames")
check(S.CurrentModule() == "UnitFrames", "module row selects inline settings")
check(Theme.GetPalette() == "teal", "palette persists across modules")
click("Maps & Quests")
check(S.CurrentModule() == "MinimapUI", "Maps & Quests opens Minimap")
click("Plugin Settings")
click("Diagnostics")
local enabled = OpenUI:IsModuleEnabled("Diagnostics")
click(enabled and "Enabled: On" or "Enabled: Off")
check(OpenUI:IsModuleEnabled("Diagnostics") ~= enabled, "diagnostics module switch applies")
check(#buttons("Open diagnostics") == 1, "diagnostics still has its own window entry")
check(#buttons("Media Library") == 0 and #buttons("Settings") == 0, "internal infrastructure excluded")

local box
for _, f in ipairs(frames) do
    if f.frameType == "EditBox" and visible(f) then box = f; break end
end
box:SetText("combat hud")
box.scripts.OnTextChanged(box)
check(S.CurrentModule() == "ActionBars" and #buttons("Unit Frames") == 1, "search matches localized category")
box:SetText("xyz")
box.scripts.OnTextChanged(box)
check(S.CurrentModule() == nil and not S.IsModuleWindowShown(), "no match hides module contents")
box:SetText("")
box.scripts.OnTextChanged(box)
check(S.CurrentModule() == "Diagnostics", "clearing search restores selected module")
Loc.Set("zhCN")
check(#buttons("插件设置") == 1 and #buttons("地图与任务") == 1 and #buttons("主题") == 1, "language redraws the whole navigation")
S.Close()
check(not S.IsOpen(), "close hides the control panel")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
