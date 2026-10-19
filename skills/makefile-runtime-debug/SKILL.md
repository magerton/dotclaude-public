---
name: makefile-runtime-debug
description: Debug Makefile runs where gmake runs but scripts fail or targets rebuild unexpectedly (R/Stata replication packets). For "No rule to make target" errors, use build-makefile.
---

# Makefile Runtime Debugging

*Use this skill when `gmake` runs but scripts fail. For "No rule to make target" errors, use the `build-makefile` skill instead.*

If the repo has `.claude/skills/makefile-runtime-debug/SKILL.md`, read it for project-specific symlinks, inventories, and known errors.

---

## DIAGNOSE BEFORE ACTING (Read This First)

**When `make all` rebuilds targets it shouldn't, ALWAYS run `gmake --debug=why -n TARGET` first** to identify exactly which prerequisite is triggering the rebuild. This prints one line like:

```
Makefile:611: update target 'foo.RData' due to: bar.RData
```

The `-n` flag is critical -- it does a dry run so nothing actually executes.

**NEVER touch files, create stamp files, or edit Makefile rules until you understand the root cause.** Touching files without understanding the dependency graph can start a cascade of rebuilds that takes hours to undo. The dependency graph can be deep, and blindly touching one file to fix a timestamp will trigger rebuilds of everything downstream, which then triggers further rebuilds, and so on.

### Grouped Targets (`&:`) and Stamp Files

- **Missing stamp file creation:** If a Makefile rule targets a stamp file but the recipe never creates it (no `touch $@` and the script doesn't write it), make will ALWAYS re-run that target. Every single time. The fix is to ensure the recipe creates the stamp file, not to touch it manually.
- **Grouped target completeness:** For grouped targets (`&:`), ALL co-targets must exist and be newer than ALL prerequisites, or make rebuilds the whole group. A single missing or stale co-target triggers a full rebuild of all outputs in the group.
- **Diagnosis workflow:**
  1. Run `gmake --debug=why -n TARGET` to identify which specific prerequisite or missing co-target is the problem
  2. Check whether the reported prerequisite was legitimately updated, or whether its timestamp was disturbed
  3. If a stamp file is the culprit, verify the recipe actually creates it
  4. Only after understanding the full chain should you make any changes

### Example Debugging Session

```bash
# Step 1: See what make WANTS to rebuild
make -n all 2>&1

# Step 2: For each unexpected target, find out WHY
gmake --debug=why -n data-intermediate/some-output.RData

# Step 3: Read the output — it tells you exactly what's stale
#   Makefile:611: update target 'some-output.RData' due to: input.csv
#   This means input.csv is newer than some-output.RData

# Step 4: Investigate — is that correct? Was input.csv actually modified?
ls -la data-intermediate/some-output.RData
ls -la data/input.csv
```

---

## Quick Decision Tree

| Error Message | Skill | Action |
|---------------|-------|--------|
| `No rule to make target 'X'` | build-makefile | Add rule for X |
| `cannot open connection` + X has rule | **this skill** | Check dependency chain |
| `cannot open connection` + X has NO rule | build-makefile | Add rule for X first |
| `object 'Y' not found` in R | **this skill** | Check prereq ordering |
| Stata `file not found` | **this skill** | Check symlinks |
| Script succeeds but output wrong | **this skill** | Check script logic |

## Debugging Commands

### Check Dry Run for Specific Target
```bash
gmake -n TARGET 2>&1
# Example: gmake -n data-intermediate/panel.RData
```
Shows what would run without executing. If dependencies are missing, they won't appear here.

### Print Make Database (Variable Values)
```bash
gmake -p 2>/dev/null | grep -A5 "VARIABLE_NAME"
# Example: gmake -p 2>/dev/null | grep -A5 "LOOKUP_TABLE"
```
Shows how Make expanded variables and rules.

### Check Rule Prerequisites
```bash
gmake -p 2>/dev/null | grep -A3 "target_file.RData:"
# Shows the actual prerequisites Make sees (after variable expansion)
```

### Check if File Exists
```bash
ls -la path/to/file 2>&1
```
Simple but often forgotten - verify files in dependency chain exist.

## Variable Declaration Order (CRITICAL)

**Problem**: Variables defined with `:=` are expanded immediately at parse time.

```makefile
# BAD - LOOKUP_TABLE is empty when rule is parsed
$(PANEL): $(SCRIPTS_R)/build-panel.R $(LOOKUP_TABLE)
    $(RSCRIPT) $<

# ... 100 lines later ...
LOOKUP_TABLE := $(DATA_INTER)/lookup_table.RData  # TOO LATE!
```

**Solution**: Define variables BEFORE their first use, or use forward declarations:

```makefile
# GOOD - Forward declare early
LOOKUP_TABLE := $(DATA_INTER)/lookup_table.RData

$(PANEL): $(SCRIPTS_R)/build-panel.R $(LOOKUP_TABLE)
    $(RSCRIPT) $<
```

**Diagnosis**:
```bash
gmake -p 2>/dev/null | grep -A3 "panel"
# If LOOKUP_TABLE is missing from prerequisites, it expanded to empty
```

## Common Runtime Errors

### "cannot open the connection" (R)
```
Error in readChar(con, 5L, useBytes = TRUE) : cannot open the connection
In addition: Warning message:
  cannot open compressed file 'path/to/file.RData', probable reason 'No such file or directory'
```

**Causes**:
1. Missing dependency in Makefile rule
2. Script loads file not listed as prerequisite
3. Circular dependency (file A needs B, B needs A)

**Debug**:
1. Check which file is missing from error message
2. Search Makefile for that file using Grep tool: `pattern="filename", path="Makefile"`
3. Verify the rule that creates it has correct prerequisites
4. Check if there's a circular dependency

### Missing Package (R)
```
Error in library(xyz) : there is no package called 'xyz'
```

**Fix**:
```bash
Rscript -e 'renv::install("xyz"); renv::snapshot()'
git add renv.lock
git commit -m "Add xyz package to renv.lock"
```

## Dependency Chain Tracing

When a script fails because it can't load a file:

1. **Check inventories first** if the project keeps them (fastest):
   - `inventories/critical-path.yaml` - has script → outputs mappings
   - `inventories/dependencies.yaml` - maps outputs to source chain

2. **Find what creates the file** (use Grep tool):
   - Pattern: `save.*filename|write.*filename`, path: `R/`, glob: `*.R`
   - Pattern: `VARIABLE.*filename`, path: `Makefile`

3. **Check if that script's target is a dependency** (use Grep tool):
   - Pattern: `filename`, path: `Makefile`

4. **Verify variable declaration order** (see above)

5. **Run the specific target**:
   ```bash
   gmake -n data-intermediate/filename.RData
   ```

## Commit Hygiene During Debugging

See the `build-makefile` skill for the full commit policy. Key point for debugging:
- **One fix per commit** - easier to rollback if fix causes new issues
- Include problem description in message

## Circular Dependencies

**Symptoms**: Script A loads file from script B, but B needs output from A.

**Detection** (use Grep tool):
- Pattern: `load\(|read`, path: `R/scriptA.R` - what script loads
- Pattern: `save.*filename`, path: `R/`, glob: `*.R` - what creates each file

**Resolution strategies**:
1. Split one script to separate the circular portion
2. Create a bootstrap script that generates minimal data
3. Reorder operations within a single script

## Stata-Specific Debugging

**Log file location**: Script `foo.do` produces `foo.log` in working directory.

**Common errors in logs**:
```
file ... not found          → Check symlinks and input folder paths
variable ... not found      → Missing prerequisite .dta file
r(601) invalid file spec    → Path has special characters
```

**Symlink verification** (from repo root), if the project maps Stata paths with symlinks: `ls -la | grep "^l"`, and compare with the project's setup target.


**Before shipping**: check the project's `CLAUDE.md` for scaffolding to remove.

## R Package Resolution (Bulk)

When multiple packages are missing:
```bash
# Find missing packages (use Grep tool for search, then install)
Rscript -e '
  scripts <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  code <- unlist(lapply(scripts, readLines, warn = FALSE))
  libs <- unique(gsub(".*library\\(([^)]+)\\).*", "\\1", grep("library\\(", code, value = TRUE)))
  missing <- libs[!libs %in% rownames(installed.packages())]
  if (length(missing) > 0) { renv::install(missing); renv::snapshot() }
'
```

## Distinguishing Error Types

| Symptom | Cause | Fix |
|---------|-------|-----|
| `No rule to make target 'X'` | Missing Makefile rule | Use build-makefile skill |
| `cannot open connection` | File not created by prereq | Check dependency chain |
| `object 'X' not found` | Script ran before prereq | Check Makefile ordering |
| Empty output file | Script logic error | Check script, not Makefile |

## Common Runtime Error Patterns

1. **Path not updated** - `intermediate_data/` should be `data-intermediate/`
   - Fix with `sed -i '' '/^[[:space:]]*#/!s|intermediate_data/|data-intermediate/|g'` (skips comment lines)

2. **Debug `stopifnot(F)` left in script** - Search with Grep: `stopifnot\(F\)` in `R/*.R`

3. **Missing sourced files** - Check with Grep: `source\(` in the script, then verify files exist

4. **Figures for other outputs** - Comment out `ggsave` calls for slides or other outputs the packet does not ship; keep the paper's figures

5. **`Sys.Date()` in output filenames** - Breaks Makefile deps when run on different days. Hardcode a fixed date: `DATE <- "YYYY-MM-DD"`

6. **Package masking: `year()` and `yearmon`** - `data.table::year()` masks `lubridate::year()` but fails on `zoo::yearmon`. Fix: load `lubridate` after `data.table`, or use `lubridate::year()` explicitly.

## Portability

`sed -i ''` is BSD/macOS syntax; with GNU sed (Linux) use `sed -i`. `--debug=why` needs GNU make 4 (`gmake` on macOS).
