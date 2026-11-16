-- OpenUI 视觉v3黑盒测试（Issue #55 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_visual3_test.lua
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
local function mktex() local t={} function t:SetPoint() end function t:SetAllPoints() end function t:SetColorTexture(r,g,b,a) self.r,self.g,self.b=r,g,b end function t:SetAlpha() end function t:SetTexture(x) self.texture=x end function t:SetSize(w,h) self.w=w self.h=h end function t:SetHeight() end function t:SetGradient(o,c1,c2) self.gradient={orientation=o,c1=c1,c2=c2} end function t:Hide() self.hidden=true end function t:Show() self.hidden=false end return t end
local function mkfs() local f={shown=true} function f:SetPoint() end function f:SetWidth() end function f:SetText(s) self.text=s end function f:SetTextColor() end function f:SetAlpha() end function f:SetFont() end function f:Show() self.shown=true end function f:Hide() self.shown=false end function f:IsShown() return self.shown end return f end
local function mkframe(t,name,parent)
  local f={frameType=t,name=name,shown=true,parent=parent,registered={},scripts={},textures={},fonts={},attrs={},refs={},moving=false}
  function f:RegisterEvent(e) self.registered[e]=true end function f:UnregisterEvent(e) self.registered[e]=nil end
  function f:SetScript(n,fn) self.scripts[n]=fn end
  function f:CreateTexture() local x=mktex(); table.insert(self.textures,x); return x end
  function f:CreateFontString() local x=mkfs(); table.insert(self.fonts,x); return x end
  function f:SetSize() end function f:SetPoint(a,b,c,d,e) self.lastPoint={a,b,c,d,e} end function f:ClearAllPoints() self.lastPoint=nil end function f:SetAllPoints() end
  function f:SetMovable() end function f:EnableMouse() end function f:RegisterForDrag() end
  function f:StartMoving() self.moving=true end function f:StopMovingOrSizing() self.moving=false end
  function f:Show() self.shown=true end function f:Hide() self.shown=false end function f:IsShown() return self.shown end
  function f:SetFrameStrata() end function f:SetFrameLevel() end
  function f:SetAutoFocus() end function f:SetMultiLine() end function f:SetFontObject() end function f:SetTextColor() end function f:SetTextInsets() end
  function f:SetText(s) self.text=s end function f:GetText() return self.text end
  function f:SetAttribute(k,v) self.attrs[k]=v end function f:GetAttribute(k) return self.attrs[k] end
  function f:SetFrameRef(k,v) self.refs[k]=v end function f:RegisterForClicks() end
  function f:SetParent(p) self.parent=p end function f:GetParent() return self.parent end
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
function CreateColor(r,g,b,a) return {r=r,g=g,b=b,a=a} end
local function findCore() for _,f in ipairs(frames) do if f.registered["ADDON_LOADED"] then return f end end end
local function findRes(core) for _,f in ipairs(frames) do if f~=core and f.scripts["OnEvent"] then return f end end end
local ALL_ORDER = {"Init.lua","Locales/enUS.lua","Locales/zhCN.lua","Config/Defaults.lua","Core/Core.lua","Core/Resources.lua","Core/Slash.lua","Config/Profile.lua","Locales/Manager.lua","UI/Theme.lua","UI/Widgets.lua","UI/Settings.lua","UI/Diagnostics.lua","UI/ActionBars.lua","UI/Grid.lua","UI/Chat.lua","UI/Native.lua","UI/UnitFrames.lua","UI/CastBars.lua","UI/Auras.lua","UI/Nameplates.lua","UI/Restyle.lua","UI/MinimapUI.lua","UI/Media.lua"}
function GetScreenWidth() return 640 end
function GetScreenHeight() return 480 end
function GetActionTexture() return nil end
function GetActionCount() return 0 end
function GetActionBarPage() return 1 end
function GetPetActionInfo() return nil, nil, nil end
function RegisterStateDriver() end
function IsAltKeyDown() return false end
function UnitExists() return true end
function UnitName() return "Seven" end
function UnitClass() return "WARRIOR" end
function UnitHealth() return 70 end
function UnitHealthMax() return 100 end
function UnitPower() return 40 end
function UnitPowerMax() return 100 end
function UnitReaction() return 2 end
MainMenuBar = mkframe("Frame","MainMenuBar",UIParent)
PetActionBar = mkframe("Frame","PetActionBar",UIParent)
table.insert(ALL_ORDER, "UI/EditMode.lua")
local ORDER = ALL_ORDER
for _,f in ipairs(ORDER) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local W = OpenUI.Widgets
local Theme = OpenUI.Theme
local passCount, failCount = 0, 0
local failures = {}
local function ck(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local coreFrame = findCore()
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame,"ADDON_LOADED","OpenUI")
coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")

-- GradientFill API
local tex = mktex()
local primary = Theme.Get("color.primary")
ck(W.GradientFill(tex, primary) == true, "GradientFill applies gradient")
ck(tex.gradient ~= nil and tex.gradient.orientation == "VERTICAL", "vertical gradient recorded")
ck(tex.gradient.c1.r > primary[1] and tex.gradient.c2.r < primary[1], "top lighter / bottom darker")
-- 无 SetGradient 降级
local flat = { SetColorTexture = function(self, r, g, b, a) self.r = r end }
ck(W.GradientFill(flat, primary) == false and flat.r == primary[1], "fallback flat color")
-- 单位框体生命条渐变
OpenUI:EnableModule("UnitFrames")
local hpBar = OpenUI.UnitFrames.Player().health
ck(hpBar.gradient ~= nil, "unit frame health bar gradient")
-- 施法条渐变
OpenUI:EnableModule("CastBars")
ck(OpenUI.CastBars.Player().bar.gradient ~= nil, "cast bar gradient")
-- Backdrop 探测 + 边框（桩提供 SetBackdrop）
ck(type(W.HasBackdrop) == "function", "HasBackdrop probe exists")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then for _, f in ipairs(failures) do io.stderr:write("FAIL: "..f.."\n") end os.exit(1) end
os.exit(0)
