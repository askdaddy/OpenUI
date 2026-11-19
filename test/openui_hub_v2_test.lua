-- OpenUI 主控滚动、关于页和配置档交互回归（#72）。
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

S.Open()
click("Profiles")
local P = OpenUI.Profile
check(P.GetCurrent().mode == "independent", "starts on character's independent profile")
check(#buttons("Create and link") == 5, "five account-wide slot rows")
local panel = named("OpenUISettingsContent")
local about = named("OpenUISettingsAbout")
panel.scripts.OnMouseWheel(panel, -1)
local originalOffset = panel.vScroll
check(originalOffset > 0, "profile content scrolls")
click("About OpenUI")
check(visible(about) and not visible(named("OpenUISettingsModules")) and #buttons("Back") == 1, "About has separate navigation")
check(#buttons("Combat HUD") == 0, "normal tabs hidden on About")
about.scripts.OnMouseWheel(about, -100)
check(about.vScroll == 195, "About wheel clamps at bottom")
local slider
for _, f in ipairs(frames) do if f.frameType == "Slider" and visible(f) then slider = f end end
check(slider and slider.high == 195, "About overflow has a visible scrollbar")
slider:SetValue(120)
check(about.vScroll == 75, "scrollbar drag updates the body")
local linkVisible = false
for _, f in ipairs(frames) do
    if f.frameType == "EditBox" and visible(f) and f:GetText() == "https://github.com/askdaddy/OpenUI/issues" then
        linkVisible = true
    end
end
check(linkVisible, "About shows copyable Issues address")
click("Back")
check(S.CurrentModule() == "Profile" and panel.vScroll == originalOffset and not visible(about),
    "Back restores the original module and scroll offset")

Theme.SetPalette("amber")
click("Create and link")
check(P.GetCurrent().slot == 1 and Theme.GetPalette() == "starblue", "creating slot activates its theme")
Theme.SetPalette("teal")
click("Unlink")
click("Restore character profile")
check(P.GetCurrent().mode == "independent" and Theme.GetPalette() == "amber", "unlink can restore independent theme")
click("Link")
check(P.GetCurrent().slot == 1 and Theme.GetPalette() == "teal", "link reuses shared settings")
click("Unlink")
click("Copy shared settings")
check(P.GetCurrent().mode == "independent" and Theme.GetPalette() == "teal", "unlink can copy shared settings")

local another = "Offline-Forever"
_G.OpenUIDB.profiles.chars[another] = { mode = "slot", slot = 1, independent = {} }
click("Delete")
click("Cancel")
check(P.Slots()[1].used, "cancel preserves slot")
click("Delete")
click("Delete")
check(not P.Slots()[1].used and P.ConfigFor(another).theme.palette == "teal", "delete leaves offline linked character with a copy")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
