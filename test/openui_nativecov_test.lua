-- OpenUI 系统UI遮盖黑盒测试（Issue #49 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_nativecov_test.lua
local HERE = (arg[0]:match("^(.*)[/\\]") or ".")
local ADDON = HERE .. "/.."
local ns = {}
function print() end
function strtrim(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
function GetAddOnMetadata(n,f) if n=="OpenUI" and f=="Version" then return "2026.11.0-dev.1" end end
function GetLocale() return "enUS" end
function UnitFullName() return "Seven" end
function GetRealmName() return "Forever" end
local frames = {}
local function mktex() local t={} function t:SetPoint() end function t:SetAllPoints() end function t:SetColorTexture(r,g,b,a) self.r,self.g,self.b=r,g,b end function t:SetAlpha() end function t:SetTexture(x) self.texture=x end function t:SetSize(w,h) self.w=w self.h=h end return t end
local function mkfs() local f={shown=true} function f:SetPoint() end function f:SetWidth() end function f:SetText(s) self.text=s end function f:SetTextColor() end function f:SetAlpha() end function f:SetFont() end function f:Show() self.shown=true end function f:Hide() self.shown=false end function f:IsShown() return self.shown end return f end
local function mkframe(t,name,parent)
  local f={frameType=t,name=name,shown=true,parent=parent,registered={},scripts={},textures={},fonts={},attrs={},refs={}}
  function f:RegisterEvent(e) self.registered[e]=true end function f:UnregisterEvent(e) self.registered[e]=nil end
  function f:SetScript(n,fn) self.scripts[n]=fn end
  function f:CreateTexture() local x=mktex(); table.insert(self.textures,x); return x end
  function f:CreateFontString() local x=mkfs(); table.insert(self.fonts,x); return x end
  function f:SetSize() end function f:SetPoint() end function f:SetAllPoints() end
  function f:SetMovable() end function f:EnableMouse() end function f:RegisterForDrag() end
  function f:StartMoving() end function f:StopMovingOrSizing() end
  function f:Show() self.shown=true end function f:Hide() self.shown=false end function f:IsShown() return self.shown end
  function f:SetAutoFocus() end function f:SetMultiLine() end function f:SetFontObject() end function f:SetTextColor() end function f:SetTextInsets() end
  function f:SetText(s) self.text=s end function f:GetText() return self.text end
  function f:SetAttribute(k,v) self.attrs[k]=v end function f:GetAttribute(k) return self.attrs[k] end
  function f:SetFrameRef(k,v) self.refs[k]=v end function f:RegisterForClicks() end
  function f:SetParent(p) self.parent=p end function f:GetParent() return self.parent end
  function f:SetAlpha(a) self.alpha=a end function f:GetAlpha() return self.alpha or 1 end
  function f:EnableMouse(v) self.mouse=v end
  function f:SetBackdropColor(r,g,b,a) self.bgColor={r,g,b,a} end function f:GetBackdropColor() return table.unpack(self.bgColor or {0,0,0,0}) end
  function f:SetBackdropBorderColor(r,g,b,a) self.borderColor={r,g,b,a} end function f:GetBackdropBorderColor() return table.unpack(self.borderColor or {0,0,0,0}) end
  function f:GetFont() return "FRIZQT__.TTF", 14, "" end function f:SetFont(file,size,flags) self.fontFile=file self.fontSize=size end
  table.insert(frames,f) return f
end
local BootFrame = mkframe("Frame")
function CreateFrame(t,n,p,tmpl) return mkframe(t,n,p,tmpl) end
UIParent = BootFrame
UISpecialFrames = {}
SlashCmdList = {}
C_Timer = { tickers = {} }
function C_Timer.NewTicker(i,fn) local t={interval=i,fn=fn,cancelled=false} function t:Cancel() self.cancelled=true end function t:Tick() if not self.cancelled then self.fn() end end table.insert(C_Timer.tickers,t) return t end
local function findCore() for _,f in ipairs(frames) do if f.registered["ADDON_LOADED"] then return f end end end
local function findRes(core) for _,f in ipairs(frames) do if f~=core and f.scripts["OnEvent"] then return f end end end
local ALL_ORDER = {"Init.lua","Locales/enUS.lua","Locales/zhCN.lua","Config/Defaults.lua","Core/Core.lua","Core/Resources.lua","Core/Slash.lua","Config/Profile.lua","Locales/Manager.lua","UI/Theme.lua","UI/Widgets.lua","UI/Settings.lua","UI/Diagnostics.lua","UI/ActionBars.lua","UI/Chat.lua","UI/Native.lua","UI/UnitFrames.lua","UI/CastBars.lua","UI/Auras.lua","UI/Nameplates.lua","UI/Restyle.lua","UI/MinimapUI.lua","UI/Media.lua"}
function GetActionTexture() return nil end
function GetActionCount() return 0 end
function GetActionBarPage() return 1 end
function GetPetActionInfo() return nil, nil, nil end
function RegisterStateDriver() end
MainMenuBar = mkframe("Frame","MainMenuBar",UIParent)
PetActionBar = mkframe("Frame","PetActionBar",UIParent)
local ORDER = ALL_ORDER
for _,f in ipairs(ORDER) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local Native = OpenUI.Native
local passCount, failCount = 0, 0
local failures = {}
local function ck(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local coreFrame = findCore()
local resFrame = findRes(coreFrame)
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame,"ADDON_LOADED","OpenUI")
coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")

-- 1 缺帧登记后补隐藏
Native.Hide("TestA", { "LateFrameAA", "LateFrameAB" })
ck(not _G.LateFrameAA, "frame absent at hide time")
LateFrameAA = mkframe("Frame","LateFrameAA",UIParent)
LateFrameAB = mkframe("Frame","LateFrameAB",UIParent)
resFrame.scripts.OnEvent(resFrame,"ADDON_LOADED","whatever")
ck(LateFrameAA.parent ~= UIParent and LateFrameAB.parent ~= UIParent, "late frames hidden on ADDON_LOADED")
-- 2 独立记账
BuffFrame = mkframe("Frame","BuffFrame",UIParent)
Native.Hide("TestB", { "BuffFrame" })
ck(BuffFrame.parent ~= UIParent, "module B hides BuffFrame")
Native.Restore("TestA")
ck(LateFrameAA.parent == UIParent and LateFrameAA:IsShown(), "restore A only")
ck(BuffFrame.parent ~= UIParent, "module B still hidden")
Native.Restore("TestB")
ck(BuffFrame.parent == UIParent, "restore B")
-- 3 战斗延后
function InCombatLockdown() return true end
Late2 = mkframe("Frame","Late2",UIParent)
ck(Native.Hide("TestC", { "Late2" }) == false, "combat hide deferred")
ck(Late2.parent == UIParent, "not hidden during combat")
function InCombatLockdown() return false end
resFrame.scripts.OnEvent(resFrame,"PLAYER_REGEN_ENABLED")
ck(Late2.parent ~= UIParent, "applied after combat")
-- 4 诊断快照与幂等
local snap = Native.Snapshot()
local hasC = false
for _, line in ipairs(snap) do if line:find("TestC",1,true) then hasC = true end end
ck(hasC, "snapshot lists module C")
ck(Native.IsTracking("TestC") and not Native.IsTracking("TestA"), "tracking state accurate")
ck(Native.Hide("TestC", { "Late2" }) == true, "repeat hide idempotent")
Native.Restore("TestC")
ck(Late2.parent == UIParent, "final restore")
print("== S6 未找到帧名诊断（#59）==")
Native.Hide("Ghost", { "NoSuchFrameZZZ" })
local found = false
for _, line in ipairs(Native.Snapshot()) do
    if line:find("Ghost", 1, true) and line:find("missing=[NoSuchFrameZZZ]", 1, true) then
        found = true
    end
end
ck(found, "Snapshot 输出 missing=[NoSuchFrameZZZ]（帧名不匹配可诊断）")
Native.Restore("Ghost")
print("== S7 受保护/管理帧淡化策略（#70）==")
local ProtectedFrame = mkframe("Frame", "ProtectedFrame", UIParent)
function ProtectedFrame:IsProtected() return true end
_G.ProtectedFrame = ProtectedFrame
local ManagedFrame = mkframe("Frame", "ManagedFrame", UIParent)
ManagedFrame.isManagedFrame = true
_G.ManagedFrame = ManagedFrame
Native.Hide("TestFade", { "ProtectedFrame", "ManagedFrame" })
ck(math.abs((ProtectedFrame.alpha or 1) - 0.0001) < 1e-9, "受保护帧淡化为 0.0001（不隐藏）")
ck(ProtectedFrame.parent == UIParent and ProtectedFrame:IsShown(), "受保护帧不换父不隐藏")
ck(ProtectedFrame.mouse == false, "受保护帧禁鼠标")
ck(ManagedFrame.isManagedFrame and math.abs((ManagedFrame.alpha or 1) - 0.0001) < 1e-9,
    "EditMode 管理帧同样淡化")
local fadeLabel = false
for _, line in ipairs(Native.Snapshot()) do
    if line:find("TestFade", 1, true) and line:find("(fade)", 1, true) then fadeLabel = true end
end
ck(fadeLabel, "Snapshot 标注 (fade) 模式")
Native.Restore("TestFade")
ck((ProtectedFrame.alpha or 1) == 1 and ProtectedFrame.mouse == true, "恢复 alpha 与鼠标")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then for _, f in ipairs(failures) do io.stderr:write("FAIL: "..f.."\n") end os.exit(1) end
os.exit(0)
