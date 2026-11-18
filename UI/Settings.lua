-- 主控面板：固定导航与页脚，模块配置在窗口内独立滚动。
local _, ns = ...
local OpenUI = ns.OpenUI
local L, Theme, Widgets = OpenUI.L, OpenUI.Theme, OpenUI.Widgets
local Settings, panels = {}, {}
local categories = {
    { "SETTINGS_CAT_CORE", { "Theme", "Locale", "Profile", "Grid", "Diagnostics" } },
    { "SETTINGS_CAT_COMBAT", { "ActionBars", "UnitFrames", "CastBars", "Auras", "Nameplates" } },
    { "SETTINGS_CAT_MAP", { "MinimapUI", "WorldMapUI", "QuestUI" } },
    { "SETTINGS_CAT_PANELS", { "Bags", "CharUI", "SpellUI", "ProfUI", "Tooltips", "SystemUI", "SpecialUI" } },
    { "SETTINGS_CAT_SOCIAL", { "Chat", "PartyUI", "SocialUI", "NPCUI", "TradeUI", "AuctionUI" } },
}
local labels = {
    Theme = "THEME", Locale = "LOCALE", Profile = "PROFILE", Grid = "GRID", Diagnostics = "DIAGNOSTICS",
    ActionBars = "ACTIONBARS", UnitFrames = "UNITFRAMES", CastBars = "CASTBARS", Auras = "AURAS", Nameplates = "NAMEPLATES",
    MinimapUI = "MINIMAPUI", WorldMapUI = "WORLDMAPUI", QuestUI = "QUESTUI",
    Bags = "BAGS", CharUI = "CHARUI", SpellUI = "SPELLUI", ProfUI = "PROFUI", Tooltips = "TOOLTIPS",
    SystemUI = "SYSTEMUI", SpecialUI = "SPECIALUI", Chat = "CHAT", PartyUI = "PARTYUI",
    SocialUI = "SOCIALUI", NPCUI = "NPCUI", TradeUI = "TRADEUI", AuctionUI = "AUCTIONUI",
}
local excluded = { Core = true, Settings = true, Media = true }
local categoryOf = {}
for i, category in ipairs(categories) do
    for _, name in ipairs(category[2]) do categoryOf[name] = i end
end

local frame, search, heading, sidebar, content, aboutView, footer, editButton, searchHint
local selectedCategory, currentModule, about, query = 1, nil, false, ""
local previousSearch, previousOffset
local tabs, tiles, pages, localized, paints = {}, {}, {}, {}, {}
local activePage
local render
local PALETTES = { "starblue", "teal", "amber", "amethyst", "rose", "moss", "graphite" }

local function moduleLabel(name)
    return labels[name] and L["SETTINGS_MOD_" .. labels[name]] or name
end

local function anchor(obj, parent, x, y)
    obj:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
end

local function place(obj, parent, x, y)
    if obj.ClearAllPoints then obj:ClearAllPoints() end
    anchor(obj, parent, x, y)
end

local function paint(texture, token)
    local color = Theme.Get(token)
    texture:SetColorTexture(color[1], color[2], color[3], color[4])
end

local function surface(parent, token)
    local texture = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    texture:SetAllPoints(parent)
    local function update() paint(texture, token) end
    paints[#paints + 1] = update
    update()
    return texture
end

local function copyText(parent, value, x, y, w, h, onEnter)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(w, h)
    anchor(box, parent, x, y)
    box:SetAutoFocus(false)
    if box.SetFontObject then box:SetFontObject(GameFontHighlight or "GameFontHighlight") end
    if box.SetTextInsets then box:SetTextInsets(8, 8, 0, 0) end
    box:SetText(value)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", onEnter or function(self) self:ClearFocus() end)
    surface(box, "color.surface-container-high")
    paints[#paints + 1] = function()
        local c = Theme.Get("color.on-surface")
        if box.SetTextColor then box:SetTextColor(c[1], c[2], c[3], c[4]) end
    end
    return box
end

local function text(parent, key, x, y, width, role)
    local fs = Widgets.Text(parent, L[key], role)
    anchor(fs, parent, x, y)
    if width then fs:SetWidth(width) end
    if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
    localized[#localized + 1] = function() fs:SetText(L[key]) end
    return fs
end

local function button(parent, key, x, y, width, height, action)
    local b = Widgets.Button(parent, L[key])
    b:SetSize(width, height)
    anchor(b, parent, x, y)
    b:SetScript("OnClick", action)
    localized[#localized + 1] = function() b.themedLabel:SetText(L[key]) end
    return b
end

local function selectedButton(parent, title, width, height, action)
    local b = Widgets.Button(parent, title)
    b:SetSize(width, height)
    b:SetScript("OnClick", action)
    local mark = b:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    mark:SetSize(width - 2, 2)
    local fill = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints(b)
    paints[#paints + 1] = function()
        paint(fill, "color.primary-container")
        paint(mark, "color.primary")
    end
    function b:SetSelected(value)
        local alpha = value and 1 or 0
        if fill.SetAlpha then fill:SetAlpha(alpha) end
        if mark.SetAlpha then mark:SetAlpha(alpha) end
    end
    b:SetSelected(false)
    return b
end

local function scrollView(parent, x, y, width, height, name)
    local scroll = CreateFrame("ScrollFrame", name, parent)
    anchor(scroll, parent, x, y)
    scroll:SetSize(width - 12, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - 12, height)
    if scroll.SetScrollChild then scroll:SetScrollChild(child) end

    local slider = CreateFrame("Slider", nil, parent)
    anchor(slider, parent, x + width - 8, y)
    slider:SetSize(8, height)
    surface(slider, "color.surface-container-high")
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(6, 44)
    if slider.SetOrientation then slider:SetOrientation("VERTICAL") end
    if slider.SetThumbTexture then slider:SetThumbTexture(thumb) end
    if slider.EnableMouse then slider:EnableMouse(true) end
    paints[#paints + 1] = function() paint(thumb, "color.outline") end

    local view = { frame = scroll, child = child, slider = slider, offset = 0, range = 0 }
    function view:SetOffset(offset, fromSlider)
        self.offset = math.max(0, math.min(self.range, offset))
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(self.offset) end
        if not fromSlider and slider.SetValue then slider:SetValue(self.range - self.offset) end
    end
    function view:SetHeight(size, offset)
        self.range = math.max(0, size - height)
        child:SetSize(width - 12, math.max(size, height))
        if slider.SetMinMaxValues then slider:SetMinMaxValues(0, math.max(1, self.range)) end
        thumb:SetSize(6, math.max(22, height * height / math.max(size, height)))
        if self.range > 0 then slider:Show() else slider:Hide() end
        self:SetOffset(offset or 0)
    end
    function view:SetShown(shown)
        if shown then scroll:Show() else scroll:Hide() end
        if shown and self.range > 0 then slider:Show() else slider:Hide() end
    end
    slider:SetScript("OnValueChanged", function(_, value) view:SetOffset(view.range - value, true) end)
    if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
    scroll:SetScript("OnMouseWheel", function(_, delta) view:SetOffset(view.offset - delta * 36) end)
    return view
end

function Settings.RegisterModulePanel(name, panel)
    if type(name) == "string" and type(panel) == "table" and type(panel.build) == "function" then
        panels[name] = panel
    end
end

local function buildTheme(host)
    text(host, "SETTINGS_PALETTE", 0, 0, 430, "title")
    local buttons = {}
    for i, name in ipairs(PALETTES) do
        local x, y = ((i - 1) % 2) * 231, 31 + math.floor((i - 1) / 2) * 46
        local b = selectedButton(host, "", 221, 38, function() Theme.SetPalette(name) end)
        anchor(b, host, x, y)
        local swatch = b:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(11, 11)
        swatch:SetPoint("LEFT", b, "LEFT", 12, 0)
        local color = Theme.GetPaletteColor(name)
        swatch:SetColorTexture(color[1], color[2], color[3], 1)
        buttons[i] = b
    end
    return function()
        local selected = Theme.GetPalette()
        for i, name in ipairs(PALETTES) do
            buttons[i].themedLabel:SetText(L["SETTINGS_PALETTE_" .. name])
            buttons[i]:SetSelected(selected == name)
        end
    end
end

local function buildLocale(host)
    text(host, "SETTINGS_LOCALE", 0, 0, 430, "title")
    local options = { { "auto", "SETTINGS_LOCALE_AUTO" }, { "zhCN", "SETTINGS_LANG_ZH" }, { "enUS", "SETTINGS_LANG_EN" } }
    local buttons = {}
    for i, option in ipairs(options) do
        local b = selectedButton(host, "", 450, 36, function() OpenUI.Locale.Set(option[1]) end)
        anchor(b, host, 0, 32 + (i - 1) * 44)
        buttons[i] = b
    end
    return function()
        for i, option in ipairs(options) do
            buttons[i].themedLabel:SetText(L[option[2]])
            buttons[i]:SetSelected(OpenUI.Locale.Get() == option[1])
        end
    end
end

local function buildDiagnostics(host)
    local count = Widgets.Text(host, "")
    anchor(count, host, 0, 0)
    button(host, "SETTINGS_DIAG_OPEN", 0, 32, 175, 32, function()
        if OpenUI.Diagnostics then OpenUI.Diagnostics.Open() end
    end)
    return function() count:SetText(L.SETTINGS_ERRORS_COUNT:format(#OpenUI.Diagnose.Errors())) end
end

local function buildProfiles(host)
    local profile = OpenUI.Profile
    local list = CreateFrame("Frame", nil, host)
    list:SetAllPoints(host)
    local confirm = CreateFrame("Frame", nil, host)
    confirm:SetAllPoints(host)
    confirm:Hide()
    local mode, pendingSlot, operation
    local current = Widgets.Text(list, "")
    anchor(current, list, 0, 23)
    local prompt = Widgets.Text(confirm, "", "title")
    anchor(prompt, confirm, 0, 12)
    prompt:SetWidth(450)
    local note = Widgets.Text(confirm, "")
    anchor(note, confirm, 0, 64)
    note:SetWidth(450)

    local function closePrompt()
        confirm:Hide()
        list:Show()
        pendingSlot, operation = nil, nil
    end
    local function apply(action)
        if not OpenUI:CanModifyNow() then return end
        if OpenUI.EditMode and OpenUI.EditMode.IsActive() then OpenUI.EditMode.Toggle() end
        local previous = {}
        for _, module in ipairs(OpenUI.moduleOrder) do
            previous[module.name] = OpenUI:IsModuleEnabled(module.name)
        end
        if not action() then return end
        closePrompt()
        Theme.Refresh()
        OpenUI.Locale.Refresh()
        OpenUI:RefreshProfileModules(previous)
        if OpenUI.Grid then OpenUI.Grid.RefreshProfile() end
        Settings.Refresh()
    end
    local copy = button(confirm, "SETTINGS_PROFILE_COPY", 0, 128, 166, 30, function()
        apply(function() return profile.UseIndependent({ copy = true }) end)
    end)
    local restore = button(confirm, "SETTINGS_PROFILE_RESTORE", 174, 128, 158, 30, function()
        apply(function() return profile.UseIndependent() end)
    end)
    local delete = button(confirm, "SETTINGS_PROFILE_DELETE", 0, 128, 166, 30, function()
        if operation == "delete" then apply(function() return profile.DeleteSlot(pendingSlot) end) end
    end)
    button(confirm, "SETTINGS_PROFILE_CANCEL", 340, 128, 110, 30, closePrompt)
    local function openPrompt(kind, slot)
        if not OpenUI:CanModifyNow() then return end
        pendingSlot, operation = slot, kind
        if kind == "delete" then
            prompt:SetText(L.SETTINGS_PROFILE_DELETE_TITLE:format(slot))
            note:SetText(L.SETTINGS_PROFILE_DELETE_NOTE)
            copy:Hide()
            restore:Hide()
            delete:Show()
        else
            prompt:SetText(L.SETTINGS_PROFILE_UNLINK_TITLE:format(slot))
            note:SetText(L.SETTINGS_PROFILE_UNLINK_NOTE)
            copy:Show()
            restore:Show()
            delete:Hide()
        end
        list:Hide()
        confirm:Show()
    end

    text(list, "SETTINGS_PROFILE_CHARACTER", 0, 0, 260, "title")
    local unlink = button(list, "SETTINGS_PROFILE_UNLINK", 310, 6, 140, 29, function()
        if mode and mode.slot then openPrompt("unlink", mode.slot) end
    end)
    text(list, "SETTINGS_PROFILE_ACCOUNT", 0, 53, 215, "title")
    text(list, "SETTINGS_PROFILE_SHARED_NOTE", 220, 55, 230)
    local rows = {}
    for i = 1, 5 do
        local slot = i
        local row = CreateFrame("Frame", nil, list)
        anchor(row, list, 0, 80 + (i - 1) * 36)
        row:SetSize(452, 32)
        surface(row, "color.surface-container-high")
        local name = Widgets.Text(row, "")
        local status = Widgets.Text(row, "")
        anchor(name, row, 9, 8)
        anchor(status, row, 156, 8)
        name:SetWidth(143)
        status:SetWidth(105)
        local use = Widgets.Button(row, "")
        anchor(use, row, 269, 3)
        use:SetSize(111, 26)
        use:SetScript("OnClick", function() apply(function() return profile.UseSlot(slot) end) end)
        local remove = button(row, "SETTINGS_PROFILE_DELETE", 385, 3, 64, 26, function()
            openPrompt("delete", slot)
        end)
        rows[i] = { name = name, status = status, use = use, remove = remove }
    end
    text(list, "SETTINGS_PROFILE_RELOAD", 0, 268, 445)
    return function()
        mode = profile.GetCurrent()
        current:SetText(mode.slot and L.SETTINGS_PROFILE_LINKED:format(mode.slot) or L.SETTINGS_PROFILE_INDEPENDENT)
        if mode.slot then unlink:Show() else unlink:Hide() end
        for i, slot in ipairs(profile.Slots()) do
            local row = rows[i]
            local selected = mode.slot == i
            row.name:SetText(L.SETTINGS_PROFILE_SLOT:format(i))
            row.status:SetText(selected and L.SETTINGS_PROFILE_ACTIVE
                or slot.used and L.SETTINGS_PROFILE_USED or L.SETTINGS_PROFILE_EMPTY)
            row.use.themedLabel:SetText(slot.used and L.SETTINGS_PROFILE_USE or L.SETTINGS_PROFILE_CREATE)
            if selected then row.use:Hide() else row.use:Show() end
            if slot.used then row.remove:Show() else row.remove:Hide() end
        end
    end, closePrompt
end

Settings.RegisterModulePanel("Theme", { build = buildTheme, height = 228 })
Settings.RegisterModulePanel("Locale", { build = buildLocale, height = 180 })
Settings.RegisterModulePanel("Diagnostics", { build = buildDiagnostics })
Settings.RegisterModulePanel("Profile", { build = buildProfiles, height = 300 })

local function buildAbout(parent)
    text(parent, "SETTINGS_ABOUT", 0, 0, 640, "title")
    text(parent, "SETTINGS_ABOUT_INTRO", 0, 38, 630)
    text(parent, "SETTINGS_ABOUT_START", 0, 111, 620, "title")
    text(parent, "SETTINGS_ABOUT_GUIDE", 0, 143, 630)
    text(parent, "SETTINGS_ABOUT_MEDIA", 0, 225, 620, "title")
    text(parent, "SETTINGS_ABOUT_BRIDGE", 0, 257, 630)
    text(parent, "SETTINGS_ABOUT_PROJECT", 0, 336, 620, "title")
    text(parent, "SETTINGS_ABOUT_AUTHOR", 0, 365, 620)
    local links = {
        { "SETTINGS_ABOUT_CONTACT", "askdaddy@gmail.com" },
        { "SETTINGS_ABOUT_REPO", "https://github.com/askdaddy/OpenUI" },
        { "SETTINGS_ABOUT_ISSUES", "https://github.com/askdaddy/OpenUI/issues" },
    }
    for i, entry in ipairs(links) do
        local y = 392 + (i - 1) * 37
        text(parent, entry[1], 0, y + 7, 138)
        local value = entry[2]
        local box = copyText(parent, value, 145, y, 490, 30)
        box:SetScript("OnEditFocusGained", function(self) if self.HighlightText then self:HighlightText() end end)
        box:SetScript("OnTextChanged", function(self, userInput)
            if userInput and self:GetText() ~= value then
                self:SetText(value)
                if self.HighlightText then self:HighlightText() end
            end
        end)
    end
    text(parent, "SETTINGS_ABOUT_COPY", 145, 509, 490)
    return 536
end

local function pageFor(name)
    if pages[name] then return pages[name] end
    local panel = panels[name]
    local host = CreateFrame("Frame", nil, content.child)
    host:SetSize(460, (panel and panel.height) or 220)
    anchor(host, content.child, 0, 56)
    local page = { host = host, size = ((panel and panel.height) or 220) + 62 }
    if panel then
        page.refresh, page.reset = panel.build(host)
    else
        text(host, "SETTINGS_MODULE_NO_OPTIONS", 0, 0, 450)
    end
    pages[name] = page
    return page
end

local function selectModule(name)
    if not name or not OpenUI.modules[name] or excluded[name] then return end
    currentModule = name
    selectedCategory = categoryOf[name] or 4
    render(true)
end

local function matches(name, category)
    return query == "" or moduleLabel(name):lower():find(query, 1, true)
        or L[categories[category][1]]:lower():find(query, 1, true)
end

local function results(category)
    local result = {}
    for _, name in ipairs(categories[category][2]) do
        if OpenUI.modules[name] and matches(name, category) then result[#result + 1] = name end
    end
    if category == 4 then
        for _, mod in ipairs(OpenUI.moduleOrder) do
            local name = mod.name
            if not categoryOf[name] and not excluded[name] and matches(name, category) then
                result[#result + 1] = name
            end
        end
    end
    return result
end

local function selectCategory(index)
    local names = results(index)
    if #names > 0 then
        selectModule(names[1])
    else
        selectedCategory, currentModule = index, nil
        render(true)
    end
end

local function addTile(name)
    local b = selectedButton(sidebar.child, moduleLabel(name), 164, 35, function() selectModule(name) end)
    if b.themedLabel.ClearAllPoints then b.themedLabel:ClearAllPoints() end
    b.themedLabel:SetPoint("LEFT", b, "LEFT", 9, 0)
    local dot
    if not OpenUI.modules[name].alwaysEnabled then
        dot = Widgets.Text(b, "")
        dot:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    end
    local tile = { button = b, dot = dot }
    tiles[name] = tile
    return tile
end

local function refreshChrome()
    for _, apply in ipairs(paints) do apply() end
    for _, tile in pairs(tiles) do
        if tile.dot then
            local name = tile.name
            local enabled = OpenUI:IsModuleEnabled(name)
            local c = Theme.Get(enabled and "color.primary" or "color.on-surface-variant")
            tile.dot:SetText(enabled and "●" or "○")
            tile.dot:SetTextColor(c[1], c[2], c[3], c[4])
        end
    end
    if activePage and activePage.refresh then activePage.refresh() end
end

local moduleSwitch, aboutTabs, normalTabs, sideSurface
render = function(resetScroll)
    if not frame then return end
    local offset = resetScroll and 0 or content.offset
    if about then
        normalTabs:Hide()
        aboutTabs:Show()
        search:Hide()
        searchHint:Hide()
        editButton:Hide()
        sideSurface:Hide()
        sidebar:SetShown(false)
        content:SetShown(false)
        aboutView:SetShown(true)
        footer:Hide()
        return
    end
    normalTabs:Show()
    aboutTabs:Hide()
    search:Show()
    if query == "" and not (search.HasFocus and search:HasFocus()) then searchHint:Show()
    else searchHint:Hide() end
    editButton:Show()
    sideSurface:Show()
    sidebar:SetShown(true)
    content:SetShown(true)
    aboutView:SetShown(false)
    footer:Show()
    for i, tab in ipairs(tabs) do
        tab.themedLabel:SetText(L[categories[i][1]])
        tab:SetSelected(i == selectedCategory)
    end
    for _, tile in pairs(tiles) do tile.button:Hide() end
    local visible = results(selectedCategory)
    for i, name in ipairs(visible) do
        local tile = tiles[name] or addTile(name)
        tile.name = name
        tile.button.themedLabel:SetText(moduleLabel(name))
        place(tile.button, sidebar.child, 0, (i - 1) * 42)
        tile.button:SetSelected(name == currentModule)
        tile.button:Show()
    end
    sidebar:SetHeight(#visible * 42)
    local nextPage = currentModule and pageFor(currentModule)
    if activePage and activePage ~= nextPage then
        if activePage.reset then activePage.reset() end
        activePage.host:Hide()
    end
    activePage = nextPage
    heading:SetText(currentModule and moduleLabel(currentModule) or L.SETTINGS_NO_RESULTS)
    if currentModule and not OpenUI.modules[currentModule].alwaysEnabled then moduleSwitch:Show()
    else moduleSwitch:Hide() end
    if activePage then activePage.host:Show() end
    content:SetHeight(activePage and activePage.size or 0, offset)
    refreshChrome()
    Widgets.Refresh()
end

local function openAbout()
    previousOffset = content.offset
    if search.ClearFocus then search:ClearFocus() end
    about = true
    aboutView:SetHeight(aboutView.bodyHeight)
    render()
end

function Settings.ReturnFromAbout()
    if not about then return end
    about = false
    render()
    content:SetOffset(previousOffset or 0)
end

local function build()
    if frame then return end
    frame = Widgets.Panel(UIParent, { name = "OpenUISettings" })
    frame:SetSize(700, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local header = CreateFrame("Frame", nil, frame)
    anchor(header, frame, 1, 1)
    header:SetSize(698, 108)
    surface(header, "color.surface-container-high")
    text(header, "SETTINGS_TITLE", 19, 17, 195, "title")
    button(header, "SETTINGS_CLOSE_SHORT", 640, 16, 39, 34, function() Settings.Close() end)
    editButton = button(header, "SETTINGS_EDIT_MODE", 512, 16, 112, 34, function()
        if OpenUI.EditMode then OpenUI.EditMode.Toggle() end
        Settings.Refresh()
    end)
    search = copyText(header, "", 220, 16, 280, 34)
    searchHint = text(search, "SETTINGS_SEARCH", 8, 8, 260)
    search:SetScript("OnTextChanged", function(self) Settings.ApplyFilter(self:GetText()) end)
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function() if query == "" then searchHint:Show() end end)

    normalTabs = CreateFrame("Frame", nil, header)
    normalTabs:SetAllPoints(header)
    for i, category in ipairs(categories) do
        local index = i
        local tab = selectedButton(normalTabs, L[category[1]], 123, 41, function() selectCategory(index) end)
        anchor(tab, normalTabs, 20 + (i - 1) * 132, 67)
        tabs[i] = tab
    end
    aboutTabs = CreateFrame("Frame", nil, header)
    aboutTabs:SetAllPoints(header)
    local tab = selectedButton(aboutTabs, "", 143, 41, nil)
    anchor(tab, aboutTabs, 20, 67)
    tab:SetSelected(true)
    localized[#localized + 1] = function() tab.themedLabel:SetText(L.SETTINGS_ABOUT) end
    button(aboutTabs, "SETTINGS_ABOUT_RETURN", 175, 67, 90, 41, Settings.ReturnFromAbout)

    sideSurface = CreateFrame("Frame", nil, frame)
    anchor(sideSurface, frame, 1, 110)
    sideSurface:SetSize(192, 370)
    surface(sideSurface, "color.surface-container-low")
    sidebar = scrollView(sideSurface, 11, 13, 180, 344, "OpenUISettingsModules")
    content = scrollView(frame, 216, 125, 480, 341, "OpenUISettingsContent")
    local rule = content.child:CreateTexture(nil, "ARTWORK")
    anchor(rule, content.child, 0, 46)
    rule:SetSize(462, 1)
    paints[#paints + 1] = function() paint(rule, "color.outline-variant") end
    heading = Widgets.Text(content.child, "", "title")
    anchor(heading, content.child, 0, 4)
    moduleSwitch = Widgets.Toggle(content.child, "SETTINGS_MODULE_TOGGLE",
        function() return currentModule and OpenUI:IsModuleEnabled(currentModule) end,
        function(want)
            if not currentModule then return end
            if want then OpenUI:EnableModule(currentModule) else OpenUI:DisableModule(currentModule) end
            refreshChrome()
        end)
    anchor(moduleSwitch, content.child, 328, 0)
    moduleSwitch:SetSize(126, 29)
    aboutView = scrollView(frame, 24, 125, 672, 341, "OpenUISettingsAbout")
    aboutView.bodyHeight = buildAbout(aboutView.child)

    local bottom = CreateFrame("Frame", nil, frame)
    anchor(bottom, frame, 1, 480)
    bottom:SetSize(698, 39)
    surface(bottom, "color.surface-container-high")
    text(bottom, "SETTINGS_HINT", 19, 11, 400)
    footer = button(bottom, "SETTINGS_ABOUT", 550, 5, 128, 29, openAbout)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "OpenUISettings") end
    Theme.RegisterRefresh(refreshChrome)
    for _, update in ipairs(localized) do update() end
    selectCategory(1)
end

function Settings.OpenModule(name)
    build()
    frame:Show()
    if about then Settings.ReturnFromAbout() end
    selectModule(name)
end

function Settings.CloseModule()
    if activePage and activePage.reset then activePage.reset() end
    currentModule = nil
    render(true)
end

function Settings.Open()
    build()
    frame:Show()
    render()
end

function Settings.Close()
    if not frame then return end
    Settings.ReturnFromAbout()
    if activePage and activePage.reset then activePage.reset() end
    frame:Hide()
end

function Settings.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Settings.ApplyFilter(value)
    local nextQuery = (value or ""):lower()
    if nextQuery == query then return end
    if not frame then build() end
    if not about and query == "" then previousSearch = { selectedCategory, currentModule } end
    query = nextQuery
    if query == "" and previousSearch then
        selectedCategory, currentModule = previousSearch[1], previousSearch[2]
        previousSearch = nil
    elseif currentModule == nil or not matches(currentModule, selectedCategory) then
        local hits = results(selectedCategory)
        if #hits > 0 then
            currentModule = hits[1]
        else
            currentModule = nil
            for index in ipairs(categories) do
                local names = results(index)
                if #names > 0 then selectedCategory, currentModule = index, names[1]; break end
            end
        end
    end
    render(true)
end

function Settings.Refresh()
    if not frame then return end
    for _, update in ipairs(localized) do update() end
    local marker = OpenUI.EditMode and OpenUI.EditMode.IsActive() and "● " or ""
    editButton.themedLabel:SetText(marker .. L.SETTINGS_EDIT_MODE)
    render()
end

Settings.IsModuleWindowShown = function() return Settings.IsOpen() and not about and currentModule ~= nil end
Settings.CurrentModule = function() return currentModule end
Settings.Tile = function(name) return tiles[name] end
Settings.ContentHeight = function() return content and content.range + 341 or 0 end
OpenUI.Settings = Settings
OpenUI:RegisterModule("Settings", { alwaysEnabled = true })
