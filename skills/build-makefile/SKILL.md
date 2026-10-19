---
name: build-makefile
description: |
  Build Makefile dependency graphs iteratively for replication packets. Use when:
  - gmake fails with "No rule to make target"
  - Adding scripts to replication packet
  - Resolving dependency chains
user-invocable: false
---

# Makefile Building Guide

*This is the authoritative guide for building Makefiles iteratively.*

**Project settings first.** If the repo has `.claude/skills/build-makefile/SKILL.md`, read it.
It holds the project's source repos, path substitutions, inventories, and lessons; those take
precedence over the general rules and examples here. The project's `CLAUDE.md` may hold them too.

## Cardinal Rules

1. **DIAGNOSE BEFORE ACTING** - When make rebuilds unexpectedly, run `gmake --debug=why -n TARGET` (GNU make 4; macOS's /usr/bin/make 3.81 rejects `--debug=why`) first. See the `makefile-runtime-debug` skill for the full diagnosis workflow. Never touch files or edit rules until you understand the root cause.
2. **NEVER copy pre-computed intermediate files** - replication must go from rawest raw data to final product
3. **Always note script modifications in headers** and commit changes
4. **COMMIT at every stage** - see Required Commit Points below
5. **Context efficiency is critical** - use subagents, stop at 70% context
6. **Learn and record** efficient patterns in the project's copy of this guide and status in its inventory files (e.g. `inventories/makefile-build-status.yaml`)

## Subagent Usage

**CRITICAL: When spawning subagents, ALWAYS tell them to read this skill file first:**
```
Read `~/.claude/skills/build-makefile/SKILL.md`, and `.claude/skills/build-makefile/SKILL.md` if it exists, for patterns and procedures.
```

### Single Subagent for Full Loop
For maximum context efficiency, spawn ONE subagent to handle the entire iteration loop:
- Run `gmake -n all` → find blocker → resolve → commit → repeat
- Subagent continues until Stage 1 complete or hits major blocker
- Report back only final status

### Pre-Approved Commands (Run Separately!)
See CLAUDE.md "Replication Script Guidelines" for the copy pattern. Pre-approved in `.claude/settings.json`:
- `cp`, `sed -i`, `git add/commit/status/log/diff/-C`, `gmake`

**CRITICAL**:
1. Each command must be a **separate Bash call**: permission rules match the start of the command text (`Bash(cp:*)`, `Bash(sed -i:*)`, `Bash(git add:*)`), so a chained command may not match.

Execute CLAUDE.md pattern as separate calls:
1. `git -C ~/projects/repo log -1 ...` (description: "git -C get commit hash")
2. `cp ~/projects/repo/path/to/script.R R/` (description: "cp script to R/")
3. `sed -i '' "1i\\..." R/script.R` (description: "sed -i add header")

## CRITICAL: Commit Policy

**Commit early and often. Do NOT batch work without commits.**

### Required Commit Points
1. **After copying a script** (before path changes) - allows rollback if path updates break things
2. **After updating paths in a script** - separate commit from the copy
3. **After adding Makefile rule(s)** - can batch related rules together
4. **After fixing a runtime error** - one fix per commit for easy rollback

### Commit Message Format
```bash
# Script copy
git commit -m "Copy SCRIPT.R from SOURCE-REPO (no path changes yet)"

# Path updates
git commit -m "Update paths in SCRIPT.R"

# Makefile rule
git commit -m "Add Makefile rule for TARGET (SCRIPT)"

# Runtime fix
git commit -m "Fix ISSUE in SCRIPT"
```

**Always include** the `Co-Authored-By:` attribution line from the session's instructions.

## Efficient Dependency Resolution

### Step 1: Find the Blocker
```bash
gmake -n all 2>&1 | grep "No rule"
# Example output: No rule to make target 'data-intermediate/foo.RData'
```

### Step 2: Consult Inventories (FAST)
If the project keeps inventories, check them BEFORE grepping source repos. For example:

1. **`inventories/critical-path.yaml`** - Best for finding which script creates a file
   - Has `script → outputs` mappings
   - Organized by execution stages

2. **`inventories/dependencies.yaml`** - Maps paper outputs to source chain

### Step 3: Grep Source Repos (FALLBACK)
Only if inventories don't have the answer:
```bash
# For .RData outputs
grep -rn "save.*FILENAME" ~/projects/SOURCE-REPO/R/

# For .dta outputs
grep -rn "write_dta.*FILENAME" ~/projects/SOURCE-REPO/R/

# For Stata outputs
grep -rn "save.*FILENAME" ~/projects/SOURCE-REPO/Scripts/
```

## CRITICAL: Check for Sourced Files

**When copying a new R script, ALWAYS check what files it `source()`s:**

```bash
grep "source(" R/new_script.R
```

**Then verify those sourced files exist:**
```bash
for f in $(sed -n 's/.*source("\([^"]*\)".*/\1/p' R/new_script.R); do
  [ -f "$f" ] && echo "EXISTS: $f" || echo "MISSING: $f"
done
```

**If any are missing:**
1. Copy them from source repo (with replication header)
2. Commit the sourced file(s)
3. Then proceed with the script that uses them


## Two-Commit Pattern for Scripts

**Commit 1: Copy with header only**
```bash
COMMIT=$(git -C ~/projects/SOURCE-REPO log -1 --format="%h on %ai" -- path/to/script.R)
cp ~/projects/SOURCE-REPO/path/to/script.R R/
sed -i '' "1i\\
# REPLICATION PACKET SCRIPT\\
# Original: ~/projects/SOURCE-REPO/path/to/script.R\\
# Last modified: $COMMIT\\
# Modifications: None yet\\
" R/script.R
git add R/script.R && git commit -m "Copy script.R from SOURCE-REPO (no path changes yet)"
```

**Commit 2: Update paths**
```bash
sed -i '' 's|"rawdata/|"data-raw/|g' R/script.R
sed -i '' 's|"intermediate_data/|"data-intermediate/|g' R/script.R
sed -i '' 's|Modifications: None yet|Modifications: Updated paths for replication packet|' R/script.R
git add R/script.R && git commit -m "Update paths in script.R"
```

**Verify with diff:**
```bash
diff ~/projects/SOURCE-REPO/path/to/script.R R/script.R
# Should show ONLY: header addition + path substitutions
```

## Path Substitutions

Use the project's mapping, recorded in the project's `CLAUDE.md` or project skill (for example `rawdata/` → `data-raw/`, `intermediate_data/` → `data-intermediate/`).


## Makefile Syntax Notes

- **Spaces in filenames**: Escape with backslash in prerequisites
  ```makefile
  $(DATA_INTER)/output.RData: $(SCRIPTS_R)/01d\ -\ process\ data.R
  	$(RSCRIPT) "$<"
  ```
- **Grouped targets** (one script, multiple outputs): Use `&:`
  ```makefile
  output1.dta output2.dta &: script.R
  	$(RSCRIPT) $<
  ```

## CRITICAL: Prevent Duplicate Script Execution

**Problem**: Expensive scripts (data processing, model estimation) can take hours. Running them multiple times wastes time and resources.

**Prevention**:

1. **Always use grouped targets (`&:`)** for rules that produce multiple outputs:
   ```makefile
   # GOOD - script runs once, creates both outputs
   $(OUTPUT1) $(OUTPUT2) &: script.R
   	$(RSCRIPT) $<

   # BAD - script may run twice if both outputs are dependencies
   $(OUTPUT1): script.R
   	$(RSCRIPT) $<
   $(OUTPUT2): script.R
   	$(RSCRIPT) $<
   ```

2. **Verify with dry run**:
   ```bash
   gmake -n all 2>&1 | grep -E "Rscript|stata-se" | sort | uniq -c | sort -rn | head -30
   # ALL counts should be 1. Any count > 1 means duplicate execution!
   ```

3. **When adding new rules**, check that you're not duplicating existing rules:
   ```bash
   grep "script_name" Makefile
   ```

**Note**: Requires GNU Make 4.3+ for grouped targets. The Makefile includes a version check.

## Source Repos Reference

List the source repos (name, path, content) in the project's `CLAUDE.md` or project skill.

## Handling New .do Files from Co-authors

When receiving updated Stata scripts:
1. **Compare to existing** - `diff new_script.do Stata/existing_script.do`
2. **Check if it's a replacement** (same outputs) or **new script** (new outputs)
3. **For replacements**: Update in place, note in header, commit
4. **For new scripts**: Add to Stata/, add Makefile rule, commit
5. **Update inventories** if outputs change


## Open Questions

- How to handle date-stamped filenames (e.g., `*-2023-10-31.RData`) in Makefile?
- Best approach for CONSTANTS.R dependencies that use variables?

## Portability

`sed -i ''` is BSD/macOS syntax; with GNU sed (Linux) use `sed -i`. `--debug=why` needs GNU make 4 (`gmake` on macOS).
