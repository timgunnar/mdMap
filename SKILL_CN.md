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

mdMap 解决的问题是：它把所有文档读一遍，提取每份文档本应能宣告自己的信息，存进 JSON 索引。之后你查索引，不扫目录。导航不消耗任何 token。

## 你必须遵守的规则

**在这个项目中打开任何 markdown 文档之前，先查 mdMap。**

知道文档路径：`mdmap find <路径>`
有一个任务描述：`mdmap find --trigger "<你在做什么>"`

只打开 mdMap 返回的文档。其他都和当前任务无关。

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

## 何时用 mdMap，何时直接读文件

mdMap 是导航层，不是文件 I/O 的替代品。**你始终用传统方式打开和阅读文件。** mdMap 只告诉你该读哪一个。

| 场景 | 用什么 | 为什么 |
|------|--------|--------|
| 不知道要读哪个文档 | **mdMap** `find --search --type` | 先定位，再打开 |
| 已经知道文件路径 | **直接打开文件** | mdMap 是中间层，已知路径就跳过 |
| 需要查到所有相关规则 | **mdMap** `find --type rule` | 精确 type 过滤，结果 2-5 条 |
| 文件还不存在，要新建 | **直接创建** | `init` 下次运行自动感知 |
| 验证文档图是否完整 | **mdMap** `validate` | 四项确定性检查，零 LLM |
| 看看磁盘上文件变化 | **mdMap** `changed` | new: 新增 / deleted: 删除，即时 diff |

**核心设计**：`mdmap init` 不打开任何 md 文件。它只列目录，所有字段从空开始。你在实际工作中遇到某篇文档后，再填充它的 type/summary/triggers/links。这就是双轨制：mdMap 是地图（你可以用），不是文件阅读的替代品（你永远可以直接读文件）。

**你的任务**：当你因任何任务读了某一篇 `init` 出的空壳文档（不管通过什么方式），读完后更新它在 mdMap.json 中的条目——填 type、summary、triggers、links 等。索引随 Agent 的实际工作有机增长。

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
mdmap validate          # 孤儿、断裂链接、文件移动、陈旧引用
mdmap validate --fix    # 自动更新 mdMap.json 中被移动的文档路径
mdmap validate --strict # CI 门禁
```

### 追踪变更

```bash
mdmap changed           # 上次索引以来发生了什么变化
```

## 你应该帮忙维护索引

你不只是索引的消费者——你也是它的维护者。帮忙保持它的时效性：

**`mdmap validate` 报告了孤儿文件：** 磁盘上有新文档但索引里没有。先读 SCHEMA.md，然后逐个读孤儿文档，提取语义字段，写入 mdMap.json。如果引入了新的 type/status/tag 值，更新 SCHEMA.md 的项目惯例部分。

**`mdmap changed` 报告了文件修改：** 文档内容变了，hash 不再匹配。重读文档，更新语义字段和 hash。

**你创建了新文档：** 不要只写文件。同时在 mdMap.json 里添加条目，填好语义字段，然后跑 `mdmap validate` 确认没破坏任何东西。

## 你应该理解的架构

这个项目保持严格的职责分离：

- **LLM 读文档，写索引。** 每篇文档读一次。语义提取。
- **代码验证索引。** 确定性检查。零 LLM 参与。

你在 LLM 角色里。你做提取。CLI 做验证。信任 `validate`——它会捕获你可能犯的错误（断裂链接、陈旧引用）。每次更新后都跑一遍。
