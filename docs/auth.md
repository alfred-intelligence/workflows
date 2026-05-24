# Authentication setup

Both the workflow and the script need credentials that can:

1. Push a branch to your fork of the marketplace
   (`Mr-RedHat-fb/claude-marketplace`).
2. Open a pull request upstream
   (`alfred-intelligence/claude-marketplace`).

The workflow uses a stored Personal Access Token. The script uses your local
`gh` authentication.

## Workflow: PAT in a repo secret

### Create the PAT

Either a **classic** or a **fine-grained** PAT works.

**Classic** — simplest:

- Scope: `repo` (full).
- Expiration: pick a date you'll remember to rotate.

**Fine-grained** — preferred for least-privilege:

- Resource owner: your account (e.g., `Mr-RedHat-fb`).
- Repository access: select both `Mr-RedHat-fb/claude-marketplace` and
  `alfred-intelligence/claude-marketplace`.
- Repository permissions:
  - On the fork: `Contents: Read and write`, `Pull requests: Read and write`.
  - On the upstream: `Pull requests: Read and write`, `Contents: Read-only`.

### Store the PAT

1. Open
   <https://github.com/alfred-intelligence/workflows/settings/secrets/actions>.
2. Click **New repository secret**.
3. **Name**: `MARKETPLACE_PAT`.
4. **Value**: paste the PAT.
5. Click **Add secret**.

That's the only setup needed for the workflow.

## Script: `gh` authentication

The script uses `gh` for the cross-repo operations. Authenticate once on the
machine you'll run from:

```
gh auth login --hostname github.com --git-protocol https --scopes repo
```

`gh` stores its token in `~/.config/gh/hosts.yml`. No further setup.

The account `gh` is authenticated as needs the same access as the PAT above
(push to the fork, PR-create upstream).

## Rotation

PATs expire. When the workflow starts failing with `Bad credentials`,
regenerate the PAT and update the `MARKETPLACE_PAT` secret. `gh`'s token is
long-lived and doesn't need rotation under normal use.

## Why not GITHUB_TOKEN?

The default `GITHUB_TOKEN` is scoped to the calling repo
(`alfred-intelligence/workflows`). It has no write access to either the
marketplace fork or the upstream marketplace, so it cannot push a branch or
open a PR across repos. A PAT (or a GitHub App token) is required.

A GitHub App is a reasonable later upgrade if the number of skills or external
contributors grows enough to justify the setup overhead.
