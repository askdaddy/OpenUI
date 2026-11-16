-- OpenUI 拖拽/主题刷新/默认位置黑盒测试（Issue #50 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_drag_refresh_test.lua
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
local ALT = false
function IsAltKeyDown() return ALT end
local frames = {}
local function mktex()
    local t = {}
    function t:SetPoint() end
    function t:SetAllPoints() end
    function t:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function t:SetAlpha() end
    function t:SetTexture() end
    function t:SetSize() end
    function t:SetHeight() end
    function t:SetGradient() end
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
                registered = {}, scripts = {}, textures = {}, fonts = {}, attrs = {}, refs = {},
                moving = false }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:UnregisterEvent(e) self.registered[e] = nil end
    function f:SetScript(n, fn) self.scripts[n] = fn end
    function f:CreateTexture() local x = mktex(); self.textures[#self.textures + 1] = x; return x end
    function f:CreateFontString() local x = mkfs(); self.fonts[#self.fonts + 1] = x; return x end
    function f:SetSize() end
    function f:SetPoint(a, b, c, d, e) self.lastPoint = { a, b, c, d, e } end
    function f:ClearAllPoints() self.lastPoint = nil end
    function f:SetAllPoints() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
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
    function f:SetBackdropColor(r, g, b, a) self.bgColor = { r, g, b, a } end
    function f:GetBackdropColor() return table.unpack(self.bgColor or { 0, 0, 0, 0 }) end
    function f:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r, g, b, a } end
    function f:GetBackdropBorderColor() return table.unpack(self.borderColor or { 0, 0, 0, 0 }) end
    function f:GetFont() return "FRIZQT__.TTF", 14, "" end
    function f:SetFont(file, size) self.fontFile = file; self.fontSize = size end
    function f:GetLeft() return 300 end
    function f:GetBottom() return 200 end
    table.insert(frames, f)
    return f
end
local BootFrame = mkframe("Frame")
function CreateFrame(t, n, p, tmpl) return mkframe(t, n, p, tmpl) end
UIParent = BootFrame
UISpecialFrames = {}
SlashCmdList = {}
C_Timer = { tickers = {} }
function C_Timer.NewTicker(i, fn)
    local t = { interval = i, fn = fn, cancelled = false }
    function t:Cancel() self.cancelled = true end
    function t:Tick() if not self.cancelled then self.fn() end end
    table.insert(C_Timer.tickers, t)
    return t
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetActionTexture() return nil end
function GetActionCount() return 0 end
function GetActionBarPage() return 1 end
function GetPetActionInfo() return nil, nil, nil end
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
local Theme = OpenUI.Theme
local L = OpenUI.L

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

print("== S1 半透明默认（视觉 v2）==")
check(Theme.Get("opacity.panel") == 0.88, "opacity.panel 默认 0.88（可见半透明）")

print("== S2 默认位置与拖拽助手（步骤 1–2）==")
OpenUI:EnableModule("UnitFrames")
local UF = OpenUI.UnitFrames
local playerFrame = UF.Player().frame
check(playerFrame.lastPoint ~= nil and playerFrame.lastPoint[1] == "TOPLEFT"
    and playerFrame.lastPoint[4] == 20 and playerFrame.lastPoint[5] == -24,
    "玩家框体默认左上（20,-24）")
local targetFrame = UF.Target().frame
check(targetFrame.lastPoint[5] == -76, "目标框体默认（20,-76）")
ALT = false
playerFrame.scripts.OnDragStart(playerFrame)
check(not playerFrame.moving, "无 Alt 时不可拖动")
ALT = true
playerFrame.scripts.OnDragStart(playerFrame)
check(playerFrame.moving, "Alt+左键开始拖动")
playerFrame.scripts.OnDragStop(playerFrame)
local cfg = OpenUI.Profile.Config()
check(cfg.unitframes and cfg.unitframes.player and cfg.unitframes.player.x == 300,
    "拖拽位置持久化（x=300）")

print("== S3 宠物条可拖（步骤 2）==")
local petBar = OpenUI.ActionBars.PetBar()
check(petBar ~= nil, "宠物条存在")
ALT = false
petBar.scripts.OnDragStart(petBar)
check(not petBar.moving, "宠物条无 Alt 不可拖")
ALT = true
petBar.scripts.OnDragStart(petBar)
check(petBar.moving, "宠物条 Alt 可拖")
petBar.scripts.OnDragStop(petBar)
local cfg2 = OpenUI.Profile.Config()
check(cfg2.actionbars and cfg2.actionbars.pet and cfg2.actionbars.pet.y == 200,
    "宠物条位置持久化")

print("== S4 主题覆盖模块（步骤 3）==")
OpenUI:EnableModule("CastBars")
OpenUI:EnableModule("Auras")
local before = UF.Player().healthBg.r
Theme.SetPalette("moss")
local mossTrack = Theme.Get("color.surface-container-highest")
check(UF.Player().healthBg.r == mossTrack[1], "单位框体底纹随配色重绘")
local CB = OpenUI.CastBars
check(CB.Player().track.r == mossTrack[1], "施法条底纹随配色重绘")
local A = OpenUI.Auras
local buffBorder = A.Row("Buff").slots[1].border
local mossOutline = Theme.Get("color.outline")
check(buffBorder.r == mossOutline[1], "光环描边随配色重绘")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
