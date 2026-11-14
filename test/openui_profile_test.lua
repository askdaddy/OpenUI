-- OpenUI 配置档黑盒测试（Issue #9 plan 步骤 1–3 冻结验收，QA 独立编写）。
-- 以 WoW API 桩模拟客户端边界（含角色身份 API），按 TOC 次序加载后断言；
-- 不读游戏客户端、不修改业务代码。
-- 运行：lua test/openui_profile_test.lua（仓库任意位置可执行）

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.." -- 包根即仓库根（D54）

local ns = {}
local passCount, failCount = 0, 0
local failures = {}

-- ==== WoW 环境桩 ====
function print() end
function strtrim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
function GetAddOnMetadata(name, field)
    if name == "OpenUI" and field == "Version" then return "2026.11.0-dev.1" end
end
function GetLocale() return "enUS" end
function UnitFullName(unit) return "Seven" end
function GetRealmName() return "Forever" end

local frames = {}
local function mktex()
    local t = {}
    function t:SetAllPoints() end
    function t:SetColorTexture() end
    function t:SetAlpha() end
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

-- ==== 按 TOC 次序加载（含 Profile） ====
local order = {
    "Init.lua",
    "Locales/enUS.lua",
    "Locales/zhCN.lua",
    "Config/Defaults.lua",
    "Core/Core.lua",
    "Core/Resources.lua",
    "Core/Slash.lua",
    "Config/Profile.lua",
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
local P = OpenUI.Profile
local T = OpenUI.Theme
local Loc = OpenUI.Locale
local coreFrame = frames[1]

print("== S0 迁移前回退（步骤 1）==")
check(P.Config() == nil, "迁移前 Config() 为 nil")
check(Loc.Get() == "auto", "迁移前 Locale.Get 缺省 auto")

print("== S1 legacy 迁移（步骤 1）==")
_G.OpenUIDB = {
    configVersion = 1,
    debug = true,
    locale = "zhCN",
    theme = { palette = "teal", ["color.primary"] = { 1, 0, 0, 1 } },
    modules = { enabled = { Theme = false } },
}
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
local cfg = P.Config()
check(type(cfg) == "table" and cfg.locale == "zhCN" and cfg.debug == true, "迁移 locale/debug")
check(cfg.theme.palette == "teal" and cfg.theme["color.primary"][1] == 1, "迁移 theme（深拷贝）")
check(cfg.modules.enabled.Theme == false, "迁移 modules")
check(_G.OpenUIDB.locale == "zhCN" and _G.OpenUIDB.theme.palette == "teal", "legacy 顶层键保留不清洗")
check(Loc.Get() == "zhCN", "Locale 经 Profile 生效")
check(T.GetPalette() == "teal", "Theme 配色经 Profile 生效")
check(OpenUI:IsModuleEnabled("Theme") == false, "模块状态经 Profile 生效")
check(cfg.theme["color.primary"] ~= _G.OpenUIDB.theme["color.primary"], "迁移为深拷贝（表身份不同）")
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
check(P.Config() == cfg, "迁移幂等（重复初始化不重置）")

print("== S2 5 槽与活引用（步骤 2）==")
local slots = P.Slots()
check(#slots == 5 and slots[1].used == false, "5 槽且初始未使用")
check(P.GetCurrent().mode == "independent", "初始为独立档")
check(P.UseSlot(2) == true, "UseSlot(2)")
check(P.GetCurrent().mode == "slot" and P.GetCurrent().slot == 2, "当前关联槽 2")
check(P.Config() == _G.OpenUIDB.profiles.slots[2].config, "槽配置为活引用（同表）")
check(P.UseSlot(0) == false and P.UseSlot(6) == false, "非法槽号拒绝")
T.Set("opacity.panel", 0.7)
check(_G.OpenUIDB.profiles.slots[2].config.theme["opacity.panel"] == 0.7, "写入穿到槽配置")
_G.OpenUIDB.profiles.chars["Alt-Forever"] = { mode = "slot", slot = 2, independent = {} }
check(P.ConfigFor("Alt-Forever") == P.Config(), "同槽另一角色解析到同一表（共享影响全部关联角色）")

print("== S3 切换与解除关联（D10）==")
check(P.UseIndependent() == true, "解除关联（保留独立）")
check(P.GetCurrent().mode == "independent", "回到独立档")
check(P.Config().theme["opacity.panel"] ~= 0.7, "原独立档保留（非槽副本）")
P.UseSlot(1)
T.Set("opacity.panel", 0.65)
check(P.UseIndependent({ copy = true }) == true and P.Config().theme["opacity.panel"] == 0.65,
    "解除二选一：复制槽当前配置")

print("== S4 删除槽与离线副本（D09）==")
P.UseSlot(2)
_G.OpenUIDB.profiles.chars["Offline-Forever"] = { mode = "slot", slot = 2, independent = {} }
_G.OpenUIDB.profiles.chars["Other-Forever"] = { mode = "independent", independent = { marker = 42 } }
check(P.DeleteSlot(2) == true, "DeleteSlot(2)")
check(_G.OpenUIDB.profiles.slots[2] == nil, "槽已移除")
local act = P.GetCurrent()
check(act.mode == "independent" and act.slot == nil, "删除者解除关联")
check(P.Config().theme["opacity.panel"] == 0.7, "删除者保留删除前副本")
check(P.ConfigFor("Offline-Forever").theme["opacity.panel"] == 0.7, "离线关联角色保留副本")
check(P.ConfigFor("Alt-Forever").theme["opacity.panel"] == 0.7, "第二关联角色保留副本")
check(P.ConfigFor("Other-Forever").marker == 42, "未关联角色不受影响")
check(P.DeleteSlot(2) == false, "重复删除返回 false")

print("== S5 消费者写穿与运行数据（步骤 3）==")
Loc.Set("enUS")
check(P.Config().locale == "enUS", "Locale.Set 写入生效配置")
OpenUI:DisableModule("Locale")
check(P.Config().modules ~= nil and P.Config().modules.enabled.Locale == false, "DisableModule 写入生效配置")
OpenUI:EnableModule("Locale")
check(P.Config().modules.enabled.Locale == true, "EnableModule 写入生效配置")
T.SetPalette("amber")
check(P.Config().theme.palette == "amber", "SetPalette 写入生效配置")
local hasErrors = false
for key in pairs(P.Config()) do
    if key == "errors" then hasErrors = true end
end
check(not hasErrors, "运行数据（错误队列）不入配置档")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do
        io.stderr:write("FAIL: " .. f .. "\n")
    end
    os.exit(1)
end
os.exit(0)