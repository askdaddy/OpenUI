-- OpenUI 诊断增强黑盒测试（Issue #10 plan 步骤 1–3 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_diagnostics_test.lua

local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.."

local ns = {}
local output = {}
local passCount, failCount = 0, 0
local failures = {}

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    output[#output + 1] = table.concat(parts, " ")
end
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
    function f:SetMultiLine() end
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
    "UI/Diagnostics.lua",
}
for _, file in ipairs(order) do
    assert(loadfile(("%s/%s"):format(ADDON, file)))("OpenUI", ns)
end

local OpenUI = ns.OpenUI
local D = OpenUI.Diagnostics
local function diagFrame()
    for _, f in ipairs(frames) do
        if f.name == "OpenUIDiagnostics" then return f end
    end
end
local function editBox()
    for _, f in ipairs(frames) do
        if f.frameType == "EditBox" then return f end
    end
end

print("== S1 空队列与窗口（步骤 1）==")
D.Open()
local win = diagFrame()
check(win ~= nil and win:IsShown(), "打开诊断窗口")
local box = editBox()
check(box ~= nil and box.text == "No errors recorded.", "空队列显示无错误提示")
D.Close()
check(not diagFrame():IsShown(), "关闭隐藏窗口")

print("== S2 50 条 FIFO 上限（步骤 3）==")
for i = 1, 52 do
    OpenUI.Diagnose.Report("M" .. i, "err-" .. i)
end
local errs = OpenUI.Diagnose.Errors()
check(#errs == 50, "上限 50（实际 " .. #errs .. "）")
check(errs[1]:find("err-3", 1, true) ~= nil and errs[1]:find("err-1", 1, true) == nil,
    "最旧条目被淘汰（FIFO）")
check(errs[50]:find("err-52", 1, true) ~= nil, "最新条目保留")

print("== S3 查看与复制内容（步骤 1–2）==")
local longStack = {}
for i = 1, 200 do longStack[i] = "stack-frame-" .. i end
OpenUI.Diagnose.Report("Boom", "long\n" .. table.concat(longStack, "\n"))
D.Open()
check(box.text:find("1. M4: err-4", 1, true) ~= nil, "条目按编号顺序列出")
check(box.text:find("stack-frame-200", 1, true) ~= nil, "长堆栈完整不截断")
check(box.text:find("50. ", 1, true) ~= nil, "50 条全部纳入")
output = {}
SlashCmdList.OPENUI("errors")
check(table.concat(output, " | "):find("err-52", 1, true) ~= nil, "/openui errors 聊天输出保留")
check(diagFrame():IsShown(), "/openui errors 同时打开查看窗口")
local wins = 0
for _, f in ipairs(frames) do
    if f.name == "OpenUIDiagnostics" then wins = wins + 1 end
end
check(wins == 1, "单实例窗口")

print("== S4 运行数据不持久化（步骤 1）==")
check(_G.OpenUIDB == nil or _G.OpenUIDB.errors == nil, "错误队列不写 SavedVariables")
check(#UISpecialFrames >= 1 and UISpecialFrames[#UISpecialFrames] == "OpenUIDiagnostics",
    "ESC 关闭已注册")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
