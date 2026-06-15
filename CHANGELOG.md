# Changelog

All notable changes to mdMap are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-06-16

### Added

- `init <dir>` — idempotent two-way sync: add new, remove deleted, update hashes for modified files. Never overwrites existing type/summary/links/triggers metadata. Git-aware: uses `git ls-files` when repo detected; falls back to filesystem walk. ≥50KB files automatically marked `status: "unread"` (title only, no hash, no content read — zero token cost)
- `find <path>` — exact document lookup by path (O(1))
- `find --search <text>` — substring filter across semantic fields (title, summary, positioning)
- `find --trigger <text>` — find documents by read-trigger condition
- `find --maintains <text>` — find documents by update-trigger condition
- `find --retires <text>` — find documents by retirement-trigger condition
- `find --type <text>` — filter by document type (rule, resource, or project-specific)
- `find --tag <text>` — filter by tag (exact match)
- `find --status <text>` — filter by status (active, deprecated, draft, archived, unread)
- `find --json` — machine-readable output mode
- `validate` — 5 integrity checks: disk↔index bidirectional, file move detection, broken links, link cycles, stale links
- `validate --fix` — auto-fix file moves in mdMap.json
- `validate --strict` — treat warnings as errors (CI gate)
- `changed` — detect added, modified, moved, and deleted documents since last index
- Structured document model: title, type, summary, positioning, status, tags, links, triggers, maintains, retires
- Predefined types: `rule` (constraint documents agents must follow), `resource` (standalone reference)
- Predefined statuses: `active`, `deprecated`, `draft`, `archived`, `unread` (large files, lazy-indexed)
- Progressive indexing: `unread` documents get indexed when an agent first reads them — not at init time
- Streaming I/O: `extractTitle` uses `bufio.Scanner`, `computeHash` uses `io.Copy` → `md5.New`. Won't OOM on large files
- SCHEMA.md — LLM-readable field reference for maintaining the index, includes predefined enums
- `_ext` field — transparent passthrough for project-specific extensions
- Cross-platform Go binary, zero dependencies

[0.0.1]: https://github.com/timgunnar/mdMap/releases/tag/v0.0.1
