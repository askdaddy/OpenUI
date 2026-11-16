-- 最小控件工厂（#7）：Panel/Button/Text 主题化基础件，供设置/动作条/聊天等消费模块增量扩展。
-- 全部读取当前主题 token；Set/SetPalette/rebuild 后经 Widgets.Refresh() 原地换色。
-- 不做动画引擎、不做列表/输入框（消费模块票增量）。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme
local L = OpenUI.L

local Widgets = {}
local instances = {}

-- ==== 装饰（#48）：1px 细边框 + 顶部渐亮 sheen + 半透明底 ====
local function edgeTexture(frame, x1, y1, x2, y2, color, alpha)
    local t = frame:CreateTexture(nil, "BORDER")
    if type(t.SetColorTexture) == "function" then
        t:SetColorTexture(color[1], color[2], color[3], alpha)
    end
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", x1, y1)
    t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", x2, y2)
    return t
end

-- 顶层装饰实例随 Refresh 换色
local decorated = {}

local function decorate(frame, kind)
    local border = Theme.Get("color.outline-variant")
    local alpha = kind == "panel" and 0.85 or 0.6
    local edges = {
        edgeTexture(frame, 0, 0, 0, -1, border, alpha),   -- 上
        edgeTexture(frame, 0, 1, 0, 0, border, alpha),    -- 下
        edgeTexture(frame, 0, 0, 1, 0, border, alpha),    -- 左
        edgeTexture(frame, -1, 0, 0, 0, border, alpha),   -- 右
    }
    local sheen
    if kind == "panel" and type(CreateColor) == "function" then
        sheen = frame:CreateTexture(nil, "ARTWORK")
        sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        sheen:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        if type(sheen.SetGradient) == "function" then
            local top = Theme.Get("color.surface-container-highest")
            sheen:SetGradient("VERTICAL",
                CreateColor(top[1], top[2], top[3], 0.12),
                CreateColor(top[1], top[2], top[3], 0))
        else
            sheen:Hide()
        end
    end
    decorated[#decorated + 1] = { frame = frame, edges = edges, sheen = sheen, kind = kind }
end



local function get(token, moduleName)
    if moduleName then return Theme.GetFor(moduleName, token) end
    return Theme.Get(token)
end

local function setColor(texture, token, moduleName, alphaOverride)
    local c = get(token, moduleName)
    if type(c) ~= "table" then return end
    texture:SetColorTexture(c[1], c[2], c[3], alphaOverride or c[4])
end

local function panelApply(self)
    setColor(self.bg, "color.surface-container", self.moduleName,
        get("opacity.panel", self.moduleName))
end

-- Panel(parent, { module = ?, name = ? }) -> Frame（背景=surface-container × opacity.panel）
function Widgets.Panel(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", opts.name, parent)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
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
    local bg = button:CreateTexture(nil, "BACKGROUND")
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
    local border = Theme.Get("color.outline-variant")
    local top = Theme.Get("color.surface-container-highest")
    for i = 1, #decorated do
        local d = decorated[i]
        local alpha = d.kind == "panel" and 0.85 or 0.6
        for _, edge in ipairs(d.edges) do
            if type(edge.SetColorTexture) == "function" then
                edge:SetColorTexture(border[1], border[2], border[3], alpha)
            end
        end
        if d.sheen and type(d.sheen.SetGradient) == "function" and type(CreateColor) == "function" then
            d.sheen:SetGradient("VERTICAL",
                CreateColor(top[1], top[2], top[3], 0.12),
                CreateColor(top[1], top[2], top[3], 0))
        end
    end
end

-- Toggle(parent, label, getState, setState, { module = ? }) -> Button
-- 开/关两态控件（#8）：点击切换，文本随 L 即时刷新。
function Widgets.Toggle(parent, label, getState, setState, opts)
    opts = opts or {}
    local button = CreateFrame("Button", nil, parent)
    local bg = button:CreateTexture(nil, "BACKGROUND")
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

OpenUI.Widgets = Widgets