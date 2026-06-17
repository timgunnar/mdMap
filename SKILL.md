---
name: "mdMap"
description: "Markdown document map. Triggers when user mentions mdMap, document map, mdmap sync, mdmap find, find docs, or updating the map. Reviews recently-read documents and updates mdMap.json annotations. All commands read-only except sync."
---

# mdMap — Markdown Document Map

mdMap is a zero-dependency CLI that builds a structured JSON index of your markdown files — letting agents search by type, status, and semantic content without opening wrong documents.

> **Markdown document index and query engine. Tell it what you're doing — find the right doc without burning LLM context on the wrong ones.**

## ⚠️ Mandatory Rule: Update At Task Milestones

**At the end of each task milestone** (a multi-step operation completes, a standalone task wraps up, before ending a conversation), review all .md files read during this task phase and update:

1. **Is it in mdMap.json?** → Not found: add to mdMap.json with title/summary/type/status/triggers filled
2. **Are fields empty?** → title/summary/type/status blank → fill them in
3. **Is info stale?** → what you just read conflicts with the map → update

**Trigger threshold**: ≥3 .md files read → must execute one batch update. Do this before completing the task, not after every single Read.

> Don't batch-label the entire map. Only update documents you actually read during this task. Empty fields aren't bugs — nobody needed that building yet.

## Why this exists

### The pre-map era: how agents find documents today

There's a project with hundreds of `.md` files. An agent needs to find the publishing guide. Here's what actually happens:

**Step 1 — grep the contents.** The agent has access to grep. Not just filenames — file **contents**. It runs `grep -rl "publish" docs/` which searches every line of every file for the word "publish" and returns the paths of matching files:

```
publish_checklist.md           ← exactly right
auth_v3.md                     ← contains "publish token..." somewhere
architecture_overview.md       ← mentions "after publish..."
meeting_notes_2026-05.md       ← "discussed publish flow timeline"
deploy_guide.md               ← "similar to publish flow"
release_guide.md               ← the actual publishing guide, but this file never says "publish" — it says "release"
```

The agent gets 20 paths back. Some are perfect matches. Some are documents that mention the word once in passing. One critical document — `release_guide.md` — is completely invisible because it uses different vocabulary. This is **vocabulary mismatch**: the agent searches for "publish", the document talks about "release".

**Step 2 — open the candidates, one by one.** The agent can't tell which of these 20 files are relevant from grep output alone. grep returns paths (or at best, fragmented matching lines out of context). The agent must open each promising file to check:

```
Read(auth_v3.md)              → authentication doc, one mention of "publish token" → close. -2K tokens.
Read(architecture_overview.md) → architecture doc, passing reference → close. -1.5K tokens.
Read(deploy_guide.md)          → deployment guide, "similar to publish flow" → close. -2K tokens.
Read(publish_checklist.md)     → YES, this is the publishing guide → read fully. -3K tokens.
```

Three wrong doors opened, one right one found. 5.5K tokens spent on doors that didn't contain what the agent needed.

**Step 3 — follow the hidden signposts.** Inside `publish_checklist.md`, the agent reads: *"Before publishing, check the security policy in security_policy.md."* And: *"If you're releasing to GitHub, see release_guide.md."* The agent opens those too. Another 4K tokens. These cross-references were trapped inside the document — invisible until the agent opened it.

**Step 4 — repeat everything next session.** Agent B starts a similar task tomorrow. grep "publish" → 20 paths → open 4 files → 10K tokens burned. No knowledge from Agent A's session carries over. Every agent reinvents the same navigation, every time.

**The numbers.** For a typical documentation navigation task:

| phase | tokens burned | what the agent actually needed |
|-------|-------------|-------------------------------|
| grep | ~200 | paths — only clues |
| open wrong files | ~5,500 | nothing useful |
| follow cross-refs | ~4,000 | useful, but discovered by accident |
| read the right files | ~3,000 | the actual goal |
| **total** | **~12,700** | **only 3,000 was useful content** |

~76% of context spent on navigation. The agent isn't guessing from filenames — it's reading. It's just reading the wrong things first, over and over.

### The revolution

mdMap replaces this entire workflow with a single lookup:

```
mdmap find --search "publishing"
# [checklist]  publish_checklist.md  — Step-by-step guide for releasing tools to GitHub
# [rule]       security_policy.md    — Security requirements for all releases
# [checklist]  release_guide.md      — Full release procedures (GitHub releases, changelog, npm)
```

One command. Three results. The agent reads the summaries inline — `publish_checklist.md` is exactly what it needs. It opens that file directly. Zero wrong doors.

But look at the third result: `release_guide.md`. A grep for "publish" would never have found it — the word "publish" doesn't appear anywhere in that file. mdMap found it because a previous agent read the document, understood that it was about **releasing**, and annotated it with the trigger keyword "publishing a tool". The agent bridged the vocabulary gap between how people search and how documents are written.

Here's what mdMap adds to every result that grep can't provide:

| grep returns | mdMap returns |
|-------------|--------------|
| raw file path | path + **type tag** (`[rule]`, `[checklist]`) — you know the document's role at a glance |
| fragmented matching lines | **one-sentence summary** — you know what the document is about without opening it |
| no status information | **status label** (`[deprecated]`, `[draft]`, `[archived]`) — you know whether to read it or skip it |
| no relationship data | **links** — the map tracks which documents point to which, all visible without entering any of them |
| no knowledge accumulation | **cumulative index** — Agent A's annotation benefits Agent B, C, D forever |

And it gets better with every agent who walks through. Agent A filled in publish_checklist.md's triggers. Agent B added the link to security_policy.md. Agent C discovered auth_v2.md was deprecated and marked it. The index grows organically — not in one expensive pass, but document by document as agents encounter them during real work.

The terrain — your `.md` files — is untouched. The Go CLI (`sync`, `find`, `validate`, `changed`) makes the card, queries it, checks it. Agents annotate it. You can still grep if you want. You can still read files directly. But you no longer have to spend 76% of your context window on navigation.

## The rule

**mdMap is a lookup tool, not a recommendation engine.**

When you query the map:

```
mdmap find --type rule --search "publishing"
```

mdMap returns **every record that matches your conditions**. Each result is a full row: path, type, status, summary, title, tags — everything the map knows about that document. Like SQL: `SELECT * FROM docs WHERE type='rule' AND (title LIKE '%publishing%' OR summary LIKE '%publishing%')`.

**mdMap does no sorting, no ranking, no recommendation.** The order of results has no meaning. There is no "top match", no "best result". The map returns raw data — the same way a database returns rows.

**You read every returned summary. You decide.** After looking at all returned rows, you judge which document (or documents) to open. You might open one. You might open three. You might read none — the summaries were enough to determine that none of these documents are what you need. In that case, the map doesn't cover this area yet — you scan the directory yourself, read promising files, and label the map afterward.

**The map is a filter, not a guide.** It narrows the ocean of `.md` files to the set that match your conditions. Everything after that — which door to open, how many to enter, what order to walk in — is your judgment.

## How the map was made

Someone ran `mdmap sync` — the cartography tool that scans every street and draws a blank map. Every building appears as an empty entry: it exists on the terrain, but the map says nothing about it.

Then agents walked the streets. Each time someone entered a building, they annotated the map: what flag color it should have, what condition plaque, what signs are on the door, what other buildings it points to. The map filled in street by street.

The map lives in `mdMap.json`. The legend (what each field means, which flag colors and plaques are valid) is part of this skill doc. Never read the full `mdMap.json` — always query it through the CLI.

## The map's hidden power: signs and connections

Two features make the map more useful than the terrain alone:

**Signs (triggers, maintains, retires).** When someone walks into a building, they read the signs on the wall — *"come here if you're publishing"*, *"review this if auth changed"*. They copy those signs onto the map. Now you can search for "publishing" and find the building without ever entering it or any of its neighbors. Every sign that was once trapped inside a document is now indexed on the surface.

**Connections (links).** Buildings contain directions to other buildings — *"before publishing, see security_policy.md"*, *"superseded by auth_v4.md"*. Someone who entered the building recorded those connections on the map. Now you can trace the entire road network without walking it — see which buildings point where, spot dead-end links, detect circular references.

```bash
# Signs on doors — searchable without entering
mdmap find --trigger "publishing"     # "which buildings say 'come here if you're publishing'?"
mdmap find --maintains "auth changed" # "which buildings should be reviewed after auth changes?"
mdmap find --retires "CLI deprecated" # "which buildings are obsolete now?"

# The map itself tracks connections
mdmap validate  # checks: Are there signs pointing to demolished buildings?
                #         Are buildings linked in circles?
                #         Are buildings missing from the map entirely?
```

## How to query the map

`mdmap find` is a map lookup. Each flag is a dimension you filter by. The result is a set of full records — like SQL rows.

```
Find every record where type=rule AND title/summary contains "publishing".

  --type rule     document type (rule, checklist, guide…)
  --search "pub"   substring match on title, summary, positioning
```

The underlying engine is equivalent to SQL: exact fields use `=` filtering, semantic fields use `LIKE` substring matching. Every row that passes all conditions is returned. No ordering, no ranking.

```bash
mdmap find --type rule --search "project a"
# [rule]  project_a_publish.md  — Publishing rules for project-a: GitHub releases
# [rule]  project_b_publish.md  — Publishing rules for project-b: npm publish

# You read both summaries. project_a_publish.md matches your task → open it.
```

**You evaluate all returned rows.** The map gives you the data — path, type, status, summary — for every matching document. You read all the summaries and decide which documents to open. You make all the judgment calls. The map is a filter, not a curator.

**Why triggers are separate from search:**

| flag | what it queries | metaphor |
|------|----------------|----------|
| `--search` | title, summary, positioning | the label on the building and its one-line description |
| `--trigger` | the `triggers` list | the signs copied from the door ("come here if you're publishing") |
| `--maintains` | the `maintains` list | the signs about maintenance ("come here if auth changed") |
| `--retires` | the `retires` list | the signs about retirement ("come here if CLI development stopped") |
| `--type` | document type | building category flag color |
| `--status` | document status | building condition plaque |
| `--tag` | tags | freeform markers on the building |

Search scans what the building IS. Trigger/Maintains/Retires scan what the signs SAY. Different dimensions, same map.

## Building categories

Every building on the map has a colored flag. Two flag colors are mandatory:

| flag | meaning | rule |
|------|---------|------|
| **`rule`** (red flag) | this building constrains HOW work must be done | **Must enter.** Skipping it means you're not complying with project standards. Examples: coding standards, security policies, architectural principles |
| **`resource`** (blue flag) | standalone long-form content, no connections to other buildings | **Enter if curious.** It doesn't constrain your behavior. Examples: novel chapters, world-building docs, historical reference notes |

Other flag colors emerge from the project: `checklist`, `architecture`, `guide`, `api_spec`, `meeting_notes`, etc. When you label a building, reuse existing flag colors for consistency.

The map shows the flag inline:

```bash
mdmap find --search "auth"
# [rule]        security_policy.md    — API authentication security policy — must comply
# [checklist]   auth_migration.md     — Authentication migration checklist
# [resource]    auth_history.md       — History of OAuth protocol evolution
```

**Red flag (`rule`) = open first. Blue flag (`resource`) = open only if you need reference.**

## Building condition

Every building has a condition plaque. Four plaques are mandatory:

| plaque | meaning | what to do |
|--------|---------|-----------|
| **`active`** | operational, current, authoritative | **Enter. This is the one to read.** |
| **`deprecated`** | condemned — replaced or no longer applicable | **Do not enter as primary reference.** The map shows `[deprecated]` warning. Enter only to find what replaced it. |
| **`draft`** | under construction — content may change | **Enter for direction only.** Not final authority. |
| **`archived`** | historical landmark — kept for record | **Do not enter unless explicitly asked.** Not part of the active knowledge graph. |

`active` is not printed (it's the default — no noise). Non-active plaques are shown:

```bash
mdmap find --search "auth migration"
# [checklist]   auth_migration_v3.md   — Current auth migration checklist (v3)
# [checklist]  [deprecated]  auth_migration_v2.md  — Old checklist (v2)
# [guide]      [draft]  auth_migration_v4.md  — New guide (drafting)
```

## Two-track architecture

You are a person with a map, walking real terrain.

| element | what it is | in mdMap |
|---------|-----------|---------|
| the terrain | real geography — what you walk through | `.md` files on disk |
| the map | a flat representation of the terrain — streets, labels, notes | `mdMap.json` |
| the cartography tools | instruments that create, compare, and check maps | `mdmap sync / changed / validate / find` |
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
              --search         read files
                               directly
```

**When to skip the map entirely:**
- You know the exact path. You've been there before.
- The project just finished `mdmap sync` — everything is blank.
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
                   after sync),      you found a note
                   fill it in        saying it was
                   even if you       superseded → set
                   think the         it to [deprecated].
                   content is
                   obvious.
```

**When to update:** the map is missing the document entirely, the map has empty fields (fresh after sync), the map's type/summary/status/triggers don't match what you just read, the document references other documents the map doesn't link to, the document says it was superseded but the map says active.

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
| doc is in map but file doesn't exist on disk | — | file was deleted/moved without updating map | run `mdmap sync` to re-sync, or `mdmap validate` to detect |

**You catch these discrepancies by walking.** The map can't tell you it's wrong — only the terrain can. Every time you open a document, you're validating the map against reality.

**The tools catch some of them too:**
- `mdmap validate` finds: files on disk not in map (orphans), map entries pointing to missing files, links to deprecated docs, link cycles.
- `mdmap changed` finds: files added to or removed from disk since last `sync`.

---

### Decision 4: how does the map improve over time?

The map gets better every time someone walks a street they haven't walked before.

```
Day 1: mdmap sync → 200 blank entries
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
| Map is blank, you need to find a doc | Scan the directory yourself. Read promising files. Label them on the map afterward. |
| Map has labels, you need to find a doc | `mdmap find --search "..." --type rule`. Review all returned summaries. Decide which to open. |
| find returns empty (map doesn't cover this area) | Scan the directory yourself. Read promising files. After reading, label the map. |
| find returns results, you review them | Read all summaries. Decide which documents to open (could be one, could be several). Then read them. |
| You already know the file path | Open it directly. No need to consult the map. After reading, still check: does the map accurately describe this place? |
| You read a doc and it references other docs | Update the map's `links` field. Future agents searching for this doc will discover those connections without opening it. |
| You create a new .md file | Add its entry to mdMap.json with full semantic fields. Don't wait for `sync` to pick it up as a blank entry. |
| `mdmap validate` reports orphans | New files exist on disk but aren't in the map. Read them, add entries to mdMap.json. |
| `mdmap validate` reports broken links | A document links to something that doesn't exist. Check the terrain — was the target deleted? Moved? Fix or remove the link. |
| `mdmap validate` reports stale links | A document links to a deprecated/archived doc. Should the link be updated to the replacement? |
| `mdmap validate` reports cycles | Documents link to each other in a loop. Usually a mistake — fix the link structure. |
| `mdmap changed` reports new files | Someone added .md files to disk. Read them, add entries to mdMap.json. |
| `mdmap changed` reports deleted files | Files removed from disk. Run `mdmap sync` to clean up the map, or manually remove the entries. |
| You suspect the map is out of sync | Run `mdmap changed`. It tells you exactly what differs between disk and the last `sync`. |
| The map says [deprecated], you need the current version | Read the deprecated doc to find what superseded it. Then follow that link. Update the map if the link is missing. |
| The map has incomplete info for a doc you're reading | Fill in the missing fields. Even partial updates help: just adding a summary is better than blank. |

## The cartography toolkit

```bash
# Create the map — scan every street, draw blank entries
mdmap sync ./docs

# Query the map — find buildings by flag, plaque, signs, labels
mdmap find --type rule --search "publishing"
mdmap find --trigger "publishing a CLI tool"
mdmap find --type checklist --tag "publish"
mdmap find docs/architecture/auth_v3.md      # look up by address
mdmap find --trigger "auth" --json           # machine-readable output

# Health check — is the map consistent with the terrain?
mdmap validate          # orphans, broken links, cycles, stale refs
mdmap validate --strict # CI gate (warnings become errors)

# Terrain diff — what changed since the last map was drawn?
mdmap changed           # new buildings, demolished buildings
```
