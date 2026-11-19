-- OpenUI 多动作条黑盒测试（Issue #47 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_multibar_test.lua
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
function GetActionTexture(slot) return "tex"..slot end
function GetActionCount(slot) return 2 end
function GetActionBarPage() return 1 end
function GetPetActionInfo() return nil, nil, nil end
RegisteredDrivers = {}
function RegisterStateDriver(frame, state, driver) table.insert(RegisteredDrivers, {frame=frame, state=state, driver=driver}) end
MainMenuBar = mkframe("Frame","MainMenuBar",UIParent)
PetActionBar = mkframe("Frame","PetActionBar",UIParent)
local ORDER = ALL_ORDER
for _,f in ipairs(ORDER) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local AB = OpenUI.ActionBars
local S = OpenUI.Settings
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
ck(#AB.BarKeys() == 6, "six bars defined")
local keys = AB.BarKeys()
local allBuilt = true
for _, key in ipairs(keys) do
    local bar = AB.Bar(key)
    if not bar or #bar.buttons ~= 12 then allBuilt = false end
end
ck(allBuilt, "each bar has 12 buttons")
local bar2 = AB.Bar("bar2")
local okOffsets = true
for i = 1, 12 do
    if bar2.buttons[i]:GetAttribute("action") ~= 12 + i then okOffsets = false end
end
ck(okOffsets, "bar2 fixed slots 13..24")
ck(AB.Bar("bar1").buttons[1]:GetAttribute("action") == 1, "bar1 pageable from slot 1")
ck(AB.MainBar():IsShown(), "main bar shown")
ck(not bar2.frame:IsShown(), "bar2 hidden by default")
S.Open()
S.OpenModule("ActionBars")
ck(S.Tile("ActionBars") ~= nil, "hub has ActionBars tile")
S.OpenModule("ActionBars")
local function btnByPrefix(pfx)
    for _,f in ipairs(frames) do
        if f.frameType=="Button" and f.themedLabel and f.themedLabel.text:find(pfx,1,true)==1 then return f end
    end
end
local bar2Toggle = btnByPrefix("Bar 2")
ck(bar2Toggle ~= nil, "module panel Bar 2 toggle")
bar2Toggle.scripts.OnClick()
ck(bar2.frame:IsShown(), "toggle shows bar2")
local cfg = OpenUI.Profile.Config()
ck(cfg.actionbars and cfg.actionbars.bar2 and cfg.actionbars.bar2.shown == true, "bar2 visible state persisted")
-- 位置持久化
bar2.frame._left, bar2.frame._bottom = 100, 50
function bar2.frame:GetLeft() return self._left end
function bar2.frame:GetBottom() return self._bottom end
function bar2.frame:ClearAllPoints() end
bar2.frame.scripts.OnDragStop(bar2.frame)
ck(cfg.actionbars.bar2.x == 100 and cfg.actionbars.bar2.y == 50, "drag position persisted")
ck(MainMenuBar.parent ~= UIParent, "native bars hidden")
OpenUI:DisableModule("ActionBars")
ck(MainMenuBar.parent == UIParent, "native restored")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then for _, f in ipairs(failures) do io.stderr:write("FAIL: "..f.."\n") end os.exit(1) end
os.exit(0)
