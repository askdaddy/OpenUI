# 变更记录

[文档入口](docs/README.md) · [工作约束](AGENTIC.md) · [版本规则](docs/planning/版本规则.md)

仅按版本记录已落地的代码变化，不记录设计讨论、方案、规划、决策或纯文档调整。

## 2026.11.0-dev.1（未发布）

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
