# mdMap

[English](./README.md)

> **Markdown 文档索引与查询引擎。告诉它你在做什么，精准找到文档，LLM 上下文不再白白烧掉。**

---

你的 Markdown 文档是一片海洋。你知道正确答案就在某篇里面——但找到它意味着在几十个文件中跋涉，打开看着像的，翻两下，关掉，再试。等到你终于找到对的那篇，上下文窗口已经烧掉了三分之一——全花在找东西上，不是阅读上。

每次都这样。不管你是用 AI agent 开发的程序员，管理世界观设定的写作者，还是维护内部规范的团队。知识都在那里，只是在你打开正确文件之前，它不告诉你它在哪。

**每座图书馆都有目录。每个数据库都有索引。你的 Markdown 文件什么都没有。** 直到现在。

mdMap 就是这层目录。你指给它一个文件夹，它读一遍所有文档，构建结构化索引。不是全文搜索——是一张地图，知道每篇文档覆盖什么范围、什么场景该读它、它和哪些文档有关联。构建完之后，你再也不扫目录。提一个问题。拿到一个路径。打开那个文件。完成。

```
之前：
  任务："发布一个新的 CLI 工具"
  → 扫描 docs/tools/ → 打开 5 个文件 → 翻 → 关掉 3 个 → 读 2 个
  → 导航烧掉 15K tokens

之后：
  mdmap find --trigger "发布 CLI 工具"
  → publish_checklist.md
  → ~3K tokens。全部。
```

## 三分钟上手

```bash
# 安装
go install github.com/timgunnar/mdMap@latest

# 为你的项目建索引——200 篇文档，5ms
mdmap init ./docs
```

`init` 扫描每个 `.md` 文件，提取标题和 hash，写入 `mdMap.json` + `SCHEMA.md`。语义字段——每篇文档讲什么、什么时候读、什么时候更新——留空。让 LLM 填一次。

```bash
# 让 LLM 丰富索引：
# "读 SCHEMA.md。对 mdMap.json 中字段为空的每篇文档，
#  读取全文，提取 type/summary/triggers/links，写回。"

# 之后，你再也不扫目录。
mdmap find --search "发布工具"                    # 语义字段模糊匹配
mdmap find --type rule --search "project a"     # 精确 type + 语义搜索
mdmap find --trigger "发布工具"                   # 精确：只看读取触发
mdmap find --maintains "github 改了认证"          # 精确：只看更新触发
mdmap find --retires "停止了 CLI 开发"            # "什么可以归档了？"
mdmap find --type checklist --tag "发布"          # 过滤搜索
```

`--search` 在语义字段（标题/摘要/定位）中做子串匹配。`--type`、`--status`、`--tag` 做精确匹配。组合使用如 SQL 条件查询：先缩小到规则文档，再模糊搜项目名，返回 2-5 条——Agent 读摘要即可判断，无需打开文档。

## 不一样在哪

**它索引的不是关键词，是约束。** 文档自己写了什么时候该读它——"如果准备发布工具，看这份检查清单"。问题是你不打开文件就看不到这句话。mdMap 提取这些指令，让它们可查询。

**LLM 过一遍，之后全是代码。** LLM 每篇文档只读一次，提取语义。之后所有查询跑编译好的 Go 代码——O(1) 查找，零 token，零猜测。`validate` 跑五项确定性检查（孤儿检测、文件移动追踪、断裂链接、循环检测、陈旧引用），零 LLM 参与。

**你的术语，不是我们的。** 不写死文档类型。不限制状态值。软件项目可以标 `checklist`、`architecture`、`api_spec`。写小说的用 `character_profile`、`chapter_outline`、`world_setting`。mdMap 从 SCHEMA.md 学会你的词汇，然后保持一致。

**人类会移动文件。mdMap 替你处理。** 重命名文件夹，重新组织文档——`validate` 通过 hash 交叉匹配检测移动。`--fix` 自动更新索引。没有断裂路径。不需要手工清理。

## 你看不到的索引

`mdMap.json` 不是给人读的。它是一个数据库——快速查询，精简输出。1000 篇文档产生约 200KB 的地图。你的查询只返回你问的内容，通常不到 2KB。过滤在 Go 进程中完成。你的 LLM 上下文干干净净。

```
1000 篇文档的索引：    ~200KB  （永不进入上下文）
单文档精确查找：       ~2KB
触发器命中：           ~200B
```

## 命令

| 命令 | 做什么 |
|:--|:--|
| `init <dir>` | 可重入双向同步——永不覆盖元数据。git 仓库用 `git ls-files`，否则走文件遍历 |
| `find <path>` | 精确查找（O(1)） |
| `find --search <文本>` | 语义字段模糊匹配（标题/摘要/定位） |
| `find --trigger <文本>` | "这个任务该读什么？" |
| `find --maintains <文本>` | "这次变更后什么该更新？" |
| `find --retires <文本>` | "什么可以安全归档？" |
| `find --type <文本>` | 按文档类型过滤 |
| `find --tag <文本>` | 按标签过滤 |
| `validate` | 完整性检查：孤儿、移动、断裂、循环、陈旧 |
| `validate --fix` | 自动修复检测到的文件移动 |
| `changed` | 上次索引以来发生了什么变化 |

单 Go 二进制。零依赖。启动不到一毫秒。

## 许可证

MIT
