# mdMap

[中文](./README_CN.md)

> **Markdown document index and query engine. Tell it what you're doing — find the right doc without burning LLM context on the wrong ones.**

---

Your markdown files are an ocean. You know the right document is in there — but finding it means wading through dozens of files, opening wrong ones, skimming, closing, trying again. By the time you reach the right one, a third of your context window is gone — spent not on reading, but on searching.

This happens every time. Whether you're a developer working with an AI agent, a writer managing world-building docs, or a team maintaining internal specs. The knowledge is there. It just doesn't tell you where it is until you open the right file.

**Every library has a catalog. Every database has an index. Your markdown files have neither.** Until now.

mdMap is that catalog. You point it at a directory, it scans the directory structure and builds a structured index — it never opens .md files, just lists filenames. Not a full-text search — a map that agents annotate as they naturally encounter documents, recording what each document covers, when you should read it, and which documents it connects to. After indexing, you never scan directories again. You ask a question. You get a path. You open that file. Done.

```
Before:
  Task: "publish a new CLI tool"
  → grep -rl "publish" docs/ → 20 files hit
  → Open auth.md (authentication doc, one mention) → close
  → Open deploy.md (deployment guide, passing reference) → close
  → Open 3rd file: publish_checklist.md — finally right
  → Inside: "before publishing, check security_policy.md" → open that too
  → ~12K tokens burned on navigation (only 3K was useful content)

After:
  mdmap find --search "publishing"
  → [checklist]  publish_checklist.md  — Step-by-step guide for releasing to GitHub
  → [rule]       security_policy.md    — Security requirements for all releases
  → [checklist]  release_guide.md      — Full release procedures
  → Read three summaries, open what you need. ~3K tokens. Total.
```

## It works like this

```bash
# Install
go install github.com/timgunnar/mdMap@latest

# Index your project — 200 documents in 5ms
mdmap sync ./docs
```

`sync` scans the directory structure and writes `mdMap.json`. It never opens .md files — just lists filenames. The semantic fields — what each document is about, when to read it, when to update it — start empty. Agents fill them when they naturally encounter documents during work.

```bash
# Ask your LLM to enrich the index:
# "Read the schema section at the top of this skill doc. For each document in mdMap.json with empty fields,
#  read the doc, extract type/summary/triggers/links, write back."

# After that, you never scan directories again.
mdmap find --search "publishing a tool"          # semantic field substring
mdmap find --type rule --search "project a"     # exact type + semantic search
mdmap find --trigger "publishing a tool"         # narrower: read-trigger only
mdmap find --maintains "github changed auth"     # narrower: update-trigger only
mdmap find --retires "stopped CLI development"  # "what can I archive now?"
mdmap find --type checklist --tag "publish"     # filtered search
```

`--search` does substring matching on semantic fields (title/summary/positioning). `--type`, `--status`, `--tag` do exact matching. Combined like SQL: narrow to rules, fuzzy-match project name, get 2-5 results — the Agent reads summaries and judges, without opening files.

## What makes it different

**It indexes constraints, not keywords.** A document already tells you when to read it — "if you're publishing a tool, see this checklist." The problem is you can't see that instruction without opening the file. mdMap extracts those instructions and makes them queryable.

**One LLM pass, then pure code.** Agents evaluate and update semantic fields when they naturally encounter documents during work. After that, every query runs in compiled Go — O(1) lookups, zero tokens, zero guesswork. `validate` runs four deterministic checks (orphan detection, broken links, cycles, stale references) with no LLM involvement.

**Your conventions, not ours.** No hardcoded document types. No restricted status values. A software project might tag documents `checklist`, `architecture`, `api_spec`. A fiction writer might use `character_profile`, `chapter_outline`, `world_setting`. mdMap learns your vocabulary from the schema section in this skill doc and stays consistent.

**Two tracks.** mdMap is a map, not a substitute for direct file access. Agents always open files normally. mdMap just tells them which one. Moved files? Reorganized folders? `mdmap sync` re-syncs in one command.

## The index you never see

`mdMap.json` is not meant to be read. It's a database — fast queries, lean output. A 1000-document project produces a ~200KB map. Your queries return exactly what you asked for, usually under 2KB. Filtering happens in the Go process. Your LLM context stays clean.

```
1000-document index:    ~200KB  (never enters context)
Single document lookup: ~2KB
Trigger-based match:    ~200B
```

## Commands

| Command | What it does |
|:--|:--|
| `sync <dir>` | Sync map with terrain, create mdMap.json (annotations preserved) |
| `find <path>` | Exact document lookup (O(1)) |
| `find --search <text>` | Filter by semantic fields (title/summary/positioning) |
| `find --trigger <text>` | "What should I read for this task?" |
| `find --maintains <text>` | "What needs updating after this change?" |
| `find --retires <text>` | "What can be safely archived?" |
| `find --type <text>` | Filter by document type |
| `find --status <text>` | Filter by document status |
| `find --tag <text>` | Filter by tag |
| `find --json` | Machine-readable JSON output |
| `validate` | Integrity checks: orphans, broken links, cycles, stale links |
| `changed` | What changed on disk since last index (new + deleted) |

All in a single Go binary. No dependencies. Starts in under a millisecond.

## License

MIT
