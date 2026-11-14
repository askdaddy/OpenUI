-- 最小控件工厂（#7）：Panel/Button/Text 主题化基础件，供设置/动作条/聊天等消费模块增量扩展。
-- 全部读取当前主题 token；Set/SetPalette/rebuild 后经 Widgets.Refresh() 原地换色。
-- 不做动画引擎、不做列表/输入框（消费模块票增量）。

local _, ns = ...
local OpenUI = ns.OpenUI
local Theme = OpenUI.Theme

local Widgets = {}
local instances = {}

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

-- Panel(parent, { module = ?, }) -> Frame（背景=surface-container × opacity.panel）
function Widgets.Panel(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, parent)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    local inst = { bg = bg, moduleName = opts.module, apply = panelApply }
    instances[#instances + 1] = inst
    inst:apply()
    return frame
end

local function buttonApply(self)
    panelApply(self)
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
    -- 运行时切换禁用：门控状态层与文本透明度
    function button:SetThemedEnabled(enabled)
        inst.disabled = not enabled
        inst.stateAlpha = 0
        inst:apply()
    end
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
end

OpenUI.Widgets = Widgets