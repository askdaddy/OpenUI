# 变更记录

[文档入口](docs/README.md) · [工作约束](AGENTIC.md) · [版本规则](docs/planning/版本规则.md)

仅按版本记录已落地的代码变化，不记录设计讨论、方案、规划、决策或纯文档调整。

## 2026.11.0-dev.1（未发布）

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
