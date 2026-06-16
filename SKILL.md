---
name: "mdMap"
description: "Markdown document map. Index markdown files into a structured JSON map with triggers, links, and CRUD lifecycle hooks. LLM translates, code verifies. All commands are read-only except init."
---

# mdMap — Markdown Document Map

mdMap is a zero-dependency CLI that builds a structured JSON index of your markdown files — letting agents search by type, status, and semantic content without opening wrong documents.

> **Markdown document index and query engine. Tell it what you're doing — find the right doc without burning LLM context on the wrong ones.**

## Why this exists, for you specifically

You are an LLM agent working in a project with markdown documentation. Every time you start a task, you face the same problem: which documents should you read?

The documents themselves contain the answer. They say things like "if you're publishing a tool, see this checklist" and "before modifying auth, read the v3 design doc." But you cannot see these instructions without opening the documents first. So you open files that look relevant. Skim. Close. Open more. A significant portion of your context window disappears just finding the right documents.

mdMap solves this by building a structured JSON index. Agents enrich it when they naturally encounter documents. From that point on, you query the index instead of scanning directories. You spend zero tokens on navigation.

## The rule

**When you don't know which document to open: try mdMap first.** If it returns results, open the top match. If it returns nothing (the index is blank — common after a fresh `init`), scan the directory and pick the most likely file by filename.

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

## Two-track architecture

Think of yourself as a person working in a large city. mdMap is your map.

**Track 1: the map (Go code)** — `init`, `changed`, `validate`, `find`. Determines what streets exist, whether they appeared or disappeared, whether the road network has dead ends or loops. No LLM involved. This is structural: what files are on disk, what links point where.

**Track 2: the person (Agent)** — you. You walk the streets, look at buildings, learn what's inside. When you discover something the map doesn't know — a new restaurant, a closed shop, a street that changed direction — you update the map.

### The cold start

After `mdmap init`, the map is blank. Every street is on it, but none of them have labels:

```
mdmap find --search "publishing"
# (nothing — all fields are empty)
```

**This is normal.** A new map always starts blank. Your job is to walk the first few streets and label them:

```
# Step 1: find returns nothing → scan the directory yourself
ls docs/
# architecture.md  auth.md  publish_checklist.md  security.md ...

# Step 2: pick the most likely file, open it directly
read docs/publish_checklist.md

# Step 3: after reading, update the map
#   title → "Publishing Checklist"
#   type → "checklist"
#   summary → "Step-by-step guide for releasing tools to GitHub"
#   triggers → ["publishing a tool", "releasing", "shipping"]
```

**Step 4: next time you search → it works:**

```
mdmap find --search "publishing"
# [checklist]  publish_checklist.md  — Step-by-step guide for releasing tools to GitHub
```

Over time, as you (and other agents) encounter documents and update the map, `find` becomes more and more useful. The index grows organically — not in one expensive pass, but street by street as people actually walk them.

### When to use the map, when to use your eyes

| scenario | use | why |
|----------|-----|-----|
| Starting fresh — map is blank | **Look around. Read files directly.** | A blank map doesn't help. Label the first few streets yourself |
| Don't know which file to open | **mdMap** `find --search --type` | Check the map first, then walk |
| Already know the file path | **Open it directly** | You don't need a map to go to a place you already know |
| `find` returns empty | **Scan the directory. Pick by filename.** | The map doesn't have labels for this area yet. Walk there and label it |
| You read a document (for any task) | **Update the map afterward** | If the map is missing info you now know — type, summary, triggers — write it in |
| Creating a new document | **Create the file, then update the map** | Add its entry to mdMap.json with semantic fields filled in |
| Check if the map is consistent | **mdMap** `validate` | Are there streets on the map that don't exist? Links pointing nowhere? |
| See what changed | **mdMap** `changed` | New streets appeared? Old ones demolished? |
| `find` works and returns results | **Trust it. Open the document it suggests.** | The map is populated. Use it |

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
mdmap validate          # orphans, broken links, cycles, stale refs
mdmap validate --strict # CI gate
```

### Tracking changes

```bash
mdmap changed           # what changed since the last index
```
