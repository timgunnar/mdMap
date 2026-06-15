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

## How trigger matching works

`--trigger`, `--maintains`, and `--retires` use **substring matching** against the text stored in the index. They are not semantic — they do not understand synonyms or paraphrasing on their own.

**Your job is to translate the user's intent into short, high-probability keywords.** For example, when a user says "help me publish this to GitHub" or "I want to push a release":

```bash
# ✅ Good — extract the core keyword and try a few variations
mdmap find --trigger "publish"
mdmap find --trigger "release"
mdmap find --trigger "github"

# ❌ Bad — using the full user sentence as-is
mdmap find --trigger "help me publish this to GitHub"
```

If the first query returns nothing, try one or two synonyms before giving up. The trigger text in the index should have been written with diverse keywords by the LLM that filled it — so short, common keywords usually match.

## Commands you will use

### Finding documents

```bash
# Exact lookup (O(1)) — you know the path
mdmap find docs/architecture/auth_v3.md

# Read trigger — "what document covers what I'm doing right now?"
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
