---
name: git-merge
description: Safely merge current branch into target branch and return. Use when user wants to merge current branch to another branch, mentions "merge A to B", "merge my branch into", or similar merge requests. Ensures current changes are committed before merging, switches to target branch, performs merge, then switches back.
---

# Git Merge Workflow

Safely merge the current branch into a target branch and return to the original branch.

## When to Use

Automatically activate when the user:
- Explicitly asks to merge branches ("merge A to B", "merge my branch into")
- Mentions combining changes from current branch to another ("merge into main", "merge to develop")
- Asks to "push my changes to [branch]" but means merging
- Says phrases like "merge this feature to main" or "combine my branch with develop"

## Workflow

**ALWAYS use the script** - do NOT use manual git commands:

```bash
bash skills/git-merge/scripts/safe_merge.sh <target-branch>
```

Example:
```bash
bash skills/git-merge/scripts/safe_merge.sh main
bash skills/git-merge/scripts/safe_merge.sh develop
```

## Safety Guarantees

1. Checks for uncommitted changes and warns user
2. Stashes uncommitted changes if requested
3. Verifies target branch exists
4. Performs merge with clear output
5. Always returns to original branch
6. Reports merge status clearly

## Script Details

The script handles:
- Detecting current branch
- Checking for uncommitted changes
- Stashing changes if needed
- Switching to target branch
- Merging current branch into target
- Returning to original branch
- Restoring stashed changes if applicable
- Clear status reporting
