# workflows

Reusable GitHub Actions workflows and CLI scripts for the
alfred-intelligence ecosystem.

## What's here

| Path | Purpose |
|---|---|
| [`.github/workflows/register-skill.yml`](.github/workflows/register-skill.yml) | Register a published skill in the alfred marketplace via fork-and-PR. Manual trigger from the Actions tab. |
| [`scripts/register-skill.sh`](scripts/register-skill.sh) | Local CLI fallback for the same registration flow. |
| [`docs/register-skill.md`](docs/register-skill.md) | When to use the workflow vs the script, with step-by-step instructions. |
| [`docs/auth.md`](docs/auth.md) | PAT setup, required scopes, and where the secret lives. |

## Quick start

See [docs/register-skill.md](docs/register-skill.md). First-time setup
(creating the PAT and saving the secret) is in [docs/auth.md](docs/auth.md).

## License

MIT. See [LICENSE](LICENSE).
