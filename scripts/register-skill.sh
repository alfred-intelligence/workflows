#!/usr/bin/env bash
# register-skill.sh — register a skill in a Claude Code marketplace.
#
# This is the manual fallback for the register-skill workflow. When you run
# it, you push to your own fork as yourself; commits and PR are your identity.
# Bot-attributed PRs come from the workflow.
#
# Required env (set in your shell or a config file you source):
#   MARKETPLACE_REPO   The upstream marketplace, owner/repo
#   MARKETPLACE_FORK   The fork to push to, owner/repo
#                      (default: derived from current `gh` user)
#
# Required tools: gh, jq, git.
#
# Usage:
#   cd ~/code/ontology-skill
#   register-skill.sh [--category productivity] [--dry-run]
#
#   register-skill.sh --skill-dir ~/code/ontology-skill [--category ...] [--dry-run]

set -euo pipefail

MARKETPLACE_REPO="${MARKETPLACE_REPO:-}"
MARKETPLACE_FORK="${MARKETPLACE_FORK:-}"
MANIFEST_PATH=".claude-plugin/marketplace.json"

SKILL_DIR="$PWD"
CATEGORY=""
DRY_RUN=false

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)  SKILL_DIR="$2"; shift 2 ;;
    --category)   CATEGORY="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "error: unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for cmd in gh jq git; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: $cmd is required but not installed" >&2
    exit 1
  }
done

if [[ -z "$MARKETPLACE_REPO" ]]; then
  echo "error: MARKETPLACE_REPO env var must be set (e.g., owner/repo)" >&2
  exit 1
fi

# Default the fork to the authenticated gh user's namespace if not explicit.
if [[ -z "$MARKETPLACE_FORK" ]]; then
  GH_USER=$(gh api user --jq .login 2>/dev/null || true)
  REPO_NAME="${MARKETPLACE_REPO##*/}"
  if [[ -z "$GH_USER" ]]; then
    echo "error: MARKETPLACE_FORK not set and gh is not authenticated" >&2
    exit 1
  fi
  MARKETPLACE_FORK="${GH_USER}/${REPO_NAME}"
fi

cd "$SKILL_DIR"

if [[ -f .claude-plugin/plugin.json ]]; then
  MANIFEST=.claude-plugin/plugin.json
elif [[ -f plugin.json ]]; then
  MANIFEST=plugin.json
else
  echo "error: no plugin.json found in $SKILL_DIR" >&2
  exit 1
fi

NAME=$(jq -r '.name' "$MANIFEST")
DESCRIPTION=$(jq -r '.description // ""' "$MANIFEST")
VERSION=$(jq -r '.version // ""' "$MANIFEST")

if [[ -z "$NAME" || "$NAME" == "null" ]]; then
  echo "error: plugin.json is missing required field: name" >&2
  exit 1
fi

if [[ -n "$VERSION" && "$VERSION" != "null" ]]; then
  HANDLE="${NAME}@${VERSION}"
else
  VERSION=""
  HANDLE="$NAME"
fi

# Derive the GitHub repo from the skill's origin remote so the operator does
# not have to repeat themselves.
REPO=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  if [[ "$REMOTE_URL" =~ github\.com[:/]+([^/]+/[^/.]+) ]]; then
    REPO="${BASH_REMATCH[1]}"
  fi
fi
if [[ -z "$REPO" ]]; then
  echo "error: cannot determine GitHub repo for $SKILL_DIR (set the origin remote)" >&2
  exit 1
fi

echo "── inputs ──"
echo "  skill=$NAME"
echo "  version=${VERSION:-(unset)}"
echo "  source=$REPO"
echo "  category=${CATEGORY:-(omitted)}"
echo "  upstream=$MARKETPLACE_REPO"
echo "  fork=$MARKETPLACE_FORK"
echo

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

gh repo clone "$MARKETPLACE_FORK" "$WORK/marketplace" -- --quiet >/dev/null
cd "$WORK/marketplace"
git remote add upstream "https://github.com/${MARKETPLACE_REPO}.git"
git fetch --quiet upstream main
git reset --quiet --hard upstream/main

NEW=$(jq -n \
  --arg name "$NAME" \
  --arg desc "$DESCRIPTION" \
  --arg repo "$REPO" \
  '{name: $name, description: $desc, source: {source: "github", repo: $repo}}')
if [[ -n "$CATEGORY" ]]; then
  NEW=$(echo "$NEW" | jq --arg cat "$CATEGORY" '.category = $cat')
fi

jq --argjson new "$NEW" '
  if any(.plugins[]?; .name == $new.name)
  then .plugins |= map(if .name == $new.name then $new else . end)
  else .plugins += [$new]
  end
' "$MANIFEST_PATH" > "$MANIFEST_PATH.tmp"
mv "$MANIFEST_PATH.tmp" "$MANIFEST_PATH"

if git diff --quiet -- "$MANIFEST_PATH"; then
  echo "no changes — entry already up to date"
  exit 0
fi

echo "── diff ──"
git --no-pager diff -- "$MANIFEST_PATH"
echo

if $DRY_RUN; then
  echo "dry-run — not pushing or opening PR"
  exit 0
fi

BRANCH="register/$NAME"
git checkout -q -b "$BRANCH"
git add "$MANIFEST_PATH"
git commit -q -m "chore(marketplace): register $HANDLE"
git push --quiet --force-with-lease origin "$BRANCH"

FORK_OWNER="${MARKETPLACE_FORK%%/*}"
PR_BODY=$(cat <<BODY
Registers \`$NAME\` in the marketplace.

- **Source**: https://github.com/$REPO
- **Version**: ${VERSION:-unset}

Created with [register-skill.sh](https://github.com/alfred-intelligence/workflows/blob/main/scripts/register-skill.sh).
BODY
)

gh pr create \
  --repo "$MARKETPLACE_REPO" \
  --base main \
  --head "$FORK_OWNER:$BRANCH" \
  --title "chore(marketplace): register $HANDLE" \
  --body "$PR_BODY"
