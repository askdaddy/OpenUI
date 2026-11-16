-- OpenUI 布局网格黑盒测试（Issue #52 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_grid_test.lua
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
local function mktex() local t={} function t:SetPoint() end function t:SetAllPoints() end function t:SetColorTexture(r,g,b,a) self.r,self.g,self.b,self.a=r,g,b,a end function t:SetAlpha() end function t:SetTexture(x) self.texture=x end function t:SetSize(w,h) self.w=w self.h=h end function t:SetHeight() end function t:SetGradient() end function t:Hide() self.hidden=true end function t:Show() self.hidden=false end return t end
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
  function f:SetAlpha(a) self.alpha=a end function f:GetAlpha() return self.alpha or 1 end
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
function IsAltKeyDown() return true end
MainMenuBar = mkframe("Frame","MainMenuBar",UIParent)
PetActionBar = mkframe("Frame","PetActionBar",UIParent)
local ORDER = ALL_ORDER
for _,f in ipairs(ORDER) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local Grid = OpenUI.Grid
local S = OpenUI.Settings
local Theme = OpenUI.Theme
local passCount, failCount = 0, 0
local function tickAll() local snap={} for i,t in ipairs(C_Timer.tickers) do snap[i]=t end for _,t in ipairs(snap) do t:Tick() end end
local failures = {}
local function ck(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [%s] %s\n"):format(cond and "PASS" or "FAIL", label))
end
local coreFrame = findCore()
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame,"ADDON_LOADED","OpenUI")
coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")
ck(OpenUI:IsModuleEnabled("Grid") == false, "Grid default off")
OpenUI:EnableModule("Grid")
ck(not Grid.IsShown(), "overlay hidden by default")
local count48 = Grid.Rebuild()
ck(count48 == 25, "48px grid lines (640x480) count="..count48)
ck(Grid.Toggle() == true and Grid.IsShown(), "toggle shows overlay")
ck(OpenUI.Profile.Config().grid.shown == true, "shown persisted")
Grid.SetSize(64)
ck(Grid.SegmentCount() == 19, "64px rebuild count="..Grid.SegmentCount())
local x, y = Grid.Snap(100, 100)
ck(x == 128 and y == 128, "snap 100 -> 128 (64 grid)")
Grid.SetSnap(false)
local ux, uy = Grid.Snap(100, 100)
ck(ux == 100 and uy == 100, "snap disabled unchanged")
Grid.SetSnap(true)
local testFrame = mkframe("Frame", nil, UIParent)
function testFrame:GetLeft() return 100 end
function testFrame:GetBottom() return 100 end
OpenUI.Widgets.MakeDraggable(testFrame, "test", "f1", { "TOPLEFT", "TOPLEFT", 0, 0 })
testFrame.scripts.OnDragStop(testFrame)
local saved = OpenUI.Profile.Config().test.f1
ck(saved.x == 128 and saved.y == 128, "drag stop snaps and persists")
local gridFrame
for _, f in ipairs(frames) do if f.name == "OpenUIGrid" then gridFrame = f end end
ck(gridFrame ~= nil and #gridFrame.textures > 0, "grid textures exist")
local firstTex = gridFrame.textures[#gridFrame.textures]
Theme.SetPalette("moss")
local outline = Theme.Get("color.outline-variant")
ck(firstTex.r == outline[1], "line color follows theme")
local out = {}
local savedPrint = print
print = function(...) local parts={} for i=1,select("#",...) do parts[#parts+1]=tostring((select(i,...))) end out[#out+1]=table.concat(parts," ") end
SlashCmdList.OPENUI("grid")
print = savedPrint
ck(#out > 0 and out[1]:find("grid",1,true) ~= nil, "slash /openui grid toggles")
ck(not Grid.IsShown(), "slash toggled off")
S.Open()
S.OpenModule("Grid")
local found = false
for _, f in ipairs(frames) do
    if f.frameType == "Button" and f.themedLabel and f.themedLabel.text:find("Show grid",1,true) then found = true end
end
ck(found, "grid module panel has display toggle")
OpenUI:DisableModule("Grid")
ck(not Grid.IsShown(), "disable hides overlay")
print("== S5 增强：/openui grid <尺寸> 与拖拽淡入淡出 ==")
local outs = {}
local savedPrint2 = print
print = function(...) local parts={} for i=1,select("#",...) do parts[#parts+1]=tostring((select(i,...))) end outs[#outs+1]=table.concat(parts," ") end
SlashCmdList.OPENUI("grid 8")
print = savedPrint2
ck(Grid.GetSize() == 8, "/openui grid 8 sets size 8")
ck(Grid.IsShown(), "/openui grid 8 shows overlay")
ck(#outs > 0 and outs[1]:find("8",1,true) ~= nil, "prints size confirmation")
-- 淡入淡出：拖拽开始 alpha 趋向 1
local gridFrame
for _, f in ipairs(frames) do if f.name == "OpenUIGrid" then gridFrame = f end end
gridFrame.alpha = 0.45
Grid.NotifyDragStart()
for i = 1, 10 do tickAll() end
ck(gridFrame.alpha == 1, "drag start fades to 1.0")
Grid.NotifyDragEnd()
for i = 1, 10 do tickAll() end
ck(math.abs((gridFrame.alpha or 0) - 0.45) < 1e-9, "drag end fades back to 0.45")
-- 中心轴 primary 高亮
LocalTheme = Theme
local primary = Theme.Get("color.primary")
local centerFound = false
for _, tex in ipairs(gridFrame.textures) do
    if tex.r == primary[1] and tex.g == primary[2] and tex.a == 0.35 then centerFound = true end
end
ck(centerFound, "center axis uses primary color (0.35)")
print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then for _, f in ipairs(failures) do io.stderr:write("FAIL: "..f.."\n") end os.exit(1) end
os.exit(0)
