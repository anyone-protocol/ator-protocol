# Upstream Tor Merge Plan

## Overview

This document describes the procedure for merging upstream Tor changes into the
ator-protocol (Anon Client) fork. The fork diverged from upstream Tor at commit
`d07810a3c` (2023-11-22), which sits between the upstream `tor-0.4.8.9` and
`tor-0.4.8.10` releases. Since then:

- **294 commits** have been made on the ator-protocol fork (591 files changed)
- **~820 commits** have been made upstream (up to `tor-0.4.9.5` / `0.5.0.0-alpha-dev`)
- **106 files** were renamed as part of the `tor` → `anon` rebrand
- **168 files** were added by the fork (CI, Docker, configs, etc.)

The core challenge is that the fork performed a systematic rename of `tor` → `anon`
across filenames and source code, which causes massive spurious conflicts on any
naive `git merge` because upstream patches reference the old `tor_*` names.

## Key References

| Item | Value |
|------|-------|
| Fork repo | `https://github.com/anyone-protocol/ator-protocol` |
| Upstream repo | `https://gitlab.torproject.org/tpo/core/tor` |
| Fork point commit | `d07810a3c96b7c063696fd3a27d9ad09f5141135` |
| Fork point tag | `last-commit-before-fork` |
| Fork point date | 2023-11-22 |
| Upstream at fork | Between `tor-0.4.8.9` and `tor-0.4.8.10` |
| Latest upstream stable | `tor-0.4.8.22` (0.4.8.x series), `tor-0.4.9.5` (0.4.9.x series) |
| Upstream main | `0.5.0.0-alpha-dev` |

## Strategy: Reverse-Rename, Merge, Re-Rename

The cleanest approach is to temporarily reverse the `anon` naming back to `tor`
naming, perform a standard `git merge` with upstream (where file/symbol names
match), then re-apply the `anon` naming. This turns rename-induced noise into
clean merges and leaves only real semantic conflicts to resolve manually.

### Phase 0: Preparation

#### 0.1 — Build the rename mapping

Catalog every `tor` → `anon` transformation that was applied. This includes:

- **File renames** (106 files): `tor_main.c` → `anon_main.c`, `torrc` → `anonrc`, etc.
- **Content substitutions**: function names, variable names, strings, comments,
  config keys, binary names, directory names, etc.
- **Selective renames**: the rename was NOT a blind `s/tor/anon/g` — words like
  "iterator", "monitor", "vector", "directory" were left intact. The rules must
  be captured precisely.

Generate the initial mapping:

```bash
# List all file renames
cd /home/jim/dev/ator/ator-protocol
git diff --diff-filter=R --name-status last-commit-before-fork..main > /tmp/file-renames.txt

# Sample content changes to infer substitution rules
git diff last-commit-before-fork..main -- '*.c' '*.h' | \
  grep '^[-+]' | grep -i 'anon\|tor' | head -500 > /tmp/content-changes-sample.txt
```

#### 0.2 — Write the rename scripts

Create two scripts:

1. **`scripts/maint/reverse-rename.sh`** — Converts `anon` naming back to `tor`
   naming (the inverse transform `T⁻¹`).
2. **`scripts/maint/forward-rename.sh`** — Converts `tor` naming to `anon`
   naming (the forward transform `T`).

**Critical requirement:** these must be perfect inverses. Verify with:

```bash
git checkout -b test-roundtrip main
./scripts/maint/reverse-rename.sh
./scripts/maint/forward-rename.sh
git diff  # Must be empty!
git checkout main
git branch -D test-roundtrip
```

Skeleton for the scripts:

```bash
#!/bin/bash
# reverse-rename.sh — T⁻¹: anon → tor
set -euo pipefail

# --- File renames (generated from file-renames.txt) ---
file_renames=(
  "src/app/main/anon_main.c:src/app/main/tor_main.c"
  "src/config/anonrc.sample.in:src/config/torrc.sample.in"
  # ... (all 106 renames, reversed)
)

for entry in "${file_renames[@]}"; do
  src="${entry%%:*}"
  dst="${entry##*:}"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    git mv "$src" "$dst"
  fi
done

# --- Content substitutions (order matters: longest match first) ---
# Only operate on tracked source files to avoid corrupting binaries
git ls-files '*.c' '*.h' '*.py' '*.sh' '*.am' '*.ac' '*.in' '*.txt' '*.md' '*.conf' | \
  xargs sed -i \
    -e 's/ator-protocol/tor/g' \
    -e 's/anon_main/tor_main/g' \
    -e 's/anonrc/torrc/g' \
    -e 's/anon-resolve/tor-resolve/g' \
    -e 's/anon-gencert/tor-gencert/g' \
    # ... (extend with all identified substitution rules)

git add -A
```

The forward-rename script is the same but with reversed `sed` substitutions and
file renames going the other direction.

> **Tip:** To discover all substitution patterns, run:
> ```bash
> git diff last-commit-before-fork..main -- '*.c' '*.h' | \
>   grep -oP '(?<=^-).*tor[a-z_]*|(?<=^\+).*anon[a-z_]*' | \
>   sort -u > /tmp/substitution-candidates.txt
> ```

#### 0.3 — Set up upstream remote in ator-protocol

```bash
cd /home/jim/dev/ator/ator-protocol
git remote add upstream https://gitlab.torproject.org/tpo/core/tor.git
git fetch upstream
```

#### 0.4 — Enable rerere

```bash
git config rerere.enabled true
```

This tells Git to remember conflict resolutions so you don't have to redo them
if the merge needs to be retried.

### Phase 1: Reverse-Rename Branch

```bash
# Create a working branch
git checkout -b upstream-merge main

# Apply the reverse rename
./scripts/maint/reverse-rename.sh
git commit -am "TEMP: Reverse anon->tor naming for upstream merge"
```

At this point, the code on `upstream-merge` should look structurally similar to
upstream Tor (same filenames, same symbol names), but with all the fork's
functional changes present.

### Phase 2: Merge Upstream

Decide which upstream target to merge. Options:

| Target | Commits from fork | Risk | Recommendation |
|--------|-------------------|------|----------------|
| `tor-0.4.8.22` | ~401 | Low — same major version, security/bugfix only | **Start here** |
| `tor-0.4.9.5` | ~819 | Medium — new features, API changes | Second step |
| `origin/main` (0.5.0-alpha) | ~827 | High — dev branch, unstable | Avoid unless needed |

**Recommended: merge in stages, starting with `tor-0.4.8.22`.**

```bash
# Merge the latest 0.4.8.x stable release
git merge upstream/release-0.4.8 --no-commit
# Or a specific tag:
# git merge tor-0.4.8.22 --no-commit

# Resolve conflicts. Since filenames now match upstream,
# conflicts should be limited to real semantic conflicts
# where both sides changed the same code.

# Review the merge carefully
git diff --cached --stat
git diff --cached  # full diff

# Once satisfied:
git commit -m "Merge upstream tor-0.4.8.22 into ator-protocol (reversed naming)"
```

### Phase 3: Re-Apply Anon Naming

```bash
./scripts/maint/forward-rename.sh
git commit -am "Re-apply anon naming after upstream merge"
```

### Phase 4: Validate

```bash
# Build
./autogen.sh
./configure
make -j$(nproc)

# Run tests
make check

# Verify no tor references leaked back in where they shouldn't be
# (some internal references to "tor" are intentional — protocol names, etc.)
grep -rn '\btor_main\b\|torrc\b\|tor-resolve\b' src/ | \
  grep -v '\.git' | grep -v 'test/' || echo "Clean"
```

### Phase 5: Integrate Back to Main

```bash
git checkout main
git merge upstream-merge --no-ff -m "Merge upstream Tor 0.4.8.22 changes"
```

### Phase 6 (Optional): Merge 0.4.9.x

Once 0.4.8.x is stable, repeat Phases 1–5 targeting `tor-0.4.9.5`:

```bash
git checkout -b upstream-merge-049 main
./scripts/maint/reverse-rename.sh
git commit -am "TEMP: Reverse anon->tor naming for 0.4.9 merge"
git merge tor-0.4.9.5 --no-commit
# Resolve conflicts, commit, forward-rename, validate, merge to main
```

## Files That Should NOT Be Reverse-Renamed

Some files/directories are unique to the fork and should be excluded from the
rename scripts:

- `.github/` — CI/CD workflows (168 added files)
- `docker/` — Docker configurations
- `debian/` — Debian packaging (already customized for `anon`)
- `anonrc-dev/` — Fork-specific config
- `operations/` — Fork-specific operational tooling
- Any new source files added by the fork that don't have upstream counterparts

The rename scripts should have an exclusion list for these paths.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Rename scripts miss a substitution, causing broken code | Round-trip test (Phase 0.2); build + test after merge |
| Upstream changed files that the fork also changed | Manual conflict resolution during Phase 2 merge |
| Upstream added new files with `tor` naming | Forward-rename script should handle new files too |
| Upstream removed files that fork modified | Conflict will surface during merge; decide per-file |
| Content substitution corrupts non-rename occurrences | Use word-boundary-aware patterns; test thoroughly |
| Binary files corrupted by sed | Only operate on tracked text files (use `git ls-files`) |

## Alternative Approaches Considered

| Approach | Why Not |
|----------|---------|
| Direct `git merge` | Thousands of false conflicts from renames; unusable |
| `git rebase` onto upstream | Same rename conflict problem, repeated per-commit |
| Cherry-pick upstream commits | 400+ commits, each with rename conflicts |
| Manual diff + patch | Extremely tedious, error-prone at this scale |
| Start fresh from upstream | Loses 294 commits of fork-specific work |

## Ongoing Maintenance

After the initial merge, to keep up with upstream going forward:

1. **Keep the rename scripts updated** as new files/symbols are added.
2. **Merge upstream regularly** (quarterly or per-release) to avoid large deltas.
3. **Tag each upstream merge** for traceability:
   `git tag upstream-merge-0.4.8.22` after each successful merge.
4. Consider a **CI job** that periodically checks for new upstream releases and
   opens a tracking issue.

## Quick Reference: Full Merge Sequence

```bash
# Setup (one-time)
git remote add upstream https://gitlab.torproject.org/tpo/core/tor.git
git config rerere.enabled true

# Merge procedure
git fetch upstream
git checkout -b upstream-merge main
./scripts/maint/reverse-rename.sh
git commit -am "TEMP: Reverse anon->tor naming for upstream merge"
git merge tor-0.4.8.22 --no-commit
# ... resolve conflicts ...
git commit -m "Merge upstream tor-0.4.8.22 (reversed naming)"
./scripts/maint/forward-rename.sh
git commit -am "Re-apply anon naming after upstream merge"
# Build + test
git checkout main
git merge upstream-merge --no-ff -m "Merge upstream Tor 0.4.8.22"
git tag upstream-merge-0.4.8.22
git branch -d upstream-merge
```
