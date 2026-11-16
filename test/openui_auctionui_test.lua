-- 共享测试桩头（B1 批量）：帧/纹理/字体串/C_Timer/时钟
-- OpenUI 拍卖行黑盒测试（Issue #29 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_AuctionUI_test.lua
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
local function mkfs() local f={shown=true} function f:SetText(s) self.text=s end function f:SetTextColor() end function f:SetAlpha() end function f:SetFont() end function f:SetPoint() end function f:Show() self.shown=true end function f:Hide() self.shown=false end function f:IsShown() return self.shown end return f end
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
  function f:SetAutoFocus() end function f:SetMultiLine() end function f:SetText(s) self.text=s end function f:GetText() return self.text end
  function f:SetAttribute(k,v) self.attrs[k]=v end function f:GetAttribute(k) return self.attrs[k] end
  function f:SetFrameRef(k,v) self.refs[k]=v end function f:RegisterForClicks() end
  function f:SetParent(p) self.parent=p end function f:GetParent() return self.parent end
  function f:SetBackdropColor(r,g,b,a) self.bgColor={r,g,b,a} end
  function f:GetBackdropColor() return table.unpack(self.bgColor or {0,0,0,0}) end
  function f:SetBackdropBorderColor(r,g,b,a) self.borderColor={r,g,b,a} end
  function f:GetBackdropBorderColor() return table.unpack(self.borderColor or {0,0,0,0}) end
  function f:GetFont() return "FRIZQT__.TTF", 14, "" end
  function f:SetFont(file,size,flags) self.fontFile=file self.fontSize=size end
  table.insert(frames,f) return f
end
local BootFrame = mkframe("Frame")
function CreateFrame(t,n,p,tmpl) return mkframe(t,n,p,tmpl) end
UIParent = BootFrame
UISpecialFrames = {}
SlashCmdList = {}
C_Timer = { tickers = {} }
function C_Timer.NewTicker(i,fn) local t={interval=i,fn=fn,cancelled=false} function t:Cancel() self.cancelled=true end function t:Tick() if not self.cancelled then self.fn() end end table.insert(C_Timer.tickers,t) return t end
local function tickAll() local snap={} for i,t in ipairs(C_Timer.tickers) do snap[i]=t end for _,t in ipairs(snap) do t:Tick() end end
local function findCore()
  for _,f in ipairs(frames) do if f.registered["ADDON_LOADED"] then return f end end
end
local function findRes(core)
  for _,f in ipairs(frames) do if f~=core and f.scripts["OnEvent"] then return f end end
end
local ALL_ORDER = {"Init.lua","Locales/enUS.lua","Locales/zhCN.lua","Config/Defaults.lua","Core/Core.lua","Core/Resources.lua","Core/Slash.lua","Config/Profile.lua","Locales/Manager.lua","UI/Theme.lua","UI/Widgets.lua","UI/Settings.lua","UI/Diagnostics.lua","UI/ActionBars.lua","UI/Chat.lua","UI/Native.lua","UI/UnitFrames.lua","UI/CastBars.lua","UI/Auras.lua","UI/Nameplates.lua"}

local THEME_FRAMES = { "AuctionFrame", "AucHouseFrame" }
for _, name in ipairs(THEME_FRAMES) do
    local f = mkframe("Frame", name, UIParent)
    _G[name] = f
    f.bgColor = { 0.2, 0.2, 0.2, 1 }
end
table.insert(ALL_ORDER, "UI/Restyle.lua")
table.insert(ALL_ORDER, "UI/MinimapUI.lua")
table.insert(ALL_ORDER, "UI/AuctionUI.lua")
local ORDER = ALL_ORDER
for _,f in ipairs(ORDER) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local M = OpenUI.AuctionUI
local passCount, failCount = 0, 0
local failures = {}
local function ck(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local coreFrame = findCore()
local resFrame = findRes(coreFrame)
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame,"ADDON_LOADED","OpenUI")
coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")

ck(OpenUI:IsModuleEnabled("AuctionUI")==false, "B1 default off")
OpenUI:EnableModule("AuctionUI")
local surf = Theme.Get("color.surface")
local applied = true
for _, name in ipairs(THEME_FRAMES) do
    local f = _G[name]
    if f and (f.bgColor[1] ~= surf[1] or f.bgColor[4] ~= 0.88) then applied = false end
end
ck(applied, "all existing frames themed (bg x opacity)")
Theme.SetPalette("moss")
local mossSurf = Theme.Get("color.surface")
local refreshed = true
for _, name in ipairs(THEME_FRAMES) do
    local f = _G[name]
    if f and f.bgColor[1] ~= mossSurf[1] then refreshed = false end
end
ck(refreshed, "palette switch re-applies")
OpenUI:DisableModule("AuctionUI")
local restored = true
for _, name in ipairs(THEME_FRAMES) do
    local f = _G[name]
    if f and f.bgColor[1] ~= 0.2 then restored = false end
end
ck(restored, "disable restores originals")
OpenUI:EnableModule("AuctionUI")
ck(_G[THEME_FRAMES[1]] ~= nil and _G[THEME_FRAMES[1]].bgColor[1] == mossSurf[1], "re-enable re-applies")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then for _, f in ipairs(failures) do io.stderr:write("FAIL: "..f.."\n") end os.exit(1) end
os.exit(0)
