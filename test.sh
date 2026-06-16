#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
CYAN='\033[0;36m'

pass_count=0
fail_count=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; pass_count=$((pass_count+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; fail_count=$((fail_count+1)); }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/mdmap"
TESTDIR="$SCRIPT_DIR/testdata"
DOCSDIR="$TESTDIR/docs"

rm -rf "$TESTDIR"
mkdir -p "$DOCSDIR"

echo -e "${CYAN}=== Building mdmap ===${NC}"
(cd "$SCRIPT_DIR" && go build -o "$BIN" .)
echo "  build ok"

rundir() { (cd "$DOCSDIR" && "$@"); }

# ============================================================
# Test: init
# ============================================================
echo -e "\n${CYAN}=== 1. init ===${NC}"

cat > "$DOCSDIR/architecture.md" << 'EOF'
# Architecture Overview

The system follows a layered architecture.

For authentication details, see auth_v3.md.
EOF

cat > "$DOCSDIR/auth_v3.md" << 'EOF'
# Authentication v3 Design

This document describes the auth system.
If you are publishing a new tool, consult the publish checklist.
EOF

cat > "$DOCSDIR/publish_checklist.md" << 'EOF'
# Publishing Checklist

Step-by-step guide for releasing tools.
EOF

cat > "$DOCSDIR/deprecated_migration.md" << 'EOF'
# Old Migration Guide

This is obsolete.
EOF

"$BIN" init "$DOCSDIR" > /dev/null

if [ -f "$DOCSDIR/mdMap.json" ]; then pass "mdMap.json created"; else fail "mdMap.json not created"; fi
if [ -f "$DOCSDIR/SCHEMA.md" ]; then pass "SCHEMA.md created"; else fail "SCHEMA.md not created"; fi

doc_count=$(python3 -c "import json; d=json.load(open('$DOCSDIR/mdMap.json')); print(len(d['docs']))")
if [ "$doc_count" = "4" ]; then pass "init found 4 documents"; else fail "init found $doc_count docs (expected 4)"; fi

has_schema=$(python3 -c "import json; d=json.load(open('$DOCSDIR/mdMap.json')); print('SCHEMA.md' in d['docs'])")
if [ "$has_schema" = "False" ]; then pass "SCHEMA.md excluded from index"; else fail "SCHEMA.md should not be indexed"; fi

has_updated=$(python3 -c "import json; d=json.load(open('$DOCSDIR/mdMap.json')); print(bool(d.get('_updated')))")
if [ "$has_updated" = "True" ]; then pass "_updated timestamp set"; else fail "_updated missing"; fi

# ============================================================
# Test: inject semantic data
# ============================================================
echo -e "\n${CYAN}=== 2. Semantic data injection ===${NC}"

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f:
    m = json.load(f)
docs = m["docs"]

docs["architecture.md"].update({
    "type": "architecture", "summary": "Layered system architecture",
    "positioning": "Foundation document for all design decisions",
    "status": "active", "tags": ["architecture", "system"],
    "triggers": ["designing a new module", "understanding system layout"],
    "maintains": ["new module added", "architectural pattern change"],
    "links": [{"to": "auth_v3.md", "why": "For auth module details"}]
})
docs["auth_v3.md"].update({
    "type": "design_proposal", "summary": "Authentication system design v3",
    "positioning": "Defines auth tokens and sessions",
    "status": "active", "tags": ["auth", "security"],
    "triggers": ["modifying auth logic", "adding OAuth", "auditing security"],
    "maintains": ["token format changes", "new auth method added"],
    "retires": ["auth system rewritten from scratch"]
})
docs["publish_checklist.md"].update({
    "type": "checklist", "summary": "Complete CLI publishing checklist",
    "positioning": "Must-read before any release",
    "status": "active", "tags": ["publish", "checklist"],
    "triggers": ["publishing a CLI tool", "preparing a GitHub release", "publishing to npm"],
    "maintains": ["new publishing requirement", "GitHub changed release flow"],
    "retires": ["project stopped building CLI tools"],
    "links": [{"to": "architecture.md", "why": "Release process follows system architecture"}, {"to": "auth_v3.md", "why": "If release includes auth changes"}]
})
docs["deprecated_migration.md"].update({
    "type": "guide", "summary": "Old migration guide for v1 to v2",
    "positioning": "Historical reference only",
    "status": "deprecated", "tags": ["migration", "legacy"],
    "retires": ["all users migrated past v2"]
})
with open("$DOCSDIR/mdMap.json", "w") as f:
    json.dump(m, f, indent=2, ensure_ascii=False)
PYEOF
pass "semantic data injected"

# ============================================================
# Test: find — exact lookup
# ============================================================
echo -e "\n${CYAN}=== 3. find — exact lookup ===${NC}"

result=$(rundir "$BIN" find architecture.md 2>&1)
if echo "$result" | grep -q "Architecture Overview"; then pass "find by path returns title"; else fail "find by path: $result"; fi

jsonout=$(cd "$DOCSDIR" && "$BIN" find architecture.md --json 2>/dev/null)
if [ -n "$jsonout" ] && echo "$jsonout" | grep -q 'architecture'; then pass "find --json valid"; else fail "find --json invalid"; fi

# ============================================================
# Test: find — trigger search
# ============================================================
echo -e "\n${CYAN}=== 4. find — trigger search ===${NC}"

result=$(rundir "$BIN" find --trigger "publishing" 2>&1)
if echo "$result" | grep -q "publish_checklist.md"; then pass "find --trigger 'publishing' hits checklist"; else fail "trigger missed: $result"; fi

result=$(rundir "$BIN" find --trigger "security" 2>&1)
if echo "$result" | grep -q "auth_v3.md"; then pass "find --trigger 'security' hits auth"; else fail "trigger missed: $result"; fi

# ============================================================
# Test: find — filters
# ============================================================
echo -e "\n${CYAN}=== 5. find — filters ===${NC}"

result=$(rundir "$BIN" find --type checklist 2>&1)
if echo "$result" | grep -q "publish_checklist.md" && [ "$(echo "$result" | wc -l | tr -d ' ')" = "1" ]; then
  pass "find --type checklist returns 1 doc"
else fail "find --type checklist: $result"; fi

result=$(rundir "$BIN" find --tag publish 2>&1)
if echo "$result" | grep -q "publish_checklist.md"; then pass "find --tag publish works"; else fail "find --tag publish: $result"; fi

# ============================================================
# Test: find --search (substring + combo)
# ============================================================
echo -e "\n${CYAN}=== 5b. find --search (substring filter) ===${NC}"

result=$(rundir "$BIN" find --search "publishing" 2>&1)
if echo "$result" | grep -q "publish_checklist.md"; then pass "--search 'publishing' hits checklist"; else fail "--search missed: $result"; fi

result=$(rundir "$BIN" find --search "publishing" 2>&1)
if echo "$result" | grep -q " — "; then pass "--search output has summary"; else fail "--search no summary: $result"; fi

result=$(rundir "$BIN" find --search "architecture" 2>&1)
if echo "$result" | grep -q "architecture.md"; then pass "--search 'architecture' hits architecture.md"; else fail "--search missed arch: $result"; fi

result=$(rundir "$BIN" find --type checklist --search "publishing" 2>&1)
if [ "$(echo "$result" | grep -c 'publish_checklist.md')" -ge 1 ]; then
  pass "--type checklist --search 'publishing' works"
else fail "--type --search combo: $result"; fi

json_result=$(rundir "$BIN" find --search "publishing" --json 2>/dev/null)
if echo "$json_result" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d,list) and len(d)>0 and 'summary' in d[0]" 2>/dev/null; then
  pass "--search --json returns array with summary"
else fail "--search --json: $json_result"; fi

# ============================================================
# Test: validate — clean
# ============================================================
echo -e "\n${CYAN}=== 6. validate — clean ===${NC}"

result=$(rundir "$BIN" validate 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "EXIT:0"; then pass "validate clean exits 0"; else fail "validate clean: $result"; fi

# ============================================================
# Test: validate — orphans
# ============================================================
echo -e "\n${CYAN}=== 7. validate — orphans ===${NC}"

cat > "$DOCSDIR/unregistered.md" << 'EOF'
# Unregistered
EOF
result=$(rundir "$BIN" validate 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "orphans" && echo "$result" | grep -q "unregistered.md"; then pass "validate detects orphans"; else fail "orphan missed: $result"; fi
if echo "$result" | grep -q "EXIT:1"; then pass "validate exits 1 on orphan"; else fail "orphan exit code: $result"; fi
rm "$DOCSDIR/unregistered.md"

# ============================================================
# Test: validate — file move + --fix
# ============================================================
echo -e "\n${CYAN}=== 8. validate — file move + --fix ===${NC}"

mkdir -p "$DOCSDIR/subdir"
mv "$DOCSDIR/auth_v3.md" "$DOCSDIR/subdir/auth_v3.md"

result=$(rundir "$BIN" validate 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "moves"; then pass "validate detects moves"; else fail "move missed: $result"; fi

rundir "$BIN" validate --fix > /dev/null 2>&1 || true
moved=$(python3 -c "import json; d=json.load(open('$DOCSDIR/mdMap.json')); print('subdir/auth_v3.md' in d['docs'])")
[ "$moved" = "True" ] && pass "--fix updated index" || fail "--fix missed: $moved"
old=$(python3 -c "import json; d=json.load(open('$DOCSDIR/mdMap.json')); print('auth_v3.md' in d['docs'])")
[ "$old" = "False" ] && pass "--fix removed old key" || fail "--fix kept old key"

# move back
mv "$DOCSDIR/subdir/auth_v3.md" "$DOCSDIR/auth_v3.md"
rmdir "$DOCSDIR/subdir"
rundir "$BIN" validate --fix > /dev/null 2>&1 || true

# ============================================================
# Test: validate — broken links
# ============================================================
echo -e "\n${CYAN}=== 9. validate — broken links ===${NC}"

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["architecture.md"]["links"].append({"to": "nonexistent.md", "why": "broken"})
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

result=$(rundir "$BIN" validate 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "broken links"; then pass "validate detects broken links"; else fail "broken link missed: $result"; fi

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["architecture.md"]["links"] = [l for l in m["docs"]["architecture.md"]["links"] if l["to"] != "nonexistent.md"]
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

# ============================================================
# Test: validate — stale links
# ============================================================
echo -e "\n${CYAN}=== 10. validate — stale links ===${NC}"

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
d = m["docs"]["auth_v3.md"]
if d.get("links") is None:
    d["links"] = []
d["links"].append({"to": "deprecated_migration.md", "why": "historical"})
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

result=$(rundir "$BIN" validate 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "stale links"; then pass "validate detects stale links"; else fail "stale missed: $result"; fi

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["auth_v3.md"]["links"] = [l for l in m["docs"]["auth_v3.md"]["links"] if l["to"] != "deprecated_migration.md"]
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

# ============================================================
# Test: validate — cycle detection
# ============================================================
echo -e "\n${CYAN}=== 11. validate — cycles ===${NC}"

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["architecture.md"]["links"].append({"to": "publish_checklist.md", "why": "test cycle"})
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

result=$(rundir "$BIN" validate 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "cycles"; then pass "validate detects cycles"; else fail "cycle missed: $result"; fi

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["architecture.md"]["links"] = [l for l in m["docs"]["architecture.md"]["links"] if l["why"] != "test cycle"]
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

# ============================================================
# Test: validate --strict
# ============================================================
echo -e "\n${CYAN}=== 12. validate --strict ===${NC}"

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
d = m["docs"]["auth_v3.md"]
if d.get("links") is None:
    d["links"] = []
d["links"].append({"to": "deprecated_migration.md", "why": "historical"})
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

result=$(rundir "$BIN" validate --strict 2>&1; echo "EXIT:$?")
if echo "$result" | grep -q "EXIT:1"; then pass "validate --strict fails on warnings"; else fail "--strict missed: $result"; fi

python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["auth_v3.md"]["links"] = [l for l in m["docs"]["auth_v3.md"]["links"] if l["to"] != "deprecated_migration.md"]
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

# ============================================================
# Test: changed — new/modified/deleted/moved
# ============================================================
echo -e "\n${CYAN}=== 13. changed — all states ===${NC}"

# rebuild clean index
"$BIN" init "$DOCSDIR" > /dev/null
python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
for k in m["docs"]:
    m["docs"][k]["type"] = "test"
    m["docs"][k]["status"] = "active"
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

# new file (not yet indexed → should show as new)
cat > "$DOCSDIR/new_doc.md" << 'EOF'
# New Document
EOF
result=$(rundir "$BIN" changed 2>&1)
echo "$result" | grep -q "new: new_doc.md" && pass "changed detects new" || fail "changed new: $result"

# add to index so we can test deletion
hash=$(python3 -c "import hashlib; print(hashlib.md5(open('$DOCSDIR/new_doc.md','rb').read()).hexdigest())")
python3 << PYEOF
import json
with open("$DOCSDIR/mdMap.json") as f: m = json.load(f)
m["docs"]["new_doc.md"] = {"title":"New Document","hash":"$hash","type":"test","status":"active"}
with open("$DOCSDIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

# modified
echo "modified" >> "$DOCSDIR/architecture.md"
result=$(rundir "$BIN" changed 2>&1)
echo "$result" | grep -q "modified: architecture.md" && pass "changed detects modified" || fail "changed modified: $result"

# deleted
rm "$DOCSDIR/new_doc.md"
result=$(rundir "$BIN" changed 2>&1)
echo "$result" | grep -q "deleted: new_doc.md" && pass "changed detects deleted" || fail "changed deleted: $result"

# moved
mkdir -p "$DOCSDIR/renamed"
mv "$DOCSDIR/deprecated_migration.md" "$DOCSDIR/renamed/deprecated_migration.md"
result=$(rundir "$BIN" changed 2>&1)
echo "$result" | grep -q "moved:" && pass "changed detects moved" || fail "changed moved: $result"

# cleanup
mv "$DOCSDIR/renamed/deprecated_migration.md" "$DOCSDIR/deprecated_migration.md"
rmdir "$DOCSDIR/renamed"
python3 -c "
open('$DOCSDIR/architecture.md','w').write('# Architecture Overview\n\nThe system follows a layered architecture.\n\nFor authentication details, see auth_v3.md.\n')
"

# ============================================================
# Test: init — unread for large files
# ============================================================
echo -e "\n${CYAN}=== 14. init — unread status ===${NC}"

UNREAD_DIR="$TESTDIR/unread_test"
mkdir -p "$UNREAD_DIR"
echo "# Small Rules" > "$UNREAD_DIR/small_rules.md"
# create a 52KB file (hash=skip, status=unread)
dd if=/dev/zero of="$UNREAD_DIR/big_novel.md" bs=1024 count=52 2>/dev/null
echo "# Big Novel" > "$UNREAD_DIR/big_novel.md"
dd if=/dev/zero bs=1024 count=51 >> "$UNREAD_DIR/big_novel.md" 2>/dev/null

rundir "$BIN" init "$UNREAD_DIR" >/dev/null

is_unread=$(python3 -c "import json; d=json.load(open('$UNREAD_DIR/mdMap.json')); doc=d['docs'].get('big_novel.md',{}); print(doc.get('status',''))")
if [ "$is_unread" = "unread" ]; then pass "large file marked unread"; else fail "large file status: $is_unread (expected unread)"; fi

hash_val=$(python3 -c "import json; d=json.load(open('$UNREAD_DIR/mdMap.json')); doc=d['docs'].get('big_novel.md',{}); print(doc.get('hash',''))")
if [ "$hash_val" = "" ]; then pass "unread doc has empty hash"; else fail "unread doc has hash: $hash_val"; fi

small_status=$(python3 -c "import json; d=json.load(open('$UNREAD_DIR/mdMap.json')); doc=d['docs'].get('small_rules.md',{}); print(doc.get('status',''))")
if [ "$small_status" = "" ]; then pass "small file NOT marked unread"; else fail "small file has status: $small_status"; fi

small_hash=$(python3 -c "import json; d=json.load(open('$UNREAD_DIR/mdMap.json')); doc=d['docs'].get('small_rules.md',{}); print(doc.get('hash','') != '')")
if [ "$small_hash" = "True" ]; then pass "small file has hash"; else fail "small file missing hash"; fi

result=$(rundir "$BIN" find --dir "$UNREAD_DIR" --status unread 2>&1)
if echo "$result" | grep -q "big_novel.md"; then pass "find --status unread works"; else fail "find unread: $result"; fi

rm -rf "$UNREAD_DIR"

# ============================================================
# Test: init — re-run preserves metadata, detects adds/deletes
# ============================================================
echo -e "\n${CYAN}=== 15. init — idempotent resync ===${NC}"

SYNC_DIR="$TESTDIR/sync_test"
mkdir -p "$SYNC_DIR"
echo "# Doc A" > "$SYNC_DIR/a.md"
echo "# Doc B" > "$SYNC_DIR/b.md"
echo "# Doc C" > "$SYNC_DIR/c.md"

rundir "$BIN" init "$SYNC_DIR" >/dev/null
python3 << PYEOF
import json
with open("$SYNC_DIR/mdMap.json") as f: m = json.load(f)
m["docs"]["a.md"]["type"] = "rule"
m["docs"]["a.md"]["summary"] = "Rule A"
m["docs"]["a.md"]["status"] = "active"
with open("$SYNC_DIR/mdMap.json", "w") as f: json.dump(m, f, indent=2)
PYEOF

rm "$SYNC_DIR/b.md"
echo "# Doc D" > "$SYNC_DIR/d.md"

rundir "$BIN" init "$SYNC_DIR" >/dev/null

count=$(python3 -c "import json; d=json.load(open('$SYNC_DIR/mdMap.json')); print(len(d['docs']))")
if [ "$count" = "3" ]; then pass "re-init: 3 docs (b removed, d added)"; else fail "re-init count: $count (expected 3)"; fi

has_d=$(python3 -c "import json; d=json.load(open('$SYNC_DIR/mdMap.json')); print('d.md' in d['docs'])")
if [ "$has_d" = "True" ]; then pass "re-init: d.md added"; else fail "re-init: d.md missing"; fi

has_b=$(python3 -c "import json; d=json.load(open('$SYNC_DIR/mdMap.json')); print('b.md' in d['docs'])")
if [ "$has_b" = "False" ]; then pass "re-init: b.md removed"; else fail "re-init: b.md still present"; fi

meta=$(python3 -c "import json; d=json.load(open('$SYNC_DIR/mdMap.json')); doc=d['docs']['a.md']; print(doc.get('type','')+'|'+doc.get('summary','')+'|'+doc.get('status',''))")
if [ "$meta" = "rule|Rule A|active" ]; then pass "re-init: metadata preserved"; else fail "re-init metadata lost: $meta"; fi

rm -rf "$SYNC_DIR"

# ============================================================
# Test: init — git-ignored files ARE indexed (mdMap owns all md)
# ============================================================
echo -e "\n${CYAN}=== 16. init — git-independent ===${NC}"

IGN_DIR="$TESTDIR/ign_test"
mkdir -p "$IGN_DIR"
echo "# Rules" > "$IGN_DIR/rules.md"
echo "# Long Novel" > "$IGN_DIR/novel.md"
echo "novel.md" > "$IGN_DIR/.gitignore"

rundir "$BIN" init "$IGN_DIR" >/dev/null

has_rules=$(python3 -c "import json; d=json.load(open('$IGN_DIR/mdMap.json')); print('rules.md' in d['docs'])")
if [ "$has_rules" = "True" ]; then pass "gitignored dir: rules.md indexed"; else fail "gitignored: rules.md missing"; fi

has_novel=$(python3 -c "import json; d=json.load(open('$IGN_DIR/mdMap.json')); print('novel.md' in d['docs'])")
if [ "$has_novel" = "True" ]; then pass "gitignored dir: novel.md indexed (ignores .gitignore)"; else fail "gitignored: novel.md missing"; fi

rm -rf "$IGN_DIR"

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${CYAN}=============================${NC}"
echo -e "  ${GREEN}Passed: $pass_count${NC}"
if [ "$fail_count" -gt 0 ]; then
  echo -e "  ${RED}Failed: $fail_count${NC}"
fi
echo -e "${CYAN}=============================${NC}"

# Cleanup
rm -rf "$TESTDIR"
rm -f "$BIN"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
