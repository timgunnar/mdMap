---
name: "mdMap"
description: "Markdown document map. Index markdown files into a structured JSON map with triggers, links, and CRUD lifecycle hooks. LLM translates, code verifies. All commands are read-only except init."
---

# mdMap — Markdown Document Map

mdMap is a zero-dependency CLI that indexes your markdown files into a structured JSON map, extracting constraints from inside documents to the surface.

> **Markdown document index and query engine. Tell it what you're doing — find the right doc without burning LLM context on the wrong ones.**

## Why this exists, for you specifically

You are an LLM agent working in a project with markdown documentation. Every time you start a task, you face the same problem: which documents should you read?

The documents themselves contain the answer. They say things like "if you're publishing a tool, see this checklist" and "before modifying auth, read the v3 design doc." But you cannot see these instructions without opening the documents first. So you open files that look relevant. Skim. Close. Open more. A significant portion of your context window disappears just finding the right documents.

mdMap solves this by reading every document once, extracting what each document should have been able to announce about itself, and storing it in a JSON index. From that point on, you query the index instead of scanning directories. You spend zero tokens on navigation.

## The rule you must follow

**Before opening any markdown document in this project, check mdMap first.**

If you know the exact document path: `mdmap find <path>`
If you have a task description: `mdmap find --trigger "<what you are doing>"`

Only open the documents mdMap returns. Everything else is irrelevant to your current task.

## How the project got here

Someone ran `mdmap init` to create the initial index. Then an LLM (possibly a previous instance of you) read SCHEMA.md, processed each document, and filled in the semantic fields: type, summary, positioning, links, triggers, maintains, retires.

The index lives in `mdMap.json`. Maintenance instructions live in `SCHEMA.md`. You should never read the full `mdMap.json` into context — always query it through the CLI.

## How to find the right document

mdMap models search as **SQL conditional queries** — exact fields use `=` filtering, semantic fields use `LIKE` substring matching, and your semantic understanding makes the final call.

```
--type rule --status active --search "project a"
   type=rule      status=active      title/summary/positioning contains "project a"
```

**Two-layer filtering**:

| field type | matching | example |
|-----------|----------|---------|
| exact fields | type, status, tag exact match | `--type rule`, `--status active`, `--tag publish` |
| semantic fields | title, summary, positioning substring | `--search "project a publish"` |

**Core strategy: narrow with type, then read summaries.**

```bash
# User says: "I need to publish project-a"
# You reason: they need publishing rules → --type rule
mdmap find --type rule --search "project a"
# [rule]  project_a_publish.md  — Publishing rules for project-a: GitHub releases, vX.Y.Z tags
# [rule]  project_b_publish.md  — Publishing rules for project-b: npm publish

# Two results. First summary matches → open project_a_publish.md. Done.
```

**No ranking, no scoring needed.** After conditional filtering, you get 2-5 results. Your own semantic understanding on 2-5 summary lines beats any algorithm. If the first summary doesn't match, check the second — you'll find the right one within 5 lines at most. Same as SQL: WHERE narrows the result set, your brain does the final filter.

## Document type system

mdMap predefines two core types that you must use consistently:

| type | meaning | when executing a task |
|------|---------|----------------------|
| **`rule`** | constraint document — governs HOW a task should be executed | **Must follow.** Ignoring it means you are not complying with project standards/security/architecture. Examples: coding standards, architectural principles, security policies |
| **`resource`** | standalone reference — long-form content with no indexing relationships | **Consult as needed.** It does not constrain your behavior; it provides information. Examples: long-form fiction, world-building docs, historical reference notes |

Search output shows the type tag inline — you know a document's role at a glance:

```bash
mdmap find --search "auth"
# [rule]        security_policy.md    — API authentication security policy — must comply
# [checklist]   auth_migration.md     — Authentication migration checklist
# [resource]    auth_history.md       — History of OAuth protocol evolution
```

When you see `[rule]` → open it first. You must follow its constraints. When you see `[resource]` → open it only if you need reference information.

**When indexing:** if a document constrains agent behavior → tag it `rule`. If it is a standalone long-form document with no index relationships to other docs → tag it `resource`. For all other documents, use project-specific types.

## Document status system

mdMap predefines four core statuses that you must use consistently:

| status | meaning | agent behavior |
|--------|---------|---------------|
| **`active`** | current authoritative version | **Use directly.** This is the version you should read and follow |
| **`deprecated`** | replaced or no longer applicable | **Do not use as primary reference.** Search output shows `[deprecated]` warning |
| **`draft`** | work in progress, content may change | **Consult for direction only.** Not final authority |
| **`archived`** | historical record, kept for reference | **Do not open proactively.** Only when the user explicitly asks |

`active` is not shown in search output (it's the default — no noise). Non-active statuses are labeled:

```bash
mdmap find --search "auth migration"
# [checklist]   auth_migration_v3.md   — Current auth migration checklist (v3)
# [checklist]  [deprecated]  auth_migration_v2.md  — Old auth migration checklist (v2)
# [guide]      [draft]  auth_migration_v4.md  — New auth migration guide (drafting)
```

## When to use mdMap vs direct file access

mdMap is a navigation layer, not a replacement for file I/O. **You always open and read files the normal way.** mdMap just tells you which one to open.

| scenario | use | why |
|----------|-----|-----|
| Don't know which document to read | **mdMap** `find --search --type` | Locate first, then open |
| Already know the file path | **Open file directly** | mdMap is middleware; skip if you know the target |
| Need to find all applicable rules | **mdMap** `find --type rule` | Exact type filter → 2-5 results |
| File doesn't exist yet, creating new | **Create directly** | `init` will pick it up next run |
| Verify document graph integrity | **mdMap** `validate` | Four deterministic checks, zero LLM |
| See what changed on disk | **mdMap** `changed` | new: + deleted: — instant diff |

**Core design**: `mdmap init` does NOT open .md files. It only lists directory entries. All fields start empty. You fill them in when you encounter documents during real work. This is the two-track approach: mdMap is a map (you can use it), not a substitute for reading files directly (you always can).

**Your job**: when you read an `init`-stub document (for any task, via any method), update its entry in mdMap.json afterward — fill in type, summary, triggers, links, etc. The index grows organically as agents do real work.

## Commands you will use

### Finding documents

```bash
# Primary — SQL-style conditional query (exact type + semantic search)
mdmap find --type rule --search "publishing"

# Exact lookup (O(1)) — you know the path
mdmap find docs/architecture/auth_v3.md

# Narrower — only read-trigger, update-trigger, or retire-trigger fields
mdmap find --trigger "publishing a CLI tool"

# Update trigger — "what documents should be reviewed after this change?"
mdmap find --maintains "github changed authentication"

# Retire trigger — "what documents are obsolete now?"
mdmap find --retires "stopped building CLI tools"

# Filter by type or tag
mdmap find --type checklist --tag "publish"

# JSON output for programmatic consumption
mdmap find --trigger "auth" --json
```

### Checking index health

```bash
mdmap validate          # orphans, broken links, file moves, stale refs
mdmap validate --fix    # auto-update moved document paths in mdMap.json
mdmap validate --strict # CI gate
```

### Tracking changes

```bash
mdmap changed           # what changed since the last index
```

## When you should help maintain the index

You are not just a consumer of the index — you are also its maintainer. Help keep it current:

**After `mdmap validate` reports orphans:** new documents exist on disk but are not in the index. Read SCHEMA.md, then read each orphan document, extract its semantic fields, and write them into mdMap.json. Update SCHEMA.md's Project Convention section if you introduce new type/status/tag values.

**After `mdmap changed` reports modifications:** a document's content has changed. Its hash no longer matches. Re-read the document, update its semantic fields, update the hash.

**When you create a new document:** don't just write the file. Also add its entry to mdMap.json with the semantic fields filled in, and run `mdmap validate` to confirm nothing is broken.

## Architecture you should understand

The project maintains a strict separation:

- **LLM reads documents, writes the index.** One read per document. Semantic extraction.
- **Code validates the index.** Deterministic checks. Zero LLM involvement.

You are in the LLM role. You do the extraction. The CLI does the verification. Trust `validate` — it catches mistakes you might make (broken links, stale references). Run it after every update.
