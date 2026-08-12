# deploy-infra

Shared GitHub Actions deployment logic for every project on the
`aspirez-prod` server: jan-score, land-registry-chain, media-ops, p-iden,
and aspirez itself.

## Why this exists

All five projects deploy the same way — push a version tag, a self-hosted
runner on the target server checks it out, writes a `.env` from GitHub
secrets, and runs `scripts/deploy-prod.sh` — but until now that logic was
copy-pasted into each project's own `.github/workflows/deploy.yml`. A fix
to one (say, a retry helper or a health-check tweak) had to be manually
repeated in the other four. This repo holds that logic once, as a
[reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows),
and each project's own workflow file is now a short "caller" that supplies
its project-specific details.

## What this does *not* change

Self-hosted runners on a personal (non-organization) GitHub account are
always registered against exactly one repo — there is no way for a single
runner process to pick up jobs from five independent repos without
converting to a GitHub Organization (which enables org-level runner
groups). So each project still has, and needs, its own runner process on
the server (`actions-runner-jan-score`, `actions-runner-media-ops`, etc.).
What's centralized here is the deployment *steps*, not the runner
infrastructure.

## Usage

In a project's `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    tags:
      - "v*.*.*-prod"

jobs:
  deploy-prod:
    uses: 0xVISHWAJEET/deploy-infra/.github/workflows/deploy-prod.yml@main
    with:
      runner-label: jan-score-prod   # the self-hosted runner label for this project
      project-dir: jan-score         # directory under the runner user's home dir
    secrets:
      env-file: |
        DATABASE_URL=${{ secrets.DATABASE_URL }}
        AUTH_SECRET=${{ secrets.AUTH_SECRET }}
        # ...every secret this project's .env needs
```

`env-file` is optional — a project with no runtime `.env` (like aspirez)
can omit the `secrets:` block entirely.

## Making a change

Edit `.github/workflows/deploy-prod.yml` here and push to `main`. Nothing
deploys as a result of that push by itself — the next time any project cuts
a real release (`scripts/release.sh`, which pushes a `vX.Y.Z-prod` tag),
its deploy job picks up whatever is on this repo's `main` branch at that
moment (per the `@main` ref in each caller workflow).
