-- 主题最小挂点（spec C8）：共享颜色/字体常量与访问器。
-- 取值为骨架占位；正式扁平暗色预设属"主题与控件"模块（D05 细节待讨论）。

local _, ns = ...
local OpenUI = ns.OpenUI

local colors = {
    bg = { 0.09, 0.09, 0.11, 1 },
    panel = { 0.13, 0.13, 0.16, 1 },
    border = { 0.24, 0.24, 0.28, 1 },
    text = { 0.92, 0.92, 0.94, 1 },
    accent = { 0.20, 0.56, 0.85, 1 },
    warn = { 0.92, 0.60, 0.10, 1 },
}

local fonts = {
    normal = "GameFontNormal",
    header = "GameFontNormalLarge",
}

OpenUI.Theme = {
    colors = colors,
    fonts = fonts,
    GetColor = function(name)
        return colors[name]
    end,
    GetFont = function(name)
        return fonts[name]
    end,
}
