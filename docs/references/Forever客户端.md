# Forever 客户端与资料

[返回 README](../../README.md) · [规划](../planning/项目规划.md) · [待决策](../planning/决策记录.md)

核查日期：2026-11-12。本文记录环境证据与资料适用范围，不将外部资料视为当前构建的实测结论。

## 本机环境

- 用户提供版本：`1.60.1.70888`。
- 安装根目录：`/Applications/World of Warcraft`。
- 已观察到客户端目录：`/Applications/World of Warcraft/_forever_`。
- 已观察到应用：`_forever_/World of Warcraft.app`，以及 `Interface` 目录。
- 应用 `Contents/Info.plist` 实际读取结果：`CFBundleShortVersionString=1.60.1`、`CFBundleVersion=1.60.1.70888`，与用户提供的版本一致。
- 本轮仅只读检查文件系统，没有启动游戏、安装插件、改动游戏配置或运行 API 探针。
- 当前构建的 Interface 版本、API 可用性、受保护操作和战斗行为仍需核实；不能从游戏版本号推定全部能力。

## 找到的第一手研究资料

| 来源 | 证据与用途 | 限制 |
| --- | --- | --- |
| [Atraeau / WoW-Addons API Reference](https://github.com/Atraeau/WoW-Addons/blob/main/docs/api/README.md) | 作者注明由客户端 APIDocumentation 生成，来源 build 70790、interface 16001，生成日期 2026-11-05；可作为查找接口签名的入口 | 并非本机 70888 构建；已声明接口不等于对应场景运行成功 |
| [Thunderz96 / forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) | 作者记录测试服 1.60.1.69893 的实际测量，提供 API 基线与移植研究 | README 明确为早期快照，最后更新 2026-09-24，部分问题在后续构建已修复；仅作历史线索 |

以上为第三方作者直接生成或测量的材料，不是 Blizzard 对当前构建的官方兼容承诺。尚未取得可确认匹配 70888 的完整官方 API 资料。

## 待研究事项

- 找到匹配当前构建的客户端 UI 源码或 APIDocumentation，记录构建和来源。
- 分模块核查容器、动作条、名牌、地图、任务、聊天、窗口与天赋接口。
- 区分接口存在、参数可用、战斗可用、受保护操作及真实数据可用。
- 在获准进入实现与测试阶段后，再进行游戏内验证；目前不编写探针代码。

## 2026-11-16 游戏内实测记录（B0+B1 验收期间）

以下为在本机 1.60.1.70888 上通过 `/openui probe` 差分测试与用户截图确证的事实，作为后续实现的硬约束。

### Secret Values 已启用

- `UnitHealth` 等战斗/单位数值在插件（tainted）上下文中为**秘密值**，直接算术或 `string.format` 会抛错：
  `attempt to perform arithmetic on local 'hp' (a secret number value, while execution tainted by 'OpenUI')`。
- 对策：所有数值消费路径使用 `OpenUI.Try(fn, fallback)`（pcall 封装）降级，失败时显示空文本/静态条/隐藏槽；秘密字符串（单位名、图标路径）传给 SetText/SetTexture 同样需要 pcall。

### 纹理渲染

- `Texture:SetColorTexture(r,g,b,a)` 四参可用；`SetTexture(WHITE8X8)+SetVertexColor` 亦可用；BACKGROUND/BORDER/ARTWORK/HIGHLIGHT/OVERLAY 各层均可正常着色（五图层红条实证）。
- `CreateTexture(name, layer, template, subLevel)` 的第四参为子层级；ForeverUI 参考实现使用 `BACKGROUND, nil, -8` 作填充、`OVERLAY, nil, 7` 作描边。
- **不要使用 SetBackdrop/BackdropTemplate**：仅 edgeFile 的 Backdrop 在客户端会以默认白底填充（参考实现 ForeverUI 亦明确回避）。
- 1px 边线必须"每边两点锚定 + SetHeight/SetWidth(1)"；用 TOPLEFT/BOTTOMRIGHT 对角锚点构造边线极易生成覆盖整框的薄膜（本项目踩坑记录，见 CHANGES #69）。

### 帧与接口可用性（实测）

- `PlayerFrame`、`TargetFrame`、`MultiBar5/6/7`、`MultiBarBottomLeft/Right`、`MultiBarLeft/Right`、`PetActionBar` 存在且可被重新挂父隐藏。
- `PlayerCastingBarFrame` 存在（现代命名）；`CastingBarFrame` 不存在。
- `MainMenuBar` 全局不存在（原生主条使用未定位的帧名；`LoadAddOn("Blizzard_ActionBar")` 无效）。
- `GetActionTexture(slot)` 返回**文件 ID 数字**（如 133052），可直接传给 `SetTexture`；`GetActionBarPage`、`C_ActionBar` 存在。
- 界面模块启用时需隐藏对应原生帧；Native 助手按模块记账，并以 ADDON_LOADED / PLAYER_ENTERING_WORLD / 脱战 + 登录后 1s/3s/6s 重试覆盖懒加载与大厅重挂。

### 原生 UI 接管策略（2026-11-17 研究结论）

- **ElvUI**：复用暴雪动作按钮（SetParent 到自有条），再把条壳帧 `SetParent(HiddenFrame)` + `UnregisterAllEvents`；帧名线索 `MainActionBar`、`MicroButtonAndBagsBar`、`StatusTrackingBarManager:Kill()`。
- **ForeverUI（本客户端实证，含 2026-09-26 故障记录）**：**受保护帧与 Edit Mode 管理帧绝不 Hide 或换父**——其 OnHide 会污染 Edit Mode 管理表，Forever 布局 pass 随后读取光环数据崩溃；目标的目标 OnHide 会重配目标框光环容器，导致 `CompactUnitFrame ... secret number value ... tainted`。做法是就地"Conceal"：`SetAlpha(≈0)` + `EnableMouse(false)` + `UnregisterAllEvents`；仅普通帧才 Hide + SetParent(hidden)。其源码明言隐藏"需要 /reload 才能撤销"。
- **OpenUI 采用**（Native v3，#70）：`IsProtected()` / `isManagedFrame` 帧 → 淡化 alpha=0.0001 + 禁鼠标（可逆恢复，不解注册事件以保证运行时开关可恢复）；普通帧维持 Hide+SetParent；`/openui probe` 以 `(fade)/(hidden)` 标注模式。原生动作条帧名清单以 ForeverUI 的清单为事实来源（多版本别名并存、缺失跳过）。
- 已知限制：若某帧被归类为普通帧并执行了隐藏，其事件注册不会自动恢复（与参考实现相同的限制），极端情况需 /reload。

### 参考实现（examples/，只读、不提交）

- `examples/elvui-16.01`：网格（`/egrid`、`Grid_Create`）、Movers 拖拽淡入淡出、Backdrop/gloss 纹理方案；
- `examples/ForeverUI`：面向本客户端的实际实现——BACKGROUND,-8 填充、OVERLAY,7 手绘边线、不用 SetBackdrop、字体/引导线细节；
- `examples/Ruyi`：位置登记（Mover）与边缘吸附选项，无布局网格。
