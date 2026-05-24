# Register a skill in the alfred marketplace

There are two ways to register: the **workflow** (browser, recommended) and the
**script** (local CLI, fallback). Both end with a PR opened from
`Mr-RedHat-fb/claude-marketplace` into `alfred-intelligence/claude-marketplace`
that adds or updates the skill's entry. Merge the PR and the skill is live.

First-time setup (creating the PAT and saving the secret) is in
[auth.md](auth.md).

## When to use which

| Use the workflow when… | Use the script when… |
|---|---|
| You're at any machine with browser access | You're already in the skill repo locally and want a one-liner |
| You don't want to set up `gh` and a PAT on a new device | `gh` is already authenticated where you are |
| You want a clean audit trail in GitHub Actions | You're iterating fast and don't need a log entry |
| The skill is published to GitHub | Same |

## The workflow

1. Open <https://github.com/alfred-intelligence/workflows/actions/workflows/register-skill.yml>.
2. Click **Run workflow**.
3. Fill in the inputs:
   - **Skill repo** — e.g., `Mr-RedHat-fb/ontology-skill`
   - **Skill ref** — leave empty for default branch, or set to a tag like `v1.0.0`
   - **Category** — e.g., `productivity`, `legal`, `infrastructure`. Optional.
   - **Dry run** — tick to preview the diff without opening a PR.
4. Click **Run workflow**.
5. Wait for the run to finish. The PR link is in the run's `Open pull request`
   step output, and as a comment in the marketplace repo.

The workflow is idempotent: re-running with the same inputs detects no change
and exits cleanly.

## The script

Prerequisites: `gh`, `jq`, `git`. `gh` must be authenticated against an
account with push rights to your marketplace fork and PR-create rights
upstream. See [auth.md](auth.md).

Run from inside the skill repo:

```
cd ~/code/ontology-skill
~/code/workflows/scripts/register-skill.sh --category productivity
```

Or with explicit path:

```
register-skill.sh --skill-dir ~/code/ontology-skill --category productivity --dry-run
```

### Options

| Flag | Description |
|---|---|
| `--skill-dir <path>` | Path to the skill repo. Default: current directory. |
| `--category <name>` | Marketplace category. Optional. |
| `--dry-run` | Show the diff without pushing or opening a PR. |

### Behaviour

- Reads `name`, `description`, and `version` from
  `.claude-plugin/plugin.json`, or from `plugin.json` at repo root for
  flat-layout single-skill plugins.
- Reads the GitHub repo from the skill's `origin` remote.
- Clones the marketplace fork to a temp directory, syncs with upstream, applies
  the change, force-pushes the `register/<skill-name>` branch to the fork, and
  opens the PR via `gh pr create`.
- If an entry with the same `name` already exists in the marketplace, the
  script *updates* it instead of adding a duplicate.

## Override the marketplace fork

By default the workflow and script use `Mr-RedHat-fb/claude-marketplace` as the
fork. For the script, override with the `MARKETPLACE_FORK` environment
variable:

```
MARKETPLACE_FORK=some-other-user/claude-marketplace register-skill.sh
```

For the workflow, change the `MARKETPLACE_FORK` value in `env:` at the top of
`.github/workflows/register-skill.yml` and commit.

## Updating an existing entry

Re-run the workflow or script. If `name`, `description`, `category`, or `repo`
has changed, the existing entry is replaced. If nothing has changed, the run
exits without a PR.
