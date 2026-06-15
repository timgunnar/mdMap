package main

import (
	"crypto/md5"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type Link struct {
	To  string `json:"to"`
	Why string `json:"why"`
}

type Doc struct {
	Title       string                 `json:"title"`
	Type        string                 `json:"type"`
	Summary     string                 `json:"summary"`
	Positioning string                 `json:"positioning"`
	Status      string                 `json:"status"`
	Tags        []string               `json:"tags"`
	Links       []Link                 `json:"links"`
	Triggers    []string               `json:"triggers"`
	Maintains   []string               `json:"maintains"`
	Retires     []string               `json:"retires"`
	Hash        string                 `json:"hash"`
	Ext         map[string]interface{} `json:"_ext,omitempty"`
}

type MapFile struct {
	Schema  string          `json:"_schema"`
	Updated string          `json:"_updated"`
	Root    string          `json:"root"`
	Docs    map[string]*Doc `json:"docs"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "mdMap: markdown document index and query engine. we map your docs, you find them.")
		fmt.Fprintln(os.Stderr, "usage: mdmap <command> [flags]")
		fmt.Fprintln(os.Stderr, "  init <dir>     scan directory, create mdMap.json + SCHEMA.md")
		fmt.Fprintln(os.Stderr, "  find <flags>   search documents by path, search, trigger, type, tag")
		fmt.Fprintln(os.Stderr, "  validate       integrity checks (orphans, broken links, cycles)")
		fmt.Fprintln(os.Stderr, "  changed        show what changed since last index")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "init":
		cmdInit(os.Args[2:])
	case "find":
		cmdFind(os.Args[2:])
	case "validate":
		cmdValidate(os.Args[2:])
	case "changed":
		cmdChanged(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "mdMap: unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}
}

func loadMap(rootDir string) (*MapFile, error) {
	path := filepath.Join(rootDir, "mdMap.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m MapFile
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	if m.Docs == nil {
		m.Docs = make(map[string]*Doc)
	}
	return &m, nil
}

func saveMap(m *MapFile, rootDir string) error {
	m.Updated = time.Now().UTC().Format(time.RFC3339)
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(rootDir, "mdMap.json"), data, 0644)
}

func computeHash(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%x", md5.Sum(data))
}

var h1Pattern = regexp.MustCompile(`^#\s+(.+)$`)

func extractTitle(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		m := h1Pattern.FindStringSubmatch(strings.TrimRight(line, "\r"))
		if len(m) == 2 {
			return strings.TrimSpace(m[1])
		}
	}
	return ""
}

func cmdInit(args []string) {
	flags := flag.NewFlagSet("init", flag.ExitOnError)
	flags.Parse(args)

	rootDir := "."
	if flags.NArg() > 0 {
		rootDir = flags.Arg(0)
	}

	m := MapFile{
		Schema: "1.0",
		Root:   rootDir,
		Docs:   make(map[string]*Doc),
	}

	absRoot, _ := filepath.Abs(rootDir)
	schemaPath := filepath.Join(absRoot, "SCHEMA.md")

	filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}
		if !strings.HasSuffix(info.Name(), ".md") {
			return nil
		}
		absPath, _ := filepath.Abs(path)
		if absPath == schemaPath {
			return nil
		}

		relPath, _ := filepath.Rel(rootDir, path)
		if _, exists := m.Docs[relPath]; exists {
			return nil
		}

		m.Docs[relPath] = &Doc{
			Title: extractTitle(path),
			Hash:  computeHash(path),
		}
		return nil
	})

	if err := saveMap(&m, rootDir); err != nil {
		fmt.Fprintf(os.Stderr, "mdMap: %v\n", err)
		os.Exit(1)
	}

	schema := `# mdMap Schema

## Fields

- **title**: Document title.
- **type**: Document type. Use consistent values across the project — look at existing documents for convention.
- **summary**: One-sentence summary (≤80 chars). Answers "what is this document about".
- **positioning**: One-sentence positioning in the knowledge system. Answers "what role does this document play".
- **status**: Document status. Use consistent values across the project — look at existing documents for convention.
- **tags**: Free-form tags. Reuse existing tags for consistency.
- **links**: Navigation hints found in the document body ("See also", "For details see", "Supersedes", etc.). Each link has a target path and a natural-language reason.
- **triggers**: When should someone read this document? Used for find --trigger queries, which match by substring. Include multiple phrasings covering different ways users might express the same intent. Cover common synonyms and keywords that people who need this document would naturally search for. Example: for a publishing guide, include "publishing a tool", "npm publish", "releasing to GitHub", "shipping a release" — not just one phrasing.
- **maintains**: When should this document be updated? Same substring-matching principle as triggers. Include diverse keywords. Each maintain is one sentence describing a maintenance trigger.
- **retires**: When can this document be safely deprecated? Same substring-matching principle. Each retire is one sentence describing a retirement condition.

## Project Convention

(Will be populated after the first batch of documents is indexed by an LLM.)
`
	os.WriteFile(schemaPath, []byte(schema), 0644)

	fmt.Printf("mdMap: initialized %d documents in %s\n", len(m.Docs), rootDir)
	fmt.Printf("  mdMap.json — document index\n")
	fmt.Printf("  SCHEMA.md  — field reference for LLM maintenance\n")
}

func cmdFind(args []string) {
	flags := flag.NewFlagSet("find", flag.ExitOnError)
	trigger := flags.String("trigger", "", "find by read trigger")
	maintains := flags.String("maintains", "", "find by update trigger")
	retires := flags.String("retires", "", "find by retire trigger")
	search := flags.String("search", "", "BM25 ranked search across all text fields")
	docType := flags.String("type", "", "filter by document type")
	status := flags.String("status", "", "filter by document status")
	tag := flags.String("tag", "", "filter by tag")
	jsonOut := flags.Bool("json", false, "machine-readable output")
	dir := flags.String("dir", ".", "root directory containing mdMap.json")
	flags.Parse(args)

	rootDir := *dir

	m, err := loadMap(rootDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mdMap: %v\n", err)
		os.Exit(1)
	}

	if flags.NArg() > 0 {
		path := flags.Arg(0)
		doc, exists := m.Docs[path]
		if !exists {
			fmt.Fprintf(os.Stderr, "mdMap: document not found: %s\n", path)
			os.Exit(1)
		}
		if *jsonOut {
			data, _ := json.MarshalIndent(doc, "", "  ")
			fmt.Println(string(data))
			return
		}
		printDoc(path, doc)
		return
	}

	if *search != "" {
		scored := bm25Search(m.Docs, *search)
		if *jsonOut {
			data, _ := json.MarshalIndent(scored, "", "  ")
			fmt.Println(string(data))
			return
		}
		top := 20
		if len(scored) < top {
			top = len(scored)
		}
		for i := 0; i < top; i++ {
			fmt.Printf("%.2f  %s\n", scored[i].Score, scored[i].Path)
		}
		return
	}

	var results []string
	for path, doc := range m.Docs {
		if *trigger != "" && !containsAny(doc.Triggers, *trigger) {
			continue
		}
		if *maintains != "" && !containsAny(doc.Maintains, *maintains) {
			continue
		}
		if *retires != "" && !containsAny(doc.Retires, *retires) {
			continue
		}
		if *docType != "" && doc.Type != *docType {
			continue
		}
		if *status != "" && doc.Status != *status {
			continue
		}
		if *tag != "" && !hasTag(doc.Tags, *tag) {
			continue
		}
		results = append(results, path)
	}

	if *jsonOut {
		data, _ := json.MarshalIndent(results, "", "  ")
		fmt.Println(string(data))
		return
	}

	for _, path := range results {
		fmt.Println(path)
	}
}

func printDoc(path string, doc *Doc) {
	fmt.Printf("path: %s\n", path)
	fmt.Printf("title: %s\n", doc.Title)
	if doc.Type != "" {
		fmt.Printf("type: %s\n", doc.Type)
	}
	if doc.Summary != "" {
		fmt.Printf("summary: %s\n", doc.Summary)
	}
	if doc.Positioning != "" {
		fmt.Printf("positioning: %s\n", doc.Positioning)
	}
	if doc.Status != "" {
		fmt.Printf("status: %s\n", doc.Status)
	}
	if len(doc.Tags) > 0 {
		fmt.Printf("tags: %s\n", strings.Join(doc.Tags, ", "))
	}
	if len(doc.Triggers) > 0 {
		fmt.Printf("triggers:\n")
		for _, t := range doc.Triggers {
			fmt.Printf("  - %s\n", t)
		}
	}
	if len(doc.Maintains) > 0 {
		fmt.Printf("maintains:\n")
		for _, m := range doc.Maintains {
			fmt.Printf("  - %s\n", m)
		}
	}
	if len(doc.Retires) > 0 {
		fmt.Printf("retires:\n")
		for _, r := range doc.Retires {
			fmt.Printf("  - %s\n", r)
		}
	}
	if len(doc.Links) > 0 {
		fmt.Printf("links:\n")
		for _, l := range doc.Links {
			fmt.Printf("  → %s — %s\n", l.To, l.Why)
		}
	}
}

func containsAny(list []string, substr string) bool {
	substr = strings.ToLower(substr)
	for _, s := range list {
		if strings.Contains(strings.ToLower(s), substr) {
			return true
		}
	}
	return false
}

func hasTag(tags []string, target string) bool {
	for _, t := range tags {
		if t == target {
			return true
		}
	}
	return false
}

type scoredDoc struct {
	Path  string  `json:"path"`
	Score float64 `json:"score"`
}

const (
	bm25k1 = 1.2
	bm25b  = 0.75
)

type fieldWeight struct {
	text   string
	weight float64
}

func bm25Search(docs map[string]*Doc, query string) []scoredDoc {
	query = strings.ToLower(strings.TrimSpace(query))
	if query == "" {
		return nil
	}
	queryWords := strings.Fields(query)

	docFields := make(map[string][]fieldWeight)

	for path, doc := range docs {
		var fields []fieldWeight
		add := func(s string, w float64) {
			s = strings.ToLower(strings.TrimSpace(s))
			if s == "" {
				return
			}
			fields = append(fields, fieldWeight{text: s, weight: w})
		}
		add(doc.Title, 3.0)
		add(doc.Summary, 1.5)
		add(doc.Positioning, 1.0)
		for _, t := range doc.Triggers {
			add(t, 2.0)
		}
		for _, t := range doc.Tags {
			add(t, 2.0)
		}
		for _, m := range doc.Maintains {
			add(m, 1.0)
		}
		for _, r := range doc.Retires {
			add(r, 1.0)
		}
		docFields[path] = fields
	}

	N := float64(len(docs))
	if N == 0 {
		return nil
	}

	df := make(map[string]int)
	for _, fields := range docFields {
		seen := make(map[string]bool)
		for _, f := range fields {
			for _, w := range strings.Fields(f.text) {
				if !seen[w] {
					seen[w] = true
					df[w]++
				}
			}
		}
	}

	var docLengths []float64
	pathList := make([]string, 0, len(docs))
	for path, fields := range docFields {
		var length float64
		for _, f := range fields {
			length += float64(len(strings.Fields(f.text))) * f.weight
		}
		docLengths = append(docLengths, length)
		pathList = append(pathList, path)
	}

	var avgdl float64
	for _, l := range docLengths {
		avgdl += l
	}
	avgdl /= N

	var results []scoredDoc
	for i, path := range pathList {
		var score float64
		for _, qw := range queryWords {
			n := df[qw]
			if n == 0 {
				continue
			}
			idf := math.Log((N-float64(n)+0.5)/(float64(n)+0.5) + 1.0)

			var tf float64
			for _, f := range docFields[path] {
				for _, w := range strings.Fields(f.text) {
					if w == qw {
						tf += 1.0 * f.weight
					}
				}
			}
			if tf == 0 {
				continue
			}

			dl := docLengths[i]
			numerator := tf * (bm25k1 + 1)
			denominator := tf + bm25k1*(1-bm25b+bm25b*dl/avgdl)
			score += idf * numerator / denominator
		}
		if score > 0 {
			results = append(results, scoredDoc{Path: path, Score: math.Round(score*100) / 100})
		}
	}

	sort.Slice(results, func(i, j int) bool {
		if results[i].Score != results[j].Score {
			return results[i].Score > results[j].Score
		}
		return results[i].Path < results[j].Path
	})

	return results
}

func cmdValidate(args []string) {
	flags := flag.NewFlagSet("validate", flag.ExitOnError)
	fix := flags.Bool("fix", false, "auto-fix detected file moves")
	strict := flags.Bool("strict", false, "treat warnings as errors")
	flags.Parse(args)

	rootDir := "."
	if flags.NArg() > 0 {
		rootDir = flags.Arg(0)
	}

	m, err := loadMap(rootDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mdMap: %v\n", err)
		os.Exit(1)
	}

	hasIssues := false
	hasWarnings := false

	var diskOnly []string
	var mapOnly []string

	filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}
		if !strings.HasSuffix(info.Name(), ".md") {
			return nil
		}
		absPath, _ := filepath.Abs(path)
		absRoot, _ := filepath.Abs(rootDir)
		schemaPath := filepath.Join(absRoot, "SCHEMA.md")
		if absPath == schemaPath {
			return nil
		}
		relPath, _ := filepath.Rel(rootDir, path)
		if _, exists := m.Docs[relPath]; !exists {
			diskOnly = append(diskOnly, relPath)
		}
		return nil
	})

	for path := range m.Docs {
		if _, err := os.Stat(filepath.Join(rootDir, path)); os.IsNotExist(err) {
			mapOnly = append(mapOnly, path)
		}
	}

	type Move struct {
		From string
		To   string
	}

	var moves []Move
	var stillMissing []string

	for _, missing := range mapOnly {
		doc := m.Docs[missing]
		if doc.Hash == "" {
			stillMissing = append(stillMissing, missing)
			continue
		}
		matched := false
		for _, orphan := range diskOnly {
			diskHash := computeHash(filepath.Join(rootDir, orphan))
			if diskHash == doc.Hash {
				moves = append(moves, Move{From: missing, To: orphan})
				if *fix {
					m.Docs[orphan] = doc
					delete(m.Docs, missing)
				}
				matched = true
				break
			}
		}
		if !matched {
			stillMissing = append(stillMissing, missing)
		}
	}
	mapOnly = stillMissing

	if *fix && len(moves) > 0 {
		filtered := make([]string, 0, len(diskOnly))
		movedTo := make(map[string]bool)
		for _, mv := range moves {
			movedTo[mv.To] = true
		}
		for _, p := range diskOnly {
			if !movedTo[p] {
				filtered = append(filtered, p)
			}
		}
		diskOnly = filtered
	}

	var brokenLinks []string
	for path, doc := range m.Docs {
		for _, link := range doc.Links {
			if _, exists := m.Docs[link.To]; !exists {
				brokenLinks = append(brokenLinks, fmt.Sprintf("%s → %s", path, link.To))
			}
		}
	}

	var staleLinks []string
	for path, doc := range m.Docs {
		for _, link := range doc.Links {
			if target, exists := m.Docs[link.To]; exists && target.Status == "deprecated" {
				staleLinks = append(staleLinks, fmt.Sprintf("%s → %s", path, link.To))
			}
		}
	}

	cycles := findCycles(m.Docs)

	if len(diskOnly) > 0 {
		fmt.Printf("orphans (%d):\n", len(diskOnly))
		for _, p := range diskOnly {
			fmt.Printf("  %s\n", p)
		}
		hasIssues = true
	}
	if len(mapOnly) > 0 {
		fmt.Printf("missing (%d):\n", len(mapOnly))
		for _, p := range mapOnly {
			fmt.Printf("  %s\n", p)
		}
		hasIssues = true
	}
	if len(moves) > 0 {
		fmt.Printf("moves (%d):\n", len(moves))
		for _, mv := range moves {
			fmt.Printf("  %s → %s\n", mv.From, mv.To)
		}
	}
	if len(brokenLinks) > 0 {
		fmt.Printf("broken links (%d):\n", len(brokenLinks))
		for _, l := range brokenLinks {
			fmt.Printf("  %s\n", l)
		}
		hasIssues = true
	}
	if len(cycles) > 0 {
		fmt.Printf("cycles (%d):\n", len(cycles))
		for _, c := range cycles {
			fmt.Printf("  %s\n", c)
		}
		hasIssues = true
	}
	if len(staleLinks) > 0 {
		fmt.Printf("stale links (%d):\n", len(staleLinks))
		for _, l := range staleLinks {
			fmt.Printf("  %s\n", l)
		}
		hasWarnings = true
	}

	if *fix && len(moves) > 0 {
		if err := saveMap(m, rootDir); err != nil {
			fmt.Fprintf(os.Stderr, "mdMap: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("mdMap.json updated")
	}

	if hasIssues {
		os.Exit(1)
	}
	if *strict && hasWarnings {
		os.Exit(1)
	}
	fmt.Println("ok")
}

func findCycles(docs map[string]*Doc) []string {
	adj := make(map[string][]string)
	for path, doc := range docs {
		for _, link := range doc.Links {
			to := link.To
			if _, exists := docs[to]; exists {
				adj[path] = append(adj[path], to)
			}
		}
	}

	const (
		white = 0
		gray  = 1
		black = 2
	)
	color := make(map[string]int)
	var cycles []string

	var dfs func(node string, stack []string)
	dfs = func(node string, stack []string) {
		color[node] = gray
		stack = append(stack, node)
		for _, next := range adj[node] {
			switch color[next] {
			case gray:
				start := -1
				for i, n := range stack {
					if n == next {
						start = i
						break
					}
				}
				if start >= 0 {
					cycle := stack[start:]
					cycle = append(cycle, next)
					cycles = append(cycles, strings.Join(cycle, " → "))
				}
			case white:
				dfs(next, stack)
			}
		}
		color[node] = black
	}

	for node := range adj {
		if color[node] == white {
			dfs(node, nil)
		}
	}
	return cycles
}

func cmdChanged(args []string) {
	flags := flag.NewFlagSet("changed", flag.ExitOnError)
	flags.Parse(args)

	rootDir := "."
	if flags.NArg() > 0 {
		rootDir = flags.Arg(0)
	}

	m, err := loadMap(rootDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mdMap: %v\n", err)
		os.Exit(1)
	}

	current := make(map[string]string)
	absRoot, _ := filepath.Abs(rootDir)
	schemaPath := filepath.Join(absRoot, "SCHEMA.md")

	filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}
		if !strings.HasSuffix(info.Name(), ".md") {
			return nil
		}
		absPath, _ := filepath.Abs(path)
		if absPath == schemaPath {
			return nil
		}
		relPath, _ := filepath.Rel(rootDir, path)
		current[relPath] = computeHash(path)
		return nil
	})

	var newFiles []string
	for path := range current {
		if _, exists := m.Docs[path]; !exists {
			newFiles = append(newFiles, path)
		}
	}

	var printedMoves = make(map[string]bool)
	var modified []string

	for path, doc := range m.Docs {
		h, exists := current[path]
		if !exists {
			matched := false
			for _, nf := range newFiles {
				if current[nf] == doc.Hash {
					fmt.Printf("moved: %s → %s\n", path, nf)
					printedMoves[nf] = true
					matched = true
					break
				}
			}
			if !matched {
				fmt.Printf("deleted: %s\n", path)
			}
		} else if h != doc.Hash {
			modified = append(modified, path)
		}
	}

	for _, p := range newFiles {
		if !printedMoves[p] {
			fmt.Printf("new: %s\n", p)
		}
	}

	for _, p := range modified {
		fmt.Printf("modified: %s\n", p)
	}
}
