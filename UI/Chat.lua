-- 聊天主题与原生恢复（#12），聊天阅读层与操作控件（#74）。
local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local spread = unpack or table.unpack

local Chat = {}
local originals = {} -- 帧 -> { bg = {r,g,b,a}, border = {r,g,b,a}, font = {file, size, flags} }
local eventsRegistered = false
local fallbackMessageSize

local function targets()
    local list = {}
    local count = tonumber(NUM_CHAT_WINDOWS) or 0
    for i = 1, count do
        local cf = _G["ChatFrame" .. i]
        if cf then list[#list + 1] = cf end
    end
    local editBox = _G.ChatFrame1EditBox
    if editBox then list[#list + 1] = editBox end
    return list
end

local function snapshot(frame)
    local record = originals[frame]
    if record then return record end
    record = {}
    if frame.GetBackdropColor then
        local r, g, b, a = frame:GetBackdropColor()
        if r then record.bg = { r, g, b, a } end
    end
    if frame.GetBackdropBorderColor then
        local r, g, b, a = frame:GetBackdropBorderColor()
        if r then record.border = { r, g, b, a } end
    end
    if frame.GetFont then
        local file, size, flags = frame:GetFont()
        if file then record.font = { file, size, flags } end
    end
    originals[frame] = record
    return record
end

local function applyTo(frame)
    local bg = Theme.Get("color.surface")
    if frame.SetBackdropColor and bg then
        local alpha = Theme.Get("opacity.panel") or 1
        frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha)
    end
    local border = Theme.Get("color.outline")
    if frame.SetBackdropBorderColor and border then
        frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.95)
    end
    local body = Theme.Get("type.body")
    if frame.SetFont and type(body) == "table" then
        local record = snapshot(frame)
        local file = record.font and record.font[1]
        if file then frame:SetFont(file, (fallbackMessageSize and fallbackMessageSize(frame)) or body.size, record.font[3]) end
    end
end

local function restoreFrame(frame)
    local record = originals[frame]
    if not record then return end
    if record.bg and frame.SetBackdropColor then
        frame:SetBackdropColor(record.bg[1], record.bg[2], record.bg[3], record.bg[4])
    end
    if record.border and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(record.border[1], record.border[2], record.border[3], record.border[4])
    end
    if record.font and frame.SetFont then
        frame:SetFont(record.font[1], record.font[2], record.font[3])
    end
end

local function applyAll()
    for _, frame in ipairs(targets()) do
        snapshot(frame)
        applyTo(frame)
    end
end

-- 聊天阅读层：观察原生聊天分发，发言、链接菜单和战斗记录仍由客户端处理。
local L, Widgets = OpenUI.L, OpenUI.Widgets
local OPTIONS = { 12, 13, 15, 17 }
local LIMIT = 240
local GROUPS = {
    { "SAY", "CHAT_CHANNEL_SAY", "SAY" },
    { "YELL", "CHAT_CHANNEL_YELL", "YELL" },
    { "WHISPER", "CHAT_CHANNEL_WHISPER", "WHISPER" },
    { "PARTY", "CHAT_CHANNEL_PARTY", "PARTY" },
    { "RAID", "CHAT_CHANNEL_RAID", "RAID" },
    { "RAID_WARNING", "CHAT_CHANNEL_RAID_WARNING", "RAID_WARNING" },
    { "GUILD", "CHAT_CHANNEL_GUILD", "GUILD" },
    { "OFFICER", "CHAT_CHANNEL_OFFICER", "OFFICER" },
    { "INSTANCE_CHAT", "CHAT_CHANNEL_INSTANCE", "INSTANCE_CHAT" },
    { "BATTLEGROUND", "CHAT_CHANNEL_BATTLEGROUND", "BATTLEGROUND" },
}
local groupByType = {}
for _, def in ipairs(GROUPS) do groupByType[def[1]] = def end
local aliases = {
    PARTY_LEADER = "PARTY", RAID_LEADER = "RAID", INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    WHISPER_INFORM = "WHISPER", BN_WHISPER = "WHISPER", BN_WHISPER_INFORM = "WHISPER",
}
local root, reader, library, tabs, tabStrip, track, thumb, latest, sender, caption, shell, rule, grip
local tabsWidth = 0
local buttons, order, buffered, seen, sendButtons, tabPool = {}, {}, {}, {}, {}, {}
local captured, nativeStates, inputTextures = {}, {}, {}
local selected, active, lastProfile = "all", false, nil
local initializationFailed
local nativeChat, nativeLog, nativeEdit, selectedSend
local layout
local idsByKind = {}

local function profileConfig()
    return OpenUI.Profile and OpenUI.Profile.Config() or _G.OpenUIDB
end

local function saved(create)
    local cfg = profileConfig()
    if type(cfg) ~= "table" then return end
    if create and type(cfg.chat) ~= "table" then cfg.chat = {} end
    return type(cfg.chat) == "table" and cfg.chat or nil
end

function Chat.GetMessageSize()
    local cfg = saved()
    local size = cfg and cfg.messageSize
    for _, allowed in ipairs(OPTIONS) do
        if size == allowed then return size end
    end
    return 13
end

fallbackMessageSize = function(frame)
    local cfg = saved()
    if cfg and cfg.messageSize and frame ~= _G.ChatFrame1EditBox then return Chat.GetMessageSize() end
end

local function paintTexture(tex, color, opacity)
    tex:SetColorTexture(color[1], color[2], color[3], opacity or color[4] or 1)
end

local function role(token)
    return Theme.Get("color." .. token)
end

local function eventColors(kind)
    local info = ChatTypeInfo and ChatTypeInfo[kind]
    if info and info.r and info.g and info.b then return { info.r, info.g, info.b, 1 } end
    return role("primary")
end

local function textAt(parent, x, y, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    label:SetText(text)
    return label
end

local function colorText(label, color)
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function flatButton(parent, label)
    local button = CreateFrame("Button", nil, parent)
    local background = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetAllPoints(button)
    local line = button:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    line:SetHeight(1)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", button, "CENTER")
    text:SetText(label)
    return { button = button, background = background, line = line, text = text }
end

local function sendOptions()
    local result = {}
    local function add(key, label, command, colorKind)
        result[#result + 1] = { key = key, label = label, command = command, color = eventColors(colorKind or key) }
    end
    add("SAY", L.CHAT_CHANNEL_SAY, "/s ")
    add("YELL", L.CHAT_CHANNEL_YELL, "/y ")
    add("WHISPER", L.CHAT_CHANNEL_WHISPER, "/w ")
    local raid = IsInRaid and IsInRaid()
    if raid then
        add("RAID", L.CHAT_CHANNEL_RAID, "/raid ")
        if (UnitIsGroupLeader and UnitIsGroupLeader("player")) or
            (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) then
            add("RAID_WARNING", L.CHAT_CHANNEL_RAID_WARNING, "/rw ")
        end
    elseif IsInGroup and IsInGroup() then
        add("PARTY", L.CHAT_CHANNEL_PARTY, "/p ")
    end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        add("INSTANCE_CHAT", L.CHAT_CHANNEL_INSTANCE, "/i ")
    elseif IsInInstance then
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" then add("BATTLEGROUND", L.CHAT_CHANNEL_BATTLEGROUND, "/bg ") end
    end
    if IsInGuild and IsInGuild() then
        add("GUILD", L.CHAT_CHANNEL_GUILD, "/g ")
        if C_GuildInfo and C_GuildInfo.CanViewOfficerNote and C_GuildInfo.CanViewOfficerNote() then
            add("OFFICER", L.CHAT_CHANNEL_OFFICER, "/o ")
        elseif CanViewOfficerNote and CanViewOfficerNote() then
            add("OFFICER", L.CHAT_CHANNEL_OFFICER, "/o ")
        end
    end
    if GetChannelList then
        local values = { GetChannelList() }
        for i = 1, #values, 3 do
            local id, name, disabled = values[i], values[i + 1], values[i + 2]
            local service = name == L.CHAT_CHANNEL_SERVICE or name == "Services" or name == "Service" or name == "服务"
            if type(id) == "number" and id > 0 and type(name) == "string" and disabled ~= true
                and disabled ~= 1 and not service then
                add("channel:" .. name, name, "/" .. id .. " ", "CHANNEL" .. id)
            end
        end
    end
    return result
end

local function setSend(opt)
    if not active or not ChatFrame_OpenChat then return end
    local input = nativeEdit:GetText() or ""
    local previous = input:match("^/%S+%s+(.*)$") or input
    if opt.key == "WHISPER" or selectedSend == "WHISPER" then previous = "" end
    selectedSend = opt.key
    ChatFrame_OpenChat(opt.command .. previous, nativeChat)
end

local function refreshSender()
    if not active then return end
    local opts = sendOptions()
    local valid = false
    for _, opt in ipairs(opts) do if opt.key == selectedSend then valid = true end end
    if not valid then selectedSend = "SAY" end
    local width = (root:GetWidth() - 18) / #opts
    caption:Hide()
    for i, opt in ipairs(opts) do
        local entry = sendButtons[i]
        if not entry then
            entry = flatButton(sender, "")
            entry.text:Hide()
            local button = entry.button
            button:SetScript("OnClick", function()
                setSend(entry.option)
                for _, other in ipairs(sendButtons) do
                    if other.option then other.line:SetHeight(other.option.key == selectedSend and 4 or 2) end
                end
            end)
            button:SetScript("OnEnter", function()
                caption:ClearAllPoints()
                caption:SetPoint("BOTTOM", button, "TOP", 0, 1)
                caption:SetText(entry.option.label)
                colorText(caption, entry.option.color)
                caption:Show()
            end)
            button:SetScript("OnLeave", function() caption:Hide() end)
            sendButtons[i] = entry
        end
        entry.option = opt
        entry.button:ClearAllPoints()
        entry.button:SetPoint("LEFT", sender, "LEFT", (i - 1) * width, 0)
        entry.button:SetSize(math.max(1, width - 5), 20)
        paintTexture(entry.background, opt.color, 0)
        paintTexture(entry.line, opt.color)
        entry.line:SetHeight(opt.key == selectedSend and 4 or 2)
        entry.button:Show()
    end
    for i = #opts + 1, #sendButtons do
        sendButtons[i].option = nil
        sendButtons[i].button:Hide()
    end
end

local function stripColors(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function formatLine(text, stamp)
    text = stripColors(text):gsub("(|H[%a]+:[^|]+|h)(.-)(|h)", function(opening, title, ending)
        local kind = opening:match("^|H([%a]+):")
        if (kind == "player" or kind == "BNplayer" or kind == "item") and title:sub(1, 1) ~= "[" then
            title = "[" .. title .. "]"
        end
        return opening .. title .. ending
    end)
    return stamp and "|cff9aaabd" .. stamp .. "|r  " .. text or text
end

local function resolveType(id)
    if not id or not ChatTypeInfo then return end
    if idsByKind[id] then return idsByKind[id] end
    for kind, info in pairs(ChatTypeInfo) do
        if type(info) == "table" and info.id then idsByKind[info.id] = kind end
    end
    return idsByKind[id]
end

local function channelIdentity(kind, line)
    local number = kind and kind:match("^CHANNEL(%d+)$")
    if number then
        local name
        if GetChannelName then
            local _
            _, name = GetChannelName(tonumber(number))
        end
        if type(name) ~= "string" or name == "" then name = line:match("|h%[%d+%. ([^%]]+)%]|h") end
        if name then return "channel:" .. name, name end
        return
    end
    local def = groupByType[aliases[kind] or kind]
    if def then return def[1], L[def[2]], def[2] end
end

local function emit(row)
    reader:AddMessage(row.text, row.color[1], row.color[2], row.color[3])
end

local function updateHistory()
    if not active or selected == "combat" then latest:Hide(); return end
    local offset = reader.GetScrollOffset and reader:GetScrollOffset() or 0
    if offset > 0 then latest:Show() else latest:Hide() end
    local messageCount = reader.GetNumMessages and reader:GetNumMessages() or #buffered
    local fraction = math.min(1, offset / math.max(1, messageCount - 1))
    local travel = math.max(1, reader:GetHeight() - 24)
    thumb:ClearAllPoints()
    thumb:SetPoint("BOTTOM", track, "BOTTOM", 0, fraction * travel)
end

local function rebuildReader()
    reader:Clear()
    for _, row in ipairs(buffered) do
        if selected == "all" or row.key == selected then emit(row) end
    end
    reader:ScrollToBottom()
    updateHistory()
end

local function updateTabs()
    if not active then return end
    local x = 0
    for _, key in ipairs(order) do
        local entry = buttons[key]
        local b = entry.button
        local color = entry.kind and eventColors(entry.kind) or role("on-surface-variant")
        if key == "all" then
            for _, opt in ipairs(sendOptions()) do
                if opt.label == L.CHAT_TAB_ALL or opt.label == "General" or opt.label == "综合" then
                    color = opt.color
                    break
                end
            end
        end
        local name = entry.locale and L[entry.locale] or entry.label
        entry.text:SetText(name)
        local width = math.ceil(entry.text:GetStringWidth()) + 20
        b:ClearAllPoints()
        b:SetPoint("LEFT", tabs, "LEFT", x, 0)
        b:SetSize(width, 24)
        paintTexture(entry.background, role("surface-container-high"), key == selected and .86 or .45)
        paintTexture(entry.line, color)
        entry.line:SetHeight(key == selected and 2 or 1)
        colorText(entry.text, key == selected and color or role("on-surface-variant"))
        x = x + width + 6
    end
    tabsWidth = x
    tabs:SetWidth(math.max(root:GetWidth(), x))
    local max = math.max(0, tabsWidth - root:GetWidth())
    tabStrip:SetHorizontalScroll(math.min(tabStrip:GetHorizontalScroll(), max))
end

local function choose(key)
    selected = key
    if key == "combat" then
        reader:Hide()
        track:Hide()
        nativeLog:SetAlpha(1)
        nativeLog:EnableMouse(true)
        nativeLog:Show()
    else
        nativeLog:Hide()
        reader:Show()
        track:Show()
        rebuildReader()
    end
    updateHistory()
    updateTabs()
end

local function persist()
    local cfg = saved(true)
    if not cfg then return end
    local x, y = root:GetLeft(), root:GetBottom()
    if x and y then
        cfg.position = { x = x, y = y, width = root:GetWidth(), height = root:GetHeight() }
    end
end

local function addTab(key, name, kind, locale)
    if buttons[key] then return end
    local entry = table.remove(tabPool) or flatButton(tabs, name)
    local button = entry.button
    button:Show()
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function()
        if not active or entry.dragging then entry.dragging = false; return end
        choose(key)
    end)
    button:SetScript("OnMouseDown", function() entry.dragging = false end)
    button:SetScript("OnDragStart", function()
        if not active then return end
        entry.dragging = true
        root:StartMoving()
    end)
    button:SetScript("OnDragStop", function()
        if not entry.dragging then return end
        root:StopMovingOrSizing()
        persist()
    end)
    entry.label, entry.locale, entry.kind = name, locale, kind
    buttons[key] = entry
    order[#order + 1] = key
end

local function append(line, r, g, b, chatID, lineID, historical)
    if type(line) ~= "string" or line == "" then return end
    if lineID and lineID ~= 0 and seen[lineID] then return end
    local kind = resolveType(chatID)
    local colorKind = aliases[kind] or kind
    local key, name, localized = channelIdentity(kind, line)
    local stamp = not historical and type(date) == "function" and date("%H:%M") or nil
    local color = colorKind and eventColors(colorKind) or { r or 1, g or 1, b or 1, 1 }
    local row = { key = key, text = formatLine(line, stamp), color = color, id = lineID }
    if #buffered == LIMIT then
        local old = table.remove(buffered, 1)
        if old.id then seen[old.id] = nil end
    end
    if lineID and lineID ~= 0 then seen[lineID] = true end
    buffered[#buffered + 1] = row
    if not historical and key and not buttons[key] then
        addTab(key, name, colorKind, localized)
        updateTabs()
    end
    if selected == "all" or selected == key then emit(row); updateHistory() end
end

local function snapshotNative(frame, geometry)
    if not frame or nativeStates[frame] then return end
    local record = { alpha = frame:GetAlpha(), shown = frame:IsShown(), mouse = frame:IsMouseEnabled() }
    if geometry then
        record.points = {}
        for i = 1, frame:GetNumPoints() do record.points[i] = { frame:GetPoint(i) } end
        record.level = frame:GetFrameLevel()
        record.parent = frame:GetParent()
    end
    nativeStates[frame] = record
end

local function restoreNative()
    for frame, record in pairs(nativeStates) do
        if record.points then
            frame:SetParent(record.parent)
            frame:ClearAllPoints()
            for _, point in ipairs(record.points) do frame:SetPoint(spread(point, 1, 5)) end
            frame:SetFrameLevel(record.level)
        end
        frame:SetAlpha(record.alpha)
        frame:EnableMouse(record.mouse)
        if record.shown then frame:Show() else frame:Hide() end
    end
    for texture, alpha in pairs(inputTextures) do texture:SetAlpha(alpha) end
    nativeStates, inputTextures = {}, {}
end

local function cover(frame)
    if not frame or not frame.GetAlpha or not frame.IsMouseEnabled then return end
    if (frame.IsProtected and frame:IsProtected()) or (frame.IsForbidden and frame:IsForbidden()) then return end
    snapshotNative(frame)
    frame:SetAlpha(0)
    frame:EnableMouse(false)
end

local function attachNative()
    snapshotNative(nativeEdit, true)
    snapshotNative(nativeLog, true)
    for i = 1, tonumber(NUM_CHAT_WINDOWS) or 2 do
        local f = _G["ChatFrame" .. i]
        if f and f ~= nativeLog then cover(f) end
        cover(_G["ChatFrame" .. i .. "Tab"])
    end
    cover(_G.ChatFrameMenuButton)
    cover(_G.ChatFrameChannelButton)
    for _, suffix in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
        local texture = nativeEdit[suffix] or _G["ChatFrame1EditBox" .. suffix]
        if texture and texture.GetAlpha and texture.SetAlpha then
            inputTextures[texture] = texture:GetAlpha()
            texture:SetAlpha(0)
        end
    end
    nativeEdit:SetParent(root)
    nativeEdit:ClearAllPoints()
    nativeEdit:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 9, 6)
    nativeEdit:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -9, 6)
    nativeEdit:SetFrameLevel(root:GetFrameLevel() + 5)
    nativeEdit:SetAlpha(1)
    nativeLog:SetParent(root)
    nativeLog:ClearAllPoints()
    nativeLog:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -8)
    nativeLog:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -12, 34)
    nativeLog:SetFrameLevel(root:GetFrameLevel() + 2)
    if nativeLog.SetBackdropColor then nativeLog:SetBackdropColor(0, 0, 0, 0) end
    if nativeLog.SetBackdropBorderColor then nativeLog:SetBackdropBorderColor(0, 0, 0, 0) end
    if nativeEdit.SetBackdropColor then nativeEdit:SetBackdropColor(0, 0, 0, 0) end
    if nativeEdit.SetBackdropBorderColor then nativeEdit:SetBackdropBorderColor(0, 0, 0, 0) end
end

local function supported()
    nativeChat, nativeLog, nativeEdit = _G.ChatFrame1, _G.ChatFrame2, _G.ChatFrame1EditBox
    if not (UIParent and ChatTypeInfo and type(hooksecurefunc) == "function" and ChatFrame_OpenChat
        and nativeChat and nativeLog and nativeEdit and nativeChat.AddMessage
        and nativeEdit.SetFrameLevel and nativeLog.SetFrameLevel and nativeEdit.GetFont) then return false end
    for _, f in ipairs({ nativeChat, nativeLog, nativeEdit }) do
        if (f.IsProtected and f:IsProtected()) or (f.IsForbidden and f:IsForbidden()) then return false end
    end
    return true
end

local function buildShell()
    root = CreateFrame("Frame", "OpenUIChat", UIParent)
    root:SetSize(540, 223)
    root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 90)
    root:SetMovable(true)
    root:SetResizable(true)
    root:SetClampedToScreen(true)
    if root.SetClampRectInsets then root:SetClampRectInsets(0, 0, 29, -23) end
    if root.SetResizeBounds then root:SetResizeBounds(310, 138)
    elseif root.SetMinResize then root:SetMinResize(310, 138) end
    shell = root:CreateTexture(nil, "BACKGROUND", nil, -8)
    shell:SetAllPoints(root)
    rule = root:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 10, 32)
    rule:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -10, 32)
    rule:SetHeight(1)
    -- 保证启动时没有半成品遮盖原生框。
    root:Hide()

    tabStrip = CreateFrame("ScrollFrame", nil, root)
    tabStrip:SetPoint("BOTTOMLEFT", root, "TOPLEFT", 0, 5)
    tabStrip:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", 0, 5)
    tabStrip:SetHeight(24)
    tabs = CreateFrame("Frame", nil, tabStrip)
    tabs:SetSize(540, 24)
    tabStrip:SetScrollChild(tabs)
    tabStrip:EnableMouseWheel(true)
    tabStrip:SetScript("OnMouseWheel", function(_, delta)
        local max = math.max(0, tabsWidth - root:GetWidth())
        tabStrip:SetHorizontalScroll(math.max(0, math.min(max, tabStrip:GetHorizontalScroll() - delta * 55)))
    end)
    addTab("all", L.CHAT_TAB_ALL, nil, "CHAT_TAB_ALL")
    addTab("combat", L.CHAT_TAB_COMBAT, nil, "CHAT_TAB_COMBAT")

    reader = CreateFrame("ScrollingMessageFrame", nil, root)
    reader:SetPoint("TOPLEFT", root, "TOPLEFT", 9, -10)
    reader:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -17, 36)
    reader:SetMaxLines(LIMIT)
    reader:SetFading(false)
    reader:SetHyperlinksEnabled(true)
    reader:EnableMouse(true)
    reader:EnableMouseWheel(true)
    reader:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then reader:ScrollUp() else reader:ScrollDown() end
        updateHistory()
    end)
    for _, event in ipairs({ "OnHyperlinkClick", "OnHyperlinkEnter", "OnHyperlinkLeave" }) do
        reader:SetScript(event, function(_, ...)
            local handler = nativeChat:GetScript(event)
            if handler then return handler(nativeChat, ...) end
            if event == "OnHyperlinkClick" and SetItemRef then SetItemRef(...) end
        end)
    end

    track = CreateFrame("Frame", nil, root)
    track:SetPoint("TOPRIGHT", root, "TOPRIGHT", -7, -29)
    track:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -7, 39)
    track:SetWidth(4)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then reader:ScrollUp() else reader:ScrollDown() end
        updateHistory()
    end)
    track:SetScript("OnMouseDown", function(self)
        if not (reader.SetScrollOffset and GetCursorPosition and self:GetTop()) then return end
        local _, cursorY = GetCursorPosition()
        local fraction = (cursorY / self:GetEffectiveScale() - self:GetBottom()) / self:GetHeight()
        local messageCount = reader.GetNumMessages and reader:GetNumMessages() or #buffered
        reader:SetScrollOffset(math.floor(math.max(0, math.min(1, fraction)) * math.max(0, messageCount - 1)))
        updateHistory()
    end)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints(track)
    track.tint = trackBg
    thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(4, 22)
    latest = Widgets.Button(root, L.CHAT_LATEST)
    latest:SetSize(110, 23)
    latest:SetPoint("BOTTOMRIGHT", reader, "BOTTOMRIGHT", -3, 2)
    latest:SetScript("OnClick", function() reader:ScrollToBottom(); updateHistory() end)

    sender = CreateFrame("Frame", nil, root)
    sender:SetPoint("TOPLEFT", root, "BOTTOMLEFT", 9, -3)
    sender:SetPoint("TOPRIGHT", root, "BOTTOMRIGHT", -9, -3)
    sender:SetHeight(20)
    caption = sender:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:Hide()
    grip = CreateFrame("Button", nil, root)
    grip:SetPoint("TOPRIGHT", root, "TOPRIGHT", -2, -2)
    grip:SetSize(24, 24)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() if active then root:StartSizing("TOPRIGHT") end end)
    grip:SetScript("OnDragStop", function() root:StopMovingOrSizing(); persist() end)
    grip.lines = {}
    for i = 1, 3 do
        local stroke = grip:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(18 - i * 4, 1)
        stroke:SetPoint("CENTER", grip, "CENTER", (i - 2) * 4, (i - 2) * 4)
        stroke:SetRotation(-math.pi / 4)
        grip.lines[i] = stroke
    end
    root:SetScript("OnSizeChanged", function()
        if not active then return end
        updateTabs()
        refreshSender()
        updateHistory()
    end)
end

local function paintShell()
    paintTexture(shell, role("surface"), 0.72)
    paintTexture(rule, role("outline"), 0.32)
    paintTexture(track.tint, role("surface-container-high"))
    paintTexture(thumb, role("outline"))
    for _, stroke in ipairs(grip.lines) do paintTexture(stroke, role("primary")) end
    latest.themedLabel:SetText(L.CHAT_LATEST)
    local font, _, flags = nativeEdit:GetFont()
    if font then reader:SetFont(font, Chat.GetMessageSize(), flags) end
    updateTabs()
    refreshSender()
end

layout = function()
    local cfg = saved()
    local position = cfg and cfg.position
    if type(position) ~= "table" then
        root:SetSize(540, 223)
        root:ClearAllPoints()
        root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 24, 90)
        return
    end
    local w, h = tonumber(position.width) or 540, tonumber(position.height) or 223
    root:SetSize(math.max(310, math.min(w, UIParent:GetWidth())), math.max(138, math.min(h, UIParent:GetHeight())))
    root:ClearAllPoints()
    root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", tonumber(position.x) or 24, tonumber(position.y) or 90)
end

local function attachHooks()
    for i = 1, tonumber(NUM_CHAT_WINDOWS) or 2 do
        local f = _G["ChatFrame" .. i]
        if f and f ~= nativeLog and f.AddMessage and not captured[f] then
            hooksecurefunc(f, "AddMessage", function(_, text, r, g, b, id, _, lineID)
                if active and (lineID and lineID ~= 0 or f == nativeChat) then
                    append(text, r, g, b, id, lineID, false)
                end
            end)
            captured[f] = true
        end
    end
end

local function activate()
    if initializationFailed or not supported() or not OpenUI:CanModifyNow() then return end
    if not root then
        initializationFailed = true
        buildShell()
        initializationFailed = false
    end
    layout()
    attachHooks()
    attachNative()
    active, lastProfile = true, profileConfig()
    root:Show()
    if #buffered == 0 and nativeChat.GetNumMessages and nativeChat.GetMessageInfo then
        local count = nativeChat:GetNumMessages()
        for i = math.max(1, count - LIMIT + 1), count do
            local text, r, g, b, id, _, lineID = nativeChat:GetMessageInfo(i)
            append(text, r, g, b, id, lineID, true)
        end
    end
    choose(selected)
    paintShell()
end

function Chat.SetMessageSize(size)
    for _, allowed in ipairs(OPTIONS) do
        if size == allowed then
            local cfg = saved(true)
            if not cfg then return false end
            cfg.messageSize = size
            Chat.ApplyTheme()
            return true
        end
    end
    return false
end

if OpenUI.Settings and OpenUI.Settings.RegisterModulePanel then
    OpenUI.Settings.RegisterModulePanel("Chat", {
        height = 230,
        build = function(host)
            local title = Widgets.Text(host, L.CHAT_FONT_TITLE, "title")
            title:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
            local previewTitle = Widgets.Text(host, L.CHAT_FONT_PREVIEW)
            previewTitle:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -85)
            local preview = Widgets.Panel(host)
            preview:SetSize(452, 82)
            preview:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -112)
            local samples = { textAt(preview, 10, 11, ""), textAt(preview, 10, 43, "") }
            local buttons = {}
            local function refresh()
                local size = Chat.GetMessageSize()
                title:SetText(L.CHAT_FONT_TITLE)
                previewTitle:SetText(L.CHAT_FONT_PREVIEW)
                samples[1]:SetText(L.CHAT_FONT_SAMPLE_ALL)
                samples[2]:SetText(L.CHAT_FONT_SAMPLE_GUILD)
                for i, sample in ipairs(samples) do
                    local font, _, flags = sample:GetFont()
                    if font then sample:SetFont(font, size, flags) end
                    colorText(sample, i == 1 and role("on-surface") or eventColors("GUILD"))
                end
                for i, button in ipairs(buttons) do
                    button.themedLabel:SetText((OPTIONS[i] == size and "● " or "") .. OPTIONS[i])
                end
            end
            for i, size in ipairs(OPTIONS) do
                local b = Widgets.Button(host, tostring(size))
                b:SetPoint("TOPLEFT", host, "TOPLEFT", (i - 1) * 114, -32)
                b:SetSize(108, 34)
                b:SetScript("OnClick", function() Chat.SetMessageSize(size); refresh() end)
                buttons[i] = b
            end
            return refresh
        end,
    })
end

function Chat.ApplyTheme()
    if active then
        if lastProfile ~= profileConfig() and OpenUI:CanModifyNow() then
            lastProfile = profileConfig()
            layout()
        end
        paintShell()
    elseif next(originals) ~= nil then
        applyAll()
    end
end

local function attemptActivate()
    local ok = OpenUI.Run("Chat/Activate", activate)
    if not ok then
        active = false
        if root then root:Hide() end
        restoreNative()
    end
    if not active then applyAll() end
end

function Chat.OnEnable()
    applyAll()
    if not eventsRegistered then
        eventsRegistered = true
        local own = OpenUI.Own("Chat")
        own:On("PLAYER_ENTERING_WORLD", function()
            if active then Chat.ApplyTheme() else attemptActivate() end
        end)
        own:On("PLAYER_REGEN_ENABLED", function()
            if active then Chat.ApplyTheme() else attemptActivate() end
        end)
        for _, event in ipairs({ "CHANNEL_UI_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do
            own:On(event, refreshSender)
        end
    end
    attemptActivate()
end

function Chat.OnDisable()
    eventsRegistered = false
    active = false
    if root then root:Hide() end
    restoreNative()
    for frame in pairs(originals) do restoreFrame(frame) end
    for _, key in ipairs(order) do
        if key ~= "all" and key ~= "combat" then
            local entry = buttons[key]
            entry.button:Hide()
            entry.dragging = false
            tabPool[#tabPool + 1] = entry
            buttons[key] = nil
        end
    end
    order = root and { "all", "combat" } or {}
    selected, buffered, seen = "all", {}, {}
    selectedSend, lastProfile = nil, nil
    originals = {}
end

Chat.Snapshot = function(frame) return originals[frame] end
OpenUI.Chat = Chat
OpenUI:RegisterModule("Chat", { OnEnable = Chat.OnEnable, OnDisable = Chat.OnDisable })
