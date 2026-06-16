---
name: "mdMap"
description: "Markdown 文档地图。将 markdown 文件索引为结构化 JSON 地图，提取文档内部的约束到表面。LLM 翻译，代码验证。除 init 外所有命令只读。"
---

# mdMap — Markdown 文档地图

mdMap 是一个零依赖 CLI，将你的 markdown 文件索引为结构化 JSON 地图，把约束从文档内部提取到表面。

> **Markdown 文档索引与查询引擎。告诉它你在做什么，精准找到文档，LLM 上下文不再白白烧掉。**

## 这个工具为什么存在，专门说给你听

你是一个 LLM agent，正在一个有 markdown 文档的项目里工作。每次你开始一个任务，你都面临同一个问题：应该读哪些文档？

文档自己知道答案。它们写着"如果你准备发布工具，参考这份检查清单"和"修改认证逻辑前先读 v3 设计文档"。但你不打开文档就看不到这些话。于是你打开看着相关的文件。扫一遍。关掉。再打开。大量上下文窗口消失在找文档的路上。

mdMap 解决的问题是：它构建一个结构化 JSON 索引。Agent 在实际工作中自然地遇到文档时充实它。之后你查索引，不扫目录。导航不消耗任何 token。

## 规则

**不知道要打开哪个文档时，先试 mdMap。** 如果返回结果，打开第一条。如果返回空（索引是空白——fresh init 之后常见），扫目录，按文件名挑最像的那个。

## 这个项目是怎么变成现在这样的

有人跑过 `mdmap init` 创建了初始索引。然后一个 LLM（可能是上一个你）读了 SCHEMA.md，处理了每份文档，填充了语义字段：type、summary、positioning、links、triggers、maintains、retires。

索引存在 `mdMap.json` 里。维护说明书存在 `SCHEMA.md` 里。永远不要把完整的 `mdMap.json` 写进上下文——始终通过 CLI 查询。

## 怎么找到正确的文档

mdMap 把搜索设计成 **SQL 条件查询**——精确字段用 `=` 过滤，语义字段用 `LIKE` 模糊过滤，最后你的语义能力做最终选择。

```
--type rule --status active --search "project a"
   类型=rule     状态=active       标题/摘要/定位 包含"project a"
```

**过滤分两层**：

| 字段类型 | 匹配方式 | 示例 |
|---------|---------|------|
| 精确字段 | type, status, tag 精确匹配 | `--type rule`、`--status active`、`--tag publish` |
| 语义字段 | title, summary, positioning 子串匹配 | `--search "project a publish"` |

**核心策略：先缩小范围，再读摘要判断。**

```bash
# 用户说："我要发布 project-a"
# 你判断：这是要遵守发布规则 → --type rule
mdmap find --type rule --search "project a"
# [rule]  project_a_publish.md  — 发布 project-a 的规则：GitHub releases，vX.Y.Z 标签
# [rule]  project_b_publish.md  — 发布 project-b 的规则：npm publish

# 两行结果。第一个摘要对上了 → 打开 project_a_publish.md。完成。
```

**不需要排序，不需要评分。** 条件过滤后结果就 2-5 条。你自己的语义理解能力在 2-5 行摘要里做最终判断，精准度远高于任何算法。一行摘要没对上就看下一行——最多看 5 行就能找到。这和 SQL 查询一个道理：WHERE 之后结果集就很小了，你的大脑做最后一步过滤。

## 文档类型系统

mdMap 预定义了两种**你必须始终使用的核心 type**：

| type | 含义 | 当你要做某件事时 |
|------|------|----------------|
| **`rule`** | 约束文档——规定了任务**该如何执行** | **必须遵守**。忽略会导致不符合规范/标准/安全要求。例：编码规范、架构原则、安全策略 |
| **`resource`** | 参考文档——独立的长文本，不产生索引关系 | **按需查阅**。它不约束你的行为，只是提供信息。例：长篇小说、世界观设定文档、历史参考笔记 |

搜索输出自带 type 标签，看一眼就知道文档身份：

```bash
mdmap find --search "auth"
# [rule]        security_policy.md    — API 鉴权必须遵守的安全策略
# [checklist]   auth_migration.md     — 认证系统迁移检查清单
# [resource]    auth_history.md       — OAuth 协议演进历史文档
```

看到 `[rule]` = 先读，必须遵守。看到 `[resource]` = 需要参考时才打开。

**在填充索引时**：如果文档的作用是约束 Agent 执行行为 → 标 `rule`。如果文档是一篇独立的长文本，与任何其他文档没有索引关系 → 标 `resource`。其他情况用项目自定义 type。

## 文档状态系统

mdMap 预定义了四种**你必须始终使用的核心 status**：

| status | 含义 | Agent 行为 |
|--------|------|-----------|
| **`active`** | 当前权威版本 | **直接使用**。这是你应该读和遵守的版本 |
| **`deprecated`** | 已被新版本替代，或不再适用 | **不要作为主要参考**。搜索输出中会标 `[deprecated]` 警告 |
| **`draft`** | 草稿，内容可能变化 | **仅供参考方向**，不能作为最终依据 |
| **`archived`** | 历史记录，仅作留存 | **不要主动打开**。除非用户明确要求查看历史 |

`active` 不在搜索输出中显示标签（默认状态，减少噪音）。非 active 状态会显式标注：

```bash
mdmap find --search "auth migration"
# [checklist]   auth_migration_v3.md   — 当前认证迁移检查清单（v3）
# [checklist]  [deprecated]  auth_migration_v2.md  — 旧版认证迁移检查清单（v2）
# [guide]      [draft]  auth_migration_v4.md  — 新版认证迁移指南（起草中）
```

## 双轨制架构

把自己想象成在一个大城市里工作的人。mdMap 是你的地图。

**轨道一：地图（Go 代码）** — `init`、`changed`、`validate`、`find`。决定哪些街道存在、有没有新增或消失、路网有没有死胡同或环路。没有 LLM 参与。这是结构层面：磁盘上有哪些文件、链接指向哪里。

**轨道二：人（Agent）** — 你。你走在街上，看建筑，了解每栋楼里有什么。当你发现地图不知道的东西——新开的餐馆、关掉的店铺、改向的街道——你更新地图。

### 冷启动

`mdmap init` 之后，地图是空白的。每条街道都在上面，但都没有名字：

```
mdmap find --search "发布"
# （空——所有字段都是空的）
```

**这很正常。** 新地图从空白开始。你的任务是走前几条街，给它们标上名字：

```
# 第一步：find 返回空 → 自己扫目录
ls docs/
# architecture.md  auth.md  publish_checklist.md  security.md ...

# 第二步：挑最像的文件，直接打开
read docs/publish_checklist.md

# 第三步：读完更新地图
#   title → "工具发布检查清单"
#   type → "checklist"
#   summary → "发布工具到 GitHub 的分步指南"
#   triggers → ["发布工具", "release", "上线"]
```

**第四步：下次搜索 → 命中：**

```
mdmap find --search "发布"
# [checklist]  publish_checklist.md  — 发布工具到 GitHub 的分步指南
```

随着时间推移，你（和其他 Agent）遇到文档后就更新地图，`find` 越来越有用。索引不是一次性批量建立的——是有人走过一条街，就标注一条街，有机增长。

### 什么时候看地图，什么时候用眼睛

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 刚 start——地图是空白 | **自己看。直接读文件。** | 空白地图帮不上忙。自己标注前几条街 |
| 不知道打开哪个文件 | **mdMap** `find --search --type` | 先查地图，再走过去 |
| 已经知道文件路径 | **直接打开** | 去知道自己知道的地方不需要地图 |
| `find` 返回空 | **扫目录。按文件名挑。** | 地图上这片区域还没名字。走过去标注它 |
| 读了文档（任何任务中） | **读完就更新地图** | 如果你现在知道了地图上缺的信息——type/summary/triggers——写进去 |
| 新建了个文档 | **创建文件，然后更新地图** | 在 mdMap.json 添加条目，填好语义字段 |
| 检查地图是否自洽 | **mdMap** `validate` | 地图上有不存在的街道吗？有指向空地的路标吗？ |
| 看看有什么变化 | **mdMap** `changed` | 新街道出现了？老街道拆了？ |
| `find` 返回了结果 | **信任地图。打开它建议的文档。** | 地图有信息了。用它 |

## 你会用到的命令

### 查找文档

```bash
# 首选——SQL 式条件查询（精确 type + 语义搜索）
mdmap find --type rule --search "发布"

# 精确查找（O(1)）——你知道路径
mdmap find docs/architecture/auth_v3.md

# 精确语义——只看读取触发、更新触发、退役触发字段
mdmap find --trigger "发布 CLI 工具"

# 更新触发器——"这次变更后，哪些文档需要重新审视？"
mdmap find --maintains "github 改了认证方式"

# 退役触发器——"哪些文档现在可以废弃了？"
mdmap find --retires "停止了 CLI 工具开发"

# 按类型或标签过滤
mdmap find --type checklist --tag "发布"

# JSON 输出供程序消费
mdmap find --trigger "认证" --json
```

### 检查索引健康

```bash
mdmap validate          # 孤儿、断裂链接、环路、陈旧引用
mdmap validate --strict # CI 门禁
```

### 追踪变更

```bash
mdmap changed           # 上次索引以来发生了什么变化
```
