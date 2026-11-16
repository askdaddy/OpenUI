-- 最小控件工厂（#7）：Panel/Button/Text 主题化基础件，供设置/动作条/聊天等消费模块增量扩展。
-- 全部读取当前主题 token；Set/SetPalette/rebuild 后经 Widgets.Refresh() 原地换色。
-- 不做动画引擎、不做列表/输入框（消费模块票增量）。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local L = OpenUI.L

local Widgets = {}
local instances = {}
local movers = {}

-- #57：撤回 Backdrop 方案（Forever 客户端仅 edgeFile 的 Backdrop 会以白底填充，覆盖深色纹理）。
-- 边框统一走已验证的 4 边纹理方案。API 保留返回 false 以兼容。
Widgets.HasBackdrop = function() return false end

-- #55：垂直渐变填充（上亮下暗；ElvUI gloss 状态条贴图的等价物，纯内置）
function Widgets.GradientFill(texture, color)
    if type(texture) ~= "table" or type(color) ~= "table" then return false end
    if type(texture.SetGradient) ~= "function" or type(CreateColor) ~= "function" then
        if type(texture.SetColorTexture) == "function" then
            texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        end
        return false
    end
    local function shade(mult)
        return CreateColor(
            math.min(color[1] * mult, 1),
            math.min(color[2] * mult, 1),
            math.min(color[3] * mult, 1),
            color[4] or 1)
    end
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
    texture:SetGradient("VERTICAL", shade(1.35), shade(0.55))
    return true
end


-- ==== 装饰（#48）：1px 细边框 + 顶部渐亮 sheen + 半透明底 ====
local function activeConfig()
    if OpenUI.Profile and OpenUI.Profile.Config then
        local cfg = OpenUI.Profile.Config()
        if type(cfg) == "table" then return cfg end
    end
    if type(_G.OpenUIDB) ~= "table" then _G.OpenUIDB = {} end
    return _G.OpenUIDB
end

-- #50：统一 Alt+左键拖拽助手（脱战；位置持久化到生效配置档）。
-- section/key 为配置节点；point 为缺省锚点（可选，nil 表示不重锚）。
function Widgets.MakeDraggable(frame, section, key, point)
    if type(frame) ~= "table" then return end
    movers[#movers + 1] = { frame = frame, section = section, key = key }
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local alt = type(IsAltKeyDown) == "function" and IsAltKeyDown()
        local editing = OpenUI.EditMode and OpenUI.EditMode.IsActive and OpenUI.EditMode.IsActive()
        if (alt or editing) and OpenUI:CanModifyNow() then
            self:StartMoving()
            if OpenUI.Grid and type(OpenUI.Grid.NotifyDragStart) == "function" then
                OpenUI.Grid.NotifyDragStart()
            end
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if type(self.GetLeft) ~= "function" then return end
        local x, y = self:GetLeft(), self:GetBottom()
        local G = OpenUI.Grid
        if G and type(G.IsShown) == "function" and G.IsShown() and type(G.Snap) == "function" then
            local sx, sy = G.Snap(x, y)
            if type(sx) == "number" and type(sy) == "number" and (sx ~= x or sy ~= y) then
                if type(self.ClearAllPoints) == "function" then self:ClearAllPoints() end
                self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", sx, sy)
                x, y = sx, sy
            end
        end
        local cfg = activeConfig()
        if type(cfg[section]) ~= "table" then cfg[section] = {} end
        cfg[section][key] = { x = x, y = y }
        if OpenUI.Grid and type(OpenUI.Grid.NotifyDragEnd) == "function" then
            OpenUI.Grid.NotifyDragEnd()
        end
    end)
    local cfg = activeConfig()
    local saved = type(cfg[section]) == "table" and cfg[section][key]
    if type(saved) == "table" and saved.x and saved.y then
        if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y)
    elseif point then
        if type(frame.ClearAllPoints) == "function" then frame:ClearAllPoints() end
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    end
end

-- #69：1px 边线（每边两点锚定 + SetHeight/SetWidth；修正旧实现"下边"生成全框薄膜的错误）
function Widgets.Edge(frame, side, color, alpha, anchor)
    if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" or type(color) ~= "table" then
        return nil
    end
    anchor = anchor or frame
    local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    if type(t.SetColorTexture) == "function" then
        t:SetColorTexture(color[1], color[2], color[3], alpha)
    end
    if side == "top" then
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
        if type(t.SetHeight) == "function" then t:SetHeight(1) end
    elseif side == "bottom" then
        t:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
        t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
        if type(t.SetHeight) == "function" then t:SetHeight(1) end
    elseif side == "left" then
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        t:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
        if type(t.SetWidth) == "function" then t:SetWidth(1) end
    elseif side == "right" then
        t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
        t:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
        if type(t.SetWidth) == "function" then t:SetWidth(1) end
    end
    return t
end

local function edgeTexture(frame, side, color, alpha)
    return Widgets.Edge(frame, side, color, alpha)
end

-- 顶层装饰实例随 Refresh 换色
local decorated = {}

local function decorate(frame, kind)
    local border = Theme.Get("color.outline")
    local alpha = kind == "panel" and 0.95 or 0.8
    local edges = {
        edgeTexture(frame, "top", border, alpha),
        edgeTexture(frame, "bottom", border, alpha),
        edgeTexture(frame, "left", border, alpha),
        edgeTexture(frame, "right", border, alpha),
    }
    -- #58：移除通体 sheen 渐变与顶部亮带（Forever 客户端渲染成白纱覆盖深色底）
    decorated[#decorated + 1] = { frame = frame, edges = edges, kind = kind }
end



local function get(token, moduleName)
    if moduleName then return Theme.GetFor(moduleName, token) end
    return Theme.Get(token)
end

local function setColor(texture, token, moduleName, alphaOverride)
    local c = get(token, moduleName)
    if type(c) ~= "table" then return end
    local alpha = alphaOverride or c[4]
    texture:SetColorTexture(c[1], c[2], c[3], alpha)
    -- #58：记录实际下发的颜色，供 /openui probe 客户端自证
    texture.openuiLastColor = { c[1], c[2], c[3], alpha }
end

local function panelApply(self)
    setColor(self.bg, "color.surface-container", self.moduleName,
        get("opacity.panel", self.moduleName))
end

-- Panel(parent, { module = ?, name = ? }) -> Frame（背景=surface-container × opacity.panel）
function Widgets.Panel(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", opts.name, parent)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(frame)
    local inst = { bg = bg, moduleName = opts.module, apply = panelApply }
    instances[#instances + 1] = inst
    inst:apply()
    decorate(frame, "panel")
    return frame
end

local function buttonApply(self)
    setColor(self.bg, "color.surface-container-high", self.moduleName,
        get("opacity.panel", self.moduleName))
    setColor(self.overlay, "color.on-surface", self.moduleName, self.stateAlpha or 0)
    local fg = get("color.on-surface", self.moduleName)
    if type(fg) == "table" then
        self.label:SetTextColor(fg[1], fg[2], fg[3], fg[4])
    end
    if self.disabled then
        self.label:SetAlpha(1 - get("state.disabled", self.moduleName))
    else
        self.label:SetAlpha(1)
    end
end

-- Button(parent, label, { module = ? }) -> Button（状态层：hover/pressed/disabled）
function Widgets.Button(parent, label, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent)
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(button)
    local overlay = button:CreateTexture(nil, "ARTWORK")
    overlay:SetAllPoints(button)
    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", button, "CENTER", 0, 0)
    fs:SetText(label or "")
    local inst = {
        bg = bg, overlay = overlay, label = fs,
        moduleName = opts.module, stateAlpha = 0, disabled = false,
        apply = buttonApply,
    }
    button:SetScript("OnEnter", function()
        if inst.disabled then return end
        inst.stateAlpha = get("state.hover", inst.moduleName)
        inst:apply()
    end)
    button:SetScript("OnLeave", function()
        inst.stateAlpha = 0
        inst:apply()
    end)
    button:SetScript("OnMouseDown", function()
        if inst.disabled then return end
        inst.stateAlpha = get("state.pressed", inst.moduleName)
        inst:apply()
    end)
    button:SetScript("OnMouseUp", function()
        if inst.disabled then return end
        inst.stateAlpha = get("state.hover", inst.moduleName)
        inst:apply()
    end)
    instances[#instances + 1] = inst
    inst:apply()
    decorate(button, "button")
    -- 运行时切换禁用：门控状态层与文本透明度
    function button:SetThemedEnabled(enabled)
        inst.disabled = not enabled
        inst.stateAlpha = 0
        inst:apply()
    end
    button.themedLabel = fs
    return button
end

local function textApply(self)
    local token = Theme.Get("type." .. self.role)
    if type(token) == "table" and token.file then
        self.fontString:SetFont(token.file, token.size, token.flags)
    end
end

-- Text(parent, text, role?) -> FontString（role 默认 body；file=nil 时继承创建模板字体）
function Widgets.Text(parent, text, role)
    local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- #58：显式文字颜色（此前继承 GameFontNormal 的默认金色）
    local textColor = Theme.Get("color.on-surface")
    if type(fontString.SetTextColor) == "function" and type(textColor) == "table" then
        fontString:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
    end
    if type(fontString.SetShadowOffset) == "function" then
        fontString:SetShadowOffset(1, -1)
        if type(fontString.SetShadowColor) == "function" then
            fontString:SetShadowColor(0, 0, 0, 0.9)
        end
    end
    fontString:SetText(text or "")
    local inst = { fontString = fontString, role = role or "body", apply = textApply }
    instances[#instances + 1] = inst
    inst:apply()
    return fontString
end

-- 重新读取主题并原地换色（Theme rebuild 后自动调用）。
function Widgets.Refresh()
    for i = 1, #instances do
        instances[i]:apply()
    end
    local border = Theme.Get("color.outline")
    local top = Theme.Get("color.surface-container-highest")
    for i = 1, #decorated do
        local d = decorated[i]
        local alpha = d.kind == "panel" and 0.95 or 0.8
        for _, edge in ipairs(d.edges) do
            if type(edge.SetColorTexture) == "function" then
                edge:SetColorTexture(border[1], border[2], border[3], alpha)
            end
        end
    end
end

-- Toggle(parent, label, getState, setState, { module = ? }) -> Button
-- 开/关两态控件（#8）：点击切换，文本随 L 即时刷新。
function Widgets.Toggle(parent, label, getState, setState, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent)
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints(button)
    local overlay = button:CreateTexture(nil, "ARTWORK")
    overlay:SetAllPoints(button)
    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", button, "CENTER", 0, 0)
    local inst = {
        bg = bg, overlay = overlay, label = fs, moduleName = opts.module,
        stateAlpha = 0, disabled = false, apply = buttonApply,
        labelText = label, getState = getState, setState = setState,
    }
    function inst:refreshText()
        local state = self.getState and self.getState() and true or false
        self.label:SetText((L[self.labelText] or self.labelText)
            .. ": " .. (state and L.SETTINGS_ON or L.SETTINGS_OFF))
    end
    local applyBase = inst.apply
    inst.apply = function(self)
        applyBase(self)
        inst:refreshText()
    end
    button:SetScript("OnEnter", function()
        if inst.disabled then return end
        inst.stateAlpha = get("state.hover", inst.moduleName)
        inst:apply()
    end)
    button:SetScript("OnLeave", function()
        inst.stateAlpha = 0
        inst:apply()
    end)
    button:SetScript("OnMouseDown", function()
        if inst.disabled then return end
        inst.stateAlpha = get("state.pressed", inst.moduleName)
        inst:apply()
    end)
    button:SetScript("OnMouseUp", function()
        if inst.disabled then return end
        inst.stateAlpha = get("state.hover", inst.moduleName)
        inst:apply()
    end)
    button:SetScript("OnClick", function()
        if inst.setState then inst.setState(not (inst.getState and inst.getState())) end
        inst:apply()
    end)
    instances[#instances + 1] = inst
    inst:apply()
    decorate(button, "button")
    button.themedLabel = fs
    return button
end

function Widgets.Movers()
    return movers
end

-- #58：客户端自证——实例数量与首个面板实际下发颜色
function Widgets.DebugInfo()
    local info = "widgets=" .. #instances
    local first = instances[1]
    if first and first.bg and first.bg.openuiLastColor then
        local c = first.bg.openuiLastColor
        info = info .. (" first-bg=%.3f/%.3f/%.3f/%.2f"):format(c[1], c[2], c[3], c[4])
    end
    return info
end

OpenUI.Widgets = Widgets