-- 共享测试桩头（B1 批量）：帧/纹理/字体串/C_Timer/时钟
-- OpenUI 媒体黑盒测试（Issue #43 冻结验收，QA 独立编写）。
-- 运行：lua test/openui_media_test.lua
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
table.insert(ALL_ORDER, "UI/Media.lua")
local ORDER = ALL_ORDER
for _,f in ipairs(ORDER) do assert(loadfile(("%s/%s"):format(ADDON, f)))("OpenUI", ns) end
local OpenUI = ns.OpenUI
local Media = OpenUI.Media
local passCount, failCount = 0, 0
local failures = {}
local function ck(cond, label)
    if cond then passCount = passCount + 1 else failCount = failCount + 1; failures[#failures + 1] = label end
    io.write(("  [s] %s %s\n"):format(cond and "PASS" or "FAIL", label))
end
local coreFrame = findCore()
_G.OpenUIDB = OpenUI.Config.MergeDefaults(nil)
coreFrame.scripts.OnEvent(coreFrame,"ADDON_LOADED","OpenUI")
coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")

-- 场景 A：无 LSM
ck(Media.Register("statusbar", "OpenUI:Flat", "Interface\\AddOns\\OpenUI\\media\\flat") == true, "valid registration")
ck(Media.Fetch("statusbar", "OpenUI:Flat"):find("flat", 1, true) ~= nil, "fetch returns value")
ck(#Media.List("statusbar") == 1, "list contains one")
ck(Media.Register("statusbar", "Plain", "x") == false, "non-prefixed name rejected")
ck(Media.Register("movie", "OpenUI:X", "x") == false, "invalid kind rejected")
ck(Media.Register("statusbar", "OpenUI:Bad", 42) == false, "non-string value rejected")
local n0 = #OpenUI.Diagnose.Errors()
ck(n0 >= 3, "rejections diagnosed")
ck(Media.Register("statusbar", "OpenUI:Flat", "media/flat2") == true and Media.Fetch("statusbar","OpenUI:Flat"):find("flat2",1,true)~=nil, "duplicate overwrites")
ck(Media.Bridge() == false and Media.External("statusbar") == nil, "no LSM -> bridge false, external nil")
-- 场景 B：注入 LSM 桩（模拟其他插件晚加载）
local LSM_STATE = { registered = {}, lists = { statusbar = { "Blizzard", "OpenUI:Flat" } } }
function LSM_STATE:Register(kind, name, value) self.registered[kind..":"..name] = value end
function LSM_STATE:List(kind) return self.lists[kind] end
LSM = { ["LibSharedMedia-3.0"] = LSM_STATE }
LibStub = function(name)
    if name == "LibSharedMedia-3.0" then return LSM[name] end
end
resFrameScenario = true
ck(Media.External("statusbar") ~= nil and #Media.External("statusbar") == 2, "external list via LSM")
ck(Media.Bridge() == true, "bridge succeeds with LSM")
ck(LSM_STATE.registered["statusbar:OpenUI:Flat"] ~= nil, "internal media registered into LSM")
ck(Media.External("statusbar")[1] == "Blizzard", "external includes third-party entries")
-- 预览/配置标识（#43 前置验证）：值为字符串标识
ck(type(Media.Fetch("statusbar", "OpenUI:Flat")) == "string", "media value is identifier string")

-- ==== #43 断言 ====
ck(#Media.Options("statusbar") >= 2, "options merges internal + external")
local seenOpt = {}
for _, n in ipairs(Media.Options("statusbar")) do seenOpt[n] = true end
ck(seenOpt["OpenUI:Flat"] and seenOpt["Blizzard"], "options contains both sources")
local r1 = Media.Resolve("statusbar", "OpenUI:Flat")
ck(r1.source == "internal" and r1.value ~= nil, "resolve internal")
local r2 = Media.Resolve("statusbar", "Blizzard")
ck(r2.source == "external", "resolve external")
local nBefore = #OpenUI.Diagnose.Errors()
local r3 = Media.Resolve("statusbar", "OpenUI:Ghost", "OpenUI:Flat")
ck(r3.source == "internal" and r3.name == "OpenUI:Flat" and r3.fellBack == true, "missing falls back")
ck(#OpenUI.Diagnose.Errors() == nBefore + 1, "missing diagnosed once")
local r4 = Media.Resolve("statusbar", "OpenUI:Ghost")
ck(r4.source == "missing" and r4.value == nil, "no fallback -> missing")
local cfg = {}
ck(Media.SetConfigName(cfg, "statusbar", "statusbar", "OpenUI:Flat") == true and cfg.statusbar == "OpenUI:Flat", "config stores name string only")
ck(Media.SetConfigName(cfg, "k", "statusbar", 42) == false and cfg.k == nil, "non-string name rejected")
ck(type(cfg.statusbar) == "string", "export identifier is string (no material embedded)")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then for _, f in ipairs(failures) do io.stderr:write("FAIL: "..f.."\n") end os.exit(1) end
os.exit(0)
