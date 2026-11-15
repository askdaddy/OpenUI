-- OpenUI 单位框体黑盒测试（Issue #13 plan 步骤 1–4 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_unitframes_test.lua
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
    local t = { w = 208, h = 10 }
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
function CreateFrame(frameType, name, parent, template) return mkframe(frameType, name, parent, template) end
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
PlayerFrame = mkframe("Frame", "PlayerFrame", UIParent)
TargetFrame = mkframe("Frame", "TargetFrame", UIParent)
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
local UNIT_STATE = {
    player = { name = "Seven", class = "WARRIOR", hp = 70, hpMax = 100, pp = 40, ppMax = 100 },
    target = { name = "Boar", reaction = 2, hp = 30, hpMax = 120, pp = 10, ppMax = 60 },
}
function UnitExists(unit) return UNIT_STATE[unit] ~= nil end
function UnitName(unit) return UNIT_STATE[unit] and UNIT_STATE[unit].name end
function UnitClass(unit) return UNIT_STATE[unit] and UNIT_STATE[unit].class end
function UnitHealth(unit) return UNIT_STATE[unit].hp end
function UnitHealthMax(unit) return UNIT_STATE[unit].hpMax end
function UnitPower(unit) return UNIT_STATE[unit].pp end
function UnitPowerMax(unit) return UNIT_STATE[unit].ppMax end
function UnitReaction(unit, other) return UNIT_STATE[unit].reaction end
local function check(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local order = {
    "Init.lua", "Locales/enUS.lua", "Locales/zhCN.lua", "Config/Defaults.lua",
    "Core/Core.lua", "Core/Resources.lua", "Core/Slash.lua", "Config/Profile.lua",
    "Locales/Manager.lua", "UI/Theme.lua", "UI/Widgets.lua", "UI/Settings.lua",
    "UI/Diagnostics.lua", "UI/ActionBars.lua", "UI/Chat.lua", "UI/Native.lua", "UI/UnitFrames.lua",
}
for _, file in ipairs(order) do
    assert(loadfile(("%s/%s"):format(ADDON, file)))("OpenUI", ns)
end
local OpenUI = ns.OpenUI
local UF = OpenUI.UnitFrames
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
print("== S1 默认关闭与启用（步骤 2/4）==")
check(OpenUI:IsModuleEnabled("UnitFrames") == false, "B1 默认关闭")
OpenUI:EnableModule("UnitFrames")
local p, t = UF.Player(), UF.Target()
check(p.frame:IsShown() and t.frame:IsShown(), "启用后框体显示")
print("== S2 数值与配色（步骤 2）==")
check(p.name.text == "Seven" and p.healthText.text == "70 / 100", "玩家名称/生命文本")
check(math.abs(p.health.w - 208 * 0.7) < 1e-6, "玩家生命条宽度 = 70%")
check(math.abs(p.health.r - 0.78) < 1e-6, "玩家生命条 = 职业色")
check(math.abs(p.power.w - 208 * 0.4) < 1e-6, "玩家能量条宽度 = 40%")
check(t.name.text == "Boar" and t.healthText.text == "30 / 120", "目标名称/生命文本")
check(math.abs(t.health.w - 208 * (30 / 120)) < 1e-6, "目标生命条比例")
check(t.health.r == 0.78 and t.health.g == 0.26, "敌对反应色")
print("== S3 原生隐藏与恢复（步骤 4）==")
check(PlayerFrame.parent ~= UIParent and PlayerFrame:IsShown() == false, "原生玩家框隐藏")
check(TargetFrame.parent ~= UIParent, "原生目标框隐藏")
OpenUI:DisableModule("UnitFrames")
check(not p.frame:IsShown() and not t.frame:IsShown(), "自有框体隐藏")
check(PlayerFrame.parent == UIParent and PlayerFrame:IsShown() == true, "原生玩家框恢复")
check(TargetFrame.parent == UIParent, "原生目标框恢复")
print("== S4 事件刷新（步骤 3）==")
OpenUI:EnableModule("UnitFrames")
p, t = UF.Player(), UF.Target()
UNIT_STATE.player.hp = 50
resFrame.scripts.OnEvent(resFrame, "UNIT_HEALTH", "player")
check(p.healthText.text == "50 / 100", "UNIT_HEALTH 刷新生命")
UNIT_STATE.target = nil
resFrame.scripts.OnEvent(resFrame, "PLAYER_TARGET_CHANGED")
check(t.name.text == "" and t.health.w == 0, "无目标清空")
UNIT_STATE.target = { name = "Ally", reaction = 8, hp = 100, hpMax = 100, pp = 50, ppMax = 50 }
resFrame.scripts.OnEvent(resFrame, "PLAYER_TARGET_CHANGED")
check(t.name.text == "Ally" and t.health.g == 0.74, "友方反应色")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
