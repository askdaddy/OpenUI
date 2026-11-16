# 变更记录

[文档入口](docs/README.md) · [工作约束](AGENTIC.md) · [版本规则](docs/planning/版本规则.md)

仅按版本记录已落地的代码变化，不记录设计讨论、方案、规划、决策或纯文档调整。

## 2026.11.0-dev.1（未发布）

- **根因修复3（#69）**：`edgeTexture` 下边框锚点错误（TOPLEFT(0,1)+BOTTOMRIGHT(0,0)）生成的是**覆盖整框的薄膜**（0.408 灰×0.95），这是"面板浅灰、文字变暗"系列现象的真正原因（probe v5 A/B 差分确证）。新增 `Widgets.Edge(frame, side, color, alpha)`（每边两点锚定+SetHeight/SetWidth(1)），Widgets 四边、动作按钮四边、单位框体条描边、施法条描边全部替换。（#69）
- 诊断增强（#68）：probe v5——Widgets.Panel vs ForeverUI 裸克隆配方并排（A/B）、裸 FontString vs Widgets.Text（C）、带/不带阴影（D），一次截图定位"深底变白/亮字变黑"的触发层。（#68）
- **根因修复2（#67，对照 examples/ForeverUI 配方）**：该客户端上**子层级 0 的填充纹理渲染为白色**（下发的颜色值正确、裸 ARTWORK 色块正常）。按 ForeverUI 的配方统一：全部填充 `CreateTexture(nil, "BACKGROUND", nil, -8)`（面板/按钮/条轨/搜索框底），全部描边 `CreateTexture(nil, "OVERLAY", nil, 7)`（四边/动作按钮/条描边/光环）；网格线保持 ARTWORK。（#67）
- 诊断增强（#66）：probe v4——五图层着色矩阵（BACKGROUND/BORDER/ARTWORK/HIGHLIGHT/OVERLAY 同红色对照，独立裸帧避免面板干扰）+ surface 色 ARTWORK 对照组，一次截图确定客户端可用图层。（#66）
- **根因修复（#65）：Forever 客户端 BACKGROUND 纹理层渲染为白色**（probe v3 四对照条确证：ARTWORK 正常、BACKGROUND 全白）。全部填充纹理（面板/按钮/条轨/网格线/搜索框/光环底）由 BACKGROUND 迁移至 **ARTWORK**（按创建序保持层级）；描边统一 **OVERLAY**（填充之上）；probe 主条扫描改为仅 Frame 对象、每行一条。（#65）
- 诊断增强（#64）：probe v3——样块面板屏上显示 surface/on-surface/opacity/palette 数值与四条对照（α=1/α=0.88/WHITE8X8 顶点色/0.5 灰参考），并扫描全局输出 MainMenu/MainBar/ActionBar 候选帧名（定位原生主条真名）。（#64）
- 诊断增强（#60）：`/openui probe` v2——打印 `OpenUIDB.theme` 全量键值（检测旧/异常定制）、主题行首尾各打印一次（防聊天滚动丢失）、用真实 Panel 管线渲染"surface 底 + onSurface 文字 + outline 边框"样块（与红/绿测试块对照定位"值浅 vs 渲染浅"）。（#60）
- 原生帧名兼容（#61）：施法条隐藏清单加入现代别名 `PlayerCastingBarFrame`（保留 CastingBarFrame）；动作条启用/脱战/延迟重试时尝试 `LoadAddOn("Blizzard_ActionBar")` 使懒加载帧就绪；Grid 全屏层增加 `SetMouseClickEnabled(false)` 硬化鼠标穿透（排除聊天文字无法选中的可能原因）。（#61）
- 验收修复（#59）：动作条/宠物条/光环图标**全格填充**（去掉内缩，描边置于图标之上）；`Native.Snapshot` 升级为 `hidden=[…] missing=[…]`——暴露**未找到的原生帧名**（Forever 帧名差异导致隐藏静默失败的诊断关键，/openui probe 可见）。（#59）
- 验收修复（#58）：Widgets.Text 显式 SetTextColor(on-surface)（消除 GameFontNormal 默认金色表头）；移除通体 sheen 渐变与顶部亮带（客户端渲染成白纱覆盖深色底）；`/openui probe` 增补主题取值、Widgets 下发色自证与双测试色块（红=SetColorTexture / 绿=WHITE8X8+SetVertexColor，10s 自动消失）。（#58）
- 验收修复（#57）：**撤回 Backdrop 方案**（Forever 客户端仅 edgeFile 的 Backdrop 会以白底填充导致面板变浅灰；边框回到 4 边纹理方案，银边效果保留）；原生动作条隐藏加固——登录后 1s/3s/6s 延迟重试（覆盖暴雪大厅初始化后的重挂/重显），`/openui probe` 可查隐藏清单。（#57）
- 视觉 v4（#56，按用户提供的 ElvUI 效果图对齐）：面板/按钮边框由暗色 outline-variant 提升为**明亮银灰 color.outline**（面板 ×0.95 / 按钮 ×0.8，Backdrop 与纹理同步）；Widgets.Text 统一**黑色阴影**（1,-1，0.9）；面板顶部 28px 亮带叠加 sheen；动作按钮 1px 描边 + 数量阴影；单位框体生命/能量条 1px 暗描边、生命数值**居中覆盖于血条**；施法条进度条描边；光环图标描边 0.9；聊天边框提升 color.outline。（#56）
- 视觉 v3（#55，按 examples/elvui-16.01 源码方案）：
  - `Widgets.GradientFill`：上亮(×1.35)下暗(×0.55)垂直渐变填充，SetGradient 不可用时降级纯色；
  - 单位框体生命/能量条、施法条进度条改用渐变填充（ElvUI gloss 状态条贴图的纯内置等价物）；
  - 探测 `BackdropTemplate`：可用时 Panel/Button/Toggle 加 1px WHITE8X8 Backdrop 边框（面板 outline×0.9 / 按钮 ×0.75，随 Refresh 换色），与既有 sheen/半透明叠加；不可用零报错退回旧外观。（#55）
- 布局编辑模式（#54，类似原生 Edit Mode）：`/openui edit` 或主控面板「布局编辑」按钮进入——网格自动显示并恒亮；拥有可移动组件的模块（单位框体/施法条/光环/动作条）**临时启用**使全部组件可见；每个 mover 显示主题主色高亮边框；此模式下**无需 Alt 直接拖放**；退出恢复模块启停与网格原状态，位置仍即时持久化；Widgets 增加 movers 登记表（7 个：单位×2/施法×2/光环×2/宠物条）。（#54）
- 布局网格增强（#53，参照 examples/elvui-16.01 的 egrid/Movers）：拖拽开始网格淡入至 1.0、松手淡回 0.45（0.2s 插值）；中心十字轴改用 color.primary×0.35 高亮；`/openui grid <4..256>` 直接设定像素步长并显示（原有切换/循环/设置小窗保持）。（#53）
- 布局网格系统（#52）：
  - Grid 模块（默认关闭）：全屏 1px 网格线（outline-variant×0.15）+ 中心十字轴线（2px×0.25），单元格 32/48/64 可切换（默认 48），按屏幕尺寸生成、随配色主题刷新；
  - 入口：`/openui grid` 切换；主控面板「基础」类「布局网格」模块小窗（显示/尺寸循环/吸附开关/提示）；
  - 吸附定位：`Widgets.MakeDraggable` 拖拽结束时按最近网格取整（网格显示且吸附开启时），保存吸附后坐标并即时重锚；
  - 配置 `cfg.grid = { shown, size, snap }` 持久化；8 个新双语 key（74/74）。（#52）
- UI 拖拽统一与视觉 v2（#50）：新增 `Widgets.MakeDraggable`（Alt+左键，脱战，位置持久化到生效配置档）并接入单位框体/施法条/光环/宠物条（含宠物按钮 Alt 转发）；单位框体默认移至左上、施法条/光环重排避让屏幕中心；`Theme.RegisterRefresh` 订阅——UnitFrames/CastBars/Auras 底纹与描边随配色重绘；`opacity.panel` 默认 0.95→**0.88**（可见半透明），面板 sheen 渐变增强 0.35→0 与 24px 亮带降级、边框 alpha 面板 0.9/按钮 0.7。（#50）
- 系统 UI 遮盖机制（#49）：Native 助手升级——保存模块声明的帧名清单（含未加载帧），ADDON_LOADED/PLAYER_ENTERING_WORLD/脱战自动重应用（延迟加载的暴雪帧出现即隐藏）；动作条迁移至 Native 并覆盖 MainMenuBar+MultiBar×7+PetActionBar，光环补 DebuffFrame；每模块独立记账、恢复幂等；`OpenUI.Native.Snapshot()` 供 `/openui probe` 查看隐藏清单。（#49）
- UI 基础美化（#48）：全部 Widgets.Panel 与 Button/Toggle 增加 **1px 细边框**（outline-variant，面板 0.85 / 按钮 0.6）与面板**顶部 sheen 渐变**（surface-container-highest 0.12→0，SetGradient 可用时）；半透明基色保持；配色切换时装饰随 Refresh 换色；缺失 CreateColor/SetGradient 自动降级零报错。（#48）
- 动作条 T2（#47）：新增 bar2–bar6（各 12 安全按钮，固定槽 13–72；主条保持安全分页）；每 bar 独立显示开关（默认仅主条）与独立位置（Alt+左键/条体拖拽，脱战，持久化到生效配置档）；原生多动作条全部隐藏与关闭恢复；设置面板「动作条」模块小窗含 6 条开关与拖拽提示；3 个新双语 key（66/66）。（#47）
- 主控面板（#46）：/openui 改为模块分类总览（基础/战斗界面/系统窗口/工具四类，三列磁贴，●/○ 启停状态点，搜索按模块名/类目过滤）；点击磁贴打开模块独立小窗（单实例，含启用开关与模块专属控件：主题七套配色/语言/诊断入口/媒体说明/无设置提示）；Settings 自注册为模块；33+2 本地化 key（63/63）。（#46）
- **Secret Values 兼容（Forever 客户端实测能力）**：UnitHealth/CastingInfo/Aura/动作数量等返回值可能为秘密值，受污染执行中算术与格式化会抛错——新增 OpenUI.Try 共享助手，UnitFrames/CastBars/Auras/ActionBars/Nameplates/MinimapUI 全部数值/格式化路径降级保护（不可用时显示空文本/静态条/隐藏槽，不中断模块）（验收修复）。
- 验收修复六：诊断窗口 EditBox 点击聚焦（此前无法拖选/Ctrl+C 复制），Esc 取消聚焦（#10 验收修复）。
- 验收修复五：诊断窗口多行 EditBox 补字体对象与文字颜色（此前窗口空白、聊天输出正常）；搜索框同类问题一并依赖同一修复路径（#10 验收修复）。
- 验收修复四：小地图边框由整块方框描边改为**圆形点环**（36 段沿圆周、支持 SetRotation 则细化为切线方向；方框在圆形小地图上会显示为"小方块"）（#17 验收修复）。
- 验收修复三：搜索框补字体对象与文字颜色（此前输入内容不可见）；动作条支持 **Alt+左键**从任意动作按钮拖拽移动（脱战，避免与施法点击冲突），条体直接拖拽保留（#8/#11 验收修复）。
- 验收修复二：设置搜索框点击聚焦/ESC 退出并支持回车退出；搜索无结果时隐藏当前页内容（防提示叠页）；动作条主条支持**拖拽移动**并将位置持久化到生效配置档（脱战可拖，宠物条随主条）；`ClearAllPoints` 守卫（#8/#11 验收修复）。
- 验收修复：Widgets Button/Toggle 标签 FontString 补锚定（未锚定 Region 在客户端不渲染，导致设置窗口按钮无文字）；按钮/开关背景改用 surface-container-high 提升对比度；设置搜索框增加可见背景；动作条图标读取增加 C_ActionBar 回退；新增 `/openui probe` 现场诊断命令（动作 API/槽位纹理/动作条状态）（#8/#11 验收修复）。
- 媒体选择与缺失处理 T1：`Media.Options`（内部+外部去重合并的选择器/预览数据源）、`Media.Resolve`（internal/external/missing 三态、缺失软报告并回退）、`Media.SetConfigName`（配置只存媒体名标识，导出串不嵌入素材本体）（#43）。
- 特殊场景 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#31）。
- 系统界面 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#30）。
- 拍卖行 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#29）。
- 专业与成长 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#28）。
- 交易与邮件 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#27）。
- 社交与组队 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#26）。
- 队伍与团队 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#25）。
- 法术书与天赋 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#24）。
- 角色与装备 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#23）。
- NPC交互 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#22）。
- 任务 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#21）。
- 世界地图 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#20）。
- 背包与银行 T1（B1，默认关闭）：经共享助手 OpenUI.Restyle 主题化命名原生帧（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）（#19）。
- 提示框 T1（B1，默认关闭）：经 OpenUI.Restyle 主题化 GameTooltip/购物比较提示框（背景/边框/字号，关闭恢复、换色联动、缺帧守卫）；顺带修复模块无 OnInitialize/OnDisable 回调时启停产生的诊断噪声（#18）。
- 小地图 T1（B1，默认关闭）：主题化边框环（outline-variant 描边锚定原生 Minimap，功能全保留）+ 坐标文本（GetPlayerMapPosition 百分比、1s 刷新、无定位清空）；**新增共享外观重绘助手 `OpenUI.Restyle`**（命名原生帧主题背景/边框/字号 + 原值恢复 + 配色切换刷新，B1 后续界面票复用）（#17）。
- 名牌 T1（B1，默认关闭）：经 NAME_PLATE_CREATED/UNIT_ADDED 事件对名牌应用主题（反应色血条、名称字号 type.label）；结构不可识别零操作零报错（守卫）；不触碰锚点/缩放/点击；关闭停止应用（已应用保持到刷新，已知限制）；连击点/资源/仇恨增强分期（#16）。
- 光环 T1（B1，默认关闭）：玩家 Buff/Debuff 两行图标（图标/层数/剩余时间分钟-秒自适应、Buff outline 描边/Debuff error 描边、无持续时间留空）；UNIT_AURA 事件重算 + 0.5s 定时刷新剩余；无光环整行隐藏；原生 BuffFrame（含临时附魔区）经 OpenUI.Native 隐藏、关闭恢复；目标光环/过滤排序/点击取消分期（#15）。
- 施法条 T1（B1，默认关闭）：玩家/目标施法条（法术名、primary 进度条、剩余秒；引导法术反向进度并标注）；施法事件即时重算 + 0.1s 定时推进（战斗信息及时）；无施法隐藏；原生 CastingBarFrame/TargetFrameSpellBar 经 OpenUI.Native 隐藏、关闭恢复；焦点/宠物施法条分期（#14）。
- 单位框体 T1（B1，默认关闭）：玩家/目标框体（名称、职业色/反应色生命条+数值、能量条，Unit* API 全守卫）；新增共享原生帧隐藏助手 `OpenUI.Native`（按模块记账、脱战应用、恢复幂等，B1 各票复用）；隐藏原生 PlayerFrame/TargetFrame，关闭恢复；队友/焦点/ToT/宠物分期保持原生（#13）。
- 聊天 T1：主题化原生聊天框架外观——全部 ChatFrame 与输入框背景（surface × opacity.panel）、边框（outline-variant）、字号（type.body，保留原字体文件）；配色切换即时联动（Theme rebuild 钩子）、PLAYER_ENTERING_WORLD 重应用；关闭模块逐项恢复启用前原值；不重建聊天引擎（消息/超链接/右键/标签交互原生保留）；自定义标签视觉/停靠/战斗日志/频道增强分期（#12）。
- 动作条 T1：主条 12 个安全按钮（SecureActionButtonTemplate；分页 1–6 经 SecureHandlerStateTemplate 安全状态驱动，含 bonusbar 形态页）、宠物条 10 安全按钮；主题化底/图标/数量显示；原生主条与宠物条仅脱战隐藏（战斗中经 PLAYER_REGEN_ENABLED 延后），关闭模块恢复原生；多动作条/姿态/载具/额外动作保持原生（后续分期）（#11）。
- 诊断增强：`/openui errors` 保留聊天输出并额外打开**可复制堆栈查看窗口**（多行 EditBox，编号条目含完整 debugstack，选中 Ctrl+C 复制；空队列显示无错误提示；单实例、拖拽/ESC 关闭、`Diagnostics` 模块默认启用）；错误队列维持 50 条 FIFO 上限且**不跨会话保留**（运行数据不入档、不写 SavedVariables）（#10）。
- 配置档 T1：账号级 `OpenUIDB.profiles`（5 共享槽 + 角色独立档 + 持续关联活引用，`Profile.Config/UseSlot/UseIndependent{copy}/DeleteSlot/ConfigFor/Slots`）；删除槽为全部关联角色（含未登录记录）保留删除前副本；首次初始化把 legacy 顶层配置深拷贝迁移进角色独立档（legacy 键保留）；Theme/Locale/Core 读写改经生效配置（未加载 Profile 时回退 legacy）（#9）。
- 统一设置窗口：裸 `/openui` 开窗（保留版本/模块打印）+ 左侧竖排导航（外观/语言/模块/关于）+ 搜索（匹配页名与设置项、无结果提示）+ 全部选项即时生效；外观页七套配色切换、语言页 Auto/enUS/zhCN、模块页各模块开关（接 #6）、关于页版本/模块/错误计数；控件均来自 `OpenUI.Widgets`（新增 Toggle），配色切换自动换色、语言切换窗口文案即时刷新（#8）。
- 主题与控件（M3 Expressive）：18 个 M3 语义色角色（surface 层级/on-\*/outline/primary/secondary/tertiary/error）+ **七套可切换暗色配色**（starblue 默认/teal/amber/amethyst/rose/moss/graphite，seed+配方纯 Lua 确定性生成）+ `Theme.SetPalette/GetPalette`（持久化 `OpenUIDB.theme.palette`，非法软失败）；旧 17-token 全部保留为兼容别名并自动迁移旧定制；新增排版角色（type.\* 5 级）、形状等级（shape.\*）、状态层（state.\*，M3 口径）、动效 token（motion.\*）；新增最小控件工厂 `OpenUI.Widgets`（Panel/Button/Text + 换色自动刷新）（#7）。
- 核心完善：模块启停配置（`OpenUIDB.modules.enabled`，注册时声明 `defaultEnabled`、缺省启用，Core 恒开不可关）、`EnableModule/DisableModule` 状态机（幂等、状态先行、回调错误隔离、最新意图胜）、事件/定时器资源调度器（`OpenUI.Own` 登记、关闭自动释放、末位反注册）、战斗中启停意图队列经 `PLAYER_REGEN_ENABLED` 脱战自动应用（#6）。
- 本地化模块：`OpenUIDB.locale`（auto/enUS/zhCN，默认 auto）手动语言选择并**即时生效**（L 原地重建、表身份不变，消费者零改动）；locale 资源表化（enUS 基表与 zhCN 覆盖表常驻 `OpenUI.Locales`）；非法值软失败按 auto 兜底不清洗用户数据（#4）。
- 主题系统 T1：17 个语义 token 六族预设（颜色/透明度/字体字号/边框/间距/尺寸，扁平暗色默认值冻结）、模块运行时覆盖与分别重置（不落库）、`OpenUIDB.theme` 全局定制持久化、非法值软失败进诊断队列；`GetColor/GetFont` 兼容视图保持既有行为（#3）。
- 初始插件骨架：TOC 显式加载（Interface 16001）、命名空间、模块注册表与 OnInitialize/OnEnable/OnDisable 生命周期、回调错误隔离（#1）。
- 新增 `/openui`（回显版本与模块列表）与 `/openui errors`（错误队列）命令。
- enUS/zhCN 本地化回退、`OpenUIDB` 默认配置深拷贝合并、主题颜色/字体常量挂点。
- 打包根位于仓库根（可直接整体 symlink 为 `Interface/AddOns/OpenUI`）。
