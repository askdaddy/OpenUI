# 变更记录

[文档入口](docs/README.md) · [工作约束](AGENTIC.md) · [版本规则](docs/planning/版本规则.md)

仅按版本记录已落地的代码变化，不记录设计讨论、方案、规划、决策或纯文档调整。

## 2026.11.0-dev.1（未发布）

- 核心完善：模块启停配置（`OpenUIDB.modules.enabled`，注册时声明 `defaultEnabled`、缺省启用，Core 恒开不可关）、`EnableModule/DisableModule` 状态机（幂等、状态先行、回调错误隔离、最新意图胜）、事件/定时器资源调度器（`OpenUI.Own` 登记、关闭自动释放、末位反注册）、战斗中启停意图队列经 `PLAYER_REGEN_ENABLED` 脱战自动应用（#6）。
- 本地化模块：`OpenUIDB.locale`（auto/enUS/zhCN，默认 auto）手动语言选择并**即时生效**（L 原地重建、表身份不变，消费者零改动）；locale 资源表化（enUS 基表与 zhCN 覆盖表常驻 `OpenUI.Locales`）；非法值软失败按 auto 兜底不清洗用户数据（#4）。
- 主题系统 T1：17 个语义 token 六族预设（颜色/透明度/字体字号/边框/间距/尺寸，扁平暗色默认值冻结）、模块运行时覆盖与分别重置（不落库）、`OpenUIDB.theme` 全局定制持久化、非法值软失败进诊断队列；`GetColor/GetFont` 兼容视图保持既有行为（#3）。
- 初始插件骨架：TOC 显式加载（Interface 16001）、命名空间、模块注册表与 OnInitialize/OnEnable/OnDisable 生命周期、回调错误隔离（#1）。
- 新增 `/openui`（回显版本与模块列表）与 `/openui errors`（错误队列）命令。
- enUS/zhCN 本地化回退、`OpenUIDB` 默认配置深拷贝合并、主题颜色/字体常量挂点。
- 打包根位于仓库根（可直接整体 symlink 为 `Interface/AddOns/OpenUI`）。
