-- OpenUI 施法条黑盒测试（Issue #14 plan 步骤 1–3 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_castbars_test.lua
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
local function mktex() local t={w=0,h=0} function t:SetPoint() end function t:SetAllPoints() end function t:SetColorTexture(r,g,b,a) self.r,self.g,self.b=r,g,b end function t:SetAlpha() end function t:SetTexture() end function t:SetSize(w,h) self.w=w self.h=h end return t end
local function mkfs() local f={shown=true} function f:SetText(s) self.text=s end function f:SetTextColor() end function f:SetAlpha() end function f:SetFont() end function f:SetPoint() end function f:Show() self.shown=true end function f:Hide() self.shown=false end function f:IsShown() return self.shown end return f end
local function mkframe(t,name,parent)
  local f={frameType=t,name=name,shown=true,parent=parent,registered={},scripts={},textures={},fonts={}}
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
CastingBarFrame = mkframe("Frame","CastingBarFrame",UIParent)
TargetFrameSpellBar = mkframe("Frame","TargetFrameSpellBar",UIParent)
-- 施法状态桩
local NOW = 100.0
function GetTime() return NOW end
local CAST = {}
function UnitCastingInfo(unit)
  local c = CAST[unit] and CAST[unit].cast
  if c then return c.name, nil, nil, c.start*1000, c.send*1000 end
end
function UnitChannelInfo(unit)
  local c = CAST[unit] and CAST[unit].channel
  if c then return c.name, nil, nil, c.start*1000, c.send*1000 end
end
local order = {"Init.lua","Locales/enUS.lua","Locales/zhCN.lua","Config/Defaults.lua","Core/Core.lua","Core/Resources.lua","Core/Slash.lua","Config/Profile.lua","Locales/Manager.lua","UI/Theme.lua","UI/Widgets.lua","UI/Settings.lua","UI/Diagnostics.lua","UI/ActionBars.lua","UI/Chat.lua","UI/Native.lua","UI/UnitFrames.lua","UI/CastBars.lua"}
for _,f in ipairs(order) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local CB = OpenUI.CastBars
local passCount, failCount = 0, 0
local failures = {}
local function ck(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local coreFrame, resFrame
for _,f in ipairs(frames) do
  if not coreFrame and f.registered["ADDON_LOADED"] then coreFrame=f
  elseif coreFrame and not resFrame and f.scripts["OnEvent"] then resFrame=f end
end
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame,"ADDON_LOADED","OpenUI")
coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")

ck(OpenUI:IsModuleEnabled("CastBars")==false, "B1 default off")
OpenUI:EnableModule("CastBars")
local p = CB.Player()
ck(not p.frame:IsShown(), "no cast -> hidden")
ck(CastingBarFrame.parent~=UIParent and TargetFrameSpellBar.parent~=UIParent, "native cast bars hidden")
-- 玩家施法 3s：t0=98..101
CAST.player = { cast = { name="Fireball", start=98, send=101 } }
resFrame.scripts.OnEvent(resFrame,"UNIT_SPELLCAST_START","player")
ck(p.frame:IsShown() and p.name.text=="Fireball", "cast shown with name")
ck(math.abs(p.bar.w-240*(2/3))<1e-6, "cast progress 2/3")
ck(p.text.text=="1.0s", "remaining 1.0s")
-- 定时推进
NOW = 100.5
tickAll()
ck(p.text.text=="0.5s" and p.bar.w>240*(2/3), "ticker advances progress")
-- 打断
CAST.player = nil
resFrame.scripts.OnEvent(resFrame,"UNIT_SPELLCAST_INTERRUPTED","player")
ck(not p.frame:IsShown(), "interrupt hides")
-- 引导：4s t0=99..103，反向
CAST.player = { channel = { name="Evocation", start=99, send=103 } }
resFrame.scripts.OnEvent(resFrame,"UNIT_SPELLCAST_CHANNEL_START","player")
ck(p.name.text=="Evocation (引导)", "channel label")
ck(math.abs(p.bar.w-240*(1-(1.5/4)))<1e-6, "channel reverse fill (elapsed 1.5/4 -> 62.5%)")
-- 目标施法
CAST.target = { cast = { name="Heal", start=100, send=102 } }
resFrame.scripts.OnEvent(resFrame,"UNIT_SPELLCAST_START","target")
local t = CB.Target()
ck(t.frame:IsShown() and t.name.text=="Heal" and t.text.text=="1.5s", "target cast shown")
-- 关闭恢复
OpenUI:DisableModule("CastBars")
ck(not p.frame:IsShown() and not t.frame:IsShown(), "bars hidden on disable")
ck(CastingBarFrame.parent==UIParent and CastingBarFrame:IsShown()==true, "native restored")
ck(TargetFrameSpellBar.parent==UIParent, "native target cast restored")
-- 定时器释放（#6 Release）
CAST.player = { cast = { name="X", start=99, send=103 } }
tickAll()
local tickerFired = false
for _,tk in ipairs(C_Timer.tickers) do if not tk.cancelled and tk.interval==0.1 then tickerFired=true end end
ck(not tickerFired, "cast ticker cancelled on disable")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
