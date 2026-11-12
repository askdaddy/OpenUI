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
