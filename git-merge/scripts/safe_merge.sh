#!/bin/bash
# Safe Git Merge Script for git-merge skill
# Safely merges current branch into target branch and returns to original

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
info() { echo -e "${GREEN}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
step() { echo -e "${BLUE}◆${NC} $1"; }

# Check if target branch is provided
if [ -z "$1" ]; then
    error "Usage: $0 <target-branch>"
    echo ""
    echo "Example: $0 main"
    echo "         $0 develop"
    exit 1
fi

TARGET_BRANCH="$1"

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
info "当前分支: $CURRENT_BRANCH"
info "目标分支: $TARGET_BRANCH"
echo ""

# Check if target branch exists
step "检查目标分支是否存在..."
if ! git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
    error "目标分支 '$TARGET_BRANCH' 不存在!"
    echo ""
    echo "可用的分支:"
    git branch --format='%(refname:short)'
    exit 1
fi
info "目标分支 '$TARGET_BRANCH' 存在 ✓"
echo ""

# Check for uncommitted changes
step "检查工作区状态..."
if ! git diff --quiet || ! git diff --cached --quiet; then
    warn "检测到未提交的更改!"
    echo ""
    echo "未提交的更改:"
    git status --short
    echo ""

    read -p "是否暂存这些更改并继续合并? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        step "暂存所有更改..."
        git stash push -m "safe_merge: 暂存于 $(date)"
        STASHED=true
        info "更改已暂存 ✓"
    else
        error "请先提交或暂存您的更改，然后重试"
        exit 1
    fi
else
    info "工作区干净 ✓"
    STASHED=false
fi
echo ""

# Switch to target branch
step "切换到目标分支 '$TARGET_BRANCH'..."
git checkout "$TARGET_BRANCH"
info "已切换到 '$TARGET_BRANCH' ✓"
echo ""

# Pull latest changes from target branch
step "拉取目标分支最新代码..."
git pull origin "$TARGET_BRANCH" 2>/dev/null || git pull 2>/dev/null || true
info "已更新 '$TARGET_BRANCH' ✓"
echo ""

# Perform merge
step "执行合并: 将 '$CURRENT_BRANCH' 合并到 '$TARGET_BRANCH'..."
if git merge "$CURRENT_BRANCH" --no-edit; then
    info "合并成功 ✓"
    echo ""
    echo "合并统计:"
    git diff --stat HEAD~1 HEAD 2>/dev/null || git log --oneline -1
else
    error "合并失败! 可能存在冲突"
    echo ""
    echo "请解决冲突后手动提交"
    echo ""
    # Return to original branch
    step "返回原分支 '$CURRENT_BRANCH'..."
    git checkout "$CURRENT_BRANCH"
    exit 1
fi
echo ""

# Push to remote if needed
read -p "是否推送到远程仓库 '$TARGET_BRANCH'? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    step "推送到远程 '$TARGET_BRANCH'..."
    if git push origin "$TARGET_BRANCH"; then
        info "推送成功 ✓"
    else
        error "推送失败"
    fi
fi
echo ""

# Return to original branch
step "返回原分支 '$CURRENT_BRANCH'..."
git checkout "$CURRENT_BRANCH"
info "已返回 '$CURRENT_BRANCH' ✓"
echo ""

# Restore stashed changes if any
if [ "$STASHED" = true ]; then
    step "恢复暂存的更改..."
    git stash pop
    info "更改已恢复 ✓"
fi
echo ""

# Summary
echo "========================================"
info "✅ 合并完成!"
echo "========================================"
echo "  源分支: $CURRENT_BRANCH"
echo "  目标分支: $TARGET_BRANCH"
echo ""
if [ "$STASHED" = true ]; then
    warn "注意: 暂存的更改已恢复"
fi
echo "========================================"

exit 0
