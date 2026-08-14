# deploy-infra

A generic, reusable GitHub Actions deployment workflow for projects that
deploy by pushing a version tag to a self-hosted runner: check out the
tagged release, optionally write a `.env` file from a secret, run a deploy
script, and record the deployed version.

## Why this exists

Deploying this way tends to involve the same handful of steps across
multiple projects — copy-pasting that logic into every project's own
`.github/workflows/deploy.yml` means a fix to one (a retry helper, a
health-check tweak) has to be manually repeated everywhere else. This repo
holds that logic once, as a
[reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows),
and each project's own workflow file becomes a short "caller" that
supplies its own specific details.

## What this does *not* change

Self-hosted runners on a personal (non-organization) GitHub account are
always registered against exactly one repo — there is no way for a single
runner process to pick up jobs from multiple independent repos without
converting to a GitHub Organization (which enables org-level runner
groups). So each project still has, and needs, its own runner process.
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
    uses: <owner>/deploy-infra/.github/workflows/deploy-prod.yml@main
    with:
      runner_label: myapp-prod    # the self-hosted runner label for this project
      project_path: ~/myapp       # full path to the checkout on the runner
    secrets:
      env_file: |
        DATABASE_URL=${{ secrets.DATABASE_URL }}
        AUTH_SECRET=${{ secrets.AUTH_SECRET }}
        # ...every secret this project's .env needs
```

`env_file` is optional — a project with no runtime `.env` can omit the
`secrets:` block entirely.

Input/secret names use underscores, not hyphens, on purpose — see the
comment at the top of `deploy-prod.yml`: a hyphenated name like
`runner-label` parses as subtraction (`inputs.runner - label`) when
referenced via `${{ inputs.runner-label }}`, which silently invalidates
the whole workflow file. Keep any new input/secret name underscore-only.

## Making a change

Edit `.github/workflows/deploy-prod.yml` here and push to `main`. Nothing
deploys as a result of that push by itself — the next time any calling
project cuts a real release, its deploy job picks up whatever is on this
repo's `main` branch at that moment (per the `@main` ref in each caller
workflow).

## Testing a change safely

A tag-triggered production deploy fails silently and unhelpfully if this
workflow file has a validation error — GitHub reports "workflow file
issue" with zero jobs and no logs, giving no indication of what's wrong.
A `workflow_dispatch`-triggered test workflow in a calling repo (see git
history for an example) surfaces the actual validation error immediately
via `gh workflow run`, which is a much faster way to catch a mistake here
before it breaks a real deploy.
