-- OpenUI 聊天 T1 黑盒测试（Issue #12 plan 步骤 1–3 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_chat_test.lua

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
    function t:SetColorTexture() end
    function t:SetAlpha() end
    function t:SetTexture() end
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

local function mkChatFrame(name, withBorder, withFont)
    local f = mkframe("ScrollingMessageFrame", name, UIParent)
    f.bgColor = { 0.5, 0.5, 0.5, 0.5 }
    f.borderColor = { 0.7, 0.7, 0.7, 0.7 }
    f.font = { "FRIZQT__.TTF", 14, "" }
    function f:GetBackdropColor() return table.unpack(f.bgColor) end
    function f:SetBackdropColor(r, g, b, a) f.bgColor = { r, g, b, a } end
    if withBorder then
        function f:GetBackdropBorderColor() return table.unpack(f.borderColor) end
        function f:SetBackdropBorderColor(r, g, b, a) f.borderColor = { r, g, b, a } end
    end
    if withFont then
        function f:GetFont() return table.unpack(f.font) end
        function f:SetFont(file, size, flags) f.font = { file, size, flags or "" } end
    end
    return f
end
NUM_CHAT_WINDOWS = 2
ChatFrame1 = mkChatFrame("ChatFrame1", true, true)
ChatFrame2 = mkChatFrame("ChatFrame2", false, true)
ChatFrame1EditBox = mkChatFrame("ChatFrame1EditBox", true, false)

local function check(cond, label)
    if cond then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        failures[#failures + 1] = label
    end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local function eq(a, b)
    for i = 1, 4 do
        if math.abs((a[i] or -1) - (b[i] or -1)) > 1e-9 then return false end
    end
    return true
end

local order = {
    "Init.lua", "Locales/enUS.lua", "Locales/zhCN.lua", "Config/Defaults.lua",
    "Core/Core.lua", "Core/Resources.lua", "Core/Slash.lua", "Config/Profile.lua",
    "Locales/Manager.lua", "UI/Theme.lua", "UI/Widgets.lua", "UI/Settings.lua",
    "UI/Diagnostics.lua", "UI/ActionBars.lua", "UI/Chat.lua",
}
for _, file in ipairs(order) do
    assert(loadfile(("%s/%s"):format(ADDON, file)))("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local Chat = OpenUI.Chat
local Theme = OpenUI.Theme
local coreFrame = frames[5]
local resFrame = frames[6]

print("== S1 外观应用（步骤 1）==")
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "OpenUI")
coreFrame.scripts.OnEvent(coreFrame, "PLAYER_LOGIN")
local surf = Theme.Get("color.surface")
local ov = Theme.Get("color.outline")
check(eq(ChatFrame1.bgColor, { surf[1], surf[2], surf[3], 0.88 }), "ChatFrame1 背景 = surface × opacity.panel")
check(eq(ChatFrame1.borderColor, { ov[1], ov[2], ov[3], 0.95 }), "ChatFrame1 边框 = outline")
check(ChatFrame1.font[1] == "FRIZQT__.TTF" and ChatFrame1.font[2] == 13,
    "字体文件保留、字号 = type.body")
check(eq(ChatFrame2.bgColor, { surf[1], surf[2], surf[3], 0.88 }),
    "无边框 setter 的帧不崩溃且背景生效（守卫）")
check(eq(ChatFrame1EditBox.bgColor, { surf[1], surf[2], surf[3], 0.88 }), "输入框背景主题化")

print("== S2 主题联动与重应用（步骤 2）==")
Theme.SetPalette("moss")
local moss = Theme.Get("color.surface")
check(eq(ChatFrame1.bgColor, { moss[1], moss[2], moss[3], 0.88 }), "换配色即时联动")
ChatFrame1.bgColor = { 0, 0, 0, 0 }
resFrame.scripts.OnEvent(resFrame, "PLAYER_ENTERING_WORLD")
check(eq(ChatFrame1.bgColor, { moss[1], moss[2], moss[3], 0.88 }), "PLAYER_ENTERING_WORLD 重应用")

print("== S3 关闭恢复与重启（步骤 1）==")
OpenUI:DisableModule("Chat")
check(eq(ChatFrame1.bgColor, { 0.5, 0.5, 0.5, 0.5 }) and eq(ChatFrame1.borderColor, { 0.7, 0.7, 0.7, 0.7 }),
    "ChatFrame1 背景/边框恢复原值")
check(ChatFrame1.font[2] == 14, "字号恢复原值")
check(eq(ChatFrame2.bgColor, { 0.5, 0.5, 0.5, 0.5 }), "ChatFrame2 恢复")
check(eq(ChatFrame1EditBox.bgColor, { 0.5, 0.5, 0.5, 0.5 }), "输入框恢复")
OpenUI:EnableModule("Chat")
check(eq(ChatFrame1.bgColor, { moss[1], moss[2], moss[3], 0.88 }), "重新启用再次主题化")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
