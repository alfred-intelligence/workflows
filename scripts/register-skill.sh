#!/usr/bin/env bash
# register-skill.sh — register a skill in the alfred marketplace.
#
# Reads plugin.json from the current dir (or --skill-dir), edits a fork of
# the marketplace, opens a PR upstream. Requires gh, jq, git.
#
# Usage:
#   cd ~/code/ontology-skill
#   ~/code/workflows/scripts/register-skill.sh --category productivity
# Or:
#   register-skill.sh --skill-dir ~/code/ontology-skill --category productivity [--dry-run]

set -euo pipefail

MARKETPLACE_REPO="alfred-intelligence/claude-marketplace"
MARKETPLACE_FORK="${MARKETPLACE_FORK:-Mr-RedHat-fb/claude-marketplace}"
MANIFEST_PATH=".claude-plugin/marketplace.json"

SKILL_DIR="$PWD"
CATEGORY=""
DRY_RUN=false

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)  SKILL_DIR="$2"; shift 2 ;;
    --category)   CATEGORY="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "error: unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

# Required tools — fail early with a clear message instead of cryptic later errors.
for cmd in gh jq git; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: $cmd is required but not installed" >&2
    exit 1
  }
done

cd "$SKILL_DIR"

# The manifest may live at .claude-plugin/plugin.json or, for flat single-skill
# plugins, at the repo root.
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

echo "── skill ──"
echo "  name=$NAME"
echo "  version=${VERSION:-(unset)}"
echo "  repo=$REPO"
echo "  category=${CATEGORY:-(omitted)}"
echo

# Clone the fork to a temp dir and reset it to upstream/main so we work on
# top of the latest published state, not stale fork history.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

gh repo clone "$MARKETPLACE_FORK" "$WORK/marketplace" -- --quiet >/dev/null
cd "$WORK/marketplace"
git remote add upstream "https://github.com/${MARKETPLACE_REPO}.git"
git fetch --quiet upstream main
git reset --quiet --hard upstream/main

# Build the new entry; omit category when empty so the JSON stays clean.
NEW=$(jq -n \
  --arg name "$NAME" \
  --arg desc "$DESCRIPTION" \
  --arg repo "$REPO" \
  '{name: $name, description: $desc, source: {source: "github", repo: $repo}}')
if [[ -n "$CATEGORY" ]]; then
  NEW=$(echo "$NEW" | jq --arg cat "$CATEGORY" '.category = $cat')
fi

# Insert if new, update in place if an entry with the same name exists.
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
PR_BODY=$(cat <<EOF
Registers \`$NAME\` in the alfred marketplace.

- **Source**: https://github.com/$REPO
- **Version**: ${VERSION:-unset}

Created with [register-skill.sh](https://github.com/alfred-intelligence/workflows/blob/main/scripts/register-skill.sh).
EOF
)

gh pr create \
  --repo "$MARKETPLACE_REPO" \
  --base main \
  --head "$FORK_OWNER:$BRANCH" \
  --title "chore(marketplace): register $HANDLE" \
  --body "$PR_BODY"
