-- OpenUI 动作条黑盒测试（Issue #11 plan 步骤 1–4 冻结验收，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界（安全模板属性/帧引用/状态驱动/原生条），按 TOC 次序加载后断言。
-- 运行：lua test/openui_actionbars_test.lua

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
    function t:SetTexture(x) self.texture = x end
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
    local f = { frameType = frameType, name = name, shown = true, template = template,
                parent = parent or UIParent, registered = {}, scripts = {},
                textures = {}, fonts = {}, attrs = {}, refs = {} }
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

MainMenuBar = mkframe("Frame", "MainMenuBar", UIParent)
PetActionBar = mkframe("Frame", "PetActionBar", UIParent)

function GetActionTexture(slot) return "tex" .. slot end
function GetActionCount(slot) if slot % 5 == 0 then return 0 end return 2 end
function GetActionBarPage() return 1 end
function GetPetActionInfo(slot) return nil, nil, "pettex" .. slot end
RegisteredDrivers = {}
function RegisterStateDriver(frame, state, driver)
    table.insert(RegisteredDrivers, { frame = frame, state = state, driver = driver })
end

local function check(cond, label)
    if cond then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        failures[#failures + 1] = label
    end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end

local order = {
    "Init.lua", "Locales/enUS.lua", "Locales/zhCN.lua", "Config/Defaults.lua",
    "Core/Core.lua", "Core/Resources.lua", "Core/Slash.lua", "Config/Profile.lua",
    "Locales/Manager.lua", "UI/Theme.lua", "UI/Widgets.lua", "UI/Settings.lua",
    "UI/Diagnostics.lua", "UI/ActionBars.lua",
}
for _, file in ipairs(order) do
    assert(loadfile(("%s/%s"):format(ADDON, file)))("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local AB = OpenUI.ActionBars
local coreFrame = frames[4]
local resFrame = frames[5]

print("== S1 模块启用与结构（步骤 1–2）==")
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
coreFrame.scripts.OnEvent(coreFrame, "PLAYER_LOGIN")
local mainBar, petBar = AB.MainBar(), AB.PetBar()
check(mainBar ~= nil and mainBar:IsShown(), "主条构建并显示")
check(petBar ~= nil and petBar:IsShown(), "宠物条构建并显示")
local mb, pb = AB.MainButtons(), AB.PetButtons()
check(#mb == 12 and #pb == 10, "12 主按钮 + 10 宠物按钮")
local allMain = true
for i = 1, 12 do
    if mb[i]:GetAttribute("type") ~= "action" or mb[i]:GetAttribute("action") ~= i then
        allMain = false
    end
end
check(allMain, "主按钮 type=action / action=1..12")
local allPet = true
for i = 1, 10 do
    if pb[i]:GetAttribute("type") ~= "pet" or pb[i]:GetAttribute("action") ~= i then
        allPet = false
    end
end
check(allPet, "宠物按钮 type=pet / action=1..10")

print("== S2 安全分页（步骤 1）==")
check(type(mainBar:GetAttribute("_onstate-page")) == "string", "安全分页片段已注册")
local driverOK = false
for _, d in ipairs(RegisteredDrivers) do
    if d.frame == mainBar and d.driver:find("bonusbar:1", 1, true) then driverOK = true end
end
check(driverOK, "状态驱动已注册（含 bonusbar 形态页条件）")
local snippet = mainBar:GetAttribute("_onstate-page")
local fn = assert(load("return function(self, newstate) " .. snippet .. " end", "snippet"))()
local fakeSelf = { GetFrameRef = function(_, key) return mainBar.refs[key] end }
fn(fakeSelf, "2")
local page2 = true
for i = 1, 12 do
    if mb[i]:GetAttribute("action") ~= 12 + i then page2 = false end
end
check(page2, "page=2 → action=13..24（安全片段映射）")
fn(fakeSelf, "1")
check(mb[1]:GetAttribute("action") == 1, "page=1 → action 复位")

print("== S3 图标与数量（步骤 3）==")
check(mb[1].openuiIcon.texture == "tex1", "图标纹理 = 当前页槽位")
check(mb[1].openuiCount.text == "2", "数量文本显示")
check(mb[5].openuiCount.text == "", "数量为 0 时隐藏")
check(pb[1].openuiIcon.texture == "pettex1", "宠物条图标纹理")
resFrame.scripts.OnEvent(resFrame, "ACTIONBAR_SLOT_CHANGED", 1)
check(mb[1].openuiIcon.texture == "tex1", "事件驱动刷新可达")

print("== S4 原生隐藏与恢复（步骤 4）==")
check(MainMenuBar.parent ~= UIParent and MainMenuBar:IsShown() == false,
    "原生主条已 reparent 到隐藏宿主")
check(PetActionBar.parent ~= UIParent, "原生宠物条已 reparent")
OpenUI:DisableModule("ActionBars")
check(not mainBar:IsShown() and not petBar:IsShown(), "关闭模块隐藏自有条")
check(MainMenuBar.parent == UIParent and MainMenuBar:IsShown() == true, "原生主条恢复")
check(PetActionBar.parent == UIParent, "原生宠物条恢复")
OpenUI:EnableModule("ActionBars")
check(mainBar:IsShown() and MainMenuBar.parent ~= UIParent, "重新启用恢复自有条并隐藏原生")
resFrame.scripts.OnEvent(resFrame, "ACTIONBAR_SLOT_CHANGED", 1)
check(mb[12].openuiIcon.texture == "tex12", "重新启用后事件仍生效")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
