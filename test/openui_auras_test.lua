-- OpenUI 光环黑盒测试（Issue #15 plan 步骤 1–3 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_auras_test.lua
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
local function mktex() local t={} function t:SetPoint() end function t:SetAllPoints() end function t:SetColorTexture(r,g,b,a) self.r,self.g,self.b=r,g,b end function t:SetAlpha() end function t:SetTexture(x) self.texture=x end function t:SetSize() end return t end
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
BuffFrame = mkframe("Frame","BuffFrame",UIParent)
-- 光环桩
local NOW = 100.0
function GetTime() return NOW end
local BUFFS, DEBUFFS = {}, {}
function UnitBuff(unit, i)
  local b = BUFFS[i]
  if b then return b.name, nil, b.icon, b.stacks, nil, b.duration or 0, b.expiration or 0 end
end
function UnitDebuff(unit, i)
  local d = DEBUFFS[i]
  if d then return d.name, nil, d.icon, d.stacks, nil, d.duration or 0, d.expiration or 0 end
end
local order = {"Init.lua","Locales/enUS.lua","Locales/zhCN.lua","Config/Defaults.lua","Core/Core.lua","Core/Resources.lua","Core/Slash.lua","Config/Profile.lua","Locales/Manager.lua","UI/Theme.lua","UI/Widgets.lua","UI/Settings.lua","UI/Diagnostics.lua","UI/ActionBars.lua","UI/Chat.lua","UI/Native.lua","UI/UnitFrames.lua","UI/CastBars.lua","UI/Auras.lua"}
for _,f in ipairs(order) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local A = OpenUI.Auras
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

ck(OpenUI:IsModuleEnabled("Auras")==false, "B1 default off")
OpenUI:EnableModule("Auras")
local buffRow, debuffRow = A.Row("Buff"), A.Row("Debuff")
ck(not buffRow.frame:IsShown() and not debuffRow.frame:IsShown(), "empty -> rows hidden")
ck(BuffFrame.parent~=UIParent, "native BuffFrame hidden")
-- 注入光环
BUFFS = {
  { name="Mark", icon="icon_mark", stacks=3, expiration=NOW+45 },
  { name="Shield", icon="icon_shield", stacks=1, expiration=0 },
}
DEBUFFS = { { name="Curse", icon="icon_curse", stacks=1, expiration=NOW+120 } }
resFrame.scripts.OnEvent(resFrame,"UNIT_AURA","player")
ck(buffRow.frame:IsShown() and debuffRow.frame:IsShown(), "rows shown with auras")
local s1, s2 = buffRow.slots[1], buffRow.slots[2]
ck(s1.button:IsShown() and s2.button:IsShown() and not buffRow.slots[3].button:IsShown(), "slot visibility = aura count")
ck(s1.icon.texture=="icon_mark" and s1.count.text=="3", "icon + stacks")
ck(s1.time.text=="45" and s2.time.text=="", "duration text / no-duration empty")
ck(debuffRow.slots[1].icon.texture=="icon_curse" and debuffRow.slots[1].time.text=="2m", "debuff icon + minutes")
-- tick 刷新
NOW = NOW + 44
tickAll()
ck(s1.time.text=="1", "ticker refreshes remaining")
-- 清空
BUFFS, DEBUFFS = {}, {}
resFrame.scripts.OnEvent(resFrame,"UNIT_AURA","player")
ck(not buffRow.frame:IsShown() and not debuffRow.frame:IsShown(), "cleared -> hidden")
-- 关闭恢复
OpenUI:DisableModule("Auras")
ck(BuffFrame.parent==UIParent and BuffFrame:IsShown()==true, "native BuffFrame restored")
local aurasTicker = false
for _,t in ipairs(C_Timer.tickers) do if not t.cancelled and t.interval==0.5 then aurasTicker=true end end
ck(not aurasTicker, "ticker cancelled on disable")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
