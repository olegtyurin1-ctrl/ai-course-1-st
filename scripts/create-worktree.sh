#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/create-worktree.sh <agent-name> [base-ref]

Creates a git worktree one level above the current repository.

Example:
  scripts/create-worktree.sh codex
  scripts/create-worktree.sh codex origin/development

Environment:
  WORKTREE_PROJECT_PREFIX  Override directory prefix.
                           Default: uppercase repository folder name.
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's#[^a-z0-9._-]#-#g; s#-\\{2,\\}#-#g; s#^-##; s#-$##'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

agent_name="${1:-}"
[ -n "$agent_name" ] || {
  usage
  exit 1
}

git_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this script inside a git repository"
cd "$git_root"

current_branch="$(git branch --show-current)"
[ -n "$current_branch" ] || die "current HEAD is detached; pass an explicit base ref from a checked-out branch"

base_ref="${2:-$current_branch}"
repo_name="$(basename "$git_root")"
project_prefix="${WORKTREE_PROJECT_PREFIX:-$(printf '%s' "$repo_name" | tr '[:lower:]' '[:upper:]')}"

branch_slug="$(slugify "$current_branch")"
agent_slug="$(slugify "$agent_name")"
[ -n "$agent_slug" ] || die "agent name must contain at least one letter or digit"

parent_dir="$(dirname "$git_root")"
worktree_dir="$parent_dir/${project_prefix}-worktree-${branch_slug}-${agent_slug}"
worktree_branch="worktree/${branch_slug}-${agent_slug}"

git rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null \
  || die "base ref '$base_ref' does not exist"

if [ -e "$worktree_dir" ]; then
  die "target already exists: $worktree_dir"
fi

if git show-ref --verify --quiet "refs/heads/$worktree_branch"; then
  if git worktree list --porcelain | grep -Fqx "branch refs/heads/$worktree_branch"; then
    die "branch '$worktree_branch' is already checked out in another worktree"
  fi

  git worktree add "$worktree_dir" "$worktree_branch"
else
  git worktree add -b "$worktree_branch" "$worktree_dir" "$base_ref"
fi

printf '\nCreated worktree:\n'
printf '  path:   %s\n' "$worktree_dir"
printf '  branch: %s\n' "$worktree_branch"
printf '  base:   %s\n' "$base_ref"
