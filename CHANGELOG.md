# Changelog

All notable changes to mdMap are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-06-16

### Added

- `init <dir>` — scan directory, create mdMap.json + SCHEMA.md skeleton
- `find <path>` — exact document lookup by path (O(1))
- `find --trigger <text>` — find documents by read-trigger condition
- `find --maintains <text>` — find documents by update-trigger condition
- `find --retires <text>` — find documents by retirement-trigger condition
- `find --type <text>` — filter by document type
- `find --tag <text>` — filter by tag
- `find --json` — machine-readable output mode
- `validate` — 5 integrity checks: disk↔index bidirectional, file move detection, broken links, link cycles, stale links
- `validate --fix` — auto-fix file moves in mdMap.json
- `validate --strict` — treat warnings as errors (CI gate)
- `changed` — detect added, modified, moved, and deleted documents since last index
- Structured document model: title, type, summary, positioning, status, tags, links, triggers, maintains, retires
- SCHEMA.md — LLM-readable field reference for maintaining the index
- `_ext` field — transparent passthrough for project-specific extensions
- Cross-platform Go binary, zero dependencies

[0.0.1]: https://github.com/timgunnar/mdMap/releases/tag/v0.0.1
