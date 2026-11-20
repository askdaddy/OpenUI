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
function UnitFullName(unit) if unit == "player" then return "Seven" end end
function GetRealmName() return "Forever" end

local frames = {}
local function mktex()
    local t = {}
    function t:SetPoint() end
    function t:SetAllPoints() end
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetHeight(h) self.height = h end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:ClearAllPoints() end
    function t:SetRotation(value) self.rotation = value end
    function t:SetAlpha(value) self.alpha = value end
    function t:GetAlpha() return self.alpha or 1 end
    function t:SetTexture() end
    return t
end
local function mkfs()
    local f = { shown = true }
    function f:SetText(s) self.text = s end
    function f:SetTextColor() end
    function f:SetAlpha() end
    function f:SetFont(file, size, flags) self.font = { file, size, flags } end
    function f:GetFont() return table.unpack(self.font or { "FRIZQT__.TTF", 13, "" }) end
    function f:SetWidth() end
    function f:GetStringWidth() return #(self.text or "") * 7 end
    function f:ClearAllPoints() end
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
    function f:HookScript(n, fn)
        local native = self.scripts[n]
        self.scripts[n] = function(...)
            if native then native(...) end
            fn(...)
        end
    end
    function f:CreateTexture() local x = mktex(); self.textures[#self.textures + 1] = x; return x end
    function f:CreateFontString() local x = mkfs(); self.fonts[#self.fonts + 1] = x; return x end
    function f:SetSize(w, h)
        self.width, self.height = w, h
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, w, h) end
    end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetWidth() return self.width or 800 end
    function f:GetHeight() return self.height or 600 end
    function f:SetPoint(...)
        self.points = self.points or {}
        table.insert(self.points, table.pack(...))
    end
    function f:ClearAllPoints() self.points = {} end
    function f:GetNumPoints() return #(self.points or {}) end
    function f:GetPoint(i) return table.unpack(self.points[i], 1, self.points[i].n) end
    function f:GetLeft() return self.left or 24 end
    function f:GetBottom() return self.bottom or 90 end
    function f:GetTop() return self:GetBottom() + self:GetHeight() end
    function f:GetEffectiveScale() return 1 end
    function f:GetAlpha() return self.alpha or 1 end
    function f:SetAlpha(a) self.alpha = a end
    function f:IsMouseEnabled() return self.mouse ~= false end
    function f:GetFrameLevel() return self.frameLevel or 1 end
    function f:SetFrameLevel(level) self.frameLevel = level end
    function f:GetScript(name) return self.scripts[name] end
    function f:SetJustifyH(value) self.justify = value end
    function f:GetJustifyH() return self.justify or "CENTER" end
    function f:SetResizable() end
    function f:SetClampedToScreen() end
    function f:SetResizeBounds() end
    function f:StartSizing(edge) self.sizing = edge end
    function f:SetScrollChild(child) self.scrollChild = child end
    function f:EnableMouseWheel(value) self.wheel = value end
    function f:SetHorizontalScroll(value) self.horizontal = value end
    function f:GetHorizontalScroll() return self.horizontal or 0 end
    function f:SetMaxLines(limit) self.maxLines = limit end
    function f:SetFading() end
    function f:SetHyperlinksEnabled(enabled) self.hyperlinks = enabled end
    function f:SetScrollOffset(value) self.offset = value end
    function f:GetScrollOffset() return self.offset or 0 end
    function f:ScrollUp() self.offset = (self.offset or 0) + 1 end
    function f:ScrollDown() self.offset = math.max(0, (self.offset or 0) - 1) end
    function f:ScrollToBottom() self.offset = 0 end
    function f:AddMessage(...) self.lines = self.lines or {}; self.lines[#self.lines + 1] = table.pack(...) end
    function f:GetNumMessages() return #(self.lines or {}) end
    function f:GetMessageInfo(i) return table.unpack(self.lines[i], 1, self.lines[i].n) end
    function f:Clear() self.lines = {} end
    function f:GetFont() return table.unpack(self.font or { "FRIZQT__.TTF", 13, "" }) end
    function f:SetFont(file, size, flags) self.font = { file, size, flags } end
    function f:SetAllPoints() end
    function f:SetMovable() end
    function f:EnableMouse(value) self.mouse = value end
    function f:RegisterForDrag() end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving, self.sizing = false, nil end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetAutoFocus() end
    function f:SetFontObject() end
    function f:SetFocus() self.focused = true end
    function f:ClearFocus() self.focused = false end
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

-- #74: run the supported client path after testing the legacy fallback.
OpenUI:DisableModule("Chat")
local localParty = false
function IsInGroup() return localParty end
function IsInRaid() return false end
function IsInGuild() return true end
function GetChannelList() return 2, "Trade", false, 6, "Services", false, 7, "Other", true end
function GetChannelName(i) return i, i == 2 and "Trade" or "Services" end
ChatTypeInfo = {
    SAY = { id = 1, r = 1, g = 1, b = 1 },
    PARTY = { id = 2, r = 0.4, g = 0.6, b = 1 },
    GUILD = { id = 3, r = 0.3, g = 1, b = 0.4 },
    CHANNEL2 = { id = 4, r = 1, g = 0.75, b = 0.6 },
}
local opened, linkClick
local senderFilters = {}
function ChatFrame_AddMessageEventFilter(event, callback) senderFilters[event] = callback end
function UnitGUID(unit) if unit == "player" then return "Player-test-self" end end
function ChatFrame_OpenChat(text, f) opened = { text, f }; ChatFrame1EditBox:SetText(text) end
function hooksecurefunc(object, method, after)
    local native = object[method]
    object[method] = function(self, ...)
        native(self, ...)
        after(self, ...)
    end
end
ChatFrame1:SetScript("OnHyperlinkClick", function(_, link, text, button) linkClick = { link, text, button } end)
QuickJoinToastButton = mkframe("Button", "QuickJoinToastButton", UIParent)
GeneralDockManager = mkframe("Frame", "GeneralDockManager", UIParent)
CombatLogQuickButtonFrame = mkframe("Frame", "CombatLogQuickButtonFrame", ChatFrame2)
ChatFrame2EditBox = mkChatFrame("ChatFrame2EditBox", true, true)
local focusDecoration = mktex()
function focusDecoration:GetObjectType() return "Texture" end
function ChatFrame2EditBox:GetRegions() return focusDecoration end
ChatFrame2EditBox:SetScript("OnEditFocusGained", function() focusDecoration:SetAlpha(1) end)
ChatFrame2.Background = mktex()
ChatFrame2.Background:SetAlpha(0.6)
ChatFrame1EditBox:SetPoint("BOTTOMLEFT", ChatFrame1, "BOTTOMLEFT", 2, -18)
ChatFrame1:AddMessage("|Hplayer:Initial|hInitial|h: already in history", 1, 1, 1, 3, 0, 101)
OpenUI:EnableModule("Chat")
local function frameBy(test)
    for _, f in ipairs(frames) do if test(f) then return f end end
end
local window = assert(frameBy(function(f) return f.name == "OpenUIChat" end), "custom chat not constructed")
local reader = assert(frameBy(function(f) return f.hyperlinks and f.parent == window end), "missing live message area")
local function tab(label)
    return frameBy(function(f)
        return f.frameType == "Button" and f.fonts[1] and f.fonts[1].text == label and f:IsShown()
    end)
end
local function click(f) return assert(f and f.scripts.OnClick)(f) end
check(window:IsShown() and ChatFrame1:GetAlpha() == 0, "custom surface is visible and native message frame covered")
check(ChatFrame1EditBox:GetParent() == window, "native edit box shares custom background")
check(reader:GetJustifyH() == "LEFT", "chat messages are left-aligned")
ChatFrame2EditBox.scripts.OnEditFocusGained(ChatFrame2EditBox)
check(ChatFrame2EditBox:GetParent() == window and focusDecoration:GetAlpha() == 0
    and ChatFrame2EditBox.bgColor[4] == 0, "focused secondary native editor uses integrated style")
check(not QuickJoinToastButton:GetParent():IsShown() and not GeneralDockManager:GetParent():IsShown(),
    "native social button and dock are suppressed")
check(tab("General") and tab("Combat Log") and not tab("Guild"), "only two tabs at startup")
check(reader:GetNumMessages() == 1, "native history loaded into General")
ChatFrame1:AddMessage("|cff00ff00|Hplayer:Seven|hSeven|h|r: |Hitem:12|hBag|h", 0.3, 1, 0.4, 3, 0, 102)
check(tab("Guild") and reader:GetNumMessages() == 2, "new guild message creates a single tab and stays in General")
check(reader.lines[2][1]:find("|Hplayer:Seven|h[Seven]|h", 1, true) and
    reader.lines[2][1]:find("|Hitem:12|h[Bag]|h", 1, true), "bracket labels preserve hyperlink payload")
check(reader.lines[2][2] == 0.3 and reader.lines[2][3] == 1, "full line uses channel color")
ChatFrame1:AddMessage("duplicate", 1, 1, 1, 3, 0, 102)
check(reader:GetNumMessages() == 2, "duplicate native line is not shown twice")
ChatFrame1:AddMessage("Trade message", 1, 0.75, 0.6, 4, 0, 103)
check(tab("Trade") and reader:GetNumMessages() == 3, "joined channel starts its own tab and is aggregated")
click(tab("Guild"))
check(reader:GetNumMessages() == 2, "guild tab includes only guild history")
reader.scripts.OnHyperlinkClick(reader, "player:Seven", "[Seven]", "RightButton")
check(linkClick and linkClick[3] == "RightButton" and linkClick[1] == "player:Seven", "native link and button forwarded")
reader.scripts.OnMouseWheel(reader, 1)
check(reader:GetScrollOffset() == 1, "wheel scrolls message history")
click(tab("Back to latest"))
check(reader:GetScrollOffset() == 0, "return to latest resets scroll")
click(tab("Combat Log"))
check(ChatFrame2:IsShown() and not reader:IsShown(), "combat tab keeps original log frame")
check(ChatFrame2:GetJustifyH() == "LEFT" and ChatFrame2.Background:GetAlpha() == 0
    and not CombatLogQuickButtonFrame:GetParent():IsShown(), "combat mode shows the text without native chrome")
click(tab("General"))
check(not ChatFrame2:IsShown() and reader:GetNumMessages() == 3, "general restores all channels")

local function sendButton(label)
    for _, f in ipairs(frames) do
        if f.frameType == "Button" and f:IsShown() and f.scripts.OnEnter and f.parent and
            f.parent.parent == window and f.parent.fonts[1] then
            f.scripts.OnEnter(f)
            if f.parent.fonts[1].text == label then return f end
            if f.scripts.OnLeave then f.scripts.OnLeave(f) end
        end
    end
end
for _, channel in ipairs({ "Say", "Party", "Raid", "Instance", "Guild", "Yell", "Whisper" }) do
    check(sendButton(channel), "fixed send channel is shown: " .. channel)
end
opened = nil
click(sendButton("Party"))
check(not opened, "unavailable fixed channel ignores clicks")
check(sendButton("Trade") and not sendButton("Services"), "public choices reflect memberships")
localParty = true
resFrame.scripts.OnEvent(resFrame, "GROUP_ROSTER_UPDATE")
click(sendButton("Party"))
check(opened and opened[1] == "/p " and opened[2] == ChatFrame1, "send choice opens native editor without sending")

local social, macro, recipient, selectedLanguage, emote
function ToggleFriendsFrame() social = true end
function ShowMacroFrame() macro = true end
function GetNumLanguages() return 1 end
function GetLanguageByIndex() return "Common", 1 end
function ChatFrame1EditBox:SetGameLanguage(name, id) selectedLanguage = { name, id } end
EmoteList, TextEmoteSpeechList = { "WAVE" }, { "HELLO" }
function DoEmote(token) emote = token end
MenuUtil = { CreateContextMenu = function(_, setup)
    setup(nil, { CreateButton = function(_, _, callback) callback() end })
end }
ChatFrameUtil = { SendTell = function(name, native) recipient = { name, native } end }
click(tab("O"))
click(tab("M"))
click(tab("L"))
click(tab("E"))
check(social and macro and selectedLanguage[1] == "Common" and emote == "WAVE", "left toolbar calls native actions")
click(tab("T"))
check(emote == "HELLO", "talk opens voice emote actions")
opened = nil
click(sendButton("Whisper"))
local promptInput = frameBy(function(f) return f.frameType == "EditBox" and f.focused end)
check(promptInput and not opened, "whisper opens recipient prompt without a Say slash draft")
promptInput:SetText("Seven-Forever")
promptInput.scripts.OnEnterPressed(promptInput)
check(recipient and recipient[1] == "Seven-Forever" and recipient[2] == ChatFrame1 and not opened,
    "recipient is passed to the native whisper entry")

RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
ITEM_QUALITY_COLORS = { [4] = { hex = "|cffa335ee" } }
function UnitClass(unit) if unit == "player" then return "Mage", "MAGE" end end
function UnitLevel(unit) if unit == "player" then return 60 end end
function GetItemInfo(link)
    if link == "item:99" then return "Relic", nil, 4 end
end
ChatFrame1:AddMessage("|Hplayer:Seven|hSeven|h: |Hitem:99|hRelic|h |Hplayer:Other|h[Other]|h", .3, 1, .4, 3, 0, 104)
local colored = reader.lines[reader:GetNumMessages()][1]
check(colored:find("|Hplayer:Seven|h|cff3fc7eb[60 Seven]|r|h", 1, true)
    and colored:find("|Hitem:99|h|cffa335ee[Relic]|r|h", 1, true),
    "known player level, class and item quality preserve hyperlink payload")
check(colored:find("|Hplayer:Other|h[Other]|h", 1, true), "unknown class keeps channel color")
ChatFrame1:AddMessage("|Hplayer:New|h[|cff3fc7ebNew|r]|h: |cffa335ee|Hitem:100|h[Uncached]|h|r", .3, 1, .4, 3, 0, 105)
colored = reader.lines[reader:GetNumMessages()][1]
check(colored:find("|Hplayer:New|h|cff3fc7eb[New]|r|h", 1, true)
    and colored:find("|Hitem:100|h|cffa335ee[Uncached]|r|h", 1, true),
    "native class color and uncached item quality are preserved")

function GetNumGuildMembers() return 1 end
function GetGuildRosterInfo() return "Guildie-Forever", nil, nil, 46 end
C_FriendList = {
    GetNumFriends = function() return 1 end,
    GetFriendInfoByIndex = function() return { name = "Friend-Forever", level = 38 } end,
}
resFrame.scripts.OnEvent(resFrame, "GUILD_ROSTER_UPDATE")
ChatFrame1:AddMessage("|Hplayer:Guildie|hGuildie|h |Hplayer:Friend|hFriend|h", .3, 1, .4, 3, 0, 106)
colored = reader.lines[reader:GetNumMessages()][1]
check(colored:find("[46 Guildie]", 1, true) and colored:find("[38 Friend]", 1, true),
    "matching guild and friend roster levels appear outside the group")

local sayFilter = assert(senderFilters.CHAT_MSG_SAY)
local suppressed = sayFilter(ChatFrame1, "CHAT_MSG_SAY", "A sample", "Seven-Realm Alias",
    nil, nil, nil, nil, nil, nil, nil, nil, 107, "Player-test-self")
ChatFrame1:AddMessage("[Say] [Seven-Realm Alias]: A sample", 1, 1, 1, 1, 0, 107)
colored = reader.lines[reader:GetNumMessages()][1]
check(not suppressed and colored:find("[60 Seven-Realm Alias]", 1, true),
    "raw sender GUID supplies own level even when the display line has no player hyperlink")

local ownGUID = UnitGUID
function UnitGUID(unit)
    if unit == "party1" then return "Player-test-party" end
    return ownGUID(unit)
end
function GetNumSubgroupMembers() return 1 end
local ownLevel = UnitLevel
function UnitLevel(unit) if unit == "party1" then return 54 end; return ownLevel(unit) end
sayFilter(ChatFrame1, "CHAT_MSG_SAY", "Cross-realm sample", "Teammate-OtherRealm",
    nil, nil, nil, nil, nil, nil, nil, nil, 108, "Player-test-party")
ChatFrame1:AddMessage("[Say] [Teammate]: Cross-realm sample", 1, 1, 1, 1, 0, 108)
colored = reader.lines[reader:GetNumMessages()][1]
check(colored:find("[54 Teammate]", 1, true), "cross-realm speaker level resolved by party GUID")

function GetPlayerInfoByGUID(guid)
    if guid == "Player-test-stranger" then
        return "Mage", "MAGE", "人类", "HUMAN", 3, "Stranger", "OtherRealm", 57
    end
end
ChatFrame1:AddMessage("|Hplayer:Stranger:109|h[Stranger]|h: Hello", 1, 1, 1, 1, 0, 109, "CHAT_MSG_SAY",
    { [1] = "Hello", [2] = "Stranger-OtherRealm", [11] = 109, [12] = "Player-test-stranger" })
colored = reader.lines[reader:GetNumMessages()][1]
check(colored:find("|Hplayer:Stranger:109|h[57 人类♀ Stranger]|h", 1, true),
    "Forever event GUID supplies level, race and sex for an ungrouped speaker")

function IsControlKeyDown() return true end
reader.scripts.OnHyperlinkClick(reader, "player:Teammate-OtherRealm:109", "[Teammate]", "LeftButton")
check(linkClick[1] == "player:Teammate-OtherRealm:109", "Ctrl-click returns to native player link behavior")
IsControlKeyDown = nil

local general = tab("General")
general.scripts.OnDragStart(general)
check(window.moving, "dragging the tab moves the chat component")
window.left, window.bottom = 56, 142
general.scripts.OnDragStop(general)
local grip = assert(frameBy(function(f)
    return f.parent == window and #f.textures == 3 and f.scripts.OnDragStart
end))
grip.scripts.OnDragStart(grip)
check(window.sizing == "TOPRIGHT", "grip resizes from top right")
window:SetSize(650, 280)
grip.scripts.OnDragStop(grip)
local config = OpenUI.Profile.Config().chat
check(config.position.x == 56 and config.position.y == 142 and config.position.width == 650
    and config.position.height == 280, "release saves position and size")
OpenUI.Settings.OpenModule("Chat")
click(tab("17"))
check(Chat.GetMessageSize() == 17 and reader.font[2] == 17 and config.messageSize == 17,
    "main settings changes and persists the message font")

OpenUI:DisableModule("Chat")
check(not window:IsShown() and ChatFrame1:GetAlpha() == 1 and ChatFrame2:IsShown(), "disable restores the native frames")
check(QuickJoinToastButton:GetParent() == UIParent and GeneralDockManager:GetParent() == UIParent
    and CombatLogQuickButtonFrame:GetParent() == ChatFrame2 and ChatFrame2.Background:GetAlpha() == 0.6
    and ChatFrame2:GetJustifyH() == "CENTER", "native chrome and alignment are restored")
local _, relative, _, dx, dy = ChatFrame1EditBox:GetPoint(1)
check(ChatFrame1EditBox:GetParent() == UIParent and relative == ChatFrame1 and dx == 2 and dy == -18,
    "disable restores native edit box parent and anchors")
OpenUI:EnableModule("Chat")
check(window:GetWidth() == 650 and window:GetHeight() == 280 and Chat.GetMessageSize() == 17,
    "enable restores saved layout and font")
local _, _, _, x, y = window:GetPoint(1)
check(x == 56 and y == 142, "enable restores saved position")
check(not tab("Guild"), "reopen only shows the default tabs before new chat")

print(("== 结果: %d 通过, %d 失败 =="):format(passCount, failCount))
if #failures > 0 then
    for _, f in ipairs(failures) do io.stderr:write("FAIL: " .. f .. "\n") end
    os.exit(1)
end
os.exit(0)
