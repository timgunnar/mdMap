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

**把 `--search` 作为你的首选查询方法。** 它用 **BM25** 对每篇文档打分——这是一种工业级排序算法，奖励关键词出现频率（TF），同时惩罚在所有文档都能找到的通用词（IDF）。一次搜全部文本字段（标题、摘要、定位、触发器、更新触发、退役触发、标签）。

```bash
# 首选——按相关性排序，分数高的排前面
mdmap find --search "发布"
# 4.23  publishing_guide.md
# 2.27  testing_guide.md
# 0.52  architecture.md
```

**直接把用户的意图扔进去。** BM25 把查询拆成词，逐词对每篇文档独立打分。输出按分数排序——排第一的就是你该优先打开的。一篇在触发词和标签里多次提到"发布"的文档，会比只提了一次的文档排得高很多。

只有在需要更精确的语义时才用 `--trigger`、`--maintains`、`--retires`（比如"只搜这个变更后需要更新的文档"——这个概念只存在于 `maintains` 字段）。

## 你会用到的命令

### 查找文档

```bash
# 首选——一次搜全部字段（先用这个）
mdmap find --search "发布"

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
