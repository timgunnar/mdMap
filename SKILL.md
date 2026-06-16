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

You are a person with a map, walking real terrain.

| element | what it is | in mdMap |
|---------|-----------|---------|
| the terrain | real geography — what you walk through | `.md` files on disk |
| the map | a flat representation of the terrain — streets, labels, notes | `mdMap.json` |
| the cartography tools | instruments that create, compare, and check maps | `mdmap init / changed / validate / find` |
| you | the person who walks, reads, judges, annotates | the Agent |

**The tools don't walk the terrain.** They produce maps from directory scans, compare map versions against disk, check the map's internal consistency, look things up. Zero LLM. Structural only.

**The map doesn't walk the terrain either.** It's a flat artifact — what you annotated last time you were here. It might be accurate, outdated, blank, or wrong.

**You walk the terrain.** You read actual .md files. You compare what you see against what the map says. You decide whether the map needs updating.

---

### Decision 1: should I consult the map?

```
┌─────────────────────────────────┐
│ Do you already know which file  │
│ to open?                        │
└────────────┬────────────────────┘
             │
     ┌───────┴───────┐
     │ yes           │ no
     ▼               ▼
  Open it        ┌─────────────────────────┐
  directly.      │ Is the map likely to    │
                 │ have labels here?        │
                 │ (have you/others walked  │
                 │  these streets before?)  │
                 └──────────┬──────────────┘
                            │
                    ┌───────┴───────┐
                    │ probably      │ probably
                    │ populated     │ blank
                    ▼               ▼
              query the map:   walk freely:
              mdmap find       scan dir,
              --search         pick by
                               filename
```

**When to skip the map entirely:**
- You know the exact path. You've been there before.
- The project just finished `mdmap init` — everything is blank.
- You tried `find` and got nothing — the map doesn't cover this area.

**When to consult the map:**
- You don't know which file to open for a task.
- You need to find all documents that constrain a particular activity (`--type rule`).
- You want to know if a document has been deprecated or is still active.
- Multiple agents have been working here — others may have labeled streets you haven't walked.

---

### Decision 2: after reading a document, should I update the map?

You read a document for any reason — a task, curiosity, a `find` result. After reading, ask:

```
┌─────────────────────────────────────┐
│ Is the document already in          │
│ mdMap.json?                         │
└────────────┬────────────────────────┘
             │
     ┌───────┴───────┐
     │ no            │ yes
     ▼               ▼
  Update the     ┌─────────────────────────────────────┐
  map. It's      │ Does what you just read MATCH        │
  a new place.   │ what the map says about it?          │
                 │                                      │
                 │ Check: title, type, summary,          │
                 │ status, triggers, maintains,          │
                 │ retires, links                        │
                 └──────────────┬──────────────────────┘
                                │
                        ┌───────┴───────┐
                        │ matches       │ doesn't match
                        ▼               ▼
                   Do nothing.      Update the map.
                   The map is       Fix what's wrong.
                   already          The terrain has
                   accurate.        changed since the
                                    last annotation.

                   Exception:       Exception:
                   if the document   if the document
                   was blank in      was marked
                   the map (fresh    [active] but
                   after init),      you found a note
                   fill it in        saying it was
                   even if you       superseded → set
                   think the         it to [deprecated].
                   content is
                   obvious.
```

**When to update:** the map is missing the document entirely, the map has empty fields (fresh after init), the map's type/summary/status/triggers don't match what you just read, the document references other documents the map doesn't link to, the document says it was superseded but the map says active.

**When NOT to update:** the map already accurately describes the document. You read it, confirmed everything the map says, learned nothing that contradicts the map. Not every visit requires a map annotation — only when you discover a discrepancy or complete a blank entry.

---

### Decision 3: what if the map and terrain disagree?

Sometimes the map is outright wrong — not just incomplete.

| the map says | but the terrain shows | what happened | what to do |
|-------------|----------------------|---------------|-----------|
| "auth_v3.md" (status: active) | doc body says "Superseded by auth_v4.md" | someone updated the doc but not the map | set auth_v3 → deprecated, add retires reason |
| "rules.md" (type: checklist) | doc body is all constraints and policies | wrong type classification | change type → rule |
| trigger: "publishing" | doc is actually about deployment, not publishing | trigger is misleading | replace trigger with accurate keywords |
| links → "old_design.md" | old_design.md doesn't exist on disk | link target was deleted | remove or update the link |
| doc is in map but file doesn't exist on disk | — | file was deleted/moved without updating map | run `mdmap init` to re-sync, or `mdmap validate` to detect |

**You catch these discrepancies by walking.** The map can't tell you it's wrong — only the terrain can. Every time you open a document, you're validating the map against reality.

**The tools catch some of them too:**
- `mdmap validate` finds: files on disk not in map (orphans), map entries pointing to missing files, links to deprecated docs, link cycles.
- `mdmap changed` finds: files added to or removed from disk since last `init`.

---

### Decision 4: how does the map improve over time?

The map gets better every time someone walks a street they haven't walked before.

```
Day 1: mdmap init → 200 blank entries
       Agent A walks 5 streets, labels them
       Map: 5 labeled, 195 blank

Day 2: Agent B walks 3 of the same streets → confirms labels are still accurate
       Agent B walks 7 new streets → labels them
       Map: 12 labeled, 188 blank

Day 3: Agent A walks a street it labeled on Day 1
       → doc was updated since Day 1 → summary no longer matches
       → Agent A updates the map
       Map: 12 labeled (1 updated), 188 blank

Day N: 80 streets labeled. find --search is genuinely useful.
       120 still blank — but they're blank because nobody needed them yet.
```

**Don't batch-label the entire map.** Only label streets you actually walk. A street nobody needs is fine being blank. When someone finally needs it, they'll walk it and label it then.

**Multiple agents share the map.** What Agent A labeled yesterday, Agent B benefits from today. What Agent B discovers is wrong, Agent A won't trip over tomorrow.

---

### Summary: every scenario

| scenario | what you do |
|----------|------------|
| Map is blank, you need to find a doc | Scan the directory yourself. Pick by filename. Read the best candidate. Label it on the map. |
| Map has labels, you need to find a doc | `mdmap find --search "..." --type rule`. Read the top result. |
| find returns empty (map doesn't cover this area) | Scan the directory yourself. Pick by filename. After reading, label the map. |
| find returns a result, you read the doc | Compare doc content against map metadata. If they match → done. If they don't → update the map. |
| You already know the file path | Open it directly. No need to consult the map. After reading, still check: does the map accurately describe this place? |
| You read a doc and it references other docs | Update the map's `links` field. Future agents searching for this doc will discover those connections without opening it. |
| You create a new .md file | Add its entry to mdMap.json with full semantic fields. Don't wait for `init` to pick it up as a blank entry. |
| `mdmap validate` reports orphans | New files exist on disk but aren't in the map. Read them, add entries to mdMap.json. |
| `mdmap validate` reports broken links | A document links to something that doesn't exist. Check the terrain — was the target deleted? Moved? Fix or remove the link. |
| `mdmap validate` reports stale links | A document links to a deprecated/archived doc. Should the link be updated to the replacement? |
| `mdmap validate` reports cycles | Documents link to each other in a loop. Usually a mistake — fix the link structure. |
| `mdmap changed` reports new files | Someone added .md files to disk. Read them, add entries to mdMap.json. |
| `mdmap changed` reports deleted files | Files removed from disk. Run `mdmap init` to clean up the map, or manually remove the entries. |
| You suspect the map is out of sync | Run `mdmap changed`. It tells you exactly what differs between disk and the last `init`. |
| The map says [deprecated], you need the current version | Read the deprecated doc to find what superseded it. Then follow that link. Update the map if the link is missing. |
| The map has incomplete info for a doc you're reading | Fill in the missing fields. Even partial updates help: just adding a summary is better than blank. |

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
